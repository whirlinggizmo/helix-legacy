package helix.input;

/** Where reading the device's tilt is (Input.tiltState): not asked for, waiting (for the player's tap that grants it, or its first reading),
	reading, refused by the player, or not there to read (a computer, natively). */
@:build(helix.macro.EnumNames.build())
enum abstract TiltState(Int) to Int {
	/** Not asked for: requestTilt starts it. */
	var Off;

	/** Asked for: waiting for the player's next tap (iOS asks then) or the first reading. */
	var Waiting;

	/** Reading: tiltX and tiltY follow the device. */
	var On;

	/** The player refused it. */
	var Refused;

	/** Nothing to read: no motion sensor (a computer), or natively. */
	var Unavailable;
}
