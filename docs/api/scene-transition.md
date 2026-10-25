# helix.scene.transition

[Back to the index](README.md)

## Closing

*class* in [`src/helix/scene/transition/Closing.hx`](../../src/helix/scene/transition/Closing.hx), `import helix.scene.transition.Closing;`

A hole in the cover closing on a point until all is covered at the middle, where what's shown swaps, then opening from it: the hole round (Iris) or a diamond (Diamond). The point is the stage's, read as it draws, so it can follow something moving; the middle of the visible area unless set.

```haxe
var color:Int
var pointX:Float
var pointY:Float
function setPoint(x:Float, y:Float):Void
function draw(cover:Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void
```

- `color`: Its color, 0xAARRGGBB: set it any time.
- `pointX`: The point it closes on and opens from, in the stage's units; NaN (the default) for the middle of the visible area.
- `pointY`: The point's y; NaN for the middle.
- `setPoint`: Sets the point it closes on and opens from, in the stage's units.

## Diamond

*class* in [`src/helix/scene/transition/Diamond.hx`](../../src/helix/scene/transition/Diamond.hx), `import helix.scene.transition.Diamond;`

A diamond-shaped hole closing on a point and opening from it (Closing).

```haxe
function new(?seconds:Float = .5, ?color:Int = 0xff000000)
```

- `new`: A diamond over seconds (half a second unless given) in color (black unless given, 0xAARRGGBB), on the middle of the visible area until setPoint.

## Fade

*class* in [`src/helix/scene/transition/Fade.hx`](../../src/helix/scene/transition/Fade.hx), `import helix.scene.transition.Fade;`

A fade to a color and back: covered at the middle, where what's shown swaps.

```haxe
function new(?seconds:Float = .5, ?color:Int = 0xff000000)
var color:Int
function draw(cover:Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void
```

- `new`: A fade over seconds (half a second unless given) through color (black unless given, 0xAARRGGBB, its alpha the cover at the middle).
- `color`: Its color, 0xAARRGGBB: set it any time.

## Iris

*class* in [`src/helix/scene/transition/Iris.hx`](../../src/helix/scene/transition/Iris.hx), `import helix.scene.transition.Iris;`

A round hole closing on a point and opening from it (Closing).

```haxe
function new(?seconds:Float = .5, ?color:Int = 0xff000000)
```

- `new`: An iris over seconds (half a second unless given) in color (black unless given, 0xAARRGGBB), on the middle of the visible area until setPoint.

## Noise

*class* in [`src/helix/scene/transition/Noise.hx`](../../src/helix/scene/transition/Noise.hx), `import helix.scene.transition.Noise;`

The screen covered square by square in a scattered order, then uncovered the same way in another: a dissolve in blocks.

```haxe
function new(?seconds:Float = .5, ?cell:Float = 24., ?color:Int = 0xff000000)
var cell(default, null):Float
var color(default, null):Int
function draw(cover:Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void
```

- `new`: Squares of cell stage units (24 unless given, at least 2) over seconds (half a second unless given) in color (black unless given, 0xAARRGGBB).
- `cell`: Each square's size, the stage's units.
- `color`: Its color.

## Slide

*class* in [`src/helix/scene/transition/Slide.hx`](../../src/helix/scene/transition/Slide.hx), `import helix.scene.transition.Slide;`

A cover sliding across: in from one side until it covers everything at the middle, where what's shown swaps, then on out across the far side, or back out the way it came (back). Its edge is square to the way it moves, so a diagonal one sweeps corner to corner.

```haxe
function new(?seconds:Float = .5, ?direction:SlideDirection = Left, ?back:Bool = false, ?color:Int = 0xff000000)
var direction(default, null):SlideDirection
var back(default, null):Bool
var color(default, null):Int
function draw(cover:Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void
```

- `new`: A slide over seconds (half a second unless given) moving direction (Left unless given), back out the way it came when back, in color (black unless given, 0xAARRGGBB).
- `direction`: Which way it moves.
- `back`: Whether it leaves the way it came in (true) or goes on across (false).
- `color`: Its color.

## SlideDirection

*enum* in [`src/helix/scene/transition/SlideDirection.hx`](../../src/helix/scene/transition/SlideDirection.hx), `import helix.scene.transition.SlideDirection;`

Which way a Slide's cover moves across the screen: it comes in from the opposite side (Left enters from the right).

- `Left`
- `Right`
- `Up`
- `Down`
- `UpLeft`
- `UpRight`
- `DownLeft`
- `DownRight`

## Transition

*class* in [`src/helix/scene/transition/Transition.hx`](../../src/helix/scene/transition/Transition.hx), `import helix.scene.transition.Transition;`

How one screen gives way to the next on the stage (docs/DISPLAY_MODEL.md): a cover drawn over everything. Run whole (run, swap), it covers for coverSeconds, swaps what's shown at the middle, stays covered for hold seconds and uncovers for uncoverSeconds, after a delay when given, each half along its own ease. Or in halves: cover covers and stays covered (game over, a load under the cover) until uncover is called, and uncover alone, from covered, is a fade in from black at the start. It runs itself on the frames' time, not the game's clock, so a paused game still transitions to its menu; quick (the run option quick=1) skips it, swapping at once. The kinds made (Fade, Slide, Iris, Diamond, Noise) each draw their cover; a game's own extends this and draws anything into its cover by progress (draw).

```haxe
function new(seconds:Float)
var coverSeconds(default, set):Float
var uncoverSeconds(default, set):Float
var seconds(get, never):Float
var running(default, null):Bool
var covered(get, never):Bool
var progress(default, null):Float
var delay(default, set):Float
var hold(default, set):Float
var coverEase:Float -> Float
var uncoverEase:Float -> Float
function draw(cover:Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void
function cover(?done:() -> Void):Bool
function uncover(?done:() -> Void):Bool
function run(atMiddle:() -> Void, ?done:() -> Void):Bool
function swap(from:Null<Node2D>, to:Null<Node2D>, ?done:() -> Void):Bool
```

- `new`: A transition taking seconds, half covering and half uncovering (coverSeconds, uncoverSeconds). Throws for 0 or less.
- `coverSeconds`: Seconds it takes to cover, from its start (after its delay) to its middle, where what's shown swaps: half the seconds it was made with to start; 0 for less (covered at once). A quick close and a slow open: coverSeconds .2, uncoverSeconds .8.
- `uncoverSeconds`: Seconds it takes to uncover, from the end of its hold to its end: half the seconds it was made with to start; 0 for less.
- `seconds`: How long it covers and uncovers, its delay and hold aside: coverSeconds and uncoverSeconds together.
- `running`: Whether it's running now: from run or cover through its delay and covering, while covered, and through its uncovering.
- `covered`: Whether it's fully covered now: after cover until uncover (or through run's hold).
- `progress`: Where it is, as last drawn: 0 to .5 covering, .5 covered (at the middle and through its hold), .5 to 1 uncovering, each half after its ease; 0 before it starts (and through its delay), 1 once done.
- `delay`: Seconds after run before it starts covering, nothing drawn meanwhile: 0 to start (and for less).
- `hold`: Seconds it stays fully covered at its middle, after the swap and before it uncovers: 0 to start (and for less).
- `coverEase`: How its first half goes, an easing from time to progress, 0 to 1 (helix.tween.Ease's, called from a lambda so a hot reload reaches it: t -> Ease.quadIn(t) starts slow): linear to start. What it gives is held to 0..1, so a curve past the ends (back, elastic) can't overshoot the cover.
- `uncoverEase`: How its second half goes, as coverEase: linear to start.
- `draw`: Draws the cover at progress 0 to 1 (the swap at .5) into cover (cleared before each call, over everything on the stage, in the stage's units), the visible area x, y, width x height. Nothing by default.
- `cover`: Covers the stage after its delay, over coverSeconds, and stays covered until uncover is called: done (when given) once covered (put the next screen on the stage there, or start a load under the cover). False, doing nothing, while it's running already.
- `uncover`: Uncovers the stage over uncoverSeconds, done (when given) at its end: from covered (after cover), or, not running, from fully covered at once (a fade in from black as a game starts). While it's still covering, it uncovers once covered. False, doing nothing, while it's uncovering already.
- `run`: Runs it over the stage, after its delay: atMiddle at its middle (swap what's shown there), held covered for its hold, done (when given) at its end. False, running nothing, while it's running already.
- `swap`: Runs it, taking from off the stage and putting to on it at its middle (either null for none), done (when given) at its end. False, running nothing, while it's running already.
