package helix.render3d;

import helix.graphics.Color;
import helix.texture.Sampling;
import helix.texture.Wrap;
import helix.texture.Texture2D;
import helix.render3d.Gltf.field;
import helix.render3d.Track3D;
import helix.render3d.TrackInterpolation3D;
import helix.render3d.TrackPath3D;
import helix.render3d.ImageSource3D;

/** A model file read into what a Renderer3D draws: its meshes (a part a glTF primitive), its materials and its node tree, from a glTF 2.0 file
	(ModelCache3D loads them). instantiate() makes a fresh node tree each call, sharing the file's meshes and materials, so any number of copies draw
	together; each copy has lights and cameras of its own. Made by ModelCache3D; read, never changed after.

	Read: GLB and .gltf files, their buffers inside them, inline (data: URIs) or in files beside them, and their images in buffer views, inline
	or in files beside them; triangle primitives' positions, normals (worked out when missing), first texture coordinates and tangents (worked
	out when missing); metallic-roughness materials' base color and texture, metallic and roughness factors, normal map and its scale, emissive
	color (with KHR_materials_emissive_strength), alphaMode BLEND and doubleSided; nodes' names, translation, rotation and scale or matrix, and
	children; the default scene's roots; textures' samplers (filter and wrap); KHR_lights_punctual's directional, point and spot lights; cameras
	(a perspective one's yfov, znear and zfar, an orthographic one's ymag, znear and zfar; its aspectRatio or xmag is the viewport's business
	and isn't read); skins
	(each vertex's first four joints and weights, the joints by their nodes' names, their inverse bind matrices), each copy's skinned models
	bound to that copy's joints; animations as AnimationClips (clips), their tracks targeting nodes by name, so a file of animations alone
	plays on any skeleton with those names. Not read yet (warned once a file): morph targets (and animations of their weights),
	metallic-roughness, occlusion and emissive textures, alphaMode MASK, texture transforms (KHR_texture_transform beyond its texture coordinate
	set), a second texture coordinate set, and a second set of joints and weights (a vertex's fifth to eighth joints). */
class ModelFile3D {
	var gltf:Gltf;
	var parts:Array<Array<{mesh:Mesh3D, material:Material3D}>> = [];
	var materialList:Array<Material3D> = [];
	var lights:Array<Dynamic>;
	var roots:Array<Int> = [];
	var warningList:Array<String> = [];
	var skinList:Array<Skin3D> = [];
	var clipList:Array<AnimationClip3D> = [];

	/** The file read, its images not yet decoded (ModelCache3D decodes them and sets them on its materials). Throws, saying why, for a file it can't
		read. */
	@:allow(helix.render3d.ModelCache3D)
	function new(gltf:Gltf) {
		this.gltf = gltf;
		for (m in gltf.list("materials"))
			materialList.push(material(m));
		var fallback = new Material3D();
		for (m in gltf.list("meshes")) {
			var list = [];
			var primitives:Array<Dynamic> = field(m, "primitives");
			for (p in primitives) {
				var mode:Null<Int> = field(p, "mode");
				if (mode != null && mode != 4) {
					warn('a primitive of mode $mode (not triangles) is skipped');
					continue;
				}
				if (field(p, "targets") != null)
					warn("morph targets are ignored");
				var index:Null<Int> = field(p, "material");
				list.push({mesh: mesh(p), material: index == null ? fallback : materialList[index]});
			}
			parts.push(list);
		}
		var nodes = gltf.list("nodes");
		for (s in gltf.list("skins"))
			skinList.push(skin(s, nodes));
		var index = 0;
		for (a in gltf.list("animations"))
			clipList.push(clip(a, index++, nodes));
		lights = field(field(field(gltf.document, "extensions"), "KHR_lights_punctual"), "lights");
		if (lights == null)
			lights = [];
		var scenes = gltf.list("scenes");
		var scene:Null<Int> = field(gltf.document, "scene");
		if (scenes.length > 0) {
			var nodes:Array<Int> = field(scenes[scene == null ? 0 : scene], "nodes");
			roots = nodes == null ? [] : nodes;
		} else {
			// No scene: every node that is no node's child.
			var children = new Map<Int, Bool>();
			for (n in gltf.list("nodes")) {
				var list:Array<Int> = field(n, "children");
				if (list != null)
					for (c in list)
						children[c] = true;
			}
			roots = [for (i in 0...gltf.list("nodes").length) if (!children.exists(i)) i];
		}
	}

	/** What the file used that isn't read yet, each once. */
	public var warnings(get, never):Array<String>;

	function get_warnings():Array<String>
		return warningList.copy();

	/** Its skins, in the file's order: the joints its skinned meshes follow. */
	public var skins(get, never):Array<Skin3D>;

	function get_skins():Array<Skin3D>
		return skinList.copy();

	/** Its animations, in the file's order. */
	public var clips(get, never):Array<AnimationClip3D>;

	function get_clips():Array<AnimationClip3D>
		return clipList.copy();

	/** The animation named name: its whole name, or the part after a "|" (a Blender export names a clip "Armature|Walk", so "Walk" finds it);
		null for none. */
	public function getClip(name:String):Null<AnimationClip3D> {
		for (clip in clipList)
			if (clip.name == name)
				return clip;
		for (clip in clipList) {
			var full = clip.name;
			if (full.substr(full.lastIndexOf("|") + 1) == name)
				return clip;
		}
		return null;
	}

	/** Its materials, in the file's order: change one and every copy's parts with it change. */
	public var materials(get, never):Array<Material3D>;

	function get_materials():Array<Material3D>
		return materialList.copy();

	/** A new node tree of the file's default scene, under a group named name: each of the file's nodes as one node of its name, transform and
		children: a node with a mesh a Model3D (its primitives the model's parts, sharing the file's meshes and materials), a light node a
		DirectionalLight3D, PointLight3D or SpotLight3D as the file says (of its own, each copy), a camera node a Camera3D (of its own, each copy)
		seeing from the node down its -z with its +y up, as glTF's does, so nothing is turned, and any other a group (a bare Node3D: a joint,
		an empty). A node with both a mesh and a light is the model, the light its first child; one with both a mesh and a camera is the
		model, the camera a child named the node's name with "_camera" appended. */
	public function instantiate(name = ""):Node3D {
		var root = new Node3D();
		root.name = name;
		var skinned = [];
		for (r in roots)
			root.addChild(node(r, skinned));
		// Each copy's skinned models follow that copy's joints, found by name once the tree is whole.
		for (s in skinned)
			if (!s.model.bindSkeleton(root, skinList[s.skin]))
				throw 'A skinned model\'s joints aren\'t all in its file\'s scene';
		return root;
	}

	function warn(message:String):Void
		if (warningList.indexOf(message) < 0)
			warningList.push(message);

	// 0..1 linear, as glTF's factors are, to the sRGB-encoded 0..255 of the convention's colors.
	static function srgb(c:Float):Int {
		c = c < 0 ? 0 : c > 1 ? 1 : c;
		return Math.round((c <= .0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - .055) * 255);
	}

	static function color(rgba:Array<Float>):Int
		return Color.fromChannels(srgb(rgba[0]), srgb(rgba[1]), srgb(rgba[2]), Math.round((rgba.length > 3 ? rgba[3] : 1) * 255));

	function material(m:Dynamic):Material3D {
		var material = new Material3D(),
			pbr:Dynamic = field(m, "pbrMetallicRoughness");
		var base:Array<Float> = field(pbr, "baseColorFactor");
		material.baseColor = base == null ? 0xffffffff : color(base);
		var metallic:Null<Float> = field(pbr, "metallicFactor"),
			roughness:Null<Float> = field(pbr, "roughnessFactor");
		material.metallic = metallic == null ? 1 : metallic;
		material.roughness = roughness == null ? 1 : roughness;
		var emissive:Array<Float> = field(m, "emissiveFactor");
		if (emissive != null) {
			var strength:Null<Float> = field(field(field(m, "extensions"), "KHR_materials_emissive_strength"), "emissiveStrength");
			material.setEmissive(color(emissive), strength == null ? 1 : strength);
		}
		var normal:Dynamic = field(m, "normalTexture");
		if (normal != null) {
			var scale:Null<Float> = field(normal, "scale");
			material.normalScale = scale == null ? 1 : scale;
		}
		if (field(m, "alphaMode") == "BLEND")
			material.blended = true;
		else if (field(m, "alphaMode") == "MASK")
			warn("alphaMode MASK draws opaque");
		material.doubleSided = field(m, "doubleSided") == true;
		if (field(pbr, "metallicRoughnessTexture") != null || field(m, "occlusionTexture") != null || field(m, "emissiveTexture") != null)
			warn("metallic-roughness, occlusion and emissive textures are ignored");
		return material;
	}

	// glTF's wrap modes (WebGL's numbers) as a Sampling's; repeat when unset.
	static function wrap(mode:Null<Int>):Wrap
		return mode == 33071 ? Clamp : mode == 33648 ? Mirror : Repeat;

	/** The images materials use, each once (an image two materials share is decoded once): where its file is (in a buffer view, inline, or a
		file of its own named by a uri relative to the model), how its texture samples (its sampler's filter, linear unless its magnification
		filter is nearest, and wrap), and what to set once it's decoded. */
	@:allow(helix.render3d.ModelCache3D)
	function images():Array<{source:ImageSource3D, sampling:Sampling, set:Array<Texture2D->Void>}> {
		var out:Array<{source:ImageSource3D, sampling:Sampling, set:Array<Texture2D->Void>}> = [],
			byKey = new Map<String, Int>();
		var textures = gltf.list("textures"),
			images = gltf.list("images"),
			samplers = gltf.list("samplers");
		function image(info:Dynamic, set:Texture2D->Void):Void {
			if (info == null)
				return;
			if (field(info, "texCoord") != null && field(info, "texCoord") != 0)
				warn("a second texture coordinate set is read as the first");
			var transform:Dynamic = field(field(info, "extensions"), "KHR_texture_transform");
			if (transform != null
				&& (field(transform, "offset") != null || field(transform, "scale") != null || field(transform, "rotation") != null))
				warn("texture transforms (KHR_texture_transform) are ignored");
			var textureIndex:Int = field(info, "index"),
				t = textures[textureIndex],
				imageIndex:Null<Int> = field(t, "source");
			if (imageIndex == null || imageIndex < 0 || imageIndex >= images.length) {
				warn("a texture without an image is skipped");
				return;
			}
			var samplerIndex:Null<Int> = field(t, "sampler");
			var key = '$imageIndex/$samplerIndex';
			if (byKey.exists(key)) {
				out[byKey[key]].set.push(set);
				return;
			}
			var img = images[imageIndex],
				view:Null<Int> = field(img, "bufferView"),
				uri:Null<String> = field(img, "uri");
			var source = view != null ? InView(view) : uri == null ? null : StringTools.startsWith(uri, "data:") ? Inline(Gltf.dataUri(uri)) : File(uri);
			if (source == null) {
				warn("an image with neither a buffer view nor a uri is skipped");
				return;
			}
			var sampler:Dynamic = samplerIndex == null ? null : samplers[samplerIndex];
			var mag:Null<Int> = field(sampler, "magFilter");
			byKey[key] = out.length;
			out.push({
				source: source,
				sampling: new Sampling(mag != 9728 ? Linear : Nearest, wrap(field(sampler, "wrapS")), wrap(field(sampler, "wrapT"))),
				set: [set]
			});
		}
		var list = gltf.list("materials");
		for (i in 0...list.length) {
			var target = materialList[i];
			image(field(field(list[i], "pbrMetallicRoughness"), "baseColorTexture"), t -> target.texture = t);
			image(field(list[i], "normalTexture"), t -> target.normalTexture = t);
		}
		return out;
	}

	@:allow(helix.render3d.ModelCache3D)
	function gltfFile():Gltf
		return gltf;

	function mesh(p:Dynamic):Mesh3D {
		var attributes:Dynamic = field(p, "attributes");
		var position:Null<Int> = field(attributes, "POSITION");
		if (position == null)
			throw "A primitive has no POSITION";
		var normal:Null<Int> = field(attributes, "NORMAL"),
			uv:Null<Int> = field(attributes, "TEXCOORD_0"),
			tangent:Null<Int> = field(attributes, "TANGENT"),
			indices:Null<Int> = field(p, "indices"),
			joints:Null<Int> = field(attributes, "JOINTS_0"),
			weights:Null<Int> = field(attributes, "WEIGHTS_0");
		if (field(attributes, "JOINTS_1") != null)
			warn("a second set of joints and weights is ignored: a vertex follows its first four joints");
		var skinned = joints != null && weights != null;
		return Mesh3D.fromArrays(gltf.floats(position), normal == null ? null : gltf.floats(normal), uv == null ? null : gltf.floats(uv),
			tangent == null ? null : gltf.floats(tangent), indices == null ? null : gltf.ints(indices), skinned ? gltf.floats(joints) : null,
			skinned ? gltf.floats(weights) : null);
	}

	// A skin: its joints by their nodes' names, which must be there and unique in the file for a copy's models to find them.
	function skin(s:Dynamic, nodes:Array<Dynamic>):Skin3D {
		var joints:Array<Int> = field(s, "joints");
		if (joints == null || joints.length == 0)
			throw "A skin has no joints";
		var names = [];
		for (j in joints) {
			var name:String = field(nodes[j], "name");
			if (name == null || name == "")
				throw 'A skin\'s joint (node $j) has no name';
			names.push(name);
		}
		for (n in names)
			if ([for (node in nodes) if (field(node, "name") == n) 1].length > 1)
				throw 'A skin\'s joint name "$n" is used by more than one node';
		var inverseBind:Null<Int> = field(s, "inverseBindMatrices");
		return new Skin3D(names, inverseBind == null ? null : gltf.floats(inverseBind));
	}

	// An animation: a track a channel, targeting its node by name; morph targets' weights aren't read.
	function clip(a:Dynamic, index:Int, nodes:Array<Dynamic>):AnimationClip3D {
		var name:String = field(a, "name"), samplers:Array<Dynamic> = field(a, "samplers"), channels:Array<Dynamic> = field(a, "channels"), tracks = [];
		for (c in channels) {
			var target:Dynamic = field(c, "target"),
				node:Null<Int> = field(target, "node"),
				path:String = field(target, "path");
			if (path == "weights") {
				warn("animations of morph target weights are ignored");
				continue;
			}
			if (node == null)
				continue;
			var nodeName:String = field(nodes[node], "name");
			if (nodeName == null || nodeName == "")
				throw 'An animation moves a node ($node) without a name';
			var sampler = samplers[field(c, "sampler")],
				interpolation:String = field(sampler, "interpolation");
			tracks.push(new Track3D(nodeName, path == "rotation" ? TrackPath3D.Rotation : path == "scale" ? TrackPath3D.Scale : TrackPath3D.Translation,
				interpolation == "STEP" ? TrackInterpolation3D.Step : interpolation == "CUBICSPLINE" ? TrackInterpolation3D.CubicSpline : TrackInterpolation3D.Linear,
				gltf.floats(field(sampler, "input")), gltf.floats(field(sampler, "output"))));
		}
		return new AnimationClip3D(name == null || name == "" ? 'animation$index' : name, tracks);
	}

	function light(index:Int):Light3D {
		var l = lights[index], type:String = field(l, "type");
		var range:Null<Float> = field(l, "range");
		var light:Light3D;
		if (type == "spot") {
			var spot = new SpotLight3D(), cone:Dynamic = field(l, "spot");
			var inner:Null<Float> = field(cone, "innerConeAngle"),
				outer:Null<Float> = field(cone, "outerConeAngle");
			spot.setCone(inner == null ? 0 : inner, outer == null ? Math.PI / 4 : outer);
			spot.range = range == null ? 0 : range;
			light = spot;
		} else if (type == "point") {
			var point = new PointLight3D();
			point.range = range == null ? 0 : range;
			light = point;
		} else
			light = new DirectionalLight3D();
		var c:Array<Float> = field(l, "color");
		light.color = c == null ? 0xffffffff : color(c);
		var intensity:Null<Float> = field(l, "intensity");
		light.intensity = intensity == null ? 1 : intensity;
		return light;
	}

	// Camera index as a Camera3D at the origin, unturned (its node places it): a perspective one's fovY, near and far from its yfov, znear
	// and zfar (an absent zfar, glTF's infinite one, keeps Camera3D's default far); an orthographic one's height 2 x ymag (ymag is half the
	// height seen, as Camera3D's height is all of it). Throws for a type that is neither, a required value missing, or values outside what
	// the glTF format allows (the camera would clamp them, and a file's camera is read as written or not at all).
	function camera(index:Int):Camera3D {
		var c = gltf.list("cameras")[index], type:String = field(c, "type");
		var camera = new Camera3D();
		camera.setPosition(0, 0, 0);
		camera.setQuaternion(0, 0, 0, 1);
		if (type == "perspective") {
			var p:Dynamic = field(c, "perspective");
			var yfov:Null<Float> = field(p, "yfov"),
				znear:Null<Float> = field(p, "znear"),
				zfar:Null<Float> = field(p, "zfar");
			if (yfov == null || znear == null)
				throw 'Camera $index has no yfov or znear';
			if (zfar == null)
				zfar = camera.far;
			if (!(yfov > 0 && yfov < Math.PI && znear > 0 && zfar > znear))
				throw 'Camera $index\'s yfov, znear and zfar aren\'t 0 < yfov < pi and 0 < znear < zfar';
			camera.projection = Perspective;
			camera.fovY = yfov;
			clipPlanes(camera, znear, zfar);
		} else if (type == "orthographic") {
			var o:Dynamic = field(c, "orthographic");
			var ymag:Null<Float> = field(o, "ymag"),
				znear:Null<Float> = field(o, "znear"),
				zfar:Null<Float> = field(o, "zfar");
			if (ymag == null || znear == null || zfar == null)
				throw 'Camera $index has no ymag, znear or zfar';
			if (!(ymag > 0 && zfar > znear))
				throw 'Camera $index\'s ymag, znear and zfar aren\'t ymag > 0 and znear < zfar';
			camera.projection = Orthographic;
			camera.orthographicHeight = 2 * ymag;
			clipPlanes(camera, znear, zfar);
		} else
			throw 'Camera $index has type $type, neither perspective nor orthographic';
		return camera;
	}

	// near and far (near < far, and above 0 for a perspective camera) onto camera exactly: near set first lands under the old far, far
	// then goes where asked, and near again where asked should the old far have held it.
	static function clipPlanes(camera:Camera3D, near:Float, far:Float):Void {
		camera.near = near;
		camera.far = far;
		camera.near = near;
	}

	function node(index:Int, skinned:Array<{model:Model3D, skin:Int}>):Node3D {
		var n = gltf.list("nodes")[index],
			meshIndex:Null<Int> = field(n, "mesh"),
			cameraIndex:Null<Int> = field(n, "camera");
		var lightIndex:Null<Int> = field(field(field(n, "extensions"), "KHR_lights_punctual"), "light");
		var name:String = field(n, "name");
		if (name == null)
			name = "";
		var node:Node3D;
		if (meshIndex != null) {
			var model = new Model3D();
			for (part in parts[meshIndex])
				model.addPart(part.mesh, part.material);
			var skin:Null<Int> = field(n, "skin");
			if (skin != null && model.mesh != null && model.mesh.skinned)
				skinned.push({model: model, skin: skin});
			if (lightIndex != null)
				model.addChild(light(lightIndex));
			if (cameraIndex != null) {
				var lens = camera(cameraIndex);
				lens.name = name + "_camera";
				model.addChild(lens);
			}
			node = model;
		} else if (lightIndex != null)
			node = light(lightIndex);
		else if (cameraIndex != null)
			node = camera(cameraIndex);
		else
			node = new Node3D();
		node.name = name;
		var matrix:Array<Float> = field(n, "matrix");
		if (matrix != null)
			node.setMatrix(matrix);
		else {
			var t:Array<Float> = field(n, "translation"),
				r:Array<Float> = field(n, "rotation"),
				s:Array<Float> = field(n, "scale");
			if (t != null)
				node.setPosition(t[0], t[1], t[2]);
			if (r != null)
				node.setQuaternion(r[0], r[1], r[2], r[3]);
			if (s != null)
				node.setScale(s[0], s[1], s[2]);
		}
		var children:Array<Int> = field(n, "children");
		if (children != null)
			for (c in children)
				node.addChild(this.node(c, skinned));
		return node;
	}
}
