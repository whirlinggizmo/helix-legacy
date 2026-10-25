package helix.scene.transition;

import helix.graphics.Color;
import helix.render2d.Drawing2D;

/** A fade to a color and back: covered at the middle, where what's shown swaps. */
class Fade extends Transition {
	/** A fade over seconds (half a second unless given) through color (black unless given, 0xAARRGGBB, its alpha the cover at the middle). */
	public function new(seconds = .5, color = 0xff000000) {
		super(seconds);
		this.color = color;
	}

	/** Its color, 0xAARRGGBB: set it any time. */
	public var color:Int;

	override public function draw(cover:Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void {
		var amount = progress < .5 ? progress * 2 : (1 - progress) * 2;
		cover.rect(x, y, width, height, Color.withAlpha(color, Math.round(Color.getAlpha(color) * amount)));
	}
}
