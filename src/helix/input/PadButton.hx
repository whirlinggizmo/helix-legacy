package helix.input;

/** A gamepad's buttons, as on an Xbox-style pad, numbered as the W3C standard gamepad numbers them. The triggers are buttons too (pressed when pulled past half way, or by a digital trigger) as well as axes. */
@:build(helix.macro.EnumNames.build())
enum abstract PadButton(Int) to Int {
	var South = 0;
	var East = 1;
	var West = 2;
	var North = 3;
	var LeftBumper = 4;
	var RightBumper = 5;
	var LeftTrigger = 6;
	var RightTrigger = 7;
	var Back = 8;
	var Start = 9;
	var LeftStick = 10;
	var RightStick = 11;
	var Up = 12;
	var Down = 13;
	var Left = 14;
	var Right = 15;
	var Guide = 16;

	/** One past the largest value, for arrays indexed by button. */
	public static inline var COUNT = 17;

	/** Every button. */
	public static final all:Array<PadButton> = [
		South,
		East,
		West,
		North,
		LeftBumper,
		RightBumper,
		LeftTrigger,
		RightTrigger,
		Back,
		Start,
		LeftStick,
		RightStick,
		Up,
		Down,
		Left,
		Right,
		Guide
	];
}
