import helix.collision.Collide2D;
import helix.debug.FpsOverlay;
import helix.texture.Sampling;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Camera2D;
import helix.render2d.Drawing2D;
import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.render2d.View2D;
import helix.time.Time;
import helix.host.ScreenShape;

/** A scrolling tile map: one sprite sheet (textures/tiles.png), one Sprite2D a cell cut out by its source region, under a Node2D shown
	by a View2D through a Camera2D in world units (a cell is 1 x 1, y down); the HUD is on the stage over the view, in its units.
	- ground first, then props over it, in the order they were added
	- trees and flags are 16x32 in the sheet, drawn 1 x 2, and stand on their cell: their pivot is their bottom edge (0.5, 1)
	- drag or the arrow keys scroll; the wheel zooms (the world units seen top to bottom)
	- coins light up under the pointer, and a click (a press and a release on the same coin) collects them
	Only the cells in view are drawn (the view culls), counted in the corner (View2D.drawnNodeCount). Escape quits where quitting means anything. */
class App extends helix.App {
	static inline var WORLD_W = 24;
	static inline var WORLD_H = 16;

	// Cells of the sheet in texels, x, y, width, height: each has a gutter repeating its edge, so sampling never reaches a neighbour.
	static var GRASS = [2, 2, 16, 16];
	static var SAND = [22, 2, 16, 16];
	static var WATER = [42, 2, 16, 16];
	static var STONE = [62, 2, 16, 16];
	static var TREE = [2, 22, 16, 32];
	static var FLAG = [22, 22, 16, 32];
	static var COIN = [42, 22, 16, 16];
	static var ROCK = [62, 22, 16, 16];

	var world = new Node2D();
	var camera = new Camera2D();
	var view:View2D;
	var hud = new Drawing2D();
	var fps = new FpsOverlay();
	var texture:Null<Texture2D>;
	var sprites:Array<Sprite2D> = [];
	var coins:Array<Sprite2D> = [];
	var collected = 0;
	var pressed:Null<Sprite2D>;
	var centerX = WORLD_W / 2;
	var centerY = WORLD_H / 2;
	var seen = 12.;
	var lastX = -1.;
	var lastY = -1.;

	// A sprite of one cell, placed at x, y in world units by its pivot, size width x height.
	function add(cell:Array<Int>, x:Float, y:Float, width:Float, height:Float, pivotX:Float, pivotY:Float):Sprite2D {
		var sprite = new Sprite2D(texture);
		sprite.setRegion(cell[0], cell[1], cell[2], cell[3]);
		sprite.setSize(width, height);
		sprite.setPivot(pivotX, pivotY);
		sprite.setPosition(x, y);
		world.addChild(sprite);
		sprites.push(sprite);
		return sprite;
	}

	// A small hand-made map: water along the bottom, a sand shore, stone paths.
	static function tileAt(x:Int, y:Int):Array<Int>
		return y >= WORLD_H - 2 ? WATER : y >= WORLD_H - 3 ? SAND : x == 8 || y == 6 ? STONE : GRASS;

	override public function init():Void {
		Window.title = "HeliX tilemap";
		Window.requestSize(960, 600);
		Stage.color = 0xff181c26;
		// Tiles at whole units with their top-left as pivot: neighbours share their edges exactly, so no seam shows between them.
		for (y in 0...WORLD_H)
			for (x in 0...WORLD_W)
				add(tileAt(x, y), x, y, 1, 1, 0, 0);
		// Props stand on their cell: their pivot is their bottom middle, at the cell's bottom.
		for (i in 0...7)
			add(TREE, 2.5 + i * 3, 4 + i % 3, 1, 2, .5, 1);
		add(FLAG, 8.5, 7, 1, 2, .5, 1);
		for (i in 0...6)
			add(ROCK, 4.5 + i * 3.5, 12 - (i % 2) * 2, 1, 1, .5, 1);
		for (i in 0...8)
			coins.push(add(COIN, 3.5 + i * 2.5, 9 - i % 3, .8, .8, .5, 1));
		view = new View2D(world, camera);
		Stage.addChild(view);
		Stage.addChild(hud);
		Stage.addChild(fps);
		Textures.load("textures/tiles.png", Nearest, loaded -> useTiles(loaded));
	}

	// The tile sheet in: every sprite draws its cell of it, crisp.
	function useTiles(loaded:Texture2D):Void {
		// Pixel art: crisp texels when zoomed in.
		loaded.sampling = Sampling.NEAREST;
		texture = loaded;
		for (sprite in sprites)
			sprite.texture = loaded;
	}

	// The coin under world point x, y, the topmost (the last added) first, inside its disc; null for none.
	function coinAt(x:Float, y:Float):Null<Sprite2D> {
		var i = coins.length;
		while (i-- > 0) {
			var coin = coins[i], r = coin.width / 2;
			if (coin.visible && Collide2D.pointInCircle(x, y, coin.x, coin.y - r, r))
				return coin;
		}
		return null;
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		fps.update(dt, Time.frameCpu);
		var height = Window.framebufferHeight;
		var unitsPerPixel = seen / height;

		// Scroll: drag, or the arrow keys.
		var px = Input.pointerX, py = Input.pointerY;
		if (Input.pointerDown && lastX >= 0 && px >= 0) {
			centerX -= (px - lastX) * unitsPerPixel;
			centerY -= (py - lastY) * unitsPerPixel;
		}
		lastX = px;
		lastY = py;
		var speed = seen * .6 * dt;
		if (Input.isDown(Key.Left))
			centerX -= speed;
		if (Input.isDown(Key.Right))
			centerX += speed;
		if (Input.isDown(Key.Up))
			centerY -= speed;
		if (Input.isDown(Key.Down))
			centerY += speed;
		// Zoom: fewer world units seen is closer.
		seen = Math.max(4, Math.min(32, seen - Input.wheelY * 1.5));
		centerX = Math.max(0, Math.min(WORLD_W, centerX));
		centerY = Math.max(0, Math.min(WORLD_H, centerY));
		camera.zoom = height / seen;
		camera.setPosition(centerX, centerY);
		// The HUD in the design for the window's shape, along the top of what's visible of it; the world keeps its own camera.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;

		// Coins: hover lights them up, a click collects them.
		var hovered = px >= 0 ? coinAt(camera.screenToWorldX(px), camera.screenToWorldY(py)) : null;
		if (Input.pointerFramePressed)
			pressed = hovered;
		if (Input.pointerFrameReleased) {
			if (pressed != null && pressed == hovered) {
				hovered.visible = false;
				collected++;
				hovered = null;
			}
			pressed = null;
		}
		for (coin in coins)
			coin.tint = coin == hovered ? 0xffffe68c : 0xffffffff;

		// The text wrapped to what's visible, the band behind it as tall as it wraps to.
		var title = "HeliX tilemap: a 2D camera over sprite tiles",
			status = 'coins: $collected of 8   zoom: ${Math.round(seen * 10) / 10} units   center: ${Math.round(centerX * 10) / 10}, ${Math.round(centerY * 10) / 10}${texture == null ? "   (loading)" : ""}',
			help = 'drag or arrows to scroll, wheel to zoom, click the coins   (${view.drawnNodeCount} of ${sprites.length} drawn)';
		var font = Stage.font;
		inline function tall(text:String, size:Float):Float
			return font.measureWrapped(text, size, vw - 40);
		hud.clear();
		hud.rect(vx, vy, vw, 20 + tall(title, 20) + 1 + tall(status, 15) + 3 + tall(help, 15) + 1, 0xbe121418);
		var y = vy + 20;
		y += hud.drawTextWrapped(title, vx + 20, y, 20, vw - 40, 0xffebeef5) + 1;
		y += hud.drawTextWrapped(status, vx + 20, y, 15, vw - 40, 0xff8c929e) + 3;
		hud.drawTextWrapped(help, vx + 20, y, 15, vw - 40, 0xff8c929e);
		fps.setPosition(vx + vw - 150, vy + 4);
	}
}
