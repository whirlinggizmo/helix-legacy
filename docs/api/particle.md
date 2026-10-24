# helix.particle

[Back to the index](README.md)

## Emitter

*class* in [`src/helix/particle/Emitter.hx`](../../src/helix/particle/Emitter.hx), `import helix.particle.Emitter;`

A particle emitter: many particles from one texture, each decided when it's born (where, how fast, how long it lives, how big, how it spins, within the ranges set here) and never touched again: the GPU works out where it is from its age (gravity and drag move it; its size and color follow their curves over its life). Spawning is all the CPU does, so thousands cost about what spawning them does. A node places it on a stage (a Particles3D, or Node2D.emitter), which advances it by the stage's clock each draw; particles stay where they were born when it moves (trails), face the camera, and aren't sorted among themselves. Its random numbers are its own (seed): the same seed and settings give the same particles. Colors are 0xAARRGGBB, sRGB values, as sprites' are.

```haxe
function new(texture:Null<Texture2D>, ?maxParticles:Int = 1024, ?flat:Bool = false)
static function getDot(?gpu:IGraphics):Texture2D
var texture:Null<Texture2D>
var maxParticles(get, never):Int
var regionX(default, null):Float
var regionY(default, null):Float
var regionWidth(default, null):Float
var regionHeight(default, null):Float
function setRegion(x:Float, y:Float, width:Float, height:Float):Void
var frameColumns(get, never):Int
var frameRows(get, never):Int
var frameCount(default, null):Int
var framesPerSecond(default, null):Float
function setFrames(columns:Int, rows:Int, ?frameCount:Int = 0, ?perSecond:Float = 0.):Bool
var rate(default, set):Float
var emitting:Bool
var minLife(get, never):Float
var maxLife(get, never):Float
function setLife(min:Float, max:Float):Bool
var spawnHalfX(get, never):Float
var spawnHalfY(get, never):Float
var spawnHalfZ(get, never):Float
function setSpawnBox(halfX:Float, halfY:Float, halfZ:Float):Void
var spawnRadius(get, never):Float
function setSpawnSphere(radius:Float):Bool
var velocityX(get, never):Float
var velocityY(get, never):Float
var velocityZ(get, never):Float
var spread(default, null):Float
var speedVariance(default, null):Float
function setVelocity(x:Float, y:Float, z:Float, ?spread:Float = 0., ?variance:Float = 0.):Bool
var gravityX(default, null):Float
var gravityY(default, null):Float
var gravityZ(default, null):Float
function setGravity(x:Float, y:Float, z:Float):Void
var drag(default, set):Float
var inheritVelocity(get, set):Float
var sizeVariance(default, null):Float
var sizeKeyCount(get, never):Int
function getSizeKeyTime(index:Int):Float
function getSizeKeySize(index:Int):Float
function setSize(start:Float, end:Float, ?variance:Float = 0.):Bool
function clearSizeKeys():Void
function addSizeKey(t:Float, size:Float):Bool
var colorKeyCount(get, never):Int
function getColorKeyTime(index:Int):Float
function getColorKeyColor(index:Int):Int
function setColor(start:Int, end:Int):Void
function clearColorKeys():Void
function addColorKey(t:Float, color:Int):Bool
var paletteColorCount(get, never):Int
function getPaletteColor(index:Int):Int
function addPaletteColor(color:Int):Bool
function clearPalette():Void
var minSpin(get, never):Float
var maxSpin(get, never):Float
function setSpin(min:Float, max:Float):Bool
var stretch(default, set):Float
var alphaCutoff(get, never):Float
function setAlphaMode(mode:AlphaMode, ?cutoff:Float = .5):Bool
var alphaMode(default, null):AlphaMode
var seed(get, set):Int
var particleCount(get, never):Int
function clear():Void
var spent(get, never):Bool
function burst(count:Int):Bool
function prewarm(seconds:Float):Void
function jump(x:Float, y:Float, z:Float):Void
function advance(dt:Float, x:Float, y:Float, z:Float):Void
function writeRecords(out:haxe.io.Bytes, at:Int):Int
var drawable(get, never):Bool
function writeUniforms(out:haxe.io.Bytes, viewProjection:Mat4, axisX:Array<Float>, axisY:Array<Float>):Void
```

- `new`: An emitter of particles drawn from texture (null for none yet: it draws nothing), at most maxParticles alive at once (newer replace the oldest; clamped to 1..65536), flat for a 2D stage (its particles in the x-y plane, a sphere a circle). By default: no steady rate (bursts only), a life of 1 second, born at a point, moving up at 1 unit a second, size 1, white, added.
- `getDot`: The built-in particle: a soft round dot, white (tinted by the particles' colors), 32 texels a side, its alpha falling smoothly from its center to its edge, sampled linear. Made on gpu (the program's, Graphics, when not given) the first time it's asked for there, kept for the program and freed at its end. The presets draw it (Particles2D.explosion and the others).
- `texture`: Its texture, or null (it draws nothing).
- `maxParticles`: The most particles alive at once.
- `regionX`: The region's left, in texels.
- `regionY`: The region's top, in texels.
- `regionWidth`: The region's width in texels (0 or less: the whole texture).
- `regionHeight`: The region's height in texels (0 or less: the whole texture).
- `setRegion`: The region of the texture each particle shows, in texels from its top-left (an atlas cell); a width or height of 0 or less (the default) is the whole texture.
- `frameColumns`: The flipbook's columns (1: none).
- `frameRows`: The flipbook's rows (1: none).
- `frameCount`: The flipbook frames used.
- `framesPerSecond`: The flipbook frames a second (0: once over a life).
- `setFrames`: A flipbook: the region split into columns x rows frames (left to right, top to bottom), of which the first frameCount are used (0 or less, or more than there are: all). With perSecond 0 each particle plays them once over its life (puffs, explosions); above 0 it loops at that rate from a random frame (flames). False for columns or rows below 1.
- `rate`: Its steady rate, particles a second (0: bursts only). 0 or more (under 0, or NaN, is 0).
- `emitting`: Whether the steady rate runs; stopped, the particles alive finish their lives.
- `minLife`: The shortest life, seconds.
- `maxLife`: The longest life, seconds.
- `setLife`: Each particle's life, seconds, between min and max. False unless 0 < min <= max.
- `spawnHalfX`: The spawn box's half size along x (0 with a sphere set).
- `spawnHalfY`: The spawn box's half size along y.
- `spawnHalfZ`: The spawn box's half size along z.
- `setSpawnBox`: Born anywhere in a box of these half sizes around its position (a point by default); a half size's sign is ignored (the same box).
- `spawnRadius`: The spawn sphere's radius (0: born in the box).
- `setSpawnSphere`: Born evenly within a sphere (a circle, flat) of radius around its position. False below 0.
- `velocityX`: The velocity's x, units a second.
- `velocityY`: The velocity's y, units a second.
- `velocityZ`: The velocity's z, units a second (0 when flat).
- `spread`: How far a particle may turn off the velocity, radians.
- `speedVariance`: How much faster or slower a particle may be, 0..1 of the speed.
- `setVelocity`: Moving along x, y, z at its length's speed, turned up to spread radians off it (a cone; flat, a fan; its sign is ignored, the same cone), faster or slower by up to variance (0..1) of it. False, changing nothing, for a variance outside 0..1.
- `gravityX`: Gravity's x, units a second squared.
- `gravityY`: Gravity's y, units a second squared.
- `gravityZ`: Gravity's z, units a second squared (0 when flat).
- `setGravity`: An acceleration on every particle, units a second squared (none by default).
- `drag`: Slowing in proportion to speed, a second (1 loses about 63% of the speed in a second, less gravity's pull; gravity / drag is how fast they end up falling). 0 or more (under 0, or NaN, is 0).
- `inheritVelocity`: The fraction of its own movement (where its node went over the last advance) particles take at birth: 1 carries them along with it.
- `sizeVariance`: How much each particle's size may be scaled, 0..1.
- `sizeKeyCount`: The size keys.
- `getSizeKeyTime`: Size key index's time, 0..1 of a life (0 for an index out of range).
- `getSizeKeySize`: Size key index's size, world units (0 for an index out of range).
- `setSize`: Size over life, world units: start at birth to end at death, each particle's scaled by up to variance (0..1). Replaces the size keys. False, changing nothing, for a variance outside 0..1.
- `clearSizeKeys`: Clears the size keys (a curve without keys draws nothing until one is added).
- `addSizeKey`: Adds a size key at t (0..1 of a life), in order: between keys the size moves in a line; before the first and after the last it holds. False past 8 keys, or for a t before the last key's or outside 0..1.
- `colorKeyCount`: The color keys.
- `getColorKeyTime`: Color key index's time, 0..1 of a life (0 for an index out of range).
- `getColorKeyColor`: Color key index's color, 0xAARRGGBB (0 for an index out of range).
- `setColor`: Color over life (alpha included, so a fade): start at birth to end at death. Replaces the color keys.
- `clearColorKeys`: Clears the color keys.
- `addColorKey`: Adds a color key at t, as addSizeKey.
- `paletteColorCount`: The palette colors.
- `getPaletteColor`: Palette color index, 0xAARRGGBB (0 for an index out of range).
- `addPaletteColor`: Adds a palette color (at most 8): each particle picks one at birth, tinting its color over life (confetti from one emitter). False past 8.
- `clearPalette`: Clears the palette: no tint.
- `minSpin`: The slowest spin, radians a second.
- `maxSpin`: The fastest spin, radians a second.
- `setSpin`: Spin, radians a second between min and max (positive clockwise on screen), from a random angle. None by default. False, changing nothing, unless min <= max.
- `stretch`: Stretched along the motion (sparks, rain), in seconds of movement: each particle's texture points its top along its velocity across the screen, as long as the distance it moves in that time (plus its size); stretched ones don't spin. 0 (the default) is off; 0 or more (under 0, or NaN, is 0).
- `alphaCutoff`: A Mask's alpha cutoff, 0..1.
- `setAlphaMode`: How it uses its texels' alpha (Add by default: glows, sparks, fire), and a Mask's cutoff. False for a cutoff outside 0..1.
- `alphaMode`: How it uses its texels' alpha.
- `seed`: Where its random numbers start (the seed it was last given, or its own, unseeded): the same seed and settings give the same particles. 0 is taken as 1 (the generator needs a seed other than 0).
- `particleCount`: Particles that may still be alive.
- `clear`: All of them gone.
- `spent`: Whether it's spent: no steady rate running, no burst or prewarm waiting for its first place, and no particle alive. A one-shot (a preset's explosion, say) is spent once its burst has died out: its node can come off the stage.
- `burst`: Bursts count particles at once, where it is now; before it's first placed (a node made and burst before a draw has placed it), where it first is. False below 0.
- `prewarm`: Starts over as if the steady rate had run for seconds: those it would have made and still alive now are made where it is; before it's first placed, where it first is.
- `jump`: Puts it at x, y, z without a move: nothing spawns along the way, and particles inherit no velocity from it.
- `advance`: Advances its clock by dt seconds, it being at x, y, z now (its node's world position): the steady rate's particles due are born along the way it moved, and the dead are let go. A stage calls this each draw.
- `writeRecords`: Copies the particles that may still be alive, oldest first, into out at byte at (48 bytes each); how many.
- `drawable`: Whether it draws: a texture, particles alive, and a size and color key each.
- `writeUniforms`: Writes its draw's uniforms (the particle program's block) into out: viewProjection, the quad's axes before spin (3D: the camera's right and up; 2D: across and up the screen), and its settings, its clock now.

## ParticlePreset

*abstract* in [`src/helix/particle/ParticlePreset.hx`](../../src/helix/particle/ParticlePreset.hx), `import helix.particle.ParticlePreset;`

The particle presets' recipes, which Particles2D's and Particles3D's factories (explosion, smokePuff, sparks, dust, fire, smoke, rain, snow, confetti) make their emitters from: each in units of size (about how big the effect is, in its space's units: pixels on a 2D stage, world units in 3D), down being the sign of its space's downward y (+1 on a 2D stage, where y grows downward; -1 in 3D, +y up), drawn with the built-in dot (Emitter.getDot). A one-shot (explosion, smoke puff, sparks, dust, confetti) bursts once, where its node first is; the others run steadily. Each is an ordinary Emitter: change what doesn't fit.

- `ParticlePreset.Explosion`: A burst of light outward, fading from white-yellow to red: a hit, a pop, a small explosion. One-shot.
- `ParticlePreset.SmokePuff`: A soft gray puff, spreading and rising a little as it fades: a landing, a vanish, a smoke grenade. One-shot.
- `ParticlePreset.Sparks`: Hot sparks thrown up and out, streaked along their motion and falling: a hit on metal, a grinder. One-shot.
- `ParticlePreset.Dust`: A low, wide kick of dust that settles: footsteps, a landing, a skid. One-shot.
- `ParticlePreset.Fire`: A steady flame, rising and fading from yellow to red: a torch, a campfire.
- `ParticlePreset.Smoke`: A steady column of gray smoke, rising and spreading: a chimney, a wreck.
- `ParticlePreset.Rain`: Steady rain over a width of size, streaked along its fall, falling size units below the node.
- `ParticlePreset.Snow`: Steady snow over a width of size, drifting down size units below the node.
- `ParticlePreset.Confetti`: Paper of five colors thrown up, spinning and falling: a win, a level cleared. One-shot.

```haxe
function make(size:Float, down:Float, flat:Bool):Emitter
function toString():String
```

- `make`: An emitter of this preset, size big, for a space whose y goes down by the sign of down, flat for a 2D stage.
- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.
