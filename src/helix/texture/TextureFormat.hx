package helix.texture;

/** What a texture's texels are: plain RGBA8, a GPU's compressed format (4x4 blocks of 16 bytes each), which only some GPUs sample
	(IGraphics.canSample), or half floats, linear light beyond 1 (an environment's cubes). The 8-bit and compressed ones' colors are sRGB values,
	as the shaders treat them. */
@:build(helix.macro.EnumNames.build())
enum abstract TextureFormat(Int) to Int {
	/** 4 bytes a texel, rows top first. */
	var Rgba8 = 0;

	/** BC7 (BPTC): desktops. */
	var Bc7 = 1;

	/** ASTC 4x4: phones. */
	var Astc4x4 = 2;

	/** ETC2 RGBA8 (with EAC alpha): older phones. */
	var Etc2Rgba8 = 3;

	/** RGBA half floats (IEEE binary16, little-endian), 8 bytes a texel, rows top first; filtered linearly where canSample says so. */
	var Rgba16f = 4;

	/** The bytes of a level width x height (of one face, for a cube). */
	public function levelBytes(width:Int, height:Int):Int
		return this == Rgba8 ? width * height * 4 : this == Rgba16f ? width * height * 8 : Std.int((width + 3) / 4) * Std.int((height + 3) / 4) * 16;
}
