import helix.debug.FpsOverlay;
import helix.graphics.Color;
import helix.graphics.Shaders;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Textures;
import helix.render3d.Camera3D;
import helix.render3d.EnvironmentMap3D;
import helix.render3d.Environment3D;
import helix.render3d.Environments3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.ModelFile3D;
import helix.render3d.Models3D;
import helix.render3d.Node3D;
import helix.render3d.Tonemap;
import helix.render3d.View3D;
import helix.time.Time;
import helix.host.ScreenShape;
import helix.render3d.Orbit3D;

/** Image-based light, a background and tone mapping: the material spheres (red plastic above, gold below, roughness 0 to 1 left to right), a
	normal-mapped sphere, a pearl (a surface shader of the example's own that lets the engine shade it) and a car, lit by an environment alone,
	no lights and no ambient light: an Environment3D on the level's root, its map lighting and its background behind, the exposure and the
	tone mapping the View3D's. Metals mirror the world around them; rougher
	surfaces blur it. Each environment is a 1K .hdr from Poly Haven, prepared as it loads a few milliseconds a frame (Environments3D); until it's
	ready the level is lit by nothing, and the readout says how long it took.

	E: environment (sunset, studio, none); B: background (sharp, soft, blurred, off); T: tone mapping (Neutral, ACES, none); UP / DOWN:
	exposure, half a stop a press; LEFT / RIGHT: turn the environment; O: orbit the camera or hold it; Escape: quit, where quitting means
	anything. */
class App extends helix.App {
	static inline var COLUMNS = 5;
	static inline var SPACING = 1.35;
	static var PATHS = ["environments/venice_sunset_1k.hdr", "environments/studio_small_09_1k.hdr"];
	static var NAMES = ["sunset", "studio", "none"];
	static var BLURS = [0., .35, .8];
	static var BLUR_NAMES = ["sharp", "soft", "blurred", "off"];
	static var TONEMAPS = [Tonemap.Neutral, Tonemap.Aces, Tonemap.None];
	static var TONEMAP_NAMES = ["Neutral", "ACES", "none"];

	var level = new Node3D();
	var light = new Environment3D();
	var view:View3D;
	var camera = new Camera3D();
	var text = new Drawing2D();
	var fps = new FpsOverlay();
	var environments:Array<Null<EnvironmentMap3D>> = [null, null];
	var loadMs:Array<Float> = [0, 0];
	var current = 0;
	var blur = 1;
	var tonemap = 0;
	var exposure = 0.;
	var rotation = 0.;
	// The camera, circling.
	var orbit = new Orbit3D(7.5, 1.8, .15, 1.2);
	var turning:Array<Node3D> = [];
	var shaders:Shaders;

	// A linear color as 0xAARRGGBB, sRGB-encoded.
	static function color(r:Float, g:Float, b:Float):Int {
		inline function encode(c:Float):Int
			return Math.round((c <= .0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - .055) * 255);
		return Color.fromChannels(encode(r), encode(g), encode(b));
	}

	function sphere(mesh:Mesh3D, x:Float, y:Float, base:Int, metallic:Float, roughness:Float):Material3D {
		var material = new Material3D();
		material.baseColor = base;
		material.metallic = metallic;
		material.roughness = roughness;
		var node = new Model3D(mesh, material);
		node.setPosition(x, y, 0);
		level.addChild(node);
		turning.push(node);
		return material;
	}

	override public function init():Void {
		Window.title = "HeliX environment";
		Window.requestSize(1000, 700);
		Stage.color = 0xff14161c;
		level.environment = light;
		// Framed for 16:9: every column of spheres on a phone held upright too.
		camera.minAspect = 16 / 9;
		var ball = Mesh3D.sphere(.5, 32, 64);
		for (c in 0...COLUMNS) {
			var x = (c - (COLUMNS - 1) / 2) * SPACING,
				roughness = c / (COLUMNS - 1);
			sphere(ball, x, 2.7, color(.8, .05, .04), 0, roughness);
			sphere(ball, x, 1.35, color(1, .77, .34), 1, roughness);
		}
		var tiles = sphere(ball, -SPACING, 0, color(.6, .6, .62), 0, .35);
		Textures.load("textures/tiles_normal.png", Linear, texture -> tiles.normalTexture = texture);
		sphere(ball, -2 * SPACING, 0, color(.95, .95, .95), 1, .1);
		var pearl = sphere(ball, 0, 0, color(.9, .88, .85), 0, .2);
		shaders = new Shaders();
		shaders.load("shaders/pearl.hxshader", shader -> pearl.setShader(shader));
		Models3D.load("models/car-kit/sedan-sports.glb", file -> place(file));
		for (i in 0...PATHS.length) {
			var started = Time.time;
			Environments3D.load(PATHS[i], environment -> prepared(i, environment, started));
		}
		view = new View3D(level, camera);
		Stage.addChild(view);
		Stage.addChild(text);
		Stage.addChild(fps);
	}

	// The car's file in: a copy of it turning beside the spheres.
	function place(file:ModelFile3D):Void {
		var car = file.instantiate("car");
		car.setPosition(2.7, -.5, .2);
		car.setScale(1.1, 1.1, 1.1);
		level.addChild(car);
		turning.push(car);
	}

	// Environment i prepared, its load begun at started: kept, with how long it took.
	function prepared(i:Int, environment:EnvironmentMap3D, started:Float):Void {
		environments[i] = environment;
		loadMs[i] = (Time.time - started) * 1000;
		// Said in the log too, so a run without a screen shows how long the bake took.
		trace('${NAMES[i]} ready in ${Math.round(loadMs[i])} ms');
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		if (Input.isFramePressed(Key.E))
			current = (current + 1) % NAMES.length;
		if (Input.isFramePressed(Key.B))
			blur = (blur + 1) % BLUR_NAMES.length;
		if (Input.isFramePressed(Key.T))
			tonemap = (tonemap + 1) % TONEMAPS.length;
		if (Input.isFramePressed(Key.Up))
			exposure += .5;
		if (Input.isFramePressed(Key.Down))
			exposure -= .5;
		if (Input.isDown(Key.Left))
			rotation -= dt;
		if (Input.isDown(Key.Right))
			rotation += dt;
		if (Input.isFramePressed(Key.O))
			orbit.running = !orbit.running;
		// The game's clock: paused, the motion stops.
		var time = Time.clock.time;
		// The orbit starts once everything is in (both environments bake at the start): from the front, so a picture taken then (the site's,
		// once nothing loads) sees the rows, not their ends.
		if (!Host.busy)
			orbit.update(dt);
		for (node in turning)
			node.setRotation(0, time * .3, 0);
		fps.update(dt, Time.frameCpu);

		var environment = current < PATHS.length ? environments[current] : null;
		light.setMap(environment, 1, rotation);
		light.setBackground(blur < BLURS.length ? environment : null, blur < BLURS.length ? BLURS[blur] : 0);
		view.tonemap = TONEMAPS[tonemap];
		view.exposure = exposure;

		orbit.apply(camera);
		// The readout in the design for the window's shape, wrapped to what's visible of it.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		var title = "HeliX environment: image-based light, a background and tone mapping";
		var state = current == PATHS.length ? "" : environment == null ? " (preparing)" : ' (ready in ${Math.round(loadMs[current])} ms)';
		var readout = '[E] ${NAMES[current]}$state   [B] background ${BLUR_NAMES[blur]}   [T] ${TONEMAP_NAMES[tonemap]}   '
			+ 'UP/DOWN exposure ${exposure >= 0 ? "+" : ""}$exposure EV   LEFT/RIGHT turn   [O] camera';
		// The band's height is the readout's, wrapped.
		var wrap = vw - 24, font = Stage.font;
		var readoutY = vy + 36 + font.measureWrapped(title, 20, wrap) + 3,
			bottom = readoutY + font.measureWrapped(readout, 16, wrap) - 2;

		text.clear();
		// A dark band behind the readout, which a bright sky would wash out.
		text.rect(vx, vy, vw, bottom - vy, 0x8c000000);
		text.drawTextWrapped(title, vx + 12, vy + 36, 20, wrap, 0xfff5f5f5);
		text.drawTextWrapped(readout, vx + 12, readoutY, 16, wrap, 0xffc8c8c8);
		fps.setPosition(vx + 12, vy + 10);
	}

	override public function cleanup():Void {
		for (environment in environments)
			if (environment != null)
				Environments3D.release(environment);
		view.destroy();
	}
}
