package helix.render2d;

import helix.texture.Texture2D;
import helix.font.Font;
import helix.math.Bounds2D;

/** A sprite: a texture (or a region of it, or a SpriteSheet2D's frame) drawn as a rectangle, its region's size in texels unless sized, its pivot at its position (its
	top left by default, as every 2D kind's but a circle's), tinted (0xAARRGGBB). Its scale scales it and its rotation turns it, about its pivot; a nine-slice frame keeps its
	corners' size as it's sized (setNineSlice). It may draw through an effect (effect). */
@:allow(helix.render2d.Renderer2D)
class Sprite2D extends Node2D {
	var sliceLeft = 0.;
	var sliceTop = 0.;
	var sliceRight = 0.;
	var sliceBottom = 0.;
	var sourceX = 0.;
	var sourceY = 0.;
	var sourceWidth = 0.;
	var sourceHeight = 0.;
	var givenWidth = 0.;
	var givenHeight = 0.;

	/** A sprite of texture (null for none yet: it draws nothing), the whole texture at its size in texels, turning about its center, tinted
		(0xAARRGGBB, white for none). */
	public function new(texture:Null<Texture2D>, tint = 0xffffffff) {
		super();
		this.texture = texture;
		this.tint = tint;
	}

	/** Its texture, or null: it draws nothing. */
	public var texture:Null<Texture2D>;

	/** What its texels are multiplied by, 0xAARRGGBB: white leaves them as they are. */
	public var tint:Int = 0xffffffff;

	/** How its texture is sampled, in place of the texture's own (Texture2D.sampling), or null for the texture's: the same texture drawn sharp
		here and smooth elsewhere. */
	public var sampling:Null<helix.texture.Sampling>;

	/** Its region of its texture, in texels from its top-left; a width or height of 0 or less (the default) shows the whole texture. It shows
		no sheet's frame after (setFrame). */
	public function setRegion(x:Float, y:Float, width:Float, height:Float):Void {
		frame = null;
		sourceX = x;
		sourceY = y;
		sourceWidth = width;
		sourceHeight = height;
	}

	/** Shows sheet's frame at index (a SpriteAnimator2D given the sprite shows its frames so): its texture becomes the sheet's, its size the frame's
		whole picture (unless sized), its pivot the frame's when its file gives one. A trimmed frame draws where it was in its picture, a rotated
		one upright; a frame draws whole, not as a nine-slice. False, changing nothing, for an index the sheet hasn't. */
	public function setFrame(sheet:SpriteSheet2D, index:Int):Bool {
		var next = sheet.getFrame(index);
		if (next == null)
			return false;
		frame = next;
		texture = sheet.texture;
		if (next.hasPivot)
			setPivot(next.pivotX, next.pivotY);
		return true;
	}

	/** The sheet's frame it shows (setFrame), or null: it shows its region. */
	public var frame(default, null):Null<SpriteFrame2D>;

	/** Its region's left, in texels. */
	public var regionX(get, never):Float;

	function get_regionX():Float
		return sourceX;

	/** Its region's top, in texels. */
	public var regionY(get, never):Float;

	function get_regionY():Float
		return sourceY;

	/** Its region's width in texels: its frame's whole picture's when it shows one, else what was set, or else its texture's (0 without one). */
	public var regionWidth(get, never):Float;

	function get_regionWidth():Float
		return frame != null ? frame.sourceWidth : sourceWidth > 0 && sourceHeight > 0 ? sourceWidth : texture == null ? 0 : texture.width;

	/** Its region's height in texels: its frame's whole picture's when it shows one, else what was set, or else its texture's (0 without one). */
	public var regionHeight(get, never):Float;

	function get_regionHeight():Float
		return frame != null ? frame.sourceHeight : sourceWidth > 0
			&& sourceHeight > 0 ? sourceHeight : texture == null ? 0 : texture.height;

	// Its region's left and top as drawn: 0, 0 for the whole texture.
	function drawnRegionX():Float
		return sourceWidth > 0 && sourceHeight > 0 ? sourceX : 0.;

	function drawnRegionY():Float
		return sourceWidth > 0 && sourceHeight > 0 ? sourceY : 0.;

	/** The width it draws at, in its own units: as sized, else its region's in texels. */
	public var width(get, never):Float;

	function get_width():Float
		return givenWidth > 0 && givenHeight > 0 ? givenWidth : regionWidth;

	/** The height it draws at, in its own units: as sized, else its region's in texels. */
	public var height(get, never):Float;

	function get_height():Float
		return givenWidth > 0 && givenHeight > 0 ? givenHeight : regionHeight;

	/** Sizes it, in its own units; a width or height of 0 or less goes back to its region's size. */
	public function setSize(width:Float, height:Float):Void {
		givenWidth = width;
		givenHeight = height;
	}

	/** Sets the point at its position, which it turns and scales about, as a fraction of its size: 0, 0 its top-left, 1, 1 its bottom-right
		(0, 0 to start, as every 2D kind; setPivot(.5, .5) for a sprite that turns about its middle). */
	public function setPivot(x:Float, y:Float):Void {
		pivotX = x;
		pivotY = y;
	}

	/** Its pivot's x fraction. */
	public var pivotX(default, null):Float = 0.;

	/** Its pivot's y fraction. */
	public var pivotY(default, null):Float = 0.;

	/** Draws it as a nine-slice frame (Batch2D.nineSlice): its region's corners left, top, right and bottom texels in from its edges keep their
		size as it's sized, its edges and middle stretch. All 0 (the start) draws it stretched whole. False, changing nothing, for an inset
		below 0. */
	public function setNineSlice(left:Float, top:Float, right:Float, bottom:Float):Bool {
		if (!(left >= 0 && top >= 0 && right >= 0 && bottom >= 0))
			return false;
		sliceLeft = left;
		sliceTop = top;
		sliceRight = right;
		sliceBottom = bottom;
		return true;
	}

	/** Its nine-slice's left inset, texels. */
	public var nineSliceLeft(get, never):Float;

	function get_nineSliceLeft():Float
		return sliceLeft;

	/** Its nine-slice's top inset, texels. */
	public var nineSliceTop(get, never):Float;

	function get_nineSliceTop():Float
		return sliceTop;

	/** Its nine-slice's right inset, texels. */
	public var nineSliceRight(get, never):Float;

	function get_nineSliceRight():Float
		return sliceRight;

	/** Its nine-slice's bottom inset, texels. */
	public var nineSliceBottom(get, never):Float;

	function get_nineSliceBottom():Float
		return sliceBottom;

	/** Whether it draws as a nine-slice frame. */
	public var nineSlice(get, never):Bool;

	function get_nineSlice():Bool
		return sliceLeft > 0 || sliceTop > 0 || sliceRight > 0 || sliceBottom > 0;

	override function measureOwn(font:Null<Font>, out:Bounds2D):Bool {
		var w = width, h = height;
		if (texture == null || w <= 0 || h <= 0)
			return false;
		out.set(-pivotX * w, -pivotY * h, (1 - pivotX) * w, (1 - pivotY) * h);
		return true;
	}
}
