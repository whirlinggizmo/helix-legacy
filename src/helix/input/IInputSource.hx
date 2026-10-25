package helix.input;

/** A platform's input: its keyboard, mouse, touch, focus and gamepad events reported as they are, in order, to the shared InputRouter,
	which makes the input an app reads from them. Edges, the pointer, focus policy and pad slots are the router's. */
@:noCompletion
interface IInputSource {
	/** Reports to events from now on, on the host thread: as the platform's events arrive, or at poll. Called once, before the first poll. */
	public function start(events:IInputEvents):Void;

	/** Before the app's frame: reports what arrived since the last poll, then every connected gamepad's state, in the platform's order. */
	public function poll():Void;

	/** Asks the platform for typed text while on (SDL3's text input; a soft keyboard where the platform has one), and no longer when off.
		The router calls it before a poll, as the app's text entry (IInput.setTextEntry) changes; off until then. */
	public function setTextEntry(on:Bool):Void;

	/** Starts reading the device's tilt while on (reporting it as IInputEvents.tilt, and what came of asking as tiltState), stops while
		off: in a browser through its device orientation, asking for it at the player's next tap where the browser wants a tap for it (iOS);
		Unavailable where there's none. The router calls it before a poll, as the app asks (IInput.requestTilt); off until then. */
	public function setTiltWanted(on:Bool):Void;

	/** Releases the platform's input, after the app's cleanup. */
	public function shutdown():Void;
}
