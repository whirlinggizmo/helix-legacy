package helix.debug;

import helix.App;
import helix.asset.Assets;
import helix.graphics.Screenshots;
import helix.host.Host;
import helix.input.Input;

/** Plays an autopilot script through a game with probes (App.probe), attached to it by helix.macro.AppBuild, so a game writes no loop of
	its own: with the option autopilot naming a script under assets/, it loads the script before the game's init, then each frame plays
	the script's ticks, each an update(1 / 60), one a frame (up to 120 with fast=1), a press ending the frame's ticks (so what runs itself
	once a frame, a splash or a transition, reads it), none while a sample waits for its frame. Once the script is done it publishes the
	probes it names, read then, with its snapshot (TestHarness.publish: {game, autopilot}), and quits with autoclose=1; after that the game
	updates as usual. A script that fails, or doesn't load, is published as failed (Autopilot.failure). Without the option it does nothing. */
@:noCompletion
class AutopilotDriver {
	/** Ticks a frame with fast=1. */
	public static inline var FAST_TICKS = 120;

	/** Attaches to app when the run asks for a script (the autopilot option). */
	@:access(helix.App)
	public static function attach(app:App):Void {
		var script = Host.getOption("autopilot", "");
		if (script == "")
			return;
		var fast = Host.getOption("fast", "0") == "1",
			close = Host.getOption("autoclose", "0") == "1";
		var pilot:Null<Autopilot> = null, published = false;
		app.autopilotStart = go -> Assets.load(script, bytes -> {
			// An invalid script throws, its failure published.
			pilot = new Autopilot(bytes.toString(), name -> Screenshots.take(name), name -> app.pressWidget(name),
				(points, done, failed) -> Screenshots.sample(points, done, failed), (target, part, x, y, out) -> app.locateWidget(target, part, x, y, out));
			app.autopilot = pilot;
			go();
		}, message -> {
			var failure = 'Autopilot script $script did not load: $message';
			if (TestHarness.instance != null)
				TestHarness.publish({failed: failure});
			Log.error(failure, "autopilot");
		});
		app.autopilotFrame = dt -> {
			if (pilot == null || pilot.failure != null)
				return pilot != null;
			if (!pilot.done) {
				for (_ in 0...(fast ? FAST_TICKS : 1)) {
					pilot.advance(name -> app.probe(name));
					if (pilot.done || pilot.awaitingFrame)
						break;
					app.update(1 / 60);
					if (Input.anyFramePressed)
						break;
				}
				if (!pilot.done)
					return true;
			}
			if (!published) {
				published = true;
				var game:Dynamic = {};
				for (name in pilot.probeNames)
					Reflect.setField(game, name, app.probe(name));
				TestHarness.publish({game: game, autopilot: pilot.snapshot});
				if (close)
					Host.quit();
			}
			return false;
		};
	}
}
