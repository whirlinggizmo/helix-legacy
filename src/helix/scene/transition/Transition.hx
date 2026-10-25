package helix.scene.transition;

import helix.render2d.Drawing2D;
import helix.render2d.Node2D;
import helix.render2d.Stage;
import helix.scene.Flow;

/** How one screen gives way to the next on the stage (docs/DISPLAY_MODEL.md): a cover drawn over everything. Run whole (run, swap), it
	covers for coverSeconds, swaps what's shown at the middle, stays covered for hold seconds and uncovers for uncoverSeconds, after a delay
	when given, each half along its own ease. Or in halves: cover covers and stays covered (game over, a load under the cover) until uncover
	is called, and uncover alone, from covered, is a fade in from black at the start. It runs itself on the frames' time, not the game's
	clock, so a paused game still transitions to its menu; quick (the run option quick=1) skips it, swapping at once. The kinds made (Fade,
	Slide, Iris, Diamond, Noise) each draw their cover; a game's own extends this and draws anything into its cover by progress (draw). */
class Transition {
	/** A transition taking seconds, half covering and half uncovering (coverSeconds, uncoverSeconds). Throws for 0 or less. */
	public function new(seconds:Float) {
		if (!(seconds > 0))
			throw 'A transition takes some time, not $seconds';
		coverSeconds = uncoverSeconds = seconds / 2;
	}

	/** Seconds it takes to cover, from its start (after its delay) to its middle, where what's shown swaps: half the seconds it was made
		with to start; 0 for less (covered at once). A quick close and a slow open: coverSeconds .2, uncoverSeconds .8. */
	public var coverSeconds(default, set):Float;

	function set_coverSeconds(value:Float):Float
		return coverSeconds = value > 0 ? value : 0;

	/** Seconds it takes to uncover, from the end of its hold to its end: half the seconds it was made with to start; 0 for less. */
	public var uncoverSeconds(default, set):Float;

	function set_uncoverSeconds(value:Float):Float
		return uncoverSeconds = value > 0 ? value : 0;

	/** How long it covers and uncovers, its delay and hold aside: coverSeconds and uncoverSeconds together. */
	public var seconds(get, never):Float;

	function get_seconds():Float
		return coverSeconds + uncoverSeconds;

	/** Whether it's running now: from run or cover through its delay and covering, while covered, and through its uncovering. */
	public var running(default, null):Bool = false;

	/** Whether it's fully covered now: after cover until uncover (or through run's hold). */
	public var covered(get, never):Bool;

	function get_covered():Bool
		return phase == COVERED;

	/** Where it is, as last drawn: 0 to .5 covering, .5 covered (at the middle and through its hold), .5 to 1 uncovering, each half
		after its ease; 0 before it starts (and through its delay), 1 once done. */
	public var progress(default, null):Float = 0;

	/** Seconds after run before it starts covering, nothing drawn meanwhile: 0 to start (and for less). */
	public var delay(default, set):Float = 0;

	function set_delay(value:Float):Float
		return delay = value > 0 ? value : 0;

	/** Seconds it stays fully covered at its middle, after the swap and before it uncovers: 0 to start (and for less). */
	public var hold(default, set):Float = 0;

	function set_hold(value:Float):Float
		return hold = value > 0 ? value : 0;

	/** How its first half goes, an easing from time to progress, 0 to 1 (helix.tween.Ease's, called from a lambda so a hot reload reaches
		it: t -> Ease.quadIn(t) starts slow): linear to start. What it gives is held to 0..1, so a curve past the ends (back, elastic) can't
		overshoot the cover. */
	public var coverEase:Float->Float = t -> t;

	/** How its second half goes, as coverEase: linear to start. */
	public var uncoverEase:Float->Float = t -> t;

	/** Draws the cover at progress 0 to 1 (the swap at .5) into cover (cleared before each call, over everything on the stage, in the stage's
		units), the visible area x, y, width x height. Nothing by default. */
	public function draw(cover:Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void {}

	// Where it is: idle, waiting out its delay, covering, covered, or uncovering; seconds into that, and what's called next.
	static inline var IDLE = 0;
	static inline var WAITING = 1;
	static inline var COVERING = 2;
	static inline var COVERED = 3;
	static inline var UNCOVERING = 4;

	var phase = IDLE;
	var phaseSeconds = 0.;
	// Called once covered; seconds covered before uncovering on its own (run's hold), or -1 to stay until uncover; called once uncovered.
	var whenCovered:Null<Void->Void>;
	var holdLeft = -1.;
	var whenUncovered:Null<Void->Void>;
	var coverNode:Null<Drawing2D>;

	/** Covers the stage after its delay, over coverSeconds, and stays covered until uncover is called: done (when given) once covered (put
		the next screen on the stage there, or start a load under the cover). False, doing nothing, while it's running already. */
	public function cover(?done:Void->Void):Bool {
		if (running)
			return false;
		if (Flow.quick) {
			start(COVERED);
			if (done != null)
				done();
			return true;
		}
		whenCovered = done;
		holdLeft = -1;
		start(delay > 0 ? WAITING : COVERING);
		return true;
	}

	/** Uncovers the stage over uncoverSeconds, done (when given) at its end: from covered (after cover), or, not running, from fully covered
		at once (a fade in from black as a game starts). While it's still covering, it uncovers once covered. False, doing nothing, while it's
		uncovering already. */
	public function uncover(?done:Void->Void):Bool {
		if (phase == UNCOVERING)
			return false;
		whenUncovered = done;
		if (phase == WAITING || phase == COVERING) {
			holdLeft = 0;
			return true;
		}
		if (phase == IDLE)
			start(UNCOVERING);
		else
			enter(UNCOVERING);
		if (Flow.quick)
			finish();
		return true;
	}

	/** Runs it over the stage, after its delay: atMiddle at its middle (swap what's shown there), held covered for its hold, done (when
		given) at its end. False, running nothing, while it's running already. */
	public function run(atMiddle:Void->Void, ?done:Void->Void):Bool {
		if (running)
			return false;
		if (Flow.quick) {
			atMiddle();
			if (done != null)
				done();
			return true;
		}
		whenCovered = atMiddle;
		whenUncovered = done;
		holdLeft = hold;
		start(delay > 0 ? WAITING : COVERING);
		return true;
	}

	// Puts the cover on the stage and runs it from phase on the frames' time.
	function start(from:Int):Void {
		running = true;
		var node = new Drawing2D();
		node.pickable = false;
		coverNode = node;
		Stage.addChild(node);
		enter(from);
		Flow.run(dt -> step(Math.max(0, dt)));
	}

	function enter(next:Int):Void {
		phase = next;
		phaseSeconds = 0;
		if (next == COVERED) {
			var then = whenCovered;
			whenCovered = null;
			if (then != null)
				then();
			// Over what the swap put on the stage.
			if (coverNode != null)
				Stage.addChild(coverNode);
		}
	}

	// A frame of it, dt seconds on: its phase moved on, its cover drawn; false once it's done.
	function step(dt:Float):Bool {
		if (phase == IDLE)
			return false;
		phaseSeconds += dt;
		// Each phase's end within this frame starts the next with the time left over.
		inline function next(end:Float, to:Int):Void {
			// Rounding below a nanosecond is none (a frame's .05 and .2 reaching a .25 hold).
			var over = phaseSeconds - end;
			if (over < 1e-9)
				over = 0;
			enter(to);
			phaseSeconds = over;
		}
		if (phase == WAITING && phaseSeconds >= delay)
			next(delay, COVERING);
		if (phase == COVERING && phaseSeconds >= coverSeconds)
			next(coverSeconds, COVERED);
		if (phase == COVERED && holdLeft >= 0 && phaseSeconds >= holdLeft)
			next(holdLeft, UNCOVERING);
		if (phase == UNCOVERING && phaseSeconds >= uncoverSeconds) {
			finish();
			return false;
		}
		inline function eased(curve:Float->Float, t:Float):Float {
			var v = curve(t < 1 ? t : 1);
			return v > 0 ? (v < 1 ? v : 1) : 0;
		}
		var drawn = switch phase {
			case COVERING: eased(coverEase, coverSeconds > 0 ? phaseSeconds / coverSeconds : 1) * .5;
			case COVERED: .5;
			case UNCOVERING: .5 + eased(uncoverEase, uncoverSeconds > 0 ? phaseSeconds / uncoverSeconds : 1) * .5;
			case _: -1.;
		};
		progress = drawn >= 0 ? drawn : 0;
		var area = helix.host.Screen.instance;
		coverNode.clear();
		if (drawn >= 0)
			draw(coverNode, area.visibleX, area.visibleY, area.visibleWidth, area.visibleHeight, drawn);
		return true;
	}

	// Done: the cover off the stage, done called.
	function finish():Void {
		if (coverNode != null)
			Stage.removeChild(coverNode);
		coverNode = null;
		phase = IDLE;
		running = false;
		progress = 1;
		var then = whenUncovered;
		whenUncovered = null;
		if (then != null)
			then();
	}

	/** Runs it, taking from off the stage and putting to on it at its middle (either null for none), done (when given) at its end. False,
		running nothing, while it's running already. */
	public function swap(from:Null<Node2D>, to:Null<Node2D>, ?done:Void->Void):Bool
		return run(() -> {
			if (from != null)
				Stage.removeChild(from);
			if (to != null)
				Stage.addChild(to);
		}, done);
}
