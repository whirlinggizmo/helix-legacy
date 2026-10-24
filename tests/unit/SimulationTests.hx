import Game.Body;
import helix.input.Input;
import helix.input.InputState;
import helix.input.Key;
import helix.input.PadButton;
import helix.input.PadAxis;
import helix.debug.Autopilot;

class SimulationTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	// A script's samples: read once the frame ends (here, when the test answers), no tick while one waits, the input it returned then played
	// later with its edges, kept by name in the snapshot, and checked unlike an earlier one point by point.
	static function samples(g:Game):Void {
		var asked:Array<{points:Array<Array<Float>>, done:Array<Array<Int>>->Void, failed:String->Void}> = [];
		function pilot(commands:String):Autopilot
			return new Autopilot('{"version":1,"seed":1,"commands":[' + commands + ']}', null, null,
				(points, done, failed) -> asked.push({points: points, done: done, failed: failed}));
		var off = '{"op":"sample","name":"off","points":[[1,2],[3.5,4]]}',
			on = '{"op":"sample","name":"on","points":[[1,2],[3.5,4]],"tolerance":9,"differsFrom":"off","by":10}';
		var script = pilot('{"op":"press","key":"Enter"},' + off + ',' + on);
		var input = script.advance(g.probe);
		check(input.isDown(Key.Enter) && !script.awaitingFrame && script.tickCount == 1, "The press's tick");
		input = script.advance(g.probe);
		check(script.awaitingFrame && asked.length == 1 && asked[0].points[1][0] == 3.5 && script.tickCount == 1,
			"A sample asks for its frame once and waits for it, taking no tick");
		script.advance(g.probe);
		check(script.awaitingFrame && asked.length == 1, "Still waiting for the frame: not asked again");
		asked[0].done([[10, 20, 30, 255], [0, 0, 0, 255]]);
		input = script.advance(g.probe);
		check(input.isFrameReleased(Key.Enter), "The release returned while waiting reaches the input played next");
		check(script.awaitingFrame && asked.length == 2, "The frame read, the next sample asks for its own");
		asked[1].done([[10, 20, 45, 255], [12, 0, 0, 255]]);
		script.advance(g.probe);
		var kept:Dynamic = script.snapshot.samples;
		check(script.done
			&& kept.off.colors[0][2] == 30
			&& kept.off.tolerance == 3
			&& kept.on.tolerance == 9
			&& kept.on.points[1][1] == 4,
			"Each sample kept by name: points, colors and tolerance (3 unless given)");
		asked = [];
		var same = pilot(off + ',' + on);
		same.advance(g.probe);
		asked[0].done([[10, 20, 30, 255], [0, 0, 0, 255]]);
		same.advance(g.probe);
		asked[1].done([[10, 20, 45, 255], [0, 0, 9, 255]]);
		rejects(() -> same.advance(g.probe), "A point less unlike the sample it must differ from than by fails the script");
		var alike = '{"op":"sample","name":"alike","points":[[1,2],[3.5,4]],"matches":"off","within":2}';
		for (second in [[[11, 21, 30, 255], [0, 2, 0, 255]], [[10, 20, 30, 255], [0, 0, 3, 255]]]) {
			asked = [];
			var matching = pilot(off + ',' + alike);
			matching.advance(g.probe);
			asked[0].done([[10, 20, 30, 255], [0, 0, 0, 255]]);
			matching.advance(g.probe);
			asked[1].done(second);
			if (second[1][2] == 0) {
				matching.advance(g.probe);
				check(matching.done, "A sample within its match's amount at every point passes");
			} else
				rejects(() -> matching.advance(g.probe), "A point further from the sample it must match than within fails the script");
		}
		asked = [];
		var failing = pilot(off);
		failing.advance(g.probe);
		asked[0].failed("No frame has ended");
		rejects(() -> failing.advance(g.probe), "A frame that can't be read fails the script");
		rejects(() -> new Autopilot('{"version":1,"seed":1,"commands":[' + off + ']}').advance(g.probe), "A sample with nothing to read with fails");
		for (bad in [
			'{"op":"sample","name":"x","points":[]}',
			'{"op":"sample","name":"x","points":[[1]]}',
			'{"op":"sample","name":"x y","points":[[1,2]]}',
			'{"op":"sample","name":"x","points":[[1,2]],"tolerance":256}',
			'{"op":"sample","name":"x","points":[[1,2]],"by":4}',
			'{"op":"sample","name":"x","points":[[1,2]],"differsFrom":"x","by":4}',
			off + ',' + off,
			off + ',{"op":"sample","name":"x","points":[[1,2]],"differsFrom":"off","by":4}',
			off + ',{"op":"sample","name":"x","points":[[1,2],[3,4]],"differsFrom":"off","by":0}',
			off + ',{"op":"sample","name":"x","points":[[1,2],[3,4]],"matches":"off"}',
			off + ',{"op":"sample","name":"x","points":[[1,2]],"matches":"off","within":2}',
			off + ',{"op":"sample","name":"x","points":[[1,2],[3,4]],"matches":"off","within":256}'
		])
			rejects(() -> pilot(bad), "An invalid sample rejected: " + bad);
	}

	// A drag: the pointer pressed at its start, moved a straight line over its ticks, let go at its end on the tick after; without a runner the
	// points are the pointer's as given. Text typed on one tick while text entry is on, and dropped while it's off.
	static function pointerAndText(g:Game):Void {
		var script = new Autopilot('{"version":1,"seed":1,"commands":[{"op":"drag","from":[10,20],"to":[50,40],"ticks":4},'
			+ '{"op":"type","text":"#ff8800"},{"op":"type","text":"ab"}]}');
		var input = script.advance(g.probe);
		check(input.pointerDown && input.pointerFramePressed && input.pointerX == 10 && input.pointerY == 20, "A drag presses at its start");
		input = script.advance(g.probe);
		check(input.pointerDown && !input.pointerFramePressed && input.pointerX == 20 && input.pointerY == 25, "and moves a quarter of the way");
		for (_ in 0...3)
			input = script.advance(g.probe);
		check(input.pointerDown && input.pointerX == 50 && input.pointerY == 40, "reaching its end after its ticks");
		input = script.advance(g.probe);
		check(!input.pointerDown && input.pointerFrameReleased && input.pointerX == 50, "let go there on the tick after");
		input.textEntry = true;
		input = script.advance(g.probe);
		check(input.text == "#ff8800" && script.tickCount == 7, "Text typed on a tick of its own");
		input.textEntry = false;
		input = script.advance(g.probe);
		check(input.text == "" && !script.done, "Dropped while text entry is off");
		script.advance(g.probe);
		check(script.done, "Done");
		for (bad in [
			'{"op":"drag","from":[1,2],"to":[3,4]}',
			'{"op":"drag","from":[1],"to":[3,4],"ticks":2}',
			'{"op":"drag","from":[1,2],"to":[3,4],"ticks":0}',
			'{"op":"type","text":""}',
			'{"op":"type","text":5}'
		])
			rejects(() -> new Autopilot('{"version":1,"seed":1,"commands":[' + bad + ']}'), "An invalid drag or type rejected: " + bad);
	}

	// Points naming widgets: checked as a script is read, found through the app's locate (here a fake one over named rectangles: a point at
	// fractions of its widget's, or its part's) every time they're used, so a moving layout is followed; waited for while not found, ticking,
	// and failing the script after its seconds; a sample keeps the points as found, a click with "at" clicks the pointer there.
	static function widgetPoints(g:Game):Void {
		var rectangles = new Map<String, Array<Float>>();
		rectangles.set("box", [100, 200, 50, 20]);
		rectangles.set("box/knob", [10, 10, 4, 4]);
		var asked:Array<{points:Array<Array<Float>>, done:Array<Array<Int>>->Void, failed:String->Void}> = [];
		function locate(target:String, part:String, x:Float, y:Float, out:Array<Float>):Bool {
			var r = rectangles.get(part == "" ? target : target + "/" + part);
			if (r == null)
				return false;
			out[0] = r[0] + r[2] * x;
			out[1] = r[1] + r[3] * y;
			return true;
		}
		function pilot(commands:String):Autopilot
			return new Autopilot('{"version":1,"seed":1,"commands":[' + commands + ']}', null, name -> false,
				(points, done, failed) -> asked.push({points: points, done: done, failed: failed}), (t, p, x, y, out) -> locate(t, p, x, y, out));
		var box = '{"target":"box","at":[0,0]}',
			far = '{"target":"box","at":[1,1]}',
			knob = '{"target":"box","part":"knob","at":[0.5,0.5]}';
		pilot('{"op":"sample","name":"a","points":['
			+ box
			+ ',[1,2],'
			+ knob
			+ '],"seconds":2},'
			+ '{"op":"drag","from":'
			+ box
			+ ',"to":[3,4],"ticks":2,"seconds":1},'
			+ '{"op":"sample","name":"b","points":[[0,0],[1,1],{"target":"box","at":[-0.5,1.5]}],"differsFrom":"a","by":1},'
			+ '{"op":"click","target":"box","part":"knob","at":[0.5,0.5],"seconds":1}');
		for (bad in [
			'{"op":"sample","name":"x","points":[{"target":"","at":[0,0]}]}',
			'{"op":"sample","name":"x","points":[{"target":"box"}]}',
			'{"op":"sample","name":"x","points":[{"target":"box","at":[0]}]}',
			'{"op":"sample","name":"x","points":[{"target":"box","at":[0,0],"where":1}]}',
			'{"op":"sample","name":"x","points":[{"target":"box","part":"","at":[0,0]}]}',
			'{"op":"sample","name":"x","points":[{"target":"box","part":3,"at":[0,0]}]}',
			'{"op":"sample","name":"x","points":[[1,2]],"seconds":0}',
			'{"op":"drag","from":' + box + ',"to":[3,4],"ticks":2,"seconds":700}',
			'{"op":"click","target":"box","part":"knob","seconds":1}',
			'{"op":"click","target":"box","at":[0.5],"seconds":1}'
		])
			rejects(() -> pilot(bad), "An invalid widget point rejected: " + bad);

		// A drag from a widget's corner to its other corner: found on the press, the end followed as the widget moves.
		var drag = pilot('{"op":"drag","from":' + box + ',"to":' + far + ',"ticks":2}');
		var input = drag.advance(g.probe);
		check(input.pointerDown && input.pointerX == 100 && input.pointerY == 200, "A drag presses at its widget's point");
		input = drag.advance(g.probe);
		check(input.pointerX == 125 && input.pointerY == 210, "and moves halfway to the other");
		rectangles.set("box", [300, 200, 50, 20]);
		input = drag.advance(g.probe);
		check(input.pointerDown && input.pointerX == 350 && input.pointerY == 220, "its end found again as the widget moves");
		input = drag.advance(g.probe);
		check(!input.pointerDown && input.pointerX == 350, "let go there");
		rectangles.set("box", [100, 200, 50, 20]);

		// A widget not shown yet: waited for, ticking, without pressing; then the drag runs as from its first tick.
		var later = pilot('{"op":"drag","from":{"target":"later","at":[0.5,0.5]},"to":{"target":"later","at":[1,1]},"ticks":1}');
		for (_ in 0...3) {
			input = later.advance(g.probe);
			check(!input.pointerDown && !later.done && !later.awaitingFrame, "A drag waits for its widget, not pressing");
		}
		check(later.tickCount == 3, "ticking as it waits");
		rectangles.set("later", [0, 0, 10, 10]);
		input = later.advance(g.probe);
		check(input.pointerDown && input.pointerFramePressed && input.pointerX == 5 && input.pointerY == 5, "then presses once it's there");
		rectangles.remove("later");
		rejects(() -> later.advance(g.probe), "A drag's end that's gone fails the script");

		// A sample: its points found as it asks, kept as found; waits for a part not there yet.
		asked = [];
		var sampler = pilot('{"op":"sample","name":"s","points":[' + knob + ',[7,8],{"target":"box","part":"thumb","at":[0,1]}]}');
		sampler.advance(g.probe);
		check(asked.length == 0 && !sampler.awaitingFrame && sampler.tickCount == 1, "A sample waits, ticking, for a part not there");
		rectangles.set("box/thumb", [20, 30, 2, 6]);
		sampler.advance(g.probe);
		check(asked.length == 1 && sampler.awaitingFrame && asked[0].points[0][0] == 12 && asked[0].points[0][1] == 12 && asked[0].points[1][0] == 7
			&& asked[0].points[2][1] == 36,
			"then asks for its frame at the points as found (a plain one as given)");
		asked[0].done([[1, 2, 3, 255], [1, 2, 3, 255], [1, 2, 3, 255]]);
		sampler.advance(g.probe);
		var kept:Dynamic = sampler.snapshot.samples;
		check(sampler.done && kept.s.points[0][0] == 12 && kept.s.points[2][1] == 36, "The sample keeps the points as found");

		// A click at a widget's part: pressed there on one tick, let go the next.
		var clicker = pilot('{"op":"click","target":"box","part":"knob","at":[0,1],"timeout":5}');
		input = clicker.advance(g.probe);
		check(input.pointerDown && input.pointerX == 10 && input.pointerY == 14, "A click with at presses there");
		input = clicker.advance(g.probe);
		check(!input.pointerDown && input.pointerFrameReleased && input.pointerX == 10, "and lets go there");
		clicker.advance(g.probe);
		check(clicker.done, "A pointer click done");

		// Never found: the script fails after its limit, naming the widget and part.
		var ghost = pilot('{"op":"click","target":"ghost","part":"knob","at":[0,0],"timeout":3}'), message = "";
		try {
			for (_ in 0...10)
				ghost.advance(g.probe);
		} catch (error:Dynamic) {
			message = Std.string(error);
		}
		check(message.indexOf("no shown ghost part knob") >= 0
			&& ghost.tickCount == 3, "An unknown widget fails the script after its limit: " + message);
		var lost = pilot('{"op":"sample","name":"x","points":[{"target":"ghost","at":[0,0]}],"seconds":0.001}');
		message = "";
		var started = haxe.Timer.stamp();
		try {
			while (haxe.Timer.stamp() - started < 5)
				lost.advance(g.probe);
		} catch (error:Dynamic) {
			message = Std.string(error);
		}
		check(message.indexOf("no shown ghost") >= 0, "and a sample's, after its seconds");
		rejects(() -> new Autopilot('{"version":1,"seed":1,"commands":[{"op":"drag","from":' + box + ',"to":[1,2],"ticks":1}]}').advance(g.probe),
			"A widget's point with nothing to find it with fails");
	}

	static function rejects(action:Void->Void, message:String):Void {
		var rejected = false;
		try {
			action();
		} catch (error:Dynamic) {
			rejected = true;
		}
		check(rejected, message);
	}

	static function main():Void {
		var g = new Game(), c = new Controls();
		check(g.state == "title" && g.attract.length == 6 && g.rocks.length == 0, "A drifting title field: dressing, no game rocks");
		c.start = true;
		g.step(c);
		check(g.state == "playing" && g.lives == 3 && g.wave == 1 && g.rocks.length == 4, "Start reference wave count");
		c.start = false;
		c.thrust = true;
		for (_ in 0...20)
			g.step(c);
		check(g.ship.y < Game.H * 128, "Thrust accelerates ship");
		c.thrust = false;
		g.ship.x = Game.W * 256 - 1;
		g.ship.vx = 500;
		g.step(c);
		check(g.ship.x < 1000, "Ship wraps");
		check(Game.near(new Body(2 * 256, 0, 0, 0, 1), new Body((Game.W - 1) * 256, 0, 0, 0, 1), 5), "Toroidal seam collision");
		g.rocks = [new Body(100 * 256, 100 * 256, 0, 0, 3)];
		g.bullets = [new Body(100 * 256, 100 * 256, 0, 0, 2, 10)];
		g.step(c);
		check(g.hits == 1 && g.splits == 1 && g.score == 20 && g.rocks.length == 2 && g.bullets.length == 0, "Bullet splits large rock");
		g.rocks = [new Body(g.ship.x, g.ship.y, 0, 0, 3)];
		g.invulnerable = 0;
		g.lives = 1;
		g.ship.vx = g.ship.vy = 0;
		g.step(c);
		check(g.state == "gameover" && g.lives == 0 && g.deaths == 1 && g.best == g.score, "Last collision records best");
		var best = g.best;
		c.title = true;
		g.step(c);
		check(g.state == "title" && g.attract.length == 6 && g.rocks.length == 0, "Return to title");
		c.title = false;
		c.start = true;
		g.step(c);
		check(g.state == "playing" && g.lives == 3 && g.score == 0 && g.best == best, "Restart retains best");
		var a = new Game(73), b = new Game(73);
		for (i in 0...2400) {
			c.replay(i);
			a.step(c);
			b.step(c);
		}
		check(haxe.Json.stringify(a.snapshot()) == haxe.Json.stringify(b.snapshot()), "Seeded replay repeats exactly");
		// When play starts doesn't matter: started after 5 title ticks or 300, the same input from the start gives the same game. A menu, a
		// load or a frame's timing can delay the start without the game differing (the title's rocks are dressing).
		var early = new Game(91), late = new Game(91), idle = new Controls();
		for (_ in 0...5)
			early.step(idle);
		for (_ in 0...300)
			late.step(idle);
		for (g2 in [early, late]) {
			var played = new Controls();
			played.start = true;
			g2.step(played);
			played.start = false;
			for (i in 0...1200) {
				played.replay(i);
				g2.step(played);
			}
		}
		check(haxe.Json.stringify(early.snapshot()) == haxe.Json.stringify(late.snapshot()), "Started 5 or 300 ticks into the title: the same game");
		g = new Game();
		c = new Controls();
		c.start = true;
		g.step(c);
		c.start = false;
		c.fire = true;
		g.rocks = [new Body(200 * 256, 200 * 256, 0, 0, 3)];
		for (_ in 0...30)
			g.step(c);
		check(g.shots == 3, "Fire cooldown bounds rate");
		for (_ in 0...20)
			g.step(c);
		check(g.bullets.length <= 6, "Bullet cap");
		g.bullets = [new Body(50 * 256, 50 * 256, 0, 0, 2, 1)];
		c.fire = false;
		g.step(c);
		check(g.bullets.length == 0, "Bullet expiry");
		g.rocks = [];
		var wave = g.wave;
		for (_ in 0...89)
			g.step(c);
		check(g.wave == wave && g.waveDelay == 89, "Wave delay preserved");
		g.step(c);
		check(g.wave == wave + 1, "Wave advances after 90 ticks");
		g.score = 9980;
		g.lives = 2;
		g.addScore(20);
		check(g.lives == 3 && g.sounds.indexOf(5) >= 0, "Extra life every 10000 points");
		g.rocks = [new Body(g.ship.x, g.ship.y, 0, 0, 3)];
		g.ship.vx = g.ship.vy = 0;
		g.invulnerable = 0;
		g.step(c);
		check(g.respawnDelay == 120 && g.lives == 2, "Two-second respawn delay");
		for (_ in 0...120)
			g.step(c);
		check(g.respawnDelay == 0 && g.invulnerable > 0, "Respawn grants invulnerability");
		var state = new InputState();
		state.keyEvent(Key.Enter, true);
		state.keyEvent(Key.Enter, false);
		check(!state.isDown(Key.Enter) && state.isPressed(Key.Enter) && state.isReleased(Key.Enter), "Short tap retains both edges");
		@:privateAccess Input.bind(state);
		c.read();
		check(c.start, "Controls see short tap");
		state.consume();
		check(!state.isPressed(Key.Enter) && !state.isReleased(Key.Enter), "Consume once");
		state.keyEvent(Key.Space, true);
		state.consume();
		state.keyEvent(Key.Space, true);
		check(state.isDown(Key.Space) && !state.isPressed(Key.Space), "Key repeat is not a new edge");
		state.clear();
		check(!state.isDown(Key.Space) && state.isReleased(Key.Space), "Focus clear releases held key");
		state.padEvent(PadButton.East, true);
		state.axisEvent(PadAxis.LeftX, -.8);
		state.axisEvent(PadAxis.RightTrigger, .7);
		@:privateAccess Input.bind(state);
		c.read();
		check(c.fire && c.left && c.thrust, "Standard controller actions");
		state.clear();
		check(state.getPadAxis(PadAxis.LeftX) == 0 && !state.isPadDown(PadButton.East), "Controller disconnect clears state");
		for (name in ["smoke", "playthrough"]) {
			// The game-over menu's Title, pressed by name as the app's Ui.press would.
			var wantTitle = false;
			var pilot = new Autopilot(sys.io.File.getContent("examples/asteroids/autopilot/" + name + ".json"), null,
				target -> target == "title" && g.state == "gameover" ? wantTitle = true : false);
			g = new Game(pilot.seed);
			c = new Controls();
			for (_ in 0...15000) {
				var source = pilot.advance(g.probe);
				if (pilot.done)
					break;
				@:privateAccess Input.bind(source);
				c.read();
				c.title = wantTitle;
				wantTitle = false;
				g.step(c);
				source.consume();
			}
			check(pilot.done, "Autopilot " + name + " completes");
			if (name == "playthrough")
				check(g.state == "playing" && g.lives == 3 && g.score == 0, "Autopilot covers gameover/title/restart");
		}
		rejects(() -> new Autopilot('{"version":1,"seed":1,"commands":[{"op":"hold","keys":[],"ticks":-1}]}'), "Invalid script duration rejected");
		var timeout = new Autopilot('{"version":1,"seed":1,"commands":[{"op":"wait","probe":"state","equals":"never","timeout":1}]}');
		timeout.advance(g.probe);
		rejects(() -> timeout.advance(g.probe), "Unmet wait fails with bounded timeout");
		// A failure is published at once (the check reports it without waiting out its limit), once, and thrown again if advanced again;
		// an invalid script's too.
		var harness = new RecordingHarness(),
			was = @:privateAccess helix.debug.TestHarness.instance;
		@:privateAccess helix.debug.TestHarness.instance = harness;
		var failing = new Autopilot('{"version":1,"seed":1,"commands":[{"op":"assert","probe":"state","equals":"never"}]}');
		rejects(() -> failing.advance(g.probe), "An unmet assert fails");
		rejects(() -> failing.advance(g.probe), "A failed script fails again");
		check(harness.published.length == 1
			&& StringTools.startsWith(harness.published[0].failed, "Autopilot assertion failed at command 0")
			&& harness.published[0].autopilot.failed == failing.failure,
			"The failure published once, with the snapshot");
		rejects(() -> new Autopilot('{"version":1,"seed":1,"commands":[{"op":"jump"}]}'), "An unknown command rejected");
		check(harness.published.length == 2
			&& harness.published[1].failed == "Unknown autopilot command", "An invalid script's failure published");
		@:privateAccess helix.debug.TestHarness.instance = was;
		rejects(() -> new Autopilot('{"version":1,"seed":1,"commands":[{"op":"wait","probe":"state","equals":"x"}]}'), "A wait needs a limit");
		rejects(() -> new Autopilot('{"version":1,"seed":1,"commands":[{"op":"wait","probe":"state","equals":"x","timeout":5,"seconds":1}]}'),
			"A wait has one limit");
		var patient = new Autopilot('{"version":1,"seed":1,"commands":[{"op":"wait","probe":"state","equals":"never","seconds":30}]}');
		for (_ in 0...500)
			patient.advance(g.probe);
		check(!patient.done, "A wait in seconds outlasts any tick count, until its seconds pass");
		var shots:Array<Null<String>> = [];
		var shooter = new Autopilot('{"version":1,"seed":1,"commands":[{"op":"screenshot","name":"title.png"},{"op":"screenshot"},{"op":"press","key":"Enter"}]}',
			name -> shots.push(name));
		shooter.advance(g.probe);
		check(shots.length == 2 && shots[0] == "title.png" && shots[1] == null && shooter.tickCount == 1, "Screenshots take no tick, named or not");
		rejects(() -> new Autopilot('{"version":1,"seed":1,"commands":[{"op":"screenshot","name":"../x.png"}]}'), "A screenshot name with a path rejected");
		samples(g);
		pointerAndText(g);
		widgetPoints(g);
		trace(haxe.Json.stringify({checks: checks, passed: true, replay: a.snapshot()}));
	}
}

// What's published, kept.
class RecordingHarness implements helix.debug.ITestHarness {
	public var published:Array<Dynamic> = [];

	public function new() {}

	public function publish(value:Dynamic):Void
		published.push(value);
}
