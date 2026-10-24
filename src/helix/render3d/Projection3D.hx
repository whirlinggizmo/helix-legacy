package helix.render3d;

/** How a Camera3D flattens the world onto its viewport: which of its two projections draws (Camera3D.projection). */
@:build(helix.macro.EnumNames.build())
enum abstract Projection3D(Int) to Int {
	/** Lines converge toward the eye: fovY radians of vertical view, near above 0. */
	var Perspective = 0;

	/** No perspective: orthographicHeight world units seen top to bottom, the width by the viewport's shape; near may be 0 or less. */
	var Orthographic = 1;
}
