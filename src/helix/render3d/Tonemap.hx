package helix.render3d;

/** How a stage brings lit color, which can run past 1 (bright lights, an HDR environment), into the 0..1 a screen shows, after its exposure. */
@:build(helix.macro.EnumNames.build())
enum abstract Tonemap(Int) to Int {
	/** Clamped: everything past 1 is 1, so highlights flatten to white and shift hue. */
	var None = 0;

	/** Khronos PBR Neutral: colors unchanged until highlights roll off; glTF viewers' default. */
	var Neutral = 1;

	/** ACES filmic (Narkowicz's fit): more contrast, highlights shifting toward white. */
	var Aces = 2;
}
