package helix.texture;

/** How a texture is filtered as it's drawn at another size than its own: Linear blends its texels (smooth, and loaded with mipmaps, so it
	can be drawn smaller without shimmering), Nearest takes the nearest one (sharp: pixel art). */
@:build(helix.macro.EnumNames.build())
enum abstract Filter(Int) to Int {
	/** The nearest texel: sharp, for pixel art. */
	var Nearest = 0;

	/** Texels blended: smooth, through its mipmaps when it has them. */
	var Linear = 1;
}
