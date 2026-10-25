package helix.adapter.host.dom;

import helix.host.IHost;
import helix.host.IWindow;
import js.Browser;
import js.html.CanvasElement;

/** The browser host: the page's canvas (id "canvas") and its window, a requestAnimationFrame loop, the page's clock, and options from the URL
	query. An error the page doesn't catch, or a lost graphics context, stops the frames and says so in the element with id "status". */
@:noCompletion
class DomHostAdapter implements IHost {
	var stopped = false;
	var quitting = false;
	var closed = false;
	var params = new js.html.URLSearchParams(Browser.window.location.search);

	/** The page's host. */
	public function new() {
		canvas = cast Browser.document.getElementById("canvas");
		window = new DomWindow(canvas);
		Browser.window.addEventListener("unhandledrejection", e -> failure((cast e : Dynamic).reason));
		Browser.window.addEventListener("error", e -> failure((cast e : Dynamic).error));
		canvas.addEventListener("webglcontextlost", e -> {
			e.preventDefault();
			stopped = true;
			unavailable("Graphics context lost");
			Browser.document.getElementById("status").textContent = "Graphics context lost. Reload to recover.";
		});
	}

	/** The canvas the program draws in, for the graphics and input adapters. */
	@:isVar public var canvas(get, null):CanvasElement;

	function get_canvas():CanvasElement
		return canvas;

	/** Says on the page's window (graphicsUnavailable) that the platform can't draw, and why, for tools driving the page (tools/autopilot.cjs
		falls back to software rendering), apart from the program's own failures. */
	function unavailable(reason:String):Void
		Reflect.setField(Browser.window, "graphicsUnavailable", reason);

	function failure(error:Dynamic):Void {
		stopped = true;
		if (Std.isOfType(error, helix.graphics.GraphicsUnavailable))
			unavailable((error : helix.graphics.GraphicsUnavailable).message);
		var message = Std.string(error);
		Browser.document.getElementById("status").textContent = message;
		Browser.console.error(message);
	}

	public function run(init:Void->Void, frame:Void->Void, cleanup:Void->Void):Void {
		// Closes once: the page going away, or a quit, which takes effect after its frame as natively.
		function close():Void {
			stopped = true;
			if (!closed) {
				closed = true;
				cleanup();
			}
		}
		init();
		var loop:Float->Void = null;
		loop = _ -> {
			if (stopped)
				return;
			frame();
			if (quitting)
				close();
			else if (!stopped)
				Browser.window.requestAnimationFrame(loop);
		};
		Browser.window.requestAnimationFrame(loop);
		Browser.window.addEventListener("pagehide", _ -> close());
	}

	public var time(get, never):Float;

	function get_time():Float
		return Browser.window.performance.now() / 1000;

	@:isVar public var window(get, null):IWindow;

	function get_window():IWindow
		return window;

	public function canQuit():Bool
		return false;

	public var device(get, never):helix.host.Device;

	// The browser's word for it: the system from its user agent, a touch screen from its touch points, a fine pointer from any-pointer.
	function get_device():helix.host.Device {
		var touches:Int = js.Syntax.code("navigator.maxTouchPoints || 0");
		var fine:Bool = js.Syntax.code("window.matchMedia ? window.matchMedia('(any-pointer: fine)').matches : true");
		return new helix.host.Device(true, systemOf(Browser.navigator.userAgent, touches), touches > 0, fine);
	}

	/** The operating system a browser's user agent names, as Device names it ("" for none it knows); an iPad saying it's a Mac is told
		by its touch points. */
	@:noCompletion
	public static function systemOf(agent:String, touchPoints:Int):String {
		if (agent.indexOf("Android") >= 0)
			return "android";
		if (~/iPhone|iPad|iPod/.match(agent) || agent.indexOf("Macintosh") >= 0 && touchPoints > 1)
			return "ios";
		if (agent.indexOf("CrOS") >= 0)
			return "chromeos";
		if (agent.indexOf("Windows") >= 0)
			return "windows";
		if (agent.indexOf("Mac OS X") >= 0)
			return "macos";
		if (agent.indexOf("Linux") >= 0)
			return "linux";
		return "";
	}

	public function quit():Void
		quitting = true;

	public function getOption(name:String):Null<String>
		return params.get(name);

	public function reportBusy(busy:Bool):Void
		Reflect.setField(Browser.window, "helixBusy", busy);

	/** The page says whether it has one: a <meta name="helix-config" content="config.json"> the build writes beside it when the example (or
		game) ships one, so a page without one makes no request (a 404 would be a console error, which an autopilot counts as a failure).
		Fetched past the HTTP cache ("no-cache": revalidated), so an edited file is read on the next load. */
	public function loadConfig(done:Null<haxe.io.Bytes>->Void):Void {
		var meta:Null<js.html.MetaElement> = cast Browser.document.querySelector('meta[name="helix-config"]');
		if (meta == null || meta.content == "") {
			done(null);
			return;
		}
		Browser.window.fetch(meta.content, {cache: NO_CACHE}).then(response -> {
			if (!response.ok) {
				done(null);
				return;
			}
			response.arrayBuffer().then(buffer -> done(haxe.io.Bytes.ofData(buffer)), _ -> done(null));
		}, _ -> done(null));
	}
}
