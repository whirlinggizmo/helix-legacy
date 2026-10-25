import helix.debug.FpsOverlay;
import helix.graphics.Shader;
import helix.graphics.Shaders;
import helix.graphics.SpriteEffect;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.render3d.Camera3D;
import helix.render3d.Decals3D;
import helix.render3d.Ray3D;
import helix.render3d.DirectionalLight3D;
import helix.render3d.Drawing3D;
import helix.render3d.Environment3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.Sprite3D;
import helix.render3d.Node3D;
import helix.render3d.View3D;
import helix.shader.SpriteDissolve;
import helix.shader.SpriteFlash;
import helix.shader.SpriteOutline;
import helix.shader.SpriteRing;
import helix.time.Time;
import helix.host.ScreenShape;
import helix.render3d.Orbit3D;

/** Textured sprites in a 3D level shown by a View3D, under a circling camera, over a grid (a Drawing3D) and a lit pedestal:
	- the logo, facing the camera as it circles, bobbing over the pedestal (blended by its alpha)
	- trees, cut from the tile sheet, upright: they turn to the camera about y only, and stand on their bottom edge (pivot 0.5, 1)
	- a flag on a sign post, as its node is turned (Free), and a coin flat on the ground (Ground)
	- the coin's glow, added over everything (Add), and masked flames that cut out where their texels fade
	- a ring round the coin, lying on the ground: a SpriteRing (dashed, turning, pulsing) drawn over a 1 x 1 white texture
	Sprites are unlit and instanced: alike ones (a texture, an alpha mode, an effect) are one draw, and the readout counts them.
	Sprite effects (helix.shader, as on 2D sprites): the trees share one SpriteOutline (1), read only inside each tree's cell of the sheet; the
	sign dissolves (SpriteDissolve, 2), its cut-out still masked; the logo flashes (SpriteFlash) on F. The flames shimmer (3) through the
	example's own sprite shader, shaders/heat.glsl (packed into an .hxshader asset and loaded at run time, new SpriteEffect(shader)), its
	parameters set by name.
	C collects: coins fly from the coin on the ground to the counter at the top right (helix.scene.Collect2D, from where View3D.project sees
	the coin on the stage), the count rising as each lands. Dragging the pointer over the ground leaves a trail of decals (Decals3D: where its
	ray meets the ground, View3D.computeRay and Ray3D.hitHeight), each fading out after 4 seconds on the game's clock, and the oldest sooner
	as the pool comes round to them. O stops the camera; Escape quits where quitting means anything. Options: autopilot (a script under assets/: the time and the camera are then
	held, the stage's with it (Stage.heldTime), the window the autopilot's page's size, so its samples of the frame compare across targets)
	and autoclose (1: quit once the script is done); the probes are ready (the textures and the heat in), outline, dissolving and shimmering. */
class App extends helix.App {
	var level = new Node3D();
	var view:View3D;
	var camera = new Camera3D();
	var hud = new Drawing2D();
	// The coins collected, at the top right, and the flight that brings them.
	var counter = new helix.render2d.Text2D("coins 0", 20, 0xffffd25a);
	var coins = 0;
	var flight:Null<helix.scene.Collect2D>;
	// The decals a drag leaves on the ground, and where the last went (NaN: none this drag).
	var decals:Decals3D;
	var ray = new Ray3D();
	var ground = new helix.math.Point3D();
	var lastDecalX = Math.NaN;
	var lastDecalZ = Math.NaN;
	var fps = new FpsOverlay();
	var logo:Sprite3D;
	var sign:Sprite3D;
	// The camera, circling.
	var orbit = new Orbit3D(8, 3.5, .3, 1);
	var trees:Array<Sprite3D> = [];
	var tileSprites:Array<Sprite3D> = [];
	var flames:Array<Sprite3D> = [];
	var outline:SpriteOutline;
	var dissolve:SpriteDissolve;
	var flash:SpriteFlash;
	var outlined = true;
	var dissolving = true;
	var shaders:Shaders;
	var heat:Null<SpriteEffect>;
	var shimmering = true;
	var loaded = 0;

	// The time the autopilot holds the level at, and its window's size (the autopilot's browser page's), so its samples compare across targets.
	static inline var HELD_TIME = 2.;
	static inline var PILOT_WIDTH = 800;
	static inline var PILOT_HEIGHT = 600;

	// A sprite of the tile sheet's cell x, y, width x height texels, placed at x, z on the ground.
	function tile(cell:Array<Int>, x:Float, z:Float, width:Float, height:Float):Sprite3D {
		var sprite = new Sprite3D(null);
		sprite.setRegion(cell[0], cell[1], cell[2], cell[3]);
		sprite.setSpriteSize(width, height);
		sprite.setPosition(x, 0, z);
		tileSprites.push(sprite);
		level.addChild(sprite);
		return sprite;
	}

	override public function init():Void {
		outline = new SpriteOutline(0xffffffff, 1);
		dissolve = new SpriteDissolve();
		flash = new SpriteFlash();
		Window.title = "HeliX sprite3d";
		// Under an autopilot (its script in before init: App.probe), the autopilot's window, and the stage drawn at the held time too: its
		// effects' clock.
		if (autopilot != null) {
			Window.requestSize(PILOT_WIDTH, PILOT_HEIGHT);
			Stage.heldTime = HELD_TIME;
		} else
			Window.requestSize(1000, 600);
		// Framed for 16:9: the pedestal and the trees around it on a phone held upright too.
		camera.minAspect = 16 / 9;
		Stage.color = 0xff1c1e26;
		level.environment = new Environment3D();
		level.environment.setAmbient(0xffffffff, .3);
		var grid = new Drawing3D();
		grid.grid(16, 1, 0xff3c3f48);
		level.addChild(grid);
		var sun = new DirectionalLight3D();
		sun.intensity = 2.5;
		sun.lookAt(-.5, -1, -.3);
		level.addChild(sun);
		var stone = new Material3D();
		stone.baseColor = 0xff8a8f99;
		stone.roughness = .8;
		var pedestal = new Model3D(Mesh3D.cylinder(.6, 1), stone);
		pedestal.setPosition(0, .5, 0);
		level.addChild(pedestal);

		// A ring round the coin: drawn by its effect, the sprite's texture only a quad's, its tint the ring's color.
		var white = haxe.io.Bytes.alloc(4);
		white.fill(0, 4, 255);
		var ring = new Sprite3D(helix.texture.Texture2D.fromRgba(1, 1, white), 0xc040e0ff);
		ring.facing = Ground;
		ring.setSpriteSize(1.6, 1.6);
		ring.setPosition(-2, .01, 1.5);
		var look = new SpriteRing();
		look.dashes = 10;
		look.spin = .1;
		look.pulse = .1;
		ring.effect = look;
		level.addChild(ring);

		logo = new Sprite3D(null);
		logo.setSpriteSize(1.6, 1.6);
		level.addChild(logo);
		// Trees: upright, standing on their bottom edge.
		for (i in 0...6) {
			var a = i / 6 * Math.PI * 2 + .3;
			var tree = tile([2, 22, 16, 32], Math.cos(a) * 4, Math.sin(a) * 4, 1.2, 2.4);
			tree.facing = Upright;
			tree.setPivot(.5, 1);
			tree.setAlphaMode(Mask, .5);
			tree.effect = outline;
			trees.push(tree);
		}
		// A flag on a post, turned as its node is: a sign.
		sign = tile([22, 22, 16, 32], 2, -1.5, 1, 2);
		sign.facing = Free;
		sign.setPivot(.5, 1);
		sign.setAlphaMode(Mask);
		sign.effect = dissolve;
		// A coin lying on the ground, and its glow added over it.
		var coin = tile([42, 22, 16, 16], -2, 1.5, .8, .8);
		coin.facing = Ground;
		coin.setPosition(-2, .02, 1.5);
		coin.setAlphaMode(Mask);
		Textures.load("sprites/logo/wg-logo-white-alpha.png", Linear, texture -> useLogo(texture));
		Textures.load("textures/tiles.png", Nearest, texture -> useTiles(texture));
		Textures.load("textures/flame.png", Linear, texture -> light(texture));
		logo.effect = flash;
		shaders = new Shaders();
		shaders.load("shaders/heat.hxshader", shader -> useHeat(shader));
		decals = new Decals3D(helix.particle.Emitter.getDot(), 48);
		decals.size = .3;
		decals.tint = 0xd0140c08;
		decals.lifeSeconds = 4;
		decals.fadeSeconds = 1;
		level.addChild(decals);
		view = new View3D(level, camera);
		Stage.addChild(view);
		Stage.addChild(hud);
		counter.setPivot(1, 0);
		counter.setPosition(0, 0);
		Stage.addChild(counter);
		Stage.addChild(fps);
	}

	// The example's own shader in: the flames shimmer, its parameters set by name.
	function useHeat(shader:Shader):Void {
		heat = new SpriteEffect(shader);
		heat.parameters.setFloat("amplitude", 16);
		heat.parameters.setFloat("waves", 1.5);
		heat.parameters.setFloat("speed", 1.2);
		shimmer();
		loaded++;
	}

	// The flames through the heat, or as the framework draws them.
	function shimmer():Void
		for (flame in flames)
			flame.effect = shimmering ? heat : null;

	override public function probe(name:String):Dynamic
		return switch name {
			case "ready": loaded == 4;
			case "outline": outlined;
			case "dissolving": dissolving;
			case "shimmering": shimmering;
			default: throw 'Unknown probe ' + name;
		}

	// The logo's texture in: the billboard draws it, tinted blue.
	function useLogo(texture:Texture2D):Void {
		logo.texture = texture;
		logo.tint = 0xff66bfff;
		loaded++;
	}

	// The tile sheet in: every tile sprite draws its cell of it.
	function useTiles(texture:Texture2D):Void {
		for (sprite in tileSprites)
			sprite.texture = texture;
		loaded++;
	}

	// The flame sheet in: masked flames, cut out where their soft edges fade, a row of them behind the pedestal, and the coin's glow.
	function light(texture:Texture2D):Void {
		for (i in 0...5) {
			var flame = new Sprite3D(texture, 0xffffa040);
			flame.setRegion(0, 0, 64, 64);
			flame.setSpriteSize(.9, .9);
			flame.setPivot(.5, 1);
			flame.facing = Upright;
			flame.setAlphaMode(Mask, .4);
			flame.setPosition(i * .8 - 1.6, 0, -2.5);
			flames.push(flame);
			level.addChild(flame);
		}
		// The heat, when it came in first.
		if (heat != null)
			shimmer();
		// The coin's glow: a soft puff of the same sheet, gold, added over everything.
		var glow = new Sprite3D(texture, 0xffffd25a);
		glow.setRegion(0, 0, 64, 64);
		glow.setSpriteSize(1.4, 1.4);
		glow.setPosition(-2, .5, 1.5);
		glow.setAlphaMode(Add);
		level.addChild(glow);
		loaded++;
	}

	override public function update(dt:Float):Void {
		// The program's input (the autopilot's while it plays, a tick an update).
		{
			if (Host.canQuit() && Input.isFramePressed(Key.Escape))
				Host.quit();
			if (Input.isFramePressed(Key.O))
				orbit.running = !orbit.running;
			if (Input.isFramePressed(Key.Digit1)) {
				outlined = !outlined;
				for (tree in trees)
					tree.effect = outlined ? outline : null;
			}
			if (Input.isFramePressed(Key.Digit2)) {
				dissolving = !dissolving;
				sign.effect = dissolving ? dissolve : null;
			}
			if (Input.isFramePressed(Key.Digit3)) {
				shimmering = !shimmering;
				shimmer();
			}
			if (Input.isFramePressed(Key.F))
				flash.trigger(0xffffffff, .4);
			if (Input.isFramePressed(Key.C))
				collect();
			if (Input.pointerDown)
				addDecal();
			else
				lastDecalX = Math.NaN;
		}
		// The game's clock: paused, the motion stops; held under the autopilot, the camera with it.
		var time = autopilot != null ? HELD_TIME : Time.clock.time;
		orbit.update(autopilot != null ? 0 : dt);
		// Half gone at the autopilot's held time, coming and going.
		dissolve.amount = .5 + .45 * Math.sin((time - HELD_TIME) * .9);
		fps.update(dt, Time.frameCpu);
		logo.setPosition(0, 2.1 + Math.sin(time * 2) * .2, 0);
		sign.setRotation(0, Math.sin(time) * .8, 0);
		orbit.apply(camera);
		// The text in the design for the window's shape, wrapped to what's visible of it.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		hud.clear();
		var y = vy + 36, title = "HeliX sprite3d: sprites facing the camera, upright, flat and free; masked, blended and added";
		y += hud.drawTextWrapped(title, vx + 12, y, 18, vw - 24, 0xfff5f5f5) + 4;
		var on = (value:Bool) -> value ? "on" : "off";
		hud.drawTextWrapped('${view.drawnNodeCount} models and sprites in ${view.drawCallCount} draws   O: the camera  [1] outline ${on(outlined)}  [2] dissolve ${on(dissolving)}  [3] heat ${on(shimmering)}  [F] flash  [C] collect  [LMB] add decal',
			vx
			+ 12, y, 16, vw
			- 24, 0xffc8c8c8);
		fps.setPosition(vx + 12, vy + 10);
		counter.setPosition(vx + vw - 12, vy + 10);
	}

	override public function cleanup():Void {
		if (heat != null)
			shaders.release(heat.shader);
	}

	// A decal where the pointer's ray meets the ground while the left button is down, once it's moved far enough from the last, turned along the way it went.
	function addDecal():Void {
		var through = view.computeRay(Screen.toUnitsX(Input.pointerX), Screen.toUnitsY(Input.pointerY), ray);
		var along = through != null ? through.hitHeight(0) : Math.NaN;
		if (!(along > 0))
			return;
		through.pointAt(along, ground);
		var dx = ground.x - lastDecalX, dz = ground.z - lastDecalZ;
		if (dx * dx + dz * dz < .3 * .3)
			return;
		decals.place(ground.x, 0, ground.z, Math.isNaN(dx) ? 0 : Math.atan2(-dx, -dz));
		lastDecalX = ground.x;
		lastDecalZ = ground.z;
	}

	// Coins from the coin on the ground to the counter: where the view sees it on the stage, then a flight to the counter, a coin counted as
	// each lands.
	function collect():Void {
		var seen = view.project(-2, .1, 1.5);
		if (seen == null)
			return;
		if (flight == null) {
			flight = new helix.scene.Collect2D(helix.particle.Emitter.getDot(), 10);
			flight.size = 18;
			flight.tint = 0xffffd25a;
		}
		flight.run(seen.x, seen.y, counter, _ -> counter.text = 'coins ${++coins}');
	}
}
