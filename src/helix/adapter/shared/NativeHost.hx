package helix.adapter.shared;

import helix.host.IHost;
import helix.host.IWindow;

/** What either native host (sokol_app's or SDL's) does the same: the frame loop's callbacks, haxe.Timer's clock, the window
	(NativeWindow) and options from HELIX_* environment variables. A host adapter opens its window and runs its loop (start) and quits. */
@:noCompletion
abstract class NativeHost implements IHost {
	static var init:Void->Void;
	static var frame:Void->Void;
	static var cleanup:Void->Void;

	var nativeWindow = new NativeWindow();
	var msaaSamples:Int;

	/** The program's host; its window opens when run starts, asking for msaaSamples multisampling samples a pixel (1: none). */
	function new(msaaSamples:Int) {
		this.msaaSamples = msaaSamples;
	}

	public function run(init:Void->Void, frame:Void->Void, cleanup:Void->Void):Void {
		NativeHost.init = init;
		NativeHost.frame = frame;
		NativeHost.cleanup = cleanup;
		start(cpp.Callable.fromStaticFunction(onInit), cpp.Callable.fromStaticFunction(onFrame), cpp.Callable.fromStaticFunction(onCleanup), msaaSamples);
	}

	/** Opens the window with msaaSamples samples a pixel and runs the loop: init once, frame each frame, cleanup as it ends; returns then. */
	abstract function start(init:cpp.Callable<Void->Void>, frame:cpp.Callable<Void->Void>, cleanup:cpp.Callable<Void->Void>, msaaSamples:Int):Void;

	static function onInit():Void
		init();

	static function onFrame():Void
		frame();

	static function onCleanup():Void
		cleanup();

	public var time(get, never):Float;

	function get_time():Float
		return haxe.Timer.stamp();

	public var window(get, never):IWindow;

	function get_window():IWindow
		return nativeWindow;

	public function canQuit():Bool
		return true;

	public var device(get, never):helix.host.Device;

	// The system's name (Sys.systemName: Windows, Linux, Mac, BSD), lowercase as Device names it; a mouse assumed, no touch screen reported.
	function get_device():helix.host.Device {
		var os = switch Sys.systemName() {
			case "Windows": "windows";
			case "Mac": "macos";
			case "Linux": "linux";
			case _: "";
		};
		return new helix.host.Device(false, os, false, true);
	}

	public function getOption(name:String):Null<String>
		return Sys.getEnv("HELIX_" + name.toUpperCase());

	public function reportBusy(busy:Bool):Void {}

	/** config.json beside the executable, read whole when it's there. */
	public function loadConfig(done:Null<haxe.io.Bytes>->Void):Void {
		var path = haxe.io.Path.join([haxe.io.Path.directory(Sys.programPath()), "config.json"]);
		done(sys.FileSystem.exists(path) ? sys.io.File.getBytes(path) : null);
	}
}
