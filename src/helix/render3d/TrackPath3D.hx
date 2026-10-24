package helix.render3d;

/** What a track moves: its node's position, rotation (a quaternion) or scale. */
@:build(helix.macro.EnumNames.build())
enum abstract TrackPath3D(Int) to Int {
	/** Its position: x, y, z. */
	var Translation = 0;

	/** Its rotation: a quaternion x, y, z, w. */
	var Rotation = 1;

	/** Its scale: x, y, z. */
	var Scale = 2;
}
