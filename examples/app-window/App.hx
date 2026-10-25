import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.host.ScreenShape;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;

/** The window: its size, place, fullscreen, and monitors. Arrows move it 50 pixels, = and - grow and shrink it by 10%, F toggles fullscreen where the
	window can be, M moves it to the next monitor, H hides it for two seconds (it keeps running), Esc quits where quitting means anything.
	Where programs don't place their windows (the web, a Wayland desktop) moving and changing monitor say "not supported here". The text is a
	Drawing2D on the stage, drawn again each update. */
class App extends helix.App {
	var text = new Drawing2D();
	var status = "press a key";
	var hiddenFor = 0.;

	override public function init():Void {
		Window.title = "HeliX window";
		Window.requestSize(900, 400);
		Stage.color = 0xff181c26;
		Stage.addChild(text);
	}

	function report(what:String, ok:Bool):Void
		status = what + ": " + (ok ? "done" : "not supported here");

	override public function update(dt:Float):Void {
		var width = Window.width, height = Window.height, x = Window.x, y = Window.y;
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		if (Input.isFramePressed(Key.Left))
			report("move", Window.requestPosition(x - 50, y));
		if (Input.isFramePressed(Key.Right))
			report("move", Window.requestPosition(x + 50, y));
		if (Input.isFramePressed(Key.Up))
			report("move", Window.requestPosition(x, y - 50));
		if (Input.isFramePressed(Key.Down))
			report("move", Window.requestPosition(x, y + 50));
		if (Input.isFramePressed(Key.Equal))
			report("grow", Window.requestSize(Std.int(width * 1.1), Std.int(height * 1.1)));
		if (Input.isFramePressed(Key.Minus))
			report("shrink", Window.requestSize(Std.int(width / 1.1), Std.int(height / 1.1)));
		// A request: fullscreen answers on a later frame, and the request says whether it was granted (the browser refuses one with no
		// recent press).
		if (Input.isFramePressed(Key.F)) {
			var asked = Window.requestFullscreen(!Window.fullscreen, () -> status = "fullscreen: granted", reason -> status = 'fullscreen: refused ($reason)');
			status = "fullscreen: " + (asked ? "asked for" : "not supported here");
		}
		if (Input.isFramePressed(Key.H)) {
			Window.requestVisible(false);
			hiddenFor = 2;
			report("hide for 2 s", true);
		}
		if (hiddenFor > 0 && (hiddenFor -= dt) <= 0) {
			Window.requestVisible(true);
			report("show", true);
		}
		if (Input.isFramePressed(Key.M))
			report("monitor", Window.requestMonitorIndex((Window.monitorIndex + 1) % Window.monitorCount));
		// The text in the design for the window's shape, wrapped to what's visible of it.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		text.clear();
		var row = vy + 12;
		row += text.drawTextWrapped("HeliX window   arrows: move   =/-: size   "
			+ (Window.canFullscreen() ? "F: fullscreen" : "(no fullscreen here)")
			+ "   M: next monitor   H: hide",
			vx
			+ 12, row, 16, vw
			- 24, 0xfff5f5f5)
			+ 12;
		row += text.drawTextWrapped('window: $width x $height at ($x, $y)   fullscreen: ' + (Window.fullscreen ? "yes" : "no") + "   focused: "
			+ (Window.focused ? "yes" : "no"),
			vx + 12, row, 16, vw - 24, 0xffc8c8c8)
			+ 4;
		row += text.drawTextWrapped(status, vx + 12, row, 16, vw - 24, 0xffffcb00) + 12;
		for (m in 0...Window.monitorCount) {
			row += text.drawTextWrapped((m == Window.monitorIndex ? "> " : "  ")
				+
				'monitor $m "${Window.getMonitorName(m)}": ${Window.getMonitorWidth(m)} x ${Window.getMonitorHeight(m)} at (${Window.getMonitorX(m)}, ${Window.getMonitorY(m)})',
				vx
				+ 12, row, 16, vw
				- 24, 0xffc8c8c8)
				+ 2;
		}
	}
}
