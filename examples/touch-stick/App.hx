import helix.host.Host;
import helix.host.Screen;
import helix.host.ScreenShape;
import helix.host.Window;
import helix.input.Actions;
import helix.input.Input;
import helix.input.Key;
import helix.input.StickArea;
import helix.math.Point2D;
import helix.render2d.Drawing2D;
import helix.render2d.Shape2D;
import helix.render2d.Stage;
import helix.render2d.Text2D;
import helix.ui.TouchStick2D;

/** Floating touch sticks steering a dot (Binding.TouchStick, drawn by TouchStick2D), in four layouts chosen by the buttons at the top,
	laid out in the examples' design for the window's shape (ScreenShape: 560 units across upright), so they scale with the window and two
	regions side by side fit in either orientation:
	- 1 stick: on the whole screen (StickArea.Anywhere). A thumb landing anywhere holds it, centered where it landed; another thumb landing
	  takes it over, centered there; the holding thumb lifting hands it to one still down.
	- 2 sticks: the left half moves the dot, the right half aims it (LeftHalf, RightHalf), each thumb holding its own.
	- Region: one stick in a rectangle at the bottom left (StickArea.Region), outlined.
	- 2 regions: the moving stick in a rectangle at the bottom left, the aiming one in one at the bottom right; a thumb between them
	  takes neither.
	The buttons aren't the sticks' (Actions.touchStickBlocked): a tap on one presses it. A faint ring says where each stick's thumb goes
	while none holds it. The arrow keys and a pad's left stick steer the dot too (and the pad's right stick aims), all read as one direction
	held to a circle (Actions.direction), so a diagonal of keys is no faster than straight. Escape quits where quitting means anything. */
class App extends helix.App {
	static inline var SPEED = 420.;
	static inline var RADIUS = 80.;
	static inline var BUTTON_Y = 56.;
	static inline var BUTTON_HEIGHT = 48.;
	static inline var BUTTON_GAP = 8.;
	static inline var BUTTON_WIDTH = 100.;
	static inline var REGION_SIDE = 260.;
	static final REGION = Region(BottomLeft, 0, -REGION_SIDE, REGION_SIDE, REGION_SIDE);
	static final AIM_REGION = Region(BottomRight, -REGION_SIDE, -REGION_SIDE, REGION_SIDE, REGION_SIDE);

	var actions:Actions;
	var dot = Shape2D.circle(24, 0xffffd25a);
	var drawing = new Drawing2D();
	var status = new Text2D("", 18, 0xffe8e8e8);
	var moveStick:TouchStick2D;
	var aimStick:TouchStick2D;
	var buttons:Array<{
		label:String,
		width:Float,
		face:Shape2D,
		text:Text2D
	}> = [];
	var move = new Point2D();
	var aim = new Point2D();
	var aimX = 1.;
	var aimY = 0.;
	var mode = "1 stick";
	var paused = false;
	var placed = false;

	override public function init():Void {
		Window.title = "HeliX touch sticks";
		Window.requestSize(900, 700);
		ScreenShape.update();
		Stage.color = 0xff161921;
		Stage.addChild(drawing);
		Stage.addChild(dot);
		Stage.addChild(status);
		for (label in ["1 stick", "2 sticks", "Region", "2 regions", "Pause"]) {
			var button = {
				label: label,
				width: BUTTON_WIDTH,
				face: Shape2D.rectangle(1, BUTTON_HEIGHT, 0xff2e3448),
				text: new Text2D(label, 18, 0xffe8e8e8)
			};
			button.face.setSize(button.width, BUTTON_HEIGHT);
			button.text.setPivot(.5, .5);
			Stage.addChild(button.face);
			Stage.addChild(button.text);
			buttons.push(button);
		}
		moveStick = new TouchStick2D(null, "moveX");
		aimStick = new TouchStick2D(null, "aimX", 0x80ff9a6a);
		moveStick.hint = aimStick.hint = true;
		Stage.addChild(moveStick);
		Stage.addChild(aimStick);
		choose("1 stick");
	}

	// The layout: the actions bound afresh for it (the arrows and a pad steering in every one), the sticks drawn from them.
	function choose(chosen:String):Void {
		mode = chosen;
		if (actions != null)
			actions.input = null;
		actions = new Actions();
		var moveArea:StickArea = switch mode {
			case "2 sticks": LeftHalf;
			case "Region" | "2 regions": REGION;
			case _: Anywhere;
		};
		actions.bind("moveX", TouchStick(moveArea, RADIUS, X));
		actions.bind("moveY", TouchStick(moveArea, RADIUS, Y));
		if (aiming()) {
			var aimArea:StickArea = mode == "2 sticks" ? RightHalf : AIM_REGION;
			actions.bind("aimX", TouchStick(aimArea, RADIUS, X));
			actions.bind("aimY", TouchStick(aimArea, RADIUS, Y));
		}
		actions.bind("moveX", KeyboardPair(Left, Right));
		actions.bind("moveY", KeyboardPair(Up, Down));
		actions.bind("moveX", Axis(LeftX, 0, 0));
		actions.bind("moveY", Axis(LeftY, 0, 0));
		actions.bind("aimX", Axis(RightX, 0, 0));
		actions.bind("aimY", Axis(RightY, 0, 0));
		// A thumb landing on a button presses it, not a stick.
		actions.touchStickBlocked = (x, y) -> buttonAt(x, y) != null;
		moveStick.actions = aimStick.actions = actions;
	}

	// Whether the layout has an aiming stick.
	function aiming():Bool
		return mode == "2 sticks" || mode == "2 regions";

	// The button at x, y (the stage's units), laid out in a row along the top, or null.
	function buttonAt(x:Float, y:Float):Null<String> {
		var left = Screen.visibleX + BUTTON_GAP,
			top = Screen.visibleY + BUTTON_Y;
		for (button in buttons) {
			if (x >= left && x < left + button.width && y >= top && y < top + BUTTON_HEIGHT)
				return button.label;
			left += button.width + BUTTON_GAP;
		}
		return null;
	}

	override public function update(dt:Float):Void {
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth,
			vh = Screen.visibleHeight;
		if (!placed) {
			placed = true;
			dot.setPosition(vx + vw / 2, vy + vh / 2);
		}
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		// The buttons: placed along the top, the chosen layout lit; a tap (or a click) on one chooses it, or pauses.
		var left = vx + BUTTON_GAP;
		for (button in buttons) {
			button.face.setPosition(left, vy + BUTTON_Y);
			button.text.setPosition(left + button.width / 2, vy + BUTTON_Y + BUTTON_HEIGHT / 2);
			button.face.color = button.label == mode ? 0xff4c8ef0 : 0xff2e3448;
			if (button.label == "Pause")
				button.text.text = paused ? "Resume" : "Pause";
			left += button.width + BUTTON_GAP;
		}
		if (Input.pointerFramePressed) {
			var pressed = buttonAt(Stage.camera.screenToWorldX(Input.pointerX), Stage.camera.screenToWorldY(Input.pointerY));
			if (pressed == "Pause")
				paused = !paused;
			else if (pressed != null && pressed != mode)
				choose(pressed);
		}
		// The dot moved by one direction, kept on the screen; aimed by the other, its last aim kept while none is pushed.
		actions.direction("moveX", "moveY", move);
		actions.direction("aimX", "aimY", aim);
		if (!paused)
			dot.setPosition(Math.max(vx, Math.min(vx + vw, dot.x + move.x * SPEED * dt)), Math.max(vy, Math.min(vy + vh, dot.y + move.y * SPEED * dt)));
		var aimed = Math.sqrt(aim.x * aim.x + aim.y * aim.y);
		if (aimed > 0) {
			aimX = aim.x / aimed;
			aimY = aim.y / aimed;
		}
		drawing.clear();
		if (aiming())
			drawing.line(dot.x, dot.y, dot.x + aimX * 70, dot.y + aimY * 70, 4, 0xffff9a6a);
		// The regions' outlines, where a thumb takes a stick.
		if (mode == "Region" || mode == "2 regions")
			drawing.frame(vx, vy + vh - REGION_SIDE, REGION_SIDE, REGION_SIDE, 2, 0x40e8e8e8);
		if (mode == "2 regions")
			drawing.frame(vx + vw - REGION_SIDE, vy + vh - REGION_SIDE, REGION_SIDE, REGION_SIDE, 2, 0x40ff9a6a);
		status.setPosition(vx + 16, vy + 16);
		var push = Math.round(Math.sqrt(move.x * move.x + move.y * move.y) * 100);
		status.text = '$mode: move ${push}%${aiming() ? '   aim ${Math.round(aimed * 100)}%' : ""}${paused ? "   paused" : ""}';
	}
}
