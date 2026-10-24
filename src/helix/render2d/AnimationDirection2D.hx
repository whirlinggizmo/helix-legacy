package helix.render2d;

/** Which way a SpriteAnimation2D plays through its frames (Aseprite's tag directions). */
@:build(helix.macro.EnumNames.build())
enum abstract AnimationDirection2D(Int) {
	/** First to last. */
	var Forward;

	/** Last to first. */
	var Reverse;

	/** First to last and back, the ends shown once a turn. */
	var PingPong;

	/** Last to first and back, the ends shown once a turn. */
	var PingPongReverse;
}
