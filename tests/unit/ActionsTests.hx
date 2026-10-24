import haxe.io.Bytes;
import helix.asset.IStore;
import helix.asset.SaveService;
import helix.asset.Saves;
import helix.asset.Storage;
import helix.asset.StorageService;
import helix.asset.StorageResult;
import helix.asset.StorageWriteResult;
import helix.asset.StorageSourceResult;
import helix.host.Presentation;
import helix.host.PresentationMode;
import helix.input.Actions;
import helix.input.Anchor;
import helix.input.Binding;
import helix.input.InputState;
import helix.input.Key;
import helix.input.MouseButton;
import helix.input.PadAxis;
import helix.input.PadButton;

/** A store in memory, answering at the next poll. */
private class Memory implements IStore {
	public var files:Map<String, Bytes> = [];

	var pending:Array<Void->Void> = [];

	public function new() {}

	public function read(key:String, maxBytes:Int, done:StorageResult->Void):Void
		pending.push(() -> done(files.exists(key) ? Stored(files[key]) : Missing));

	public function write(key:String, bytes:Bytes, done:StorageWriteResult->Void):Void
		pending.push(() -> {
			files[key] = bytes;
			done(Written);
		});

	public function remove(key:String, done:StorageWriteResult->Void):Void
		pending.push(() -> {
			files.remove(key);
			done(Written);
		});

	public function clear(done:StorageWriteResult->Void):Void
		pending.push(() -> {
			files.clear();
			done(Written);
		});

	public function lease(key:String, done:StorageSourceResult->Void):Void
		pending.push(() -> done(Missing));

	public function poll():Void {
		var now = pending;
		pending = [];
		for (f in now)
			f();
	}

	public function shutdown():Void {}
}

/** The action map (Actions) over a scripted InputState: every binding kind's value, axis and down, the furthest pushed winning across two
	pads, tick and frame edges, touch regions on the visible area under three presentations, the refusals, capture (a key, an axis, a finger,
	Escape cancelling, the map up while it waits), describe's texts, and save, load and reset through Storage. */
class ActionsTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float):Bool
		return Math.abs(a - b) < 1e-9;

	// The tick, then the frame, ending: what a runner does after each.
	static function step(input:InputState):Void {
		input.consume();
		input.endFrame();
	}

	static function presentation(mode:PresentationMode, width:Int, height:Int, ratio = 1.):Presentation {
		var p = new Presentation();
		if (mode != None)
			p.set(mode, 1280, 720);
		@:privateAccess p.refit(width, height, ratio);
		return p;
	}

	static function main():Void {
		keys();
		pads();
		mouseAndTouch();
		refusals();
		sticks();
		captures();
		texts();
		saving();
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}

	static function keys():Void {
		var input = new InputState();
		var actions = new Actions(input, presentation(None, 800, 600));
		check(actions.bind("jump", Keyboard(Space)) && actions.bind("jump", Pad(South)), "Bindings added");
		check(!actions.isDown("jump") && actions.value("jump") == 0, "Up at first");
		input.keyEvent(Space, true);
		check(actions.isDown("jump") && actions.value("jump") == 1 && actions.axis("jump") == 1, "A key: 1 while down");
		check(actions.isPressed("jump") && actions.isFramePressed("jump"), "Pressed on the tick and the frame");
		input.consume();
		check(!actions.isPressed("jump") && actions.isFramePressed("jump") && actions.isDown("jump"), "The tick's press ends with the tick");
		input.endFrame();
		check(!actions.isFramePressed("jump") && actions.isDown("jump"), "The frame's with the frame");
		input.keyEvent(Space, false);
		check(actions.isReleased("jump") && actions.isFrameReleased("jump") && !actions.isDown("jump"), "Released on both");
		step(input);
		check(!actions.isReleased("jump") && !actions.isFrameReleased("jump"), "Released once");
		// A tap inside one tick: pressed and released, as IInput's; two taps reach two ticks.
		for (_ in 0...2) {
			input.keyEvent(Space, true);
			input.keyEvent(Space, false);
		}
		check(actions.isPressed("jump") && actions.isReleased("jump") && !actions.isDown("jump"), "A tap inside a tick is a press");
		input.consume();
		check(actions.isPressed("jump"), "The second tap reaches the next tick");
		input.consume();
		check(!actions.isPressed("jump"), "and only that one");
		input.endFrame();
		// A pair of keys as an axis.
		actions.bind("steer", KeyboardPair(Left, Right));
		input.keyEvent(Right, true);
		check(actions.axis("steer") == 1, "Positive key");
		input.keyEvent(Left, true);
		check(actions.axis("steer") == 0 && !actions.isDown("steer"), "Both: 0");
		input.keyEvent(Right, false);
		check(actions.axis("steer") == -1 && actions.value("steer") == 1 && actions.isDown("steer"), "Negative key");
		input.keyEvent(Left, false);
		step(input);
		// An action never bound reads as up.
		check(!actions.isDown("fly") && actions.axis("fly") == 0 && actions.value("fly") == 0 && !actions.isPressed("fly") && !actions.isReleased("fly")
			&& !actions.isFramePressed("fly") && actions.bindings("fly").length == 0,
			"An unknown action is up");
		check(actions.names.join(",") == "jump,steer", "Names in the order first bound");
	}

	static function pads():Void {
		var input = new InputState();
		var actions = new Actions(input, presentation(None, 800, 600));
		var first = input.getPad(0), second = input.getPad(1);
		first.connect(true, "one");
		second.connect(true, "two");
		actions.bind("steer", Axis(LeftX, 0, .15));
		actions.bind("left", Axis(LeftX, -1, .5));
		actions.bind("right", Axis(LeftX, 1, .5));
		actions.bind("soft", Axis(LeftX, 0, 0));
		actions.bind("gas", Axis(RightTrigger, 1, .1));
		first.axisEvent(LeftX, .5);
		second.axisEvent(LeftX, -.9);
		check(near(actions.axis("steer"), second.getAxis(LeftX)) && actions.axis("steer") < -.8, "The pad pushed furthest wins");
		check(near(actions.value("left"), -second.getAxis(LeftX)) && actions.isDown("left"), "A side reads 0 to 1");
		check(actions.isPressed("left") && actions.isFramePressed("left"), "An axis past its threshold is a press");
		step(input);
		check(!actions.isPressed("left") && actions.isDown("left"), "once");
		check(actions.value("right") == 0 && !actions.isDown("right"), "The other side: the first pad's 0.41 is under the threshold");
		second.axisEvent(LeftX, 0);
		check(actions.isReleased("left") && actions.isFrameReleased("left"), "Let go: released");
		check(near(actions.axis("steer"), first.getAxis(LeftX)) && actions.isDown("steer"), "Past a non-zero threshold: down");
		check(near(actions.value("soft"), first.getAxis(LeftX)) && !actions.isDown("soft"), "A threshold of 0: down at 0.5");
		first.axisEvent(LeftX, .1);
		check(actions.axis("steer") == 0, "Inside the dead zone: 0");
		second.axisEvent(RightTrigger, .3);
		check(near(actions.value("gas"), .3) && actions.isDown("gas"), "A trigger");
		step(input);
		// Pad buttons, across the pads, alone and as a pair.
		actions.bind("jump", Pad(South));
		actions.bind("turn", PadPair(Left, Right));
		second.buttonEvent(South, true);
		check(actions.isDown("jump") && actions.isPressed("jump") && actions.isFramePressed("jump"), "The second pad's button");
		second.buttonEvent(Right, true);
		first.buttonEvent(Left, true);
		check(actions.axis("turn") == 0, "Both of a pair: 0");
		second.buttonEvent(Right, false);
		check(actions.axis("turn") == -1 && actions.isDown("turn"), "The negative button");
		second.buttonEvent(South, false);
		check(actions.isReleased("jump") && !actions.isDown("jump"), "Released");
		// The furthest pushed across binding kinds: a key at 1 over an axis.
		actions.bind("steer", KeyboardPair(Left, Right));
		first.axisEvent(LeftX, .6);
		input.keyEvent(Left, true);
		check(actions.axis("steer") == -1, "A key pushed further than the stick wins");
	}

	static function mouseAndTouch():Void {
		var input = new InputState();
		var none = presentation(None, 800, 600, 2);
		var actions = new Actions(input, none);
		actions.bind("fire", Mouse(Right));
		input.mouseEvent(Right, true);
		check(actions.isDown("fire") && actions.isPressed("fire") && actions.isFramePressed("fire"), "A mouse button");
		input.mouseEvent(Right, false);
		check(actions.isReleased("fire") && actions.isFrameReleased("fire"), "and its release");
		step(input);
		// None: units are logical pixels, 400 x 300 here at a ratio of 2; the region 300..380 x 200..280.
		actions.bind("shoot", TouchRegion(BottomRight, -100, -100, 80, 80));
		input.touchEvent(1, 650, 450, true);
		check(actions.isDown("shoot") && actions.isFramePressed("shoot") && actions.isPressed("shoot"), "A finger in the region (None)");
		step(input);
		input.touchEvent(1, 590, 450, true);
		check(!actions.isDown("shoot") && actions.isFrameReleased("shoot"), "Slid out of it, framebuffer x 590 being unit 295");
		input.touchEvent(1, 590, 450, false);
		step(input);
		// Fit on a wider window: bars of 360 pixels each side, the region 1180..1260 x 620..700 units.
		actions.presentation = presentation(Fit, 2000, 720);
		input.touchEvent(2, 1550, 650, true);
		check(actions.isDown("shoot"), "A finger in the region (Fit), past the bar");
		input.touchEvent(2, 1550, 650, false);
		step(input);
		input.touchEvent(3, 1190, 650, true);
		check(!actions.isDown("shoot"), "Where the region would be without the bar: nothing");
		input.touchEvent(3, 1190, 650, false);
		step(input);
		// Expand on the same window: the visible area grows to x -360..1640, and BottomRight follows its edge.
		actions.presentation = presentation(Expand, 2000, 720);
		input.touchEvent(4, 1950, 650, true);
		check(actions.isDown("shoot"), "BottomRight follows the wider visible area (Expand)");
		input.touchEvent(4, 1950, 650, false);
		check(!actions.isDown("shoot") && actions.isFrameReleased("shoot"), "A finger lifted in it: a frame release");
		step(input);
		// A tap inside one frame: a frame press, never down.
		input.touchEvent(5, 1950, 650, true);
		input.touchEvent(5, 1950, 650, false);
		check(actions.isFramePressed("shoot") && !actions.isDown("shoot"), "A tap inside a frame is a frame press");
		step(input);
	}

	// A touch stick: a finger landing in its region holds it, centered there, its push over the radius read as X and Y by two actions
	// (past the dead zone, in a circle) wherever it slides; a finger landing takes it over, centered where it lands; the holder lifting hands
	// it to a finger still down, centered where that one is; a blocked landing doesn't take it. A stick on the whole screen; two on the halves.
	// Saved and read back; refused without a radius. direction holds two axes to a circle.
	static function sticks():Void {
		var input = new InputState(),
			actions = new Actions(input, presentation(None, 800, 600, 2));
		// None at a ratio of 2: units are framebuffer pixels halved; the region 0..200 x 100..300 units.
		var x = TouchStick(Region(BottomLeft, 0, -200, 200, 200), 50, X),
			y = TouchStick(Region(BottomLeft, 0, -200, 200, 200), 50, Y);
		check(actions.bind("moveX", x) && actions.bind("moveY", y), "Bound across and down");
		input.touchEvent(1, 200, 400, true);
		check(actions.axis("moveX") == 0 && actions.axis("moveY") == 0, "Where it landed: the middle, 0");
		step(input);
		input.touchEvent(1, 300, 400, true);
		check(near(actions.axis("moveX"), 1) && actions.axis("moveY") == 0 && actions.isDown("moveX"), "A radius right: all the way");
		input.touchEvent(1, 240, 400, true);
		check(near(actions.axis("moveX"), (.4 - .12) / .88), "Part way, past the dead zone: " + actions.axis("moveX"));
		input.touchEvent(1, 205, 400, true);
		check(actions.axis("moveX") == 0, "Within the dead zone: 0");
		input.touchEvent(1, 600, 100, true);
		check(near(actions.axis("moveX"), .8) && near(actions.axis("moveY"), -.6), "Slid out of the region, still held, held to a circle");
		var drawn = [0., 0., 0., 0., 0., 0., 0.];
		check(@:privateAccess actions.heldStick("moveY", drawn) && drawn[0] == 100 && drawn[1] == 200 && drawn[2] == 300 && drawn[3] == 50 && drawn[4] == 50,
			"Where it landed and where it is, for drawing");
		step(input);
		// Another finger landing takes it over, centered where it lands.
		input.touchEvent(2, 100, 500, true);
		check(actions.axis("moveX") == 0 && @:privateAccess actions.heldStick("moveX", drawn) && drawn[0] == 50 && drawn[1] == 250,
			"A finger landing takes it over, centered there");
		step(input);
		input.touchEvent(2, 160, 500, true);
		check(near(actions.axis("moveX"), (.6 - .12) / .88), "and steers it");
		step(input);
		// The holder lifting hands it to the finger still down (1, out of the region now, but holding), centered where that one is.
		input.touchEvent(1, 300, 400, true);
		input.touchEvent(2, 160, 500, false);
		check(actions.axis("moveX") == 0 && @:privateAccess actions.heldStick("moveX", drawn) && drawn[0] == 150 && drawn[1] == 200,
			"Lifted: handed to the finger still down, centered where it is (no lurch)");
		step(input);
		input.touchEvent(1, 300, 400, false);
		step(input);
		check(actions.axis("moveX") == 0 && ! @:privateAccess actions.heldStick("moveX", drawn), "Every finger lifted: let go");
		// A landing where touchStickBlocked says doesn't take it.
		actions.touchStickBlocked = (bx, by) -> bx < 50;
		input.touchEvent(3, 60, 450, true);
		check(! @:privateAccess actions.heldStick("moveX", drawn), "A blocked landing (a button) doesn't take it");
		input.touchEvent(3, 60, 450, false);
		step(input);
		actions.touchStickBlocked = null;
		// The whole screen: held from anywhere, the top right corner here.
		var whole = TouchStick(Anywhere, 50, X);
		check(actions.bind("steer", whole), "A stick on the whole screen");
		input.touchEvent(4, 780, 20, true);
		step(input);
		input.touchEvent(4, 680, 20, true);
		check(near(actions.axis("steer"), -1), "Held from the top right corner, pushed left");
		input.touchEvent(4, 680, 20, false);
		step(input);
		// Two sticks, the halves (x 0..200 and 200..400 units): each thumb takes its own, neither the other's, a landing taking over only
		// its own half's.
		var twin = new Actions(input, presentation(None, 800, 600, 2));
		twin.bind("move", TouchStick(LeftHalf, 50, X));
		twin.bind("aim", TouchStick(RightHalf, 50, Y));
		input.touchEvent(5, 100, 300, true);
		input.touchEvent(6, 700, 300, true);
		step(input);
		input.touchEvent(5, 200, 300, true);
		input.touchEvent(6, 700, 400, true);
		check(near(twin.axis("move"), 1) && near(twin.axis("aim"), 1), "Each half's thumb steers its own stick");
		input.touchEvent(7, 600, 500, true);
		check(near(twin.axis("move"), 1) && twin.axis("aim") == 0, "A thumb landing on the right takes over the right stick only");
		var home = [0., 0., 0., 0., 0., 0., 0.];
		check(@:privateAccess twin.heldStick("aim",
			home) && home[5] == 400 - 90 && home[6] == 300 - 90, "The right stick's hint at the bottom right, margin and radius in");
		for (id in [5, 6, 7])
			input.touchEvent(id, 0, 0, false);
		step(input);
		twin.input = null;
		// direction: two axes held to a circle.
		actions.bind("dx", KeyboardPair(Left, Right));
		actions.bind("dy", KeyboardPair(Up, Down));
		input.keyEvent(Right, true);
		input.keyEvent(Down, true);
		var d = actions.direction("dx", "dy");
		check(near(d.x, Math.sqrt(.5)) && near(d.y, Math.sqrt(.5)), "A diagonal of keys as long as straight");
		input.keyEvent(Down, false);
		check(actions.direction("dx", "dy", d) == d && d.x == 1 && d.y == 0, "Straight; into the point given");
		input.keyEvent(Right, false);
		step(input);
		// An autopilot's finger (a touch command) holds a stick as a thumb would: landed, pushed a radius right, read as all the way.
		var steering = new helix.debug.Autopilot('{"version":1,"seed":1,"commands":[{"op":"touch","ticks":4,"fingers":[{"from":[100,100],"to":[150,100]}]}]}'),
			scripted = new Actions(steering.input, presentation(None, 800, 600, 1));
		scripted.bind("moveX", TouchStick(Anywhere, 50, X));
		var pushes = [
			for (_ in 0...5) {
				steering.advance(name -> null);
				scripted.axis("moveX");
			}
		];
		check(pushes[0] == 0 && pushes[4] == 1 && pushes[2] > 0 && pushes[2] < 1, "A script's finger steers a touch stick: " + pushes);
		scripted.input = null;
		check(@:privateAccess Actions.decode(haxe.Json.parse(@:privateAccess Actions.encodeBinding(y)))
			.equals(y) && @:privateAccess Actions.decode(haxe.Json.parse(@:privateAccess Actions.encodeBinding(whole)))
			.equals(whole) && Actions.describe(x) == "Touch stick X",
			"Saved and read back; described");
		check(!actions.bind("a", TouchStick(Anywhere, 0, X))
			&& !actions.bind("a", TouchStick(Anywhere, 5, null))
			&& !actions.bind("a", TouchStick(null, 5, X))
			&& !actions.bind("a", TouchStick(Region(Center, 0, 0, 10, 0), 5, X)),
			"A stick with no radius, axis or area, or a region with no area, is refused");
	}

	static function refusals():Void {
		var actions = new Actions(new InputState());
		check(!actions.bind("", Keyboard(A)) && !actions.bind(null, Keyboard(A)), "An empty name is refused");
		check(actions.bind("a", Keyboard(A)) && !actions.bind("a", Keyboard(A)), "A duplicate binding is refused");
		check(actions.bind("b", Keyboard(A)), "The same binding on another action isn't");
		check(!actions.bind("a", Axis(LeftX, 2, .5))
			&& !actions.bind("a", Axis(LeftX, 0, 1.5))
			&& !actions.bind("a", Axis(LeftX, 0, -.1))
			&& !actions.bind("a", Axis(LeftX, 0, Math.NaN)),
			"A side not -1, 0 or 1, or a threshold outside 0 to 1, is refused");
		check(!actions.bind("a", TouchRegion(Center, 0, 0, 0, 10))
			&& !actions.bind("a", TouchRegion(Center, 0, 0, 10, -1))
			&& !actions.bind("a", TouchRegion(Center, Math.NaN, 0, 10, 10)),
			"A region with no area is refused");
		check(actions.bindings("a").length == 1, "Nothing refused was added");
		check(!actions.unbind("a", Keyboard(B)) && !actions.unbind("z", Keyboard(A)) && actions.unbind("a", Keyboard(A)) && actions.bindings("a").length == 0,
			"unbind");
		check(!actions.clear("z") && actions.clear("b") && actions.names.join(",") == "a,b", "clear keeps the action");
		// No presentation and no Screen: a touch region reads nothing.
		var input = new InputState();
		var bare = new Actions(input);
		bare.bind("t", TouchRegion(TopLeft, 0, 0, 100, 100));
		input.touchEvent(1, 10, 10, true);
		check(!bare.isDown("t"), "No visible area: no touch");
	}

	static function captures():Void {
		var input = new InputState();
		var actions = new Actions(input, presentation(None, 800, 600, 2));
		actions.bind("jump", Keyboard(Space));
		actions.bind("jump", KeyboardPair(Up, Down));
		actions.bind("jump", Pad(South));
		actions.bind("menu", Keyboard(Enter));
		actions.bind("pause", Keyboard(Escape));
		var captured:Null<Binding> = null, cancelled = false;
		// The press that started it (a click on Rebind) doesn't count.
		input.keyEvent(A, true);
		check(actions.capture("jump", b -> captured = b, () -> cancelled = true) && actions.capturing, "Capturing");
		check(!actions.capture("menu", b -> {}), "One capture at a time");
		check(!actions.capture("", b -> {}), "An empty name is refused");
		input.endFrame();
		check(captured == null && actions.capturing, "The frame it began in is skipped");
		input.keyEvent(A, false);
		input.keyEvent(Enter, true);
		check(!actions.isDown("menu") && !actions.isPressed("menu") && !actions.isFramePressed("menu"), "Up while capturing");
		input.endFrame();
		check(!actions.capturing && Type.enumEq(captured, Keyboard(Enter)), "A key captured");
		var now = actions.bindings("jump");
		check(now.length == 2 && Type.enumEq(now[0], Pad(South)) && Type.enumEq(now[1], Keyboard(Enter)), "It replaced the keyboard's bindings only");
		check(!actions.isDown("menu") && !actions.isDown("jump") && !actions.isPressed("jump") && !actions.isPressed("menu"),
			"The captured press fires nothing while held");
		input.consume();
		input.keyEvent(Enter, false);
		check(!actions.isReleased("jump") && !actions.isFrameReleased("jump"), "nor when let go");
		step(input);
		input.keyEvent(Enter, true);
		check(actions.isPressed("jump") && actions.isPressed("menu") && actions.isFramePressed("jump"), "Pressed again: both fire");
		input.keyEvent(Enter, false);
		step(input);
		// Escape cancels, changing nothing, and fires no pause.
		captured = null;
		actions.capture("jump", b -> captured = b, () -> cancelled = true);
		input.endFrame();
		input.keyEvent(Escape, true);
		input.endFrame();
		check(cancelled && captured == null && !actions.capturing && actions.bindings("jump").length == 2, "Escape cancels");
		check(!actions.isDown("pause") && !actions.isPressed("pause"), "and its press fires nothing");
		input.keyEvent(Escape, false);
		step(input);
		input.keyEvent(Escape, true);
		check(actions.isPressed("pause"), "Escape works again once let go");
		input.keyEvent(Escape, false);
		step(input);
		// A stick past half way, replacing the pad's button.
		var pad = input.getPad(0);
		pad.connect(true, "pad");
		pad.axisEvent(LeftX, .3);
		actions.capture("jump", b -> captured = b);
		input.endFrame();
		pad.axisEvent(LeftX, -1);
		input.endFrame();
		check(Type.enumEq(captured, Axis(LeftX, -1, .5)), "A stick captured with its side");
		now = actions.bindings("jump");
		check(now.length == 2
			&& Type.enumEq(now[0], Keyboard(Enter))
			&& Type.enumEq(now[1], Axis(LeftX, -1, .5)), "It replaced the pad's");
		pad.axisEvent(LeftX, 0);
		step(input);
		// A finger: a 96 unit square around it, from the nearest anchor (units 380, 280 of 400 x 300: BottomRight).
		actions.capture("jump", b -> captured = b);
		input.endFrame();
		input.touchEvent(1, 760, 560, true);
		input.endFrame();
		check(Type.enumEq(captured, TouchRegion(BottomRight, -68, -68, 96, 96)), "A finger captured as a region");
		check(actions.bindings("jump").length == 3 && !actions.isDown("jump"), "added, its press read up while held");
		input.touchEvent(1, 760, 560, false);
		step(input);
		input.touchEvent(2, 700, 500, true);
		check(actions.isDown("jump"), "The region works");
		input.touchEvent(2, 700, 500, false);
		step(input);
		// Cancelled by the game.
		cancelled = false;
		actions.capture("jump", b -> captured = b, () -> cancelled = true);
		check(actions.cancelCapture() && cancelled && !actions.capturing && !actions.cancelCapture(), "cancelCapture");
	}

	static function texts():Void {
		var cases:Array<{binding:Binding, text:String}> = [
			{binding: Keyboard(Space), text: "Space"},
			{binding: Keyboard(A), text: "A"},
			{binding: Keyboard(Digit1), text: "1"},
			{binding: Keyboard(PageUp), text: "Page up"},
			{binding: Keyboard(Keypad5), text: "Keypad 5"},
			{binding: Keyboard(F12), text: "F12"},
			{binding: KeyboardPair(Left, Right), text: "Left / Right"},
			{binding: Pad(South), text: "Pad south"},
			{binding: PadPair(Left, Right), text: "D-pad left / D-pad right"},
			{binding: Axis(LeftX, 0, .15), text: "Left stick X"},
			{binding: Axis(LeftX, -1, .5), text: "Left stick left"},
			{binding: Axis(RightY, 1, .5), text: "Right stick down"},
			{binding: Axis(RightTrigger, 1, .1), text: "Right trigger"},
			{binding: Mouse(Left), text: "Left mouse"},
			{binding: TouchRegion(Center, 0, 0, 10, 10), text: "Touch"}
		];
		for (c in cases)
			check(Actions.describe(c.binding) == c.text, 'describe ${c.binding}: ${Actions.describe(c.binding)}, not ${c.text}');
		// Binding imported beside the key types leaves their names free: Key.Space, PadButton.South.
		check(Key.getName(Key.PageUp) == "PageUp"
			&& Key.getName(Key.Digit0) == "0"
			&& Key.named("pageup") == Key.PageUp
			&& Key.named("0") == Key.Digit0
			&& Actions.describe(Keyboard(Key.Space)) == "Space"
			&& Actions.describe(Pad(PadButton.South)) == "Pad south"
			&& Actions.describe(Axis(PadAxis.LeftX, 0, .15)) == "Left stick X"
			&& Actions.describe(Mouse(MouseButton.Left)) == "Left mouse",
			"Key names both ways");
	}

	static function defaults(actions:Actions):Void {
		actions.bind("jump", Keyboard(Space));
		actions.bind("jump", Pad(South));
		actions.bind("steer", KeyboardPair(Left, Right));
		actions.bind("steer", Axis(LeftX, 0, .15));
		actions.bind("fire", TouchRegion(BottomRight, -120, -120, 96, 96));
		actions.bind("click", Mouse(Left));
	}

	static function settle(saves:SaveService):Void
		for (_ in 0...8)
			saves.poll();

	static function saving():Void {
		// The saves apart from the asset cache, which a game may clear.
		var memory = new Memory(), cacheStore = new Memory();
		var saves = new SaveService(memory),
			cache = new StorageService(cacheStore);
		@:privateAccess Saves.bind(saves);
		@:privateAccess Storage.bind(cache);
		var input = new InputState();
		var first = new Actions(input);
		defaults(first);
		first.capture("jump", b -> {});
		input.endFrame();
		input.keyEvent(J, true);
		input.endFrame();
		input.keyEvent(J, false);
		step(input);
		var saved = false;
		first.save(() -> saved = true);
		settle(saves);
		check(saved && memory.files.exists("actions"), "Saved under actions");
		var text = memory.files["actions"].toString();
		check(StringTools.startsWith(text, '{"version":1,"actions":{"jump":[{"padButton":"South"},{"key":"J"}],')
			&& text.indexOf('{"keys":["Left","Right"]},{"padAxis":"LeftX","side":0,"threshold":0.15}') > 0
			&& text.indexOf('{"touch":"BottomRight","x":-120,"y":-120,"width":96,"height":96}') > 0
			&& text.indexOf('{"mouseButton":"Left"}') > 0,
			'The format: $text');
		// A fresh map with the same defaults loads the capture back.
		var second = new Actions(new InputState());
		defaults(second);
		var loaded = false;
		second.load(() -> loaded = true);
		settle(saves);
		check(loaded, "Loaded");
		for (name in first.names)
			check(Lambda.foreach([for (i in 0...first.bindings(name).length) i], i -> Type.enumEq(first.bindings(name)[i], second.bindings(name)[i]))
				&& first.bindings(name).length == second.bindings(name).length,
				'$name loaded as saved');
		second.reset();
		check(Type.enumEq(second.bindings("jump")[0], Keyboard(Space))
			&& second.bindings("jump").length == 2, "reset restores the code's bindings");
		first.reset();
		check(Type.enumEq(first.bindings("jump")[0], Keyboard(Space)), "and after a capture");
		// Unknown entries are skipped, an action the game doesn't bind dropped, one the save doesn't name kept.
		memory.files["broken"] = Bytes.ofString('{"version":1,"actions":{"jump":[{"key":"Nope"},{"padButton":"North"},{"wat":1},'
			+ '{"padAxis":"LeftY","side":3,"threshold":0.5}],"gone":[{"key":"A"}]}}');
		var third = new Actions(new InputState());
		defaults(third);
		var logged:Array<String> = [];
		var log = haxe.Log.trace;
		haxe.Log.trace = (v, ?infos) -> logged.push(Std.string(v));
		third.load("broken", () -> loaded = true);
		settle(saves);
		haxe.Log.trace = log;
		check(logged.length == 3 && logged[0].indexOf("broken: jump: unknown key Nope") >= 0, 'Each skipped entry logged: $logged');
		check(third.bindings("jump").length == 1 && Type.enumEq(third.bindings("jump")[0], Pad(North)), "Unknown entries skipped");
		check(third.names.indexOf("gone") < 0 && third.bindings("steer").length == 2, "An unbound action dropped, an unnamed one kept");
		// A file that isn't a save fails, changing nothing; nothing saved is no failure.
		memory.files["bad"] = Bytes.ofString('{"version":2}');
		var failure = "";
		third.load("bad", () -> {}, message -> failure = message);
		settle(saves);
		check(failure.indexOf("version 1") >= 0 && third.bindings("jump").length == 1, "A wrong version fails");
		loaded = false;
		third.load("never", () -> loaded = true, message -> failure = "missing");
		settle(saves);
		check(loaded && third.bindings("jump").length == 1, "Nothing saved: done, unchanged");
		// Clearing the asset cache keeps them: they're saves, not cached files.
		var cleared = false;
		Storage.clear(_ -> cleared = true);
		for (_ in 0...8)
			cache.poll();
		var fourth = new Actions(new InputState());
		defaults(fourth);
		loaded = false;
		fourth.load(() -> loaded = true);
		settle(saves);
		check(cleared && loaded && memory.files.exists("actions") && fourth.bindings("jump").length == first.bindings("jump").length,
			"Clearing the asset cache keeps the saved bindings");
		@:privateAccess Saves.bind(null);
		@:privateAccess Storage.bind(null);
	}
}
