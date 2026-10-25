# helix.input

[Back to the index](README.md)

## Actions

*class* in [`src/helix/input/Actions.hx`](../../src/helix/input/Actions.hx), `import helix.input.Actions;`

What the player means ("jump", "steer", "fire"), bound by name to keys, pad buttons and axes, mouse buttons, touch regions and touch sticks, and read as one: a game asks for "jump", never for Space or the south button, and a player can rebind it (capture) and keep it (save, load). Each binding gives a value from -1 to 1 (Binding), and the action is the binding pushed furthest, across every pad: axis its value, value how far (0 to 1), isDown while any binding is pushed to its limit (0.5, or a pad axis's non-zero threshold). Pressed and released come per tick (isPressed, isReleased) and per frame (isFramePressed, isFrameReleased), as IInput's do: an action is pressed when it is down and wasn't as the last tick (or frame) ended, or when a key, button or finger of it went down since (IInput's own edges, so a tap shorter than a tick is still a press, and two taps reach two ticks). The map keeps whether each action was down itself, told by the input as each tick and frame ends (IInput.watch), so a game makes no extra calls. A finger's edges are frame edges only (IInput has no tick edges for touches): a tap shorter than a frame reaches isFramePressed, not isPressed. An action never bound reads as up and 0, so a game's code may run before its bindings load. Built on IInput, so whatever drives the input drives the actions: the autopilot's input given to it (input) replays them.

```haxe
function new(?input:IInput, ?presentation:Presentation)
static inline var VERSION:Int
static inline var CAPTURE_THRESHOLD:Float
static function describe(binding:Binding):String
var input(default, set):Null<IInput>
var names(get, never):Array<String>
var capturing(default, null):Bool
var captureTouchSize(default, set):Float
var touchStickDeadZone(default, set):Float
var touchStickBlocked:Null<(x:Float, y:Float) -> Bool>
function bind(name:String, binding:Binding):Bool
function unbind(name:String, binding:Binding):Bool
function clear(name:String):Bool
function bindings(name:String):Array<Binding>
function axis(name:String):Float
function value(name:String):Float
function isDown(name:String):Bool
function isPressed(name:String):Bool
function isReleased(name:String):Bool
function direction(xName:String, yName:String, ?out:Point2D):Point2D
function isFramePressed(name:String):Bool
function isFrameReleased(name:String):Bool
function capture(name:String, done:Binding -> Void, ?cancelled:() -> Void):Bool
function cancelCapture():Bool
function save(?key:String = "actions", ?done:() -> Void, ?failed:String -> Void):Void
function load(?key:String = "actions", ?done:() -> Void, ?failed:String -> Void):Void
function reset():Void
function tickEnded():Void
function frameEnded():Void
```

- `new`: Actions read from input, the program's (Input) when not given, their touch regions placed on presentation's visible area (Screen's when null). Made in init or later when given none: before the program runs there's no input to watch, and it reads every action as up.
- `VERSION`: The saved format's version (save, load).
- `CAPTURE_THRESHOLD`: How far past it a pad axis must go for capture to take it: half way, as down is for a binding without a threshold.
- `describe`: The text a remap screen shows for binding: "Space", "Left / Right", "Pad south", "D-pad left / D-pad right", "Left stick X", "Left stick left" (a stick with a side), "Right trigger", "Left mouse", "Touch".
- `input`: The input the actions are read from, which tells the map as each tick and frame ends; null reads every action as up. Assigning stops watching the input before: a game playing an autopilot's script gives it the script's input, and an Actions given up is given null.
- `names`: The actions, in the order first bound; an action cleared or unbound to nothing stays.
- `capturing`: Whether capture is waiting for a press; while it is, every action reads as up.
- `captureTouchSize`: The width and height of a touch region capture makes, centered where the finger landed, in the game's units (Screen's). At least 1; 96 to begin with.
- `touchStickDeadZone`: How far from its middle a touch stick reads 0, a fraction of its radius (0 to 0.9): .12 to begin with, so a resting thumb doesn't drift; past it the push runs from 0 to 1.
- `touchStickBlocked`: Where a finger landing doesn't take a touch stick, asked with x, y in the game's units (Screen's): over a button, say. Null (the start): nowhere. A touch region binding isn't affected.
- `bind`: Adds binding to the action name, making the action with its first binding. False, changing nothing, for an empty name, a binding the action has already, a pad axis's side not -1, 0 or 1 or threshold outside 0 to 1, or a touch region with no area or an offset that isn't a number.
- `unbind`: Takes binding off the action name, the action kept; false for an action or binding there isn't.
- `clear`: Takes every binding off the action name, the action kept (a remap screen binds it again); false for an action there isn't.
- `bindings`: The action's bindings, in the order bound (a copy); empty for an action there isn't.
- `axis`: The action's value with its direction, -1 to 1: the binding pushed furthest. 0 for an action there isn't.
- `value`: How far the action is pushed, 0 to 1: axis without its direction.
- `isDown`: Whether the action is held: any of its bindings pushed to 0.5, or a pad axis to its threshold when that isn't 0.
- `isPressed`: The action went down: since the last tick ended, it went down, or a key, button or mouse button of it did (a tick edge).
- `isReleased`: The action came up: it was down as the last tick ended and isn't now, or a key, button or mouse button of it came up and it isn't down (a tick edge).
- `direction`: One direction from two actions, xName across and yName down (a stick's X and Y, or a pair of keys each): their axes, held to a circle, so a diagonal of keys is as long as straight and a stick's push keeps its strength. Into out when given (allocating nothing), a new Point2D otherwise: actions.direction("moveX", "moveY").
- `isFramePressed`: The action went down this frame, as isPressed for the frame, a finger landing in a touch region too (a frame edge).
- `isFrameReleased`: The action came up this frame, as isReleased for the frame, a finger lifting in a touch region too (a frame edge).
- `capture`: Waits for the player's next press and binds it to the action name: a key, a pad button, a pad axis pushed past half way (Axis with its side and a threshold of CAPTURE_THRESHOLD), or a finger (a captureTouchSize square centered where it landed, anchored to the nearest of the visible area's nine anchors). Mouse buttons aren't captured, as the mouse works the remap screen itself. The press replaces the action's bindings of the same device (the keyboard's Keyboard and KeyboardPair; the pad's Pad, PadPair and Axis; the touch screen's TouchRegion) and leaves the others; done is then called with it. Escape cancels, calling cancelled. Presses in the frame capture is called in don't count (the click or tap on a Rebind button), and while it waits every action reads as up; the captured press, and the Escape, read as up until they are let go. False, starting nothing, for an empty name or while capturing already.
- `cancelCapture`: Stops a capture waiting for a press, calling its cancelled (a remap screen's Cancel button); false when none is waiting.
- `save`: Writes every action's bindings as the save named key (Saves, kept apart from the asset cache, so clearing it keeps them), as JSON: {"version":1,"actions":{"jump":[{"key":"Space"},{"padButton":"South"}]}}, each binding by its kind ({"keys":["Left","Right"]}, {"padButtons":["Left","Right"]}, {"padAxis":"LeftX","side":0,"threshold":0.15}, {"mouseButton":"Left"}, {"touch":"BottomRight","x":-120,"y":-120,"width":96,"height":96}), keys by Key.getName. Then done; a failure (a write refused) goes to failed, or to the log when failed is null.
- `load`: Reads the bindings saved as the save named key (Saves), and replaces the bindings of each action the game has bound with the saved ones; an action the save names but the game doesn't bind is dropped, an action the save doesn't name keeps its bindings, and an entry the map can't read (an unknown kind or name, a refused binding) is skipped and logged (Failure). Then done, also when nothing was saved; a failure (a read failing, a file that isn't a version 1 save) goes to failed, or to the log when failed is null, the bindings unchanged. The defaults reset restores are kept first.
- `reset`: Restores each action's defaults: its bindings as the game bound them in code, kept at the first load or capture after the action was made (so what a player changed, by a capture or a loaded save, goes back). An action made after the last load or capture has no defaults yet and keeps its bindings.
- `tickEnded`: For the input (IInputWatcher): keeps whether each action was down as the tick ended, and lets go of a captured press seen up.
- `frameEnded`: For the input (IInputWatcher): takes a press for capture, keeps whether each action was down as the frame ended, and lets go of a captured press seen up.

## Anchor

*enum* in [`src/helix/input/Anchor.hx`](../../src/helix/input/Anchor.hx), `import helix.input.Anchor;`

A point of the visible area (Screen's), which a touch region is placed from: a corner, an edge's middle or the center.

- `TopLeft`: The visible area's top left corner.
- `Top`: The middle of its top edge.
- `TopRight`: Its top right corner.
- `Left`: The middle of its left edge.
- `Center`: Its center.
- `Right`: The middle of its right edge.
- `BottomLeft`: Its bottom left corner.
- `Bottom`: The middle of its bottom edge.
- `BottomRight`: Its bottom right corner.

## Binding

*enum* in [`src/helix/input/Binding.hx`](../../src/helix/input/Binding.hx), `import helix.input.Binding;`

What drives an action (Actions), each giving a value from -1 to 1; the action is the binding pushed furthest.

- `Keyboard(key:Key)`: A key: 1 while it is down.
- `KeyboardPair(negative:Key, positive:Key)`: A pair of keys as an axis: -1 while negative is down, 1 while positive is, 0 for both or neither.
- `Pad(button:PadButton)`: A pad button on any connected pad: 1 while it is down.
- `PadPair(negative:PadButton, positive:PadButton)`: A pair of pad buttons as an axis, across the pads: -1 for negative, 1 for positive, 0 for both or neither (the d-pad's Left and Right as steering).
- `Axis(axis:PadAxis, side:Int, threshold:Float)`: A pad axis, past the dead zone (Gamepad.getAxis), the pad pushed furthest: side 0 reads both directions (-1..1, a trigger 0..1), 1 or -1 only that side, as 0..1; under threshold (0..1) it reads 0, and at or past a non-zero threshold the action is down.
- `Mouse(button:MouseButton)`: A mouse button: 1 while it is down.
- `TouchRegion(anchor:Anchor, x:Float, y:Float, width:Float, height:Float)`: A touch region: 1 while a finger is down in it. In the game's units (Screen's): the anchor's point on the visible area, then x, y from it to the region's top left, width x height across and down; so it scales with the design and follows the visible area's edges.
- `TouchStick(area:StickArea, radius:Float, axis:StickAxis)`: A floating stick for a thumb, in area (the whole screen, a half of it, or a region). A finger landing in it holds the stick, centered where it landed, and its offset from there, radius units for all the way, is the stick's push, clamped to a circle and 0 within Actions.touchStickDeadZone of the middle. Another finger landing in it takes it over, centered where it lands; the holding finger lifting hands it to one still down in it, centered where that one is (so what it steers doesn't lurch). A finger landing where Actions.touchStickBlocked says (a button) doesn't take it, nor one holding another stick. The action reads its axis (X right, Y down, as a pad's stick); an action bound to X and one bound to Y of the same area and radius read one stick: actions.bind("moveX", TouchStick(Anywhere, 80, X)), or for two sticks LeftHalf and RightHalf.
- `Tilt(axis:StickAxis)`: The device tilted (Input.tiltX, tiltY: -1 to 1, from level, turned with the screen): X across, Y up and down the screen. Read once the game asks for it (Input.requestTilt); 0 until then. A rolling ball: actions.bind("moveX", Tilt(X)).

## Gamepad

*class* in [`src/helix/input/Gamepad.hx`](../../src/helix/input/Gamepad.hx), `import helix.input.Gamepad;`

One gamepad slot. Edges work as the keyboard's: tick edges until consume(), frame edges until the frame ends. Sticks read past a radial dead zone, rescaled so they still reach 1; getRawAxis reads them as the pad reports.

```haxe
function new()
var connected(default, null):Bool
var name(default, null):String
var deadzone(default, set):Float
function isDown(button:PadButton):Bool
function isPressed(button:PadButton):Bool
function isReleased(button:PadButton):Bool
function isFramePressed(button:PadButton):Bool
function isFrameReleased(button:PadButton):Bool
function getRawAxis(axis:PadAxis):Float
function getAxis(axis:PadAxis):Float
function connect(value:Bool, name:String):Void
function buttonEvent(button:PadButton, value:Bool):Void
function axisEvent(axis:PadAxis, value:Float):Void
function consume():Void
function endFrame():Void
```

- `new`: An empty slot.
- `connected`: Whether a pad is in this slot. While the window is unfocused a pad stays connected, its buttons up and axes centred.
- `name`: The pad's name as the platform reports it; empty when the slot is empty.
- `deadzone`: Fraction of a stick's reach that reads as centred. Clamped to 0 (none) to 0.999 (NaN is 0).
- `isDown`: Whether the button is held now.
- `isPressed`: The button went down: a counted tick edge, as a key's, so two presses between ticks reach two ticks.
- `isReleased`: The button came up: a counted tick edge.
- `isFramePressed`: The button went down this frame: a frame edge.
- `isFrameReleased`: The button came up this frame: a frame edge.
- `getRawAxis`: The axis as the pad reports it, without the dead zone: sticks -1..1, triggers 0..1.
- `getAxis`: A stick axis past the radial dead zone, rescaled to reach 1, -1..1; a trigger as reported, 0..1.
- `connect`: Fills the slot with a named pad (true) or empties it (false), for the InputRouter; emptying lets go of every button and centres every axis.
- `buttonEvent`: A button's state, from the InputRouter; going down sets both press edges.
- `axisEvent`: An axis's value, from the InputRouter, clamped to -1..1 for a stick and 0..1 for a trigger.
- `consume`: Clears the tick edges; the input's consume() calls it after each tick.
- `endFrame`: Clears the frame edges; the input's endFrame() calls it after each frame.

## IInput

*class* in [`src/helix/input/IInput.hx`](../../src/helix/input/IInput.hx), `import helix.input.IInput;`

Keyboard, pointer, mouse buttons, wheel, typed text, touches and gamepads. Tick edges (isPressed, isReleased) are counted and survive polling and render frames; consume() after a simulation tick takes one of each, so every press is seen by exactly one tick, and two presses between ticks reach two ticks. Frame edges (isFramePressed, isFrameReleased), typed text, the wheel and lifted touches last one frame. A key is claimed by what reads it first and uses it (claim: the UI's focused text field, a menu): for the rest of the frame it reads as up, unpressed and unreleased to everything after, so typing a space in a field doesn't make the player jump.

```haxe
function isDown(key:Key):Bool
function isPressed(key:Key):Bool
function isReleased(key:Key):Bool
function isFramePressed(key:Key):Bool
function isFrameReleased(key:Key):Bool
function claim(key:Key):Void
function isClaimed(key:Key):Bool
var pointerX(get, never):Float
var pointerY(get, never):Float
var pointerDown(get, never):Bool
var pointerPressed(get, never):Bool
var pointerReleased(get, never):Bool
var pointerFramePressed(get, never):Bool
var pointerFrameReleased(get, never):Bool
function isMouseDown(button:MouseButton):Bool
function isMousePressed(button:MouseButton):Bool
function isMouseFramePressed(button:MouseButton):Bool
function isMouseReleased(button:MouseButton):Bool
function isMouseFrameReleased(button:MouseButton):Bool
var wheelX(get, never):Float
var wheelY(get, never):Float
var text(get, never):String
var textEntry(get, set):Bool
var touches(get, never):Array<Touch>
var touchGesture(get, never):Bool
var touchGestureCenterX(get, never):Float
var touchGestureCenterY(get, never):Float
function getTouchGesturePanX(?perTick:Bool = false):Float
function getTouchGesturePanY(?perTick:Bool = false):Float
function getTouchGestureScale(?perTick:Bool = false):Float
function getTouchGestureRotation(?perTick:Bool = false):Float
var padCount(get, never):Int
function getPad(index:Int):Null<Gamepad>
var activated(get, never):Bool
var anyFramePressed(get, never):Bool
function isPadDown(button:PadButton):Bool
function isPadPressed(button:PadButton):Bool
function getPadAxis(axis:PadAxis):Float
var tiltX(get, never):Float
var tiltY(get, never):Float
var tiltState(get, never):TiltState
function requestTilt():Void
function calibrateTilt():Void
function consume():Void
```

- `isDown`: Whether the key is held now.
- `isPressed`: The key went down: a tick edge, counted until consume() takes it.
- `isReleased`: The key came up: a tick edge, counted until consume() takes it.
- `isFramePressed`: The key went down this frame: a frame edge.
- `isFrameReleased`: The key came up this frame: a frame edge.
- `claim`: Takes key for the rest of the frame: what reads it after sees it up, unpressed and unreleased (isDown, isPressed, isReleased and the frame edges false) until the frame ends, and its edges are spent, so no later tick sees them either. Whoever reads first and uses a key claims it: the UI does (Ui.update), so the game reads after it.
- `isClaimed`: Whether key was claimed this frame (claim).
- `pointerX`: The primary pointer, in framebuffer pixels: the mouse with its left button, or the first finger. -1 when it isn't over the window.
- `pointerY`: The primary pointer's y, in framebuffer pixels down from the top. -1 when it isn't over the window.
- `pointerDown`: Whether the primary pointer is down: the left mouse button held, or the first finger touching.
- `pointerPressed`: The primary pointer went down: a tick edge, counted until consume() takes it.
- `pointerReleased`: The primary pointer came up: a tick edge, counted until consume() takes it.
- `pointerFramePressed`: The primary pointer went down this frame: a frame edge.
- `pointerFrameReleased`: The primary pointer came up this frame: a frame edge.
- `isMouseDown`: Whether the mouse button is held now.
- `isMousePressed`: The mouse button went down: a tick edge, counted until consume() takes it.
- `isMouseFramePressed`: The mouse button went down this frame: a frame edge.
- `isMouseReleased`: The button came up: a counted tick edge, as a key's.
- `isMouseFrameReleased`: The button came up this frame: a frame edge.
- `wheelX`: Wheel notches this frame; up and right are positive.
- `wheelY`: Vertical wheel notches this frame; up is positive.
- `text`: Characters typed this frame, after the keyboard layout; only while text entry is on (textEntry).
- `textEntry`: Whether typed text is being taken; off at start. On, text carries the characters typed, and a platform with a soft keyboard shows it for them; off, keys are only keys and the keyboard stays down. The UI turns it on while a text field has focus; a game reading text itself turns it on while it types (a name entered, a chat line) and off after.
- `touches`: Fingers down, and those lifted this frame.
- `touchGesture`: Whether two fingers are down: the two down longest make the gesture.
- `touchGestureCenterX`: The point between the gesture's fingers now, in framebuffer pixels; 0 without a gesture.
- `touchGestureCenterY`: See touchGestureCenterX.
- `getTouchGesturePanX`: How far the point between the fingers moved, in framebuffer pixels: this frame, or since the last tick with perTick.
- `getTouchGesturePanY`: See getTouchGesturePanX.
- `getTouchGestureScale`: How much the fingers spread (over 1) or pinched (under 1), as a factor: this frame, or since the last tick with perTick; 1 without.
- `getTouchGestureRotation`: How far the line between the fingers turned, in radians, clockwise on screen positive: this frame, or since the last tick with perTick.
- `padCount`: Four slots, connected or not.
- `getPad`: null for an index out of range.
- `activated`: Whether the user has pressed a key, a mouse button or a finger yet (the browser's user activation, which lets audio start and fullscreen be asked for; the same rule everywhere, so a game's flow is one flow): a title screen's "press any key". A pad's press doesn't count, as a browser can't unlock with one, so a game on a pad alone asks for a tap or key once. Stays true. An autopilot's press counts, so a script gated on it presses before it waits.
- `anyFramePressed`: Whether a key, a mouse button or a finger went down this frame, whichever: a "press any key" screen's press. A pad's doesn't count, as activated's doesn't.
- `isPadDown`: Any connected pad.
- `isPadPressed`: A connected pad's button went down: a counted tick edge, as a key's.
- `getPadAxis`: The first connected pad's axis, past the dead zone as Gamepad.getAxis gives it.
- `tiltX`: How the device is tilted across, -1 to 1 (right down positive), from level: how the player held it steady at the start, after the screen turned, or after calibrateTilt. TILT_RANGE degrees is all the way. It's turned with the screen, so it's across the screen as the player sees it. 0 unless tiltState is On.
- `tiltY`: How the device is tilted up and down the screen, -1 to 1: the top tipped away negative (rolling a ball up the screen), toward the player positive. As tiltX.
- `tiltState`: Where reading the tilt is: Off until requestTilt, Waiting, Calibrating, On, Refused, Unavailable (TiltState).
- `requestTilt`: Starts reading the device's tilt (tiltX, tiltY). In a browser that wants a tap for it (iOS), it's asked for at the player's next tap, which shows the browser's prompt: call it on a title screen, say, before the tap that starts play. Again after Refused asks again.
- `calibrateTilt`: Takes level anew: tiltX and tiltY read 0 until the player holds the device steady for half a second, and that's level. Call it from a "Level" button, say, or as a round starts.
- `consume`: Call after each simulation tick: takes one of each counted tick edge and clears the pads' tick edges.

## Input

*class* in [`src/helix/input/Input.hx`](../../src/helix/input/Input.hx), `import helix.input.Input;`

Keyboard, mouse, touch and gamepads, as this frame and tick see them. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from IInput's public members with their doc comments, but watch and unwatch (plumbing for what is built on IInput, as Actions, not for a game).

```haxe
static function isDown(key:Key):Bool
static function isPressed(key:Key):Bool
static function isReleased(key:Key):Bool
static function isFramePressed(key:Key):Bool
static function isFrameReleased(key:Key):Bool
static function claim(key:Key):Void
static function isClaimed(key:Key):Bool
static var pointerX(get, never):Float
static var pointerY(get, never):Float
static var pointerDown(get, never):Bool
static var pointerPressed(get, never):Bool
static var pointerReleased(get, never):Bool
static var pointerFramePressed(get, never):Bool
static var pointerFrameReleased(get, never):Bool
static function isMouseDown(button:MouseButton):Bool
static function isMousePressed(button:MouseButton):Bool
static function isMouseFramePressed(button:MouseButton):Bool
static function isMouseReleased(button:MouseButton):Bool
static function isMouseFrameReleased(button:MouseButton):Bool
static var wheelX(get, never):Float
static var wheelY(get, never):Float
static var text(get, never):String
static var textEntry(get, set):Bool
static var touches(get, never):Array<Touch>
static var touchGesture(get, never):Bool
static var touchGestureCenterX(get, never):Float
static var touchGestureCenterY(get, never):Float
static function getTouchGesturePanX(?perTick:Bool = false):Float
static function getTouchGesturePanY(?perTick:Bool = false):Float
static function getTouchGestureScale(?perTick:Bool = false):Float
static function getTouchGestureRotation(?perTick:Bool = false):Float
static var padCount(get, never):Int
static function getPad(index:Int):Null<Gamepad>
static var activated(get, never):Bool
static var anyFramePressed(get, never):Bool
static function isPadDown(button:PadButton):Bool
static function isPadPressed(button:PadButton):Bool
static function getPadAxis(axis:PadAxis):Float
static var tiltX(get, never):Float
static var tiltY(get, never):Float
static var tiltState(get, never):TiltState
static function requestTilt():Void
static function calibrateTilt():Void
static function consume():Void
```

- `isDown`: Whether the key is held now.
- `isPressed`: The key went down: a tick edge, counted until consume() takes it.
- `isReleased`: The key came up: a tick edge, counted until consume() takes it.
- `isFramePressed`: The key went down this frame: a frame edge.
- `isFrameReleased`: The key came up this frame: a frame edge.
- `claim`: Takes key for the rest of the frame: what reads it after sees it up, unpressed and unreleased (isDown, isPressed, isReleased and the frame edges false) until the frame ends, and its edges are spent, so no later tick sees them either. Whoever reads first and uses a key claims it: the UI does (Ui.update), so the game reads after it.
- `isClaimed`: Whether key was claimed this frame (claim).
- `pointerX`: The primary pointer, in framebuffer pixels: the mouse with its left button, or the first finger. -1 when it isn't over the window.
- `pointerY`: The primary pointer's y, in framebuffer pixels down from the top. -1 when it isn't over the window.
- `pointerDown`: Whether the primary pointer is down: the left mouse button held, or the first finger touching.
- `pointerPressed`: The primary pointer went down: a tick edge, counted until consume() takes it.
- `pointerReleased`: The primary pointer came up: a tick edge, counted until consume() takes it.
- `pointerFramePressed`: The primary pointer went down this frame: a frame edge.
- `pointerFrameReleased`: The primary pointer came up this frame: a frame edge.
- `isMouseDown`: Whether the mouse button is held now.
- `isMousePressed`: The mouse button went down: a tick edge, counted until consume() takes it.
- `isMouseFramePressed`: The mouse button went down this frame: a frame edge.
- `isMouseReleased`: The button came up: a counted tick edge, as a key's.
- `isMouseFrameReleased`: The button came up this frame: a frame edge.
- `wheelX`: Wheel notches this frame; up and right are positive.
- `wheelY`: Vertical wheel notches this frame; up is positive.
- `text`: Characters typed this frame, after the keyboard layout; only while text entry is on (textEntry).
- `textEntry`: Whether typed text is being taken; off at start. On, text carries the characters typed, and a platform with a soft keyboard shows it for them; off, keys are only keys and the keyboard stays down. The UI turns it on while a text field has focus; a game reading text itself turns it on while it types (a name entered, a chat line) and off after.
- `touches`: Fingers down, and those lifted this frame.
- `touchGesture`: Whether two fingers are down: the two down longest make the gesture.
- `touchGestureCenterX`: The point between the gesture's fingers now, in framebuffer pixels; 0 without a gesture.
- `touchGestureCenterY`: See touchGestureCenterX.
- `getTouchGesturePanX`: How far the point between the fingers moved, in framebuffer pixels: this frame, or since the last tick with perTick.
- `getTouchGesturePanY`: See getTouchGesturePanX.
- `getTouchGestureScale`: How much the fingers spread (over 1) or pinched (under 1), as a factor: this frame, or since the last tick with perTick; 1 without.
- `getTouchGestureRotation`: How far the line between the fingers turned, in radians, clockwise on screen positive: this frame, or since the last tick with perTick.
- `padCount`: Four slots, connected or not.
- `getPad`: null for an index out of range.
- `activated`: Whether the user has pressed a key, a mouse button or a finger yet (the browser's user activation, which lets audio start and fullscreen be asked for; the same rule everywhere, so a game's flow is one flow): a title screen's "press any key". A pad's press doesn't count, as a browser can't unlock with one, so a game on a pad alone asks for a tap or key once. Stays true. An autopilot's press counts, so a script gated on it presses before it waits.
- `anyFramePressed`: Whether a key, a mouse button or a finger went down this frame, whichever: a "press any key" screen's press. A pad's doesn't count, as activated's doesn't.
- `isPadDown`: Any connected pad.
- `isPadPressed`: A connected pad's button went down: a counted tick edge, as a key's.
- `getPadAxis`: The first connected pad's axis, past the dead zone as Gamepad.getAxis gives it.
- `tiltX`: How the device is tilted across, -1 to 1 (right down positive), from level: how the player held it steady at the start, after the screen turned, or after calibrateTilt. TILT_RANGE degrees is all the way. It's turned with the screen, so it's across the screen as the player sees it. 0 unless tiltState is On.
- `tiltY`: How the device is tilted up and down the screen, -1 to 1: the top tipped away negative (rolling a ball up the screen), toward the player positive. As tiltX.
- `tiltState`: Where reading the tilt is: Off until requestTilt, Waiting, Calibrating, On, Refused, Unavailable (TiltState).
- `requestTilt`: Starts reading the device's tilt (tiltX, tiltY). In a browser that wants a tap for it (iOS), it's asked for at the player's next tap, which shows the browser's prompt: call it on a title screen, say, before the tap that starts play. Again after Refused asks again.
- `calibrateTilt`: Takes level anew: tiltX and tiltY read 0 until the player holds the device steady for half a second, and that's level. Call it from a "Level" button, say, or as a round starts.
- `consume`: Call after each simulation tick: takes one of each counted tick edge and clears the pads' tick edges.

## InputState

*class* in [`src/helix/input/InputState.hx`](../../src/helix/input/InputState.hx), `import helix.input.InputState;`

The input an app reads, as edges and state: fed by the InputRouter from a platform's events, or directly by replay and tests. Tick edges (isPressed, isReleased) are counted, and consume() after a simulation tick takes one of each, so every press is seen by exactly one tick, and two presses between ticks reach two ticks; frame edges (isFramePressed, isFrameReleased), typed text, the wheel and lifted touches last one frame, until endFrame() (the InputRouter's, which the Runner calls).

```haxe
function new()
static inline var TILT_RANGE:Float
static inline var TILT_STEADY_SECONDS:Float
static inline var TILT_STEADY_DEGREES:Float
function isDown(key:Key):Bool
function isPressed(key:Key):Bool
function isReleased(key:Key):Bool
function isFramePressed(key:Key):Bool
function isFrameReleased(key:Key):Bool
function claim(key:Key):Void
function isClaimed(key:Key):Bool
var pointerX(get, never):Float
var pointerY(get, never):Float
var pointerDown(get, never):Bool
var pointerPressed(get, never):Bool
var pointerReleased(get, never):Bool
var pointerFramePressed(get, never):Bool
var pointerFrameReleased(get, never):Bool
var wheelX(get, never):Float
var wheelY(get, never):Float
var text(get, never):String
var textEntry(get, set):Bool
var touches(get, never):Array<Touch>
var padCount(get, never):Int
function getPad(index:Int):Null<Gamepad>
function isMouseDown(button:MouseButton):Bool
function isMousePressed(button:MouseButton):Bool
function isMouseFramePressed(button:MouseButton):Bool
function isMouseReleased(button:MouseButton):Bool
function isMouseFrameReleased(button:MouseButton):Bool
function isPadDown(button:PadButton):Bool
function isPadPressed(button:PadButton):Bool
function getPadAxis(axis:PadAxis):Float
var activated(get, never):Bool
var anyFramePressed(get, never):Bool
function keyEvent(key:Key, value:Bool):Void
function padEvent(button:PadButton, value:Bool):Void
function axisEvent(axis:PadAxis, value:Float):Void
function mouseEvent(button:MouseButton, value:Bool):Void
function pointerEvent(x:Float, y:Float, value:Bool):Void
function textEvent(value:String):Void
function wheelEvent(x:Float, y:Float):Void
function touchEvent(id:Int, x:Float, y:Float, value:Bool):Void
var touchGesture(get, never):Bool
var touchGestureCenterX(get, never):Float
var touchGestureCenterY(get, never):Float
function getTouchGesturePanX(?perTick:Bool = false):Float
function getTouchGesturePanY(?perTick:Bool = false):Float
function getTouchGestureScale(?perTick:Bool = false):Float
function getTouchGestureRotation(?perTick:Bool = false):Float
function clear():Void
var tiltX(get, never):Float
var tiltY(get, never):Float
var tiltState(get, never):TiltState
function requestTilt():Void
function calibrateTilt():Void
function consume():Void
function endFrame():Void
```

- `new`: Nothing down, nothing pressed, no pad connected, not activated.
- `TILT_RANGE`: Degrees of tilt that read as all the way (tiltX, tiltY at 1).
- `TILT_STEADY_SECONDS`: How long the device is held steady before that's taken as level (seconds).
- `TILT_STEADY_DEGREES`: How far the device may move while it's held steady (degrees).
- `keyEvent`: A key down (true) or up (false); only a change of state counts an edge, so key repeat doesn't. A down activates (activated).
- `padEvent`: Pad 0's button or axis, connecting it: for replay and tests.
- `axisEvent`: Pad 0's axis, connecting it: for replay and tests.
- `mouseEvent`: A mouse button down (true) or up (false); only a change of state counts an edge.
- `pointerEvent`: The primary pointer at x, y in framebuffer pixels (-1, -1 off the window), down or up; only a change of down counts an edge.
- `textEvent`: Typed characters, appended to this frame's text while text entry is on; dropped while it's off.
- `wheelEvent`: Wheel notches, added to this frame's; up and right are positive.
- `touchEvent`: A finger down, moved or lifted. A lifted one stays in touches, not down, until the frame ends.
- `clear`: Lets go of everything held, as when focus is lost: the releases are edges; presses not yet consumed, typed text and the wheel are dropped.
- `endFrame`: Tells the watchers, then ends the frame's edges, text, wheel and lifted touches; the InputRouter calls it after each frame.

## Key

*abstract* in [`src/helix/input/Key.hx`](../../src/helix/input/Key.hx), `import helix.input.Key;`

Physical keys by place on a US layout, numbered as GLFW numbers them; each input adapter maps its platform's codes to them. Left and right Shift, Control, Alt and Super are one key each.

Values: `Space`, `Apostrophe`, `Comma`, `Minus`, `Period`, `Slash`, `Digit0`, `Digit1`, `Digit2`, `Digit3`, `Digit4`, `Digit5`, `Digit6`, `Digit7`, `Digit8`, `Digit9`, `Semicolon`, `Equal`, `A`, `B`, `C`, `D`, `E`, `F`, `G`, `H`, `I`, `J`, `K`, `L`, `M`, `N`, `O`, `P`, `Q`, `R`, `S`, `T`, `U`, `V`, `W`, `X`, `Y`, `Z`, `LeftBracket`, `Backslash`, `RightBracket`, `Grave`, `Escape`, `Enter`, `Tab`, `Backspace`, `Insert`, `Delete`, `Right`, `Left`, `Down`, `Up`, `PageUp`, `PageDown`, `Home`, `End`, `F1`, `F2`, `F3`, `F4`, `F5`, `F6`, `F7`, `F8`, `F9`, `F10`, `F11`, `F12`, `World1`, `World2`, `CapsLock`, `ScrollLock`, `NumLock`, `PrintScreen`, `Pause`, `F13`, `F14`, `F15`, `F16`, `F17`, `F18`, `F19`, `F20`, `F21`, `F22`, `F23`, `F24`, `F25`, `Keypad0`, `Keypad1`, `Keypad2`, `Keypad3`, `Keypad4`, `Keypad5`, `Keypad6`, `Keypad7`, `Keypad8`, `Keypad9`, `KeypadDecimal`, `KeypadDivide`, `KeypadMultiply`, `KeypadSubtract`, `KeypadAdd`, `KeypadEnter`, `KeypadEqual`, `Shift`, `Control`, `Alt`, `Super`, `Menu`.

```haxe
static inline var COUNT:Int
static final all(default, null):Array<Key>
static function named(name:String):Key
static function getName(key:Key):String
function toString():String
```

- `COUNT`: One past the largest value, for arrays indexed by key.
- `all`: Every key, in order of value.
- `named`: The key a name spells, ignoring case ("A", "space", "KeypadEnter", "0"); throws for an unknown name.
- `getName`: The key's name as named reads it: its own spelling ("Space", "PageUp", "KeypadEnter"), a digit's its digit ("0").
- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## MouseButton

*abstract* in [`src/helix/input/MouseButton.hx`](../../src/helix/input/MouseButton.hx), `import helix.input.MouseButton;`

The mouse buttons HeliX reads, numbered as Sokol numbers them.

Values: `Left`, `Right`, `Middle`.

```haxe
static final all(default, null):Array<MouseButton>
function toString():String
```

- `all`: Every button.
- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## PadAxis

*abstract* in [`src/helix/input/PadAxis.hx`](../../src/helix/input/PadAxis.hx), `import helix.input.PadAxis;`

Sticks run from -1 to 1 (down and right positive), triggers from 0 to 1.

Values: `LeftX`, `LeftY`, `RightX`, `RightY`, `LeftTrigger`, `RightTrigger`.

```haxe
static inline var COUNT:Int
static final all(default, null):Array<PadAxis>
function toString():String
```

- `COUNT`: One past the largest value, for arrays indexed by axis.
- `all`: Every axis.
- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## PadButton

*abstract* in [`src/helix/input/PadButton.hx`](../../src/helix/input/PadButton.hx), `import helix.input.PadButton;`

A gamepad's buttons, as on an Xbox-style pad, numbered as the W3C standard gamepad numbers them. The triggers are buttons too (pressed when pulled past half way, or by a digital trigger) as well as axes.

Values: `South`, `East`, `West`, `North`, `LeftBumper`, `RightBumper`, `LeftTrigger`, `RightTrigger`, `Back`, `Start`, `LeftStick`, `RightStick`, `Up`, `Down`, `Left`, `Right`, `Guide`.

```haxe
static inline var COUNT:Int
static final all(default, null):Array<PadButton>
function toString():String
```

- `COUNT`: One past the largest value, for arrays indexed by button.
- `all`: Every button.
- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## PointerGestures

*class* in [`src/helix/input/PointerGestures.hx`](../../src/helix/input/PointerGestures.hx), `import helix.input.PointerGestures;`

Taps, double taps, drags and flicks from IInput's pointer, in framebuffer pixels; touch and mouse alike (a double tap is a double click). Update once per tick, before the input is consumed, reading its tick edges; or once per frame, reading its frame edges, in a program without a fixed tick.

```haxe
function new(?slop:Float = 12., ?tapSeconds:Float = .3)
var maxTapDistance(get, set):Float
var maxTapDuration(get, set):Float
var maxDoubleTapInterval(get, set):Float
var maxDoubleTapDistance(get, set):Float
var down(default, null):Bool
var pressed(default, null):Bool
var released(default, null):Bool
var dragging(default, null):Bool
var tapped(default, null):Bool
var doubleTapped(default, null):Bool
var x(default, null):Float
var y(default, null):Float
var startX(default, null):Float
var startY(default, null):Float
var flickVelocityX(get, never):Float
var flickVelocityY(get, never):Float
function update(now:Float, perTick:Bool, ?input:IInput):Void
```

- `new`: Gestures with a tap's limits: slop in framebuffer pixels, tapSeconds in seconds, clamped as maxTapDistance and maxTapDuration are.
- `maxTapDistance`: How far a press may move and still be a tap, in pixels. 0 or more (under 0, or NaN, is 0).
- `maxTapDuration`: How long a press may last and still be a tap, in seconds. At least 1e-6 (0 or less, or NaN, is 1e-6).
- `maxDoubleTapInterval`: How long after one tap began the next may begin and make a double tap, in seconds. At least 1e-6 (0 or less, or NaN, is 1e-6); half a second at first.
- `maxDoubleTapDistance`: How far from where one tap began the next may begin and make a double tap, in pixels. 0 or more (under 0, or NaN, is 0); 24 at first.
- `down`: Whether the pointer is down, as of the last update.
- `pressed`: The pointer went down at the last update.
- `released`: The pointer came up at the last update.
- `dragging`: Moved past the slop during this press.
- `tapped`: The press that ended at the last update was a tap: it stayed within the slop and the tap time.
- `doubleTapped`: The tap that ended at the last update was the second of a double tap (a double click): it began within maxDoubleTapInterval of the tap before it and within maxDoubleTapDistance of where that one began. A third tap starts a new pair.
- `x`: The pointer's x in framebuffer pixels, as of the last update while down; it holds while the pointer is off the window, and after release.
- `y`: The pointer's y in framebuffer pixels, held as x is.
- `startX`: Where the current or last press began, x in framebuffer pixels.
- `startY`: Where the current or last press began, y in framebuffer pixels.
- `flickVelocityX`: Velocity over the last tenth of a second before release, pixels per second.
- `flickVelocityY`: Vertical velocity as flickVelocityX, down positive.
- `update`: Reads the pointer of input, the program's (Input) when not given: once per tick with perTick, its tick edges, before the input is consumed; or once per frame without, its frame edges. now is the time in seconds.

## StickArea

*enum* in [`src/helix/input/StickArea.hx`](../../src/helix/input/StickArea.hx), `import helix.input.StickArea;`

Where a finger can land to take a touch stick (Binding.TouchStick), following the visible area (Screen's) as the window changes shape or turns. Two sticks split it down the middle in either orientation (both thumbs at the bottom of a phone held upright, too).

- `Anywhere`: The whole visible area: one stick, either thumb, anywhere.
- `LeftHalf`: The visible area's left half: the moving stick of two.
- `RightHalf`: The visible area's right half: the aiming stick of two.
- `Region(anchor:Anchor, x:Float, y:Float, width:Float, height:Float)`: A rectangle placed as a touch region is (Binding.TouchRegion): the anchor's point on the visible area, then x, y from it to the top left, width x height across and down, in the game's units.

## StickAxis

*enum* in [`src/helix/input/StickAxis.hx`](../../src/helix/input/StickAxis.hx), `import helix.input.StickAxis;`

Which way of a touch stick (Binding.TouchStick) an action reads, as a pad's stick runs: across (X, right positive) or up and down (Y, down positive).

- `X`: Across: -1 at the left, 1 at the right.
- `Y`: Up and down: -1 at the top, 1 at the bottom.

## TiltState

*abstract* in [`src/helix/input/TiltState.hx`](../../src/helix/input/TiltState.hx), `import helix.input.TiltState;`

Where reading the device's tilt is (Input.tiltState): not asked for, waiting (for the player's tap that grants it, or its first reading), calibrating (waiting for the device to be held steady), reading, refused by the player, or not there to read (a computer, natively).

- `TiltState.Off`: Not asked for: requestTilt starts it.
- `TiltState.Waiting`: Asked for: waiting for the player's next tap or the first reading. A browser shows its prompt at a tap, and after the prompt, Chrome reads nothing until the player taps the page again: a game can say "tap to start" while it waits.
- `TiltState.Calibrating`: Reading, and taking level: tiltX and tiltY read 0 until the player holds the device steady for half a second, which becomes level. It comes at the first reading, after the screen turns, and after calibrateTilt. A game can say "hold steady" while it lasts.
- `TiltState.On`: Reading: tiltX and tiltY follow the device.
- `TiltState.Refused`: The player refused it.
- `TiltState.Unavailable`: Nothing to read yet: no reading came soon after asking (a computer has no motion sensor), or natively. A reading that comes later still turns it On.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Touch

*typedef* in [`src/helix/input/Touch.hx`](../../src/helix/input/Touch.hx), `import helix.input.Touch;`

A finger, in framebuffer pixels like the pointer. Its id stays the same while it is down.

- `y:Float`
- `x:Float`
- `released:Bool`
- `pressed:Bool`
- `id:Int`
- `down:Bool`
