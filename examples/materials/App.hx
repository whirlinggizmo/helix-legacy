import helix.debug.FpsOverlay;
import helix.graphics.Color;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Textures;
import helix.render3d.Camera3D;
import helix.render3d.DirectionalLight3D;
import helix.render3d.Environment3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.Node3D;
import helix.render3d.PointLight3D;
import helix.render3d.View3D;
import helix.time.Time;
import helix.host.ScreenShape;

/** glTF metallic-roughness materials made in code, one sphere mesh under them all, in a level shown by a View3D. Top row: plastic
	(metallic 0), roughness 0 to 1 left to right; middle row: gold (metallic 1), the same steps; bottom row: unlit, emissive, normal mapped and
	see-through, turning so the normal map moves. A sun, an orbiting blue point light (its marker an unlit sphere) and a little ambient light
	(an Environment3D on the level's root). 1 toggles the sun, 2 the lamp; Escape quits where quitting means anything. */
class App extends helix.App {
	static inline var COLUMNS = 5;
	static inline var SPACING = 1.35;

	var level = new Node3D();
	var camera = new Camera3D();
	var hud = new Drawing2D();
	var fps = new FpsOverlay();
	var sun:DirectionalLight3D;
	var lamp:PointLight3D;
	var marker:Model3D;
	var bottom:Array<Node3D> = [];

	// A linear color (as the earlier frameworks' examples give them) as 0xAARRGGBB, sRGB-encoded.
	static function color(r:Float, g:Float, b:Float, a = 1.):Int {
		inline function encode(c:Float):Int
			return Math.round((c <= .0031308 ? c * 12.92 : 1.055 * Math.pow(c, 1 / 2.4) - .055) * 255);
		return Color.fromChannels(encode(r), encode(g), encode(b), Math.round(a * 255));
	}

	static function pbr(base:Int, metallic:Float, roughness:Float):Material3D {
		var material = new Material3D();
		material.baseColor = base;
		material.metallic = metallic;
		material.roughness = roughness;
		return material;
	}

	function sphere(mesh:Mesh3D, x:Float, y:Float, material:Material3D):Model3D {
		var node = new Model3D(mesh, material);
		node.setPosition(x, y, 0);
		level.addChild(node);
		return node;
	}

	override public function init():Void {
		Window.title = "HeliX materials";
		Window.requestSize(1000, 700);
		Stage.color = 0xff14161c;
		level.environment = new Environment3D();
		level.environment.setAmbient(0xffffffff, .12);
		camera.setView(0, 1.6, 7.5, 0, 1.2, 0);
		// Framed for 16:9: all five columns across on a phone held upright too.
		camera.minAspect = 16 / 9;

		sun = new DirectionalLight3D();
		sun.color = 0xfffff4e4;
		sun.intensity = 3;
		sun.lookAt(-.4, -.7, -.6);
		level.addChild(sun);
		lamp = new PointLight3D();
		lamp.color = 0xff78beff;
		lamp.intensity = 8;
		lamp.range = 10;
		level.addChild(lamp);
		var glow = new Material3D();
		glow.baseColor = 0xff66bfff;
		glow.lit = false;
		marker = new Model3D(Mesh3D.sphere(.06, 8, 16), glow);
		level.addChild(marker);

		// Rows of roughness steps: red plastic, then gold.
		var ball = Mesh3D.sphere(.5, 24, 48);
		for (c in 0...COLUMNS) {
			var x = (c - (COLUMNS - 1) / 2) * SPACING,
				roughness = c / (COLUMNS - 1);
			sphere(ball, x, 2.7, pbr(color(.8, .05, .04), 0, roughness));
			sphere(ball, x, 1.35, pbr(color(1, .77, .34), 1, roughness));
		}
		var unlit = new Material3D();
		unlit.baseColor = 0xff66bfff;
		unlit.lit = false;
		bottom.push(sphere(ball, -2 * SPACING, 0, unlit));
		var emissive = pbr(color(.05, .05, .05), 0, .6);
		emissive.setEmissive(color(1, .35, .05));
		bottom.push(sphere(ball, -SPACING, 0, emissive));
		var tiles = pbr(color(.6, .6, .62), 0, .45);
		Textures.load("textures/tiles_normal.png", Linear, texture -> tiles.normalTexture = texture);
		bottom.push(sphere(ball, 0, 0, tiles));
		bottom.push(sphere(ball, SPACING, 0, pbr(color(.3, .9, .5, .35), 0, .1)));
		Stage.addChild(new View3D(level, camera));
		Stage.addChild(hud);
		Stage.addChild(fps);
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		if (Input.isFramePressed(Key.Digit1))
			sun.visible = !sun.visible;
		if (Input.isFramePressed(Key.Digit2))
			lamp.visible = !lamp.visible;
		// The game's clock: paused, the motion stops.
		var time = Time.clock.time;
		var lx = Math.cos(time * .7) * 4,
			ly = 1.4 + Math.sin(time * .9) * 1.2,
			lz = Math.sin(time * .7) * 1.5 + 2;
		lamp.setPosition(lx, ly, lz);
		marker.setPosition(lx, ly, lz);
		marker.visible = lamp.visible;
		for (node in bottom)
			node.setRotation(0, time * .5, 0);
		fps.update(dt, Time.frameCpu);
		// The text in the design for the window's shape, wrapped to what's visible of it.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		hud.clear();
		var y = vy + 36, title = "HeliX materials: metallic-roughness, unlit, emissive, normal map, blend";
		y += hud.drawTextWrapped(title, vx + 12, y, 18, vw - 24, 0xfff5f5f5) + 4;
		hud.drawTextWrapped('roughness 0 -> 1 (left to right)   rows: plastic, gold   [1] sun ${sun.visible ? "on" : "off"}  [2] lamp ${lamp.visible ? "on" : "off"}',
			vx
			+ 12, y, 15, vw
			- 24, 0xffc8c8c8);
		fps.setPosition(vx + 12, vy + 10);
	}
}
