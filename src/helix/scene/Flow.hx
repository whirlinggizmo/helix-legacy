package helix.scene;

/** Runs a step once a frame until it says it's done, so a thing can run itself without the game updating it. Transitions, the loading
	and splash screens, Collect2D, particles and decals' fading all use it, and a game's own screen or effect can too. For example, a banner
	fading out over two seconds: `var left = 2.; Flow.run(dt -> { left -= dt; banner.alpha = Math.max(0, left / 2); return left > 0; });`.
	A step is called after the game's update and before the frame is drawn, with the frame's seconds. That's real time, not the game's
	clock, so it goes on while the game is paused; read Time.clock.delta in the step to stop with the game. */
class Flow {
	static var steps:Array<Float->Bool> = [];
	static var installed = false;

	/** Whether waits and transitions should be skipped: true when the game runs with the option quick=1 (a developer's, ?quick=1 in the
		page's address), so it jumps in as soon as it's loaded. The built-in screens and transitions honor it; a game's own can too. */
	public static var quick(get, never):Bool;

	static function get_quick():Bool
		return helix.host.Host.running && helix.host.Host.getOption("quick", "0") == "1";

	/** Calls step once a frame with the frame's seconds, until it returns false. A step added while the steps run starts on the next frame.
		Outside a running game (a unit test) nothing calls it. */
	public static function run(step:Float->Bool):Void {
		if (!installed && helix.host.Host.running)
			helix.host.Host.installPart(runner -> {
				installed = true;
				runner.install({
					update: _ -> tick(helix.time.Time.frameElapsed),
					shutdown: () -> {
						steps = [];
						installed = false;
					}
				});
				null;
			});
		steps.push(step);
	}

	// A frame of dt seconds: every step, those done dropped; one added during a step runs from the next frame.
	static function tick(dt:Float):Void {
		var now = steps;
		steps = [];
		for (step in now)
			if (step(dt))
				steps.push(step);
	}
}
