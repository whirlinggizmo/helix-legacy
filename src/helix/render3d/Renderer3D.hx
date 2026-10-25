package helix.render3d;

import haxe.ds.Vector;
import haxe.io.Bytes;
import helix.graphics.BlendMode;
import helix.graphics.Color;
import helix.graphics.IGraphics;
import helix.texture.Sampling;
import helix.texture.Texture2D;

/** What draws and picks a tree of 3D nodes (docs/DISPLAY_MODEL.md): each View3D's, never a game's, which shows a tree with a View3D. A
	draw (draw(camera), inside a frame) walks the tree as it is now (each world matrix
	worked out only where something changed), gathers the lights it finds, places each model's part's box and culls it against the
	camera's view, sorts the opaque models so alike ones (same mesh and material) are together and the see-through ones back to front after
	them, writes each model's instance record (its matrix's rows, its normals' matrix's rows, its tint), and draws each run of alike models as
	one instanced draw. Lit by its lights and its ambient light, glTF metallic-roughness (Material3D).

	Shadows: lights that cast them (Light3D.shadowCasting, up to the four the stage lights by) each draw the models that cast into a layer of
	a shadow map, in drawShadows, which comes before the frame's screen pass (beginFrame) as any pass into a texture does; draw then reads the
	maps the last drawShadows made. A directional light's map is a square over what the camera sees out to its shadow distance, its texels
	the same size and in the same places in the world as the camera moves and turns, so its shadows' edges hold still; a spot's covers its
	cone.

	EnvironmentMap3D: an environment map (Environments3D.load) lights its lit models as well (setEnvironment), diffuse light from all around and
	reflections sharp to blurred by roughness, and can stand behind everything (setBackground). Its lit color, which can run past 1, comes
	into what a screen shows by its exposure and tone mapping (exposure, tonemap: Khronos PBR Neutral at 0 EV to start), or in an HDR
	scene (hdr) past 1 for a PostProcess chain to tone map; its sprites, text and particles are display colors, untouched.

	Surface shaders: a material's (Material3D.setShader) draws its models, a skinned one through the shader's skinned variant, and casts their
	shadows through its caster where it has one (a vertex hook or a discard), so the shadow moves and opens as the surface does. A model's
	passes (ModelPass3D: outlines, silhouettes) are drawn from its records after the opaque models. */
@:noCompletion
@:allow(helix)
class Renderer3D {
	// Lights: the first 64 a walk finds are considered; the 16 that reach the drawn models most are the table the shaders read, and each model
	// is lit by the 8 of those that reach it most; the first 4 that cast have shadows.
	static inline var GATHERED_LIGHTS = 64;
	static inline var TABLE_LIGHTS = 16;
	static inline var MODEL_LIGHTS = 8;
	static inline var SHADOW_LIGHTS = 4;
	// The fragment block's layout (lit3d_shared.glsl's lit3d_fs_members): the camera, the ambient light, the material's (its base color, pbr,
	// emission, flash and rim), the table's four arrays, then the shadows', tone mapping and the environment.
	static inline var MATERIAL = 32;
	static inline var LIGHT_POSITION = 112;
	static inline var LIGHT_DIRECTION = LIGHT_POSITION + TABLE_LIGHTS * 16;
	static inline var LIGHT_RADIANCE = LIGHT_DIRECTION + TABLE_LIGHTS * 16;
	static inline var LIGHT_SPOT = LIGHT_RADIANCE + TABLE_LIGHTS * 16;
	static inline var SHADOW_MATRIX = LIGHT_SPOT + TABLE_LIGHTS * 16;
	static inline var SHADOW_PARAMS = SHADOW_MATRIX + SHADOW_LIGHTS * 64;
	static inline var SHADOW_TINT = SHADOW_PARAMS + 2 * SHADOW_LIGHTS * 16;
	static inline var TONEMAP = SHADOW_TINT + SHADOW_LIGHTS * 16;
	static inline var ENVIRONMENT = TONEMAP + 16;
	static inline var IRRADIANCE = ENVIRONMENT + 16;
	// How far a directional light's map starts behind what the camera sees: casters out of view still cast into it.
	static inline var SHADOW_PULLBACK = 50.;
	// Per shadow layer, what the shaders read: its matrix (16), a texel in uv, a texel in world units, bias constant and slope, strength, near,
	// far, perspective (1 or 0), tint rgb (linear), bias texels to depth units.
	static inline var LAYER_FLOATS = 30;

	var gpu:IGraphics;
	// The tree in drawing order (depth first, the root's children down) and each node's parent's place in it (-1 for the root's children),
	// remade when the root's count of adds and removes moves; each kind's nodes with their places, in the same order. Every walk then goes
	// down the order, and each pass reads its kinds' lists.
	var builtStructure = -1;
	var order:Array<Node3D> = [];
	var parentOf:Array<Int> = [];
	// Whether each node is shown (it and every node above it visible), and whether it can be hit (shown, and it and every node above it
	// pickable).
	var shown:Array<Bool> = [];
	var hittable:Array<Bool> = [];
	var moved:Array<Bool> = [];
	// Whether each node is paused, itself or by a node above it: its emitters held still.
	var frozen:Array<Bool> = [];
	var models:Array<Model3D> = [];
	var modelAt:Array<Int> = [];
	var treeLights:Array<Light3D> = [];
	var treeLightAt:Array<Int> = [];
	var flats:Array<Node3D> = [];
	var flatAt:Array<Int> = [];
	var emitters:Array<Node3D> = [];
	var emitterAt:Array<Int> = [];
	// The kinds that draw themselves (Drawing3D: linked only into a program that makes one), after the opaque models; the batch they share,
	// the first one's to make, and how to free it.
	var owners:Array<Node3D> = [];
	var ownerAt:Array<Int> = [];
	@:allow(helix.render3d.Drawing3D)
	var ownBatch:Null<Any>;
	@:allow(helix.render3d.Drawing3D)
	var ownBatchDestroy:Null<Void->Void>;
	var pipelines:helix.graphics.Pipelines;
	var white:Texture2D;
	var flat:Texture2D;
	var capacity = 1024;
	var instanceBuffer:Int;
	var records:Bytes;
	var vertexUniforms = Bytes.alloc(64);
	var fragmentUniforms = Bytes.alloc(Lit3DProgram.fragmentUniformBytes);
	var items:Array<Item> = [];
	var drawn:Array<Item> = [];
	var count = 0;
	var lights:Array<Light3D> = [];
	var planes = new Vector<Float>(24);
	var inverse = new Mat4();
	var eyeX = 0.;
	var eyeY = 0.;
	var eyeZ = 0.;
	var forwardX = 0.;
	var forwardY = 0.;
	var forwardZ = -1.;
	var draws = 0;
	// The sprites, texts and emitters' drawing (Sprites3D: linked only into a program that makes one), made by the first one listed.
	@:allow(helix.render3d.Sprites3D)
	var sprites:Null<SpriteCalls>;
	// The clock at the last draw: emitters advance by the difference.
	var drawnTime = Math.NaN;
	// Shadows: the walk gathering casters rather than drawing; the casters (every model that casts, in view or not) and those of one layer.
	var gathering = false;
	var casters:Array<Caster> = [];
	var casterCount = 0;
	var layerCasters:Array<Caster> = [];
	var casterCapacity = 256;
	var casterBuffer:Int;
	var casterRecords:Bytes;
	// Skinned casters' records (Skinneddepth3DProgram's: the world matrix's rows, then the first joint), apart from the others'.
	var skinnedCasterCapacity = 16;
	var skinnedCasterBuffer:Int;
	var skinnedCasterRecords:Bytes;
	// The records of casters a surface shader draws (its caster: Lit3DProgram's, as the models' own), apart again.
	var shadedCasterCapacity = 16;
	var shadedCasterBuffer:Int;
	var shadedCasterRecords:Bytes;
	// The models' passes of a draw (ModelPass3D): each an item's place in the draw and one of its model's passes, sorted into runs.
	var passDraws:Array<PassDraw> = [];
	var passDrawCount = 0;
	var passUniforms = [
		Bytes.alloc(Flat3DProgram.vertexUniformBytes),
		Bytes.alloc(Flat3DProgram.fragmentUniformBytes)
	];
	// The joints of the pass's skinned models, and the skinned models the walk met, placed once it has posed every joint.
	var palette:JointPalette3D;
	// Picking: the walk testing what it meets against a ray, the nearest hit so far, a skinned model's vertices posed on the CPU.
	var picking = false;
	var pickRay = new Ray3D();
	var pickHit:PickHit3D;
	var pickBest = 0.;
	var pickCamera:Null<Camera3D>;
	var pickInverse = new Mat4();
	// The normal where a ray enters a hit area, in its node's space.
	var areaNormal = [0., 0., 0.];
	var pickPalette:JointPalette3D;
	var posedVertices = new Vector<Float>(0);
	var skinned:Array<Model3D> = [];
	var skinnedParts:Array<Part3D> = [];
	var posed = new Vector<Float>(6);
	// The shadow map (layers of the size the last drawShadows needed), and a map of one texel that stands in when there are none.
	var shadowMap = 0;
	var shadowMapSize = 0;
	var shadowMapLayers = 0;
	var noShadows:Int;
	// The lights the last drawShadows gave a layer, in layer order, and what each layer's readers need.
	var shadowLights:Array<Light3D> = [];
	var shadowLayers = new Vector<Float>(SHADOW_LIGHTS * LAYER_FLOATS);
	// The table this draw's shaders read; for choosing it, each gathered light's constants, its best score, its place in the table, each
	// model's scores, and a model's best eight so far.
	var table:Array<Light3D> = [];
	var lightData = new Vector<Float>(GATHERED_LIGHTS * 10);
	var cones = new Vector<Float>(GATHERED_LIGHTS * 2);
	var best = new Vector<Float>(GATHERED_LIGHTS);
	var tableOf = new Vector<Int>(GATHERED_LIGHTS);
	var itemScores = new Vector<Float>(0);
	var slotScores = new Vector<Float>(8);
	var shadowDraws = 0;
	var shadowCasters = 0;
	var lightView = new Mat4();
	var lightProjection = new Mat4();
	var lightViewProjection = new Mat4();
	var lightPlanes = new Vector<Float>(24);
	var depthUniforms = Bytes.alloc(Depth3DProgram.vertexUniformBytes);
	// The environment lighting the models, and the one behind them, with their settings.
	// A black cube that stands in when there's no environment, and the BRDF table, made with the first environment.
	var noEnvironment:Int;
	var brdf:Null<Texture2D>;
	var backgroundUniforms = [
		Bytes.alloc(Background3DProgram.vertexUniformBytes),
		Bytes.alloc(Background3DProgram.fragmentUniformBytes)
	];

	/** An empty stage drawing on gpu, unlit: no lights and no ambient light until they're added.  Without gpu, the program's (Graphics.instance).
		With root, it draws root's children (a View3D's tree) rather than a root of its own. */
	function new(?gpu:IGraphics, ?root:Node3D) {
		this.root = root == null ? new Node3D() : root;
		if (gpu == null)
			gpu = helix.graphics.Graphics.instance;
		this.gpu = gpu;
		pipelines = helix.graphics.Pipelines.of(gpu);
		var pixel = Bytes.alloc(4);
		pixel.fill(0, 4, 255);
		white = Texture2D.fromRgba(1, 1, pixel, gpu);
		// A normal map's "straight out": the default, which the shader skips anyway when a material has none.
		var normal = Bytes.alloc(4);
		normal.set(0, 128);
		normal.set(1, 128);
		normal.set(2, 255);
		normal.set(3, 255);
		flat = Texture2D.fromRgba(1, 1, normal, Linear, gpu);
		instanceBuffer = gpu.createBuffer(capacity * Lit3DProgram.instanceStride);
		records = Bytes.alloc(capacity * Lit3DProgram.instanceStride);
		casterBuffer = gpu.createBuffer(casterCapacity * Depth3DProgram.instanceStride);
		casterRecords = Bytes.alloc(casterCapacity * Depth3DProgram.instanceStride);
		skinnedCasterBuffer = gpu.createBuffer(skinnedCasterCapacity * Skinneddepth3DProgram.instanceStride);
		skinnedCasterRecords = Bytes.alloc(skinnedCasterCapacity * Skinneddepth3DProgram.instanceStride);
		shadedCasterBuffer = gpu.createBuffer(shadedCasterCapacity * Lit3DProgram.instanceStride);
		shadedCasterRecords = Bytes.alloc(shadedCasterCapacity * Lit3DProgram.instanceStride);
		palette = new JointPalette3D(gpu);
		pickPalette = new JointPalette3D(gpu);
		noShadows = gpu.createShadowMap(1, 1);
		var black = Bytes.alloc(6 * 4);
		for (face in 0...6)
			black.set(face * 4 + 3, 255);
		noEnvironment = gpu.createCubeTexture(1, [black], Rgba8);
	}

	// The place's light: a View3D's environment, else the first one in the tree (root's, depth first; a scene file's), set before each draw
	// over what setAmbient, setEnvironment and setBackground said, which stand only for a stage no view draws and no environment is in;
	// more than one in the tree logged once.
	@:allow(helix.render3d.View3D)
	var viewed = false;
	@:allow(helix.render3d.View3D)
	var viewEnvironment:Null<Environment3D>;
	var foundEnvironment:Null<Environment3D>;
	var moreEnvironments = false;
	var moreLogged = false;

	// Lit by environment's light (none for null).
	function light(environment:Null<Environment3D>):Void {
		if (moreEnvironments && viewEnvironment == null && !moreLogged) {
			moreLogged = true;
			trace("View3D: more than one environment in a tree; the first lights it (docs/DISPLAY_MODEL.md)");
		}
		if (environment == null) {
			setAmbient(0xffffffff, 0);
			setEnvironment(null);
			setBackground(null);
		} else {
			setAmbient(environment.ambientColor, environment.ambientIntensity);
			setEnvironment(environment.map, environment.mapIntensity, environment.rotation);
			setBackground(environment.background, environment.backgroundBlur);
		}
	}

	/** The node everything on the stage hangs from. */
	var root(default, null):Node3D;

	/** Adds node to the stage, as the root's last child. False for one of the root's ancestors (the root itself). */
	function add(node:Node3D):Bool
		return root.addChild(node);

	/** Takes node from the stage's root. False when it isn't one of the root's children. */
	function remove(node:Node3D):Bool
		return root.removeChild(node);

	/** The ambient light's color, 0xAARRGGBB (sRGB). */
	var ambientColor(default, null):Int = 0xffffffff;

	/** The ambient light's intensity. */
	var ambientIntensity(default, null):Float = 0.;

	/** The light reaching everything evenly, from no direction: color 0xAARRGGBB (sRGB) times intensity. False for an intensity under 0. */
	function setAmbient(color:Int, intensity:Float):Bool {
		if (!(intensity >= 0))
			return false;
		ambientColor = color;
		ambientIntensity = intensity;
		return true;
	}

	/** The environment lighting the lit models, or null. */
	var environment(default, null):Null<EnvironmentMap3D>;

	/** How strongly the environment lights them, and the background shows: 1 as its file has it. */
	var environmentIntensity(default, null):Float = 1.;

	/** How far the environment, and the background, turn about +y, in radians. */
	var environmentRotation(default, null):Float = 0.;

	/** Lights the lit models with environment (null: none) as well as the lights and the ambient light: its intensity (1 as its file has it)
		and its turn about +y (radians), which the background shares. False, changing nothing, for an intensity under 0. */
	function setEnvironment(environment:Null<EnvironmentMap3D>, intensity = 1., rotation = 0.):Bool {
		if (!(intensity >= 0) || !Math.isFinite(rotation))
			return false;
		this.environment = environment;
		environmentIntensity = intensity;
		environmentRotation = rotation;
		return true;
	}

	/** The environment drawn behind everything, or null. */
	var background(default, null):Null<EnvironmentMap3D>;

	/** How blurred the background is: 0 sharp to 1 its blurriest. */
	var backgroundBlur(default, null):Float = 0.;

	/** Draws environment (null: none) behind everything, before the models, at blur 0 (sharp, the image's own resolution) to 1 (blurred to a
		few texels), turned and as bright as setEnvironment says, tone mapped as the models are. False, changing nothing, for a blur outside
		0..1. */
	function setBackground(environment:Null<EnvironmentMap3D>, blur = 0.):Bool {
		if (!(blur >= 0 && blur <= 1))
			return false;
		background = environment;
		backgroundBlur = blur;
		return true;
	}

	/** How lit color comes into the screen's 0..1 after the exposure. In an HDR scene (hdr) the chain's tone mapping applies it instead. */
	var tonemap:Tonemap = Tonemap.Neutral;

	/** Whether it draws into an HDR scene (half floats): its lit color and background after the exposure, not tone mapped, written as sRGB values
		running past 1 (the sRGB curve carried on), for a PostProcess chain's effects and then its tone mapping (helix.shader.Tonemap), which
		its sprites, text and particles (sRGB values as ever) go through too. False to start; PostProcess sets it on its stage from beginScene to
		endScene when its scene is HDR. */
	var hdr:Bool = false;

	/** The exposure in stops (EV): each one doubles the light before the tone mapping; 0 to start. An exposure that isn't finite is taken as 0. */
	var exposure(default, set):Float = 0.;

	function set_exposure(value:Float):Float {
		value = Math.isFinite(value) ? value : 0;
		exposure = value;
		return value;
	}

	/** The seconds surface shaders see (helix_time): what the app last set. */
	var time:Float = 0.;

	/** Whether draws leave out what's out of view (models, sprites and text, and shadow casters out of a light's): on to start. Culls, or
		draws everything (to measure what culling saves). */
	var culling:Bool = true;

	// m's view's planes into out; with culling off, planes everything is inside.
	function viewPlanes(m:Mat4, out:Vector<Float>):Void {
		if (culling) {
			planesOf(m, out);
			return;
		}
		for (p in 0...6) {
			out[p * 4] = out[p * 4 + 1] = out[p * 4 + 2] = 0;
			out[p * 4 + 3] = 1;
		}
	}

	/** Models' parts and sprites drawn by the last draw (in view). */
	var drawnNodeCount(get, never):Int;

	function get_drawnNodeCount():Int
		return count + (sprites != null ? sprites.drawnSpriteCount() : 0);

	/** Draws of the last draw: one a run of alike models' parts, or of sprites of one texture. */
	var drawCallCount(get, never):Int;

	function get_drawCallCount():Int
		return draws + (sprites != null ? sprites.drawCallCount() : 0);

	/** Draws into shadow maps by the last drawShadows: one a run of casting parts alike in mesh, in each light's layer. */
	var shadowDrawCallCount(get, never):Int;

	function get_shadowDrawCallCount():Int
		return shadowDraws;

	/** Casting parts drawn into shadow maps by the last drawShadows, counted in each light's layer they reach. */
	var shadowCasterCount(get, never):Int;

	function get_shadowCasterCount():Int
		return shadowCasters;

	static inline function linear(channel:Int):Float {
		var c = channel / 255;
		return c <= .04045 ? c / 12.92 : Math.pow((c + .055) / 1.055, 2.4);
	}

	/** Draws the shadows of its casting lights (Light3D.shadowCasting; the first four lights found) for what camera sees: each light's casters
		into its layer of the shadow map, a pass each. Outside any pass, before the frame's screen pass (beginFrame), each frame shadows move;
		draws after use them. With no casting light or no caster, there are no shadows. */
	function drawShadows(camera:Camera3D):Void {
		shadowDraws = 0;
		shadowCasters = 0;
		shadowLights.resize(0);
		var viewProjection = camera.viewProjection;
		eyeX = camera.eyeX;
		eyeY = camera.eyeY;
		eyeZ = camera.eyeZ;
		lights.resize(0);
		casterCount = 0;
		gathering = true;
		walk();
		gathering = false;
		palette.clear();
		for (i in 0...casterCount)
			if (casters[i].skinned)
				casters[i].jointBase = palette.add(casters[i].node);
		palette.upload();
		var size = 0;
		for (light in lights)
			if (light.shadowCasting && shadowLights.length < SHADOW_LIGHTS) {
				shadowLights.push(light);
				size = Std.int(Math.max(size, light.shadowMapSize));
			}
		if (shadowLights.length == 0 || casterCount == 0) {
			shadowLights.resize(0);
			return;
		}
		if (shadowMap == 0 || shadowMapSize != size || shadowMapLayers != shadowLights.length) {
			if (shadowMap != 0)
				gpu.destroyTexture(shadowMap);
			shadowMap = gpu.createShadowMap(size, shadowLights.length);
			shadowMapSize = size;
			shadowMapLayers = shadowLights.length;
		}
		for (layer in 0...shadowLights.length) {
			var light = shadowLights[layer],
				at = layer * LAYER_FLOATS,
				spot = Std.downcast(light, SpotLight3D);
			var fit = spot != null ? fitSpot(spot, size) : fitDirectional(light, camera, size);
			for (i in 0...16)
				shadowLayers[at + i] = lightViewProjection.get(i);
			shadowLayers[at + 16] = 1 / size;
			shadowLayers[at + 17] = fit.texelWorld;
			shadowLayers[at + 18] = light.shadowBiasConstant;
			shadowLayers[at + 19] = light.shadowBiasSlope;
			shadowLayers[at + 20] = light.shadowStrength;
			shadowLayers[at + 21] = fit.near;
			shadowLayers[at + 22] = fit.far;
			shadowLayers[at + 23] = fit.perspective ? 1 : 0;
			var tint = light.shadowColor;
			shadowLayers[at + 24] = linear(Color.getRed(tint));
			shadowLayers[at + 25] = linear(Color.getGreen(tint));
			shadowLayers[at + 26] = linear(Color.getBlue(tint));
			// The bias is in texels, what acne is made of; an orthographic map's depth units are its range.
			shadowLayers[at + 27] = fit.far > fit.near ? fit.texelWorld / (fit.far - fit.near) : 0;
			drawLayer(layer);
		}
	}

	// Fits a directional light's map to what camera sees out to its shadow distance, into lightViewProjection: a square around the view's slice
	// from the near plane, as wide as the slice's bounding sphere (so its texels keep their size as the camera turns), its corner snapped to
	// whole texels of a light space fixed to the world (so its shadows don't crawl as the camera moves), from SHADOW_PULLBACK behind the slice.
	function fitDirectional(node:Light3D, camera:Camera3D, size:Int):{
		texelWorld:Float,
		near:Float,
		far:Float,
		perspective:Bool
	} {
		var w = node.worldMatrix, distance = node.shadowDistance;
		var dx = -w.get(8),
			dy = -w.get(9),
			dz = -w.get(10),
			dl = Math.sqrt(dx * dx + dy * dy + dz * dz);
		if (dl > 0) {
			dx /= dl;
			dy /= dl;
			dz /= dl;
		} else {
			dx = dz = 0;
			dy = -1;
		}
		// The camera's frame: forward, right and up.
		var fx = camera.forwardX, fy = camera.forwardY, fz = camera.forwardZ;
		var ux = camera.upX, uy = camera.upY, uz = camera.upZ;
		var rx = fy * uz - fz * uy,
			ry = fz * ux - fx * uz,
			rz = fx * uy - fy * ux;
		var rl = Math.sqrt(rx * rx + ry * ry + rz * rz);
		rx /= rl;
		ry /= rl;
		rz /= rl;
		ux = ry * fz - rz * fy;
		uy = rz * fx - rx * fz;
		uz = rx * fy - ry * fx;
		var aspect = camera.viewportWidth / camera.viewportHeight,
			orthographic = camera.projection == Orthographic;
		var corners = new Vector<Float>(24), cx = 0., cy = 0., cz = 0.;
		for (p in 0...2) {
			var z = p == 0 ? (orthographic ? 0 : camera.near) : distance;
			var halfHeight = orthographic ? camera.drawnHeight / 2 : Math.tan(camera.drawnFovY / 2) * z,
				halfWidth = halfHeight * aspect;
			for (c in 0...4) {
				// The lens shift slides the slice across as it does the picture.
				var x = (c & 1 != 0 ? halfWidth : -halfWidth) + camera.lensShiftX * halfWidth,
					y = (c & 2 != 0 ? halfHeight : -halfHeight) + camera.lensShiftY * halfHeight,
					at = (p * 4 + c) * 3;
				corners[at] = eyeX + fx * z + rx * x + ux * y;
				corners[at + 1] = eyeY + fy * z + ry * x + uy * y;
				corners[at + 2] = eyeZ + fz * z + rz * x + uz * y;
				cx += corners[at] / 8;
				cy += corners[at + 1] / 8;
				cz += corners[at + 2] / 8;
			}
		}
		// The slice's bounding sphere, its radius rounded up to a sixteenth so rounding error doesn't change it frame to frame.
		var radius = 0.;
		for (i in 0...8) {
			var ex = corners[i * 3] - cx,
				ey = corners[i * 3 + 1] - cy,
				ez = corners[i * 3 + 2] - cz;
			radius = Math.max(radius, Math.sqrt(ex * ex + ey * ey + ez * ez));
		}
		radius = Math.ceil(radius * 16) / 16;
		// Light space: from the world's origin along the light, so a texel is the same place in the world whichever way the camera moves.
		var flat = Math.abs(dy) > .99;
		lightView.makeLookAt(0, 0, 0, dx, dy, dz, 0, flat ? 0 : 1, flat ? 1 : 0);
		var vx = lightView.get(0) * cx + lightView.get(4) * cy + lightView.get(8) * cz;
		var vy = lightView.get(1) * cx + lightView.get(5) * cy + lightView.get(9) * cz;
		// The view looks down -z: depth grows that way.
		var depth = -(lightView.get(2) * cx + lightView.get(6) * cy + lightView.get(10) * cz);
		var side = radius * 2, texel = side / size;
		var left = Math.floor((vx - radius) / texel) * texel,
			bottom = Math.floor((vy - radius) / texel) * texel;
		var near = depth - radius - SHADOW_PULLBACK, far = depth + radius;
		lightProjection.makeOrthographicBox(left, left + side, bottom, bottom + side, near, far);
		lightViewProjection.makeProduct(lightProjection, lightView);
		return {
			texelWorld: texel,
			near: near,
			far: far,
			perspective: false
		};
	}

	// Fits a spot's map to its cone into lightViewProjection: a perspective from its position down its axis, a little wider than the cone, out to
	// its range (or its shadow distance, the nearer).
	function fitSpot(light:SpotLight3D, size:Int):{
		texelWorld:Float,
		near:Float,
		far:Float,
		perspective:Bool
	} {
		var w = light.worldMatrix;
		var dx = -w.get(8),
			dy = -w.get(9),
			dz = -w.get(10),
			dl = Math.sqrt(dx * dx + dy * dy + dz * dz);
		if (dl > 0) {
			dx /= dl;
			dy /= dl;
			dz /= dl;
		} else {
			dx = dz = 0;
			dy = -1;
		}
		var reach = light.range > 0 ? Math.min(light.range, light.shadowDistance) : light.shadowDistance;
		var cosOuter = Math.cos(light.outerCone);
		var fovY = 2 * Math.acos(cosOuter < -.99 ? -.99 : cosOuter > 1 ? 1 : cosOuter) * 1.1;
		fovY = fovY > 2.8 ? 2.8 : fovY < .02 ? .02 : fovY;
		var px = w.get(12),
			py = w.get(13),
			pz = w.get(14),
			flat = Math.abs(dy) > .99;
		lightView.makeLookAt(px, py, pz, px + dx, py + dy, pz + dz, 0, flat ? 0 : 1, flat ? 1 : 0);
		lightProjection.makePerspective(fovY, 1, reach * .01, reach);
		lightViewProjection.makeProduct(lightProjection, lightView);
		return {
			texelWorld: 2 * Math.tan(fovY / 2) * reach / size,
			near: reach * .01,
			far: reach,
			perspective: true
		};
	}

	// Draws layer's casters into it, through lightViewProjection: those its view reaches, the framework's static ones, its skinned ones, then
	// those a surface shader draws, each kind's alike ones together, one draw.
	function drawLayer(layer:Int):Void {
		viewPlanes(lightViewProjection, lightPlanes);
		layerCasters.resize(0);
		for (i in 0...casterCount) {
			var c = casters[i];
			if (inside(lightPlanes, c.cx, c.cy, c.cz, c.rx, c.ry, c.rz))
				layerCasters.push(c);
		}
		gpu.beginShadowPass(shadowMap, layer);
		layerCasters.sort((a, b) -> compareCasters(a, b));
		lightViewProjection.writeTo(depthUniforms);
		var n = 0, total = layerCasters.length;
		while (n < total && casterKind(layerCasters[n]) == 0)
			n++;
		var m = n;
		while (m < total && casterKind(layerCasters[m]) == 1)
			m++;
		drawStaticCasters(n);
		drawSkinnedCasters(n, m);
		drawShadedCasters(m, total);
		shadowCasters += total;
		gpu.endTargetPass();
	}

	// Which kind of caster: 0 the framework's static, 1 its skinned, 2 one a surface shader draws.
	static inline function casterKind(c:Caster):Int
		return c.program != null ? 2 : c.skinned ? 1 : 0;

	// Casters in their drawing order: by kind, then a shader's by its program and material, then by mesh.
	static function compareCasters(a:Caster, b:Caster):Int {
		var kind = casterKind(a) - casterKind(b);
		if (kind != 0)
			return kind;
		if (a.program != null) {
			if (a.program.handle != b.program.handle)
				return a.program.handle - b.program.handle;
			if (a.material.id != b.material.id)
				return a.material.id - b.material.id;
		}
		return a.mesh.id - b.mesh.id;
	}

	// Draws the layer's first n casters, the framework's static ones, through the depth program.
	function drawStaticCasters(n:Int):Void {
		if (n == 0)
			return;
		if (n > casterCapacity) {
			while (casterCapacity < n)
				casterCapacity *= 2;
			gpu.destroyBuffer(casterBuffer);
			casterBuffer = gpu.createBuffer(casterCapacity * Depth3DProgram.instanceStride);
			casterRecords = Bytes.alloc(casterCapacity * Depth3DProgram.instanceStride);
		}
		for (i in 0...n) {
			var w = layerCasters[i].node.worldMatrix,
				at = i * Depth3DProgram.instanceStride;
			for (row in 0...3)
				for (col in 0...4)
					casterRecords.setFloat(at + Depth3DProgram.model0Offset + row * 16 + col * 4, w.get(col * 4 + row));
		}
		gpu.updateBuffer(casterBuffer, casterRecords, n * Depth3DProgram.instanceStride);
		var uniforms = [depthUniforms], i = 0;
		while (i < n) {
			var last = i, mesh = layerCasters[i].mesh;
			while (last + 1 < n && layerCasters[last + 1].mesh == mesh)
				last++;
			gpu.draw(pipelines.depth3D(), [mesh.getVertexBuffer(gpu), casterBuffer], mesh.getIndexBuffer(gpu), 0, mesh.indexCount, i, last - i + 1, [], [],
				uniforms);
			shadowDraws++;
			i = last + 1;
		}
	}

	// Draws the layer's casters first to end (the framework's skinned ones) through the skinned depth program.
	function drawSkinnedCasters(first:Int, end:Int):Void {
		var n = end - first;
		if (n <= 0)
			return;
		if (n > skinnedCasterCapacity) {
			while (skinnedCasterCapacity < n)
				skinnedCasterCapacity *= 2;
			gpu.destroyBuffer(skinnedCasterBuffer);
			skinnedCasterBuffer = gpu.createBuffer(skinnedCasterCapacity * Skinneddepth3DProgram.instanceStride);
			skinnedCasterRecords = Bytes.alloc(skinnedCasterCapacity * Skinneddepth3DProgram.instanceStride);
		}
		for (i in 0...n) {
			var c = layerCasters[first + i],
				w = c.node.worldMatrix,
				at = i * Skinneddepth3DProgram.instanceStride;
			for (row in 0...3)
				for (col in 0...4)
					skinnedCasterRecords.setFloat(at + Skinneddepth3DProgram.model0Offset + row * 16 + col * 4, w.get(col * 4 + row));
			skinnedCasterRecords.setFloat(at + Skinneddepth3DProgram.skinOffset, c.jointBase);
		}
		gpu.updateBuffer(skinnedCasterBuffer, skinnedCasterRecords, n * Skinneddepth3DProgram.instanceStride);
		var uniforms = [depthUniforms], i = 0;
		while (i < n) {
			var last = i, mesh = layerCasters[first + i].mesh;
			while (last + 1 < n && layerCasters[first + last + 1].mesh == mesh)
				last++;
			gpu.draw(pipelines.skinnedDepth3D(), [mesh.getVertexBuffer(gpu), skinnedCasterBuffer, mesh.getSkinBuffer(gpu)], mesh.getIndexBuffer(gpu), 0,
				mesh.indexCount, i, last - i + 1, [palette.texture], [Sampling.NEAREST], uniforms);
			shadowDraws++;
			i = last + 1;
		}
	}

	// Draws the layer's casters first to end, those a surface shader draws (its caster: its vertex hook moving them, its fragment stage
	// discarding what it cuts away), from the lit models' records, with their materials' values and textures; a run alike in program,
	// material and mesh one draw. The shadow map being drawn is never bound: the stand-in is.
	function drawShadedCasters(first:Int, end:Int):Void {
		var n = end - first;
		if (n <= 0)
			return;
		if (n > shadedCasterCapacity) {
			while (shadedCasterCapacity < n)
				shadedCasterCapacity *= 2;
			gpu.destroyBuffer(shadedCasterBuffer);
			shadedCasterBuffer = gpu.createBuffer(shadedCasterCapacity * Lit3DProgram.instanceStride);
			shadedCasterRecords = Bytes.alloc(shadedCasterCapacity * Lit3DProgram.instanceStride);
		}
		for (i in 0...n) {
			var c = layerCasters[first + i];
			writeInstance(shadedCasterRecords, i, c.node, c.skinned, c.jointBase, null);
		}
		gpu.updateBuffer(shadedCasterBuffer, shadedCasterRecords, n * Lit3DProgram.instanceStride);
		var i = 0;
		while (i < n) {
			var last = i, c = layerCasters[first + i];
			while (last + 1 < n) {
				var next = layerCasters[first + last + 1];
				if (next.program != c.program || next.material != c.material || next.mesh != c.mesh)
					break;
				last++;
			}
			var program = c.program, mesh = c.mesh;
			writeMaterial(c.material, fragmentUniforms);
			var bound = surfaceTextures(program, c.material, noShadows);
			gpu.draw(pipelines.surfaceCaster(program.handle, c.skinned), meshBuffers(mesh, shadedCasterBuffer, c.skinned), mesh.getIndexBuffer(gpu), 0,
				mesh.indexCount, i, last - i + 1, bound.textures, bound.samplings, surfaceBlocks(program, c.material, depthUniforms));
			shadowDraws++;
			i = last + 1;
		}
	}

	// A mesh's buffers as a lit draw takes them: its vertices, the instance records, and a skinned draw's skin.
	function meshBuffers(mesh:Mesh3D, instances:Int, skinned:Bool):Array<Int>
		return skinned ? [mesh.getVertexBuffer(gpu), instances, mesh.getSkinBuffer(gpu)] : [mesh.getVertexBuffer(gpu), instances];

	/** What's under framebuffer pixel x, y (from the top-left, as the pointer is) seen through camera: the nearest model, sprite or text it shows there, into
		hit (a new one when not given), or null for nothing (or a point outside camera's viewport). A hidden or
		unpickable node and everything under it are passed over, the ray going on to what's behind; a paused one is hit. A node with a hitArea
		is hit by it in place of what it draws (a group too). Models are hit by their triangles (a skinned one's as posed now), from either side; a see-through one (its material
		blended or its tint) only where its alpha reaches a half. Sprites and text are hit by their quads as drawn (a text by its whole block), not yet by their texels. World matrices are brought up to date, as a draw does. */
	function pick(camera:Camera3D, x:Float, y:Float, ?hit:PickHit3D):Null<PickHit3D>
		return camera.computeRay(x, y, pickRay) != null ? pickAlong(pickRay, camera, hit) : null;

	/** The nearest model, sprite or text along ray, as pick says, into hit (a new one when not given); null for none. Sprites and text face as
		camera shows them: without a camera, only models are hit. */
	function pickAlong(ray:Ray3D, ?camera:Camera3D, ?hit:PickHit3D):Null<PickHit3D> {
		pickCamera = camera;
		if (builtStructure != root.structure)
			rebuild();
		if (camera != null && sprites != null)
			sprites.preparePick(camera);
		var result = hit != null ? hit : new PickHit3D();
		result.clear();
		if (ray != pickRay)
			pickRay.set(ray.originX, ray.originY, ray.originZ, ray.directionX, ray.directionY, ray.directionZ);
		pickHit = result;
		pickBest = Math.POSITIVE_INFINITY;
		picking = true;
		walk();
		picking = false;
		return result.node == null ? null : result;
	}

	// Where the ray enters the box boxX..boxRZ (0 when it starts inside), or infinity when it misses.
	function rayBox():Float {
		var lo = 0., hi = Math.POSITIVE_INFINITY;
		for (axis in 0...3) {
			var o = axis == 0 ? pickRay.originX : axis == 1 ? pickRay.originY : pickRay.originZ,
				d = axis == 0 ? pickRay.directionX : axis == 1 ? pickRay.directionY : pickRay.directionZ,
				c = axis == 0 ? boxX : axis == 1 ? boxY : boxZ,
				reach = axis == 0 ? boxRX : axis == 1 ? boxRY : boxRZ;
			if (Math.abs(d) < 1e-12) {
				if (o < c - reach || o > c + reach)
					return Math.POSITIVE_INFINITY;
				continue;
			}
			var a = (c - reach - o) / d, b = (c + reach - o) / d;
			if (a > b) {
				var t = a;
				a = b;
				b = t;
			}
			lo = Math.max(lo, a);
			hi = Math.min(hi, b);
			if (lo > hi)
				return Math.POSITIVE_INFINITY;
		}
		return lo;
	}

	// Tests a model's parts' triangles against the ray, each in the model's own space, keeping the nearest hit.
	// Tests node's hit area against the ray, in its space, as the nearest yet or not.
	function pickHitArea(node:Node3D):Void {
		var inv = pickInverse;
		if (!inv.makeInverse(node.worldMatrix))
			return;
		var ox = pickRay.originX, oy = pickRay.originY, oz = pickRay.originZ;
		var dx = pickRay.directionX,
			dy = pickRay.directionY,
			dz = pickRay.directionZ;
		var lox = inv.get(0) * ox + inv.get(4) * oy + inv.get(8) * oz + inv.get(12),
			loy = inv.get(1) * ox + inv.get(5) * oy + inv.get(9) * oz + inv.get(13),
			loz = inv.get(2) * ox + inv.get(6) * oy + inv.get(10) * oz + inv.get(14);
		var ldx = inv.get(0) * dx + inv.get(4) * dy + inv.get(8) * dz,
			ldy = inv.get(1) * dx + inv.get(5) * dy + inv.get(9) * dz,
			ldz = inv.get(2) * dx + inv.get(6) * dy + inv.get(10) * dz;
		var t = node.hitArea.enter(lox, loy, loz, ldx, ldy, ldz, areaNormal);
		if (t >= pickBest)
			return;
		var hnx = areaNormal[0], hny = areaNormal[1], hnz = areaNormal[2];
		var nx = inv.get(0) * hnx + inv.get(1) * hny + inv.get(2) * hnz,
			ny = inv.get(4) * hnx + inv.get(5) * hny + inv.get(6) * hnz,
			nz = inv.get(8) * hnx + inv.get(9) * hny + inv.get(10) * hnz;
		var length = Math.sqrt(nx * nx + ny * ny + nz * nz);
		if (length > 0) {
			nx /= length;
			ny /= length;
			nz /= length;
		}
		if (nx * dx + ny * dy + nz * dz > 0) {
			nx = -nx;
			ny = -ny;
			nz = -nz;
		}
		pickBest = t;
		pickHit.record(node, t, ox + dx * t, oy + dy * t, oz + dz * t, lox + ldx * t, loy + ldy * t, loz + ldz * t, nx, ny, nz);
	}

	// Whether a pick passes over a part of node in material: one see-through (blended or tinted) under half its alpha.
	function passesOver(node:Model3D, material:Material3D):Bool {
		var alpha = Color.getAlpha(node.tint) / 255;
		return (material.blended || alpha < 1) && alpha * Color.getAlpha(material.baseColor) / 255 < .5;
	}

	// A part's vertex positions in node's space as a pick tests them (a skinned one's posed as now), x, y, z each, into a vector reused.
	function placePositions(node:Model3D, mesh:Mesh3D):Vector<Float> {
		var count = mesh.vertexCount, vertices = mesh.vertices;
		var positions = posedVertices;
		if (positions.length < count * 3)
			positions = posedVertices = new Vector<Float>(count * 3);
		if (isSkinned(node, mesh))
			pose(node, mesh, positions);
		else
			for (i in 0...count)
				for (c in 0...3)
					positions[i * 3 + c] = vertices.getFloat(i * Lit3DProgram.stride + Lit3DProgram.positionOffset + c * 4);
		return positions;
	}

	// The triangles a pick tests on node, each corner placed in the world (x, y, z each, three a triangle), into out: its parts a pick
	// doesn't pass over, posed as now. What PickOverlay3D draws.

	@:allow(helix.debug.PickOverlay3D)
	function pickTriangles(node:Model3D, out:Array<Float>):Void {
		out.resize(0);
		var w = node.worldMatrix;
		for (i in 0...node.partCount) {
			var part = node.getPart(i), mesh = part.mesh;
			if (mesh == null || passesOver(node, part.material))
				continue;
			var positions = placePositions(node, mesh), indices = mesh.indices;
			for (k in 0...mesh.indexCount) {
				var at = indices.getInt32(k * 4) * 3,
					x = positions[at],
					y = positions[at + 1],
					z = positions[at + 2];
				out.push(w.get(0) * x + w.get(4) * y + w.get(8) * z + w.get(12));
				out.push(w.get(1) * x + w.get(5) * y + w.get(9) * z + w.get(13));
				out.push(w.get(2) * x + w.get(6) * y + w.get(10) * z + w.get(14));
			}
		}
	}

	function pickModel(node:Model3D):Void
		for (i in 0...node.partCount) {
			var part = node.getPart(i);
			if (part.mesh != null)
				pickPart(node, part.mesh, part.material);
		}

	// Tests one part's triangles against the ray, after its box, which must be nearer than the best.
	function pickPart(node:Model3D, mesh:Mesh3D, material:Material3D):Void {
		if (passesOver(node, material))
			return;
		placeBox(node, mesh);
		if (rayBox() >= pickBest)
			return;
		var w = node.worldMatrix, inv = pickInverse;
		if (!inv.makeInverse(w))
			return;
		var ox = pickRay.originX, oy = pickRay.originY, oz = pickRay.originZ;
		var dx = pickRay.directionX,
			dy = pickRay.directionY,
			dz = pickRay.directionZ;
		// The ray in the model's space: the same t reaches the same point, so distances stay the world's.
		var lox = inv.get(0) * ox + inv.get(4) * oy + inv.get(8) * oz + inv.get(12),
			loy = inv.get(1) * ox + inv.get(5) * oy + inv.get(9) * oz + inv.get(13),
			loz = inv.get(2) * ox + inv.get(6) * oy + inv.get(10) * oz + inv.get(14);
		var ldx = inv.get(0) * dx + inv.get(4) * dy + inv.get(8) * dz,
			ldy = inv.get(1) * dx + inv.get(5) * dy + inv.get(9) * dz,
			ldz = inv.get(2) * dx + inv.get(6) * dy + inv.get(10) * dz;
		var indices = mesh.indices, positions = placePositions(node, mesh);
		var found = false, hitT = 0., hnx = 0., hny = 0., hnz = 0., hitA = 0, hitB = 0, hitC = 0, hitU = 0., hitV = 0.;
		var i = 0, n = mesh.indexCount;
		while (i < n) {
			var a = indices.getInt32(i * 4) * 3,
				b = indices.getInt32(i * 4 + 4) * 3,
				c = indices.getInt32(i * 4 + 8) * 3;
			i += 3;
			// Möller–Trumbore, either face.
			var e1x = positions[b] - positions[a],
				e1y = positions[b + 1] - positions[a + 1],
				e1z = positions[b + 2] - positions[a + 2];
			var e2x = positions[c] - positions[a],
				e2y = positions[c + 1] - positions[a + 1],
				e2z = positions[c + 2] - positions[a + 2];
			var px = ldy * e2z - ldz * e2y,
				py = ldz * e2x - ldx * e2z,
				pz = ldx * e2y - ldy * e2x;
			var det = e1x * px + e1y * py + e1z * pz;
			if (Math.abs(det) < 1e-12)
				continue;
			var sx = lox - positions[a],
				sy = loy - positions[a + 1],
				sz = loz - positions[a + 2];
			var u = (sx * px + sy * py + sz * pz) / det;
			if (u < 0 || u > 1)
				continue;
			var qx = sy * e1z - sz * e1y,
				qy = sz * e1x - sx * e1z,
				qz = sx * e1y - sy * e1x;
			var v = (ldx * qx + ldy * qy + ldz * qz) / det;
			if (v < 0 || u + v > 1)
				continue;
			var t = (e2x * qx + e2y * qy + e2z * qz) / det;
			if (t < 0 || t >= pickBest || (found && t >= hitT))
				continue;
			found = true;
			hitT = t;
			hitA = a;
			hitB = b;
			hitC = c;
			hitU = u;
			hitV = v;
			hnx = e1y * e2z - e1z * e2y;
			hny = e1z * e2x - e1x * e2z;
			hnz = e1x * e2y - e1y * e2x;
		}
		if (!found)
			return;
		// The normal into the world by the inverse's transpose, made a unit vector, turned to face back along the ray.
		var nx = inv.get(0) * hnx + inv.get(1) * hny + inv.get(2) * hnz,
			ny = inv.get(4) * hnx + inv.get(5) * hny + inv.get(6) * hnz,
			nz = inv.get(8) * hnx + inv.get(9) * hny + inv.get(10) * hnz;
		var length = Math.sqrt(nx * nx + ny * ny + nz * nz);
		if (length > 0) {
			nx /= length;
			ny /= length;
			nz /= length;
		}
		if (nx * dx + ny * dy + nz * dz > 0) {
			nx = -nx;
			ny = -ny;
			nz = -nz;
		}
		pickBest = hitT;
		pickHit.record(node, hitT, ox + dx * hitT, oy + dy * hitT, oz + dz * hitT, lox + ldx * hitT, loy + ldy * hitT, loz + ldz * hitT, nx, ny, nz);
		if (isSkinned(node, mesh))
			pickHit.recordJoint(heaviestJoint(node, mesh, [hitA, hitB, hitC], [1 - hitU - hitV, hitU, hitV]));
	}

	// The joint weighing most at a point of a skinned triangle: each of its vertices' joints by its weight there and the point's share of
	// the vertex (corners, position indices three a vertex; shares, barycentric).
	function heaviestJoint(node:Model3D, mesh:Mesh3D, corners:Array<Int>, shares:Array<Float>):Null<Node3D> {
		var skin = mesh.skinData,
			found:Array<Int> = [],
			weights:Array<Float> = [];
		for (k in 0...3) {
			var s = Std.int(corners[k] / 3) * Skinned3DProgram.skinStride;
			for (slot in 0...4) {
				var weight = skin.getFloat(s + Skinned3DProgram.weightsOffset + slot * 4) * shares[k];
				if (weight <= 0)
					continue;
				var j = Std.int(skin.getFloat(s + Skinned3DProgram.jointsOffset + slot * 4) + .5),
					at = found.indexOf(j);
				if (at < 0) {
					found.push(j);
					weights.push(weight);
				} else
					weights[at] += weight;
			}
		}
		var best = -1;
		for (i in 0...found.length)
			if (best < 0 || weights[i] > weights[best])
				best = i;
		return best < 0 ? null : node.getJoint(found[best]);
	}

	// A skinned model's vertices as posed now, in its own space, into out: each moved by its joints' matrices as the GPU blends them.
	function pose(node:Model3D, mesh:Mesh3D, out:Vector<Float>):Void {
		pickPalette.clear();
		var base = pickPalette.add(node),
			vertices = mesh.vertices,
			skin = mesh.skinData;
		for (i in 0...mesh.vertexCount) {
			var at = i * Lit3DProgram.stride + Lit3DProgram.positionOffset,
				s = i * Skinned3DProgram.skinStride;
			var x = vertices.getFloat(at),
				y = vertices.getFloat(at + 4),
				z = vertices.getFloat(at + 8);
			var px = 0., py = 0., pz = 0.;
			for (k in 0...4) {
				var weight = skin.getFloat(s + Skinned3DProgram.weightsOffset + k * 4);
				if (weight <= 0)
					continue;
				var j = base + Std.int(skin.getFloat(s + Skinned3DProgram.jointsOffset + k * 4) + .5);
				px += weight * (pickPalette.getMatrix(j, 0, 0) * x + pickPalette.getMatrix(j, 0, 1) * y + pickPalette.getMatrix(j, 0, 2) * z
					+ pickPalette.getMatrix(j, 0, 3));
				py += weight * (pickPalette.getMatrix(j, 1, 0) * x + pickPalette.getMatrix(j, 1, 1) * y + pickPalette.getMatrix(j, 1, 2) * z
					+ pickPalette.getMatrix(j, 1, 3));
				pz += weight * (pickPalette.getMatrix(j, 2, 0) * x + pickPalette.getMatrix(j, 2, 1) * y + pickPalette.getMatrix(j, 2, 2) * z
					+ pickPalette.getMatrix(j, 2, 3));
			}
			out[i * 3] = px;
			out[i * 3 + 1] = py;
			out[i * 3 + 2] = pz;
		}
	}

	/** Draws the stage in the open frame, through camera, in its viewport. */
	function draw(camera:Camera3D):Void {
		var viewProjection = camera.viewProjection;
		viewPlanes(viewProjection, planes);
		eyeX = camera.eyeX;
		eyeY = camera.eyeY;
		eyeZ = camera.eyeZ;
		forwardX = camera.forwardX;
		forwardY = camera.forwardY;
		forwardZ = camera.forwardZ;
		count = 0;
		draws = 0;
		lights.resize(0);
		if (builtStructure != root.structure)
			rebuild();
		if (sprites != null)
			sprites.begin(Math.isNaN(drawnTime) ? 0 : Math.max(0, time - drawnTime), time);
		drawnTime = time;
		foundEnvironment = root.environment;
		moreEnvironments = false;
		walk();
		if (viewed)
			light(viewEnvironment != null ? viewEnvironment : foundEnvironment);
		else if (foundEnvironment != null)
			light(foundEnvironment);
		drawn.resize(count);
		for (i in 0...count)
			drawn[i] = items[i];
		drawn.sort((a, b) -> compare(a, b));
		if (count > capacity) {
			while (capacity < count)
				capacity *= 2;
			gpu.destroyBuffer(instanceBuffer);
			instanceBuffer = gpu.createBuffer(capacity * Lit3DProgram.instanceStride);
			records = Bytes.alloc(capacity * Lit3DProgram.instanceStride);
		}
		palette.clear();
		for (i in 0...count)
			if (drawn[i].skinned)
				drawn[i].jointBase = palette.add(drawn[i].node);
		palette.upload();
		chooseLights();
		for (i in 0...count)
			writeInstance(records, i, drawn[i].node, drawn[i].skinned, drawn[i].jointBase, drawn[i].lights);
		gpu.updateBuffer(instanceBuffer, records, count * Lit3DProgram.instanceStride);
		gpu.applyViewport(camera.viewportX, camera.framebufferHeight - camera.viewportY - camera.viewportHeight, camera.viewportWidth, camera.viewportHeight);
		viewProjection.writeTo(vertexUniforms);
		writeScene();
		if (background != null)
			drawBackground(viewProjection);
		if (sprites != null)
			sprites.prepare(viewProjection, camera, forwardX, forwardY, forwardZ);
		// The opaque models, the opaque and masked sprites, the silhouettes where those hide their models, the opaque models with silhouettes
		// (after them, so a model's own parts never hide it), every model's outline, the see-through models with the blended sprites between
		// them back to front, then the blended sprites nearer than any of those and the added ones.
		var i = 0;
		while (i < count && !drawn[i].blended && !drawn[i].silhouetted) {
			var last = i;
			while (last + 1 < count && alike(drawn[i], drawn[last + 1]))
				last++;
			drawRun(i, last - i + 1);
			i = last + 1;
		}
		gatherPasses();
		if (sprites != null)
			sprites.drawOpaque();
		drawPasses(true, viewProjection);
		while (i < count && !drawn[i].blended) {
			var last = i;
			while (last + 1 < count && alike(drawn[i], drawn[last + 1]))
				last++;
			drawRun(i, last - i + 1);
			i = last + 1;
		}
		// The drawings after what's opaque, before what's seen through: lines on the ground under smoke and floating labels.
		drawDrawings(camera);
		drawPasses(false, viewProjection);
		while (i < count) {
			var last = i;
			while (last + 1 < count && alike(drawn[i], drawn[last + 1]))
				last++;
			if (sprites != null)
				sprites.drawBlendedBeyond(drawn[i].depth);
			drawRun(i, last - i + 1);
			i = last + 1;
		}
		if (sprites != null)
			sprites.drawRest();
	}

	// The kinds that draw themselves (Drawing3D) shown, each where its node is, depth-tested against the opaque models: the
	// first begins the renderer's shared batch for them (ownBatch), the last ends it.
	function drawDrawings(camera:Camera3D):Void {
		var shown = [
			for (k in 0...owners.length)
				if (shown[ownerAt[k]]) owners[k]
		];
		for (k in 0...shown.length)
			shown[k].drawOwn(camera, this, k == 0, k == shown.length - 1);
	}

	// The draw's passes (ModelPass3D): each enabled pass of each drawn item's model, sorted so alike ones (in kind, mesh, color and push) of items
	// next to each other in the draw are a run, drawn as one from the items' records.
	function gatherPasses():Void {
		passDrawCount = 0;
		for (i in 0...count) {
			var node = drawn[i].node;
			for (k in 0...node.passCount) {
				var pass = node.getPass(k);
				if (!pass.enabled)
					continue;
				if (passDrawCount == passDraws.length)
					passDraws.push(new PassDraw());
				var d = passDraws[passDrawCount++];
				d.item = i;
				d.pass = pass;
			}
		}
		if (passDrawCount == 0)
			return;
		var head = passDraws.slice(0, passDrawCount);
		head.sort((a, b) -> comparePasses(a, b));
		for (k in 0...passDrawCount)
			passDraws[k] = head[k];
	}

	// Passes in drawing order: by kind (outlines first), mesh, skinned or not, winding, color and push; then by their item's place in the draw.
	function comparePasses(a:PassDraw, b:PassDraw):Int {
		var x = drawn[a.item], y = drawn[b.item];
		if (a.pass.behind != b.pass.behind)
			return a.pass.behind ? 1 : -1;
		if (x.mesh.id != y.mesh.id)
			return x.mesh.id - y.mesh.id;
		if (x.skinned != y.skinned)
			return x.skinned ? 1 : -1;
		if (x.mirrored != y.mirrored)
			return x.mirrored ? 1 : -1;
		if (a.pass.color != b.pass.color)
			return a.pass.color < b.pass.color ? -1 : 1;
		if (a.pass.push != b.pass.push)
			return a.pass.push < b.pass.push ? -1 : 1;
		return a.item - b.item;
	}

	// Whether pass draw b continues a's run: alike in everything comparePasses sorts by, its item the next one in the draw.
	function continuesRun(a:PassDraw, b:PassDraw):Bool {
		var x = drawn[a.item], y = drawn[b.item];
		return b.item == a.item + 1 && a.pass.behind == b.pass.behind && x.mesh == y.mesh && x.skinned == y.skinned && x.mirrored == y.mirrored
			&& a.pass.color == b.pass.color && a.pass.push == b.pass.push;
	}

	// Draws the gathered passes that draw behind what hides them (silhouettes) or not (outlines), a run of alike ones a draw, through the flat
	// program from the items' records and their meshes' pass vertices (Mesh3D.passVertices: normals averaged where they split).
	function drawPasses(behind:Bool, viewProjection:Mat4):Void {
		viewProjection.writeTo(passUniforms[0]);
		var k = 0;
		while (k < passDrawCount) {
			var d = passDraws[k];
			if (d.pass.behind != behind) {
				k++;
				continue;
			}
			var last = k;
			while (last + 1 < passDrawCount && continuesRun(passDraws[last], passDraws[last + 1]))
				last++;
			var item = drawn[d.item], pass = d.pass, color = pass.color;
			passUniforms[0].setFloat(64, pass.push);
			passUniforms[1].setFloat(0, Color.getRed(color) / 255);
			passUniforms[1].setFloat(4, Color.getGreen(color) / 255);
			passUniforms[1].setFloat(8, Color.getBlue(color) / 255);
			passUniforms[1].setFloat(12, Color.getAlpha(color) / 255);
			var mesh = item.mesh, vertices = mesh.getPassVertexBuffer(gpu);
			gpu.draw(pipelines.flat3D(item.skinned, behind, item.mirrored),
				item.skinned ? [vertices, instanceBuffer, mesh.getSkinBuffer(gpu)] : [vertices, instanceBuffer], mesh.getIndexBuffer(gpu), 0, mesh.indexCount,
				d.item, last - k + 1, item.skinned ? [palette.texture] : [], item.skinned ? [Sampling.NEAREST] : [], passUniforms);
			draws++;
			k = last + 1;
		}
	}

	// The background, behind everything: the environment's background cube in each pixel's direction, through the inverse view-projection.
	function drawBackground(viewProjection:Mat4):Void {
		inverse.makeInverse(viewProjection);
		var u = backgroundUniforms[1];
		for (i in 0...16)
			u.setFloat(i * 4, inverse.get(i));
		u.setFloat(64, environmentIntensity);
		u.setFloat(68, backgroundBlur * (background.backgroundMipCount - 1));
		u.setFloat(72, Math.cos(environmentRotation));
		u.setFloat(76, Math.sin(environmentRotation));
		u.setFloat(80, tonemap);
		u.setFloat(84, Math.pow(2, exposure));
		u.setFloat(88, hdr ? 1 : 0);
		gpu.draw(pipelines.background3D(), [], 0, 0, 3, 0, 1, [background.backgroundTexture], [Sampling.LINEAR], backgroundUniforms);
	}

	// The tree in drawing order and each kind's lists, again: after an add or a remove anywhere under the root.
	function rebuild():Void {
		order.resize(0);
		parentOf.resize(0);
		models.resize(0);
		modelAt.resize(0);
		treeLights.resize(0);
		treeLightAt.resize(0);
		flats.resize(0);
		flatAt.resize(0);
		emitters.resize(0);
		emitterAt.resize(0);
		owners.resize(0);
		ownerAt.resize(0);
		for (i in 0...root.childCount)
			list(root.getChild(i), -1);
		builtStructure = root.structure;
	}

	// node and what's under it into the order, after its parent at parent, each kind into its list (its class asked once here, not each walk).
	function list(node:Node3D, parent:Int):Void {
		var at = order.length;
		order.push(node);
		parentOf.push(parent);
		var model = Std.downcast(node, Model3D);
		if (model != null) {
			models.push(model);
			modelAt.push(at);
		} else if (Std.isOfType(node, Light3D)) {
			treeLights.push(cast node);
			treeLightAt.push(at);
		} else if (node.spriteKind != None) {
			node.attachSprites(this);
			if (node.spriteKind == Flat) {
				flats.push(node);
				flatAt.push(at);
			} else {
				emitters.push(node);
				emitterAt.push(at);
			}
		} else if (node.drawsOwn) {
			owners.push(node);
			ownerAt.push(at);
		}
		for (i in 0...node.childCount)
			list(node.getChild(i), at);
	}

	// The tree in drawing order, each node brought up to date from its parent; then the pass's kinds: picking the models, sprites, texts and
	// hit areas, gathering the casters and lights for shadows, or the models, lights, sprites, texts and emitters to draw. Hidden, a node and
	// everything under it draw nothing and aren't hit, but stay placed and still run (an emitter moves on).
	function walk():Void {
		if (builtStructure != root.structure)
			rebuild();
		var n = order.length;
		shown.resize(n);
		hittable.resize(n);
		moved.resize(n);
		frozen.resize(n);
		// The root's own transform places everything on the stage.
		var rootChanged = root.update(null, false);
		for (i in 0...n) {
			var node = order[i], p = parentOf[i];
			shown[i] = node.visible && (p < 0 ? root.visible : shown[p]);
			hittable[i] = shown[i] && node.pickable && (p < 0 ? root.pickable : hittable[p]);
			frozen[i] = node.paused || (p >= 0 ? frozen[p] : root.paused);
			moved[i] = node.update(p < 0 ? root.worldMatrix : order[p].worldMatrix, p < 0 ? rootChanged : moved[p]);
			if (node.environment != null) {
				if (foundEnvironment == null)
					foundEnvironment = node.environment;
				else if (node.environment != foundEnvironment)
					moreEnvironments = true;
			}
		}
		if (picking) {
			for (k in 0...models.length) {
				var model = models[k];
				if (hittable[modelAt[k]] && model.hitArea == null) {
					if (model.jointCount > 0)
						skinned.push(model);
					else
						pickModel(model);
				}
			}
			if (pickCamera != null)
				for (k in 0...flats.length)
					if (hittable[flatAt[k]] && flats[k].hitArea == null)
						pickBest = flats[k].pickSprites(sprites.part, pickRay, pickBest, pickHit);
			for (i in 0...n)
				if (hittable[i] && order[i].hitArea != null)
					pickHitArea(order[i]);
		} else {
			if (!gathering)
				for (k in 0...emitters.length) {
					var still = frozen[emitterAt[k]];
					if (shown[emitterAt[k]])
						emitters[k].visitSprites(sprites.part, planes, eyeX, eyeY, eyeZ, forwardX, forwardY, forwardZ, still);
					else if (!still)
						emitters[k].advanceSprites(sprites.part);
				}
			for (k in 0...treeLights.length)
				if (shown[treeLightAt[k]] && lights.length < GATHERED_LIGHTS)
					lights.push(treeLights[k]);
			for (k in 0...models.length) {
				var model = models[k];
				if (!shown[modelAt[k]])
					continue;
				if (model.jointCount > 0)
					skinned.push(model);
				else if (gathering)
					gatherCaster(model);
				else
					visitModel(model);
			}
			if (!gathering)
				for (k in 0...flats.length)
					if (shown[flatAt[k]])
						flats[k].visitSprites(sprites.part, planes, eyeX, eyeY, eyeZ, forwardX, forwardY, forwardZ, false);
		}
		// Skinned models after the others, every joint where this frame has it: their boxes are their joints'.
		for (node in skinned)
			if (picking)
				pickModel(node);
			else if (gathering)
				gatherCaster(node);
			else
				visitModel(node);
		skinned.resize(0);
	}

	// A part whose mesh follows the joints its model is bound to (a skinned mesh not bound draws as bound, still).
	static inline function isSkinned(node:Model3D, mesh:Mesh3D):Bool
		return node.jointCount > 0 && mesh.skinned;

	// The six planes of m's view (Gribb and Hartmann), each ax + by + cz + d >= 0 inside, into out.
	static function planesOf(m:Mat4, out:Vector<Float>):Void
		for (p in 0...6) {
			var row = Std.int(p / 2), sign = p % 2 == 0 ? 1. : -1.;
			for (c in 0...4)
				out[p * 4 + c] = m.get(c * 4 + 3) + sign * m.get(c * 4 + row);
			var length = Math.sqrt(out[p * 4] * out[p * 4] + out[p * 4 + 1] * out[p * 4 + 1] + out[p * 4 + 2] * out[p * 4 + 2]);
			if (length > 0)
				for (c in 0...4)
					out[p * 4 + c] /= length;
		}

	// Whether the box centered at c reaching r along each world axis is at least partly inside planes.
	static function inside(planes:Vector<Float>, cx:Float, cy:Float, cz:Float, rx:Float, ry:Float, rz:Float):Bool {
		for (p in 0...6) {
			var a = planes[p * 4],
				b = planes[p * 4 + 1],
				c = planes[p * 4 + 2];
			if (a * (cx + (a >= 0 ? rx : -rx)) + b * (cy + (b >= 0 ? ry : -ry)) + c * (cz + (c >= 0 ? rz : -rz)) + planes[p * 4 + 3] < 0)
				return false;
		}
		return true;
	}

	// A model's box in the world, into boxX..boxRZ: its mesh's box's center moved, each world axis's reach the absolute matrix times the half
	// extents.
	var boxX = 0.;
	var boxY = 0.;
	var boxZ = 0.;
	var boxRX = 0.;
	var boxRY = 0.;
	var boxRZ = 0.;

	function placeBox(node:Model3D, mesh:Mesh3D):Void {
		if (isSkinned(node, mesh) && JointPalette3D.computePosedBox(node, mesh, posed)) {
			boxX = posed[0];
			boxY = posed[1];
			boxZ = posed[2];
			boxRX = posed[3];
			boxRY = posed[4];
			boxRZ = posed[5];
			return;
		}
		var w = node.worldMatrix;
		var hx = (mesh.maxX - mesh.minX) / 2,
			hy = (mesh.maxY - mesh.minY) / 2,
			hz = (mesh.maxZ - mesh.minZ) / 2;
		var mx = (mesh.maxX + mesh.minX) / 2,
			my = (mesh.maxY + mesh.minY) / 2,
			mz = (mesh.maxZ + mesh.minZ) / 2;
		boxX = w.get(0) * mx + w.get(4) * my + w.get(8) * mz + w.get(12);
		boxY = w.get(1) * mx + w.get(5) * my + w.get(9) * mz + w.get(13);
		boxZ = w.get(2) * mx + w.get(6) * my + w.get(10) * mz + w.get(14);
		boxRX = Math.abs(w.get(0)) * hx + Math.abs(w.get(4)) * hy + Math.abs(w.get(8)) * hz;
		boxRY = Math.abs(w.get(1)) * hx + Math.abs(w.get(5)) * hy + Math.abs(w.get(9)) * hz;
		boxRZ = Math.abs(w.get(2)) * hx + Math.abs(w.get(6)) * hy + Math.abs(w.get(10)) * hz;
	}

	// A model's parts that cast, in view or not (see-through ones don't).
	function gatherCaster(node:Model3D):Void {
		if (!node.shadowCasting || Color.getAlpha(node.tint) < 255)
			return;
		for (i in 0...node.partCount) {
			var part = node.getPart(i), mesh = part.mesh;
			if (mesh != null && !part.material.blended)
				gatherPart(node, mesh, part.material);
		}
	}

	function gatherPart(node:Model3D, mesh:Mesh3D, material:Material3D):Void {
		placeBox(node, mesh);
		if (casterCount == casters.length)
			casters.push(new Caster());
		var c = casters[casterCount++];
		c.node = node;
		c.mesh = mesh;
		c.material = material;
		c.skinned = isSkinned(node, mesh);
		// A surface shader with a vertex hook or a discard draws its own shadow (Shader.caster); another's is the framework's.
		var shader = material.shader;
		c.program = shader == null ? null : c.skinned ? shader.skinned.caster : shader.caster;
		c.cx = boxX;
		c.cy = boxY;
		c.cz = boxZ;
		c.rx = boxRX;
		c.ry = boxRY;
		c.rz = boxRZ;
	}

	// A model's parts in view, each an item.
	function visitModel(node:Model3D):Void
		for (i in 0...node.partCount) {
			var part = node.getPart(i);
			if (part.mesh != null)
				visitPart(node, part.mesh, part.material);
		}

	function visitPart(node:Model3D, mesh:Mesh3D, material:Material3D):Void {
		var w = node.worldMatrix;
		placeBox(node, mesh);
		var cx = boxX, cy = boxY, cz = boxZ;
		if (!inside(planes, cx, cy, cz, boxRX, boxRY, boxRZ))
			return;
		if (count == items.length)
			items.push(new Item());
		var item = items[count];
		item.node = node;
		item.mesh = mesh;
		item.material = material;
		item.skinned = isSkinned(node, mesh);
		item.blended = item.material.blended || Color.getAlpha(node.tint) < 255;
		item.silhouetted = false;
		if (!item.blended)
			for (k in 0...node.passCount) {
				var pass = node.getPass(k);
				if (pass.enabled && pass.behind)
					item.silhouetted = true;
			}
		// A placement that mirrors (its matrix's determinant below 0) turns the triangles' winding over.
		item.mirrored = w.get(0) * (w.get(5) * w.get(10) - w.get(9) * w.get(6)) - w.get(4) * (w.get(1) * w.get(10) - w.get(9) * w.get(2))
			+ w.get(8) * (w.get(1) * w.get(6) - w.get(5) * w.get(2)) < 0;
		item.depth = (cx - eyeX) * forwardX + (cy - eyeY) * forwardY + (cz - eyeZ) * forwardZ;
		item.cx = cx;
		item.cy = cy;
		item.cz = cz;
		item.rx = boxRX;
		item.ry = boxRY;
		item.rz = boxRZ;
		item.order = count;
		count++;
	}

	static function compare(a:Item, b:Item):Int {
		if (a.blended != b.blended)
			return a.blended ? 1 : -1;
		if (a.blended)
			return a.depth > b.depth ? -1 : a.depth < b.depth ? 1 : a.order - b.order;
		if (a.silhouetted != b.silhouetted)
			return a.silhouetted ? 1 : -1;
		if (a.material.id != b.material.id)
			return a.material.id - b.material.id;
		if (a.mesh.id != b.mesh.id)
			return a.mesh.id - b.mesh.id;
		if (a.skinned != b.skinned)
			return a.skinned ? 1 : -1;
		if (a.mirrored != b.mirrored)
			return a.mirrored ? 1 : -1;
		return a.order - b.order;
	}

	static inline function alike(a:Item, b:Item):Bool
		return a.mesh == b.mesh && a.material == b.material && a.blended == b.blended && a.mirrored == b.mirrored && a.skinned == b.skinned
			&& a.silhouetted == b.silhouetted;

	// A model's record (Lit3DProgram's) at index in out: the world matrix's rows, the normals' matrix's rows (the inverse transpose's; the
	// first's w the tangents' handedness, the second's whether shadows fall on it, the third's a skinned model's first joint), its lights (the
	// table's entries, -1 past the last; none without lights) and its tint (linear).
	function writeInstance(out:Bytes, index:Int, node:Model3D, skinned:Bool, jointBase:Int, lights:Null<Array<Int>>):Void {
		var w = node.worldMatrix, r = inverse, at = index * Lit3DProgram.instanceStride;
		inverse.makeInverse(w);
		for (row in 0...3)
			for (col in 0...4)
				out.setFloat(at + Lit3DProgram.model0Offset + row * 16 + col * 4, w.get(col * 4 + row));
		// The w of the normals' first row: the tangents' handedness, -1 where the placement mirrors them.
		var mirrored = r.get(0) * (r.get(5) * r.get(10) - r.get(9) * r.get(6)) - r.get(4) * (r.get(1) * r.get(10) - r.get(9) * r.get(2))
			+ r.get(8) * (r.get(1) * r.get(6) - r.get(5) * r.get(2)) < 0;
		for (row in 0...3)
			for (col in 0...4)
				out.setFloat(at + Lit3DProgram.normal0Offset + row * 16 + col * 4,
					col < 3 ? r.get(row * 4 + col) : row == 0 ? (mirrored ? -1 : 1) : row == 1 ? (node.shadowReceiving ? 1 : 0) : skinned ? jointBase : 0);
		for (k in 0...MODEL_LIGHTS)
			out.setFloat(at + (k < 4 ? Lit3DProgram.lights0Offset + k * 4 : Lit3DProgram.lights1Offset + (k - 4) * 4), lights == null ? -1 : lights[k]);
		var tint = node.tint;
		out.setFloat(at + Lit3DProgram.tintOffset, linear(Color.getRed(tint)));
		out.setFloat(at + Lit3DProgram.tintOffset + 4, linear(Color.getGreen(tint)));
		out.setFloat(at + Lit3DProgram.tintOffset + 8, linear(Color.getBlue(tint)));
		out.setFloat(at + Lit3DProgram.tintOffset + 12, Color.getAlpha(tint) / 255);
	}

	// The table: the gathered lights that reach the drawn models most (each light's best score over them), at most TABLE_LIGHTS, in the order
	// found; then each model's own: the table's lights that reach it most, at most MODEL_LIGHTS, the nearest-reaching first. Each light's
	// constants are worked out once, each light and model scored once, and nothing is made per model (an insertion into fixed slots).
	function chooseLights():Void {
		var n = lights.length;
		prepareLights();
		if (itemScores.length < count * n)
			itemScores = new Vector<Float>(count * n * 2);
		for (l in 0...n)
			best[l] = 0;
		for (i in 0...count) {
			var item = drawn[i];
			for (l in 0...n) {
				var score = scoreLight(l, item);
				itemScores[i * n + l] = score;
				if (score > best[l])
					best[l] = score;
			}
		}
		// The table: the TABLE_LIGHTS best, kept in the order found.
		table.resize(0);
		for (l in 0...n) {
			tableOf[l] = -1;
			if (best[l] <= 0)
				continue;
			var better = 0;
			for (o in 0...n)
				if (best[o] > best[l] || best[o] == best[l] && o < l)
					better++;
			if (better < TABLE_LIGHTS) {
				tableOf[l] = table.length;
				table.push(lights[l]);
			}
		}
		for (i in 0...count) {
			var item = drawn[i], chosen = 0;
			for (l in 0...n) {
				var t = tableOf[l], score = itemScores[i * n + l];
				if (t < 0 || score <= 0)
					continue;
				// Into the descending list, ties in table order.
				var at = chosen;
				while (at > 0 && slotScores[at - 1] < score)
					at--;
				if (at >= MODEL_LIGHTS)
					continue;
				if (chosen < MODEL_LIGHTS)
					chosen++;
				var j = chosen - 1;
				while (j > at) {
					slotScores[j] = slotScores[j - 1];
					item.lights[j] = item.lights[j - 1];
					j--;
				}
				slotScores[at] = score;
				item.lights[at] = t;
			}
			for (k in chosen...MODEL_LIGHTS)
				item.lights[k] = -1;
		}
	}

	// Each gathered light's constants for scoring, once a draw: its brightness, place, range, kind, direction and cone.
	function prepareLights():Void {
		var n = lights.length;
		if (lightData.length < n * 10)
			lightData = new Vector<Float>(GATHERED_LIGHTS * 10);
		for (l in 0...n) {
			var light = lights[l], color = light.color, w = light.worldMatrix, at = l * 10;
			var point = Std.downcast(light, PointLight3D),
				spot = Std.downcast(light, SpotLight3D);
			lightData[at] = (.2126 * linear(Color.getRed(color)) + .7152 * linear(Color.getGreen(color)) +
				.0722 * linear(Color.getBlue(color))) * light.intensity;
			lightData[at + 1] = w.get(12);
			lightData[at + 2] = w.get(13);
			lightData[at + 3] = w.get(14);
			lightData[at + 4] = point != null ? point.range : spot != null ? spot.range : 0;
			lightData[at + 5] = spot != null ? 2 : point != null ? 1 : 0;
			var dx = -w.get(8),
				dy = -w.get(9),
				dz = -w.get(10),
				dl = Math.sqrt(dx * dx + dy * dy + dz * dz);
			lightData[at + 6] = dl > 0 ? dx / dl : 0;
			lightData[at + 7] = dl > 0 ? dy / dl : -1;
			lightData[at + 8] = dl > 0 ? dz / dl : 0;
			lightData[at + 9] = 0;
			cones[l * 2] = Math.cos(spot != null ? spot.innerCone : 0);
			cones[l * 2 + 1] = Math.cos(spot != null ? spot.outerCone : 0);
		}
	}

	// How much gathered light l reaches item's box, an estimate: its brightness, through its falloff at the box's nearest point and its
	// cone at the box's center; 0 for one that can't reach it.
	function scoreLight(l:Int, item:Item):Float {
		var at = l * 10, score = lightData[at];
		if (score <= 0 || lightData[at + 5] == 0)
			return score;
		var px = lightData[at + 1],
			py = lightData[at + 2],
			pz = lightData[at + 3],
			range = lightData[at + 4];
		var nx = Math.max(item.cx - item.rx, Math.min(px, item.cx + item.rx)) - px,
			ny = Math.max(item.cy - item.ry, Math.min(py, item.cy + item.ry)) - py,
			nz = Math.max(item.cz - item.rz, Math.min(pz, item.cz + item.rz)) - pz;
		var d2 = nx * nx + ny * ny + nz * nz;
		if (range > 0 && d2 >= range * range)
			return 0;
		// The shader's falloff: inverse square (from 0.1 out), windowed to nothing at the range.
		score /= Math.max(d2, .01);
		if (range > 0) {
			var q2 = d2 / (range * range),
				window = Math.max(0, Math.min(1, 1 - q2 * q2));
			score *= window * window;
		}
		if (lightData[at + 5] == 2) {
			var tx = item.cx - px,
				ty = item.cy - py,
				tz = item.cz - pz,
				tl = Math.sqrt(tx * tx + ty * ty + tz * tz);
			// Inside a box the light's in, its cone can't miss it.
			if (tl > 1e-6 && (Math.abs(tx) > item.rx || Math.abs(ty) > item.ry || Math.abs(tz) > item.rz)) {
				var c = (tx * lightData[at + 6] + ty * lightData[at + 7] + tz * lightData[at + 8]) / tl,
					inner = cones[l * 2],
					outer = cones[l * 2 + 1];
				score *= inner - outer <= 1e-6 ? (c >= outer ? 1 : 0) : smooth(outer, inner, c);
			}
		}
		return score;
	}

	static inline function smooth(edge0:Float, edge1:Float, x:Float):Float {
		var t = Math.max(0, Math.min(1, (x - edge0) / (edge1 - edge0)));
		return t * t * (3 - 2 * t);
	}

	// The fragment uniforms the whole draw shares: the camera, the ambient light, the lights and their shadows (the material is a run's).
	function writeScene():Void {
		var u = fragmentUniforms;
		u.setFloat(0, eyeX);
		u.setFloat(4, eyeY);
		u.setFloat(8, eyeZ);
		u.setFloat(12, 0);
		u.setFloat(16, linear(Color.getRed(ambientColor)) * ambientIntensity);
		u.setFloat(20, linear(Color.getGreen(ambientColor)) * ambientIntensity);
		u.setFloat(24, linear(Color.getBlue(ambientColor)) * ambientIntensity);
		u.setFloat(28, 0);
		for (i in 0...TABLE_LIGHTS) {
			var position = LIGHT_POSITION + i * 16,
				direction = LIGHT_DIRECTION + i * 16,
				radiance = LIGHT_RADIANCE + i * 16,
				cone = LIGHT_SPOT + i * 16;
			if (i >= table.length) {
				for (k in 0...4) {
					u.setFloat(position + k * 4, 0);
					u.setFloat(direction + k * 4, 0);
					u.setFloat(radiance + k * 4, 0);
					u.setFloat(cone + k * 4, k == 2 ? -1 : 0);
				}
				continue;
			}
			var light = table[i],
				w = light.worldMatrix,
				point = Std.downcast(light, PointLight3D),
				spot = Std.downcast(light, SpotLight3D);
			var dx = -w.get(8),
				dy = -w.get(9),
				dz = -w.get(10),
				dl = Math.sqrt(dx * dx + dy * dy + dz * dz);
			u.setFloat(position, w.get(12));
			u.setFloat(position + 4, w.get(13));
			u.setFloat(position + 8, w.get(14));
			u.setFloat(position + 12, point != null ? point.range : spot != null ? spot.range : 0);
			u.setFloat(direction, dl > 0 ? dx / dl : 0);
			u.setFloat(direction + 4, dl > 0 ? dy / dl : -1);
			u.setFloat(direction + 8, dl > 0 ? dz / dl : 0);
			u.setFloat(direction + 12, spot != null ? 2 : point != null ? 1 : 0);
			u.setFloat(cone, Math.cos(spot != null ? spot.innerCone : 0));
			u.setFloat(cone + 4, Math.cos(spot != null ? spot.outerCone : 0));
			// Its shadow slot: its layer of the map the last drawShadows made, or -1.
			u.setFloat(cone + 8, shadowLights.indexOf(light));
			u.setFloat(cone + 12, 0);
			var color = light.color, intensity = light.intensity;
			u.setFloat(radiance, linear(Color.getRed(color)) * intensity);
			u.setFloat(radiance + 4, linear(Color.getGreen(color)) * intensity);
			u.setFloat(radiance + 8, linear(Color.getBlue(color)) * intensity);
			u.setFloat(radiance + 12, 0);
		}
		// Each shadow layer: its matrix, then params, extra and tint (each four floats a layer).
		for (layer in 0...SHADOW_LIGHTS) {
			var at = layer * LAYER_FLOATS;
			for (k in 0...16)
				u.setFloat(SHADOW_MATRIX + layer * 64 + k * 4, layer < shadowLights.length ? shadowLayers[at + k] : 0);
			for (k in 0...12)
				u.setFloat(SHADOW_PARAMS + Std.int(k / 4) * SHADOW_LIGHTS * 16 + layer * 16 + (k % 4) * 4,
					layer < shadowLights.length ? shadowLayers[at + 16 + k] : 0);
			for (k in 0...4)
				u.setFloat(SHADOW_TINT + layer * 16 + k * 4, layer < shadowLights.length ? shadowLayers[at + 24 + k] : 0);
		}
		// Tone mapping, then the environment: its intensity (0 for none), last mip, rotation, and irradiance.
		u.setFloat(TONEMAP, tonemap);
		u.setFloat(TONEMAP + 4, Math.pow(2, exposure));
		u.setFloat(TONEMAP + 8, hdr ? 1 : 0);
		u.setFloat(TONEMAP + 12, 0);
		u.setFloat(ENVIRONMENT, environment != null ? environmentIntensity : 0);
		u.setFloat(ENVIRONMENT + 4, EnvironmentBake3D.MIP_COUNT - 1);
		u.setFloat(ENVIRONMENT + 8, Math.cos(environmentRotation));
		u.setFloat(ENVIRONMENT + 12, Math.sin(environmentRotation));
		var irradiance = environment != null ? environment.irradiance : null;
		for (k in 0...9)
			for (c in 0...4)
				u.setFloat(IRRADIANCE + k * 16 + c * 4, irradiance != null && c < 3 ? irradiance[k * 3 + c] : 0);
		if (environment != null && brdf == null)
			brdf = Texture2D.fromRgba(EnvironmentBake3D.BRDF_SIZE, EnvironmentBake3D.BRDF_SIZE, EnvironmentBake3D.brdfTable, Linear, gpu);
	}

	// The material's part of the fragment uniforms in u (lit3d_fs_members' from MATERIAL): its base color, metallic, roughness and whether lit,
	// its emission and the normal map's strength, its hit flash (as much as shows at the stage's time) and its rim light.
	function writeMaterial(material:Material3D, u:Bytes):Void {
		var color = material.baseColor;
		u.setFloat(MATERIAL, linear(Color.getRed(color)));
		u.setFloat(MATERIAL + 4, linear(Color.getGreen(color)));
		u.setFloat(MATERIAL + 8, linear(Color.getBlue(color)));
		u.setFloat(MATERIAL + 12, Color.getAlpha(color) / 255);
		u.setFloat(MATERIAL + 16, material.metallic);
		u.setFloat(MATERIAL + 20, material.roughness);
		u.setFloat(MATERIAL + 24, material.lit ? 1 : 0);
		u.setFloat(MATERIAL + 28, 0);
		var emissive = material.emissive, strength = material.emissiveStrength;
		u.setFloat(MATERIAL + 32, linear(Color.getRed(emissive)) * strength);
		u.setFloat(MATERIAL + 36, linear(Color.getGreen(emissive)) * strength);
		u.setFloat(MATERIAL + 40, linear(Color.getBlue(emissive)) * strength);
		u.setFloat(MATERIAL + 44, material.normalTexture == null ? 0 : material.normalScale);
		var flash = material.flashColor;
		u.setFloat(MATERIAL + 48, linear(Color.getRed(flash)));
		u.setFloat(MATERIAL + 52, linear(Color.getGreen(flash)));
		u.setFloat(MATERIAL + 56, linear(Color.getBlue(flash)));
		u.setFloat(MATERIAL + 60, material.flashAt(time) * Color.getAlpha(flash) / 255);
		var rim = material.rimColor, strength = Color.getAlpha(rim) / 255;
		u.setFloat(MATERIAL + 64, linear(Color.getRed(rim)) * strength);
		u.setFloat(MATERIAL + 68, linear(Color.getGreen(rim)) * strength);
		u.setFloat(MATERIAL + 72, linear(Color.getBlue(rim)) * strength);
		u.setFloat(MATERIAL + 76, material.rimPower);
	}

	// A surface shader program's textures and their samplings by slot: the material's base color and normal map, shadows (the stage's maps, or
	// a stand-in), the environment and the BRDF table, the joints (its skinned variants'), then its own (white where unset).
	function surfaceTextures(program:helix.graphics.Shader, material:Material3D, shadows:Int):{textures:Array<Int>, samplings:Array<Sampling>} {
		var base = material.texture != null ? material.texture : white, normal = material.normalTexture != null ? material.normalTexture : flat,
			own = material.shaderParameters.textureSlots, textures = [], samplings = [];
		for (slot in program.textureSlots) {
			while (textures.length < slot) {
				textures.push(0);
				samplings.push(Sampling.NEAREST);
			}
			switch slot {
				case 2:
					textures.push(shadows);
					samplings.push(Sampling.NEAREST);
				case 3:
					textures.push(environment != null ? environment.lightingTexture : noEnvironment);
					samplings.push(Sampling.LINEAR);
				case 4:
					textures.push(brdf != null ? brdf.handle : white.handle);
					samplings.push(Sampling.LINEAR);
				case 5:
					textures.push(palette.texture);
					samplings.push(Sampling.NEAREST);
				case _:
					var texture = slot == 0 ? base : slot == 1 ? normal : own.exists(slot) ? own[slot] : white;
					textures.push(texture.handle);
					samplings.push(texture.sampling);
			}
		}
		return {textures: textures, samplings: samplings};
	}

	// A surface shader program's uniform blocks: the stage's (vertex, a view-projection's 64 bytes, then the time; the fragment uniforms, then
	// the time), and the material's own values in its own blocks.
	function surfaceBlocks(program:helix.graphics.Shader, material:Material3D, vertex:Bytes):Array<Null<Bytes>> {
		var blocks = [for (size in program.blockSizes) size > 0 ? Bytes.alloc(size) : null],
			u = fragmentUniforms;
		if (blocks.length > 0 && blocks[0] != null) {
			blocks[0].blit(0, vertex, 0, 64);
			blocks[0].setFloat(64, time);
		}
		if (blocks.length > 1 && blocks[1] != null) {
			blocks[1].blit(0, u, 0, u.length);
			blocks[1].setFloat(u.length, time);
		}
		material.shaderParameters.write(blocks);
		return blocks;
	}

	// A run of alike models: the material's uniforms, then one instanced draw: through the lit program (skinned or not), or the material's
	// surface shader (its skinned variant for a skinned model).
	function drawRun(first:Int, runCount:Int):Void {
		var item = drawn[first],
			material = item.material,
			u = fragmentUniforms;
		writeMaterial(material, u);
		var shader = material.shader,
			shadows = shadowLights.length > 0 ? shadowMap : noShadows,
			mesh = item.mesh;
		if (shader != null) {
			var program = item.skinned ? shader.skinned : shader,
				bound = surfaceTextures(program, material, shadows);
			gpu.draw(pipelines.surface(program.handle, blendOf(item), material.doubleSided, item.mirrored, item.skinned),
				meshBuffers(mesh, instanceBuffer, item.skinned), mesh.getIndexBuffer(gpu), 0, mesh.indexCount, first, runCount, bound.textures,
				bound.samplings, surfaceBlocks(program, material, vertexUniforms));
			draws++;
			return;
		}
		var base = material.texture != null ? material.texture : white,
			normal = material.normalTexture != null ? material.normalTexture : flat,
			cube = environment != null ? environment.lightingTexture : noEnvironment,
			table = brdf != null ? brdf.handle : white.handle;
		var textures = [base.handle, normal.handle, shadows, cube, table], samplings = [
			base.sampling,
			normal.sampling,
			Sampling.NEAREST,
			Sampling.LINEAR,
			Sampling.LINEAR
		];
		// A skinned model draws through the skinned program, its joints from the palette.
		if (item.skinned) {
			textures.push(palette.texture);
			samplings.push(Sampling.NEAREST);
		}
		var pipeline = item.skinned ? pipelines.skinned3D(blendOf(item), material.doubleSided,
			item.mirrored) : pipelines.lit3D(blendOf(item), material.doubleSided, item.mirrored);
		gpu.draw(pipeline, meshBuffers(mesh, instanceBuffer, item.skinned), mesh.getIndexBuffer(gpu), 0, mesh.indexCount, first, runCount, textures,
			samplings, [vertexUniforms, u]);
		draws++;
	}

	// How item's colors meet what's behind: blended (see-through) or opaque.
	static inline function blendOf(item:Item):helix.graphics.BlendMode
		return item.blended ? Alpha : Opaque;

	/** Frees the stage's own GPU objects (its instance buffers, shadow maps, BRDF table and stand-in textures); meshes, textures and
		environments are their owners' to free, and the pipelines the GPU's (Pipelines). */
	function destroy():Void {
		if (sprites != null)
			sprites.destroy();
		sprites = null;
		builtStructure = -1;
		if (ownBatchDestroy != null)
			ownBatchDestroy();
		ownBatch = null;
		ownBatchDestroy = null;
		gpu.destroyBuffer(instanceBuffer);
		gpu.destroyBuffer(casterBuffer);
		gpu.destroyBuffer(skinnedCasterBuffer);
		gpu.destroyBuffer(shadedCasterBuffer);
		palette.destroy();
		pickPalette.destroy();
		gpu.destroyTexture(noShadows);
		if (shadowMap != 0)
			gpu.destroyTexture(shadowMap);
		white.destroy(gpu);
		flat.destroy(gpu);
		gpu.destroyTexture(noEnvironment);
		if (brdf != null)
			brdf.destroy(gpu);
	}
}

/** A model's part in view this draw. Pooled. */
private class Item {
	/** The model. */
	public var node:Model3D;

	/** Its part's mesh. */
	public var mesh:Mesh3D;

	/** Its part's material. */
	public var material:Material3D;

	/** Whether it is see-through (its material's or its tint's alpha). */
	public var blended = false;

	/** Whether its placement mirrors it, so its front faces wind clockwise. */
	public var mirrored = false;

	/** Whether it's opaque and its model has a silhouette (ModelPass3D behind): drawn after the silhouettes, so its own parts never hide it. */
	public var silhouetted = false;

	/** Whether it follows joints (Renderer3D.isSkinned). */
	public var skinned = false;

	/** Its first joint in the palette, when skinned. */
	public var jointBase = 0;

	/** Its box's center's distance along the camera's view. */
	public var depth = 0.;

	/** Its place in the walk: ties keep it. */
	public var order = 0;

	/** Its box in the world: its center. */
	public var cx = 0.;

	/** Its box's center, y. */
	public var cy = 0.;

	/** Its box's center, z. */
	public var cz = 0.;

	/** Its box's reach along x from its center. */
	public var rx = 0.;

	/** Its box's reach along y. */
	public var ry = 0.;

	/** Its box's reach along z. */
	public var rz = 0.;

	/** The table entries of the lights lighting it, the nearest-reaching first, -1 past the last. */
	public var lights = [for (_ in 0...8) -1];

	/** An empty item, filled by the walk. */
	public function new() {}
}

/** One of a model's passes (ModelPass3D) in a draw: its item's place in the draw, and the pass. Pooled. */
private class PassDraw {
	/** Its item's place in the draw (and its record's in the instance buffer). */
	public var item = 0;

	/** The pass. */
	public var pass:ModelPass3D;

	/** An empty one, filled by the draw. */
	public function new() {}
}

/** A model's part that casts shadows, gathered by drawShadows. Pooled. */
private class Caster {
	/** The model. */
	public var node:Model3D;

	/** Its part's mesh. */
	public var mesh:Mesh3D;

	/** Its part's material. */
	public var material:Material3D;

	/** The program drawing its shadow: its material's surface shader's caster (Shader.caster, its skinned variant's for a skinned part); null
		for the framework's. */
	public var program:Null<helix.graphics.Shader>;

	/** Whether it follows joints. */
	public var skinned = false;

	/** Its first joint in the palette, when skinned. */
	public var jointBase = 0;

	/** Its box's center in the world, x. */
	public var cx = 0.;

	/** Its box's center, y. */
	public var cy = 0.;

	/** Its box's center, z. */
	public var cz = 0.;

	/** Its box's reach along world x. */
	public var rx = 0.;

	/** Its box's reach along world y. */
	public var ry = 0.;

	/** Its box's reach along world z. */
	public var rz = 0.;

	/** An empty caster, filled by the walk. */
	public function new() {}
}

/** What a renderer calls on its sprites (Sprites3D), made by Sprites3D.attach: the part itself, handed to the kinds' hooks, and its calls,
	through the object, so a hot reload reaches the new code. */
private typedef SpriteCalls = {
	final part:Any;
	final begin:(dt:Float, time:Float) -> Void;
	final prepare:(viewProjection:Mat4, camera:Camera3D, forwardX:Float, forwardY:Float, forwardZ:Float) -> Void;
	final preparePick:Camera3D->Void;
	final drawOpaque:Void->Void;
	final drawBlendedBeyond:Float->Void;
	final drawRest:Void->Void;
	final drawnSpriteCount:Void->Int;
	final drawCallCount:Void->Int;
	final destroy:Void->Void;
}
