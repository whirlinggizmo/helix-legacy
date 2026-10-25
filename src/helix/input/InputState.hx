package helix.input;

/** A touch as it's tracked: changed in place as its finger moves. */
private typedef TouchState = {
	var id:Int;
	var x:Float;
	var y:Float;
	var down:Bool;
	var pressed:Bool;
	var released:Bool;
}

/** The input an app reads, as edges and state: fed by the InputRouter from a platform's events, or directly by replay and tests.
	Tick edges (isPressed, isReleased) are counted, and consume() after a simulation tick takes one of each, so every press is seen by exactly one tick,
	and two presses between ticks reach two ticks;
	frame edges (isFramePressed, isFrameReleased), typed text, the wheel and lifted touches last one frame, until endFrame() (the InputRouter's, which the Runner calls). */
class InputState implements IInput {
	var held:Array<Bool> = [for (_ in 0...Key.COUNT) false];
	var pushes:Array<Int> = [for (_ in 0...Key.COUNT) 0];
	var lifts:Array<Int> = [for (_ in 0...Key.COUNT) 0];
	var framePushes:Array<Bool> = [for (_ in 0...Key.COUNT) false];
	var frameLifts:Array<Bool> = [for (_ in 0...Key.COUNT) false];
	var claimed:Array<Bool> = [for (_ in 0...Key.COUNT) false];
	var mouseHeld = [false, false, false];
	var mousePushes = [0, 0, 0];
	var mouseLifts = [0, 0, 0];
	var mouseFramePushes = [false, false, false];
	var mouseFrameLifts = [false, false, false];
	var pads:Array<Gamepad> = [for (_ in 0...4) new Gamepad()];
	var pointerPushes = 0;
	var pointerLifts = 0;
	var touchStates:Array<TouchState> = [];
	var watchers:Array<IInputWatcher> = [];

	/** The gesture's pan x, y, log scale and rotation summed this frame, and since the last tick. */
	var frameGesture = [0., 0., 0., 0.];

	var tickGesture = [0., 0., 0., 0.];

	/** Nothing held, the pointer off the window, and four empty pad slots. */
	var anyFramePress = false;

	/** Nothing down, nothing pressed, no pad connected, not activated. */
	public function new() {}

	public function isDown(key:Key):Bool
		return held[key] && !claimed[key];

	public function isPressed(key:Key):Bool
		return pushes[key] > 0;

	public function isReleased(key:Key):Bool
		return lifts[key] > 0;

	public function isFramePressed(key:Key):Bool
		return framePushes[key];

	public function isFrameReleased(key:Key):Bool
		return frameLifts[key];

	public function claim(key:Key):Void {
		claimed[key] = true;
		pushes[key] = 0;
		lifts[key] = 0;
		framePushes[key] = false;
		frameLifts[key] = false;
	}

	public function isClaimed(key:Key):Bool
		return claimed[key];

	@:isVar public var pointerX(get, null):Float = -1.;

	function get_pointerX():Float
		return pointerX;

	@:isVar public var pointerY(get, null):Float = -1.;

	function get_pointerY():Float
		return pointerY;

	@:isVar public var pointerDown(get, null):Bool = false;

	function get_pointerDown():Bool
		return pointerDown;

	public var pointerPressed(get, never):Bool;

	function get_pointerPressed():Bool
		return pointerPushes > 0;

	public var pointerReleased(get, never):Bool;

	function get_pointerReleased():Bool
		return pointerLifts > 0;

	@:isVar public var pointerFramePressed(get, null):Bool = false;

	function get_pointerFramePressed():Bool
		return pointerFramePressed;

	@:isVar public var pointerFrameReleased(get, null):Bool = false;

	function get_pointerFrameReleased():Bool
		return pointerFrameReleased;

	@:isVar public var wheelX(get, null):Float = 0.;

	function get_wheelX():Float
		return wheelX;

	@:isVar public var wheelY(get, null):Float = 0.;

	function get_wheelY():Float
		return wheelY;

	@:isVar public var text(get, null):String = "";

	function get_text():String
		return text;

	@:isVar public var textEntry(get, set):Bool = false;

	function get_textEntry():Bool
		return textEntry;

	function set_textEntry(on:Bool):Bool {
		textEntry = on;
		return on;
	}

	public var touches(get, never):Array<Touch>;

	function get_touches():Array<Touch>
		return [
			for (t in touchStates)
				{
					id: t.id,
					x: t.x,
					y: t.y,
					down: t.down,
					pressed: t.pressed,
					released: t.released
				}
		];

	public var padCount(get, never):Int;

	function get_padCount():Int
		return pads.length;

	public function getPad(index:Int):Null<Gamepad>
		return index >= 0 && index < pads.length ? pads[index] : null;

	public function isMouseDown(button:MouseButton):Bool
		return mouseHeld[button];

	public function isMousePressed(button:MouseButton):Bool
		return mousePushes[button] > 0;

	public function isMouseFramePressed(button:MouseButton):Bool
		return mouseFramePushes[button];

	public function isMouseReleased(button:MouseButton):Bool
		return mouseLifts[button] > 0;

	public function isMouseFrameReleased(button:MouseButton):Bool
		return mouseFrameLifts[button];

	public function isPadDown(button:PadButton):Bool {
		for (pad in pads)
			if (pad.connected && pad.isDown(button))
				return true;
		return false;
	}

	public function isPadPressed(button:PadButton):Bool {
		for (pad in pads)
			if (pad.connected && pad.isPressed(button))
				return true;
		return false;
	}

	public function getPadAxis(axis:PadAxis):Float {
		for (pad in pads)
			if (pad.connected)
				return pad.getAxis(axis);
		return 0;
	}

	@:isVar public var activated(get, null):Bool = false;

	function get_activated():Bool
		return activated;

	public var anyFramePressed(get, never):Bool;

	function get_anyFramePressed():Bool
		return anyFramePress;

	/** A key down (true) or up (false); only a change of state counts an edge, so key repeat doesn't. A down activates (activated). */
	public function keyEvent(key:Key, value:Bool):Void {
		if (value)
			activated = anyFramePress = true;
		if (value && !held[key]) {
			pushes[key]++;
			framePushes[key] = true;
		}
		if (!value && held[key]) {
			lifts[key]++;
			frameLifts[key] = true;
		}
		held[key] = value;
	}

	/** Pad 0's button or axis, connecting it: for replay and tests. */
	public function padEvent(button:PadButton, value:Bool):Void {
		if (!pads[0].connected)
			pads[0].connect(true, "replay");
		pads[0].buttonEvent(button, value);
	}

	/** Pad 0's axis, connecting it: for replay and tests. */
	public function axisEvent(axis:PadAxis, value:Float):Void {
		if (!pads[0].connected)
			pads[0].connect(true, "replay");
		pads[0].axisEvent(axis, value);
	}

	/** A mouse button down (true) or up (false); only a change of state counts an edge. */
	public function mouseEvent(button:MouseButton, value:Bool):Void {
		if (value)
			activated = anyFramePress = true;
		if (value && !mouseHeld[button]) {
			mousePushes[button]++;
			mouseFramePushes[button] = true;
		}
		if (!value && mouseHeld[button]) {
			mouseLifts[button]++;
			mouseFrameLifts[button] = true;
		}
		mouseHeld[button] = value;
	}

	/** The primary pointer at x, y in framebuffer pixels (-1, -1 off the window), down or up; only a change of down counts an edge. */
	public function pointerEvent(x:Float, y:Float, value:Bool):Void {
		if (value)
			activated = anyFramePress = true;
		pointerX = x;
		pointerY = y;
		if (value && !pointerDown) {
			pointerPushes++;
			pointerFramePressed = true;
		}
		if (!value && pointerDown) {
			pointerLifts++;
			pointerFrameReleased = true;
		}
		pointerDown = value;
	}

	/** Typed characters, appended to this frame's text while text entry is on; dropped while it's off. */
	public function textEvent(value:String):Void
		if (textEntry)
			text += value;

	/** Wheel notches, added to this frame's; up and right are positive. */
	public function wheelEvent(x:Float, y:Float):Void {
		wheelX += x;
		wheelY += y;
	}

	/** A finger down, moved or lifted. A lifted one stays in touches, not down, until the frame ends. */
	public function touchEvent(id:Int, x:Float, y:Float, value:Bool):Void {
		if (value)
			activated = anyFramePress = true;
		var pair = gesturePair();
		var ax = 0., ay = 0., bx = 0., by = 0.;
		if (pair != null) {
			ax = pair[0].x;
			ay = pair[0].y;
			bx = pair[1].x;
			by = pair[1].y;
		}
		var touch = null;
		for (t in touchStates)
			if (t.id == id && t.down)
				touch = t;
		if (touch == null) {
			if (!value)
				return;
			touchStates.push({
				id: id,
				x: x,
				y: y,
				down: true,
				pressed: true,
				released: false
			});
			return;
		}
		touch.x = x;
		touch.y = y;
		if (!value) {
			touch.down = false;
			touch.released = true;
		}
		// The same two fingers before and after: they panned, pinched and twisted.
		var after = gesturePair();
		if (pair != null && after != null && after[0] == pair[0] && after[1] == pair[1]) {
			var nax = after[0].x,
				nay = after[0].y,
				nbx = after[1].x,
				nby = after[1].y;
			var before = Math.sqrt((bx - ax) * (bx - ax) + (by - ay) * (by - ay)),
				now = Math.sqrt((nbx - nax) * (nbx - nax) + (nby - nay) * (nby - nay));
			var panX = (nax + nbx - ax - bx) / 2,
				panY = (nay + nby - ay - by) / 2;
			var turn = Math.atan2(nby - nay, nbx - nax) - Math.atan2(by - ay, bx - ax);
			if (turn > Math.PI)
				turn -= 2 * Math.PI;
			if (turn < -Math.PI)
				turn += 2 * Math.PI;
			for (g in [frameGesture, tickGesture]) {
				g[0] += panX;
				g[1] += panY;
				if (before > 0 && now > 0) {
					g[2] += Math.log(now / before);
					g[3] += turn;
				}
			}
		}
	}

	/** The two fingers down longest, which make the gesture; null with fewer than two down. */
	function gesturePair():Null<Array<TouchState>> {
		var down = [for (t in touchStates) if (t.down) t];
		return down.length >= 2 ? [down[0], down[1]] : null;
	}

	public var touchGesture(get, never):Bool;

	function get_touchGesture():Bool
		return gesturePair() != null;

	public var touchGestureCenterX(get, never):Float;

	function get_touchGestureCenterX():Float {
		var pair = gesturePair();
		return pair == null ? 0 : (pair[0].x + pair[1].x) / 2;
	}

	public var touchGestureCenterY(get, never):Float;

	function get_touchGestureCenterY():Float {
		var pair = gesturePair();
		return pair == null ? 0 : (pair[0].y + pair[1].y) / 2;
	}

	public function getTouchGesturePanX(perTick = false):Float
		return (perTick ? tickGesture : frameGesture)[0];

	public function getTouchGesturePanY(perTick = false):Float
		return (perTick ? tickGesture : frameGesture)[1];

	public function getTouchGestureScale(perTick = false):Float
		return Math.exp((perTick ? tickGesture : frameGesture)[2]);

	public function getTouchGestureRotation(perTick = false):Float
		return (perTick ? tickGesture : frameGesture)[3];

	/** Lets go of everything held, as when focus is lost: the releases are edges; presses not yet consumed, typed text and the wheel are dropped. */
	public function clear():Void {
		for (key in Key.all)
			keyEvent(key, false);
		for (button in MouseButton.all)
			mouseEvent(button, false);
		for (pad in pads) {
			for (button in PadButton.all)
				pad.buttonEvent(button, false);
			for (axis in PadAxis.all)
				pad.axisEvent(axis, 0);
			pad.consume();
			pad.endFrame();
		}
		pointerEvent(-1, -1, false);
		for (t in touchStates)
			if (t.down)
				touchEvent(t.id, t.x, t.y, false);
		for (i in 0...pushes.length) {
			pushes[i] = 0;
			framePushes[i] = false;
		}
		for (i in 0...3) {
			mousePushes[i] = 0;
			mouseFramePushes[i] = false;
			mouseFrameLifts[i] = false;
		}
		pointerPushes = 0;
		pointerFramePressed = false;
		text = "";
		wheelX = 0;
		wheelY = 0;
	}

	@:noCompletion
	public function watch(watcher:IInputWatcher):Bool {
		if (watcher == null || watchers.indexOf(watcher) >= 0)
			return false;
		watchers.push(watcher);
		return true;
	}

	@:noCompletion
	public function unwatch(watcher:IInputWatcher):Bool
		return watchers.remove(watcher);

	/** Degrees of tilt that read as all the way (tiltX, tiltY at 1). */
	public static inline var TILT_RANGE = 30.;

	/** How long the device is held steady before that's taken as level (seconds). */
	public static inline var TILT_STEADY_SECONDS = .5;

	/** How far the device may move while it's held steady (degrees). */
	public static inline var TILT_STEADY_DEGREES = 3.;

	public var tiltX(get, never):Float;

	function get_tiltX():Float
		return tilted[0];

	public var tiltY(get, never):Float;

	function get_tiltY():Float
		return tilted[1];

	public var tiltState(get, never):TiltState;

	function get_tiltState():TiltState
		return tiltIs;

	var tilted = [0., 0.];
	var tiltIs:TiltState = Off;
	// Whether the tilt is wanted (the router tells the platform as it changes), and the reading taken as level (NaN until it's taken).
	@:allow(helix.input)
	var tiltWanted = false;
	var levelBeta = Math.NaN;
	var levelGamma = Math.NaN;
	// The screen's turn, in quarters, when level was taken.
	var levelQuarter = 0;
	// While level is being taken: the reading the device is held near, and since when (seconds; NaN before a reading).
	var steadyBeta = 0.;
	var steadyGamma = 0.;
	var steadySince = Math.NaN;
	// The clock steadiness is timed by (seconds), set by tests.
	var now:Void->Float = haxe.Timer.stamp;

	public function requestTilt():Void {
		if (tiltIs == On || tiltIs == Calibrating || tiltIs == Unavailable || tiltIs == Waiting && tiltWanted)
			return;
		tiltWanted = true;
		tiltIs = Waiting;
	}

	public function calibrateTilt():Void {
		levelBeta = levelGamma = steadySince = Math.NaN;
		tilted[0] = tilted[1] = 0;
		if (tiltIs == On)
			tiltIs = Calibrating;
	}

	/** A reading of the device's tilt (IInputEvents.tilt): its change from level, turned from the device's way up to the screen's, over
		TILT_RANGE degrees and held to -1..1. Level is taken once the device is held steady (within TILT_STEADY_DEGREES for
		TILT_STEADY_SECONDS): at the start, after calibrateTilt, and after the screen turns (the player holds the device anew). The tilt reads
		0 until then, the state Calibrating. */
	@:noCompletion
	public function tiltEvent(beta:Float, gamma:Float, screenAngle:Float):Void {
		var quarter = Math.round(((screenAngle % 360) + 360) % 360 / 90) % 4;
		if (quarter != levelQuarter) {
			levelBeta = levelGamma = steadySince = Math.NaN;
			levelQuarter = quarter;
		}
		if (Math.isNaN(levelBeta)) {
			var time = now();
			if (Math.isNaN(steadySince)
				|| Math.abs(beta - steadyBeta) > TILT_STEADY_DEGREES
				|| Math.abs(gamma - steadyGamma) > TILT_STEADY_DEGREES) {
				steadyBeta = beta;
				steadyGamma = gamma;
				steadySince = time;
			}
			tilted[0] = tilted[1] = 0;
			if (time - steadySince < TILT_STEADY_SECONDS) {
				tiltIs = Calibrating;
				return;
			}
			levelBeta = beta;
			levelGamma = gamma;
		}
		tiltIs = On;
		var forward = beta - levelBeta, across = gamma - levelGamma;
		// The screen turned counterclockwise from the device's way up by screenAngle: its across and down in the device's terms.
		var x = across, y = forward;
		switch quarter {
			case 1:
				x = forward;
				y = -across;
			case 2:
				x = -across;
				y = -forward;
			case 3:
				x = -forward;
				y = across;
			case _:
		}
		inline function held(v:Float):Float {
			v /= TILT_RANGE;
			return v < -1 ? -1 : v > 1 ? 1 : v;
		}
		tilted[0] = held(x);
		tilted[1] = held(y);
	}

	/** What came of asking for the tilt (IInputEvents.tiltState). Once refused, reading stops being wanted. Once unavailable, it's still
		wanted: a reading that comes late (a phone's sensor starting after its prompt closes) turns the tilt On. */
	@:noCompletion
	public function tiltStateEvent(state:TiltState):Void {
		tiltIs = state;
		if (state == Refused || state == Unavailable)
			tilted[0] = tilted[1] = 0;
		if (state == Refused)
			tiltWanted = false;
	}

	public function consume():Void {
		for (watcher in watchers.copy())
			watcher.tickEnded();
		tickGesture = [0., 0., 0., 0.];
		for (i in 0...pushes.length) {
			if (pushes[i] > 0)
				pushes[i]--;
			if (lifts[i] > 0)
				lifts[i]--;
		}
		for (pad in pads)
			pad.consume();
		for (i in 0...3) {
			if (mousePushes[i] > 0)
				mousePushes[i]--;
			if (mouseLifts[i] > 0)
				mouseLifts[i]--;
		}
		if (pointerPushes > 0)
			pointerPushes--;
		if (pointerLifts > 0)
			pointerLifts--;
	}

	/** Tells the watchers, then ends the frame's edges, text, wheel and lifted touches; the InputRouter calls it after each frame. */
	public function endFrame():Void {
		for (watcher in watchers.copy())
			watcher.frameEnded();
		anyFramePress = false;
		frameGesture = [0., 0., 0., 0.];
		for (i in 0...framePushes.length) {
			framePushes[i] = false;
			frameLifts[i] = false;
			claimed[i] = false;
		}
		pointerFramePressed = false;
		pointerFrameReleased = false;
		for (i in 0...3) {
			mouseFramePushes[i] = false;
			mouseFrameLifts[i] = false;
		}
		for (pad in pads)
			pad.endFrame();
		text = "";
		wheelX = 0;
		wheelY = 0;
		touchStates = [for (t in touchStates) if (t.down) t];
		for (t in touchStates)
			t.pressed = false;
	}
}
