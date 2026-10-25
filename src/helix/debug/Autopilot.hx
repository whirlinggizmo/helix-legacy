package helix.debug;

import helix.input.IInput;
import helix.input.Input;
import helix.input.Key;
import helix.input.InputState;

/** Bounded JSON commands produce normal input, a tick at a time; probes (named values) are supplied by the app. A script replays alike on
	every target when it keeps two rules:
	- It waits on state, never on time, for anything that isn't the simulation's (a load, a menu, a screen appearing): `wait` on a probe, its
	  limit in seconds (`"seconds"`); tick counts (`"timeout"`, `hold`) only for what the simulation itself does, once a wait has found it
	  running.
	- The game starts each replayed phase from a known state when it begins: play starting fresh from the seed (a new level), however late it
	  starts; a title screen's motion is dressing, not part of the game. Then a menu, a slow load or a frame's timing can delay a start without
	  the game differing.

	A `sample` reads the frame's pixels at points and puts them in snapshot's samples under its name, which tools/example.py compares
	between the browser and native: `{"op": "sample", "name": "lit", "points": [[x, y], ...]}`, the points in the design's units (Screen's),
	1 to 64 of them; `"tolerance"`, how far each channel (0 to 255) may differ across targets, 3 when not given; and `"differsFrom"` with
	`"by"`, an earlier sample's name and an amount, failing the script unless every point differs from the same point there by at least that
	much in some channel (an effect turned on against it off, so a shader drawing nothing fails); and `"matches"` with `"within"`, an earlier
	sample's name and an amount, failing it unless every point is within that much of the same point there in every channel (what must look
	the same either way, as a background with an HDR chain and without). The frame read is the one drawn after the
	ticks before it: while it waits for that frame to end, awaitingFrame is true and the app runs no tick.

	A `touch` is fingers on the touch screen, as a drag is the pointer, several at once for a gesture or a second thumb:
	`{"op": "touch", "ticks": n, "fingers": [{"from": [x, y], "to": [x, y]}, {"from": ..., "to": ..., "start": 5, "end": 15}]}`, 1 to 10
	fingers, their ids 1, 2 ... in the order listed. Each lands at from on its start tick (0 when not given), moves a straight line to reach
	to on its end tick (ticks when not given; start to end within 0 to ticks), and lifts there on the tick after; the command ends once every
	finger has lifted. Its points are a drag's (the design's units, or a widget's, found again every tick). The fingers are a touch screen's:
	the first down is the pointer too (a tap clicks), a second lets the pointer go (a pinch clicks nothing).

	A `drag` is the pointer held down at one point and moved to another: `{"op": "drag", "from": [x, y], "to": [x, y], "ticks": n}`, the
	points in the design's units (Screen's; as given without a runner, in a test), pressed at from on its first tick, moved a straight line to
	reach to after n more, and let go there on the tick after. A `type` is text typed on one tick, as a keyboard's characters arrive (dropped,
	as theirs are, while nothing has asked for text entry: focus a text field first): `{"op": "type", "text": "ff8800"}`.

	Any point (a sample's, a drag's) may instead be a widget's: `{"target": "background", "part": "hue", "at": [.3, .5]}`, at fractions of
	the rectangle of the UI's widget named target, or of its part named part (Ui.computePoint lists them: a slider's track, a color picker's
	square and bars, a scrollbar's thumb, a list's rows ...), 0, 0 its top left and 1, 1 its bottom right, outside it past them. So a script
	keeps working when padding, gaps or a widget's size move the layout. Each is found where the widget was last drawn when the point is
	used: a sample's as it asks for its frame; a drag's from as it presses, its to again every tick. One not found (no such widget shown, or
	no such part now) is waited for, as a click waits, within the command's "seconds" (5 when not given), and fails the script after. A
	`click` with `"at"` (and `"part"`) presses and lets go of the pointer there instead of using the widget by name.

	With a program's input bound (under the runner), while it plays, that input (Input) is the script's: a Ui, a pointer looking at the stage and the screens that
	run themselves (Splash, Loading, a Transition) play it as they read Input, with nothing handed to them; the program's own input is back
	once every command has finished. */
class Autopilot {
	var ticks = 0;

	// The program's input while the script plays as it, put back once it's done.
	var programInput:Null<IInput>;

	/** Whether every command has finished. */
	public var done(default, null):Bool = false;

	/** Why the script failed (an assertion, a wait timing out, an invalid script), or null while it hasn't. A failure is published at once
		(TestHarness.publish: {failed, autopilot: snapshot}), so the check that launched the program reports it without waiting out its
		limit, and thrown, as before. */
	public var failure(default, null):Null<String>;

	/** The probes the script names (its waits' and asserts'), each once, in the script's order: what a game's final state is published as. */
	public var probeNames(get, never):Array<String>;

	function get_probeNames():Array<String> {
		var names = [];
		for (command in commands)
			if (Reflect.hasField(command, "probe") && names.indexOf(command.probe) < 0)
				names.push(command.probe);
		return names;
	}

	/** Ticks the commands have run so far. */
	public var tickCount(get, never):Int;

	function get_tickCount():Int
		return ticks;

	/** The input the script plays, the one advance returns: the same object for the whole script, so what reads it (a UI, an Actions map)
		can be given it before the first tick. */
	public var input(get, never):IInput;

	function get_input():IInput
		return state;

	/** The script's seed, 1 to 2147483647, for the app's random numbers. */
	public var seed(default, null):Int;

	/** One record a finished command: its index, op, the tick it finished on and the probe's value. */
	public var outcomes(default, null):Array<Dynamic> = [];

	var commands:Array<Dynamic>;
	var index = 0;
	var elapsed = 0;
	// The script's input, made as a platform's is (InputRouter): its fingers through the router, so the first finger down is the pointer and
	// a second lets it go, as on a touch screen.
	var router = new helix.input.InputRouter();
	var state:InputState;
	var screenshot:Null<Null<String>->Void>;
	var press:Null<String->Bool>;
	var sample:Null<(points:Array<Array<Float>>, done:Array<Array<Int>>->Void, failed:String->Void) -> Void>;
	var locate:Null<(target:String, part:String, x:Float, y:Float, out:Array<Float>) -> Bool>;
	// A drag's or a pointer click's press, once its points were found: the elapsed tick it pressed on (-1 before), and where, with where it
	// goes, in the pointer's pixels.
	var pressedAt = -1;
	var from = [0., 0.];
	var to = [0., 0.];
	// A sample's points as found, in the design's units.
	var sampledPoints:Array<Array<Float>> = [];
	var waitStarted = 0.;
	var samples:Dynamic = {};
	var sampleAsked = false;
	var sampled:Null<Array<Array<Int>>>;
	var sampleFailure:Null<String>;

	/** Whether a sample waits for the frame being drawn to end: the input advance returned isn't to be played, and the app runs no tick this
		frame (its tick loop stops when this is true, as it does when done). */
	public var awaitingFrame(default, null):Bool = false;

	/** Checks a whole script ({version: 1, seed, commands}: press, hold, wait, assert, click, screenshot, sample, drag, touch, type; at most 128) and throws on
		anything invalid or unknown. A wait has one limit: "timeout" in ticks, or "seconds" of the clock. A click uses a UI's widget by name,
		waiting (as a web suite's actions do) until press, the app's (Ui.press, say), finds it shown and usable, within its limit; without press
		it fails; one with "at" (and "part") clicks the pointer at that point of the widget instead, waiting until it's found. A screenshot command calls screenshot with its name (null for the default name; Screenshots.take, say), or does nothing without
		one. A sample calls sample with its points (Screenshots.sample, say), which calls done with each point's color as [r, g, b, a], 0 to 255,
		once the frame has ended, or failed; without sample it fails. A point naming a widget asks locate (Ui.computePoint, say) for the
		framebuffer pixel at its fractions of the widget's or its part's rectangle (written to out; as given without a runner, in a test),
		waiting while it answers false; without locate it fails. */
	public function new(json:String, ?screenshot:Null<String>->Void, ?press:String->Bool,
			?sample:(points:Array<Array<Float>>, done:Array<Array<Int>>->Void, failed:String->Void) -> Void,
			?locate:(target:String, part:String, x:Float, y:Float, out:Array<Float>) -> Bool) {
		state = @:privateAccess router.state;
		this.screenshot = screenshot;
		this.press = press;
		this.sample = sample;
		this.locate = locate;
		try
			load(json)
		catch (e:haxe.Exception) {
			fail(e.message);
			throw e;
		}
		// While it plays, the program's input is the script's (Input), so what reads it (a Ui, a pointer looking at the stage, a splash or a
		// loading screen) plays it with nothing handed over; the program's own is back once every command has finished.
		if (Input.instance != null) {
			programInput = Input.instance;
			@:privateAccess Input.bind(state);
		}
	}

	// Checks the script and takes its seed and commands; throws on anything invalid.
	function load(json:String):Void {
		var document:Dynamic = haxe.Json.parse(json);
		fields(document, ["version", "seed", "commands"]);
		if (document.version != 1
			|| !integer(document.seed, 1, 2147483647)
			|| !Std.isOfType(document.commands, Array)
			|| document.commands.length == 0
			|| document.commands.length > 128)
			throw "Invalid autopilot header";
		seed = document.seed;
		commands = document.commands;
		// Each sample's name and its number of points, in the script's order: what a later one's differsFrom may name.
		var sampleCounts = new Map<String, Int>();
		for (command in commands) {
			switch (command.op) {
				case "press":
					fields(command, ["op", "key"]);
					if (!Std.isOfType(command.key, String))
						throw "Invalid press";
					Key.named(command.key);
				case "hold":
					fields(command, ["op", "keys", "ticks"]);
					keys(command.keys);
					if (!integer(command.ticks, 1, 36000))
						throw "Invalid hold duration";
				case "wait":
					fields(command, ["op", "probe"], ["equals", "atLeast", "keys", "timeout", "seconds"]);
					condition(command);
					// Exactly one limit: ticks for what the simulation does, seconds for what happens outside it (a load, a menu).
					if (Reflect.hasField(command, "timeout") == Reflect.hasField(command, "seconds"))
						throw "A wait needs a timeout in ticks or in seconds";
					if (Reflect.hasField(command, "timeout") && !integer(command.timeout, 1, 36000))
						throw "Invalid wait timeout";
					if (Reflect.hasField(command, "seconds")
						&& (!Std.isOfType(command.seconds, Float) || !(command.seconds > 0) || command.seconds > 600))
						throw "Invalid wait seconds";
					if (command.keys != null)
						keys(command.keys);
				case "assert":
					fields(command, ["op", "probe"], ["equals", "atLeast"]);
					condition(command);
				case "click":
					fields(command, ["op", "target"], ["timeout", "seconds", "part", "at"]);
					if (!Std.isOfType(command.target, String) || command.target == "")
						throw "Invalid click target";
					if (Reflect.hasField(command, "part") && !Reflect.hasField(command, "at"))
						throw "A click's part goes with at";
					if (Reflect.hasField(command, "at"))
						point({target: command.target, part: command.part, at: command.at});
					if (Reflect.hasField(command, "timeout") == Reflect.hasField(command, "seconds"))
						throw "A click needs a timeout in ticks or in seconds";
					if (Reflect.hasField(command, "timeout") && !integer(command.timeout, 1, 36000))
						throw "Invalid click timeout";
					if (Reflect.hasField(command, "seconds")
						&& (!Std.isOfType(command.seconds, Float) || !(command.seconds > 0) || command.seconds > 600))
						throw "Invalid click seconds";
				case "screenshot":
					fields(command, ["op"], ["name"]);
					if (command.name != null
						&& (!Std.isOfType(command.name, String) || !~/^[A-Za-z0-9_-]{1,64}\.png$/.match(command.name)))
						throw "Invalid screenshot name";
				case "sample":
					fields(command, ["op", "name", "points"], ["tolerance", "differsFrom", "by", "matches", "within", "seconds"]);
					limit(command);
					if (!Std.isOfType(command.name, String)
						|| !~/^[A-Za-z0-9_-]{1,64}$/.match(command.name)
						|| sampleCounts.exists(command.name))
						throw "Invalid or repeated sample name";
					var count = points(command.points);
					if (Reflect.hasField(command, "tolerance") && !integer(command.tolerance, 0, 255))
						throw "Invalid sample tolerance";
					if (Reflect.hasField(command, "differsFrom") != Reflect.hasField(command, "by"))
						throw "A sample's differsFrom and by go together";
					if (Reflect.hasField(command, "differsFrom")
						&& (!Std.isOfType(command.differsFrom, String) || sampleCounts.get(command.differsFrom) != count))
						throw "A sample differs from an earlier sample of as many points";
					if (Reflect.hasField(command, "by") && !integer(command.by, 1, 255))
						throw "Invalid sample difference";
					if (Reflect.hasField(command, "matches") != Reflect.hasField(command, "within"))
						throw "A sample's matches and within go together";
					if (Reflect.hasField(command, "matches")
						&& (!Std.isOfType(command.matches, String) || sampleCounts.get(command.matches) != count))
						throw "A sample matches an earlier sample of as many points";
					if (Reflect.hasField(command, "within") && !integer(command.within, 0, 255))
						throw "Invalid sample match";
					sampleCounts.set(command.name, count);
				case "drag":
					fields(command, ["op", "from", "to", "ticks"], ["seconds"]);
					limit(command);
					point(command.from);
					point(command.to);
					if (!integer(command.ticks, 1, 36000))
						throw "Invalid drag duration";
				case "touch":
					fields(command, ["op", "fingers", "ticks"], ["seconds"]);
					limit(command);
					if (!integer(command.ticks, 1, 36000))
						throw "Invalid touch duration";
					if (!Std.isOfType(command.fingers, Array) || command.fingers.length == 0 || command.fingers.length > 10)
						throw "A touch needs 1 to 10 fingers";
					for (finger in (cast command.fingers : Array<Dynamic>)) {
						fields(finger, ["from", "to"], ["start", "end"]);
						point(finger.from);
						point(finger.to);
						var start:Dynamic = Reflect.hasField(finger, "start") ? finger.start : 0,
							end:Dynamic = Reflect.hasField(finger, "end") ? finger.end : command.ticks;
						if (!integer(start, 0, command.ticks) || !integer(end, 0, command.ticks) || start > end)
							throw "Invalid finger start or end";
					}
				case "type":
					fields(command, ["op", "text"]);
					if (!Std.isOfType(command.text, String) || command.text.length == 0 || command.text.length > 256)
						throw "Invalid typed text";
				default:
					throw "Unknown autopilot command";
			}
		}
	}

	// The script failed: message kept and published, once; the program's own input back.
	function fail(message:String):Void {
		if (failure != null)
			return;
		failure = message;
		if (programInput != null && Input.instance == state)
			@:privateAccess Input.bind(programInput);
		if (TestHarness.instance != null)
			TestHarness.publish({failed: message, autopilot: snapshot});
	}

	static function fields(value:Dynamic, required:Array<String>, optional:Array<String> = null):Void {
		if (value == null || !Reflect.isObject(value) || Std.isOfType(value, Array))
			throw "Expected autopilot object";
		if (optional == null)
			optional = [];
		for (field in required)
			if (!Reflect.hasField(value, field))
				throw 'Missing autopilot field ' + field;
		for (field in Reflect.fields(value))
			if (required.indexOf(field) < 0 && optional.indexOf(field) < 0)
				throw 'Unknown autopilot field ' + field;
	}

	static function integer(value:Dynamic, min:Int, max:Int):Bool
		return Std.isOfType(value, Int) && value >= min && value <= max;

	// A sample's points: 1 to 64 [x, y] pairs of finite numbers. Their count.
	static function points(value:Dynamic):Int {
		if (!Std.isOfType(value, Array) || value.length < 1 || value.length > 64)
			throw "Invalid sample points";
		for (p in (cast value : Array<Dynamic>))
			point(p);
		return value.length;
	}

	// A point: an [x, y] pair of finite numbers, or a widget's: {target, at: [x, y], part?}, target and part names.
	static function point(value:Dynamic):Void {
		if (!Std.isOfType(value, Array)) {
			fields(value, ["target", "at"], ["part"]);
			if (!Std.isOfType(value.target, String) || value.target == "")
				throw "Invalid point target";
			if (value.part != null && (!Std.isOfType(value.part, String) || value.part == ""))
				throw "Invalid point part";
			value = value.at;
		}
		if (!Std.isOfType(value, Array) || value.length != 2 || !finite(value[0]) || !finite(value[1]))
			throw "Invalid point";
	}

	// A command's optional limit on waiting for its widgets' points: seconds, more than 0 and at most 600.
	static function limit(command:Dynamic):Void {
		if (Reflect.hasField(command, "seconds")
			&& (!Std.isOfType(command.seconds, Float) || !(command.seconds > 0) || command.seconds > 600))
			throw "Invalid seconds";
	}

	static function finite(value:Dynamic):Bool
		return Std.isOfType(value, Float) && Math.isFinite(value);

	static function keys(value:Dynamic):Array<Key> {
		if (!Std.isOfType(value, Array) || value.length > 12)
			throw "Invalid autopilot keys";
		var result:Array<Key> = [];
		for (item in (cast value : Array<Dynamic>)) {
			if (!Std.isOfType(item, String))
				throw "Invalid key name";
			var key = Key.named(item);
			if (result.indexOf(key) >= 0)
				throw "Duplicate key";
			result.push(key);
		}
		return result;
	}

	static function condition(command:Dynamic):Void {
		if (!Std.isOfType(command.probe, String) || Reflect.hasField(command, "equals") == Reflect.hasField(command, "atLeast"))
			throw "Expected one probe comparison";
		if (Reflect.hasField(command, "atLeast") && (!Std.isOfType(command.atLeast, Float) || !Math.isFinite(command.atLeast)))
			throw "Invalid numeric comparison";
	}

	static function matches(command:Dynamic, value:Dynamic):Bool
		return Reflect.hasField(command,
			"equals") ? haxe.Json.stringify(value) == haxe.Json.stringify(command.equals) : Std.isOfType(value, Float) && value >= command.atLeast;

	function setKeys(desired:Array<Key>):Void {
		for (key in Key.all)
			state.keyEvent(key, desired.indexOf(key) >= 0);
	}

	/** Once a tick: runs commands until one needs this tick, asking probe for named values, and returns the input to play it with. Throws when
		a wait times out or an assert fails (or probe throws), publishing the failure first (failure); once failed, it throws that again. */
	public function advance(probe:String->Dynamic):IInput {
		if (failure != null)
			throw failure;
		try
			return play(probe)
		catch (e:haxe.Exception) {
			fail(e.message);
			throw e;
		}
	}

	function play(probe:String->Dynamic):IInput {
		// A tick is the script's frame too: its tick edges and frame edges both end here; not after a frame awaited, whose input wasn't played.
		if (!awaitingFrame) {
			state.consume();
			state.endFrame();
		}
		while (!done) {
			if (index == commands.length) {
				done = true;
				setKeys([]);
				if (programInput != null && Input.instance == state)
					@:privateAccess Input.bind(programInput);
				break;
			}
			var command = commands[index],
				finish = false,
				value:Dynamic = null;
			switch (command.op) {
				case "press":
					setKeys([Key.named(command.key)]);
					if (elapsed == 1)
						finish = true;
				case "hold":
					setKeys(keys(command.keys));
					if (elapsed == command.ticks)
						finish = true;
				case "wait":
					setKeys(command.keys == null ? [] : keys(command.keys));
					value = probe(command.probe);
					if (elapsed == 0)
						waitStarted = haxe.Timer.stamp();
					if (matches(command, value))
						finish = true;
					else if (Reflect.hasField(command, "timeout") ? elapsed >= command.timeout : haxe.Timer.stamp() - waitStarted >= command.seconds)
						throw 'Autopilot timeout at command ' + index + ': ' + command.probe + '=' + haxe.Json.stringify(value);
				case "assert":
					value = probe(command.probe);
					if (!matches(command, value))
						throw 'Autopilot assertion failed at command ' + index + ': ' + command.probe + '=' + haxe.Json.stringify(value);
					finish = true;
				case "click" if (Reflect.hasField(command, "at")):
					setKeys([]);
					if (elapsed == 0)
						waitStarted = haxe.Timer.stamp();
					var at = {target: command.target, part: command.part, at: command.at};
					if (pressedAt < 0 && resolve(at, from, true))
						pressedAt = elapsed;
					if (pressedAt < 0)
						awaitPoint(command, at);
					else if (elapsed == pressedAt)
						pointer(from[0], from[1], true);
					else if (elapsed == pressedAt + 1)
						pointer(from[0], from[1], false);
					else
						finish = true;
				case "click":
					setKeys([]);
					if (elapsed == 0)
						waitStarted = haxe.Timer.stamp();
					if (press == null)
						throw 'Autopilot click at command ' + index + ' with nothing to press with';
					if (press(command.target))
						finish = true;
					else if (Reflect.hasField(command, "timeout") ? elapsed >= command.timeout : haxe.Timer.stamp() - waitStarted >= command.seconds)
						throw 'Autopilot timeout at command ' + index + ': no usable ' + command.target;
				case "screenshot":
					if (screenshot != null)
						screenshot(command.name);
					finish = true;
				case "drag":
					setKeys([]);
					if (elapsed == 0)
						waitStarted = haxe.Timer.stamp();
					// From found as it presses (it waits until both are), to found again every tick after.
					if (pressedAt < 0 && resolve(command.from, from, true) && resolve(command.to, to, true))
						pressedAt = elapsed;
					if (pressedAt < 0)
						awaitPoint(command, resolve(command.from, from, true) ? command.to : command.from);
					else {
						var length:Int = command.ticks,
							step = elapsed - pressedAt;
						if (step > 0 && step <= length + 1 && !resolve(command.to, to, true))
							throw 'Autopilot drag at command ' + index + ' lost ' + describe(command.to);
						if (step <= length) {
							var t = step / length;
							pointer(from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t, true);
						} else if (step == length + 1)
							pointer(to[0], to[1], false);
						else
							finish = true;
					}
				case "touch":
					setKeys([]);
					if (elapsed == 0)
						waitStarted = haxe.Timer.stamp();
					var fingers:Array<Dynamic> = command.fingers,
						ticks:Int = command.ticks;
					// Pressed once every finger's points are found (waited for as a drag's are), then each finger played tick by tick.
					if (pressedAt < 0) {
						var missing:Dynamic = null;
						for (f in fingers)
							if (missing == null)
								missing = !resolve(f.from, from, true) ? f.from : !resolve(f.to, to, true) ? f.to : null;
						if (missing == null)
							pressedAt = elapsed;
						else
							awaitPoint(command, missing);
					}
					if (pressedAt >= 0) {
						var step = elapsed - pressedAt;
						if (step > ticks + 1)
							finish = true;
						else
							for (i in 0...fingers.length) {
								var f = fingers[i];
								var start:Int = Reflect.hasField(f, "start") ? f.start : 0,
									end:Int = Reflect.hasField(f, "end") ? f.end : ticks;
								if (step < start || step > end + 1)
									continue;
								if (!resolve(f.from, from, true) || !resolve(f.to, to, true))
									throw 'Autopilot touch at command ' + index + ' lost ' + describe(!resolve(f.from, from, true) ? f.from : f.to);
								if (step <= end) {
									var t = end > start ? (step - start) / (end - start) : 1.;
									router.touch(i + 1, from[0] + (to[0] - from[0]) * t, from[1] + (to[1] - from[1]) * t, true);
								} else
									router.touch(i + 1, to[0], to[1], false);
							}
					}
				case "type":
					setKeys([]);
					if (elapsed == 0)
						state.textEvent(command.text);
					else
						finish = true;
				case "sample":
					if (!sampleAsked) {
						if (sample == null)
							throw 'Autopilot sample at command ' + index + ' with nothing to read the frame with';
						if (elapsed == 0)
							waitStarted = haxe.Timer.stamp();
						// Its points found first, waited for (ticking) while one isn't.
						var missing:Dynamic = null;
						sampledPoints = [];
						for (p in (cast command.points : Array<Dynamic>)) {
							var at = [0., 0.];
							if (!resolve(p, at, false)) {
								missing = p;
								break;
							}
							sampledPoints.push(at);
						}
						if (missing != null) {
							awaitPoint(command, missing);
							elapsed++;
							ticks++;
							return state;
						}
						sampleAsked = true;
						sampled = null;
						sampleFailure = null;
						sample(sampledPoints, colors -> sampled = colors, message -> sampleFailure = message);
					}
					if (sampleFailure != null)
						throw 'Autopilot sample failed at command ' + index + ': ' + sampleFailure;
					if (sampled == null) {
						awaitingFrame = true;
						return state;
					}
					awaitingFrame = false;
					sampleAsked = false;
					record(command, sampled);
					finish = true;
			}
			if (finish) {
				outcomes.push({
					command: index,
					op: command.op,
					tick: ticks,
					value: value
				});
				index++;
				elapsed = 0;
				pressedAt = -1;
				setKeys([]);
				continue;
			}
			elapsed++;
			ticks++;
			return state;
		}
		return state;
	}

	// The pointer at framebuffer pixel x, y (resolve's), down or up.
	function pointer(x:Float, y:Float, down:Bool):Void
		state.pointerEvent(x, y, down);

	// Point p where it is now, written to out: in the pointer's framebuffer pixels when pixels is true, else the design's units (Screen's); a
	// widget's as locate finds it, a plain one as given. Without a runner, in a test, both are as given. False while a widget's isn't found.
	function resolve(p:Dynamic, out:Array<Float>, pixels:Bool):Bool {
		var screen = helix.host.Screen.instance;
		// Typed as numbers first: hxcpp's Dynamic arithmetic on a JSON integer and a fraction would keep only the integer.
		if (Std.isOfType(p, Array)) {
			var x:Float = p[0], y:Float = p[1];
			out[0] = pixels && screen != null ? screen.toPixelsX(x) : x;
			out[1] = pixels && screen != null ? screen.toPixelsY(y) : y;
			return true;
		}
		if (locate == null)
			throw 'Autopilot point at command ' + index + ' names a widget with nothing to find it with';
		var x:Float = p.at[0], y:Float = p.at[1];
		if (!locate(p.target, p.part != null ? p.part : "", x, y, out))
			return false;
		if (!pixels && screen != null) {
			out[0] = screen.toUnitsX(out[0]);
			out[1] = screen.toUnitsY(out[1]);
		}
		return true;
	}

	// Fails the script once command has waited its limit (its "timeout" in ticks or "seconds", 5 seconds when it gives neither) for widget
	// point p.
	function awaitPoint(command:Dynamic, p:Dynamic):Void {
		var seconds:Float = Reflect.hasField(command, "seconds") ? command.seconds : 5.;
		if (Reflect.hasField(command, "timeout") ? elapsed >= command.timeout : haxe.Timer.stamp() - waitStarted >= seconds)
			throw 'Autopilot timeout at command ' + index + ': no shown ' + describe(p);
	}

	// A widget point's widget and part, for a message.
	static function describe(p:Dynamic):String
		return p.part != null ? p.target + ' part ' + p.part : p.target;

	// A sample's colors kept under its name, with its points and tolerance; checked against the sample it must match or differ from.
	function record(command:Dynamic, colors:Array<Array<Int>>):Void {
		Reflect.setField(samples, command.name, {
			points: sampledPoints,
			colors: colors,
			tolerance: Reflect.hasField(command, "tolerance") ? command.tolerance : 3
		});
		if (Reflect.hasField(command, "matches")) {
			var same:Array<Array<Int>> = Reflect.field(samples, command.matches).colors;
			for (i in 0...colors.length) {
				var most = 0;
				for (c in 0...4)
					most = Std.int(Math.max(most, Math.abs(colors[i][c] - same[i][c])));
				if (most > command.within)
					throw 'Autopilot assertion failed at command ' + index + ': sample ' + command.name + ' point ' + i + ' differs from ' + command.matches
						+ ' by ' + most + ', over ' + command.within;
			}
		}
		if (!Reflect.hasField(command, "differsFrom"))
			return;
		var other:Array<Array<Int>> = Reflect.field(samples, command.differsFrom).colors;
		for (i in 0...colors.length) {
			var most = 0;
			for (c in 0...4)
				most = Std.int(Math.max(most, Math.abs(colors[i][c] - other[i][c])));
			if (most < command.by)
				throw 'Autopilot assertion failed at command ' + index + ': sample ' + command.name + ' point ' + i + ' differs from ' + command.differsFrom
					+ ' by ' + most + ', under ' + command.by;
		}
	}

	/** Progress as a record: completed, failed (failure), ticks, the current command index, the outcomes and the samples (by name: points, colors as
		[r, g, b, a] and tolerance). */
	public var snapshot(get, never):Dynamic;

	function get_snapshot():Dynamic
		return {
			completed: done,
			failed: failure,
			ticks: ticks,
			command: index,
			outcomes: outcomes,
			samples: samples
		};
}
