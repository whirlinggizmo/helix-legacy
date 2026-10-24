package helix.graphics;

/** How a sprite or a particle uses its texels' alpha, the same in 2D and 3D (Sprite3D.alphaMode, Emitter.alphaMode). In 3D it also says
	when it's drawn among the models: with the opaque ones, among the see-through ones back to front, or after everything. */
@:build(helix.macro.EnumNames.build())
enum abstract AlphaMode(Int) to Int {
	/** Ignored: drawn solid (in 3D, with the opaque models). */
	var Opaque = 0;

	/** Texels below a cutoff are cut out, the rest solid: leaves, fences (in 3D, drawn with the opaque models). */
	var Mask = 1;

	/** Blended by it (in 3D, among the see-through models back to front). */
	var Blend = 2;

	/** Added, times it: light, fire, glows (in 3D, after everything else). */
	var Add = 3;
}
