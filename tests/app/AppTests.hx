import helix.AppOptions;
import helix.hotreload.AppRouter;
import helix.macro.AppBuild;

/** A game as a user writes one: helix.App's build (helix.macro.AppBuild) writes its hot statics into it. Never constructed here, since
	the constructor would start the backend's profile; made empty instead. */
@:access(helix)
class Game extends helix.App {
	public var inits = 0;
	public var updates = 0;
	public var cleanups = 0;
	public var lastDt = 0.;

	override public function init():Void
		inits++;

	override public function update(dt:Float):Void {
		updates++;
		lastDt = dt;
	}

	override public function cleanup():Void
		cleanups++;

	public var befores = 0;
	public var afters = 0;

	override public function beforeReload():Void
		befores++;

	override public function afterReload():Void
		afters++;
}

/** helix.App built with a backend named (-D helix-backend=webgl2, run on Node by tests/tools/app_test.py, which also checks the builds
	that must be refused): the hot statics the build writes reach the app in hotApp, and another app once hotApp is re-pointed, as a native reload does;
	the backend table; AppOptions' defaults; a AppRouter's three calls. */
@:access(helix.App)
@:access(helix)
class AppTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	// A Game without its constructor (which would start the profile), its counters at 0 (createEmptyInstance runs no initializer on JS).
	static function empty():Game {
		var game:Game = Type.createEmptyInstance(Game);
		game.inits = game.updates = game.cleanups = game.befores = game.afters = 0;
		game.running = false;
		game.lastDt = 0;
		return game;
	}

	static function main():Void {
		// The hot statics: hotApp held as the AppRouter is made, each call reaching the app's callbacks through App's run methods.
		var game = empty();
		game.options = new AppOptions();
		game.options.devKeys = false;
		game.options.pageState = false;
		check(Game.hotApp == null, "No app yet");
		var router = game.hotAppRouter();
		check(Game.hotApp == game, "Making the router holds the app in the class's hot static");
		router.init();
		check(game.inits == 1, "init reaches the app");
		router.update(.5);
		check(game.updates == 1 && game.lastDt == .5, "update reaches the app with its dt");
		router.cleanup();
		check(game.cleanups == 1, "cleanup reaches the app");
		// A native reload migrates the object held in hotApp and re-points the statics: the same router reaches the new object.
		var migrated = empty();
		migrated.options = game.options;
		// It was running when the reload carried it over.
		migrated.running = true;
		@:privateAccess Game.hotApp = migrated;
		router.update(.25);
		check(game.updates == 1 && migrated.updates == 1 && migrated.lastDt == .25, "The router reaches the app hotApp holds now");
		Game.hotInit();
		Game.hotUpdate(1);
		Game.hotCleanup();
		check(migrated.inits == 1 && migrated.updates == 2 && migrated.cleanups == 1, "The statics the Runner's lambdas call by name");
		var statics = Type.getClassFields(Game);
		for (name in AppBuild.WRITTEN.slice(0, 4))
			check(statics.contains(name), 'The build wrote $name');

		// The reload hooks (what the build's hotBeforeReload and hotAfterReload call in a hot build): only between init and cleanup.
		var hooked = empty();
		hooked.options = game.options;
		hooked.runBeforeReload();
		hooked.runAfterReload();
		check(hooked.befores == 0 && hooked.afters == 0, "No reload hook before init");
		hooked.runInit();
		hooked.runBeforeReload();
		hooked.runAfterReload();
		check(hooked.befores == 1 && hooked.afters == 1, "Both hooks after init");
		hooked.runCleanup();
		hooked.runAfterReload();
		check(hooked.afters == 1, "No reload hook after cleanup");

		// The backend table.
		check(AppBuild.BACKENDS.join(",") == "webgl2,sokol-gl,sdl3-gl,sdl3-gpu", "The four backends, the browser's first");
		check(AppBuild.profileOf("webgl2") == "helix.profile.WebGL2Profile"
			&& AppBuild.profileOf("sokol-gl") == "helix.profile.SokolGLProfile"
			&& AppBuild.profileOf("sdl3-gl") == "helix.profile.Sdl3GLProfile"
			&& AppBuild.profileOf("sdl3-gpu") == "helix.profile.Sdl3GpuProfile",
			"Each backend's profile");
		check(AppBuild.profileOf("gl") == null && AppBuild.profileOf("") == null, "A name not in the list has no profile");
		check(AppBuild.isBrowser("webgl2") && !AppBuild.isBrowser("sokol-gl") && !AppBuild.isBrowser("sdl3-gpu"), "Only webgl2 is the browser's");

		// The options' defaults.
		var options = new AppOptions();
		check(options.product == "Game" && options.company == "DefaultCompany", "A default identity");
		check(options.assets == null && options.manifest == null, "The assets beside the program, no manifest");
		check(options.window.msaaSamples == 4, "The window's defaults");
		var debug = #if debug true #else false #end;
		check(options.devKeys == debug && options.pageState == debug, "The development extras follow the build");

		// A AppRouter calls what it was given, in order.
		var calls = [];
		var made = new AppRouter(() -> calls.push("init"), dt -> calls.push('update $dt'), () -> calls.push("cleanup"));
		made.init();
		made.update(2);
		made.cleanup();
		check(calls.join(",") == "init,update 2,cleanup", "A AppRouter's three calls");

		var report = haxe.Json.stringify({passed: true, checks: checks});
		#if js
		js.Syntax.code("console.log({0})", report);
		#else
		Sys.println(report);
		#end
	}
}
