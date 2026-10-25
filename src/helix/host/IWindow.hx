package helix.host;

/** The window the app draws in: title, size, place, fullscreen, visibility and the monitors, in logical pixels.
	Names follow docs/CONVENTIONS.md: a value is a property; can says whether to offer an action at all; request asks for what the platform
	may refuse or grant later, returning whether it asked, never whether it was granted, and the property answers on a later frame. A request
	that can't act here refuses, returning false: the web can't move or size its window, and under XWayland the compositor places windows. */
@:noCompletion
interface IWindow {
	/** The drawable area's width in framebuffer pixels (the width and height sizes are logical pixels). */
	var framebufferWidth(get, never):Int;

	/** The drawable area's height in framebuffer pixels. */
	var framebufferHeight(get, never):Int;

	/** Framebuffer pixels per logical pixel. */
	var pixelRatio(get, never):Float;

	/** Whether the window has the keyboard and is shown: false while it's in the background, minimized, or (on the web) the page is hidden. */
	var focused(get, never):Bool;

	/** The title bar's text (the document's title, on the web). */
	var title(get, set):String;

	/** The window's inner width in logical pixels (the viewport's, on the web). */
	var width(get, never):Int;

	/** The window's inner height in logical pixels (the viewport's, on the web). */
	var height(get, never):Int;

	/** Asks for an inner size in logical pixels; width and height answer on a later frame, with what the window manager gave (it may
		give another size, or none). False, asking nothing, where a program can't size its window (the web), or for a size under 1. */
	function requestSize(width:Int, height:Int):Bool;

	/** Whether requestPosition and requestMonitorIndex can ask: not on the web, nor where the compositor places windows (XWayland). */
	function canMove():Bool;

	/** The window's left edge on the desktop in logical pixels; natively 0 where it can't move (canMove), on the web the browser window's. */
	var x(get, never):Int;

	/** The window's top edge on the desktop in logical pixels; natively 0 where it can't move (canMove), on the web the browser window's. */
	var y(get, never):Int;

	/** Asks for the window's left and top edges on the desktop in logical pixels; x and y answer on a later frame, with what the
		window manager gave. False, asking nothing, where the window can't move (canMove). */
	function requestPosition(x:Int, y:Int):Bool;

	/** Whether requestFullscreen can ask: always natively; on the web, where the page may go fullscreen. */
	function canFullscreen():Bool;

	/** Whether the window is fullscreen now (the canvas, on the web). */
	var fullscreen(get, never):Bool;

	/** Asks for fullscreen (enabled) or a window; fullscreen answers on a later frame, and done is called once it's granted. On the web the
		browser grants it only soon after a key press, click or tap: refused (none was recent, or the page may not), failed is called with
		its reason, or without failed it's logged as a warning, and the page stays as it was; natively it's granted. False, calling neither, where it can't
		ask (canFullscreen). */
	function requestFullscreen(enabled:Bool, ?done:Void->Void, ?failed:String->Void):Bool;

	/** Asks for the screen held a way up (Landscape, Portrait) or as the player holds it (Any, letting a lock go): done once it's locked,
		failed with the reason when it's refused, or without failed it's logged as a warning. Only some browsers lock it (Chrome on Android, and only in
		fullscreen: ask in requestFullscreen's done), not iOS Safari nor a desktop, so a game also shows "turn your device" when the shape is
		wrong (Screen's portrait). False, calling neither, where it can't ask: natively, where the window is the window. */
	function requestOrientation(orientation:helix.host.Orientation, ?done:Void->Void, ?failed:String->Void):Bool;

	/** Whether the window is shown (the canvas, on the web). */
	var visible(get, never):Bool;

	/** Asks to show or hide the window (the canvas, on the web); visible answers on a later frame (natively, once the window manager has
		shown it). Always asks: true. */
	function requestVisible(visible:Bool):Bool;

	/** How many monitors there are, at least 1; the web sees one screen. */
	var monitorCount(get, never):Int;

	/** The monitor holding the window. */
	var monitorIndex(get, never):Int;

	/** Asks for the window on monitor index; monitorIndex answers on a later frame. False, asking nothing, for an index out of range, or where
		the window can't move (canMove). */
	function requestMonitorIndex(index:Int):Bool;

	/** "" for an index out of range, as the other monitor getters answer 0. */
	function getMonitorName(index:Int):String;

	/** The monitor's left edge on the desktop in logical pixels; 0 for an index out of range, and on the web. */
	function getMonitorX(index:Int):Int;

	/** The monitor's top edge on the desktop in logical pixels; 0 for an index out of range, and on the web. */
	function getMonitorY(index:Int):Int;

	/** The monitor's width in logical pixels; 0 for an index out of range. */
	function getMonitorWidth(index:Int):Int;

	/** The monitor's height in logical pixels; 0 for an index out of range. */
	function getMonitorHeight(index:Int):Int;
}
