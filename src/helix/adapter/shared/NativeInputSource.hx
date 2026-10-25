package helix.adapter.shared;

import helix.input.IInputEvents;
import helix.input.IInputSource;
import helix.input.Key;
import helix.input.PadAxis;
import helix.input.PadButton;

/** What either native input source (sokol's or SDL3's) does the same: the window's queued events reported in order at poll (so a press and
	release in one frame keep both edges), then the gamepads, all through the shared queue (input.h). An input adapter sets its source up,
	moves it on each poll (pollSource) and shuts it down. */
@:noCompletion
abstract class NativeInputSource implements IInputSource {
	var events:IInputEvents;
	var buttons:Array<Bool> = [for (_ in PadButton.all) false];
	var axes:Array<Float> = [for (_ in PadAxis.all) 0.];

	public function start(events:IInputEvents):Void
		this.events = events;

	/** Moves the source on before the queue is read: its gamepads, and whatever it watches. */
	abstract function pollSource():Void;

	/** Nothing unless the source overrides it: a sokol window sends a typed character whenever a key makes one. */
	public function setTextEntry(on:Bool):Void {}

	/** No motion sensor is read natively: asked for, it's Unavailable. */
	public function setTiltWanted(on:Bool):Void
		if (on)
			events.tiltState(Unavailable);

	public function poll():Void {
		pollSource();
		while (InputQueueBridge.next() != 0) {
			var code = InputQueueBridge.eventCode(),
				value = InputQueueBridge.eventValue() != 0,
				x:Float = InputQueueBridge.eventX(),
				y:Float = InputQueueBridge.eventY();
			switch (InputQueueBridge.eventType()) {
				case 1:
					var key = toKey(code);
					if (key != null)
						events.key(key, value);
				case 2:
					events.text(String.fromCharCode(code));
				case 3:
					if (code >= 0 && code < 3)
						events.mouseButton(cast code, value, x, y);
				case 4:
					events.mouseMove(x, y);
				case 5:
					events.wheel(x, y);
				case 6:
					events.touch(code, x, y, value);
				case 7:
					events.focus(value);
				case 8:
					events.mouseLeave();
				default:
			}
		}
		for (i in 0...InputQueueBridge.padSlots()) {
			if (InputQueueBridge.padConnected(i) == 0)
				continue;
			for (button in PadButton.all)
				buttons[button] = InputQueueBridge.padButton(i, button) != 0;
			for (axis in PadAxis.all)
				axes[axis] = InputQueueBridge.padAxis(i, axis);
			events.pad(InputQueueBridge.padName(i), buttons, axes);
		}
	}

	/** The Key a queued key code names: the codes are Key's numbers, right-hand modifiers folded onto the left-hand ones; null for a key
		HeliX doesn't name. */
	static function toKey(code:Int):Null<Key> {
		if (code >= 344 && code <= 347)
			code -= 4;
		return code >= 0 && code < Key.COUNT && known[code] ? cast code : null;
	}

	static final known:Array<Bool> = {
		var v = [for (_ in 0...Key.COUNT) false];
		for (k in Key.all)
			v[k] = true;
		v;
	};
}
