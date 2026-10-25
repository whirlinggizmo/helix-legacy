package helix.debug;

/** How much a message matters (Log): Log.level and a tag's level let through what's at or above them. */
@:build(helix.macro.EnumNames.build())
enum abstract LogLevel(Int) to Int {
	/** Detail for finding a fault; written in debug builds and the dev loop, gone from a release build. */
	var Debug;

	/** What happened, worth knowing. */
	var Info;

	/** Something went wrong and the game carried on: a file that didn't load, a setting the platform refused. */
	var Warning;

	/** Something failed that the game may not recover from. */
	var Error;

	/** As a level to let through: nothing. */
	var Off;
}
