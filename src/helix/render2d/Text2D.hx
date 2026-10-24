package helix.render2d;

import helix.font.Font;
import helix.math.Bounds2D;

/** A line of text in the 2D world: its value, size units tall (ascent to descent), in a color (0xAARRGGBB) and a font (null: the built-in
	one). Its position is its pivot, as a sprite's is: setPivot(.5, .5) centers it there, (1, 0) puts its top right there; its top left to
	start. Wrapped to a width, it is a block of lines (setWrapWidth) whose lines line up by align. Not pickable until pickable is set: a label
	lets the pointer through to what it's on. Batch2D.drawText draws text without a node; Font.measure measures it. */
class Text2D extends Node2D {
	var size:Float;

	/** value, size units tall (0 or less, or NaN, is 1e-6), in color, in font (null: the built-in one), its top left at its position. */
	public function new(value:String, size = 16., color = 0xffffffff, ?font:Font) {
		super();
		text = value;
		this.size = size > 1e-6 ? size : 1e-6;
		this.color = color;
		this.font = font;
		pickable = false;
	}

	/** Puts its pivot, the point of it at its position, at x, y fractions of its measured box (measureWidth by measureHeight): 0, 0 its top
		left, .5, .5 its center, 1, 1 its bottom right. A pivot follows the text as it changes: a centered score stays centered. */
	public function setPivot(x:Float, y:Float):Void {
		pivotX = x;
		pivotY = y;
	}

	/** Its pivot's x fraction: 0 to start. */
	public var pivotX(default, null):Float = 0.;

	/** Its pivot's y fraction: 0 to start. */
	public var pivotY(default, null):Float = 0.;

	/** Its text. */
	public var text:String;

	/** Its size, units tall (ascent to descent). At least 1e-6 (0 or less, or NaN, is 1e-6). */
	public var textSize(get, set):Float;

	function get_textSize():Float
		return size;

	function set_textSize(value:Float):Float {
		size = value > 1e-6 ? value : 1e-6;
		return size;
	}

	/** Its color, 0xAARRGGBB. */
	public var color:Int;

	/** How a wrapped block's lines line up with each other: their left edges, centers or right edges. One line has nothing to line up with;
		its pivot places it. Left to start. */
	public var align:Align2D = Left;

	/** Its font, or null for the built-in one. */
	public var font:Null<Font>;

	/** Its wrap width in its own units: 0 for one line. */
	public var wrapWidth(default, null):Float = 0.;

	/** Its wrapped lines apart, times its size. */
	public var lineHeight(default, null):Float = 1.25;

	/** Wraps it to width in its own units (Font.wrap), its lines lineHeight times its size apart; 0 for one line. False, changing nothing, for a
		width below 0 or a line height of 0 or less. */
	public function setWrapWidth(width:Float, lineHeight = 1.25):Bool {
		if (!(width >= 0) || !(lineHeight > 0))
			return false;
		wrapWidth = width;
		this.lineHeight = lineHeight;
		return true;
	}

	/** Its width in its own units, in its font (the built-in one when it has none): its wrap width, or its one line's. */
	public function measureWidth():Float
		return widthIn(drawnFont());

	/** Its height in its own units, in its font (the built-in one when it has none): its size, or its wrapped lines'. */
	public function measureHeight():Float
		return heightIn(drawnFont());

	// The font it's drawn in: its own, or the built-in one (the stage's).
	function drawnFont():Font
		return font != null ? font : Stage.font;

	// Its width and height as drawn with fallback for its font when it has none: what a renderer measures with (its batch's font), needing
	// no stage.

	@:allow(helix)
	function widthIn(fallback:Font):Float
		return wrapWidth > 0 ? wrapWidth : (font != null ? font : fallback).measure(text, size);

	@:allow(helix)
	function heightIn(fallback:Font):Float {
		if (wrapWidth <= 0)
			return size;
		var lines = (font != null ? font : fallback).wrap(text, size, wrapWidth).length;
		return size * (1 + lineHeight * (lines - 1));
	}

	// Its box's top left in its own units, from its pivot, for a box w by h.

	@:allow(helix)
	inline function left(w:Float):Float
		return -pivotX * w;

	@:allow(helix)
	inline function top(h:Float):Float
		return -pivotY * h;

	override function measureOwn(font:Null<Font>, out:Bounds2D):Bool {
		var f = this.font != null ? this.font : font;
		if (f == null)
			return false;
		var w = widthIn(f), h = heightIn(f);
		out.set(left(w), top(h), left(w) + w, top(h) + h);
		return true;
	}
}
