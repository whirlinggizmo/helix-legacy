package helix.adapter.inputsource.dom;

import helix.input.IInputEvents;
import helix.input.IInputSource;
import helix.input.Key;
import helix.input.MouseButton;
import helix.input.PadAxis;
import helix.input.PadButton;
import js.Browser;
import js.html.CanvasElement;

/** Browser input: keys and typed text from the window; mouse buttons, moves, fingers and wheel from the canvas, in its framebuffer pixels;
	focus from the window's focus and the page's visibility; gamepads read at poll(), in the W3C standard layout. */
@:noCompletion
class DomInputSourceAdapter implements IInputSource {
	var canvas:CanvasElement;
	var events:IInputEvents;
	var buttons:Array<Bool> = [for (_ in PadButton.all) false];
	var axes:Array<Float> = [for (_ in PadAxis.all) 0.];

	/** Input from the window and canvas, once started. */
	public function new(canvas:CanvasElement)
		this.canvas = canvas;

	public function start(events:IInputEvents):Void {
		this.events = events;
		if (Browser.document.hidden)
			events.focus(false);
		Browser.window.addEventListener("blur", _ -> events.focus(false));
		Browser.window.addEventListener("focus", _ -> events.focus(!Browser.document.hidden));
		Browser.document.addEventListener("visibilitychange", _ -> events.focus(!Browser.document.hidden));
		Browser.window.addEventListener("keydown", e -> {
			var event:js.html.KeyboardEvent = cast e,
				k = codes.get(event.code);
			if (k != null) {
				events.key(k, true);
				// The page keeps its own shortcuts and the function keys; the game gets the rest.
				var n:Int = k;
				if (!(event.ctrlKey || event.metaKey || event.altKey) && !(n >= (Key.F1 : Int) && n <= (Key.F25 : Int)))
					event.preventDefault();
			}
			// Typed characters: event.key is one character (or a surrogate pair) once the layout is applied.
			if (event.key != null && (event.key.length == 1 || event.key.length == 2 && StringTools.fastCodeAt(event.key, 0) >= 0xD800))
				events.text(event.key);
		});
		Browser.window.addEventListener("keyup", e -> {
			var event:js.html.KeyboardEvent = cast e,
				k = codes.get(event.code);
			if (k != null)
				events.key(k, false);
		});
		canvas.addEventListener("contextmenu", e -> e.preventDefault());
		canvas.addEventListener("pointerdown", e -> {
			var event:js.html.PointerEvent = cast e;
			canvas.setPointerCapture(event.pointerId);
			// Prevented, the press doesn't move the keyboard's focus, so the canvas takes it: in a frame (itch.io's page) the keys go
			// to the page the player clicked.
			event.preventDefault();
			canvas.focus();
			pointer(event, true);
		});
		canvas.addEventListener("pointermove", e -> pointer(cast e, true));
		canvas.addEventListener("pointerup", e -> pointer(cast e, false));
		canvas.addEventListener("pointercancel", e -> {
			var event:js.html.PointerEvent = cast e;
			if (event.pointerType == "touch") {
				var p = position(event);
				events.touch(event.pointerId, p.x, p.y, false);
			} else
				events.mouseLeave();
		});
		canvas.addEventListener("wheel", e -> {
			var event:js.html.WheelEvent = cast e;
			event.preventDefault();
			// Notches: Chromium and Firefox report about 100 pixels or 3 lines a notch.
			var scale = event.deltaMode == 0 ? 1 / 100 : event.deltaMode == 1 ? 1 / 3 : 1;
			events.wheel(event.deltaX * scale, -event.deltaY * scale);
		}, {passive: false});
	}

	function position(event:js.html.PointerEvent):{x:Float, y:Float} {
		var box = canvas.getBoundingClientRect();
		return {x: (event.clientX - box.left) * canvas.width / box.width, y: (event.clientY - box.top) * canvas.height / box.height};
	}

	/** A finger down, moved (down) or lifted; or the mouse's buttons from the event's bitmask (a second button pressed while one is held
		arrives as a move, not a down), then its move. */
	function pointer(event:js.html.PointerEvent, down:Bool):Void {
		var p = position(event);
		if (event.pointerType == "touch") {
			events.touch(event.pointerId, p.x, p.y, down);
			return;
		}
		var held = event.buttons;
		events.mouseButton(MouseButton.Left, held & 1 != 0, p.x, p.y);
		events.mouseButton(MouseButton.Right, held & 2 != 0, p.x, p.y);
		events.mouseButton(MouseButton.Middle, held & 4 != 0, p.x, p.y);
		events.mouseMove(p.x, p.y);
	}

	/** Nothing yet: the window's keys type on a computer either way, and a phone's keyboard needs a focused input element, which waits for
		a game typing on one. */
	public function setTextEntry(on:Bool):Void {}

	// Reading the device's orientation (deviceorientation), and waiting for a tap to ask for it where the browser wants one (iOS).
	var tiltListener:Null<Dynamic->Void>;
	var tiltAsking:Null<Dynamic->Void>;

	/** Listens to the device's orientation while on: where the browser asks for leave (DeviceOrientationEvent.requestPermission, iOS),
		at the player's next tap, which shows its prompt (only a tap's own event may ask); a reading without numbers (a computer has no
		sensor) is Unavailable. */
	public function setTiltWanted(on:Bool):Void {
		var window:Dynamic = Browser.window;
		if (!on) {
			if (tiltListener != null)
				window.removeEventListener("deviceorientation", tiltListener);
			tiltListener = null;
			stopAsking();
			return;
		}
		if (window.DeviceOrientationEvent == null) {
			events.tiltState(Unavailable);
			return;
		}
		var listen = () -> {
			if (tiltListener != null)
				return;
			tiltListener = e -> {
				if (e.beta == null || e.gamma == null) {
					events.tiltState(Unavailable);
					return;
				}
				var angle:Float = js.Syntax.code("(screen.orientation && screen.orientation.angle) || window.orientation || 0");
				events.tilt(e.beta, e.gamma, angle);
			};
			window.addEventListener("deviceorientation", tiltListener);
		};
		if (!Std.isOfType(window.DeviceOrientationEvent.requestPermission, js.lib.Function)) {
			listen();
			return;
		}
		// Asked inside the next tap's own event, the only place the browser lets it be asked.
		stopAsking();
		tiltAsking = _ -> {
			stopAsking();
			(window.DeviceOrientationEvent.requestPermission() : js.lib.Promise<String>).then(answer -> {
				if (answer == "granted")
					listen();
				else
					events.tiltState(Refused);
				return null;
			}, _ -> {
				events.tiltState(Refused);
				return null;
			});
		};
		for (name in ["touchend", "click"])
			window.addEventListener(name, tiltAsking, true);
	}

	function stopAsking():Void {
		if (tiltAsking == null)
			return;
		var window:Dynamic = Browser.window;
		for (name in ["touchend", "click"])
			window.removeEventListener(name, tiltAsking, true);
		tiltAsking = null;
	}

	/** Reports the first pads the page sees (a page sees a pad only after a button press on it), each in the W3C standard layout. */
	public function poll():Void {
		var list:Dynamic = Browser.navigator.getGamepads();
		for (i in 0...list.length) {
			var pad:Dynamic = list[i];
			if (pad == null || !pad.connected)
				continue;
			for (button in PadButton.all) {
				var b:Int = button;
				buttons[b] = pad.buttons.length > b && pad.buttons[b].pressed;
			}
			for (axis in [PadAxis.LeftX, PadAxis.LeftY, PadAxis.RightX, PadAxis.RightY]) {
				var a:Int = axis;
				axes[a] = pad.axes.length > a ? pad.axes[a] : 0;
			}
			axes[(PadAxis.LeftTrigger : Int)] = pad.buttons.length > 6 ? pad.buttons[6].value : 0;
			axes[(PadAxis.RightTrigger : Int)] = pad.buttons.length > 7 ? pad.buttons[7].value : 0;
			events.pad(pad.id, buttons, axes);
		}
	}

	/** KeyboardEvent.code to Key, by place on the keyboard. */
	static final codes:Map<String, Key> = {
		var m = new Map<String, Key>();
		for (i in 0...26)
			m.set("Key" + String.fromCharCode(65 + i), cast(65 + i));
		for (i in 0...10) {
			m.set("Digit" + i, cast(48 + i));
			m.set("Numpad" + i, cast(320 + i));
		}
		for (i in 1...26)
			m.set("F" + i, cast(289 + i));
		var named:Map<String, Key> = [
			"Space" => Key.Space,
			"Quote" => Key.Apostrophe,
			"Comma" => Key.Comma,
			"Minus" => Key.Minus,
			"Period" => Key.Period,
			"Slash" => Key.Slash,
			"Semicolon" => Key.Semicolon,
			"Equal" => Key.Equal,
			"BracketLeft" => Key.LeftBracket,
			"Backslash" => Key.Backslash,
			"BracketRight" => Key.RightBracket,
			"Backquote" => Key.Grave,
			"IntlBackslash" => Key.World1,
			"IntlRo" => Key.World2,
			"Escape" => Key.Escape,
			"Enter" => Key.Enter,
			"Tab" => Key.Tab,
			"Backspace" => Key.Backspace,
			"Insert" => Key.Insert,
			"Delete" => Key.Delete,
			"ArrowRight" => Key.Right,
			"ArrowLeft" => Key.Left,
			"ArrowDown" => Key.Down,
			"ArrowUp" => Key.Up,
			"PageUp" => Key.PageUp,
			"PageDown" => Key.PageDown,
			"Home" => Key.Home,
			"End" => Key.End,
			"CapsLock" => Key.CapsLock,
			"ScrollLock" => Key.ScrollLock,
			"NumLock" => Key.NumLock,
			"PrintScreen" => Key.PrintScreen,
			"Pause" => Key.Pause,
			"NumpadDecimal" => Key.KeypadDecimal,
			"NumpadDivide" => Key.KeypadDivide,
			"NumpadMultiply" => Key.KeypadMultiply,
			"NumpadSubtract" => Key.KeypadSubtract,
			"NumpadAdd" => Key.KeypadAdd,
			"NumpadEnter" => Key.KeypadEnter,
			"NumpadEqual" => Key.KeypadEqual,
			"ShiftLeft" => Key.Shift,
			"ShiftRight" => Key.Shift,
			"ControlLeft" => Key.Control,
			"ControlRight" => Key.Control,
			"AltLeft" => Key.Alt,
			"AltRight" => Key.Alt,
			"MetaLeft" => Key.Super,
			"MetaRight" => Key.Super,
			"ContextMenu" => Key.Menu
		];
		for (code => key in named)
			m.set(code, key);
		m;
	};

	/** Nothing to release: the page's listeners go with it. */
	public function shutdown():Void {}
}
