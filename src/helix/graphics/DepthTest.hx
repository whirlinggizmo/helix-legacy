package helix.graphics;

/** Which fragments a pipeline's depth test passes, against the depth already there. */
@:build(helix.macro.EnumNames.build())
enum abstract DepthTest(Int) to Int {
	/** No test: every fragment is drawn. */
	var Off = 0;

	/** Nearer or as near: what's in front (the usual test). */
	var LessEqual = 1;

	/** Farther: only where something nearer was drawn before (what's hidden behind it). */
	var Greater = 2;
}
