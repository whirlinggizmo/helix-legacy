import helix.debug.FpsOverlay;
import helix.texture.Sampling;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.time.Time;
import helix.host.ScreenShape;

/** One loaded texture or file, and how its load went. */
private class Slot {
	public var path:String;
	public var texture:Null<Texture2D>;
	public var chosen = "";
	public var status = "loading...";
	public var asked:Float;
	public var took = 0.;

	public function new(path:String, asked:Float) {
		this.path = path;
		this.asked = asked;
	}
}

/** Textures from image files, each drawn large twice, smooth (linear) then sharp (nearest): one texture, its sampling given to each draw (Drawing2D.image's
	sampling), with its size, GPU memory and how long it took from asking to having it. The tile sheet draws as its cells, cut from their gutters.
	Below, the logo and the flame again as "name.ktx": compressed for this GPU (name.bc7.ktx on desktops, name.astc.ktx on phones,
	name.etc2.ktx on older phones), else name.png, as the tile sheet, which has no compressed files, shows. All of it is a Drawing2D drawn
	again each update, the tile sheet's cells by their source rectangles. Escape quits where quitting means anything. */
class App extends helix.App {
	static var PATHS = ["sprites/logo/wg-logo-bw-alpha.png", "textures/flame.png", "textures/tiles.png"];
	static var KTX_PATHS = ["sprites/logo/wg-logo-bw-alpha.ktx", "textures/flame.ktx", "textures/tiles.ktx"];
	static inline var TILES = 2;

	// The tile sheet's cells in its texels, x, y, width, height: each has a 2 texel gutter repeating its edge, so filtering and mipmaps never
	// reach a neighbour; the gutters aren't drawn. Grass, sand, water, stone; tree, flag, coin, rock.
	static var CELLS = [
		 [2, 2, 16, 16],  [22, 2, 16, 16],  [42, 2, 16, 16], [62, 2, 16, 16],
		[2, 22, 16, 32], [22, 22, 16, 32], [42, 22, 16, 16], [62, 22, 16, 16]
	];

	var drawing = new Drawing2D();
	var fps = new FpsOverlay();
	var slots:Array<Slot> = [];
	var compressed:Array<Slot> = [];

	override public function init():Void {
		Window.title = "HeliX textures";
		Window.requestSize(1010, 610);
		Stage.color = 0xff262a36;
		Stage.addChild(drawing);
		Stage.addChild(fps);
		for (path in PATHS)
			slots.push(load(path));
		for (path in KTX_PATHS)
			compressed.push(load(path));
	}

	function load(path:String):Slot {
		var slot = new Slot(path, Time.time);
		Textures.load(path, Linear, texture -> loaded(slot, texture), message -> failed(slot, message));
		return slot;
	}

	// slot's texture in: how long it took, and which file it came from.
	function loaded(slot:Slot, texture:Texture2D):Void {
		slot.texture = texture;
		slot.took = Time.time - slot.asked;
		slot.chosen = Textures.getPath(texture);
	}

	// slot's texture failed: said beside it, and why in the log.
	function failed(slot:Slot, message:String):Void {
		slot.status = "failed";
		trace(message);
	}

	static function fileName(path:String):String
		return path.substr(path.lastIndexOf("/") + 1);

	// Under a texture, wrapped to width: its file's name (and the file chosen for a .ktx, under it), then its size, the GPU memory it takes,
	// and how long it took. Returns the height drawn.
	function caption(slot:Slot, x:Float, y:Float, width:Float):Float {
		var name = fileName(slot.path), chosen = fileName(slot.chosen), top = y;
		y += drawing.drawTextWrapped(name, x, y, 16, width, 0xffc8c8c8) + 2;
		if (slot.chosen != "" && chosen != name)
			y += drawing.drawTextWrapped('loaded $chosen', x, y, 14, width, 0xff66bfff) + 2;
		var t = slot.texture;
		var line = t == null ? slot.status : '${t.width} x ${t.height}, GPU ${Math.round(t.byteCount / 1024)} KB, ready in ${Math.round(slot.took * 1000)} ms';
		return y + drawing.drawTextWrapped(line, x, y, 14, width, 0xffc8c8c8) - top;
	}

	// The slots in rows of columns from x, y, each size wide (twice, smooth then sharp, when both) and captioned under. Returns the bottom.
	function grid(list:Array<Slot>, both:Bool, x:Float, y:Float, size:Float, columns:Int, pitch:Float):Float {
		var bottom = y;
		for (i in 0...list.length) {
			if (i > 0 && i % columns == 0)
				y = bottom + 20;
			var left = x + (i % columns) * pitch, texture = list[i].texture;
			if (texture != null) {
				// One texture, each draw given its sampling: smooth, then sharp (or the texture's own, alone).
				drawOne(i, texture, left, y, size, both ? Sampling.LINEAR : null);
				if (both)
					drawOne(i, texture, left + size + 10, y, size, Sampling.NEAREST);
			}
			bottom = Math.max(bottom, y + size + 16 + caption(list[i], left, y + size + 16, pitch - 20));
		}
		return bottom;
	}

	// One texture width wide at x, y, sampled by sampling (null for the texture's): the tile sheet as its cells set edge to edge, anything
	// else whole.
	function drawOne(index:Int, texture:Texture2D, x:Float, y:Float, width:Float, sampling:Null<Sampling>):Void {
		if (index != TILES) {
			drawing.image(texture, x, y, width, width, 0xffffffff, 0, 0, 0, 0, sampling);
			return;
		}
		// The cells span 64 by 48 texels.
		var scale = width / 64;
		for (c in 0...CELLS.length) {
			var cell = CELLS[c], column = c % 4, top = c < 4 ? 0 : 16;
			drawing.image(texture, x + column * 16 * scale, y + top * scale, cell[2] * scale, cell[3] * scale, 0xffffffff, cell[0], cell[1], cell[2], cell[3],
				sampling);
		}
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		fps.update(dt, Time.frameCpu);
		// The design for the window's shape: three textures a row across, smaller and two a row upright, so it all fits a phone either way.
		var shape = ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		var size = shape == "landscape" ? 150 : 120,
			columns = shape == "portrait" ? 2 : 3,
			pitch = 2 * size + 30;

		drawing.clear();
		var y = vy + 30;
		y += drawing.drawTextWrapped("HeliX textures: smooth (linear) and sharp (nearest) sampling", vx + 12, y, 22, vw - 24, 0xfff5f5f5) + 22;
		y = grid(slots, true, vx + 20, y, size, columns, pitch) + 24;
		y += drawing.drawTextWrapped("compressed: as name.ktx, this GPU's variant or else the PNG", vx + 12, y, 22, vw - 24, 0xfff5f5f5) + 22;
		grid(compressed, false, vx + 20, y, size, columns, pitch);
		fps.setPosition(vx + 12, vy + 6);
	}

	override public function cleanup():Void {
		for (slot in slots.concat(compressed))
			if (slot.texture != null)
				Textures.release(slot.texture);
	}
}
