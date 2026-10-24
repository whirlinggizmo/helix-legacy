package helix.behavior;

/** When in a frame a behavior runs: the BehaviorPass pass updates every behavior of one phase before any of the next, in this order, and
	within a phase in the order they were added (a scene file's order). A class says its phase with `@:phase(Late)` on the class; without
	it, Simulate, and a subclass has its base's. Fixed and few on purpose: a reader knows what a frame does from the class alone, and
	every target runs it alike (docs/DECISIONS.md 134). */
@:build(helix.macro.EnumNames.build())
enum abstract Phase(Int) to Int {
	/** First: reads the devices and decides intent (a player's controller, an AI's choice of what to do), moving nothing yet. */
	var Input = 0;

	/** Moves the world: a car, a projectile, an AI acting on its intent. The phase of a behavior that doesn't say. */
	var Simulate = 1;

	/** Settles what Simulate produced: checkpoints seeing where the car now is, combat applying the hits queued this frame, triggers. */
	var Resolve = 2;

	/** Last: follows the settled world (cameras, HUD anchors, effects), changing nothing the others read. */
	var Late = 3;
}
