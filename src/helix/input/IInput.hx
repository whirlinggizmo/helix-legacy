package helix.input;

/** Keyboard, pointer, mouse buttons, wheel, typed text, touches and gamepads.
	Tick edges (isPressed, isReleased) are counted and survive polling and render frames; consume() after a simulation tick takes one of each,
	so every press is seen by exactly one tick, and two presses between ticks reach two ticks.
	Frame edges (isFramePressed, isFrameReleased), typed text, the wheel and lifted touches last one frame.
	A key is claimed by what reads it first and uses it (claim: the UI's focused text field, a menu): for the rest of the frame it reads as
	up, unpressed and unreleased to everything after, so typing a space in a field doesn't make the player jump. */
interface IInput {
	/** Whether the key is held now. */
	public function isDown(key:Key):Bool;

	/** The key went down: a tick edge, counted until consume() takes it. */
	public function isPressed(key:Key):Bool;

	/** The key came up: a tick edge, counted until consume() takes it. */
	public function isReleased(key:Key):Bool;

	/** The key went down this frame: a frame edge. */
	public function isFramePressed(key:Key):Bool;

	/** The key came up this frame: a frame edge. */
	public function isFrameReleased(key:Key):Bool;

	/** Takes key for the rest of the frame: what reads it after sees it up, unpressed and unreleased (isDown, isPressed, isReleased and
		the frame edges false) until the frame ends, and its edges are spent, so no later tick sees them either. Whoever reads first and
		uses a key claims it: the UI does (Ui.update), so the game reads after it. */
	public function claim(key:Key):Void;

	/** Whether key was claimed this frame (claim). */
	public function isClaimed(key:Key):Bool;

	/** The primary pointer, in framebuffer pixels: the mouse with its left button, or the first finger. -1 when it isn't over the window. */
	var pointerX(get, never):Float;

	/** The primary pointer's y, in framebuffer pixels down from the top. -1 when it isn't over the window. */
	var pointerY(get, never):Float;

	/** Whether the primary pointer is down: the left mouse button held, or the first finger touching. */
	var pointerDown(get, never):Bool;

	/** The primary pointer went down: a tick edge, counted until consume() takes it. */
	var pointerPressed(get, never):Bool;

	/** The primary pointer came up: a tick edge, counted until consume() takes it. */
	var pointerReleased(get, never):Bool;

	/** The primary pointer went down this frame: a frame edge. */
	var pointerFramePressed(get, never):Bool;

	/** The primary pointer came up this frame: a frame edge. */
	var pointerFrameReleased(get, never):Bool;

	/** Whether the mouse button is held now. */
	public function isMouseDown(button:MouseButton):Bool;

	/** The mouse button went down: a tick edge, counted until consume() takes it. */
	public function isMousePressed(button:MouseButton):Bool;

	/** The mouse button went down this frame: a frame edge. */
	public function isMouseFramePressed(button:MouseButton):Bool;

	/** The button came up: a counted tick edge, as a key's. */
	public function isMouseReleased(button:MouseButton):Bool;

	/** The button came up this frame: a frame edge. */
	public function isMouseFrameReleased(button:MouseButton):Bool;

	/** Wheel notches this frame; up and right are positive. */
	var wheelX(get, never):Float;

	/** Vertical wheel notches this frame; up is positive. */
	var wheelY(get, never):Float;

	/** Characters typed this frame, after the keyboard layout; only while text entry is on (textEntry). */
	var text(get, never):String;

	/** Whether typed text is being taken; off at start. On, text carries the characters typed, and a platform with a soft keyboard shows it
		for them; off, keys are only keys and the keyboard stays down. The UI turns it on while a text field has focus; a game reading text
		itself turns it on while it types (a name entered, a chat line) and off after. */
	var textEntry(get, set):Bool;

	/** Fingers down, and those lifted this frame. */
	var touches(get, never):Array<Touch>;

	/** Whether two fingers are down: the two down longest make the gesture. */
	var touchGesture(get, never):Bool;

	/** The point between the gesture's fingers now, in framebuffer pixels; 0 without a gesture. */
	var touchGestureCenterX(get, never):Float;

	/** See touchGestureCenterX. */
	var touchGestureCenterY(get, never):Float;

	/** How far the point between the fingers moved, in framebuffer pixels: this frame, or since the last tick with perTick. */
	public function getTouchGesturePanX(perTick:Bool = false):Float;

	/** See getTouchGesturePanX. */
	public function getTouchGesturePanY(perTick:Bool = false):Float;

	/** How much the fingers spread (over 1) or pinched (under 1), as a factor: this frame, or since the last tick with perTick; 1 without. */
	public function getTouchGestureScale(perTick:Bool = false):Float;

	/** How far the line between the fingers turned, in radians, clockwise on screen positive: this frame, or since the last tick with perTick. */
	public function getTouchGestureRotation(perTick:Bool = false):Float;

	/** Four slots, connected or not. */
	var padCount(get, never):Int;

	/** null for an index out of range. */
	public function getPad(index:Int):Null<Gamepad>;

	/** Whether the user has pressed a key, a mouse button or a finger yet (the browser's user activation, which lets audio start and
		fullscreen be asked for; the same rule everywhere, so a game's flow is one flow): a title screen's "press any key". A pad's press doesn't
		count, as a browser can't unlock with one, so a game on a pad alone asks for a tap or key once. Stays true. An autopilot's press counts,
		so a script gated on it presses before it waits. */
	var activated(get, never):Bool;

	/** Whether a key, a mouse button or a finger went down this frame, whichever: a "press any key" screen's press. A pad's doesn't count, as
		activated's doesn't. */
	var anyFramePressed(get, never):Bool;

	/** Any connected pad. */
	public function isPadDown(button:PadButton):Bool;

	/** A connected pad's button went down: a counted tick edge, as a key's. */
	public function isPadPressed(button:PadButton):Bool;

	/** The first connected pad's axis, past the dead zone as Gamepad.getAxis gives it. */
	public function getPadAxis(axis:PadAxis):Float;

	/** How the device is tilted across, -1 to 1 (right down positive): from how it was held at the first reading (or calibrateTilt), TILT_RANGE
		degrees all the way, turned with the screen so it's across the screen as the player sees it. 0 until reading (tiltState On). */
	var tiltX(get, never):Float;

	/** How the device is tilted up and down the screen, -1 to 1: the top tipped away negative (rolling a ball up the screen), toward the
		player positive. As tiltX. */
	var tiltY(get, never):Float;

	/** Where reading the tilt is: Off until requestTilt, Waiting, On, Refused, Unavailable (TiltState). */
	var tiltState(get, never):TiltState;

	/** Starts reading the device's tilt (tiltX, tiltY). In a browser that wants a tap for it (iOS), it's asked for at the player's next tap,
		which shows the browser's prompt: call it on a title screen, say, before the tap that starts play. Again after Refused asks again. */
	public function requestTilt():Void;

	/** Takes how the device is held now as level: tiltX and tiltY 0 there, from the next reading. */
	public function calibrateTilt():Void;

	/** Call after each simulation tick: takes one of each counted tick edge and clears the pads' tick edges. */
	public function consume():Void;

	/** Plumbing for what is built on the input, not for a game (the Input static leaves it out): tells watcher as each tick and each frame
		ends (consume, and the frame's end), before their edges are cleared, which is how an action map (Actions) keeps its own previous states
		without calls from the game. False, changing nothing, for a watcher already told. */
	@:noCompletion
	public function watch(watcher:IInputWatcher):Bool;

	/** Plumbing, as watch: stops telling watcher; false for one not told. */
	@:noCompletion
	public function unwatch(watcher:IInputWatcher):Bool;
}
