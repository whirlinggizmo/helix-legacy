package helix.adapter.host.dom;

import helix.host.IWindow;
import js.Browser;
import js.html.CanvasElement;

/** The page is the window: its title is the document's, its size the viewport's, and fullscreen is the canvas's. A page can't move or size its window,
	or choose a monitor; it sees one screen. */
@:noCompletion
class DomWindow implements IWindow {
	var canvas:CanvasElement;

	/** The page's window, with canvas as what goes fullscreen or hides, and as the drawing surface: its pixels follow the viewport's size and
		the pixel ratio. */
	public function new(canvas:CanvasElement) {
		this.canvas = canvas;
		resize();
		Browser.window.addEventListener("resize", _ -> resize());
		Browser.window.addEventListener("blur", _ -> focused = false);
		Browser.window.addEventListener("focus", _ -> focused = !Browser.document.hidden);
		Browser.document.addEventListener("visibilitychange", _ -> focused = !Browser.document.hidden);
	}

	function resize():Void {
		canvas.width = Std.int(Math.max(1, Browser.window.innerWidth * this.pixelRatio));
		canvas.height = Std.int(Math.max(1, Browser.window.innerHeight * this.pixelRatio));
	}

	public var framebufferWidth(get, never):Int;

	function get_framebufferWidth():Int
		return canvas.width;

	public var framebufferHeight(get, never):Int;

	function get_framebufferHeight():Int
		return canvas.height;

	public var pixelRatio(get, never):Float;

	function get_pixelRatio():Float
		return Browser.window.devicePixelRatio;

	@:isVar public var focused(get, null):Bool = true;

	function get_focused():Bool
		return focused;

	public var title(get, set):String;

	function get_title():String
		return Browser.document.title;

	function set_title(title:String):String {
		Browser.document.title = title;
		return title;
	}

	public var width(get, never):Int;

	function get_width():Int
		return Browser.window.innerWidth;

	public var height(get, never):Int;

	function get_height():Int
		return Browser.window.innerHeight;

	public function requestSize(width:Int, height:Int):Bool
		return false;

	public function canMove():Bool
		return false;

	public var x(get, never):Int;

	function get_x():Int
		return Browser.window.screenX;

	public var y(get, never):Int;

	function get_y():Int
		return Browser.window.screenY;

	public function requestPosition(x:Int, y:Int):Bool
		return false;

	public function requestOrientation(orientation:helix.host.Orientation, ?done:Void->Void, ?failed:String->Void):Bool {
		var lock:Dynamic = js.Syntax.code("(screen.orientation && screen.orientation.lock) ? screen.orientation : null");
		if (lock == null)
			return false;
		var refused = (error:Dynamic) -> {
			var reason = error != null && error.message != null ? Std.string(error.message) : Std.string(error);
			if (failed != null)
				failed(reason);
			else
				trace('Orientation refused: $reason');
			return null;
		};
		if (orientation == Any) {
			try
				lock.unlock()
			catch (_:Dynamic) {}
			if (done != null)
				done();
			return true;
		}
		var asked:Dynamic = try lock.lock(orientation == Landscape ? "landscape" : "portrait") catch (e:Dynamic) {
			refused(e);
			return true;
		};
		asked.then(_ -> {
			if (done != null)
				done();
			return null;
		}, refused);
		return true;
	}

	public function canFullscreen():Bool
		return Browser.document.fullscreenEnabled;

	public var fullscreen(get, never):Bool;

	function get_fullscreen():Bool
		return Browser.document.fullscreenElement != null;

	public function requestFullscreen(enabled:Bool, ?done:Void->Void, ?failed:String->Void):Bool {
		if (!canFullscreen())
			return false;
		// The browser may refuse (no recent key press or click): the page stays as it was, and failed says why.
		var refused = (error:Dynamic) -> {
			var reason = error != null && error.message != null ? Std.string(error.message) : Std.string(error);
			if (failed != null)
				failed(reason);
			else
				trace('Fullscreen refused: $reason');
			return null;
		};
		var granted = (_:Dynamic) -> {
			if (done != null)
				done();
			return null;
		};
		var ask = () -> {
			// The browser's promise of the change, granted or refused.
			var asked:Dynamic = enabled
				&& !this.fullscreen ? canvas.requestFullscreen() : !enabled && this.fullscreen ? Browser.document.exitFullscreen() : null;
			if (asked != null)
				asked.then(granted, refused);
			else
				granted(null);
		};
		// Going fullscreen wants a fresh press, and a phone's tap counts only as its finger lifts: asked from a frame (a game's update) as
		// the finger lands, it would be refused. With no fresh press now, it's asked inside the player's next lift, click or key.
		var activation:Dynamic = js.Syntax.code("navigator.userActivation");
		if (enabled && activation != null && !activation.isActive)
			askAtNextPress(ask);
		else
			ask();
		return true;
	}

	// What's waiting to be asked at the next press (askAtNextPress), and the listener that asks it.
	var waitingAsk:Null<Void->Void>;
	var pressListener:Null<Dynamic->Void>;

	// Asks once, inside the next lift, click or key: the events a browser counts as a press. A later ask replaces one still waiting.
	function askAtNextPress(ask:Void->Void):Void {
		waitingAsk = ask;
		if (pressListener != null)
			return;
		var window:Dynamic = Browser.window;
		pressListener = _ -> {
			for (name in ["pointerup", "touchend", "click", "keydown"])
				window.removeEventListener(name, pressListener, true);
			pressListener = null;
			var then = waitingAsk;
			waitingAsk = null;
			if (then != null)
				then();
		};
		for (name in ["pointerup", "touchend", "click", "keydown"])
			window.addEventListener(name, pressListener, true);
	}

	public var visible(get, never):Bool;

	function get_visible():Bool
		return canvas.style.visibility != "hidden";

	public function requestVisible(visible:Bool):Bool {
		canvas.style.visibility = visible ? "" : "hidden";
		return true;
	}

	public var monitorCount(get, never):Int;

	function get_monitorCount():Int
		return 1;

	public var monitorIndex(get, never):Int;

	function get_monitorIndex():Int
		return 0;

	public function requestMonitorIndex(index:Int):Bool
		return false;

	public function getMonitorName(index:Int):String
		return index == 0 ? "screen" : "";

	public function getMonitorX(index:Int):Int
		return 0;

	public function getMonitorY(index:Int):Int
		return 0;

	public function getMonitorWidth(index:Int):Int
		return index == 0 ? Browser.window.screen.width : 0;

	public function getMonitorHeight(index:Int):Int
		return index == 0 ? Browser.window.screen.height : 0;
}
