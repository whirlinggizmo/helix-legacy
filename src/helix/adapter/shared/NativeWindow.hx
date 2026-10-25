package helix.adapter.shared;

import helix.host.IWindow;

/** The desktop window of either native host (sokol_app's or SDL's), through the C each implements (window.h). Moves are refused where the
	compositor places windows (Wayland, XWayland). */
@:noCompletion
class NativeWindow implements IWindow {
	/** The program's one native window. */
	public function new() {}

	public var framebufferWidth(get, never):Int;

	function get_framebufferWidth():Int
		return WindowBridge.width();

	public var framebufferHeight(get, never):Int;

	function get_framebufferHeight():Int
		return WindowBridge.height();

	public var pixelRatio(get, never):Float;

	function get_pixelRatio():Float
		return WindowBridge.pixelRatio();

	public var focused(get, never):Bool;

	function get_focused():Bool
		return WindowBridge.focused() != 0;

	@:isVar public var title(get, set):String = "HeliX Haxe";

	function get_title():String
		return title;

	function set_title(value:String):String {
		title = value;
		WindowBridge.setTitle(value);
		return value;
	}

	public var width(get, never):Int;

	function get_width():Int
		return WindowBridge.windowWidth();

	public var height(get, never):Int;

	function get_height():Int
		return WindowBridge.windowHeight();

	public function requestSize(width:Int, height:Int):Bool {
		if (width < 1 || height < 1)
			return false;
		WindowBridge.setSize(width, height);
		return true;
	}

	public function canMove():Bool
		return WindowBridge.canMove() != 0;

	public var x(get, never):Int;

	function get_x():Int
		return canMove() ? WindowBridge.windowX() : 0;

	public var y(get, never):Int;

	function get_y():Int
		return canMove() ? WindowBridge.windowY() : 0;

	public function requestPosition(x:Int, y:Int):Bool {
		if (!canMove())
			return false;
		WindowBridge.setPosition(x, y);
		return true;
	}

	public function canFullscreen():Bool
		return true;

	public var fullscreen(get, never):Bool;

	function get_fullscreen():Bool
		return WindowBridge.fullscreen() != 0;

	public function requestFullscreen(enabled:Bool, ?done:Void->Void, ?failed:String->Void):Bool {
		// Natively it's granted: the window changes as the platform next answers.
		WindowBridge.requestFullscreen(enabled ? 1 : 0);
		if (done != null)
			done();
		return true;
	}

	public var visible(get, never):Bool;

	function get_visible():Bool
		return WindowBridge.visible() != 0;

	public function requestVisible(visible:Bool):Bool {
		WindowBridge.setVisible(visible ? 1 : 0);
		return true;
	}

	public var monitorCount(get, never):Int;

	function get_monitorCount():Int
		return WindowBridge.displayCount();

	public var monitorIndex(get, never):Int;

	function get_monitorIndex():Int
		return WindowBridge.displayCurrent();

	public function requestMonitorIndex(index:Int):Bool {
		if (index < 0 || index >= this.monitorCount || !canMove())
			return false;
		WindowBridge.setDisplay(index);
		return true;
	}

	function valid(index:Int):Bool
		return index >= 0 && index < this.monitorCount;

	public function getMonitorName(index:Int):String
		return valid(index) ? (WindowBridge.displayName(index) : String) : "";

	public function getMonitorX(index:Int):Int
		return valid(index) ? WindowBridge.displayX(index) : 0;

	public function getMonitorY(index:Int):Int
		return valid(index) ? WindowBridge.displayY(index) : 0;

	public function getMonitorWidth(index:Int):Int
		return valid(index) ? WindowBridge.displayWidth(index) : 0;

	public function getMonitorHeight(index:Int):Int
		return valid(index) ? WindowBridge.displayHeight(index) : 0;
}
