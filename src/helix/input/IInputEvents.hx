package helix.input;

/** What an IInputSource reports to: the platform's input events as they are. Positions are framebuffer pixels from the top left. */
@:noCompletion
interface IInputEvents {
	/** A key went down (true) or up (false); a repeat may report down again. */
	public function key(key:Key, down:Bool):Void;

	/** Characters typed, after the keyboard layout. */
	public function text(chars:String):Void;

	/** A mouse button went down or up with the mouse at x, y. A source may report every button's state on each event. */
	public function mouseButton(button:MouseButton, down:Bool, x:Float, y:Float):Void;

	/** The mouse moved to x, y. */
	public function mouseMove(x:Float, y:Float):Void;

	/** The mouse left the window, or the platform took it over (a cancelled pointer). */
	public function mouseLeave():Void;

	/** The wheel turned, in notches; up and right are positive. */
	public function wheel(x:Float, y:Float):Void;

	/** A finger touched (down true), moved (true) or lifted (false), at x, y. */
	public function touch(id:Int, x:Float, y:Float, down:Bool):Void;

	/** The window gained (true) or lost (false) the input: lost while it is unfocused or hidden. */
	public function focus(focused:Bool):Void;

	/** A connected gamepad's state at poll: its name, each PadButton's state by number and each PadAxis's value by number (sticks -1..1,
		triggers 0..1). The arrays are read during the call only. */
	public function pad(name:String, buttons:Array<Bool>, axes:Array<Float>):Void;

	/** A reading of the device's tilt, in degrees as a browser gives it: beta front to back (0 lying flat, 90 upright), gamma side to side
		(right side down positive), and the screen's turn from the device's natural way up (0, 90, 180 or 270, counterclockwise). */
	public function tilt(beta:Float, gamma:Float, screenAngle:Float):Void;

	/** What came of asking for the tilt: Waiting, On, Refused or Unavailable. */
	public function tiltState(state:TiltState):Void;
}
