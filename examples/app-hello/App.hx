import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.LineCap2D;
import helix.render2d.LineJoin2D;
import helix.render2d.Stage;
import helix.time.Time;
import helix.host.ScreenShape;

/** 2D shapes, text and input on the stage: a Drawing2D cleared and drawn again each update holds them (thick lines with each kind of
	corner and end, LineJoin2D and LineCap2D, and ellipses among them); a marker follows the mouse, typing
	shows what was typed (Backspace takes the last character back), and Escape quits where quitting means anything. The frame rate is shown
	at the top (an FpsOverlay node). */
class App extends helix.App {
	var drawing = new Drawing2D();
	var fps = new FpsOverlay();
	var typed = "";

	override public function init():Void {
		Window.title = "HeliX hello";
		Window.requestSize(800, 600);
		Stage.color = 0xfff5f5f5;
		Stage.addChild(drawing);
		Stage.addChild(fps);
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		if (Input.isFramePressed(Key.Backspace) && typed.length > 0)
			typed = typed.substr(0, typed.length - 1);
		if (typed.length + Input.text.length < 64)
			typed += Input.text;
		fps.update(dt, Time.frameCpu);
		// The drawing in the design for the window's shape, from the visible area's top-left corner.
		ScreenShape.update();
		var x = Screen.visibleX,
			y = Screen.visibleY,
			width = Screen.visibleWidth;
		drawing.clear();
		// filled and outlined rectangles
		drawing.rect(x + 40, y + 40, 200, 120, 0xff66bfff);
		drawing.frame(x + 40, y + 40, 200, 120, 1, 0xff0052ac);
		// a line, a triangle, circles
		drawing.line(x + 40, y + 200, x + 240, y + 320, 1, 0xffe62937);
		drawing.polygon([x + 320, y + 60, x + 280, y + 180, x + 360, y + 180], 0xffffcb00);
		drawing.circle(x + 440, y + 120, 60, 0xffc87aff);
		drawing.circleLines(x + 440, y + 120, 60, 1, 0xff000000);
		// thick lines: a zigzag for each corner (pointed, round, cut), each with its own ends (flat, round, square)
		var joins:Array<LineJoin2D> = [Miter, Round, Bevel],
			caps:Array<LineCap2D> = [Butt, Round, Square];
		for (i in 0...3) {
			var top = y + 220 + i * 45;
			drawing.polyline([
				x + 300, top + 30, x + 340, top, x + 380, top + 30, x + 420, top, x + 460, top + 30
			], 12, 0xff2f9e6e, joins[i], caps[i]);
		}
		// ellipses, one turned
		drawing.ellipse(x + 620, y + 100, 80, 36, 0xffff8a3d);
		drawing.ellipse(x + 620, y + 250, 80, 36, 0xff3d8aff, Math.PI / 6);
		// a marker that follows the mouse
		var camera = Stage.camera;
		if (Input.pointerX >= 0)
			drawing.circle(camera.screenToWorldX(Input.pointerX), camera.screenToWorldY(Input.pointerY), 8, 0xffbe2137);
		// text
		drawing.drawText("HeliX", x + 40, y + 360, 32, 0xff505050);
		var below = drawing.drawTextWrapped(typed != "" ? typed : "type something", x + 40, y + 410, 16, width - 80, typed != "" ? 0xff0052ac : 0xff828282);
		if (Host.canQuit())
			drawing.drawText("press Esc to quit", x + 40, y + 420 + below, 16, 0xff828282);
		fps.setPosition(x + 40, y + 12);
	}
}
