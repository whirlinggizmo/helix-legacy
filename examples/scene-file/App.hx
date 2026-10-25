import helix.behavior.Behavior;
import helix.behavior.BehaviorPass;
import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.IInput;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Stage;
import helix.render2d.Text2D;
import helix.render3d.Camera3D;
import helix.render3d.Node3D;
import helix.render3d.View3D;
import helix.scene.SceneFile3D;
import helix.scene.SceneFiles3D;
import helix.scene.SceneInstance3D;
import helix.time.Ticker;
import helix.time.Time;
import helix.host.ScreenShape;

/** A racer slice entirely from a scene file (helix.scene.SceneFile3D) and behaviors (helix.behavior): scenes/track.scene3d holds the place's
	light (its environment: the sky and the ambient light), the sun with its shadows, a closed loop of Kenney's Racing Kit pieces with
	barriers, a gantry and scenery (laid by tools/gen_loop.py), eight checkpoints, the race, the car (a prefab, scenes/car.scene3d, the kit's
	sports car) and the chase camera; nothing of the world is in code. The file is instantiated under a Node3D shown by a View3D on the
	stage, which holds the photography (ACES tone mapping, the exposure) and looks through the file's chase camera; the HUD is text on the
	stage over it. The behaviors (Car, ChaseCamera, Checkpoint, Race) drive it, run by a BehaviorPass of the app's own at a fixed 60 Hz
	through a Ticker. UP / DOWN or W / S drive and brake, LEFT / RIGHT or A / D steer, a pad's left stick and triggers too; R restarts the
	race (the instance destroyed and made again); the window losing focus pauses the game's clock (the app's pauseOnBlur), and the race with
	it; Escape quits where quitting means anything. The HUD shows the lap, its time and the best. Options: autopilot (a script under
	assets/), fast (1: up to 120 ticks a frame under autopilot) and autoclose (1: quit once the script is done); the probes are loaded,
	state, lap, checkpoint, passed, lapTime, bestLap, carX, carZ and speed. */
class App extends helix.App {
	/** The behaviors the scene file names: listed so the build keeps their classes, which register themselves with BehaviorRegistry as the
		program starts (a class nothing names is never compiled in). */
	static var BEHAVIORS:Array<Class<Behavior>> = [Car, ChaseCamera, Checkpoint, Race];

	var play:Play;
	var ticker:Ticker;

	override public function init():Void {
		Window.title = "HeliX scene-file";
		Window.requestSize(1200, 675);
		ticker = new Ticker();
		ticker.maxSteps = 6;
		play = new Play();
	}

	// A named value of the game for the autopilot, and the final game it publishes.
	override public function probe(name:String):Dynamic {
		var race = play == null ? null : play.race,
			car = play == null ? null : play.car;
		return switch name {
			// The instance's ready, and its ready lambda run (the pass's update after the flag), so the race and the car are found.
			case "loaded": play != null && play.instance != null && play.instance.ready && race != null;
			case "state": race == null ? "" : race.state;
			case "lap": race == null ? 0 : race.lap;
			case "checkpoint": race == null ? 0 : race.checkpoint;
			case "passed": race == null ? 0 : race.passed;
			case "lapTime": race == null ? 0 : hundredths(race.lapTime);
			case "bestLap": race == null ? 0 : hundredths(race.bestLap);
			case "carX": car == null ? 0 : hundredths(car.carX);
			case "carZ": car == null ? 0 : hundredths(car.carZ);
			case "speed": car == null ? 0 : hundredths(car.speed);
			default: throw 'Unknown probe ' + name;
		}
	}

	// A value to two decimals, the same on every target.
	static function hundredths(value:Float):Float
		return Math.round(value * 100) / 100;

	// One tick of the game from the program's input (the autopilot's while it plays): the level's keys and its behaviors at a sixtieth of a
	// second.
	function tick():Void {
		if (play != null)
			play.tick(1 / 60);
	}

	override public function update(dt:Float):Void {
		// Under an autopilot each update is one of its ticks (App.probe); otherwise the ticks the clock's time makes.
		if (autopilot != null && !autopilot.done)
			tick();
		else
			ticker.advance(Time.clock.elapsed, () -> tick());
		if (play != null)
			play.update(dt);
	}

	override public function cleanup():Void {
		if (play != null)
			play.destroy();
	}
}

/** The level: the track's file loaded through SceneFiles3D and instantiated under a Node3D with its own pass, shown on the stage by a View3D
	through the camera the file made (the Camera3D named chase); a HUD line over it, on the stage. R destroys the instance and makes it
	again. */
class Play {
	/** The track's file. */
	public static inline var TRACK = "scenes/track.scene3d";

	/** The file instantiated, or null until it has loaded. */
	public var instance(default, null):Null<SceneInstance3D>;

	/** The race's behavior, once the instance is ready; null before. */
	public var race(default, null):Null<Race>;

	/** The car's behavior, once the instance is ready; null before. */
	public var car(default, null):Null<Car>;

	var level = new Node3D();
	var view:View3D;
	var behaviors = new BehaviorPass();
	var file:Null<SceneFile3D>;
	var fallback = new Camera3D();
	var fps = new FpsOverlay();
	var line = new Text2D("Loading the track", 22, 0xfff5f5f5);
	var help = new Text2D("", 15, 0xffc8c8c8);

	/** The level on the stage, its file loading. */
	public function new() {
		Stage.color = 0xff7896c8;
		fallback.setView(0, 40, 60, 0, 0, 0);
		view = new View3D(level, fallback);
		// The photography: the view's, not the place's (the file holds the place's light).
		view.tonemap = Aces;
		view.exposure = .2;
		Stage.addChild(view);
		Stage.addChild(line);
		Stage.addChild(help);
		Stage.addChild(fps);
		SceneFiles3D.load(TRACK, loaded -> place(loaded), message -> line.text = message);
	}

	// The file in: instantiated under the level's root, with the level's pass.
	function place(loaded:SceneFile3D):Void {
		file = loaded;
		restart();
	}

	// The instance made from the file (the last one destroyed first): the race starts over from its countdown.
	function restart():Void {
		if (instance != null)
			instance.destroy();
		race = null;
		car = null;
		view.camera = fallback;
		instance = file.instantiate(level, behaviors, () -> ready());
	}

	// Everything has landed and the behaviors have started: the camera the view looks through, and the behaviors the HUD and the probes read.
	function ready():Void {
		var chase = Std.downcast(instance.node("chase"), Camera3D);
		if (chase != null)
			view.camera = chase;
		race = behaviors.find(Race);
		car = behaviors.find(Car);
	}

	/** A tick of dt seconds: the program's keys, then its behaviors. */
	public function tick(dt:Float):Void {
		if (Input.isFramePressed(Key.Escape) && Host.canQuit())
			Host.quit();
		if (Input.isFramePressed(Key.R) && file != null)
			restart();
		behaviors.update(dt);
	}

	/** The HUD for a frame of dt seconds, in the design for the window's shape. */
	public function update(dt:Float):Void {
		fps.update(dt, Time.frameCpu);
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		line.setPosition(vx + 12, vy + 36);
		help.setPosition(vx + 12, vy + 66);
		fps.setPosition(vx + vw - 150, vy + 10);
		if (race != null) {
			line.text = race.racing ? 'Lap ${race.lap}   ${seconds(race.lapTime)}   best ${race.bestLap > 0 ? seconds(race.bestLap) : "--"}' : 'Ready: ${Math.ceil(race.remaining)}';
			help.text = "UP / DOWN drive, LEFT / RIGHT steer, R restart" + (Host.canQuit() ? ", ESC quit" : "");
		}
	}

	// Seconds as m:ss.hh.
	static function seconds(value:Float):String {
		var whole = Math.floor(value),
			hundredths = Math.floor((value - whole) * 100);
		var minutes = Math.floor(whole / 60), rest = whole - minutes * 60;
		return '$minutes:${rest < 10 ? "0" : ""}$rest.${hundredths < 10 ? "0" : ""}$hundredths';
	}

	/** Its instance and its view destroyed. */
	public function destroy():Void {
		if (instance != null)
			instance.destroy();
		instance = null;
		view.destroy();
	}
}
