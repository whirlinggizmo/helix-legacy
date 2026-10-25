package helix.scene;

/** What runs the screens that run themselves (a Transition, LoadingScreen, SplashScreen) while they're on the stage: each a step called once a frame,
	after the app's update and before the frame is drawn, with the frames' seconds (not the game's clock: a paused game still transitions),
	until it says it's done. Installed by the first one (an optional part, helix.host.Part). A completion's lifetime: each step dies with
	its screen (decision 123). */
@:noCompletion
class Flow {
	static var steps:Array<Float->Bool> = [];
	static var installed = false;

	/** Whether the built-in screens' waits and every transition are skipped: the run option quick=1 (a developer's), so the game jumps in as
		soon as it's loaded. */
	public static var quick(get, never):Bool;

	static function get_quick():Bool
		return helix.host.Host.running && helix.host.Host.getOption("quick", "0") == "1";

	/** Calls step once a frame, with the frames' seconds, until it returns false. Outside the runner (a test) nothing calls the steps but
		tick. */
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
