package helix.input;

/** Where a finger can land to take a touch stick (Binding.TouchStick), following the visible area (Screen's) as the window changes shape
	or turns. Two sticks split it down the middle in either orientation (both thumbs at the bottom of a phone held upright, too). */
enum StickArea {
	/** The whole visible area: one stick, either thumb, anywhere. */
	Anywhere;

	/** The visible area's left half: the moving stick of two. */
	LeftHalf;

	/** The visible area's right half: the aiming stick of two. */
	RightHalf;

	/** A rectangle placed as a touch region is (Binding.TouchRegion): the anchor's point on the visible area, then x, y from it to the top
		left, width x height across and down, in the game's units. */
	Region(anchor:Anchor, x:Float, y:Float, width:Float, height:Float);
}
