package helix.ui;

import helix.input.Actions;
import helix.render2d.Batch2D;
import helix.render2d.Camera2D;
import helix.render2d.Drawing2D;

/** A touch stick drawn while it's held (Binding.TouchStick): a ring where the finger landed, its radius the stick's, and a knob under the
	finger, kept within the ring. Draws nothing while no finger holds it, so it shows only on a touch screen in use. It needs no Ui and runs
	itself: add it to the stage, over the game: Stage.addChild(new TouchStick2D(actions, "moveX")), naming an action bound to the stick.
	With hint on, a faint ring and knob say where a thumb goes while no finger holds it: the bottom left for the whole screen or the left
	half, the bottom right for the right half, a region's center. */
class TouchStick2D extends Drawing2D {
	/** The stick of action in actions drawn (its first touch stick binding that's held), in color (0xAARRGGBB: a light gray, half seen,
		unless given). */
	public function new(actions:Actions, action:String, color = 0x80e8e8e8) {
		super();
		this.actions = actions;
		this.action = action;
		this.color = color;
		pickable = false;
	}

	/** The actions it reads. */
	public var actions:Actions;

	/** The action whose stick it draws. */
	public var action:String;

	/** Its color, 0xAARRGGBB: the ring's, and the knob's a little more opaque. */
	public var color:Int;

	/** Whether to draw the idle hint while no finger holds it: off to start (a game turns it on once it has seen a touch, say). */
	public var hint:Bool = false;

	/** How far in from the visible area's corner the hint's ring sits, the stage's units: 40 to start. */
	public var hintMargin:Float = 40;

	// The frame it was last drawn at: once a frame, however many views show its tree.
	var refreshedAt = Math.NaN;
	var held = [0., 0., 0., 0., 0., 0., 0.];

	override function drawOwn(batch:Batch2D, camera:Camera2D, time:Float, dt:Float, frozen:Bool, shown:Bool):Bool {
		if (refreshedAt != time) {
			refreshedAt = time;
			refresh();
		}
		return super.drawOwn(batch, camera, time, dt, frozen, shown);
	}

	// The ring where the finger landed and the knob where it is, held to the ring's edge; while no finger holds the stick, the hint or
	// nothing.
	function refresh():Void {
		clear();
		if (actions == null)
			return;
		if (!actions.heldStick(action, held, hintMargin)) {
			var radius = held[4];
			if (hint && radius > 0) {
				var faint = (Std.int((color >>> 24) * .4) << 24) | (color & 0xffffff), x = held[5], y = held[6];
				circleLines(x, y, radius, Math.max(2, radius / 24), faint);
				circle(x, y, radius * .4, faint);
			}
			return;
		}
		var cx = held[0], cy = held[1], radius = held[4];
		var dx = held[2] - cx,
			dy = held[3] - cy,
			length = Math.sqrt(dx * dx + dy * dy);
		if (length > radius) {
			dx *= radius / length;
			dy *= radius / length;
		}
		var alpha = color >>> 24,
			knob = (Std.int(Math.min(255, alpha * 1.5)) << 24) | (color & 0xffffff);
		circleLines(cx, cy, radius, Math.max(2, radius / 16), color);
		circle(cx + dx, cy + dy, radius * .4, knob);
	}
}
