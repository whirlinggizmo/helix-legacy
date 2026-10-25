package helix.scene.transition;

import helix.render2d.Drawing2D;

/** A hole in the cover closing on a point until all is covered at the middle, where what's shown swaps, then opening from it: the hole
	round (Iris) or a diamond (Diamond). The point is the stage's, read as it draws, so it can follow something moving; the middle of the
	visible area unless set. */
class Closing extends Transition {
	/** A close and open over seconds in color (0xAARRGGBB). */
	function new(seconds:Float, color:Int) {
		super(seconds);
		this.color = color;
	}

	/** Its color, 0xAARRGGBB: set it any time. */
	public var color:Int;

	/** The point it closes on and opens from, in the stage's units; NaN (the default) for the middle of the visible area. */
	public var pointX:Float = Math.NaN;

	/** The point's y; NaN for the middle. */
	public var pointY:Float = Math.NaN;

	/** Sets the point it closes on and opens from, in the stage's units. */
	public function setPoint(x:Float, y:Float):Void {
		pointX = x;
		pointY = y;
	}

	override public function draw(cover:Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void {
		var cx = Math.isNaN(pointX) ? x + width / 2 : pointX,
			cy = Math.isNaN(pointY) ? y + height / 2 : pointY;
		var reach = reachOf(cx - x, cy - y, x + width - cx, y + height - cy);
		var size = reach * (progress < .5 ? 1 - progress * 2 : (progress - .5) * 2);
		if (size < .5) {
			cover.rect(x, y, width, height, color);
			return;
		}
		// The cover as two pieces round the hole, above and below a line through the point, over an area holding the visible one and the hole.
		var left = Math.min(x, cx - size) - 1,
			right = Math.max(x + width, cx + size) + 1,
			top = Math.min(y, cy - size) - 1,
			bottom = Math.max(y + height, cy + size) + 1;
		var upper = [left, top, right, top, right, cy], lower = [left, cy];
		var edge = rim(cx, cy, size);
		// The rim from its right round over the top to its left, then on under the bottom back to the right.
		var half = Std.int(edge.length / 4);
		for (i in 0...half + 1) {
			upper.push(edge[i * 2]);
			upper.push(edge[i * 2 + 1]);
		}
		upper.push(left);
		upper.push(cy);
		for (i in half...half * 2 + 1) {
			var at = i % (half * 2);
			lower.push(edge[at * 2]);
			lower.push(edge[at * 2 + 1]);
		}
		lower.push(right);
		lower.push(cy);
		lower.push(right);
		lower.push(bottom);
		lower.push(left);
		lower.push(bottom);
		cover.polygon(upper, color);
		cover.polygon(lower, color);
	}

	// How far the hole must open from the point to show the whole visible area, the point left, top, right and bottom of its edges.
	function reachOf(left:Float, top:Float, right:Float, bottom:Float):Float
		return 0;

	// The hole's rim round cx, cy at size, from its right point counterclockwise on screen (up first), an even count of points, x and y in turn.
	function rim(cx:Float, cy:Float, size:Float):Array<Float>
		return [];
}
