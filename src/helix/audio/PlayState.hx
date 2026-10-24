package helix.audio;

/** Where a playback is: playing, paused, stopped (by stop(), or it never started), or complete (it played to its end). Each value is its
	own name, so a state traced or put in a probe reads "Playing", not a number. */
enum abstract PlayState(String) {
	var Stopped = "Stopped";
	var Playing = "Playing";
	var Paused = "Paused";
	var Complete = "Complete";
}
