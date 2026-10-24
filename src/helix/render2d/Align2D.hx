package helix.render2d;

/** Which point of a line of text its x names: its left edge, center or right edge. */
@:build(helix.macro.EnumNames.build())
enum abstract Align2D(Int) {
	/** x is the text's left edge. */
	var Left;

	/** x is the text's center. */
	var Center;

	/** x is the text's right edge. */
	var Right;
}
