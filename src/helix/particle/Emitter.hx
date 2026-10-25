package helix.particle;

import helix.graphics.Color;
import helix.math.Random;
import haxe.io.Bytes;
import helix.texture.Texture2D;
import helix.graphics.AlphaMode;

/** A particle emitter: many particles from one texture, each decided when it's born (where, how fast, how long it lives,
	how big, how it spins, within the ranges set here) and never touched again: the GPU works out where it is from its age (gravity and drag
	move it; its size and color follow their curves over its life). Spawning is all the CPU does, so thousands cost about what spawning them
	does. A node places it on a stage (a Particles3D, or Node2D.emitter), which advances it by the stage's clock each draw; particles stay where
	they were born when it moves (trails), face the camera, and aren't sorted among themselves. Its random numbers are its own (seed): the
	same seed and settings give the same particles. Colors are 0xAARRGGBB, sRGB values, as sprites' are. */
class Emitter {
	static inline var RECORD = 48;
	static inline var MAX_KEYS = 8;
	static inline var REBASE = 4096.;
	// Kept across a hot reload (@:hot), so emitters made after one don't repeat the seeds of those before.
	@:hot static var seeds = 1;

	var columns = 1;
	var rows = 1;
	var owed = 0.;
	var max:Int;
	var lifeMin = 1.;
	var lifeMax = 1.;
	var boxX = 0.;
	var boxY = 0.;
	var boxZ = 0.;
	var sphere = 0.;
	var dirX = 0.;
	var dirY = 1.;
	var dirZ = 0.;
	var inherit = 0.;
	var sizeTimes:Array<Float> = [0, 1];
	var sizeValues:Array<Float> = [1, 1];
	var colorTimes:Array<Float> = [0, 1];
	var colorValues:Array<Int> = [0xffffffff, 0xffffffff];
	var palette:Array<Int> = [];
	var spinMin = 0.;
	var spinMax = 0.;
	var cutoff = .5;
	var random:Random;
	var flat:Bool;
	// The ring of birth records, newest at next - 1; live of them (the newest) may still be alive.
	var ring:Bytes;
	var next = 0;
	var live = 0;
	var time = 0.;
	// Where it was at its last advance, and how fast it moved over it.
	var placed = false;
	var lastX = 0.;
	var lastY = 0.;
	var lastZ = 0.;
	var moveX = 0.;
	var moveY = 0.;
	var moveZ = 0.;
	var jumped = false;
	// Particles a burst asked for before it was first placed, born where it first is.
	var pending = 0;
	// Seconds a prewarm asked for before it was first placed, run where it first is.
	var pendingPrewarm = 0.;

	/** An emitter of particles drawn from texture (null for none yet: it draws nothing), at most maxParticles alive at once (newer replace the oldest; clamped to 1..65536),
		flat for a 2D stage (its particles in the x-y plane, a sphere a circle). By default: no steady rate (bursts only), a life of 1 second,
		born at a point, moving up at 1 unit a second, size 1, white, added. */
	public function new(texture:Null<Texture2D>, maxParticles = 1024, flat = false) {
		this.texture = texture;
		max = maxParticles < 1 ? 1 : maxParticles > 65536 ? 65536 : maxParticles;
		this.flat = flat;
		ring = Bytes.alloc(this.max * RECORD);
		random = new Random(seeds++ * 0x9E3779B1);
	}

	/** Its texture, or null (it draws nothing). */
	public var texture:Null<Texture2D>;

	/** The most particles alive at once. */
	public var maxParticles(get, never):Int;

	function get_maxParticles():Int
		return max;

	/** The region's left, in texels. */
	public var regionX(default, null):Float = 0.;

	/** The region's top, in texels. */
	public var regionY(default, null):Float = 0.;

	/** The region's width in texels (0 or less: the whole texture). */
	public var regionWidth(default, null):Float = 0.;

	/** The region's height in texels (0 or less: the whole texture). */
	public var regionHeight(default, null):Float = 0.;

	/** The region of the texture each particle shows, in texels from its top-left (an atlas cell); a width or height of 0 or less (the default)
		is the whole texture. */
	public function setRegion(x:Float, y:Float, width:Float, height:Float):Void {
		regionX = x;
		regionY = y;
		regionWidth = width;
		regionHeight = height;
	}

	/** The flipbook's columns (1: none). */
	public var frameColumns(get, never):Int;

	function get_frameColumns():Int
		return columns;

	/** The flipbook's rows (1: none). */
	public var frameRows(get, never):Int;

	function get_frameRows():Int
		return rows;

	/** The flipbook frames used. */
	public var frameCount(default, null):Int = 1;

	/** The flipbook frames a second (0: once over a life). */
	public var framesPerSecond(default, null):Float = 0.;

	/** A flipbook: the region split into columns x rows frames (left to right, top to bottom), of which the first frameCount are used (0 or less,
		or more than there are: all). With perSecond 0 each particle plays them once over its life (puffs, explosions); above 0 it loops at that rate from a random frame
		(flames). False for columns or rows below 1. */
	public function setFrames(columns:Int, rows:Int, frameCount = 0, perSecond = 0.):Bool {
		if (columns < 1 || rows < 1 || !(perSecond >= 0))
			return false;
		this.columns = columns;
		this.rows = rows;
		this.frameCount = frameCount <= 0 || frameCount > columns * rows ? columns * rows : frameCount;
		framesPerSecond = perSecond;
		return true;
	}

	/** Its steady rate, particles a second (0: bursts only). 0 or more (under 0, or NaN, is 0). */
	public var rate(default, set):Float = 0.;

	function set_rate(perSecond:Float):Float {
		perSecond = perSecond >= 0 ? perSecond : 0;
		rate = perSecond;
		return perSecond;
	}

	/** Whether the steady rate runs; stopped, the particles alive finish their lives. */
	public var emitting:Bool = true;

	/** The shortest life, seconds. */
	public var minLife(get, never):Float;

	function get_minLife():Float
		return lifeMin;

	/** The longest life, seconds. */
	public var maxLife(get, never):Float;

	function get_maxLife():Float
		return lifeMax;

	/** Each particle's life, seconds, between min and max. False unless 0 < min <= max. */
	public function setLife(min:Float, max:Float):Bool {
		if (!(min > 0 && max >= min))
			return false;
		lifeMin = min;
		lifeMax = max;
		return true;
	}

	/** The spawn box's half size along x (0 with a sphere set). */
	public var spawnHalfX(get, never):Float;

	function get_spawnHalfX():Float
		return boxX;

	/** The spawn box's half size along y. */
	public var spawnHalfY(get, never):Float;

	function get_spawnHalfY():Float
		return boxY;

	/** The spawn box's half size along z. */
	public var spawnHalfZ(get, never):Float;

	function get_spawnHalfZ():Float
		return boxZ;

	/** Born anywhere in a box of these half sizes around its position (a point by default); a half size's sign is ignored (the same box). */
	public function setSpawnBox(halfX:Float, halfY:Float, halfZ:Float):Void {
		boxX = Math.abs(halfX);
		boxY = Math.abs(halfY);
		boxZ = Math.abs(halfZ);
		sphere = 0;
	}

	/** The spawn sphere's radius (0: born in the box). */
	public var spawnRadius(get, never):Float;

	function get_spawnRadius():Float
		return sphere;

	/** Born evenly within a sphere (a circle, flat) of radius around its position. False below 0. */
	public function setSpawnSphere(radius:Float):Bool {
		if (!(radius >= 0))
			return false;
		sphere = radius;
		return true;
	}

	/** The velocity's x, units a second. */
	public var velocityX(get, never):Float;

	function get_velocityX():Float
		return dirX;

	/** The velocity's y, units a second. */
	public var velocityY(get, never):Float;

	function get_velocityY():Float
		return dirY;

	/** The velocity's z, units a second (0 when flat). */
	public var velocityZ(get, never):Float;

	function get_velocityZ():Float
		return dirZ;

	/** How far a particle may turn off the velocity, radians. */
	public var spread(default, null):Float = 0.;

	/** How much faster or slower a particle may be, 0..1 of the speed. */
	public var speedVariance(default, null):Float = 0.;

	/** Moving along x, y, z at its length's speed, turned up to spread radians off it (a cone; flat, a fan; its sign is ignored, the same cone),
		faster or slower by up to variance (0..1) of it. False, changing nothing, for a variance outside 0..1. */
	public function setVelocity(x:Float, y:Float, z:Float, spread = 0., variance = 0.):Bool {
		if (!(variance >= 0 && variance <= 1))
			return false;
		dirX = x;
		dirY = y;
		dirZ = flat ? 0 : z;
		this.spread = Math.abs(spread);
		speedVariance = variance;
		return true;
	}

	/** Gravity's x, units a second squared. */
	public var gravityX(default, null):Float = 0.;

	/** Gravity's y, units a second squared. */
	public var gravityY(default, null):Float = 0.;

	/** Gravity's z, units a second squared (0 when flat). */
	public var gravityZ(default, null):Float = 0.;

	/** An acceleration on every particle, units a second squared (none by default). */
	public function setGravity(x:Float, y:Float, z:Float):Void {
		gravityX = x;
		gravityY = y;
		gravityZ = flat ? 0 : z;
	}

	/** Slowing in proportion to speed, a second (1 loses about 63% of the speed in a second, less gravity's pull; gravity / drag is how
		fast they end up falling). 0 or more (under 0, or NaN, is 0). */
	public var drag(default, set):Float = 0.;

	function set_drag(perSecond:Float):Float {
		perSecond = perSecond >= 0 ? perSecond : 0;
		drag = perSecond;
		return perSecond;
	}

	/** The fraction of its own movement (where its node went over the last advance) particles take at birth: 1 carries them along with it. */
	public var inheritVelocity(get, set):Float;

	function get_inheritVelocity():Float
		return inherit;

	function set_inheritVelocity(fraction:Float):Float {
		inherit = fraction;
		return fraction;
	}

	/** How much each particle's size may be scaled, 0..1. */
	public var sizeVariance(default, null):Float = 0.;

	/** The size keys. */
	public var sizeKeyCount(get, never):Int;

	function get_sizeKeyCount():Int
		return sizeTimes.length;

	/** Size key index's time, 0..1 of a life (0 for an index out of range). */
	public function getSizeKeyTime(index:Int):Float
		return index >= 0 && index < sizeTimes.length ? sizeTimes[index] : 0;

	/** Size key index's size, world units (0 for an index out of range). */
	public function getSizeKeySize(index:Int):Float
		return index >= 0 && index < sizeValues.length ? sizeValues[index] : 0;

	/** Size over life, world units: start at birth to end at death, each particle's scaled by up to variance (0..1). Replaces the size keys.
		False, changing nothing, for a variance outside 0..1. */
	public function setSize(start:Float, end:Float, variance = 0.):Bool {
		if (!(variance >= 0 && variance <= 1))
			return false;
		sizeTimes = [0, 1];
		sizeValues = [start, end];
		sizeVariance = variance;
		return true;
	}

	/** Clears the size keys (a curve without keys draws nothing until one is added). */
	public function clearSizeKeys():Void {
		sizeTimes = [];
		sizeValues = [];
	}

	/** Adds a size key at t (0..1 of a life), in order: between keys the size moves in a line; before the first and after the last it holds.
		False past 8 keys, or for a t before the last key's or outside 0..1. */
	public function addSizeKey(t:Float, size:Float):Bool {
		if (sizeTimes.length >= MAX_KEYS || !(t >= 0 && t <= 1) || sizeTimes.length > 0 && t < sizeTimes[sizeTimes.length - 1])
			return false;
		sizeTimes.push(t);
		sizeValues.push(size);
		return true;
	}

	/** The color keys. */
	public var colorKeyCount(get, never):Int;

	function get_colorKeyCount():Int
		return colorTimes.length;

	/** Color key index's time, 0..1 of a life (0 for an index out of range). */
	public function getColorKeyTime(index:Int):Float
		return index >= 0 && index < colorTimes.length ? colorTimes[index] : 0;

	/** Color key index's color, 0xAARRGGBB (0 for an index out of range). */
	public function getColorKeyColor(index:Int):Int
		return index >= 0 && index < colorValues.length ? colorValues[index] : 0;

	/** Color over life (alpha included, so a fade): start at birth to end at death. Replaces the color keys. */
	public function setColor(start:Int, end:Int):Void {
		colorTimes = [0, 1];
		colorValues = [start, end];
	}

	/** Clears the color keys. */
	public function clearColorKeys():Void {
		colorTimes = [];
		colorValues = [];
	}

	/** Adds a color key at t, as addSizeKey. */
	public function addColorKey(t:Float, color:Int):Bool {
		if (colorTimes.length >= MAX_KEYS || !(t >= 0 && t <= 1) || colorTimes.length > 0 && t < colorTimes[colorTimes.length - 1])
			return false;
		colorTimes.push(t);
		colorValues.push(color);
		return true;
	}

	/** The palette colors. */
	public var paletteColorCount(get, never):Int;

	function get_paletteColorCount():Int
		return palette.length;

	/** Palette color index, 0xAARRGGBB (0 for an index out of range). */
	public function getPaletteColor(index:Int):Int
		return index >= 0 && index < palette.length ? palette[index] : 0;

	/** Adds a palette color (at most 8): each particle picks one at birth, tinting its color over life (confetti from one emitter). False past 8. */
	public function addPaletteColor(color:Int):Bool {
		if (palette.length >= 8)
			return false;
		palette.push(color);
		return true;
	}

	/** Clears the palette: no tint. */
	public function clearPalette():Void
		palette = [];

	/** The slowest spin, radians a second. */
	public var minSpin(get, never):Float;

	function get_minSpin():Float
		return spinMin;

	/** The fastest spin, radians a second. */
	public var maxSpin(get, never):Float;

	function get_maxSpin():Float
		return spinMax;

	/** Spin, radians a second between min and max (positive clockwise on screen), from a random angle. None by default. False, changing
		nothing, unless min <= max. */
	public function setSpin(min:Float, max:Float):Bool {
		if (!(min <= max))
			return false;
		spinMin = min;
		spinMax = max;
		return true;
	}

	/** Stretched along the motion (sparks, rain), in seconds of movement: each particle's texture points its top along its velocity across
		the screen, as long as the distance it moves in that time (plus its size); stretched ones don't spin. 0 (the default) is off; 0 or
		more (under 0, or NaN, is 0). */
	public var stretch(default, set):Float = 0.;

	function set_stretch(seconds:Float):Float {
		seconds = seconds >= 0 ? seconds : 0;
		stretch = seconds;
		return seconds;
	}

	/** A Mask's alpha cutoff, 0..1. */
	public var alphaCutoff(get, never):Float;

	function get_alphaCutoff():Float
		return cutoff;

	/** How it uses its texels' alpha (Add by default: glows, sparks, fire), and a Mask's cutoff. False for a cutoff outside 0..1. */
	public function setAlphaMode(mode:AlphaMode, cutoff = .5):Bool {
		if (!(cutoff >= 0 && cutoff <= 1))
			return false;
		alphaMode = mode;
		this.cutoff = cutoff;
		return true;
	}

	/** How it uses its texels' alpha. */
	public var alphaMode(default, null):AlphaMode = Add;

	/** Where its random numbers start (the seed it was last given, or its own, unseeded): the same seed and settings give the same
		particles. 0 is taken as 1 (the generator needs a seed other than 0). */
	public var seed(get, set):Int;

	function get_seed():Int
		return random.seed;

	function set_seed(seed:Int):Int {
		random.seed = seed;
		return seed;
	}

	/** Particles that may still be alive. */
	public var particleCount(get, never):Int;

	function get_particleCount():Int
		return live;

	/** All of them gone. */
	public function clear():Void {
		live = 0;
		owed = 0;
		pending = 0;
		pendingPrewarm = 0;
	}

	inline function signed():Float
		return random.nextFloat() * 2 - 1;

	/** Whether it's spent: no steady rate running, no burst or prewarm waiting for its first place, and no particle alive. A one-shot
		(a preset's explosion, say) is spent once its burst has died out: its node can come off the stage. */
	public var spent(get, never):Bool;

	function get_spent():Bool
		return pending == 0 && pendingPrewarm == 0 && !(emitting && rate > 0) && particleCount == 0;

	/** Bursts count particles at once, where it is now; before it's first placed (a node made and burst before a draw has placed it), where
		it first is. False below 0. */
	public function burst(count:Int):Bool {
		if (count < 0)
			return false;
		if (!placed) {
			pending += count;
			return true;
		}
		for (_ in 0...count)
			spawn(time, lastX, lastY, lastZ);
		return true;
	}

	// Each GPU's dot (getDot), and whether the program frees them at its end (an optional part, installed by the first).
	static var dots = new haxe.ds.ObjectMap<helix.graphics.IGraphics, Texture2D>();
	static var freesDots = false;

	/** The built-in particle: a soft round dot, white (tinted by the particles' colors), 32 texels a side, its alpha falling smoothly from its
		center to its edge, sampled linear. Made on gpu (the program's, Graphics, when not given) the first time it's asked for there, kept
		for the program and freed at its end. The presets draw it (Particles2D.explosion and the others). */
	public static function getDot(?gpu:helix.graphics.IGraphics):Texture2D {
		gpu = gpu != null ? gpu : helix.graphics.Graphics.instance;
		var texture = dots.get(gpu);
		if (texture != null)
			return texture;
		var n = 32, pixels = Bytes.alloc(n * n * 4);
		for (y in 0...n)
			for (x in 0...n) {
				var dx = (x + .5) / n * 2 - 1, dy = (y + .5) / n * 2 - 1;
				var t = 1 - Math.sqrt(dx * dx + dy * dy);
				var alpha = t <= 0 ? 0. : t >= .5 ? 1. : (t / .5) * (t / .5) * (3 - 2 * (t / .5));
				var at = (y * n + x) * 4;
				pixels.set(at, 255);
				pixels.set(at + 1, 255);
				pixels.set(at + 2, 255);
				pixels.set(at + 3, Std.int(alpha * 255 + .5));
			}
		texture = Texture2D.fromRgba(n, n, pixels, Linear, -1, -1, true, gpu);
		dots.set(gpu, texture);
		if (!freesDots && helix.host.Host.running)
			helix.host.Host.installPart(runner -> {
				freesDots = true;
				runner.install({
					shutdown: () -> {
						for (each in dots.keys())
							dots.get(each).destroy(each);
						dots.clear();
						freesDots = false;
					}
				});
				null;
			});
		return texture;
	}

	/** Starts over as if the steady rate had run for seconds: those it would have made and still alive now are made where it is; before
		it's first placed, where it first is. */
	public function prewarm(seconds:Float):Void {
		if (!placed) {
			pendingPrewarm = seconds;
			return;
		}
		clear();
		if (!(seconds > 0) || rate <= 0)
			return;
		var n = Std.int(rate * seconds);
		for (i in 0...n)
			spawn(time - seconds + (i + .5) / rate, lastX, lastY, lastZ);
		forgetDead();
	}

	/** Puts it at x, y, z without a move: nothing spawns along the way, and particles inherit no velocity from it. */
	public function jump(x:Float, y:Float, z:Float):Void {
		lastX = x;
		lastY = y;
		lastZ = flat ? 0 : z;
		placed = true;
		jumped = true;
	}

	/** Advances its clock by dt seconds, it being at x, y, z now (its node's world position): the steady rate's particles due are born along
		the way it moved, and the dead are let go. A stage calls this each draw. */
	public function advance(dt:Float, x:Float, y:Float, z:Float):Void {
		if (flat)
			z = 0;
		if (!placed || jumped) {
			lastX = x;
			lastY = y;
			lastZ = z;
			placed = true;
			jumped = false;
		}
		if (pendingPrewarm > 0) {
			var seconds = pendingPrewarm, waiting = pending;
			pendingPrewarm = 0;
			prewarm(seconds);
			pending = waiting;
		}
		if (pending > 0) {
			for (_ in 0...pending)
				spawn(time, x, y, z);
			pending = 0;
		}
		var fromX = lastX, fromY = lastY, fromZ = lastZ;
		if (dt > 0) {
			moveX = (x - fromX) / dt;
			moveY = (y - fromY) / dt;
			moveZ = (z - fromZ) / dt;
		}
		lastX = x;
		lastY = y;
		lastZ = z;
		if (dt > 0)
			time += dt;
		// The shader's clock is a float: rebase it now and then, moving every birth with it.
		if (time > REBASE) {
			time -= REBASE;
			for (i in 0...max)
				ring.setFloat(i * RECORD + 12, ring.getFloat(i * RECORD + 12) - REBASE);
		}
		if (emitting && rate > 0 && dt > 0) {
			owed += rate * dt;
			var n = Std.int(owed);
			owed -= n;
			// Spread along the way it moved, each at the time it passed there.
			for (i in 0...n) {
				var along = (i + 1) / n;
				spawn(time - dt * (1 - along), fromX + (x - fromX) * along, fromY + (y - fromY) * along, fromZ + (z - fromZ) * along);
			}
		}
		forgetDead();
	}

	// Lets the oldest go while they're dead.
	function forgetDead():Void
		while (live > 0) {
			var at = ((next - live + max) % max) * RECORD;
			if (time - ring.getFloat(at + 12) < ring.getFloat(at + 28))
				break;
			live--;
		}

	function spawn(when:Float, x:Float, y:Float, z:Float):Void {
		var ox = 0., oy = 0., oz = 0.;
		if (sphere > 0) {
			if (flat) {
				var a = random.nextFloat() * Math.PI * 2,
					r = Math.sqrt(random.nextFloat()) * sphere;
				ox = Math.cos(a) * r;
				oy = Math.sin(a) * r;
			} else {
				var zz = signed(), ring = Math.sqrt(Math.max(0, 1 - zz * zz)), phi = random.nextFloat() * Math.PI * 2,
					r = Math.pow(random.nextFloat(), 1 / 3) * sphere;
				ox = Math.cos(phi) * ring * r;
				oy = Math.sin(phi) * ring * r;
				oz = zz * r;
			}
		} else {
			ox = signed() * boxX;
			oy = signed() * boxY;
			oz = flat ? 0 : signed() * boxZ;
		}
		// The velocity: its direction turned up to spread off it, its speed varied.
		var speed = Math.sqrt(dirX * dirX + dirY * dirY + dirZ * dirZ), vx = 0., vy = 0., vz = 0.;
		if (speed > 0) {
			var dx = dirX / speed, dy = dirY / speed, dz = dirZ / speed;
			if (flat) {
				var a = signed() * spread, c = Math.cos(a), s = Math.sin(a);
				vx = dx * c - dy * s;
				vy = dx * s + dy * c;
			} else {
				// Two axes across the direction (from a helper not along it), then a turn off it up to spread, around it at random.
				var hx = Math.abs(dy) < .9 ? 0. : 1.,
					hy = Math.abs(dy) < .9 ? 1. : 0.;
				var px = dy * 0 - dz * hy,
					py = dz * hx - dx * 0,
					pz = dx * hy - dy * hx;
				var pl = Math.sqrt(px * px + py * py + pz * pz);
				px /= pl;
				py /= pl;
				pz /= pl;
				var qx = dy * pz - dz * py,
					qy = dz * px - dx * pz,
					qz = dx * py - dy * px;
				var around = random.nextFloat() * Math.PI * 2,
					off = Math.acos(1 - random.nextFloat() * (1 - Math.cos(spread)));
				var ca = Math.cos(around),
					sa = Math.sin(around),
					so = Math.sin(off),
					co = Math.cos(off);
				vx = dx * co + (px * ca + qx * sa) * so;
				vy = dy * co + (py * ca + qy * sa) * so;
				vz = dz * co + (pz * ca + qz * sa) * so;
			}
			var v = speed * (1 + signed() * speedVariance);
			vx *= v;
			vy *= v;
			vz *= v;
		}
		vx += moveX * inherit;
		vy += moveY * inherit;
		vz += moveZ * inherit;
		var at = next * RECORD;
		ring.setFloat(at, x + ox);
		ring.setFloat(at + 4, y + oy);
		ring.setFloat(at + 8, flat ? 0 : z + oz);
		ring.setFloat(at + 12, when);
		ring.setFloat(at + 16, vx);
		ring.setFloat(at + 20, vy);
		ring.setFloat(at + 24, flat ? 0 : vz);
		ring.setFloat(at + 28, lifeMin + (lifeMax - lifeMin) * random.nextFloat());
		ring.setFloat(at + 32, 1 + signed() * sizeVariance);
		ring.setFloat(at + 36, spinMin + (spinMax - spinMin) * random.nextFloat());
		ring.setFloat(at + 40, random.nextFloat() * Math.PI * 2);
		ring.setFloat(at + 44, random.nextFloat());
		next = (next + 1) % max;
		if (live < max)
			live++;
	}

	/** Copies the particles that may still be alive, oldest first, into out at byte at (48 bytes each); how many. */
	public function writeRecords(out:Bytes, at:Int):Int {
		var first = (next - live + max) % max;
		for (i in 0...live) {
			var from = ((first + i) % max) * RECORD;
			out.blit(at + i * RECORD, ring, from, RECORD);
		}
		return live;
	}

	/** Whether it draws: a texture, particles alive, and a size and color key each. */
	public var drawable(get, never):Bool;

	function get_drawable():Bool
		return texture != null && live > 0 && sizeTimes.length > 0 && colorTimes.length > 0;

	/** Writes its draw's uniforms (the particle program's block) into out: viewProjection, the quad's axes before spin (3D: the camera's right
		and up; 2D: across and up the screen), and its settings, its clock now. */
	public function writeUniforms(out:Bytes, viewProjection:helix.render3d.Mat4, axisX:Array<Float>, axisY:Array<Float>):Void {
		viewProjection.writeTo(out);
		inline function put(index:Int, a:Float, b:Float, c:Float, d:Float):Void {
			out.setFloat(64 + index * 16, a);
			out.setFloat(68 + index * 16, b);
			out.setFloat(72 + index * 16, c);
			out.setFloat(76 + index * 16, d);
		}
		put(0, axisX[0], axisX[1], axisX[2], 0);
		put(1, axisY[0], axisY[1], axisY[2], 0);
		put(2, gravityX, gravityY, gravityZ, time);
		var alpha = switch alphaMode {
			case Opaque: -1.;
			case Mask: Math.max(cutoff, 1e-4);
			case _: 0.;
		};
		put(3, sizeTimes.length, colorTimes.length, alpha, palette.length);
		var tw = texture.width, th = texture.height;
		if (regionWidth > 0 && regionHeight > 0)
			put(4, regionX / tw, regionY / th, (regionX + regionWidth) / tw, (regionY + regionHeight) / th);
		else
			put(4, 0, 0, 1, 1);
		put(5, drag, stretch, 0, 0);
		put(6, columns, rows, frameCount, framesPerSecond);
		inline function keys(index:Int, list:Array<Float>):Void
			for (half in 0...2)
				put(index + half, k(list, half * 4), k(list, half * 4 + 1), k(list, half * 4 + 2), k(list, half * 4 + 3));
		keys(7, sizeTimes);
		keys(9, sizeValues);
		keys(11, colorTimes);
		for (i in 0...MAX_KEYS) {
			var c = i < colorValues.length ? colorValues[i] : 0;
			put(13 + i, Color.getRed(c) / 255, Color.getGreen(c) / 255, Color.getBlue(c) / 255, Color.getAlpha(c) / 255);
		}
		for (i in 0...8) {
			var c = i < palette.length ? palette[i] : 0;
			put(21 + i, Color.getRed(c) / 255, Color.getGreen(c) / 255, Color.getBlue(c) / 255, Color.getAlpha(c) / 255);
		}
	}

	static inline function k(list:Array<Float>, i:Int):Float
		return i < list.length ? list[i] : 0;
}
