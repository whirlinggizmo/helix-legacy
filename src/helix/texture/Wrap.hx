package helix.texture;

/** How a texture's edges repeat past 0..1. */
@:build(helix.macro.EnumNames.build())
enum abstract Wrap(Int) to Int {
	/** The edge texel carries on. */
	var Clamp = 0;

	/** The texture tiles. */
	var Repeat = 1;

	/** The texture tiles, every other copy mirrored. */
	var Mirror = 2;
}
