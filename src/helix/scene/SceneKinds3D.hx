package helix.scene;

import helix.particle.Emitter;
import helix.font.Font;
import helix.font.Fonts;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.render3d.Camera3D;
import helix.render3d.DirectionalLight3D;
import helix.render3d.Light3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.Node3D;
import helix.render3d.Particles3D;
import helix.render3d.PointLight3D;
import helix.render3d.Projection3D;
import helix.render3d.SpotLight3D;
import helix.render3d.Sprite3D;
import helix.graphics.AlphaMode;
import helix.render3d.SpriteFacing3D;
import helix.render3d.Text3D;
import helix.render3d.Tonemap;
import helix.scene.SceneValue;

/** The live side of SceneSchema3D's tables, in one module so the two can't drift: a node of a kind made from its name, a kind's property
	applied to a live node from a file's value and read back from it, a Model3D's inline material applied and read, and its generated mesh
	made by Mesh3D's generators and read back from the mesh's record. What the tables
	name as text here becomes the classes' values: an enum's case from its lower-case name (a sprite's facing, its alpha mode, a camera's
	projection, the stage's tonemap), a texture or a font from its path through Textures and Fonts, a color as 0xAARRGGBB. */
@:noCompletion
class SceneKinds3D {
	/** A new node of kind, as SceneSchema3D's tables name the classes: a bare Node3D for "Node3D", a Model3D of no parts, a light, a camera, a
		sprite of no texture, a text of no text, a Particles3D with an emitter of no texture holding 1024 particles. Null for a name no table
		has. */
	public static function make(kind:String):Null<Node3D> {
		return switch kind {
			case "Node3D": new Node3D();
			case "Model3D": new Model3D();
			case "DirectionalLight3D": new DirectionalLight3D();
			case "PointLight3D": new PointLight3D();
			case "SpotLight3D": new SpotLight3D();
			case "Camera3D": new Camera3D();
			case "Sprite3D": new Sprite3D(null);
			case "Text3D": new Text3D("");
			case "Particles3D": new Particles3D(new Emitter(null));
			case _: null;
		}
	}

	/** The kind node is, as the tables name it: its class's name (a Node3D of no other class is "Node3D"). Null for a class no table has. */
	public static function kindOf(node:Node3D):Null<String> {
		if (Std.isOfType(node, Model3D))
			return "Model3D";
		if (Std.isOfType(node, DirectionalLight3D))
			return "DirectionalLight3D";
		if (Std.isOfType(node, PointLight3D))
			return "PointLight3D";
		if (Std.isOfType(node, SpotLight3D))
			return "SpotLight3D";
		if (Std.isOfType(node, Camera3D))
			return "Camera3D";
		if (Std.isOfType(node, Sprite3D))
			return "Sprite3D";
		if (Std.isOfType(node, Text3D))
			return "Text3D";
		if (Std.isOfType(node, Particles3D))
			return "Particles3D";
		return Type.getClass(node) == Node3D ? "Node3D" : null;
	}

	/** Sets node's property name to value, as its own kind's table has it: a light's intensity, a camera's fovY, a spot's cones (each
		through setCone, the other widened or narrowed to keep the pair in order) and a camera's near and far (the other moved just past it to
		keep the pair in order, so a file giving both lands on both whichever comes first), a sprite's region and size, a text's size. A
		texture's or a font's path loads through Textures or Fonts and lands when it does ("" for none); instance, when given, keeps what it
		loads to release at its destroy. False, changing nothing, for a property node's kind hasn't, a value of the wrong shape, a named
		choice no enum has, or a value the class refuses. */
	public static function apply(node:Node3D, name:String, value:SceneValue, ?instance:SceneInstance3D):Bool {
		var model = Std.downcast(node, Model3D);
		if (model != null)
			return switch [name, value] {
				case ["tint", Color(c)]:
					model.tint = c;
					true;
				case ["shadowCasting", Flag(f)]:
					model.shadowCasting = f;
					true;
				case ["shadowReceiving", Flag(f)]:
					model.shadowReceiving = f;
					true;
				case _: false;
			}
		var light = Std.downcast(node, Light3D);
		if (light != null) {
			var spot = Std.downcast(node, SpotLight3D),
				point = Std.downcast(node, PointLight3D);
			return switch [name, value] {
				case ["color", Color(c)]:
					light.color = c;
					true;
				case ["intensity", Number(v)]:
					light.intensity = v;
					true;
				case ["shadowCasting", Flag(f)] if (point == null):
					light.shadowCasting = f;
					true;
				case ["shadowDistance", Number(v)] if (point == null):
					light.shadowDistance = v;
					true;
				case ["shadowMapSize", Number(v)] if (point == null):
					light.shadowMapSize = Std.int(v);
					true;
				case ["shadowStrength", Number(v)] if (point == null):
					light.shadowStrength = v;
					true;
				case ["shadowColor", Color(c)] if (point == null):
					light.shadowColor = c;
					true;
				case ["range", Number(v)] if (point != null):
					point.range = v;
					true;
				case ["range", Number(v)] if (spot != null):
					spot.range = v;
					true;
				case ["innerCone", Number(v)] if (spot != null):
					spot.setCone(v, Math.max(v, spot.outerCone));
				case ["outerCone", Number(v)] if (spot != null):
					spot.setCone(Math.min(spot.innerCone, v), v);
				case _: false;
			}
		}
		var camera = Std.downcast(node, Camera3D);
		if (camera != null)
			return switch [name, value] {
				case ["projection", Text(t)]:
					var projection = projectionOf(t);
					if (projection != null)
						camera.projection = projection;
					projection != null;
				case ["fovY", Number(v)]:
					camera.fovY = v;
					true;
				case ["near", Number(v)]:
					if (!(v < camera.far))
						camera.far = v + 1e-6;
					camera.near = v;
					true;
				case ["far", Number(v)]:
					if (!(v > camera.near))
						camera.near = v - 1e-6;
					camera.far = v;
					true;
				case ["orthographicHeight", Number(v)]:
					camera.orthographicHeight = v;
					true;
				case ["minAspect", Number(v)]:
					camera.minAspect = v;
					true;
				case _: false;
			}
		var sprite = Std.downcast(node, Sprite3D);
		if (sprite != null)
			return switch [name, value] {
				case ["texture", Text(path)]:
					loadTexture(path, instance, texture -> sprite.texture = texture);
					true;
				case ["tint", Color(c)]:
					sprite.tint = c;
					true;
				case ["regionX", Number(v)]:
					sprite.setRegion(v, sprite.regionY, sprite.regionWidth, sprite.regionHeight);
					true;
				case ["regionY", Number(v)]:
					sprite.setRegion(sprite.regionX, v, sprite.regionWidth, sprite.regionHeight);
					true;
				case ["regionWidth", Number(v)]:
					sprite.setRegion(sprite.regionX, sprite.regionY, v, sprite.regionHeight);
					true;
				case ["regionHeight", Number(v)]:
					sprite.setRegion(sprite.regionX, sprite.regionY, sprite.regionWidth, v);
					true;
				case ["spriteWidth", Number(v)]: sprite.setSpriteSize(v, sprite.spriteHeight);
				case ["spriteHeight", Number(v)]: sprite.setSpriteSize(sprite.spriteWidth, v);
				case ["pivotX", Number(v)]:
					sprite.setPivot(v, sprite.pivotY);
					true;
				case ["pivotY", Number(v)]:
					sprite.setPivot(sprite.pivotX, v);
					true;
				case ["facing", Text(t)]:
					var facing = facingOf(t);
					if (facing != null)
						sprite.facing = facing;
					facing != null;
				case ["alphaMode", Text(t)]: var mode = alphaOf(t); mode != null && sprite.setAlphaMode(mode, sprite.alphaCutoff);
				case ["alphaCutoff", Number(v)]: sprite.setAlphaMode(sprite.alphaMode, v);
				case _: false;
			}
		var text = Std.downcast(node, Text3D);
		if (text != null)
			return switch [name, value] {
				case ["text", Text(t)]:
					text.text = t;
					true;
				case ["textSize", Number(v)]:
					text.textSize = v;
					true;
				case ["color", Color(c)]:
					text.color = c;
					true;
				case ["font", Text(path)]:
					loadFont(path, instance, font -> text.font = font);
					true;
				case ["pivotX", Number(v)]:
					text.setPivot(v, text.pivotY);
					true;
				case ["pivotY", Number(v)]:
					text.setPivot(text.pivotX, v);
					true;
				case ["facing", Text(t)]:
					var facing = facingOf(t);
					if (facing != null)
						text.facing = facing;
					facing != null;
				case _: false;
			}
		return false;
	}

	/** Node's property name as it is now, as its own kind's table has it; a texture or a font as the path it was loaded from. Null for a
		property node's kind hasn't, or one that can't be read now: a sprite with no texture or a text with no font (none, or one not yet
		landed), or one that didn't come through the caches. */
	public static function read(node:Node3D, name:String):Null<SceneValue> {
		var model = Std.downcast(node, Model3D);
		if (model != null)
			return switch name {
				case "tint": Color(model.tint);
				case "shadowCasting": Flag(model.shadowCasting);
				case "shadowReceiving": Flag(model.shadowReceiving);
				case _: null;
			}
		var light = Std.downcast(node, Light3D);
		if (light != null) {
			var spot = Std.downcast(node, SpotLight3D),
				point = Std.downcast(node, PointLight3D);
			return switch name {
				case "color": Color(light.color);
				case "intensity": Number(light.intensity);
				case "shadowCasting" if (point == null): Flag(light.shadowCasting);
				case "shadowDistance" if (point == null): Number(light.shadowDistance);
				case "shadowMapSize" if (point == null): Number(light.shadowMapSize);
				case "shadowStrength" if (point == null): Number(light.shadowStrength);
				case "shadowColor" if (point == null): Color(light.shadowColor);
				case "range" if (point != null): Number(point.range);
				case "range" if (spot != null): Number(spot.range);
				case "innerCone" if (spot != null): Number(spot.innerCone);
				case "outerCone" if (spot != null): Number(spot.outerCone);
				case _: null;
			}
		}
		var camera = Std.downcast(node, Camera3D);
		if (camera != null)
			return switch name {
				case "projection": Text(projectionName(camera.projection));
				case "fovY": Number(camera.fovY);
				case "near": Number(camera.near);
				case "far": Number(camera.far);
				case "orthographicHeight": Number(camera.orthographicHeight);
				case "minAspect": Number(camera.minAspect);
				case _: null;
			}
		var sprite = Std.downcast(node, Sprite3D);
		if (sprite != null)
			return switch name {
				case "texture": texturePath(sprite.texture);
				case "tint": Color(sprite.tint);
				case "regionX": Number(sprite.regionX);
				case "regionY": Number(sprite.regionY);
				case "regionWidth": Number(sprite.regionWidth);
				case "regionHeight": Number(sprite.regionHeight);
				case "spriteWidth": Number(sprite.spriteWidth);
				case "spriteHeight": Number(sprite.spriteHeight);
				case "pivotX": Number(sprite.pivotX);
				case "pivotY": Number(sprite.pivotY);
				case "facing": Text(facingName(sprite.facing));
				case "alphaMode": Text(alphaName(sprite.alphaMode));
				case "alphaCutoff": Number(sprite.alphaCutoff);
				case _: null;
			}
		var text = Std.downcast(node, Text3D);
		if (text != null)
			return switch name {
				case "text": Text(text.text);
				case "textSize": Number(text.textSize);
				case "color": Color(text.color);
				case "font":
					var path = text.font == null ? null : Fonts.getPath(text.font);
					path == null ? null : Text(path);
				case "pivotX": Number(text.pivotX);
				case "pivotY": Number(text.pivotY);
				case "facing": Text(facingName(text.facing));
				case _: null;
			}
		return null;
	}

	/** The mesh a file's mesh entry names, made by Mesh3D's generator of its shape with its arguments, an unsaid one the generator's default
		(SceneSchema3D.shapes), a count rounded toward zero. Null for a shape no generator makes or a required argument missing. */
	public static function makeMesh(mesh:SceneMesh3D):Null<Mesh3D> {
		var schema = SceneSchema3D.shape(mesh.shape);
		if (schema == null)
			return null;
		var values = [];
		for (argument in schema.arguments) {
			var value = mesh.arguments.get(argument.name);
			if (value == null)
				value = argument.defaultValue;
			if (value == null)
				return null;
			values.push(value);
		}
		inline function count(i:Int):Int
			return Std.int(values[i]);
		return switch mesh.shape {
			case "plane": Mesh3D.plane(values[0], values[1], count(2));
			case "cube": Mesh3D.cube(values[0], values[1], values[2]);
			case "sphere": Mesh3D.sphere(values[0], count(1), count(2));
			case "cylinder": Mesh3D.cylinder(values[0], values[1], count(2));
			case "cone": Mesh3D.cone(values[0], values[1], count(2));
			case "capsule": Mesh3D.capsule(values[0], values[1], count(2), count(3));
			case "torus": Mesh3D.torus(values[0], values[1], count(2), count(3));
			case _: null;
		}
	}

	/** Mesh as a file's mesh entry, from its record of what made it (Mesh3D.shape), every argument said (the writer leaves out those at the
		generator's default). Null for a mesh with no record (from arrays or a file) or a shape the tables don't have. */
	public static function readMesh(mesh:Mesh3D):Null<SceneMesh3D> {
		var shape = mesh.shape;
		if (shape == null || SceneSchema3D.shape(shape.name) == null)
			return null;
		var read = new SceneMesh3D(shape.name);
		for (argument in SceneSchema3D.shape(shape.name).arguments)
			if (shape.arguments.exists(argument.name))
				read.arguments.set(argument.name, shape.arguments.get(argument.name));
		return read;
	}

	/** Gives model a new material carrying material's values, the rest Material3D's defaults, as its first part's (made when it has none):
		an inline material replaces the mesh's or the file's. Its textures load through Textures by path and land when they do; instance,
		when given, keeps them to release at its destroy. */
	public static function applyMaterial(model:Model3D, material:SceneMaterial3D, ?instance:SceneInstance3D):Void {
		var made = new Material3D();
		if (material.baseColor != null)
			made.baseColor = material.baseColor;
		if (material.metallic != null)
			made.metallic = material.metallic;
		if (material.roughness != null)
			made.roughness = material.roughness;
		if (material.normalScale != null)
			made.normalScale = material.normalScale;
		if (material.emissive != null || material.emissiveStrength != null)
			made.setEmissive(material.emissive != null ? material.emissive : made.emissive,
				material.emissiveStrength != null ? material.emissiveStrength : made.emissiveStrength);
		if (material.doubleSided != null)
			made.doubleSided = material.doubleSided;
		if (material.texture != null)
			loadTexture(material.texture, instance, texture -> made.texture = texture);
		if (material.normalTexture != null)
			loadTexture(material.normalTexture, instance, texture -> made.normalTexture = texture);
		model.material = made;
	}

	/** Model3D's first part's material as a file writes it, every value said; a texture as the path it was loaded from, or unsaid (null) for
		none or one that didn't come through Textures. Null for a model of no parts. */
	public static function readMaterial(model:Model3D):Null<SceneMaterial3D> {
		var material = model.material;
		if (material == null)
			return null;
		var read = new SceneMaterial3D();
		read.baseColor = material.baseColor;
		read.metallic = material.metallic;
		read.roughness = material.roughness;
		read.texture = material.texture == null ? null : Textures.getPath(material.texture);
		read.normalTexture = material.normalTexture == null ? null : Textures.getPath(material.normalTexture);
		read.normalScale = material.normalScale;
		read.emissive = material.emissive;
		read.emissiveStrength = material.emissiveStrength;
		read.doubleSided = material.doubleSided;
		return read;
	}

	/** The projection named name, "perspective" or "orthographic" (SceneSchema3D.projections); null for another name. */
	public static function projectionOf(name:String):Null<Projection3D> {
		var index = SceneSchema3D.projections.indexOf(name);
		return index < 0 ? null : cast index;
	}

	/** A projection's name as the file writes it (SceneSchema3D.projections). */
	public static function projectionName(projection:Projection3D):String
		return SceneSchema3D.projections[(projection : Int)];

	/** The facing named name, "camera", "upright", "ground" or "free"; null for another name. */
	public static function facingOf(name:String):Null<SpriteFacing3D> {
		var index = FACINGS.indexOf(name);
		return index < 0 ? null : cast index;
	}

	/** A facing's name as the file writes it. */
	public static function facingName(facing:SpriteFacing3D):String
		return FACINGS[(facing : Int)];

	/** The alpha mode named name, "opaque", "mask", "blend" or "add"; null for another name. */
	public static function alphaOf(name:String):Null<AlphaMode> {
		var index = ALPHAS.indexOf(name);
		return index < 0 ? null : cast index;
	}

	/** An alpha mode's name as the file writes it. */
	public static function alphaName(alpha:AlphaMode):String
		return ALPHAS[(alpha : Int)];

	static final FACINGS = ["camera", "upright", "ground", "free"];
	static final ALPHAS = ["opaque", "mask", "blend", "add"];

	// A sprite's texture as a value: its path, or null for none or one the cache didn't give.
	static function texturePath(texture:Null<Texture2D>):Null<SceneValue> {
		var path = texture == null ? null : Textures.getPath(texture);
		return path == null ? null : Text(path);
	}

	// path's texture through Textures ("" for none, set at once), smooth with mipmaps, into set when it lands; the instance keeps it.
	static function loadTexture(path:String, instance:Null<SceneInstance3D>, set:Null<Texture2D>->Void):Void {
		if (path == "") {
			set(null);
			return;
		}
		var request = Textures.load(path, Linear, texture -> {
			if (instance != null && !instance.holdTexture(texture))
				return;
			set(texture);
		});
		if (instance != null)
			instance.holdRequest(request);
	}

	// path's font through Fonts ("" for none, set at once), into set when it lands; the instance keeps it.
	static function loadFont(path:String, instance:Null<SceneInstance3D>, set:Null<Font>->Void):Void {
		if (path == "") {
			set(null);
			return;
		}
		var request = Fonts.load(path, font -> {
			if (instance != null && !instance.holdFont(font))
				return;
			set(font);
		});
		if (instance != null)
			instance.holdRequest(request);
	}
}
