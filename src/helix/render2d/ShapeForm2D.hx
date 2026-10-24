package helix.render2d;

/** Which shape a Shape2D is. */
@:build(helix.macro.EnumNames.build())
enum abstract ShapeForm2D(Int) {
	/** A rectangle, filled or outlined, its corners square or rounded. */
	var Rectangle = 0;

	/** A circle, filled or outlined. */
	var Circle = 1;

	/** A line segment. */
	var Line = 2;

	/** A polygon, filled or outlined. */
	var Polygon = 3;
}
