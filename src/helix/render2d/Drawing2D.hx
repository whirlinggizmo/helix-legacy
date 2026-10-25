package helix.render2d;

import helix.font.Font;
import helix.texture.Texture2D;
import helix.math.Bounds2D;

/** Drawing kept on a node (docs/DISPLAY_MODEL.md): Flash's graphics, as calls named as Batch2D's (rect, frame, roundedRect, circle,
	circleLines, ellipse, line, polyline, polygon, polygonLines, image, drawText, drawTextWrapped), each taking its own color (0xAARRGGBB), so there is no fill to begin or end. The calls
	are kept in order, in the node's own units, and drawn each frame where the node is, turned, scaled and faded with it; clear takes them away.
	Calling clear and drawing again in update is immediate drawing, as Flash games did it. Not culled; picked by the box around what it holds. */
class Drawing2D extends Node2D {
	// The calls in order: each its kind, its numbers from its place in numbers, its color, and for text, its text in texts.
	var kinds:Array<DrawingKind> = [];
	var starts:Array<Int> = [];
	var numbers:Array<Float> = [];
	var colors:Array<Int> = [];
	var texts:Array<String> = [];
	var aligns:Array<Align2D> = [];
	var fonts:Array<Null<Font>> = [];
	var triangles:Array<Null<Array<Int>>> = [];
	var points:Array<Null<Array<Float>>> = [];
	var images:Array<Null<Texture2D>> = [];
	var samplings:Array<Null<helix.texture.Sampling>> = [];
	// The box around the shapes held, in its own units (text measured as it's drawn).
	@:allow(helix.render2d.Renderer2D)
	var left = Math.POSITIVE_INFINITY;
	@:allow(helix.render2d.Renderer2D)
	var top = Math.POSITIVE_INFINITY;
	@:allow(helix.render2d.Renderer2D)
	var right = Math.NEGATIVE_INFINITY;
	@:allow(helix.render2d.Renderer2D)
	var bottom = Math.NEGATIVE_INFINITY;

	/** A drawing holding nothing yet. */
	public function new()
		super();

	/** How many calls it holds. */
	public var callCount(get, never):Int;

	function get_callCount():Int
		return kinds.length;

	/** Takes everything drawn away. */
	public function clear():Void {
		kinds.resize(0);
		starts.resize(0);
		numbers.resize(0);
		colors.resize(0);
		texts.resize(0);
		aligns.resize(0);
		fonts.resize(0);
		triangles.resize(0);
		points.resize(0);
		images.resize(0);
		samplings.resize(0);
		left = top = Math.POSITIVE_INFINITY;
		right = bottom = Math.NEGATIVE_INFINITY;
	}

	/** A filled rectangle, top-left at x, y, w x h. */
	public function rect(x:Float, y:Float, w:Float, h:Float, color:Int):Void {
		add(Rect, [x, y, w, h], color);
		include(x, y, x + w, y + h);
	}

	/** A rectangle's outline drawn inside its bounds, width wide. */
	public function frame(x:Float, y:Float, w:Float, h:Float, width:Float, color:Int):Void {
		add(Frame, [x, y, w, h, width], color);
		include(x, y, x + w, y + h);
	}

	/** A filled rectangle with corners of radius (clamped to half the shorter side). */
	public function roundedRect(x:Float, y:Float, w:Float, h:Float, radius:Float, color:Int):Void {
		add(RoundedRect, [x, y, w, h, radius], color);
		include(x, y, x + w, y + h);
	}

	/** A filled circle centered on x, y. */
	public function circle(x:Float, y:Float, radius:Float, color:Int):Void {
		add(Circle, [x, y, radius], color);
		include(x - radius, y - radius, x + radius, y + radius);
	}

	/** A circle's outline width wide, drawn inside the circle of radius around x, y (from radius - width out to radius). */
	public function circleLines(x:Float, y:Float, radius:Float, width:Float, color:Int):Void {
		add(CircleLines, [x, y, radius, width], color);
		include(x - radius, y - radius, x + radius, y + radius);
	}

	/** A filled ellipse centered on x, y, radiusX across and radiusY down, turned by rotation (radians, clockwise). */
	public function ellipse(x:Float, y:Float, radiusX:Float, radiusY:Float, color:Int, rotation = 0.):Void {
		add(Ellipse, [x, y, radiusX, radiusY, rotation], color);
		var reach = Math.max(radiusX, radiusY);
		include(x - reach, y - reach, x + reach, y + reach);
	}

	/** A segment width wide from x0, y0 to x1, y1. Its ends are flat at the points unless cap says otherwise: Round for a half circle past
		each (lines that meet then join smoothly), Square for flat half the width past. */
	public function line(x0:Float, y0:Float, x1:Float, y1:Float, width:Float, color:Int, cap:LineCap2D = Butt):Void {
		add(Line, [x0, y0, x1, y1, width, (cap : Int)], color);
		// A square cap's corners reach past an end by up to the width's 0.71.
		var reach = width * .75;
		include(Math.min(x0, x1) - reach, Math.min(y0, y1) - reach, Math.max(x0, x1) + reach, Math.max(y0, y1) + reach);
	}

	/** A line through points (x and y in turn, copied), open, width wide. Its corners are pointed unless join says Round or Bevel, and its
		two ends are as cap says, as line's. A wall drawn as one polyline has no gaps at its corners, as separate lines would. False, holding
		nothing more, for fewer than 2 points. */
	public function polyline(points:Array<Float>, width:Float, color:Int, join:LineJoin2D = Miter, cap:LineCap2D = Butt):Bool {
		if (points.length < 4 || points.length % 2 != 0)
			return false;
		add(Polyline, [width, (join : Int), (cap : Int)], color);
		this.points[this.points.length - 1] = points.copy();
		// A miter can reach twice the width past a corner.
		includePoints(points, width * 2);
		return true;
	}

	/** A filled polygon through points (x and y in turn, copied; at least 3 points, convex or not, not crossing itself). False, holding
		nothing more, for fewer than 3 points or one that can't be filled. */
	public function polygon(points:Array<Float>, color:Int):Bool {
		if (points.length < 6 || points.length % 2 != 0)
			return false;
		var made = Polygon2D.triangulate(points);
		if (made.length == 0)
			return false;
		add(Polygon, [], color);
		this.points[this.points.length - 1] = points.copy();
		triangles[triangles.length - 1] = made;
		includePoints(points, 0);
		return true;
	}

	/** A polygon's outline through points (copied), closed, width wide centered on its edges, its corners pointed unless join says Round or
		Bevel. False, holding nothing more, for fewer than 2 points. */
	public function polygonLines(points:Array<Float>, width:Float, color:Int, join:LineJoin2D = Miter):Bool {
		if (points.length < 4 || points.length % 2 != 0)
			return false;
		add(PolygonLines, [width, (join : Int)], color);
		this.points[this.points.length - 1] = points.copy();
		// A miter can reach twice the width past a corner.
		includePoints(points, width * 2);
		return true;
	}

	/** texture drawn top-left at x, y, w x h, tinted (white by default): its region sourceX, sourceY, sourceWidth x sourceHeight in texels,
		or all of it when sourceWidth or sourceHeight is 0 or less; sampled as sampling says, or as the texture's sampling is when drawn when
		null. */
	public function image(texture:Texture2D, x:Float, y:Float, w:Float, h:Float, tint = 0xffffffff, sourceX = 0., sourceY = 0., sourceWidth = 0.,
			sourceHeight = 0., ?sampling:helix.texture.Sampling):Void {
		add(Image, [x, y, w, h, sourceX, sourceY, sourceWidth, sourceHeight], tint);
		images[images.length - 1] = texture;
		samplings[samplings.length - 1] = sampling;
		include(x, y, x + w, y + h);
	}

	/** Text wrapped to width (Font.wrap), its lines lineHeight times size apart, the first's top at y, each placed by align at x, in font
		(null for the batch's, the stage's font). Returns the height its lines take, as Batch2D's does, for placing what follows (one line's
		when no font is known: none given and no stage running). */
	public function drawTextWrapped(text:String, x:Float, y:Float, size:Float, width:Float, color:Int, align:Align2D = Left, lineHeight = 1.25,
			?font:Font):Float {
		add(WrappedText, [x, y, size, width, lineHeight], color);
		texts[texts.length - 1] = text;
		aligns[aligns.length - 1] = align;
		fonts[fonts.length - 1] = font;
		var measuring = font != null ? font : Stage.instance != null ? Stage.instance.font : null;
		return measuring != null ? measuring.measureWrapped(text, size, width, lineHeight) : size * lineHeight;
	}

	/** One line of text, its top at y and x its left edge, center or right edge by align, size tall, in font (null for the batch's). */
	public function drawText(text:String, x:Float, y:Float, size:Float, color:Int, align:Align2D = Left, ?font:Font):Void {
		add(Text, [x, y, size], color);
		texts[texts.length - 1] = text;
		aligns[aligns.length - 1] = align;
		fonts[fonts.length - 1] = font;
	}

	// A call of kind with its numbers and color.
	function add(kind:DrawingKind, values:Array<Float>, color:Int):Void {
		kinds.push(kind);
		starts.push(numbers.length);
		for (v in values)
			numbers.push(v);
		colors.push(color);
		texts.push(null);
		aligns.push(Left);
		fonts.push(null);
		triangles.push(null);
		points.push(null);
		images.push(null);
		samplings.push(null);
	}

	function include(x0:Float, y0:Float, x1:Float, y1:Float):Void {
		left = Math.min(left, x0);
		top = Math.min(top, y0);
		right = Math.max(right, x1);
		bottom = Math.max(bottom, y1);
	}

	function includePoints(points:Array<Float>, reach:Float):Void {
		var k = 0;
		while (k < points.length) {
			include(points[k] - reach, points[k + 1] - reach, points[k] + reach, points[k + 1] + reach);
			k += 2;
		}
	}

	// Its calls, where it is, when shown.
	override function drawOwn(batch:Batch2D, camera:Camera2D, time:Float, dt:Float, frozen:Bool, shown:Bool):Bool {
		if (shown) {
			batch.setTransform(wa, wb, wc, wd, wx, wy);
			batch.effect = effect;
			replay(batch);
			batch.effect = null;
		}
		return true;
	}

	override function get_picksOwn():Bool
		return true;

	// Itself, when pickable and its box (or a text it holds) has the point.
	override function pickOwn(x:Float, y:Float, lx:Float, ly:Float, font:Null<Font>):Null<Node2D>
		return pickable && holds(lx, ly, font) ? this : null;

	// Draws every call into batch, its transform set to this node's.
	function replay(batch:Batch2D):Void {
		for (i in 0...kinds.length) {
			var at = starts[i], n = numbers, c = colors[i];
			switch kinds[i] {
				case Rect:
					batch.rect(n[at], n[at + 1], n[at + 2], n[at + 3], c);
				case Frame:
					batch.frame(n[at], n[at + 1], n[at + 2], n[at + 3], n[at + 4], c);
				case RoundedRect:
					batch.roundedRect(n[at], n[at + 1], n[at + 2], n[at + 3], n[at + 4], c);
				case Circle:
					batch.circle(n[at], n[at + 1], n[at + 2], c);
				case CircleLines:
					batch.circleLines(n[at], n[at + 1], n[at + 2], n[at + 3], c);
				case Ellipse:
					batch.ellipse(n[at], n[at + 1], n[at + 2], n[at + 3], n[at + 4], c);
				case Line:
					batch.line(n[at], n[at + 1], n[at + 2], n[at + 3], n[at + 4], c, cast Std.int(n[at + 5]));
				case Polyline:
					batch.polyline(points[i], n[at], c, cast Std.int(n[at + 1]), cast Std.int(n[at + 2]));
				case Polygon:
					batch.polygon(points[i], c, triangles[i]);
				case PolygonLines:
					batch.polygonLines(points[i], n[at], c, cast Std.int(n[at + 1]));
				case Text:
					batch.drawText(texts[i], n[at], n[at + 1], n[at + 2], c, aligns[i], fonts[i]);
				case WrappedText:
					batch.drawTextWrapped(texts[i], n[at], n[at + 1], n[at + 2], n[at + 3], c, aligns[i], n[at + 4], fonts[i]);
				case Image:
					batch.samplingOverride = samplings[i];
					batch.image(images[i], n[at], n[at + 1], n[at + 2], n[at + 3], c, n[at + 4], n[at + 5], n[at + 6], n[at + 7]);
					batch.samplingOverride = null;
			}
		}
	}

	// Whether own point x, y is inside the box around what it holds, text measured in font (the batch's last, for text without its own).
	function holds(x:Float, y:Float, font:Null<Font>):Bool {
		if (x >= left && x <= right && y >= top && y <= bottom)
			return true;
		for (i in 0...kinds.length)
			if (kinds[i] == Text) {
				var f = fonts[i] != null ? fonts[i] : font;
				if (f == null)
					continue;
				var at = starts[i],
					size = numbers[at + 2],
					w = f.measure(texts[i], size);
				var x0 = numbers[at] - (aligns[i] == Center ? w / 2 : aligns[i] == Right ? w : 0),
					y0 = numbers[at + 1];
				if (x >= x0 && x <= x0 + w && y >= y0 && y <= y0 + size)
					return true;
			}
		return false;
	}

	override function measureOwn(font:Null<Font>, out:Bounds2D):Bool {
		out.set(left, top, right, bottom);
		for (i in 0...kinds.length)
			if (kinds[i] == Text) {
				var f = fonts[i] != null ? fonts[i] : font;
				if (f == null)
					continue;
				var at = starts[i],
					size = numbers[at + 2],
					w = f.measure(texts[i], size);
				var x0 = numbers[at] - (aligns[i] == Center ? w / 2 : aligns[i] == Right ? w : 0),
					y0 = numbers[at + 1];
				out.expand(x0, y0).expand(x0 + w, y0 + size);
			}
		return !out.isEmpty;
	}
}

/** What a Drawing2D call draws. */
private enum abstract DrawingKind(Int) {
	var Rect;
	var Frame;
	var RoundedRect;
	var Circle;
	var CircleLines;
	var Ellipse;
	var Line;
	var Polyline;
	var Polygon;
	var PolygonLines;
	var Text;
	var WrappedText;
	var Image;
}
