import helix.input.IInputEvents;
import helix.input.IInputSource;
import helix.input.InputRouter;
import helix.input.InputState;
import helix.input.Key;
import helix.input.MouseButton;
import helix.input.PadButton;
import helix.input.PadAxis;
import helix.input.PointerGestures;
import helix.time.Ticker;

class InputTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	public static function main():Void {
		var input = new InputState();
		// Two taps between ticks reach two ticks; the frame sees them once, until the frame ends.
		for (_ in 0...2) {
			input.keyEvent(Key.Enter, true);
			input.keyEvent(Key.Enter, false);
		}
		check(input.isFramePressed(Key.Enter) && input.isPressed(Key.Enter), "Both edges set");
		input.consume();
		check(input.isPressed(Key.Enter) && input.isReleased(Key.Enter), "Second tap waits for the next tick");
		input.consume();
		check(!input.isPressed(Key.Enter), "Each tap seen once");
		input.endFrame();
		check(!input.isFramePressed(Key.Enter), "Frame edge ends with the frame");
		input.keyEvent(Key.Space, true);
		input.consume();
		input.keyEvent(Key.Space, true);
		check(input.isDown(Key.Space) && !input.isPressed(Key.Space), "Repeat is no new press");
		// A claimed key reads as up, unpressed and unreleased for the rest of the frame, its tick edges spent; free again the next frame.
		input.endFrame();
		input.keyEvent(Key.Space, false);
		input.endFrame();
		input.keyEvent(Key.A, true);
		check(input.isPressed(Key.A) && !input.isClaimed(Key.A), "Pressed, not claimed");
		input.claim(Key.A);
		check(input.isClaimed(Key.A) && !input.isDown(Key.A) && !input.isPressed(Key.A) && !input.isFramePressed(Key.A),
			"Claimed: not down, not pressed, for whoever reads after");
		input.endFrame();
		check(!input.isClaimed(Key.A) && input.isDown(Key.A) && !input.isPressed(Key.A), "The next frame: held again, its press spent");
		input.keyEvent(Key.A, false);
		input.endFrame();
		check(Key.named("f12") == Key.F12
			&& Key.all.length == 116
			&& Key.named("menu") == Key.Menu
			&& Key.named("keypadequal") == Key.KeypadEqual,
			"Key names");
		// Text comes only while text entry is on (off at start); text, wheel and touches last one frame; a lifted touch stays until then.
		input.textEvent("zz");
		check(input.text == "" && !input.textEntry, "Text is dropped while text entry is off");
		input.textEntry = true;
		input.textEvent("ab");
		input.wheelEvent(0, 1);
		input.touchEvent(7, 10, 20, true);
		input.touchEvent(7, 12, 20, false);
		check(input.text == "ab" && input.wheelY == 1 && input.touches.length == 1 && input.touches[0].released, "Frame values");
		input.endFrame();
		check(input.text == "" && input.wheelY == 0 && input.touches.length == 0, "Frame values end");
		// Mouse buttons and the pointer count like keys.
		input.mouseEvent(MouseButton.Right, true);
		input.mouseEvent(MouseButton.Right, false);
		input.mouseEvent(MouseButton.Right, true);
		check(input.isMousePressed(MouseButton.Right) && input.isMouseDown(MouseButton.Right), "Mouse edges");
		input.consume();
		check(input.isMousePressed(MouseButton.Right), "Second click next tick");
		input.pointerEvent(5, 5, true);
		input.pointerEvent(5, 5, false);
		check(input.pointerPressed && input.pointerReleased, "Pointer tap keeps both edges");
		input.consume();
		check(!input.pointerPressed, "Pointer tap seen once");
		// Pads: any-pad queries, and a stick's radial dead zone.
		input.padEvent(PadButton.North, true);
		input.axisEvent(PadAxis.LeftX, .1);
		check(input.isPadDown(PadButton.North) && input.getPad(0).getAxis(PadAxis.LeftX) == 0 && input.getPadAxis(PadAxis.LeftX) == 0,
			"Dead zone, on both pad queries");
		input.axisEvent(PadAxis.LeftX, 1);
		check(Math.abs(input.getPad(0).getAxis(PadAxis.LeftX) - 1) < 1e-9, "Full reach past the dead zone");
		// Pads count presses and have release edges, as keys do; the mouse has release edges.
		var pad = input.getPad(0);
		pad.buttonEvent(PadButton.East, true);
		pad.buttonEvent(PadButton.East, false);
		pad.buttonEvent(PadButton.East, true);
		check(pad.isPressed(PadButton.East) && pad.isReleased(PadButton.East) && pad.isFrameReleased(PadButton.East), "Pad edges");
		input.consume();
		check(pad.isPressed(PadButton.East) && !pad.isReleased(PadButton.East), "Second pad press waits for the next tick");
		input.consume();
		check(!pad.isPressed(PadButton.East), "Each pad press seen once");
		input.endFrame();
		check(!pad.isFrameReleased(PadButton.East), "Pad frame edges end with the frame");
		input.mouseEvent(MouseButton.Middle, true);
		input.mouseEvent(MouseButton.Middle, false);
		check(input.isMouseReleased(MouseButton.Middle) && input.isMouseFrameReleased(MouseButton.Middle), "Mouse release edges");
		// Two fingers pan, pinch and twist: the same pair before and after each move.
		input.endFrame();
		input.touchEvent(1, 100, 100, true);
		input.touchEvent(2, 200, 100, true);
		check(input.touchGesture && input.touchGestureCenterX == 150, "Two fingers make a gesture");
		input.touchEvent(2, 300, 100, true);
		input.touchEvent(1, 100, 200, true);
		check(Math.abs(input.getTouchGestureScale() - Math.sqrt(200 * 200 + 100 * 100) / 100) < 1e-9, "Scale multiplies");
		check(input.getTouchGesturePanX() == 50 && input.getTouchGesturePanY() == 50, "Pan follows the midpoint");
		check(Math.abs(input.getTouchGestureRotation() - Math.atan2(-100, 200)) < 1e-9, "Rotation is the turn of the line between the fingers");
		input.endFrame();
		check(input.getTouchGestureScale() == 1 && input.getTouchGestureScale(true) != 1, "Frame sums end with the frame; tick sums wait for consume");
		input.consume();
		input.touchEvent(1, 100, 200, false);
		check(!input.touchGesture && input.getTouchGesturePanX(true) == 0, "One finger is no gesture");
		input.touchEvent(2, 300, 100, false);
		input.endFrame();
		// Activation: a key, mouse or finger press, once, not a pad's.
		var fresh = new InputState();
		check(!fresh.activated, "Nothing pressed yet: not activated");
		fresh.padEvent(PadButton.South, true);
		fresh.padEvent(PadButton.South, false);
		check(!fresh.activated, "A pad's press doesn't activate (a browser can't unlock with one)");
		fresh.keyEvent(Key.Space, true);
		fresh.keyEvent(Key.Space, false);
		fresh.endFrame();
		check(fresh.activated, "A key press activates, and it stays");
		check(!fresh.anyFramePressed, "The frame's any-press ended with the frame");
		fresh.mouseEvent(MouseButton.Left, true);
		check(fresh.anyFramePressed, "A mouse button down is a press this frame");
		fresh.endFrame();
		fresh.padEvent(PadButton.South, true);
		check(!fresh.anyFramePressed, "and a pad's isn't");
		var touched = new InputState();
		touched.touchEvent(1, 5, 5, true);
		check(touched.activated, "A finger down activates");

		// Ticker: fixed steps, a pause, bounded catch-up, and input consumed per tick.
		var ticker = new Ticker(10, input), ticks = 0;
		input.keyEvent(Key.A, true);
		input.keyEvent(Key.A, false);
		var seen = 0;
		ticker.advance(.25, () -> {
			ticks++;
			if (input.isPressed(Key.A))
				seen++;
		});
		check(ticks == 2 && seen == 1 && Math.abs(ticker.fraction - .5) < 1e-9, "Ticks and fraction");
		ticker.advance(0, () -> ticks++);
		check(ticks == 2, "Paused: a clock's 0 elapsed");
		ticker.advance(.25, () -> ticks++);
		ticker.advance(.25, () -> ticks++);
		check(ticks == 7, "Accumulates");
		router();
		tilt();
		// Double taps, read per frame: two quick taps near each other pair, a third starts over, a slow or distant second doesn't pair.
		var pad = new InputState(), gestures = new PointerGestures();
		var clock = 0.;
		function tap(x:Float, y:Float, gap:Float):Bool {
			clock += gap;
			pad.pointerEvent(x, y, true);
			gestures.update(clock, false, pad);
			pad.endFrame();
			clock += .05;
			pad.pointerEvent(x, y, false);
			gestures.update(clock, false, pad);
			pad.endFrame();
			return gestures.tapped && gestures.doubleTapped;
		}
		check(!tap(100, 100, 1), "A first tap is no double tap");
		check(tap(104, 98, .2), "A quick near second tap is a double tap");
		check(!tap(104, 98, .2), "A third tap starts a new pair");
		check(tap(100, 100, .2), "And the fourth completes it");
		check(!tap(100, 100, 1) && !tap(100, 100, .6), "A second tap past the interval doesn't pair");
		check(!tap(200, 100, .2), "Nor one past the distance");
		gestures.maxDoubleTapInterval = -1;
		check(gestures.maxDoubleTapInterval == 1e-6, "The interval clamps to its least");
		gestures.maxDoubleTapDistance = Math.NaN;
		check(gestures.maxDoubleTapDistance == 0, "The distance clamps to 0");
		// Per tick, both presses between two ticks: each tick sees one, and the second pairs.
		var ticked = new InputState(), perTick = new PointerGestures();
		for (_ in 0...2) {
			ticked.pointerEvent(50, 50, true);
			ticked.pointerEvent(50, 50, false);
		}
		perTick.update(0, true, ticked);
		ticked.consume();
		check(perTick.tapped && !perTick.doubleTapped, "The first tick takes the first tap");
		perTick.update(1 / 60, true, ticked);
		ticked.consume();
		check(perTick.doubleTapped, "The second tick the second, a double tap");
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}

	// The device's tilt: asked for through the router to the platform, read from level (the first reading), turned with the screen, held to
	// -1..1; calibrated anew; refused, no longer wanted.
	static function tilt():Void {
		var source = new Source(),
			router = new InputRouter(),
			input:InputState = cast router.input;
		source.start(router);
		router.poll(source);
		check(input.tiltState == Off && !source.tiltWanted, "Off until asked");
		input.requestTilt();
		router.poll(source);
		check(source.tiltWanted && input.tiltState == Waiting, "Asked: the platform told, waiting");
		source.report = e -> e.tilt(60, 0, 0);
		router.poll(source);
		check(input.tiltState == On && input.tiltX == 0 && input.tiltY == 0, "The first reading is level");
		source.report = e -> e.tilt(45, 15, 0);
		router.poll(source);
		check(input.tiltX == .5 && input.tiltY == -.5, "Right side down half across; the top tipped away half up");
		source.report = e -> e.tilt(0, 90, 0);
		router.poll(source);
		check(input.tiltX == 1 && input.tiltY == -1, "Past the range: held to -1..1");
		// The screen turned 90 degrees counterclockwise (a phone on its side): the device's forward is across the screen.
		source.report = e -> e.tilt(75, 0, 90);
		router.poll(source);
		check(input.tiltX == .5 && input.tiltY == 0, "On its side: tipping the device's top toward the player is right on screen");
		source.report = e -> e.tilt(60, -15, 270);
		router.poll(source);
		check(input.tiltX == 0 && input.tiltY == -.5, "On its other side: the device's left side down is up on screen");
		input.calibrateTilt();
		source.report = e -> e.tilt(30, 10, 0);
		router.poll(source);
		check(input.tiltX == 0 && input.tiltY == 0, "Calibrated: level as it's held now");
		source.report = e -> e.tiltState(Refused);
		router.poll(source);
		router.poll(source);
		check(input.tiltState == Refused && input.tiltX == 0 && !source.tiltWanted, "Refused: zero, and no longer wanted");
		source.report = _ -> {};
		input.requestTilt();
		router.poll(source);
		check(source.tiltWanted && input.tiltState == Waiting, "Asked again after a refusal");
	}

	// The router's policies: the pointer from the left button or the first finger, focus, text under a shortcut modifier, pad slots.
	static function router():Void {
		var source = new Source(),
			router = new InputRouter(),
			input = router.input;
		input.textEntry = true;
		router.poll(source);
		check(source.textEntry, "The source is told when text entry turns on");
		source.start(router);
		source.report = e -> {
			e.mouseButton(MouseButton.Right, true, 5, 5);
			e.mouseMove(10, 20);
		};
		router.poll(source);
		check(input.pointerX == 10 && !input.pointerDown && input.isMouseDown(MouseButton.Right), "The mouse moves the pointer; only Left presses it");
		source.report = e -> {
			e.mouseButton(MouseButton.Right, false, 10, 20);
			e.touch(4, 50, 60, true);
		};
		router.poll(source);
		check(input.pointerDown && input.pointerX == 50, "The first finger is the pointer, natively as in a browser");
		source.report = e -> {
			e.touch(5, 90, 60, true);
			e.mouseMove(1, 1);
		};
		router.poll(source);
		check(!input.pointerDown && input.pointerX == -1 && input.touchGesture, "A second finger lets the pointer go, and the mouse waits");
		source.report = e -> {
			e.touch(4, 50, 60, false);
			e.touch(5, 90, 60, false);
			e.key(Key.Control, true);
			e.text("c");
			e.key(Key.Control, false);
			e.text("d");
		};
		router.poll(source);
		check(input.text == "d", "Text is ignored while Control is held");
		router.endFrame();
		source.report = e -> {
			e.pad("first", [for (_ in 0...17) false], [for (_ in 0...6) 0.]);
			e.pad("second", [true], [-1.]);
		};
		router.poll(source);
		check(input.getPad(0).name == "first"
			&& input.getPad(1).connected
			&& input.getPad(1).isDown(PadButton.South)
			&& !input.getPad(2).connected,
			"Connected pads fill the slots in order");
		source.report = e -> {
			e.key(Key.A, true);
			e.mouseButton(MouseButton.Left, true, 3, 3);
			e.focus(false);
			e.key(Key.B, true);
			e.text("b");
			e.wheel(0, 1);
			e.touch(9, 1, 1, true);
			e.pad("second", [true], [-1.]);
		};
		router.poll(source);
		check(!input.isDown(Key.A) && !input.isDown(Key.B) && !input.pointerDown && input.text == "" && input.wheelY == 0 && input.touches.length == 0,
			"Unfocused: everything let go, presses ignored");
		check(input.getPad(0).name == "second"
			&& !input.getPad(0).isDown(PadButton.South)
			&& input.getPad(0).getAxis(PadAxis.LeftX) == 0
			&& !input.getPad(1).connected,
			"Unfocused: pads stay connected, released and centred; a vanished pad's slot empties");
		source.report = e -> {
			e.focus(true);
			e.key(Key.B, true);
		};
		router.poll(source);
		check(input.isDown(Key.B), "Focus back: presses count again");
	}
}

/** A source whose poll reports what a test sets. */
class Source implements IInputSource {
	public var textEntry = false;

	public function setTextEntry(on:Bool):Void
		textEntry = on;

	public var tiltWanted = false;

	public function setTiltWanted(on:Bool):Void
		tiltWanted = on;

	public var report:IInputEvents->Void = _ -> {};

	var events:IInputEvents;

	public function new() {}

	public function start(events:IInputEvents):Void
		this.events = events;

	public function poll():Void
		report(events);

	public function shutdown():Void {}
}
