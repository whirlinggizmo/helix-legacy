import Render2DTests.CountingGraphics;
import haxe.io.Bytes;
import helix.asset.Assets;
import helix.asset.IAssets;
import helix.asset.AssetCacheMode;
import helix.asset.AssetProgress;
import helix.asset.EnsureOptions;
import helix.behavior.Behavior;
import helix.behavior.BehaviorPass;
import helix.graphics.Graphics;
import helix.graphics.IImageDecoder;
import helix.graphics.ImageDecoding;
import helix.graphics.ImageDecoding.ImageDecodeResult;
import helix.font.FontCache;
import helix.font.Fonts;
import helix.texture.TextureCache;
import helix.texture.Textures;
import helix.render3d.Camera3D;
import helix.render3d.DirectionalLight3D;
import helix.render3d.EnvironmentCache3D;
import helix.render3d.Environments3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.ModelCache3D;
import helix.render3d.Models3D;
import helix.render3d.Node3D;
import helix.render3d.Particles3D;
import helix.render3d.PointLight3D;
import helix.render3d.SpotLight3D;
import helix.render3d.Sprite3D;
import helix.render3d.Renderer3D;
import helix.render3d.Text3D;
import helix.scene.SceneFile3D;
import helix.scene.SceneFileCache3D;
import helix.scene.SceneFiles3D;
import helix.scene.SceneInstance3D;
import helix.scene.SceneKinds3D;
import helix.scene.SceneMaterial3D;
import helix.scene.KindSchema;
import helix.scene.SceneSchema3D;
import helix.scene.SceneValue;

/** A .scene3d file instantiated (helix.scene.SceneFile3D.instantiate, SceneInstance3D) and captured back (SceneFile3D.capture): the cache
	(SceneFileCache3D) sharing loads and remembering refusals; the round-trip sample onto a test stage, every node at its path with its
	transform, flags and properties, a prefab served by the test's assets with its override applied, a behavior made from the registry with
	every prop type and a reference resolved by name and by path, what's missing or unknown logged and the rest made, ready after the
	prefab lands; a prefab turning a flag back on, adding children and behaviors, one naming itself refused; a model file's nodes under
	their entry with its properties and an override by path; the live side of every kind's table (SceneKinds3D) applying and reading back;
	capture of an untouched instance byte-equal, and changes as overrides; generated meshes made, captured byte-equal, and one made in code
	captured as a mesh entry; and destroy taking everything out. */
@:access(helix)
class SceneInstanceTests {
	static var checks = 0;
	static var log:Array<String> = [];
	// The loads the test's assets hold, by path, and how often each was asked for.
	public static var held:Map<String, {loaded:Bytes->Void, failed:String->Void}> = [];
	public static var asked:Map<String, Int> = [];
	static var gpu:CountingGraphics;
	static var decoding:ImageDecoding;
	static var sceneFiles:SceneFileCache3D;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float):Bool
		return Math.abs(a - b) < 1e-6;

	// Whether the log holds a line with every piece of text, and clears that line.
	static function logged(pieces:Array<String>):Bool {
		for (line in log) {
			var all = true;
			for (piece in pieces)
				if (line.indexOf(piece) < 0)
					all = false;
			if (all) {
				log.remove(line);
				return true;
			}
		}
		return false;
	}

	static function release(path:String, bytes:Bytes):Void {
		var load = held[path];
		held.remove(path);
		load.loaded(bytes);
	}

	static function refuse(path:String, message:String):Void {
		var load = held[path];
		held.remove(path);
		load.failed(message);
	}

	static function parse(text:String, path:String):SceneFile3D {
		var file = SceneFile3D.parse(Bytes.ofString(text), path);
		if (file == null)
			throw 'The test\'s file $path doesn\'t parse: $log';
		return file;
	}

	static function same(a:Null<SceneValue>, b:SceneValue):Bool {
		if (a == null)
			return false;
		return switch [a, b] {
			case [Numbers(x), Numbers(y)]: x.length == y.length && [for (i in 0...x.length) x[i] == y[i]].indexOf(false) < 0;
			case [Number(x), Number(y)]: near(x, y);
			case _: a.equals(b);
		}
	}

	// A new stage and pass, the log cleared.
	static function fresh():{stage:Renderer3D, pass:BehaviorPass} {
		log = [];
		return {stage: new Renderer3D(gpu), pass: new BehaviorPass()};
	}

	static function main():Void {
		haxe.Log.trace = (v, ?pos) -> log.push(Std.string(v));
		// The services the file loads through, bound as the runner would, over assets the test answers.
		gpu = new CountingGraphics();
		var assets = new Held();
		decoding = new ImageDecoding(new StubDecoder());
		var textures = new TextureCache(assets, decoding, gpu);
		sceneFiles = new SceneFileCache3D(assets);
		@:privateAccess Graphics.bind(gpu);
		@:privateAccess Assets.bind(assets);
		@:privateAccess Textures.bind(textures);
		@:privateAccess Fonts.bind(new FontCache(assets, gpu));
		@:privateAccess Models3D.bind(new ModelCache3D(assets, textures));
		@:privateAccess Environments3D.bind(new EnvironmentCache3D(assets, decoding, gpu));
		@:privateAccess SceneFiles3D.bind(sceneFiles);
		cache();
		sample();
		prefabs();
		modelFile();
		kinds();
		flagsAndCameras();
		meshes();
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}

	// The cache: one load shared, a parsed file kept, a refusal remembered until forgotten, shutdown cancelling.
	static function cache():Void {
		var got = [], failed = [];
		sceneFiles.load("a.scene3d", f -> got.push(f), m -> failed.push(m));
		sceneFiles.load("a.scene3d", f -> got.push(f), m -> failed.push(m));
		check(asked["a.scene3d"] == 1 && sceneFiles.isLoading("a.scene3d") && sceneFiles.loadingCount == 1 && !sceneFiles.isLoaded("a.scene3d"),
			"Two loads of a file ask for it once");
		release("a.scene3d", Bytes.ofString('{"helix-scene3d": 1, "nodes": [{"kind": "Node3D", "name": "g"}]}'));
		check(got.length == 2 && got[0] == got[1] && got[0].path == "a.scene3d" && got[0].nodes[0].name == "g",
			"and both get the one file, parsed under its path");
		check(sceneFiles.isLoaded("a.scene3d")
			&& sceneFiles.find("a.scene3d") == got[0]
			&& !sceneFiles.isLoading("a.scene3d"), "which is kept");
		sceneFiles.load("a.scene3d", f -> got.push(f));
		check(got.length == 3 && asked["a.scene3d"] == 1, "A later load has it at once");
		sceneFiles.load("bad.scene3d", f -> got.push(f), m -> failed.push(m));
		release("bad.scene3d", Bytes.ofString('{"helix-scene3d": 1, "nodes": [{"kind": "Blob", "name": "g"}]}'));
		check(failed.length == 1 && failed[0].indexOf("bad.scene3d") >= 0 && logged(["bad.scene3d", "unknown kind"]),
			"A refused file fails with its reason, its problems logged");
		sceneFiles.load("bad.scene3d", f -> got.push(f), m -> failed.push(m));
		check(failed.length == 2 && asked["bad.scene3d"] == 1, "The refusal is remembered");
		sceneFiles.forget("bad.scene3d");
		sceneFiles.load("bad.scene3d", f -> got.push(f), m -> failed.push(m));
		check(asked["bad.scene3d"] == 2, "until forgotten");
		refuse("bad.scene3d", "not found");
		check(failed.length == 3 && failed[2].indexOf("not found") >= 0, "A load that fails fails the callers");
		sceneFiles.load("gone.scene3d", f -> got.push(f));
		check(logged(["gone.scene3d", "not found"]) == false, "Nothing logged yet");
		refuse("gone.scene3d", "not found");
		check(logged(["gone.scene3d", "not found"]), "A failure with no failed lambda is logged with the path");
		var told = false;
		sceneFiles.load("never.scene3d", f -> told = true, m -> told = true);
		sceneFiles.shutdown();
		check(!told && !sceneFiles.isLoading("never.scene3d") && !held.exists("never.scene3d") && !sceneFiles.isLoaded("a.scene3d"),
			"Shutting down cancels loads, telling no one, and forgets files");
		sceneFiles = new SceneFileCache3D(new Held());
		@:privateAccess SceneFiles3D.bind(sceneFiles);
	}

	static final SAMPLE = '{
		"helix-scene3d": 1,
		"environment": {
			"ambient": {"color": "#ffffff", "intensity": 0.25},
			"map": {"file": "sky/sky.hdr", "intensity": 0.7, "rotation": 0},
			"background": {"file": "sky/sky.hdr", "blur": 0}
		},
		"nodes": [
			{"kind": "Node3D", "name": "world", "paused": true, "children": [
				{"kind": "DirectionalLight3D", "name": "sun", "rotation": [-0.6, 0.7, 0], "color": "#fff4e0", "intensity": 3.5,
					"shadowCasting": true, "shadowDistance": 35, "shadowMapSize": 1024, "shadowStrength": 0.8, "shadowColor": "#102040"},
				{"kind": "PointLight3D", "name": "lamp", "position": [1, 2, 3], "range": 10, "intensity": 2},
				{"kind": "SpotLight3D", "name": "spot", "range": 20, "innerCone": 0.2, "outerCone": 0.5, "shadowCasting": true},
				{"kind": "Camera3D", "name": "chase", "position": [0, 3, -8], "fovY": 0.9, "near": 0.5, "far": 500, "minAspect": 1.777778,
					"behaviors": [{"kind": "ChaseCamera", "props": {"target": "@car", "speed": 1.5, "label": "go", "on": false,
						"offset": [0, 1.5, -6], "tint": "#ff000080"}}]},
				{"kind": "Sprite3D", "name": "glow", "texture": "fx/glow.png", "tint": "#ffffff80", "regionX": 8, "regionY": 8,
					"regionWidth": 16, "regionHeight": 16, "spriteWidth": 2, "spriteHeight": 2, "pivotX": 0, "pivotY": 1,
					"facing": "upright", "alphaMode": "add", "alphaCutoff": 0.25, "pickable": false},
				{"kind": "Text3D", "name": "label", "text": "Start \\"here\\"\\n", "textSize": 0.8, "color": "#80ff80", "font": "fonts/ui.ttf",
					"pivotY": 0, "facing": "free"},
				{"kind": "Particles3D", "name": "dust", "position": [0, 0.1, 0], "visible": false},
				{"kind": "Model3D", "name": "track", "file": "track/track.glb", "scale": [2, 2, 2], "shadowReceiving": false, "overrides": {
					"road": {"shadowCasting": false, "visible": false, "pickable": true},
					"road/line": {"tint": "#808080", "position": [0, 0, 0], "material": {"baseColor": "#2040c0"}},
					"gates/gate_0": {"children": [{"kind": "Node3D", "name": "checkpoint", "position": [0, 2, 0],
						"behaviors": [{"kind": "Checkpoint", "props": {"index": 0}}]}], "behaviors": [{"kind": "Gate"}]}
				}},
				{"kind": "Model3D", "name": "cone_1", "file": "props/cone.glb", "position": [12, 0, -3], "tint": "#ff8800", "shadowCasting": false,
					"material": {"baseColor": "#ff8800", "metallic": 0.1, "roughness": 0.3, "texture": "props/cone.png",
						"normalTexture": "props/cone_n.png", "normalScale": 0.5, "emissive": "#ff0000", "emissiveStrength": 2, "doubleSided": true},
					"props": {"team": 2, "role": "obstacle", "path": [1, 2, 3], "hot": true, "color": "#ff0000", "leader": "@cone_1"}},
				{"scene": "prefabs/car.scene3d", "name": "car", "position": [0, 0.5, 12],
					"overrides": {"body": {"material": {"baseColor": "#2040c0"}}}, "behaviors": [{"kind": "Car", "props": {"topSpeed": 60}}]}
			]}
		]
	}';

	static final CAR = '{"helix-scene3d": 1, "environment": {"ambient": {"intensity": 1}}, "nodes": [
		{"kind": "Model3D", "name": "body", "children": [{"kind": "Node3D", "name": "wheel", "visible": false}]}]}';

	// The round-trip sample under a stage's root: every node at its path, the prefab landing, the behaviors, ready, and capture.
	static function sample():Void {
		var file = parse(SAMPLE, "levels/track.scene3d");
		var made = fresh(), stage = made.stage, pass = made.pass, readyCalls = 0;
		var instance = file.instantiate(stage.root, pass, () -> readyCalls++);
		check(instance.root.parent == stage.root && instance.root.name == "track" && instance.path == "levels/track.scene3d",
			"The instance's root is a group named after the file under the node it was given");
		var light = instance.root.environment;
		check(light != null && light.ambientColor == 0xffffffff && light.ambientIntensity == .25 && stage.ambientIntensity == 0,
			"The environment section is the root's environment, its ambient light at once; the stage untouched");
		check(held.exists("sky/sky.hdr") && asked["sky/sky.hdr"] == 1, "The environment and the background share one load");
		var world = instance.node("world");
		check(world != null && world.paused && world.visible && world.childCount == 10, "The root group, paused, with its ten children");
		var sun = Std.downcast(instance.node("world/sun"), DirectionalLight3D);
		check(sun != null && near(sun.rotationX, -.6) && near(sun.rotationY, .7) && near(sun.rotationZ, 0) && sun.color == 0xfffff4e0
			&& sun.intensity == 3.5 && sun.shadowCasting && sun.shadowDistance == 35 && sun.shadowMapSize == 1024 && sun.shadowStrength == .8
			&& sun.shadowColor == 0xff102040,
			"A directional light: its rotation and every property");
		var lamp = Std.downcast(instance.node("world/lamp"), PointLight3D);
		check(lamp != null && lamp.x == 1 && lamp.y == 2 && lamp.z == 3 && lamp.range == 10 && lamp.intensity == 2, "A point light at its position");
		var spot = Std.downcast(instance.node("world/spot"), SpotLight3D);
		check(spot != null && spot.range == 20 && near(spot.innerCone, .2) && near(spot.outerCone, .5) && spot.shadowCasting, "A spot's cones");
		var chase = Std.downcast(instance.node("world/chase"), Camera3D);
		check(chase != null && chase.y == 3 && chase.z == -8 && near(chase.fovY, .9) && chase.near == .5 && chase.far == 500
			&& near(chase.minAspect, 1.777778) && chase.projection == Perspective,
			"A camera's projection, perspective unsaid");
		var glow = Std.downcast(instance.node("world/glow"), Sprite3D);
		check(glow != null && glow.tint == 0x80ffffff && glow.regionX == 8 && glow.regionWidth == 16 && glow.spriteWidth == 2 && glow.pivotX == 0
			&& glow.pivotY == 1 && glow.facing == Upright && glow.alphaMode == Add && glow.alphaCutoff == .25 && !glow.pickable && held.exists("fx/glow.png"),
			"A sprite: region, size, pivot, facing, alpha, its flag, its texture asked for");
		var label = Std.downcast(instance.node("world/label"), Text3D);
		check(label != null && label.text == 'Start "here"\n' && label.textSize == .8 && label.color == 0xff80ff80 && label.pivotY == 0
			&& label.facing == Free && held.exists("fonts/ui.ttf"),
			"A text: its value, size, color, pivot, facing, its font asked for");
		var dust = Std.downcast(instance.node("world/dust"), Particles3D);
		check(dust != null && dust.emitter != null && !dust.visible && dust.y == .1, "Particles with an emitter, hidden, placed");
		var track = instance.node("world/track"),
			cone = instance.node("world/cone_1"),
			car = instance.node("world/car");
		check(track != null && Type.getClass(track) == Node3D && track.scaleX == 2 && track.childCount == 0 && held.exists("track/track.glb")
			&& cone != null && cone.x == 12 && held.exists("props/cone.glb") && car != null && car.y == .5 && held.exists("prefabs/car.scene3d"),
			"A file node and a prefab node are placeholders at their transforms while their files load");
		check(!instance.ready && readyCalls == 0 && instance.behaviors.length == 0 && pass.count == 0, "Nothing is ready or attached yet");
		var props = instance.props(cone);
		check(props != null
			&& same(props.get("team"), Number(2))
			&& same(props.get("leader"), Reference("cone_1")), "A node's props are kept by the instance");
		check(instance.props(sun) != null && !instance.props(sun).keys().hasNext() && instance.props(new Node3D()) == null,
			"A node without props has an empty map; a node not of the file none");
		check(instance.pathOf(lamp) == "world/lamp"
			&& instance.pathOf(instance.root) == null
			&& instance.pathOf(new Node3D()) == null
			&& instance.node("nope") == null,
			"Paths both ways");

		// The missing files: logged with the scene's path and the node's, the nodes left as they are.
		refuse("track/track.glb", "not found");
		refuse("props/cone.glb", "not found");
		refuse("sky/sky.hdr", "not found");
		check(logged(["levels/track.scene3d", "world/track", "track/track.glb", "not found"])
			&& logged(["levels/track.scene3d", "world/cone_1", "props/cone.glb", "not found"])
			&& logged(["levels/track.scene3d", "environment", "map", "sky/sky.hdr"])
			&& logged(["levels/track.scene3d", "environment", "background", "sky/sky.hdr"]),
			"A missing model and a missing environment are logged with the scene's path and the node's");
		check(track.childCount == 0 && !instance.ready, "A missing model leaves its node empty; the prefab is still awaited");

		// The prefab lands: made under its node, its override applied, its environment its node's; then everything is ready.
		release("prefabs/car.scene3d", Bytes.ofString(CAR));
		var body = Std.downcast(instance.node("world/car/body"), Model3D),
			wheel = instance.node("world/car/body/wheel");
		check(body != null && body.parent == car && wheel != null && !wheel.visible, "The prefab's nodes are under its node, as the prefab says");
		check(body.material != null
			&& body.material.baseColor == 0xff2040c0
			&& body.material.roughness == .5, "The override's material replaced the body's");
		check(car.environment != null && car.environment.ambientIntensity == 1 && light.ambientIntensity == .25,
			"A prefab's environment lights its own node, the level's left as it was");
		check(instance.ready && readyCalls == 0, "Ready once the prefab landed, the lambda not yet called");
		check(instance.behaviors.length == 2 && pass.count == 3, "The behaviors are attached to the pass (and the one that tells ready)");
		var chaser = Std.downcast(instance.behaviors[0], ChaseCamera),
			driver = Std.downcast(instance.behaviors[1], Car);
		check(chaser != null
			&& chaser.node == chase
			&& chaser.target == car
			&& chaser.speed == 1.5
			&& chaser.label == "go"
			&& !chaser.on
			&& chaser.offset.join(",") == "0,1.5,-6"
			&& chaser.tint == 0x80ff0000,
			"A behavior with every prop type, its reference resolved by name to the prefab node");
		check(driver != null && driver.node == car && driver.topSpeed == 60, "A behavior on the prefab node");
		pass.update(0);
		check(readyCalls == 1 && pass.count == 2 && chaser.started && driver.started, "ready comes at the pass's next update, after the behaviors started");
		pass.update(0);
		check(readyCalls == 1, "once");
		check(log.length == 0, 'Nothing else was logged: $log');

		// Capture of the untouched instance: the sample, minus what no file provided (the environment and the background never loaded, so
		// the environment keeps its defaults there).
		var expected = parse(SAMPLE, "levels/track.scene3d");
		expected.environment.mapFile = null;
		expected.environment.mapIntensity = null;
		expected.environment.rotation = null;
		expected.environment.backgroundFile = null;
		expected.environment.backgroundBlur = null;
		var captured = SceneFile3D.capture(instance).write().toString();
		check(captured == expected.write().toString(), 'An untouched instance captures as its file:\n$captured');

		// Changes: a property, a hidden file node, a behavior attached by the file to the prefab's node read back with its props.
		lamp.intensity = 5;
		car.visible = false;
		body.shadowCasting = false;
		wheel.visible = true;
		driver.topSpeed = 80;
		var again = SceneFile3D.capture(instance);
		var lampEntry = again.nodes[0].children[1],
			carEntry = again.nodes[0].children[9];
		check(same(lampEntry.properties.get("intensity"), Number(5)), "A changed property is captured");
		check(carEntry.visible == false && carEntry.scene == "prefabs/car.scene3d", "A hidden prefab node is captured hidden, as the reference");
		var bodyChange = carEntry.overrides.get("body"),
			wheelChange = carEntry.overrides.get("body/wheel");
		check(bodyChange != null
			&& same(bodyChange.properties.get("shadowCasting"), Flag(false))
			&& bodyChange.material != null
			&& bodyChange.material.baseColor == 0xff2040c0
			&& bodyChange.material.roughness == null,
			"A prefab node's changed property joins its override, the material saying only what differs");
		check(wheelChange != null && wheelChange.visible == true && wheelChange.position == null, "A flag turned back on is an override saying so");
		check(carEntry.behaviors.length == 1
			&& same(carEntry.behaviors[0].props.get("topSpeed"), Number(80)), "A behavior's prop as it is now");
		check(log.length == 0, 'Capture logged nothing: $log');

		// Destroy: the behaviors out of the pass, the root out of the node it was put in.
		instance.destroy();
		check(instance.root.parent == null && pass.count == 0 && chaser.stopped && driver.stopped, "destroy stops the behaviors and takes the root out");
		instance.destroy();
		check(pass.count == 0, "twice does nothing more");
	}

	static final MAIN = '{"helix-scene3d": 1, "nodes": [
		{"scene": "p/one.scene3d", "name": "one", "overrides": {
			"wheel": {"visible": true, "children": [{"kind": "PointLight3D", "name": "bulb", "behaviors": [{"kind": "Gate"}]}],
				"behaviors": [{"kind": "Checkpoint", "props": {"index": 3}}]},
			"wheel/hub": {"position": [1, 0, 0]},
			"nope/path": {"visible": false}}},
		{"scene": "p/loop.scene3d", "name": "loop"},
		{"kind": "Node3D", "name": "g", "behaviors": [{"kind": "Nothing"},
			{"kind": "Checkpoint", "props": {"index": 1.5, "bogus": 1, "target": "@one/wheel"}}, {"kind": "Checkpoint", "props": {"target": 5}}]}
	]}';
	static final ONE = '{"helix-scene3d": 1, "nodes": [
		{"kind": "Node3D", "name": "wheel", "visible": false, "children": [{"kind": "Node3D", "name": "hub"}],
			"behaviors": [{"kind": "Gate"}, {"kind": "Checkpoint", "props": {"target": "@hub"}}]},
		{"scene": "p/two.scene3d", "name": "inner"}]}';
	static final TWO = '{"helix-scene3d": 1, "nodes": [{"kind": "Model3D", "name": "m"}, {"kind": "Node3D", "name": "hub"}]}';
	static final LOOP = '{"helix-scene3d": 1, "nodes": [{"scene": "p/loop.scene3d", "name": "again"}]}';

	// Prefabs: one nested in another, overrides turning a flag back on and adding children and behaviors, a self-naming one refused, an
	// unknown behavior and a bad prop logged, references by path and within a prefab, and capture of it all.
	static function prefabs():Void {
		sceneFiles.put("p/one.scene3d", parse(ONE, "p/one.scene3d"));
		sceneFiles.put("p/two.scene3d", parse(TWO, "p/two.scene3d"));
		sceneFiles.put("p/loop.scene3d", parse(LOOP, "p/loop.scene3d"));
		var file = parse(MAIN, "main.scene3d");
		var made = fresh(), stage = made.stage, pass = made.pass, readyCalls = 0;
		var instance = file.instantiate(stage.root, pass, () -> readyCalls++);
		check(instance.ready && readyCalls == 0, "With every prefab in the cache, ready at once, the lambda waiting for the pass");
		var wheel = instance.node("one/wheel"),
			hub = instance.node("one/wheel/hub"),
			bulb = instance.node("one/wheel/bulb"),
			m = instance.node("one/inner/m");
		check(wheel != null && wheel.visible && hub != null && hub.x == 1 && bulb != null && Std.isOfType(bulb, PointLight3D) && bulb.parent == wheel,
			"The prefab's flag turned back on, its node moved, a child added under it");
		check(m != null && Std.isOfType(m, Model3D) && m.parent == instance.node("one/inner"), "A prefab's own prefab lands under its node");
		check(instance.node("loop/again") != null
			&& instance.node("loop/again").childCount == 0
			&& logged(["main.scene3d", "loop/again", "p/loop.scene3d", "names itself"]),
			"A prefab naming itself is refused and logged, its node left empty");
		check(logged(["main.scene3d", "one/nope/path", "names no node"]), "An override's path naming no node is logged");
		check(logged(["main.scene3d", "g", "Nothing", "not registered"]), "An unknown behavior is logged");
		check(logged(["main.scene3d", "g", "Checkpoint.bogus", "not a prop"])
			&& logged(["main.scene3d", "g", "Checkpoint.target", "wrong shape"]),
			"A prop the behavior hasn't, and a value of the wrong shape, are logged");
		check(logged(["main.scene3d", "@hub names 2 nodes", "first is taken"]), "A name two nodes have (the nested prefab's too) is logged");
		check(log.length == 0, 'Nothing else logged: $log');
		var kinds = [
			for (b in instance.behaviors)
				Type.getClassName(Type.getClass(b)).split(".").pop() + "@" + instance.pathOf(b.node)
		];
		check(kinds.join(",") == "Gate@one/wheel,Checkpoint@one/wheel,Checkpoint@one/wheel,Gate@one/wheel/bulb,Checkpoint@g,Checkpoint@g",
			'The behaviors in order, the prefab\'s first: $kinds');
		var inner:Checkpoint = cast instance.behaviors[1],
			added:Checkpoint = cast instance.behaviors[2],
			top:Checkpoint = cast instance.behaviors[4];
		check(inner.target == hub, "A prefab's reference resolves within the prefab, the first of the name in drawing order (its own hub)");
		check(added.index == 3 && top.index == 1 && top.target == wheel, "An Int prop from a number, rounded down; a reference by path");
		pass.update(0);
		check(readyCalls == 1, "ready at the first update");

		// Capture: the prefabs' own nodes and behaviors are theirs; the overrides hold what the file added or changed.
		var expected = [
			'{',
			'  "helix-scene3d": 1,',
			'  "nodes": [',
			'    {',
			'      "scene": "p/one.scene3d",',
			'      "name": "one",',
			'      "overrides": {',
			'        "wheel": {',
			'          "visible": true,',
			'          "children": [',
			'            {',
			'              "kind": "PointLight3D",',
			'              "name": "bulb",',
			'              "behaviors": [',
			'                {',
			'                  "kind": "Gate"',
			'                }',
			'              ]',
			'            }',
			'          ],',
			'          "behaviors": [',
			'            {',
			'              "kind": "Checkpoint",',
			'              "props": {',
			'                "index": 3',
			'              }',
			'            }',
			'          ]',
			'        },',
			'        "wheel/hub": {',
			'          "position": [1, 0, 0]',
			'        }',
			'      }',
			'    },',
			'    {',
			'      "scene": "p/loop.scene3d",',
			'      "name": "loop"',
			'    },',
			'    {',
			'      "kind": "Node3D",',
			'      "name": "g",',
			'      "behaviors": [',
			'        {',
			'          "kind": "Checkpoint",',
			'          "props": {',
			'            "index": 1,',
			'            "target": "@wheel"',
			'          }',
			'        },',
			'        {',
			'          "kind": "Checkpoint"',
			'        }',
			'      ]',
			'    }',
			'  ]',
			'}'
		].join("\n") + "\n";
		var captured = SceneFile3D.capture(instance).write().toString();
		check(captured == expected, 'The prefabs capture as their references and overrides:\n$captured');

		// Changes under the prefabs and nodes added by the game.
		hub.setPosition(2, 0, 0);
		(cast m : Model3D).tint = 0xffff0000;
		var tag = new Text3D("tag");
		tag.name = "tag";
		wheel.addChild(tag);
		var sun = new DirectionalLight3D();
		sun.name = "sun";
		sun.intensity = 2;
		instance.root.addChild(sun);
		var box = new Model3D(Mesh3D.fromArrays([0, 0, 0, 1, 0, 0, 0, 1, 0], null, null, null, null), new Material3D());
		box.name = "box";
		box.material.roughness = .2;
		instance.root.addChild(box);
		var again = SceneFile3D.capture(instance);
		var one = again.nodes[0];
		check(one.overrides.get("wheel/hub").position.join(",") == "2,0,0", "A moved prefab node's override follows it");
		var mChange = one.overrides.get("inner/m");
		check(mChange != null && same(mChange.properties.get("tint"), Color(0xffff0000)) && mChange.material == null,
			"A nested prefab's model changed is an override by its path from the outer prefab");
		var wheelChange = one.overrides.get("wheel");
		check(wheelChange.children.length == 2
			&& wheelChange.children[1].kind == "Text3D"
			&& wheelChange.children[1].name == "tag"
			&& same(wheelChange.children[1].properties.get("text"), Text("tag")),
			"A node the game added under a prefab's node joins the override's children");
		check(again.nodes.length == 5
			&& again.nodes[3].kind == "DirectionalLight3D"
			&& same(again.nodes[3].properties.get("intensity"), Number(2)),
			"A light the game added at the top is captured by its class");
		var boxEntry = again.nodes[4];
		check(boxEntry.kind == "Model3D" && boxEntry.file == null && boxEntry.material != null && boxEntry.material.roughness == .2
			&& boxEntry.material.baseColor == null,
			"A model made in code from arrays is written without a file or a mesh, its material as it differs from the default");
		check(logged(["main.scene3d", "box", "has no file"]) && log.length == 0, "and logged once");
		SceneFile3D.capture(instance);
		check(logged(["main.scene3d", "box", "has no file"]), "once per capture");

		instance.destroy();
		check(pass.count == 0 && instance.root.parent == null, "destroy takes everything out");

		// Ready waits for a prefab served later.
		var later = parse('{"helix-scene3d": 1, "nodes": [{"scene": "p/late.scene3d", "name": "late"}]}', "later.scene3d");
		made = fresh();
		readyCalls = 0;
		var waiting = later.instantiate(made.stage.root, made.pass, () -> readyCalls++);
		check(!waiting.ready && held.exists("p/late.scene3d"), "Not ready while a prefab loads");
		made.pass.update(0);
		check(readyCalls == 0, "and the lambda waits");
		release("p/late.scene3d", Bytes.ofString(TWO));
		check(waiting.ready && waiting.node("late/m") != null && readyCalls == 0, "Ready once it lands");
		made.pass.update(0);
		check(readyCalls == 1, "and the lambda at the next update");
		waiting.destroy();
	}

	// A model file: its nodes moved under the entry's node, the entry's Model3D properties on every model, an override by the file's path.
	static function modelFile():Void {
		var pistol = "CharacterArmature/Root/Body/Hips/Abdomen/Torso/Chest/Shoulder.R/UpperArm.R/LowerArm.R/Wrist.R/Middle1.R/Pistol";
		var text = '{"helix-scene3d": 1, "nodes": [{"kind": "Model3D", "name": "gun", "file": "guns/gun.glb", "position": [0, 1, 0], "tint": "#ff0000",
			"shadowCasting": false, "overrides": {
				"$pistol": {"visible": false, "tint": "#00ff00"},
				"CharacterArmature/Root/Foot.L": {"position": [5, 0, 0], "children": [{"kind": "Node3D", "name": "marker"}]},
				"nope/path": {"visible": false}}}]}';
		var file = parse(text, "gun.scene3d");
		var made = fresh(), stage = made.stage, pass = made.pass, readyCalls = 0;
		var instance = file.instantiate(stage.root, pass, () -> readyCalls++);
		var gun = instance.node("gun");
		check(gun != null && gun.y == 1 && gun.childCount == 0 && held.exists("guns/gun.glb") && !instance.ready, "The file's node waits empty");
		release("guns/gun.glb", sys.io.File.getBytes("examples/assets/models/modular-women/Gun.glb"));
		check(instance.ready
			&& gun.childCount == 1
			&& gun.getChild(0).name == "CharacterArmature", "The file's roots moved under the entry's node");
		var model = Std.downcast(instance.node('gun/$pistol'), Model3D);
		check(model != null && model.mesh != null && model.tint == 0xff00ff00 && !model.shadowCasting && model.shadowReceiving && !model.visible,
			'The file\'s model got the entry\'s properties, then the override\'s: ${model == null ? "no model" : StringTools.hex(model.tint) + " " + model.mesh + " " + model.shadowCasting + " " + model.shadowReceiving + " " + model.visible} $log');
		var foot = instance.node("gun/CharacterArmature/Root/Foot.L");
		check(foot != null
			&& foot.x == 5
			&& foot.find("marker", Node3D) != null
			&& instance.pathOf(foot.find("marker", Node3D)) == "gun/CharacterArmature/Root/Foot.L/marker",
			"An override moves a file's node and adds a child under it");
		check(logged(["gun.scene3d", "gun/nope/path", "names no node"]) && log.length == 0, "A path naming no node is logged");
		pass.update(0);
		check(readyCalls == 1, "Ready after the model landed");
		var expected = [
			'{',
			'  "helix-scene3d": 1,',
			'  "nodes": [',
			'    {',
			'      "kind": "Model3D",',
			'      "name": "gun",',
			'      "file": "guns/gun.glb",',
			'      "position": [0, 1, 0],',
			'      "tint": "#ff0000",',
			'      "shadowCasting": false,',
			'      "overrides": {',
			'        "$pistol": {',
			'          "visible": false,',
			'          "tint": "#00ff00"',
			'        },',
			'        "CharacterArmature/Root/Foot.L": {',
			'          "position": [5, 0, 0],',
			'          "children": [',
			'            {',
			'              "kind": "Node3D",',
			'              "name": "marker"',
			'            }',
			'          ]',
			'        }',
			'      }',
			'    }',
			'  ]',
			'}'
		].join("\n") + "\n";
		var captured = SceneFile3D.capture(instance).write().toString();
		check(captured == expected, 'A file node captures as its reference and the overrides that differ (the one naming no node dropped):\n$captured');
		instance.destroy();
	}

	// Every kind's table: each property applied to a live node reads back equal, and the same for a material.
	static function kinds():Void {
		log = [];
		check(SceneKinds3D.make("Blob") == null
			&& SceneKinds3D.kindOf(new Node3D()) == "Node3D"
			&& SceneKinds3D.kindOf(new SpotLight3D()) == "SpotLight3D",
			"Kinds by name and by class");
		var ttf = sys.io.File.getBytes("examples/assets/fonts/Komika/KOMIKAH_.ttf"),
			pixel = Bytes.alloc(4);
		for (kind in SceneSchema3D.kinds) {
			var node = SceneKinds3D.make(kind.name);
			check(node != null && SceneKinds3D.kindOf(node) == kind.name, '${kind.name} is made and known by its class');
			for (property in kind.properties) {
				var value = away(property);
				check(SceneKinds3D.apply(node, property.name, value), '${kind.name}.${property.name} applies');
			}
			// What the paths asked for lands.
			for (path in ["elsewhere.png", "normal.png"])
				if (held.exists(path))
					release(path, pixel);
			if (held.exists("fonts/test.ttf"))
				release("fonts/test.ttf", ttf);
			decoding.poll();
			for (property in kind.properties) {
				var read = SceneKinds3D.read(node, property.name);
				check(read != null && same(read, away(property)), '${kind.name}.${property.name} reads back what was applied: $read');
			}
			check(!SceneKinds3D.apply(node, "colour", Color(0))
				&& SceneKinds3D.read(node, "colour") == null, 'A property ${kind.name} hasn\'t is refused');
			if (kind.properties.length > 0)
				check(!SceneKinds3D.apply(node, kind.properties[0].name, Reference("x")), "and a value of the wrong shape");
		}
		var sprite = new Sprite3D(null);
		check(!SceneKinds3D.apply(sprite, "facing", Text("sideways")) && !SceneKinds3D.apply(sprite, "alphaMode", Text("solid")),
			"A named choice no enum has is refused");
		var lamp = new PointLight3D();
		check(!SceneKinds3D.apply(lamp, "shadowCasting", Flag(true)) && SceneKinds3D.read(lamp, "shadowDistance") == null,
			"A point light's shadow properties aren't its to apply or read");
		var camera = new Camera3D();
		check(!SceneKinds3D.apply(camera, "projection", Text("isometric"))
			&& SceneKinds3D.projectionOf("orthographic") == Orthographic
			&& SceneKinds3D.projectionName(Perspective) == "perspective",
			"Projections by name");
		check(SceneKinds3D.apply(camera, "near", Number(2000))
			&& camera.near == 2000
			&& camera.far > 2000
			&& SceneKinds3D.apply(camera, "far", Number(5000))
			&& camera.far == 5000
			&& camera.near == 2000,
			"A near past the far moves the far just past it, so the far then said lands too");
		check(SceneKinds3D.apply(camera, "far", Number(.05))
			&& camera.far == .05
			&& camera.near < .05
			&& SceneKinds3D.apply(camera, "near", Number(.01))
			&& camera.near == .01
			&& camera.far == .05,
			"and a far under the near moves the near just under it");
		var material = new SceneMaterial3D();
		material.baseColor = 0x78123456;
		material.metallic = .25;
		material.roughness = .75;
		material.texture = "mat.png";
		material.normalTexture = "mat_n.png";
		material.normalScale = 2;
		material.emissive = 0xffff8800;
		material.emissiveStrength = 3;
		material.doubleSided = true;
		var model = new Model3D(Mesh3D.cube(1, 1, 1), new Material3D());
		var before = model.material;
		SceneKinds3D.applyMaterial(model, material);
		release("mat.png", pixel);
		release("mat_n.png", pixel);
		decoding.poll();
		var read = SceneKinds3D.readMaterial(model);
		check(model.material != before && read.baseColor == 0x78123456 && read.metallic == .25 && read.roughness == .75 && read.texture == "mat.png"
			&& read.normalTexture == "mat_n.png" && read.normalScale == 2 && read.emissive == 0xffff8800 && read.emissiveStrength == 3
			&& read.doubleSided == true,
			"A material applied reads back every value, its textures by path");
		var partial = new SceneMaterial3D();
		partial.roughness = .1;
		SceneKinds3D.applyMaterial(model, partial);
		read = SceneKinds3D.readMaterial(model);
		check(read.roughness == .1 && read.baseColor == 0xffffffff && read.texture == null && read.metallic == 0,
			"A material saying one value is that value over the defaults");
		check(SceneKinds3D.readMaterial(new Model3D()) == null, "A model of no parts has no material to read");
		check(log.length == 0, 'Nothing logged: $log');
	}

	// An unsaid flag is the kind's own default (a Text3D unpickable), a said one is applied and captured as said away from it; a camera
	// of each projection applied and read back.
	static function flagsAndCameras():Void {
		var file = parse('{"helix-scene3d": 1, "nodes": [
			{"kind": "Text3D", "name": "quiet", "text": "a"},
			{"kind": "Text3D", "name": "button", "text": "b", "pickable": true},
			{"kind": "Model3D", "name": "ghost", "pickable": false},
			{"kind": "Camera3D", "name": "eye", "position": [0, 1, 8], "projection": "perspective", "fovY": 1, "near": 0.5, "far": 50},
			{"kind": "Camera3D", "name": "flat", "position": [0, 12, 0], "projection": "orthographic", "orthographicHeight": 6, "near": 0,
				"far": 20}
		]}', "flags.scene3d");
		var made = fresh(),
			instance = file.instantiate(made.stage.root, made.pass);
		var quiet = instance.node("quiet"),
			button = instance.node("button"),
			ghost = instance.node("ghost");
		check(quiet != null && !quiet.pickable && !quiet.paused && quiet.visible, "A Text3D with no flag said is unpickable, as made in code");
		check(button != null && button.pickable, "A Text3D said pickable is");
		check(ghost != null && !ghost.pickable && ghost.visible, "A Model3D said unpickable is");
		var eye = Std.downcast(instance.node("eye"), Camera3D),
			flat = Std.downcast(instance.node("flat"), Camera3D);
		check(eye != null && eye.projection == Perspective && eye.fovY == 1 && eye.near == .5 && eye.far == 50, "A perspective camera from a file");
		check(flat != null && flat.projection == Orthographic && flat.orthographicHeight == 6 && flat.near == 0 && flat.far == 20,
			"An orthographic camera from a file, its near 0");
		var captured = SceneFile3D.capture(instance);
		check(captured.write().compare(file.write()) == 0, "The untouched instance captures to its file: flags and projections alike");
		var written = captured.write().toString();
		var quietAt = written.indexOf('"name": "quiet"'),
			buttonAt = written.indexOf('"name": "button"'),
			ghostAt = written.indexOf('"name": "ghost"');
		check(written.substring(quietAt, buttonAt).indexOf('"pickable"') < 0, "The unsaid flag at the kind's default isn't written");
		check(written.substring(buttonAt, ghostAt).indexOf('"pickable": true') >= 0, "The Text3D's pickable true is");
		check(written.substring(ghostAt).indexOf('"pickable": false') >= 0, "and the Model3D's pickable false");
		check(same(captured.nodes[4].properties.get("projection"), Text("orthographic"))
			&& same(captured.nodes[4].properties.get("near"), Number(0))
			&& same(captured.nodes[3].properties.get("projection"), Text("perspective"))
			&& written.indexOf('"projection": "perspective"') < 0,
			"A projection reads back by name, a perspective one left out of the write as the default");
		flat.projection = Perspective;
		check(flat.near > 0 && flat.far == 20, "Perspective raises a near of 0 above it");
		instance.destroy();
		check(log.length == 0, 'Nothing logged: $log');
	}

	// Generated meshes: a cube and a plane from a file, made by Mesh3D's generators with the inline material, captured byte-equal; a sphere
	// made in code captured as a mesh entry.
	static function meshes():Void {
		var file = parse('{"helix-scene3d": 1, "nodes": [
			{"kind": "Model3D", "name": "box", "position": [0, 1, 0], "mesh": {"shape": "cube", "width": 1, "height": 2, "length": 3}},
			{"kind": "Model3D", "name": "ground", "mesh": {"shape": "plane", "width": 400, "length": 400, "subdivisions": 2},
				"material": {"baseColor": "#9bbf7c", "roughness": 1}, "shadowCasting": false}
		]}', "meshes.scene3d");
		var made = fresh(),
			instance = file.instantiate(made.stage.root, made.pass);
		var box = Std.downcast(instance.node("box"), Model3D),
			ground = Std.downcast(instance.node("ground"), Model3D);
		check(box != null && box.mesh != null && box.mesh.vertexCount == 24 && box.mesh.maxY == 1 && box.mesh.maxZ == 1.5
			&& box.material.baseColor == 0xffffffff,
			"A cube from the file: 24 vertices, its size, a default material");
		check(ground != null
			&& ground.mesh != null
			&& ground.mesh.vertexCount == 16
			&& ground.mesh.maxX == 200
			&& ground.material.baseColor == 0xff9bbf7c
			&& ground.material.roughness == 1
			&& !ground.shadowCasting,
			"A plane of two subdivisions: 16 vertices, its size, the inline material");
		check(ground.mesh.shape != null && ground.mesh.shape.name == "plane" && ground.mesh.shape.arguments.get("subdivisions") == 2,
			"The mesh records what made it");
		check(SceneFile3D.capture(instance).write().compare(file.write()) == 0, "The untouched instance captures to its file");
		var ball = new Model3D(Mesh3D.sphere(2));
		ball.name = "ball";
		instance.root.addChild(ball);
		var captured = SceneFile3D.capture(instance);
		var entry = captured.nodes[2];
		check(entry.kind == "Model3D" && entry.name == "ball" && entry.file == null && entry.mesh != null && entry.mesh.shape == "sphere"
			&& entry.mesh.arguments.get("radius") == 2,
			"A Model3D made in code with a generated mesh captures as a mesh entry");
		check(captured.write().toString().indexOf('"mesh": {\n        "shape": "sphere",\n        "radius": 2\n      }') >= 0,
			"written with its defaults left out");
		check(Mesh3D.fromArrays([0, 0, 0, 1, 0, 0, 0, 1, 0], null, null, null, null).shape == null, "A mesh from arrays has no record");
		instance.destroy();
		check(log.length == 0, 'Nothing logged: $log');
	}

	// A value for property that isn't its default and that its class keeps.
	static function away(property:PropertySchema):SceneValue {
		return switch [property.name, property.type, property.defaultValue] {
			case ["shadowMapSize", _, _]: Number(1024);
			case ["texture", _, _]: Text("elsewhere.png");
			case ["font", _, _]: Text("fonts/test.ttf");
			case ["facing", _, _]: Text("ground");
			case ["alphaMode", _, _]: Text("mask");
			case ["projection", _, _]: Text("orthographic");
			case [_, Number(_, max), Number(v)]: Number(max != null ? (v == max ? max / 2 : (v + max) / 2) : v + 1);
			case [_, Text, _]: Text("elsewhere");
			case [_, Flag, Flag(v)]: Flag(!v);
			case [_, Numbers(count), _]: Numbers([for (i in 0...count) i + 1.]);
			case [_, Color, _]: Color(0x78123456);
			case [_, Reference, _]: Reference("n");
			case _: throw 'The table of ${property.name} has a type its default doesn\'t match';
		}
	}
}

/** Follows a target: a prop of every type. */
@:access(helix)
private class ChaseCamera extends Behavior {
	@:prop public var target:Node3D = null;
	@:prop public var speed = 1.;
	@:prop public var label = "";
	@:prop public var on = true;
	@:prop public var offset:Array<Float> = [0, 0, 0];
	@:prop("color") public var tint = 0xffffffff;

	public var started = false;
	public var stopped = false;

	override public function start():Void
		started = true;

	override public function stop():Void
		stopped = true;
}

/** Drives the car. */
@:access(helix)
private class Car extends Behavior {
	@:prop public var topSpeed = 0.;

	public var started = false;
	public var stopped = false;

	override public function start():Void
		started = true;

	override public function stop():Void
		stopped = true;
}

/** A gate's checkpoint, with a target. */
@:access(helix)
private class Checkpoint extends Behavior {
	@:prop public var index = -1;
	@:prop public var target:Node3D = null;
}

/** A gate. */
@:access(helix)
private class Gate extends Behavior {}

/** Assets whose loads wait until the test releases them, counting how often each path is asked for. */
@:access(helix)
private class Held implements IAssets {
	public function new() {}

	public function load(path:String, loaded:Bytes->Void, ?failed:String->Void):helix.asset.IRequest
		return ensure(path, loaded, failed);

	public function ensure(path:String, loaded:Bytes->Void, ?failed:String->Void, ?progress:helix.asset.AssetProgress->Void,
			?options:helix.asset.EnsureOptions):helix.asset.IRequest {
		SceneInstanceTests.asked[path] = (SceneInstanceTests.asked.exists(path) ? SceneInstanceTests.asked[path] : 0) + 1;
		SceneInstanceTests.held[path] = {loaded: loaded, failed: message -> helix.asset.Failure.report(path, message, failed)};
		return new helix.asset.Request(() -> SceneInstanceTests.held.remove(path));
	}

	public var host(get, never):Null<String>;

	function get_host():Null<String>
		return null;

	public function setHost(host:Null<String>):Bool
		return false;

	public function pingHost(host:String, probePath:String, timeoutSeconds:Float, complete:Bool->Void):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public function clearCache(complete:helix.asset.StorageWriteResult->Void):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public var manifest(get, never):Null<String>;

	function get_manifest():Null<String>
		return null;

	public function setManifest(path:Null<String>):Bool
		return true;

	public var cacheMode(get, set):helix.asset.AssetCacheMode;

	function get_cacheMode():helix.asset.AssetCacheMode
		return Revalidate;

	function set_cacheMode(mode:helix.asset.AssetCacheMode):helix.asset.AssetCacheMode {
		return mode;
	}

	public function streamSource(path:String, located:helix.asset.IAssets.AudioLocation->Void, ?failed:String->Void, download:Bool = false):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public function subscribe(path:String, target:helix.asset.IReloadable):Void {}

	public function unsubscribe(path:String, target:helix.asset.IReloadable):Void {}

	public var busy(get, never):Bool;

	function get_busy():Bool
		return false;
}

/** Decodes anything as one white pixel. */
@:access(helix)
private class StubDecoder implements IImageDecoder {
	public function new() {}

	public function decode(encoded:Bytes, done:ImageDecodeResult->Void):Void {
		var rgba = Bytes.alloc(4);
		rgba.fill(0, 4, 255);
		done(Decoded(1, 1, rgba));
	}

	public function poll():Void {}
}
