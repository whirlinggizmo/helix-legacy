package helix.input;

/** Where reading the device's tilt is (Input.tiltState): not asked for, waiting (for the player's tap that grants it, or its first reading),
	calibrating (waiting for the device to be held steady), reading, refused by the player, or not there to read (a computer, natively). */
@:build(helix.macro.EnumNames.build())
enum abstract TiltState(Int) to Int {
	/** Not asked for: requestTilt starts it. */
	var Off;

	/** Asked for: waiting for the player's next tap or the first reading. A browser shows its prompt at a tap, and after the prompt, Chrome
		reads nothing until the player taps the page again: a game can say "tap to start" while it waits. */
	var Waiting;

	/** Reading, and taking level: tiltX and tiltY read 0 until the player holds the device steady for half a second, which becomes level.
		It comes at the first reading, after the screen turns, and after calibrateTilt. A game can say "hold steady" while it lasts. */
	var Calibrating;

	/** Reading: tiltX and tiltY follow the device. */
	var On;

	/** The player refused it. */
	var Refused;

	/** Nothing to read yet: no reading came soon after asking (a computer has no motion sensor), or natively. A reading that comes later
		still turns it On. */
	var Unavailable;
}
