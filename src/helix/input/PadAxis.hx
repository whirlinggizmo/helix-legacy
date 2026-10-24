package helix.input;

/** Sticks run from -1 to 1 (down and right positive), triggers from 0 to 1. */
@:build(helix.macro.EnumNames.build())
enum abstract PadAxis(Int) to Int {
	var LeftX = 0;
	var LeftY = 1;
	var RightX = 2;
	var RightY = 3;
	var LeftTrigger = 4;
	var RightTrigger = 5;

	/** One past the largest value, for arrays indexed by axis. */
	public static inline var COUNT = 6;

	/** Every axis. */
	public static final all:Array<PadAxis> = [LeftX, LeftY, RightX, RightY, LeftTrigger, RightTrigger];
}
