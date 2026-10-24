package helix.graphics;

/** How a pipeline's colors meet what the framebuffer has: replacing it, blended over it by their alpha (straight alpha), or added to it
	(times their alpha: light, fire, glows). */
@:build(helix.macro.EnumNames.build())
enum abstract BlendMode(Int) to Int {
	/** Replaces what's there. */
	var Opaque = 0;

	/** Blended over what's there by its alpha. */
	var Alpha = 1;

	/** Added to what's there, times its alpha. */
	var Additive = 2;
}
