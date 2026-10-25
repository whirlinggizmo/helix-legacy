package helix.host;

/** The host: what runs the program on a platform (a browser page's frame callbacks, a native process's app loop). It owns the loop, the
	clock, quitting, the window and where run options come from, and nothing else: the Runner it pumps builds and runs everything the app
	sees (the static classes it binds: Window, Input, Graphics and the others). */
@:noCompletion
interface IHost {
	/** Runs the program: init once, when the window and the GPU exist; frame once a display refresh; cleanup once, when it closes (the window
		closed, quit, or a browser page going away). Natively it returns only after the window closes. */
	public function run(init:Void->Void, frame:Void->Void, cleanup:Void->Void):Void;

	/** Seconds on a monotonic clock. */
	var time(get, never):Float;

	/** The window the program draws in (the page, on the web). */
	var window(get, never):IWindow;

	/** What the program runs on, as far as the platform says (Device). */
	var device(get, never):Device;

	/** Whether quitting closes anything, so whether an app should offer a quit key: not in a browser page, where quit stops the program but
		the page stays. */
	public function canQuit():Bool;

	/** Closes after the current frame: cleanup runs. Natively the window closes; in a browser page the frames stop and the canvas keeps its
		last one. */
	public function quit():Void;

	/** A run option as the platform passes it, or null when it isn't given: in a browser the URL query parameter name, natively the
		environment variable HELIX_ and name in capitals. */
	public function getOption(name:String):Null<String>;

	/** Reads the game's config.json, the one beside the program (beside the page on the web, where the page says it has one; beside the
		executable natively), and gives done its bytes, or null when there is none: none is no error, the defaults stand. Fetched fresh each
		start, outside the asset cache, so a deployed game's settings change without a build (DECISIONS 131). */
	public function loadConfig(done:Null<haxe.io.Bytes>->Void):Void;

	/** Tells the platform whether the program's services are still loading (Host.busy), for the tools driving it: an App says so after
		each frame, and false at its cleanup, when its pageState option is on. A browser page says it on its window (window.helixBusy), so a
		tool captures the page once it has settled (tools/pages_shots.cjs); natively nothing listens, and nothing is done. */
	public function reportBusy(busy:Bool):Void;
}
