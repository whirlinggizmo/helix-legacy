package helix.render2d;

/** How a thick line's corners are drawn where two segments meet (Drawing2D.polyline, polygonLines). */
@:build(helix.macro.EnumNames.build())
enum abstract LineJoin2D(Int) to Int {
	/** Pointed: the edges carried on until they meet, cut at twice the line's width for a sharp corner. */
	var Miter;

	/** Rounded: a circle's arc around the corner. */
	var Round;

	/** Cut off flat across the corner. */
	var Bevel;
}
