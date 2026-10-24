package helix.render2d;

/** How a filled rectangle is colored. */
@:build(helix.macro.EnumNames.build())
enum abstract ShapeShading2D(Int) {
	/** In its color alone. */
	var Flat = 0;

	/** From its color at its left edge to its endColor at its right. */
	var Across = 1;

	/** From its color at its top to its endColor at its bottom. */
	var Down = 2;
}
