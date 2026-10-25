import helix.asset.Saves;
import helix.collision.Body2D;
import helix.collision.Collide2D;
import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.ScreenShape;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Camera2D;
import helix.render2d.CameraFollow2D;
import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.render2d.SpriteAnimator2D;
import helix.render2d.SpriteSheet2D;
import helix.render2d.Stage;
import helix.render2d.Text2D;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.render2d.View2D;
import helix.time.Ticker;
import helix.time.Time;

/** A platformer's pieces together, in a level wider and taller than the view (a tile a world unit, # solid, G a gear), its nodes shown
	through a View2D on the stage, the text over it on the stage in pixels:
	- the player an arcade body (helix.collision.Body2D) run in a 60 Hz Ticker: gravity, landing, walls, its head; a jump a moment after
	  leaving a ledge (coyote time, by its air time) or pressed a moment before landing (buffered), cut short when let go
	- drawn as the sheet's blob (sheets/gizmos.json), a Sprite2D placed between its steps (Body2D.getDrawnX), facing its way: walking in
	  low hops in step with its speed, stretched rising and rounder falling, breathing and blinking while it stands
	- a CameraFollow2D following where it's drawn, moving the view's camera: a dead zone, catching up smoothly, kept inside the level;
	  shaken by a hard landing, a bumped head and a gear collected, K for a big one
	- gears spinning (Sprite2D.setFrame), collected by touching them (Collide2D.rectCircle)
	- a save (helix.asset.Saves, "platformer.json"): the gears collected and where the player stood, written at each gear and read at the
	  start, so a visit goes on where the last left off; R starts again, removing it
	The arrows or A and D move, Space, Up, W or Z jump. Escape quits where quitting means anything. */
class App extends helix.App {
	static var LEVEL = [
		"................................................",
		"................................................",
		"..............................G.................",
		".....................######.......G.............",
		"..........G.....................#####...........",
		".......#####.........G..........................",
		"...................#####..........G....#####....",
		"..G...........................####..............",
		".#####.....G..........G.........................",
		"..........####......######.........G.....G......",
		".....G..............................######......",
		"...#####........##..........................##..",
		"#...............##.....G.......................#",
		"################################################"
	];
	static inline var RUN = 7.;
	static inline var JUMP = 15.;
	static inline var COYOTE = .1;
	static inline var BUFFER = .12;
	// World units per texel of the sheet: its 24-texel pictures about a tile wide.
	static inline var TEXEL = 1 / 20;

	var world = new Node2D();
	// The world's layers: the tiles, the gears over them, the player over both.
	var tileLayer = new Node2D();
	var gearLayer = new Node2D();
	var camera = new Camera2D();
	var body = new Sprite2D(null);
	var gearSprites:Array<Sprite2D> = [];
	var title = new Text2D("HeliX platformer: an arcade body, a sprite sheet, a following camera", 20, 0xffebeef5);
	var status = new Text2D("", 15, 0xff8c929e);
	var fps = new FpsOverlay();
	var ticker:Ticker;
	var follow:CameraFollow2D;
	var player = new Body2D(2, 10, .8, .7);
	var sheet:Null<SpriteSheet2D>;
	var tiles:Null<Texture2D>;
	var looks:Null<SpriteAnimator2D>;
	var spin:Null<SpriteAnimator2D>;
	var gears:Array<{x:Float, y:Float}> = [];
	var collected = 0;
	var total = 0;
	var saved = "";
	var facing = 1.;
	var jumpBuffered = 0.;
	var failure:Null<String>;

	override public function init():Void {
		Window.title = "HeliX platformer";
		body.setPivot(.5, .5);
		Window.requestSize(960, 600);
		Stage.color = 0xff1d2230;
		world.addChild(tileLayer);
		world.addChild(gearLayer);
		world.addChild(body);
		Stage.addChild(new View2D(world, camera));
		Stage.addChild(title);
		Stage.addChild(status);
		Stage.addChild(fps);
		ticker = new Ticker();
		player.gravity = 40;
		player.maxFallSpeed = 18;
		for (row in 0...LEVEL.length)
			for (column in 0...LEVEL[row].length)
				if (LEVEL[row].charAt(column) == "G")
					gears.push({x: column + .5, y: row + .5});
		total = gears.length;
		follow = new CameraFollow2D(player.centerX, player.centerY);
		follow.setDeadZone(2, 1.5);
		follow.smoothing = 6;
		follow.setBounds(0, 0, LEVEL[0].length, LEVEL.length);
		SpriteSheet2D.load("sheets/gizmos.json", loaded -> {
			sheet = loaded;
			looks = new SpriteAnimator2D(loaded);
			spin = new SpriteAnimator2D(loaded);
			spin.play("gear");
			for (_ in 0...total) {
				var gear = new Sprite2D(null);
				gear.setPivot(.5, .5);
				gear.setScale(TEXEL * .8, TEXEL * .8);
				gearSprites.push(gear);
				gearLayer.addChild(gear);
			}
		}, message -> failure = message);
		Textures.load("textures/tiles.png", Nearest, loaded -> {
			tiles = loaded;
			lay(loaded);
		}, message -> failure = message);
		Saves.read("platformer.json", text -> restore(haxe.Json.parse(text)), () -> saved = "no save yet", message -> failure = message);
	}

	// The level's solid tiles as sprites a world unit square, under everything else: grass on top, stone under it.
	function lay(texture:Texture2D):Void {
		for (row in 0...LEVEL.length)
			for (column in 0...LEVEL[row].length)
				if (LEVEL[row].charAt(column) == "#") {
					var under = row > 0 && LEVEL[row - 1].charAt(column) == "#";
					var tile = new Sprite2D(texture);
					tile.setRegion(under ? 62 : 2, 2, 16, 16);
					tile.setSize(1, 1);
					tile.setPosition(column, row);
					tileLayer.addChild(tile);
				}
	}

	// A save read back: the gears it collected gone, the player where it stood.
	function restore(save:{gears:Array<Array<Float>>, x:Float, y:Float}):Void {
		for (g in save.gears)
			for (gear in gears.copy())
				if (gear.x == g[0] && gear.y == g[1])
					gears.remove(gear);
		collected = total - gears.length;
		player.place(save.x, save.y);
		follow.snap(player.centerX, player.centerY);
		saved = "resumed from the save";
	}

	// Writes the gears collected and where the player stands.
	function save():Void {
		var taken = [];
		for (row in 0...LEVEL.length)
			for (column in 0...LEVEL[row].length)
				if (LEVEL[row].charAt(column) == "G" && !Lambda.exists(gears, g -> g.x == column + .5 && g.y == row + .5))
					taken.push([column + .5, row + .5]);
		Saves.write("platformer.json", haxe.Json.stringify({gears: taken, x: player.x, y: player.y}), () -> saved = 'saved $collected of $total',
			message -> failure = message);
	}

	// Starts again: every gear back, the player at the start, the save removed.
	function restart():Void {
		gears = [];
		for (row in 0...LEVEL.length)
			for (column in 0...LEVEL[row].length)
				if (LEVEL[row].charAt(column) == "G")
					gears.push({x: column + .5, y: row + .5});
		collected = 0;
		player.place(2, 10);
		follow.snap(player.centerX, player.centerY);
		Saves.remove("platformer.json", () -> saved = "save removed", message -> failure = message);
	}

	static function solid(column:Int, row:Int):Bool
		return row < 0 || row >= LEVEL.length || column < 0 || column >= LEVEL[row].length || LEVEL[row].charAt(column) == "#";

	// One step of the game: input, the body, the gears; the camera's shake for what it felt.
	function tick():Void {
		var dt = ticker.delta;
		var move = (Input.isDown(Key.Right) || Input.isDown(Key.D) ? 1 : 0) - (Input.isDown(Key.Left) || Input.isDown(Key.A) ? 1 : 0);
		player.velocityX = move * RUN;
		if (move != 0)
			facing = move;
		var jump = Input.isPressed(Key.Space) || Input.isPressed(Key.Up) || Input.isPressed(Key.W) || Input.isPressed(Key.Z);
		var held = Input.isDown(Key.Space) || Input.isDown(Key.Up) || Input.isDown(Key.W) || Input.isDown(Key.Z);
		jumpBuffered = jump ? BUFFER : Math.max(0, jumpBuffered - dt);
		if (jumpBuffered > 0 && player.airTime < COYOTE) {
			player.velocityY = -JUMP;
			jumpBuffered = 0;
		}
		// Let go while rising, the jump is cut short.
		if (!held && player.velocityY < 0)
			player.velocityY *= .6;
		var falling = player.velocityY;
		player.step(dt, 1, (column, row) -> solid(column, row));
		if (player.grounded && falling > 16)
			follow.shake(.35);
		if (player.blockedAbove)
			follow.shake(.2);
		if (Input.isPressed(Key.K))
			follow.shake(.8);
		var i = gears.length;
		while (i-- > 0)
			if (Collide2D.rectCircle(player.x, player.y, player.width, player.height, gears[i].x, gears[i].y, .4)) {
				gears.splice(i, 1);
				collected++;
				follow.shake(.15);
				save();
			}
		if (Input.isPressed(Key.R))
			restart();
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		fps.update(dt, Time.frameCpu);
		ticker.advance(Time.clock.elapsed, () -> tick());
		// A tile a ninth of the window's height; the view sets the camera's viewport as it draws.
		camera.zoom = Window.framebufferHeight / 9;
		// Drawn between its last two steps, and followed there.
		var t = ticker.fraction;
		var px = player.getDrawnX(t) + player.width / 2,
			py = player.getDrawnY(t) + player.height;
		follow.update(px, py - player.height / 2, dt, camera);
		follow.apply(camera);
		if (looks != null) {
			// Walking in step with its speed (a hop about two of its widths at a run), standing still, or in the air (below).
			looks.play(player.velocityX != 0 ? "walk" : "idle");
			looks.speed = player.velocityX != 0 ? 2.5 * Math.abs(player.velocityX) / RUN : 1;
			looks.update(dt);
			spin.update(dt);
		}
		if (sheet != null) {
			for (i in 0...gearSprites.length) {
				var gear = gearSprites[i];
				gear.visible = i < gears.length;
				if (gear.visible) {
					gear.setFrame(sheet, spin.frame);
					gear.setPosition(gears[i].x, gears[i].y);
				}
			}
			// In the air, stretched while rising, rounder falling.
			body.setFrame(sheet, player.grounded ? looks.frame : sheet.findAnimation("jump").frames[player.velocityY < 0 ? 0 : 1]);
			body.setScale(facing * TEXEL, TEXEL);
			body.setPosition(px, py);
		}
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		title.setPosition(vx + 20, vy + 20);
		status.text = failure != null ? 'failed: $failure' : 'gears $collected of $total   $saved   arrows or A, D to move, Space, Up, W or Z to jump, K to shake, R to start again';
		status.setPosition(vx + 20, vy + 46);
		fps.setPosition(vx + vw - 150, vy + 4);
	}

	override public function cleanup():Void {
		if (sheet != null)
			sheet.destroy();
		if (tiles != null)
			Textures.release(tiles);
	}
}
