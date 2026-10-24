package helix.macro;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

/** The build macro behind helix.App, run on every class extending it (`@:autoBuild`). It writes into the subclass what a native hot
	reload needs and what the build's backend decides, so a game writes neither:

	- `@:hot public static var hotApp`, the app object `new` made, and `@:hot static function hotInit()`, `hotUpdate(dt)` and
	  `hotCleanup()`, each calling the app in `hotApp`: hotreload-hx's hot statics. The Runner, compiled once into the executable, reaches
	  the game only through them (a AppRouter of lambdas calling them by name), so a native reload re-points the calls at the new module
	  and migrates `hotApp` with the other `@:hot` statics; in the browser they cost nothing. They're written here, in the game's own class,
	  because a `@:hot` static in the library's App would make the library reloaded code, and because hotreload-hx's global build, which
	  turns `@:hot` into what a reload needs, runs after a parent's `@:autoBuild` and before a class's own `@:build` (checked with Haxe
	  4.3.7), so fields this macro adds are seen as written.
	- In a hot build (`-D hotreload`), `@:beforeHotReload static function hotBeforeReload()` and `@:afterHotReload static function
	  hotAfterReload()`, hotreload-hx's hooks, calling the app's beforeReload and afterReload, so a game overrides those methods rather than
	  writing static hooks that find its object.
	- `hotAppRouter()`, giving App the AppRouter over those statics, and `hotStart(identity, router)`, running the profile of the
	  backend the build names with `-D helix-backend=` (BACKENDS); a build naming none, or one not in the list, fails here, naming the
	  choices, and an `sdl3-gpu` build without `helix_sdl3_gpu` (the define the programs carry SDL_GPU's dialects under; `-lib helix`
	  defines it from the backend, helix.macro.Haxelib, and the repository's builds pass it) too.

	A subclass can't declare a field of those names. */
@:noCompletion
class AppBuild {
	/** The backends a build may name with -D helix-backend=, each the name of a build's backend (docs/CONVENTIONS.md): the browser's
		webgl2, and natively sokol-gl, sdl3-gl and sdl3-gpu. */
	public static final BACKENDS = ["webgl2", "sokol-gl", "sdl3-gl", "sdl3-gpu"];

	/** The profile class (helix.profile) that runs backend, or null for a name not in BACKENDS. */
	public static function profileOf(backend:String):Null<String> {
		return switch backend {
			case "webgl2": "helix.profile.WebGL2Profile";
			case "sokol-gl": "helix.profile.SokolGLProfile";
			case "sdl3-gl": "helix.profile.Sdl3GLProfile";
			case "sdl3-gpu": "helix.profile.Sdl3GpuProfile";
			default: null;
		}
	}

	/** Whether backend draws in a browser (its profile takes an asset URL and a manifest) rather than natively (an asset directory). */
	public static function isBrowser(backend:String):Bool
		return backend == "webgl2";

	/** The fields the macro writes, which a subclass can't declare itself. */
	public static final WRITTEN = [
		"hotApp",
		"hotInit",
		"hotUpdate",
		"hotCleanup",
		"hotBeforeReload",
		"hotAfterReload",
		"hotAppRouter",
		"hotStart"
	];

	#if macro
	/** The subclass's fields with the hot statics and the backend's start added (the class doc above). */
	public static function build():Array<Field> {
		var cls = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		var pos = Context.currentPos();
		var choices = "-D helix-backend=" + BACKENDS.slice(0, BACKENDS.length - 1).join(", ") + " or " + BACKENDS[BACKENDS.length - 1];
		var backend = Context.definedValue("helix-backend");
		if (backend == null)
			Context.error('helix.App: the build names its backend: $choices', pos);
		var profile = profileOf(backend);
		if (profile == null)
			Context.error('helix.App: "$backend" is not a backend: $choices', pos);
		if (backend == "sdl3-gpu" && !Context.defined("helix_sdl3_gpu"))
			Context.error("helix.App: an sdl3-gpu build also defines helix_sdl3_gpu, so the programs carry SDL_GPU's dialects (-lib helix defines it from the backend)",
				pos);
		for (field in fields)
			if (WRITTEN.contains(field.name))
				Context.error('helix.App: ${field.name} is written by helix.macro.AppBuild into every App subclass; rename this one', field.pos);
		// The class's own type path: through its module where the module is named otherwise (class Game in Main.hx).
		var module = Context.getLocalModule().split(".");
		var moduleName = module[module.length - 1];
		var self:ComplexType = TPath(moduleName == cls.name ? {pack: cls.pack, name: cls.name} : {pack: cls.pack, name: moduleName, sub: cls.name});
		var run = profile.split(".");
		run.push("run");
		var start = isBrowser(backend) ? macro $p{run}(identity, options.assets != null ? options.assets : "assets/", options.manifest, router,
			options.window) : macro $p{run}(identity, options.assets != null ? options.assets : "assets", router, options.window);
		var made = (macro class {
			/** The app `new` made, the one the hot statics call: kept across a hot reload (@:hot) and migrated to the new code with it.
				Written by helix.macro.AppBuild. */
			@:hot public static var hotApp:$self;

			/** The Runner's way to the app's init, by name, so a native reload re-points it (@:hot). Written by helix.macro.AppBuild. */
			@:hot static function hotInit():Void
				hotApp.runInit();

			/** The Runner's way to the app's update, by name, so a native reload re-points it (@:hot). Written by helix.macro.AppBuild. */
			@:hot static function hotUpdate(dt:Float):Void
				hotApp.runUpdate(dt);

			/** The Runner's way to the app's cleanup, by name, so a native reload re-points it (@:hot). Written by helix.macro.AppBuild. */
			@:hot static function hotCleanup():Void
				hotApp.runCleanup();

			override function hotAppRouter():helix.hotreload.AppRouter {
				hotApp = this;
				return new helix.hotreload.AppRouter(() -> hotInit(), dt -> hotUpdate(dt), () -> hotCleanup());
			}

			override function hotStart(identity:helix.host.Identity, router:helix.hotreload.AppRouter):Void
				$start;
		}).fields;
		if (Context.defined("hotreload"))
			made = made.concat((macro class {
				/** hotreload-hx's hook before a reload: the app's beforeReload. Written by helix.macro.AppBuild. */
				@:beforeHotReload static function hotBeforeReload():Void
					if (hotApp != null)
						hotApp.runBeforeReload();

				/** hotreload-hx's hook after a reload: the app's afterReload. Written by helix.macro.AppBuild. */
				@:afterHotReload static function hotAfterReload():Void
					if (hotApp != null)
						hotApp.runAfterReload();
			}).fields);
		for (field in made)
			field.pos = pos;
		return fields.concat(made);
	}
	#end
}
