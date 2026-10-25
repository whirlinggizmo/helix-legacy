package helix.render2d;

/** How a thick line's ends are drawn (Drawing2D.line, polyline). */
@:build(helix.macro.EnumNames.build())
enum abstract LineCap2D(Int) to Int {
	/** Flat, at the end point itself. */
	var Butt;

	/** A half circle around the end point, half the line's width out. */
	var Round;

	/** Flat, half the line's width past the end point. */
	var Square;
}
