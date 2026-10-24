package helix.render3d;

/** How a track's keys run between them, glTF's three. */
@:build(helix.macro.EnumNames.build())
enum abstract TrackInterpolation3D(Int) to Int {
	/** A straight line (a rotation's spherical one). */
	var Linear = 0;

	/** Held until the next key. */
	var Step = 1;

	/** A cubic Hermite spline through the keys, each key its in-tangent, value and out-tangent. */
	var CubicSpline = 2;
}
