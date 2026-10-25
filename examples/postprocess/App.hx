import helix.debug.FpsOverlay;
import helix.graphics.PostProcess;
import helix.graphics.ScreenEffect;
import helix.graphics.Shader;
import helix.graphics.Shaders;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.render3d.Camera3D;
import helix.render3d.DirectionalLight3D;
import helix.render3d.Environment3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.ModelFile3D;
import helix.render3d.Models3D;
import helix.render3d.Node3D;
import helix.render3d.PointLight3D;
import helix.render3d.View3D;
import helix.shader.Bloom;
import helix.shader.Blur;
import helix.shader.ChromaticAberration;
import helix.shader.ColorLut;
import helix.shader.Crt;
import helix.shader.Fxaa;
import helix.shader.Pixelate;
import helix.shader.Tonemap;
import helix.shader.Vignette;
import helix.time.Time;
import helix.host.ScreenShape;
import helix.render3d.Orbit3D;

/** Screen effects over the finished frame (PostProcess, ScreenEffect): a chain in the order a game would build one, and how to write an
	effect of one's own; every library effect alone, with its parameters, is the shader-gallery example's. The frame is an ordinary lit
	level shown by a View3D: the Kenney sports car on a floor, generated shapes, a circling point light and two glowing lamps. The chain is
	the view's (View.postProcess), so the text on the stage over it stays sharp, outside the effects. The effects are the shader
	library's (helix.shader), each a class whose fields are its parameters, and one of the example's own:
	- Bloom spreads the light past white around the lamps; it wants HDR, so with it on the scene is drawn in half floats (where the GPU draws
	them) and tone mapped after it
	- Fxaa smooths the edges' stair steps
	- Blur, Pixelate, ColorLut (a teal and orange grade made from the identity strip here; a game would load its graded PNG), Crt,
	ChromaticAberration and Vignette
	- Sepia is the example's own shader (shaders/sepia.glsl, packed into a .hxshader asset and loaded at run time), to show how one is
	written: edit it while the dev server runs and it reloads in place
	They run in the order added to the chain (PostProcess.add), each on or off (ScreenEffect.enabled); Bloom, Fxaa and Vignette start on.

	H puts the library's tone mapping (helix.shader.Tonemap) first in the chain, so everything after it reads the tone-mapped frame: Bloom then
	thresholds it as it does where the GPU draws no half floats. The background is the view's color alone (View.color, what its chain's
	scene is cleared to), and looks the same with the scene HDR or not (PostProcess clears an HDR scene to what its tone mapping shows as that
	color).

	1 Bloom, 2 Fxaa, 3 Blur, 4 Pixelate, 5 ColorLut, 6 Sepia, 7 ChromaticAberration, 8 Crt, 9 Vignette: each on and off; H: the tone mapping
	first; Up / Down: the bloom's intensity; O: stop the camera; Escape: quit, where quitting means anything. Options: autopilot (a script
	under assets/: the time and the camera are then held, the stage's with it (Stage.heldTime), the window the autopilot's page's size, so its
	samples of the frame compare across targets) and autoclose (1: quit once the script is done); the probes are ready (the car and the
	example's shader in), hdr (PostProcess.hdr) and on (the names of the effects on, in the chain's order, joined by spaces). */
class App extends helix.App {
	var level = new Node3D();
	var camera = new Camera3D();
	var hud = new Drawing2D();
	var fps = new FpsOverlay();
	var post:PostProcess;
	var shaders:Shaders;
	var bloom:Bloom;
	var colorLut:ColorLut;
	var grade:Texture2D;
	var sepia:Null<ScreenEffect>;
	// The chain's effects by name, in its order, and their keys.
	var effects:Array<{name:String, effect:ScreenEffect, key:Key}> = [];
	var lamp:PointLight3D;
	// The HDR scene's tone mapping first in the chain, when it's on.
	var tonemap:Null<Tonemap>;
	var placed = false;

	// The time the autopilot holds the level at, and its window's size (the autopilot's browser page's), so its samples compare across targets.
	static inline var HELD_TIME = 2.;
	static inline var PILOT_WIDTH = 800;
	static inline var PILOT_HEIGHT = 600;

	// The camera, circling.
	var orbit = new Orbit3D(9, 4.5, .2, .5);
	var status = "loading the example's shader";

	override public function init():Void {
		Window.title = "HeliX postprocess";
		// Under an autopilot (its script in before init: App.probe), the autopilot's window and held time.
		if (autopilot != null) {
			Window.requestSize(PILOT_WIDTH, PILOT_HEIGHT);
			orbit.running = false;
			// The stage drawn at the held time too: its effects' clock.
			Stage.heldTime = HELD_TIME;
		} else
			Window.requestSize(1000, 600);
		post = new PostProcess();
		level.environment = new Environment3D();
		level.environment.setAmbient(0xffffffff, .2);
		// Framed for 16:9: the car and the shapes around it in view on a phone held upright too.
		camera.minAspect = 16 / 9;
		var sun = new DirectionalLight3D();
		sun.intensity = 2;
		sun.lookAt(-.5, -1, -.4);
		level.addChild(sun);
		lamp = new PointLight3D();
		lamp.color = 0xffff9a4a;
		lamp.intensity = 12;
		level.addChild(lamp);
		var floor = new Material3D();
		floor.baseColor = 0xff5c6066;
		floor.roughness = .9;
		level.addChild(new Model3D(Mesh3D.plane(14, 14), floor));
		var shapes = [
			Mesh3D.sphere(.6),
			Mesh3D.cube(1, 1, 1),
			Mesh3D.torus(.5, .18),
			Mesh3D.cone(.5, 1.1)
		];
		var colors = [0xff3b82f6, 0xffe5484d, 0xfff5b942, 0xff46a758];
		for (i in 0...shapes.length) {
			var material = new Material3D();
			material.baseColor = colors[i];
			material.roughness = .35;
			var model = new Model3D(shapes[i], material);
			var a = i / shapes.length * Math.PI * 2 + .4;
			model.setPosition(Math.cos(a) * 3.5, .6, Math.sin(a) * 3.5);
			level.addChild(model);
		}
		// Two lamps glowing far past white, for the bloom.
		for (i in 0...2) {
			var glow = new Material3D();
			glow.baseColor = 0xff000000;
			glow.setEmissive(i == 0 ? 0xffffd9a0 : 0xff9fd8ff, 10);
			var bulb = new Model3D(Mesh3D.sphere(.25), glow);
			bulb.setPosition(i == 0 ? -1.6 : 1.9, 1.7, i == 0 ? 1.4 : -.8);
			level.addChild(bulb);
		}
		Models3D.load("models/car-kit/sedan-sports.glb", file -> place(file));

		// The library's effects, in the chain's order; the example's own shader (Sepia) takes its place when it loads.
		bloom = new Bloom();
		grade = Texture2D.fromRgba(ColorLut.SIZE * ColorLut.SIZE, ColorLut.SIZE, tealAndOrange(), Linear);
		colorLut = new ColorLut(grade);
		var vignette = new Vignette(.5);
		var chain:Array<{name:String, effect:ScreenEffect, key:Key}> = [
			{name: "bloom", effect: bloom, key: Digit1},
			{name: "fxaa", effect: new Fxaa(), key: Digit2},
			{name: "blur", effect: new Blur(6), key: Digit3},
			{name: "pixelate", effect: new Pixelate(8), key: Digit4},
			{name: "colorLut", effect: colorLut, key: Digit5},
			{name: "chromaticAberration", effect: new ChromaticAberration(6), key: Digit7},
			{name: "crt", effect: new Crt(), key: Digit8},
			{name: "vignette", effect: vignette, key: Digit9}
		];
		for (entry in chain) {
			entry.effect.enabled = entry.name == "bloom" || entry.name == "fxaa" || entry.name == "vignette";
			effects.push(entry);
		}
		rebuild();

		shaders = new Shaders();
		shaders.load("shaders/sepia.hxshader", shader -> makeSepia(shader), message -> status = message);

		// The level through the chain, then the text over it, outside the effects.
		Stage.color = 0xff14161c;
		var view = new View3D(level, camera);
		view.postProcess = post;
		// Its chain's scene cleared to the stage's color: a background its effects work on.
		view.color = Stage.color;
		Stage.addChild(view);
		Stage.addChild(hud);
		Stage.addChild(fps);
	}

	// A grade, as an artist would make one from the identity strip: shadows toward teal, highlights toward orange, a little more contrast.
	static function tealAndOrange():haxe.io.Bytes {
		var pixels = ColorLut.identity();
		for (i in 0...Std.int(pixels.length / 4)) {
			var r = pixels.get(i * 4) / 255,
				g = pixels.get(i * 4 + 1) / 255,
				b = pixels.get(i * 4 + 2) / 255;
			var luma = .299 * r + .587 * g + .114 * b;
			var warm = luma - .5;
			inline function channel(c:Float, shift:Float):Int {
				var v = .5 + (c - .5) * 1.15 + shift * warm;
				return Std.int(Math.max(0, Math.min(1, v)) * 255 + .5);
			}
			pixels.set(i * 4, channel(r, .25));
			pixels.set(i * 4 + 1, channel(g, -.08));
			pixels.set(i * 4 + 2, channel(b, -.3));
		}
		return pixels;
	}

	override public function probe(name:String):Dynamic
		return switch name {
			case "ready": placed && sepia != null;
			case "hdr": post.hdr;
			case "on": [for (e in effects) if (e.effect.enabled) e.name].join(" ");
			default: throw 'Unknown probe ' + name;
		}

	// The car's file in: a copy of it in the middle.
	function place(file:ModelFile3D):Void {
		var car = file.instantiate("car");
		car.setScale(1.5, 1.5, 1.5);
		level.addChild(car);
		placed = true;
	}

	// The example's shader in: its effect, toned toward old paper, after the grade.
	function makeSepia(shader:Shader):Void {
		sepia = new ScreenEffect(shader);
		sepia.parameters.setFloat("amount", .85);
		sepia.parameters.setColor("paper", 0xffffe2b0);
		sepia.enabled = false;
		var at = 0;
		while (effects[at].name != "colorLut")
			at++;
		effects.insert(at + 1, {name: "sepia", effect: sepia, key: Digit6});
		rebuild();
		status = "";
	}

	// The chain made again in its order: the tone mapping first when it's on, then the effects.
	function rebuild():Void {
		for (e in effects)
			post.remove(e.effect);
		if (tonemap != null)
			post.remove(tonemap);
		if (tonemap != null)
			post.add(tonemap);
		for (e in effects)
			post.add(e.effect);
	}

	// The tone mapping first in the chain, or out of it.
	function toggleTonemap():Void {
		if (tonemap != null) {
			post.remove(tonemap);
			tonemap = null;
		} else
			tonemap = new Tonemap();
		rebuild();
	}

	override public function update(dt:Float):Void {
		// The program's input: the autopilot's while it plays, a tick an update.
		control(dt);
		// The game's clock: paused, the motion stops.
		var time = autopilot != null ? HELD_TIME : Time.clock.time;
		orbit.update(dt);
		fps.update(dt, Time.frameCpu);
		lamp.setPosition(Math.cos(time) * 2.5, 1.2, Math.sin(time) * 2.5);
		orbit.apply(camera);
		// The text in the design for the window's shape, wrapped to what's visible of it.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;

		hud.clear();
		var y = vy + 36, title = "HeliX postprocess: the shader library's screen effects over the finished frame";
		y += hud.drawTextWrapped(title, vx + 12, y, 20, vw - 24, 0xfff5f5f5) + 3;
		var keys = [
			for (e in effects)
				'[${(e.key : Int) - (Key.Digit0 : Int)}] ${e.name} ${e.effect.enabled ? "on" : "off"}'
		].join("  ");
		y += hud.drawTextWrapped(keys, vx + 12, y, 16, vw - 24, 0xffc8c8c8) + 4;
		var state = '[H] tone mapping first ${tonemap == null ? "off" : "on"}  HDR scene ${post.hdr ? "yes" : "no"}  [Up/Down] bloom ${Math.round(bloom.intensity * 100) / 100}  [O] camera';
		y += hud.drawTextWrapped(state, vx + 12, y, 16, vw - 24, 0xffc8c8c8) + 4;
		if (status != "")
			hud.drawTextWrapped(status, vx + 12, y, 16, vw - 24, 0xffff8080);
		fps.setPosition(vx + 12, vy + 10);
	}

	// The keys, from the window or the autopilot.
	function control(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		for (e in effects)
			if (Input.isFramePressed(e.key))
				e.effect.enabled = !e.effect.enabled;
		if (Input.isFramePressed(Key.H))
			toggleTonemap();
		if (Input.isFramePressed(Key.O))
			orbit.running = !orbit.running;
		if (Input.isDown(Key.Up))
			bloom.intensity = bloom.intensity + dt;
		if (Input.isDown(Key.Down))
			bloom.intensity = bloom.intensity - dt;
	}

	override public function cleanup():Void {
		if (sepia != null)
			shaders.release(sepia.shader);
		post.destroy();
		grade.destroy();
	}
}
