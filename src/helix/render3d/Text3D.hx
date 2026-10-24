package helix.render3d;

import helix.font.Font;
import helix.math.Bounds3D;

/** A line of text in the world: its value, size world units tall (ascent to descent), in a font (null: the stage's built-in one), its block's
	pivot at its position (its center by default), facing the camera, in a color (0xAARRGGBB, sRGB). Unlit and blended, as sprites are, and
	sharp at any distance (a distance-field font). Pivoted and faced as a sprite. Not pickable until pickable is set: a label lets a pick
	through to what it's on. */
class Text3D extends Node3D {
	var size:Float;

	/** value, size world units tall (a size of 0 or less is 0.5), in color, in font (null: the stage's built-in one). */
	public function new(value:String, size = .5, color = 0xffffffff, ?font:Font) {
		super();
		text = value;
		this.size = size > 0 ? size : .5;
		this.color = color;
		this.font = font;
		pickable = false;
	}

	/** Its text. */
	public var text:String;

	/** Its size, world units tall. At least 1e-6 (0 or less, or NaN, is 1e-6). */
	public var textSize(get, set):Float;

	function get_textSize():Float
		return size;

	function set_textSize(value:Float):Float {
		value = value > 1e-6 ? value : 1e-6;
		size = value;
		return value;
	}

	/** Its color, 0xAARRGGBB (sRGB). */
	public var color:Int;

	/** Its font, or null for the stage's built-in one. */
	public var font:Null<Font>;

	/** Sets the point of its block at its position, which it turns and scales about, as a fraction of its size: 0, 0 its top-left, 1, 1 its
		bottom-right (0.5, 0.5, its center, by default). */
	public function setPivot(x:Float, y:Float):Void {
		pivotX = x;
		pivotY = y;
	}

	/** Its pivot's x fraction. */
	public var pivotX(default, null):Float = .5;

	/** Its pivot's y fraction. */
	public var pivotY(default, null):Float = .5;

	/** How it faces. */
	public var facing:SpriteFacing3D = Camera;

	/** Its width in its own units, in its font (the built-in one when it has none), as Text2D measures. */
	public function measureWidth():Float
		return (font != null ? font : helix.render2d.Stage.font).measure(text, size);

	/** Its height in its own units: its size (one line, ascent to descent), as Text2D measures. */
	public function measureHeight():Float
		return size;

	override function get_spriteKind():Node3D.SpriteKind3D
		return Flat;

	override function attachSprites(renderer:Renderer3D):Void
		Sprites3D.attach(renderer);

	override function visitSprites(sprites:Any, planes:haxe.ds.Vector<Float>, eyeX:Float, eyeY:Float, eyeZ:Float, forwardX:Float, forwardY:Float,
			forwardZ:Float, still:Bool):Void
		(sprites : Sprites3D).visitText(this, planes, eyeX, eyeY, eyeZ, forwardX, forwardY, forwardZ);

	override function pickSprites(sprites:Any, ray:Ray3D, best:Float, hit:PickHit3D):Float
		return (sprites : Sprites3D).pickText(this, ray, best, hit);

	override function hitQuad(sprites:Any, out:Array<Float>):Bool
		return (sprites : Sprites3D).textQuad(this, out);

	// The font it was last drawn in (its own, or the stage's built-in one), for measuring it; null before a draw when it has none of its own.
	@:allow(helix.render3d.Sprites3D)
	var drawnFont:Null<Font>;

	// The box its block can reach, placed by world, as it faces (Sprites3D.measureQuad): measured in its font, or the one it was last drawn
	// or picked in; nothing before then when it has none of its own. Node3D.computeBounds.
	override function measureOwnWorld(world:Mat4, out:Bounds3D):Void {
		var measuring = font != null ? font : drawnFont;
		if (measuring != null && text.length > 0)
			Sprites3D.measureQuad(world, facing, pivotX, pivotY, measuring.measure(text, size), size, out);
	}
}
