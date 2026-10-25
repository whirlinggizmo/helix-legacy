# helix.math

[Back to the index](README.md)

## Bounds2D

*class* in [`src/helix/math/Bounds2D.hx`](../../src/helix/math/Bounds2D.hx), `import helix.math.Bounds2D;`

An axis-aligned box in 2D, its least and most on each axis: a 2D node's and the like (Node2D.computeBounds), a trigger's region, a camera's limits. Empty when made (its least past its most), so expanding it by a first point makes that point; x, y in whatever space its maker says. Its 2D is its dimensions, as a Texture2D's is, not the display kind (docs/CONVENTIONS.md).

```haxe
function new()
var minX:Float
var maxX:Float
var minY:Float
var maxY:Float
function set(minX:Float, minY:Float, maxX:Float, maxY:Float):Bounds2D
function clear():Bounds2D
function copyFrom(other:Bounds2D):Bounds2D
var isEmpty(get, never):Bool
var width(get, never):Float
var height(get, never):Float
var centerX(get, never):Float
var centerY(get, never):Float
function expand(x:Float, y:Float):Bounds2D
function union(other:Bounds2D):Bounds2D
function contains(x:Float, y:Float):Bool
function intersects(other:Bounds2D):Bool
```

- `new`: An empty box.
- `minX`: Its least x; infinity while empty.
- `maxX`: Its most x; minus infinity while empty.
- `minY`: Its least y; infinity while empty.
- `maxY`: Its most y; minus infinity while empty.
- `set`: Sets it to minX, minY to maxX, maxY; returns it.
- `clear`: Empties it; returns it.
- `copyFrom`: Sets it to other's; returns it.
- `isEmpty`: Whether it holds nothing: its least past its most on an axis (as made, or cleared).
- `width`: Its width, maxX - minX; 0 while empty.
- `height`: Its height, maxY - minY; 0 while empty.
- `centerX`: Its center's x; NaN while empty.
- `centerY`: Its center's y; NaN while empty.
- `expand`: Grows it to hold the point x, y; returns it.
- `union`: Grows it to hold other too (an empty other changes nothing); returns it.
- `contains`: Whether the point x, y is in it, its faces included.
- `intersects`: Whether it and other overlap, touching faces included; never for an empty one.

## Bounds3D

*class* in [`src/helix/math/Bounds3D.hx`](../../src/helix/math/Bounds3D.hx), `import helix.math.Bounds3D;`

An axis-aligned box in 3D, its least and most on each axis: a 3D node's and the like (Node3D.computeBounds), a trigger's region, a camera's limits. Empty when made (its least past its most), so expanding it by a first point makes that point; x, y, z in whatever space its maker says. Its 3D is its dimensions, as a Texture2D's is, not the display kind (docs/CONVENTIONS.md).

```haxe
function new()
var minX:Float
var maxX:Float
var minY:Float
var maxY:Float
var minZ:Float
var maxZ:Float
function set(minX:Float, minY:Float, minZ:Float, maxX:Float, maxY:Float, maxZ:Float):Bounds3D
function clear():Bounds3D
function copyFrom(other:Bounds3D):Bounds3D
var isEmpty(get, never):Bool
var width(get, never):Float
var height(get, never):Float
var depth(get, never):Float
var centerX(get, never):Float
var centerY(get, never):Float
var centerZ(get, never):Float
function expand(x:Float, y:Float, z:Float):Bounds3D
function union(other:Bounds3D):Bounds3D
function contains(x:Float, y:Float, z:Float):Bool
function intersects(other:Bounds3D):Bool
```

- `new`: An empty box.
- `minX`: Its least x; infinity while empty.
- `maxX`: Its most x; minus infinity while empty.
- `minY`: Its least y; infinity while empty.
- `maxY`: Its most y; minus infinity while empty.
- `minZ`: Its least z; infinity while empty.
- `maxZ`: Its most z; minus infinity while empty.
- `set`: Sets it to minX, minY, minZ to maxX, maxY, maxZ; returns it.
- `clear`: Empties it; returns it.
- `copyFrom`: Sets it to other's; returns it.
- `isEmpty`: Whether it holds nothing: its least past its most on an axis (as made, or cleared).
- `width`: Its width, maxX - minX; 0 while empty.
- `height`: Its height, maxY - minY; 0 while empty.
- `depth`: Its depth, maxZ - minZ; 0 while empty.
- `centerX`: Its center's x; NaN while empty.
- `centerY`: Its center's y; NaN while empty.
- `centerZ`: Its center's z; NaN while empty.
- `expand`: Grows it to hold the point x, y, z; returns it.
- `union`: Grows it to hold other too (an empty other changes nothing); returns it.
- `contains`: Whether the point x, y, z is in it, its faces included.
- `intersects`: Whether it and other overlap, touching faces included; never for an empty one.

## Curve

*class* in [`src/helix/math/Curve.hx`](../../src/helix/math/Curve.hx), `import helix.math.Curve;`

A curve through or near points in 2D or 3D (a camera rail, a patrol path, a projectile's arc), asked where it is at t from 0 to 1 along its whole length, which way it heads there, how long it is, and the t at a distance along it, so something moves along it at a steady speed. Kinds: through its points (Catmull-Rom, centripetal: no loops or kinks between unevenly spaced points), by control points (cubic Bézier, a curve from each four), or straight between points (a polyline); open, or closed back to the start. Points are flat (x, y or x, y, z, as the dimensions say), as HeliX passes positions; a curve's points are fixed once made.

```haxe
static function through(points:Array<Float>, ?dimensions:Int = 2, ?closed:Bool = false):Curve
static function bezier(points:Array<Float>, ?dimensions:Int = 2):Curve
static function polyline(points:Array<Float>, ?dimensions:Int = 2, ?closed:Bool = false):Curve
var kind(default, null):CurveKind
var dimensions(default, null):Int
var closed(default, null):Bool
var pointCount(get, never):Int
function getPoint(index:Int, axis:Int):Float
function getX(t:Float):Float
function getY(t:Float):Float
function getZ(t:Float):Float
function evaluate(t:Float, out:Array<Float>):Array<Float>
function tangent(t:Float, out:Array<Float>):Array<Float>
var length(get, never):Float
function getParameterAtDistance(distance:Float):Float
```

- `through`: A curve through every point in order (Catmull-Rom, centripetal), closed back to the first when closed. Throws for fewer than 2 points or a count that doesn't divide by dimensions.
- `bezier`: Cubic Bézier pieces: the first point, then three for each piece (two control points and the piece's end), the pieces joined. Throws for another count.
- `polyline`: Straight from point to point, closed back to the first when closed. Throws for fewer than 2 points.
- `kind`: Its kind.
- `dimensions`: 2 or 3.
- `closed`: Whether it comes back to its start.
- `pointCount`: How many points it was made with.
- `getPoint`: Point index's coordinate axis (0 x, 1 y, 2 z); 0 past them.
- `getX`: X at t, 0 to 1 along the whole curve (held to it; around it when closed).
- `getY`: Y at t.
- `getZ`: Z at t; 0 in 2D.
- `evaluate`: Where it is at t, all axes into out (x, y and z in 3D), which it returns.
- `tangent`: Which way it heads at t, as a unit vector into out (x, y and z in 3D), which it returns; 0s where it doesn't move.
- `length`: Its length, measured along it (SAMPLES straight pieces a segment).
- `getParameterAtDistance`: The t at distance along it from the start (held to its length; around it when closed), so steps of equal distance move at a steady speed where equal steps of t don't.

## CurveKind

*enum* in [`src/helix/math/CurveKind.hx`](../../src/helix/math/CurveKind.hx), `import helix.math.CurveKind;`

How a curve passes its points.

- `Through`: Through each, smoothly (Catmull-Rom).
- `Bezier`: By cubic Bézier control points.
- `Polyline`: Straight between them.

## Interpolate

*class* in [`src/helix/math/Interpolate.hx`](../../src/helix/math/Interpolate.hx), `import helix.math.Interpolate;`

Interpolation and the small math every game writes again: between two numbers, back to a fraction, clamped, smoothed, the short way round between angles, moved by at most a step, or eased toward a target at a rate that's the same at any frame rate. For drawing and feel: a replayed simulation keeps to integer math or Trig, as Math.exp differs by a bit between targets.

```haxe
static function lerp(a:Float, b:Float, t:Float):Float
static function inverseLerp(a:Float, b:Float, value:Float):Float
static function remap(value:Float, fromA:Float, fromB:Float, toA:Float, toB:Float):Float
static function clamp(value:Float, min:Float, max:Float):Float
static function smoothStep(t:Float):Float
static function wrapAngle(angle:Float):Float
static function lerpAngle(a:Float, b:Float, t:Float):Float
static function moveToward(value:Float, target:Float, step:Float):Float
static function damp(value:Float, target:Float, rate:Float, dt:Float):Float
static function dampAngle(value:Float, target:Float, rate:Float, dt:Float):Float
```

- `lerp`: From a to b by t: a at 0, b at 1, past them past 0 and 1.
- `inverseLerp`: Where value lies from a to b, as t: 0 at a, 1 at b; 0 when a and b are the same.
- `remap`: value's place from fromA to fromB, taken to the same place from toA to toB.
- `clamp`: value held between min and max (swapped when max is less).
- `smoothStep`: t held between 0 and 1, then smoothed: slow at both ends (3t² - 2t³).
- `wrapAngle`: angle in radians brought to -π up to π.
- `lerpAngle`: From angle a to b in radians by t, the short way round.
- `moveToward`: value moved toward target by at most step (a step of 0 or less moves nothing), reaching it exactly.
- `damp`: value eased toward target over dt seconds at rate (the share closed each second, as 1 - e^(-rate dt)): the same approach at any frame rate, never arriving exactly, which moveToward does. A rate of 0 or less leaves value.
- `dampAngle`: As damp, between angles in radians the short way round.

## Point2D

*class* in [`src/helix/math/Point2D.hx`](../../src/helix/math/Point2D.hx), `import helix.math.Point2D;`

A point in 2D, x, y, in whatever space its maker says: what a computation of a point returns (Camera3D.project, Ray3D.pointAt), into one given for reuse. Its 2D is its dimensions, as Bounds2D's is, not the display kind (docs/CONVENTIONS.md).

```haxe
function new(?x:Float = 0., ?y:Float = 0.)
var x:Float
var y:Float
function set(x:Float, y:Float):Point2D
function copyFrom(other:Point2D):Point2D
```

- `new`: The point x, y, 0 for each not given.
- `x`: Its x.
- `y`: Its y.
- `set`: Sets it to x, y; returns it.
- `copyFrom`: Sets it to other's; returns it.

## Point3D

*class* in [`src/helix/math/Point3D.hx`](../../src/helix/math/Point3D.hx), `import helix.math.Point3D;`

A point in 3D, x, y, z, in whatever space its maker says: what a computation of a point returns (Camera3D.project, Ray3D.pointAt), into one given for reuse. Its 3D is its dimensions, as Bounds3D's is, not the display kind (docs/CONVENTIONS.md).

```haxe
function new(?x:Float = 0., ?y:Float = 0., ?z:Float = 0.)
var x:Float
var y:Float
var z:Float
function set(x:Float, y:Float, z:Float):Point3D
function copyFrom(other:Point3D):Point3D
```

- `new`: The point x, y, z, 0 for each not given.
- `x`: Its x.
- `y`: Its y.
- `z`: Its z.
- `set`: Sets it to x, y, z; returns it.
- `copyFrom`: Sets it to other's; returns it.

## Random

*class* in [`src/helix/math/Random.hx`](../../src/helix/math/Random.hx), `import helix.math.Random;`

Random numbers from a seed, the same sequence on every target: xorshift32 in integer math alone, so the interpreter, JS and hxcpp agree bit for bit, as Trig does. A simulation that must replay (an autopilot's seed, a lockstep game) draws from one of these; what only looks random (a particle's spin) may too. A game keeps as many as it has streams: play's, and the title's dressing, so when play starts doesn't matter (Asteroids keeps the title's state).

```haxe
function new(?seed:Int = 12345)
var seed(default, set):Int
var state(default, set):Int
function next():Int
function nextInt(max:Int):Int
function nextFloat():Float
function nextRange(min:Float, max:Float):Float
function nextBool(?chance:Float = .5):Bool
function pick(items:Array<T>):Null<T>
function pickWeighted(weights:Array<Float>):Int
function shuffle(items:Array<T>):Array<T>
```

- `new`: A generator starting from seed (12345 unless given); 0 is taken as 1, as xorshift needs a state other than 0.
- `seed`: The seed the sequence last started from; assigning one starts the sequence again from it (0 is taken as 1).
- `state`: Where the sequence is now (seed is where it started): read and assigned back later, the sequence goes on from there (0 is taken as 1), one generator serving two streams in turn.
- `next`: The next whole number, from 0 to 2147483647.
- `nextInt`: The next whole number from 0 up to but not including max: next() % max, so 0 for a max of 1 or less.
- `nextFloat`: The next number from 0 up to but not including 1, in 24 bits (exact in a float on every target).
- `nextRange`: The next number from min up to but not including max (min when they're equal; swapped when max is less).
- `nextBool`: True with the chance given, 0 to 1 (a half when not given).
- `pick`: One of items, each as likely; null for none.
- `pickWeighted`: The index of one of weights, each as likely as its weight (a weight of 0 or less never); -1 for none or no weight over 0.
- `shuffle`: Shuffles items in place (Fisher and Yates', from the end: each place swapped with one at or before it) and returns them.

## Trig

*class* in [`src/helix/math/Trig.hx`](../../src/helix/math/Trig.hx), `import helix.math.Trig;`

Trigonometry that gives the same bits on every target, for simulations that must play alike in the browser and natively (an autopilot's replay, lockstep, physics). `Math`'s functions don't: V8's and the C library's differ in the last bit for a few percent of angles (`atan2` for about a fifth), and a simulation turns that into a different world. These are built from arithmetic alone (and `Math.sqrt` and `Math.floor`, exact everywhere), each step its own statement, and within a few ulp of `Math`'s. Drawing doesn't need them. Radians; NaN for an infinite or NaN angle, and for `asin` and `acos` past -1..1, as `Math`'s. Any finite angle is reduced exactly: a game's angle that keeps growing (an unwrapped spin, a time used as a phase) stays within a few ulp of `Math`'s however large it gets.

Natively the generated C++ is compiled with `-ffp-contract=off` (GCC and clang): a compiler that fuses a multiply and an add (GCC does on arm64, clang by default) would round differently from a target that can't. MSVC's default, /fp:precise, doesn't fuse them.

```haxe
static function sin(x:Float):Float
static function cos(x:Float):Float
static function tan(x:Float):Float
static function atan2(y:Float, x:Float):Float
static function asin(x:Float):Float
static function acos(x:Float):Float
```

- `sin`: The sine of x.
- `cos`: The cosine of x.
- `tan`: The tangent of x.
- `atan2`: The angle of (x, y) from the +x axis, -pi..pi, as `Math.atan2(y, x)`.
- `asin`: The angle whose sine is x, -pi/2..pi/2.
- `acos`: The angle whose cosine is x, 0..pi.
