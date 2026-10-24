package helix.input;

/** Which way of a touch stick (Binding.TouchStick) an action reads, as a pad's stick runs: across (X, right positive) or up and down (Y,
	down positive). */
enum StickAxis {
	/** Across: -1 at the left, 1 at the right. */
	X;

	/** Up and down: -1 at the top, 1 at the bottom. */
	Y;
}
