package helix.render3d;

/** How a 3D sprite or text faces. */
@:build(helix.macro.EnumNames.build())
enum abstract SpriteFacing3D(Int) to Int {
	/** The camera, square to its view: a coin, a glow, a particle. */
	var Camera = 0;

	/** The camera, turning about y and staying upright: a tree, a character drawn flat. */
	var Upright = 1;

	/** Flat, its texture's top toward its node's -z, facing its node's +y (the ground's up, unturned): a decal, a shadow blob. */
	var Ground = 2;

	/** As its node is turned: in the node's x-y plane, facing its +z. A sign. */
	var Free = 3;
}
