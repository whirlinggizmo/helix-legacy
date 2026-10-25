package helix.input;

/** Makes the input an app reads (an InputState) from a platform's events, the same on every platform:
	- the primary pointer is the mouse with its left button, or the first finger down; a second finger lets it go, off the window, so a pinch
	  never drops or clicks anything, and the pointer stays let go until every finger lifts;
	- losing focus lets go of everything, and while unfocused presses, text, the wheel and pads are ignored (releases and moves still count);
	- text is ignored while Control or Super is held (a shortcut, not typing); Alt isn't, because AltGr and macOS's Option type characters;
	- the first four connected gamepads fill the four slots in the platform's order, and the rest of the slots are empty. */
@:noCompletion
class InputRouter implements IInputEvents {
	var state = new InputState();
	var focused = true;
	var fingers:Array<Int> = [];
	var pointerFinger = -1;
	var gesture = false;
	var padSlot = 0;
	var textEntryTold = false;
	var tiltTold = false;

	/** Focused, with nothing held. */
	public function new() {}

	/** The input the app reads. */
	public var input(get, never):IInput;

	function get_input():IInput
		return state;

	/** Before the app's frame: tells source when the app's text entry changed, has it report what arrived, then empties the pad slots no
		connected pad reported into. */
	public function poll(source:IInputSource):Void {
		if (state.tiltWanted != tiltTold) {
			tiltTold = state.tiltWanted;
			source.setTiltWanted(tiltTold);
		}
		if (state.textEntry != textEntryTold) {
			textEntryTold = state.textEntry;
			source.setTextEntry(textEntryTold);
		}
		padSlot = 0;
		source.poll();
		for (i in padSlot...state.padCount) {
			var pad = state.getPad(i);
			if (pad.connected)
				pad.connect(false, "");
		}
	}

	/** After the app's frame: the frame's edges, text, wheel and lifted touches end. */
	public function endFrame():Void
		state.endFrame();

	public function key(key:Key, down:Bool):Void
		if (focused || !down)
			state.keyEvent(key, down);

	public function text(chars:String):Void
		if (focused && !state.isDown(Key.Control) && !state.isDown(Key.Super))
			state.textEvent(chars);

	public function mouseButton(button:MouseButton, down:Bool, x:Float, y:Float):Void {
		if (down && !focused && !state.isMouseDown(button))
			return;
		state.mouseEvent(button, down);
		if (button == MouseButton.Left && isMousePointer())
			state.pointerEvent(x, y, down);
	}

	public function mouseMove(x:Float, y:Float):Void
		if (isMousePointer())
			state.pointerEvent(x, y, state.isMouseDown(MouseButton.Left));

	public function mouseLeave():Void
		if (isMousePointer())
			state.pointerEvent(-1, -1, false);

	public function wheel(x:Float, y:Float):Void
		if (focused)
			state.wheelEvent(x, y);

	public function touch(id:Int, x:Float, y:Float, down:Bool):Void {
		var known = fingers.indexOf(id) >= 0;
		if (!known && (!down || !focused))
			return;
		state.touchEvent(id, x, y, down);
		if (down && !known)
			fingers.push(id);
		if (!down)
			fingers.remove(id);
		if (fingers.length > 1 && !gesture) {
			gesture = true;
			if (pointerFinger >= 0) {
				state.pointerEvent(-1, -1, false);
				pointerFinger = -1;
			}
		}
		if (gesture) {
			if (fingers.length == 0)
				gesture = false;
			return;
		}
		if (pointerFinger < 0 && down) {
			pointerFinger = id;
			state.pointerEvent(x, y, true);
		} else if (id == pointerFinger) {
			state.pointerEvent(x, y, down);
			if (!down)
				pointerFinger = -1;
		}
	}

	public function focus(value:Bool):Void {
		if (value == focused)
			return;
		focused = value;
		if (!value) {
			state.clear();
			fingers = [];
			pointerFinger = -1;
			gesture = false;
		}
	}

	public function tilt(beta:Float, gamma:Float, screenAngle:Float):Void
		state.tiltEvent(beta, gamma, screenAngle);

	public function tiltState(value:helix.input.TiltState):Void
		state.tiltStateEvent(value);

	public function pad(name:String, buttons:Array<Bool>, axes:Array<Float>):Void {
		if (padSlot >= state.padCount)
			return;
		var slot = state.getPad(padSlot++);
		if (!slot.connected || slot.name != name)
			slot.connect(true, name);
		for (button in PadButton.all) {
			var b:Int = button;
			slot.buttonEvent(button, focused && b < buttons.length && buttons[b]);
		}
		for (axis in PadAxis.all) {
			var a:Int = axis;
			slot.axisEvent(axis, focused && a < axes.length ? axes[a] : 0);
		}
	}

	// The mouse drives the pointer unless a finger does, or a gesture holds it let go.
	function isMousePointer():Bool
		return pointerFinger < 0 && !gesture;
}
