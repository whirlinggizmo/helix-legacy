package helix.host;

/** Which way up a game wants the screen (Window.requestOrientation): its long side across (Landscape), up and down (Portrait), or as the
	player holds it (Any). */
@:build(helix.macro.EnumNames.build())
enum abstract Orientation(Int) to Int {
	/** As the player holds it: the lock let go. */
	var Any;

	/** Wider than tall: the long side across. */
	var Landscape;

	/** Taller than wide: a phone held upright. */
	var Portrait;
}
