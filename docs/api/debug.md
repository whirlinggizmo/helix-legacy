# helix.debug

[Back to the index](README.md)

## Autopilot

*class* in [`src/helix/debug/Autopilot.hx`](../../src/helix/debug/Autopilot.hx), `import helix.debug.Autopilot;`

Bounded JSON commands produce normal input, a tick at a time; probes (named values) are supplied by the app. A script replays alike on every target when it keeps two rules: - It waits on state, never on time, for anything that isn't the simulation's (a load, a menu, a screen appearing): `wait` on a probe, its limit in seconds (`"seconds"`); tick counts (`"timeout"`, `hold`) only for what the simulation itself does, once a wait has found it running. - The game starts each replayed phase from a known state when it begins: play starting fresh from the seed (a new level), however late it starts; a title screen's motion is dressing, not part of the game. Then a menu, a slow load or a frame's timing can delay a start without the game differing. A `sample` reads the frame's pixels at points and puts them in snapshot's samples under its name, which tools/example.py compares between the browser and native: `{"op": "sample", "name": "lit", "points": [[x, y], ...]}`, the points in the design's units (Screen's), 1 to 64 of them; `"tolerance"`, how far each channel (0 to 255) may differ across targets, 3 when not given; and `"differsFrom"` with `"by"`, an earlier sample's name and an amount, failing the script unless every point differs from the same point there by at least that much in some channel (an effect turned on against it off, so a shader drawing nothing fails); and `"matches"` with `"within"`, an earlier sample's name and an amount, failing it unless every point is within that much of the same point there in every channel (what must look the same either way, as a background with an HDR chain and without). The frame read is the one drawn after the ticks before it: while it waits for that frame to end, awaitingFrame is true and the app runs no tick. A `touch` is fingers on the touch screen, as a drag is the pointer, several at once for a gesture or a second thumb: `{"op": "touch", "ticks": n, "fingers": [{"from": [x, y], "to": [x, y]}, {"from": ..., "to": ..., "start": 5, "end": 15}]}`, 1 to 10 fingers, their ids 1, 2 ... in the order listed. Each lands at from on its start tick (0 when not given), moves a straight line to reach to on its end tick (ticks when not given; start to end within 0 to ticks), and lifts there on the tick after; the command ends once every finger has lifted. Its points are a drag's (the design's units, or a widget's, found again every tick). The fingers are a touch screen's: the first down is the pointer too (a tap clicks), a second lets the pointer go (a pinch clicks nothing). A `drag` is the pointer held down at one point and moved to another: `{"op": "drag", "from": [x, y], "to": [x, y], "ticks": n}`, the points in the design's units (Screen's; as given without a runner, in a test), pressed at from on its first tick, moved a straight line to reach to after n more, and let go there on the tick after. A `type` is text typed on one tick, as a keyboard's characters arrive (dropped, as theirs are, while nothing has asked for text entry: focus a text field first): `{"op": "type", "text": "ff8800"}`. Any point (a sample's, a drag's) may instead be a widget's: `{"target": "background", "part": "hue", "at": [.3, .5]}`, at fractions of the rectangle of the UI's widget named target, or of its part named part (Ui.computePoint lists them: a slider's track, a color picker's square and bars, a scrollbar's thumb, a list's rows ...), 0, 0 its top left and 1, 1 its bottom right, outside it past them. So a script keeps working when padding, gaps or a widget's size move the layout. Each is found where the widget was last drawn when the point is used: a sample's as it asks for its frame; a drag's from as it presses, its to again every tick. One not found (no such widget shown, or no such part now) is waited for, as a click waits, within the command's "seconds" (5 when not given), and fails the script after. A `click` with `"at"` (and `"part"`) presses and lets go of the pointer there instead of using the widget by name. With a program's input bound (under the runner), while it plays, that input (Input) is the script's: a Ui, a pointer looking at the stage and the screens that run themselves (SplashScreen, LoadingScreen, a Transition) play it as they read Input, with nothing handed to them; the program's own input is back once every command has finished.

```haxe
function new(json:String, ?screenshot:Null<String> -> Void, ?press:String -> Bool, ?sample:(points:Array<Array<Float>>, done:Array<Array<Int>> -> Void, failed:String -> Void) -> Void, ?locate:(target:String, part:String, x:Float, y:Float, out:Array<Float>) -> Bool)
var done(default, null):Bool
var failure(default, null):Null<String>
var probeNames(get, never):Array<String>
var tickCount(get, never):Int
var input(get, never):IInput
var seed(default, null):Int
var outcomes(default, null):Array<Dynamic>
var awaitingFrame(default, null):Bool
function advance(probe:String -> Dynamic):IInput
var snapshot(get, never):Dynamic
```

- `new`: Checks a whole script ({version: 1, seed, commands}: press, hold, wait, assert, click, screenshot, sample, drag, touch, type; at most 128) and throws on anything invalid or unknown. A wait has one limit: "timeout" in ticks, or "seconds" of the clock. A click uses a UI's widget by name, waiting (as a web suite's actions do) until press, the app's (Ui.press, say), finds it shown and usable, within its limit; without press it fails; one with "at" (and "part") clicks the pointer at that point of the widget instead, waiting until it's found. A screenshot command calls screenshot with its name (null for the default name; Screenshots.take, say), or does nothing without one. A sample calls sample with its points (Screenshots.sample, say), which calls done with each point's color as [r, g, b, a], 0 to 255, once the frame has ended, or failed; without sample it fails. A point naming a widget asks locate (Ui.computePoint, say) for the framebuffer pixel at its fractions of the widget's or its part's rectangle (written to out; as given without a runner, in a test), waiting while it answers false; without locate it fails.
- `done`: Whether every command has finished.
- `failure`: Why the script failed (an assertion, a wait timing out, an invalid script), or null while it hasn't. A failure is published at once (TestHarness.publish: {failed, autopilot: snapshot}), so the check that launched the program reports it without waiting out its limit, and thrown, as before.
- `probeNames`: The probes the script names (its waits' and asserts'), each once, in the script's order: what a game's final state is published as.
- `tickCount`: Ticks the commands have run so far.
- `input`: The input the script plays, the one advance returns: the same object for the whole script, so what reads it (a UI, an Actions map) can be given it before the first tick.
- `seed`: The script's seed, 1 to 2147483647, for the app's random numbers.
- `outcomes`: One record a finished command: its index, op, the tick it finished on and the probe's value.
- `awaitingFrame`: Whether a sample waits for the frame being drawn to end: the input advance returned isn't to be played, and the app runs no tick this frame (its tick loop stops when this is true, as it does when done).
- `advance`: Once a tick: runs commands until one needs this tick, asking probe for named values, and returns the input to play it with. Throws when a wait times out or an assert fails (or probe throws), publishing the failure first (failure); once failed, it throws that again.
- `snapshot`: Progress as a record: completed, failed (failure), ticks, the current command index, the outcomes and the samples (by name: points, colors as [r, g, b, a] and tolerance).

## FpsOverlay

*class* in [`src/helix/debug/FpsOverlay.hx`](../../src/helix/debug/FpsOverlay.hx), `import helix.debug.FpsOverlay;`

The frame rate and the frame's cost, averaged over half a second, as a node (docs/DISPLAY_MODEL.md): put it on the stage where it should show (its top-left at its position, in the stage's units), and update it each frame; it draws its line again when the numbers change.

```haxe
function new(?size:Float = 16., ?color:Int = 0xff7fe07f)
var size:Float
var color:Int
var frameRate(get, never):Float
var frameMs(get, never):Float
function update(dt:Float, cpu:Float):Void
```

- `new`: An overlay showing 0 until half a second of frames has been seen, size tall (16 unless given) in color (0xAARRGGBB, a light green unless given).
- `size`: The glyph height, in the stage's units.
- `color`: Its color, 0xAARRGGBB.
- `frameRate`: Frames a second over the last half second.
- `frameMs`: The frame's average cost in milliseconds over the last half second.
- `update`: dt: the frame's interval; cpu: what the frame cost, in milliseconds (Time.frameCpu).

## Log

*class* in [`src/helix/debug/Log.hx`](../../src/helix/debug/Log.hx), `import helix.debug.Log;`

Writes messages for whoever is developing the game, each with how much it matters and, optionally, a tag saying what it's about: `Log.info("level 3 loaded")`, `Log.warn('no save yet', "saves")`, `Log.debug('ball at $x, $y', "physics")`. A line says where it was written from, as trace does (`Game.hx:42: [physics] ball at 10, 4`). In the browser it goes to the console (console.debug, info, warn and error, so the console's own filter works); natively, debug and info lines to the standard output and warnings and errors to the standard error. trace goes through it too, as Info. What's written is what's at or above `Log.level`, or a tag's own level when it has one (`Log.setTagLevel("physics", Warning)` quiets that tag's debug and info). Log.debug is gone from a release build altogether, so leave it in freely. The engine logs as well, under its own tags ("asset", "audio", "input", "shader", "tiled", "view", "window", "autopilot", "screenshot", "saves").

```haxe
static var level:LogLevel
static function debug(message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void
static function info(message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void
static function warn(message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void
static function error(message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void
static function write(level:LogLevel, message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void
static function isWritten(level:LogLevel, ?tag:String):Bool
static function setTagLevel(tag:String, level:Null<LogLevel>):Void
static function listen(listener:(LogLevel, String) -> Void):Void
static function unlisten(listener:(LogLevel, String) -> Void):Void
```

- `level`: The least a message must matter to be written, unless its tag has a level of its own: Debug in a debug build and the dev loop, Info in a release, to start. Off writes nothing.
- `debug`: Writes message (anything; written as a string) as Debug: detail for finding a fault. Only in a debug build or the dev loop: a release build leaves the call out.
- `info`: Writes message as Info: what happened, worth knowing.
- `warn`: Writes message as Warning: something went wrong and the game carried on.
- `error`: Writes message as Error: something failed.
- `write`: Writes message as level says, when it's let through (isWritten).
- `isWritten`: Whether a message of level under tag (none when null) would be written: at or above the tag's level if it has one, else Log.level. To skip building a costly message that wouldn't be.
- `setTagLevel`: Gives tag a level of its own, in place of Log.level for its messages (Off to silence it), or takes it away with null.
- `listen`: Calls listener with each line written (its level, and the line as written), for an in-game console, an overlay or a test.
- `unlisten`: Stops calling listener.

## LogLevel

*abstract* in [`src/helix/debug/LogLevel.hx`](../../src/helix/debug/LogLevel.hx), `import helix.debug.LogLevel;`

How much a message matters (Log): Log.level and a tag's level let through what's at or above them.

- `LogLevel.Debug`: Detail for finding a fault; written in debug builds and the dev loop, gone from a release build.
- `LogLevel.Info`: What happened, worth knowing.
- `LogLevel.Warning`: Something went wrong and the game carried on: a file that didn't load, a setting the platform refused.
- `LogLevel.Error`: Something failed that the game may not recover from.
- `LogLevel.Off`: As a level to let through: nothing.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## PickOverlay2D

*class* in [`src/helix/debug/PickOverlay2D.hx`](../../src/helix/debug/PickOverlay2D.hx), `import helix.debug.PickOverlay2D;`

What picks test and what drawing culls by, drawn over a 2D tree for finding why a click misses: add it to the tree to look at (on the stage, or in the tree a View2D shows) last, so it's over the rest, at its origin, unturned and unscaled. Each frame it draws every shown node's own box, square to the tree, as computeBounds measures it and drawing culls by it (boundsColor), and for each node a pick can hit, what the pick tests (hitColor): its hitArea, or its kind's own shape (a sprite's or text's rectangle, a circle's disc or ring, a line's or outline's stroke, a polygon's inside, a drawing's extent and texts). Nothing is drawn for what a pick doesn't test (a group without a hit area, an emitter; a view picks inside the tree it shows, which an overlay of its own shows). The flags hold as for a pick: a hidden node and everything under it are left out, an unpickable one's gets no pick shape. A clipping node's clip, which also limits a pick, isn't drawn. Never picked.

```haxe
function new(?hitColor:Int = 0xff33ff66, ?boundsColor:Int = 0xffffa020, ?lineWidth:Float = 1.)
var pickShapes:Bool
var drawBounds:Bool
var hitColor:Int
var boundsColor:Int
var lineWidth:Float
```

- `new`: An overlay drawing hit shapes in hitColor (green unless given) and boxes in boundsColor (orange unless given), lineWidth wide (1 unless given), in the tree's units.
- `pickShapes`: Whether it draws what a pick tests on each node it can hit. On to start.
- `drawBounds`: Whether it draws each shown node's own box, square to the tree (an AABB: what drawing culls by). On to start.
- `hitColor`: The color of what each node is hit by, 0xAARRGGBB.
- `boundsColor`: The color of each node's box, 0xAARRGGBB.
- `lineWidth`: How wide its lines are, in the tree's units.

## PickOverlay3D

*class* in [`src/helix/debug/PickOverlay3D.hx`](../../src/helix/debug/PickOverlay3D.hx), `import helix.debug.PickOverlay3D;`

What picks test and what drawing culls by, drawn in a 3D tree for finding why a click misses: add it to the tree to look at (the one a View3D shows) at its origin, unturned and unscaled. Each frame it draws every shown node's box, square to the world, as computeBounds measures it and drawing culls by it (boundsColor), and for each node a pick can hit, what the pick tests (hitColor): its hitArea, a sprite's or text's quad as it faces the camera now, a model's triangles as posed (but for parts too see-through to hit). Nothing is drawn for what a pick doesn't test. The flags hold as for a pick: a hidden node and everything under it are left out, an unpickable one's gets no pick shape. Depth-tested as any drawing, so what's inside a model is hidden by it. Never picked.

```haxe
function new(?hitColor:Int = 0xff33ff66, ?boundsColor:Int = 0xffffa020)
var pickShapes:Bool
var drawBounds:Bool
var hitColor:Int
var boundsColor:Int
```

- `new`: An overlay drawing hit shapes in hitColor (green unless given) and boxes in boundsColor (orange unless given).
- `pickShapes`: Whether it draws what a pick tests on each node it can hit. On to start.
- `drawBounds`: Whether it draws each shown node's own box, square to the world (an AABB: Node3D.computeBounds's, what drawing culls by). On to start.
- `hitColor`: The color of what each node is hit by, 0xAARRGGBB.
- `boundsColor`: The color of each node's box, 0xAARRGGBB.

## TestHarness

*class* in [`src/helix/debug/TestHarness.hx`](../../src/helix/debug/TestHarness.hx), `import helix.debug.TestHarness;`

Where results go for the check that launched the program (an autopilot's final state, a test's checks). The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from ITestHarness's public members with their doc comments.

```haxe
static function publish(value:Dynamic):Void
```

- `publish`: Hands value (JSON-able) to the check: window.result in a browser; natively a JSON line on stdout, also written to the file HELIX_RESULT names.
