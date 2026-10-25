package helix;

import helix.debug.Log;
import helix.AppOptions;
import helix.hotreload.AppRouter;
import helix.graphics.Screenshots;
import helix.host.Host;
import helix.host.Identity;
import helix.input.Input;
import helix.input.Key;

/** HeliX's entry point. A game is a class extending it, overriding init, update and cleanup, and its Main is
	`new Game()`: the constructor starts HeliX, picking the profile by the backend the build names (`-D helix-backend=webgl2`,
	`sokol-gl`, `sdl3-gl` or `sdl3-gpu`; a build naming none fails, naming the choices), so one Main serves every target: `class Game
	extends helix.App { override public function init():Void {...} override public function update(dt:Float):Void {...} }` (init once,
	the services bound: Window, Input, Graphics and the others; update once a display refresh, the game's logic), and
	`class Main { static function main() new Game(); }`. The drawing is the runner's: after update it draws the Stage (helix.render2d.Stage),
	what the game put on it (docs/DISPLAY_MODEL.md).

	The object exists before HeliX does: a field initializer runs before the services are bound, so what needs them (a Batch2D, a
	texture) is made in init. Natively the constructor returns only when the window closes. Options (AppOptions: the identity, where the
	assets are, a manifest, the window, the development extras) are given to the constructor, `super(options)` or `new Game(options)`.

	Hot reload (the dev loop, in the browser): the app is the object that's kept. After a reload it's the same object with its fields as
	they were, running the new code, so keep the game's state in the app's fields (or objects they hold), not in plain statics, which start
	over at each reload. Override afterReload to build what an edit added to init, and beforeReload to let go of what it will build again.
	The Runner reaches the app only through `@:hot` static functions that helix.macro.AppBuild writes into the game's class (`hotApp`, the
	object, and the calls to it), as hotreload-hx needs for a native reload; HeliX doesn't run native reloads yet. The game class is
	therefore not Main, which hotreload-hx never reloads and refuses `@:hot` in. */
@:autoBuild(helix.macro.AppBuild.build())
class App {
	/** The options it started with. */
	public var options(default, null):AppOptions;

	/** Starts HeliX with this app, with options (the defaults when not given): the profile of the build's backend runs, binds the
		services, calls init once the game's config.json (if any) has come, then update once a display refresh, and cleanup when the
		window closes (the page goes away). Throws for an identity (product, company) that isn't a file name. Natively returns when the
		window has closed. */
	public function new(?options:AppOptions) {
		this.options = options == null ? new AppOptions() : options;
		hotStart(new Identity(this.options.product, this.options.company), hotAppRouter());
	}

	/** Once, before the first frame, with the app's services bound (Window, Input, Graphics and the others). Nothing by default. */
	public function init():Void {}

	/** Once a display refresh, before the frame is drawn: the game's logic. dt is the measured seconds since the last frame, held between
		1e-6 and 0.1, and 1/60 on the first: for animation. A fixed-rate simulation takes Time.frameElapsed instead (helix.host.FrameClock).
		Nothing by default. */
	public function update(dt:Float):Void {}

	/** Once, when the window closes (on the web, at the page's pagehide). Nothing by default. */
	public function cleanup():Void {}

	/** Just before a hot reload swaps in the new code, still running the old: let go of what afterReload will build again. Only between
		init and cleanup. Nothing by default. */
	public function beforeReload():Void {}

	/** Just after a hot reload: this is the same object, its fields kept, now running the new code. Build here what an edit added to init
		(init doesn't run again), or rebuild what it changed. Only between init and cleanup. Nothing by default. */
	public function afterReload():Void {}

	/** A named value of the game for an autopilot script (helix.debug.Autopilot) to wait on and assert, and to publish as the game's final
		state, which tools/example.py and tools/autopilot.cjs compare between the browser and natively. Overriding it makes the game
		scriptable: run with the option autopilot naming a script under assets/ (?autopilot=autopilot/run.json in the page's URL,
		HELIX_AUTOPILOT natively), HeliX loads it before init, so every run starts alike, then plays it as the input a tick of 1/60 s at a
		time, each tick an update(1 / 60) (up to 120 a frame with fast=1, a press ending the frame's ticks), and once it's done publishes the
		probes it names, and quits with autoclose=1. Throw for a name it doesn't know: the script fails, naming it. */
	public function probe(name:String):Dynamic
		return null;

	/** Presses the widget named name for a script's click (Ui.press, say): false while there's none to press, which the script waits for.
		False to start. */
	public function pressWidget(name:String):Bool
		return false;

	/** The framebuffer pixel at x, y fractions of the widget named target, or of its part named part, into out, for a script's point naming
		a widget (Ui.computePoint, say): false while there's none, which the script waits for. False to start. */
	public function locateWidget(target:String, part:String, x:Float, y:Float, out:Array<Float>):Bool
		return false;

	/** The autopilot script playing (its seed for the game's random numbers), from init on, or null without one (probe). */
	public var autopilot(default, null):Null<helix.debug.Autopilot>;

	// What the subclass's hot statics call: the development extras (AppOptions) around the app's own callbacks. Final, so init, update,
	// cleanup and the reload hooks are the only overrides.
	final function runInit():Void {
		attachAutopilot();
		if (autopilotStart != null)
			autopilotStart(() -> runStart());
		else
			runStart();
	}

	final function runStart():Void {
		running = true;
		init();
	}

	// Between init and cleanup: when update and the reload hooks run.
	var running = false;

	// Set by the autopilot's driver (helix.debug.AutopilotDriver, attached by helix.macro.AppBuild to a game with probes) when a script is
	// asked for: it starts it, calling go once it's in, and plays each frame's updates, true when it did.
	var autopilotStart:Null<(go:Void->Void)->Void>;
	var autopilotFrame:Null<Float->Bool>;

	// Written by helix.macro.AppBuild into a subclass with probes: attaches the driver.
	function attachAutopilot():Void {}

	final function runBeforeReload():Void
		if (running)
			beforeReload();

	final function runAfterReload():Void
		if (running)
			afterReload();

	final function runUpdate(dt:Float):Void {
		// The autopilot's script still loading: the game not started.
		if (!running)
			return;
		if (options.devKeys && Input.isFramePressed(Key.F9))
			Screenshots.take(null, result -> switch result {
				case Saved(where, _): Log.info('Screenshot saved: $where', "screenshot");
				case Failed(message): Log.warn('Screenshot failed: $message', "screenshot");
			});
		if (autopilotFrame == null || !autopilotFrame(dt))
			update(dt);
		if (options.pauseOnBlur)
			followFocus();
		if (options.pageState)
			Host.instance.reportBusy(Host.busy);
	}

	// The game's clock paused while the window is out of focus, and only if this paused it, going on when the focus is back (pauseOnBlur).
	var blurred = false;
	var pausedClock = false;

	function followFocus():Void {
		var window = helix.host.Window.instance, clock = helix.time.Time.clock;
		if (window == null || clock == null)
			return;
		var focused = helix.host.Window.focused;
		if (!focused && !blurred) {
			blurred = true;
			if (!clock.paused) {
				clock.pause();
				pausedClock = true;
			}
		} else if (focused && blurred) {
			blurred = false;
			if (pausedClock && clock.paused)
				clock.resume();
			pausedClock = false;
		}
	}

	// After a quit nothing loads (the shutdown cancelled it all), and no frame comes to say so.
	final function runCleanup():Void {
		running = false;
		cleanup();
		if (options.pageState)
			Host.instance.reportBusy(false);
	}

	// Written by helix.macro.AppBuild into every subclass: the AppRouter over the class's @:hot statics, hotApp set to this ...
	function hotAppRouter():AppRouter
		throw "helix.App: hotAppRouter is written by helix.macro.AppBuild into each subclass";

	// ... and the start on the profile of the backend the build names.
	function hotStart(identity:Identity, router:AppRouter):Void
		throw "helix.App: hotStart is written by helix.macro.AppBuild into each subclass";
}
