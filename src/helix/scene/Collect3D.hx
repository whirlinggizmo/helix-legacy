package helix.scene;

import helix.math.Bounds3D;
import helix.math.Random;
import helix.render3d.Mat4;
import helix.render3d.Node3D;
import helix.render3d.Sprite3D;
import helix.texture.Texture2D;

/** Things collected flying to where they count, in a 3D world: a chest's coins to the player, gems to a pedestal. Sprites of a texture burst
	up and out from a point, scatter for a moment, then each arcs in to a target node, one after another, with a callback as each arrives (a
	ding, a score tick) and another once all have. It runs itself (run), on the frames' time as a Transition does, and takes its sprites out of
	the world when done. Positions and sizes are in world units of the tree the target is in. To fly to something on the stage (a counter on
	the HUD), use Collect2D from a View3D's project of the point instead. */
class Collect3D {
	/** Sprites of texture, count of them (at least 1). */
	public function new(texture:Texture2D, count = 12) {
		this.texture = texture;
		this.count = count > 1 ? count : 1;
	}

	/** Their texture. */
	public var texture(default, null):Texture2D;

	/** How many fly. */
	public var count(default, null):Int;

	/** Each sprite's size in world units, square: .25 by default. */
	public var size:Float = .25;

	/** Their tint, 0xAARRGGBB: white (the texture as it is) by default. */
	public var tint:Int = 0xffffffff;

	/** How far they scatter from the point before they fly, in world units: 1 by default. */
	public var scatter:Float = 1;

	/** Seconds they scatter for: .35 by default. */
	public var scatterSeconds:Float = .35;

	/** Seconds each takes to fly in once it sets off: .6 by default. */
	public var flySeconds:Float = .6;

	/** Seconds between one setting off and the next: .05 by default. */
	public var stagger:Float = .05;

	/** Whether it's running now. */
	public var running(default, null):Bool = false;

	/** Bursts them from x, y, z to target and calls arrived (when given) with each one's index as it arrives, and done (when given) once all
		have. The point is in the units of the topmost node above target (the level the game puts in a View3D), and the sprites go under that
		node while they fly. Each flies to the center of target's bounds as it is when it arrives, or to target's position when it has no
		bounds (a group). Returns false, running nothing, while it's running already. With the run option quick=1, they arrive at once. */
	public function run(x:Float, y:Float, z:Float, target:Node3D, ?arrived:Int->Void, ?done:Void->Void):Bool {
		if (running)
			return false;
		running = true;
		var root = target;
		while (root.parent != null)
			root = root.parent;
		var holder = new Node3D(), random = new Random(Std.int(x * 31 + y * 17 + z * 13) + count), sprites = [];
		holder.pickable = false;
		// Where each scatters to (up and out, never down), and when it sets off.
		var spreadX = [], spreadY = [], spreadZ = [], leaves = [], landed = [];
		for (i in 0...count) {
			var sprite = new Sprite3D(texture, tint);
			sprite.setSpriteSize(size, size);
			sprite.setPosition(x, y, z);
			holder.addChild(sprite);
			sprites.push(sprite);
			var angle = random.nextFloat() * Math.PI * 2,
				rise = .3 + .7 * random.nextFloat(),
				reach = scatter * (.4 + .6 * random.nextFloat());
			var across = Math.sqrt(1 - rise * rise);
			spreadX.push(x + Math.cos(angle) * across * reach);
			spreadY.push(y + rise * reach);
			spreadZ.push(z + Math.sin(angle) * across * reach);
			leaves.push(scatterSeconds + i * stagger);
			landed.push(false);
		}
		root.addChild(holder);
		var elapsed = 0., left = count, bounds = new Bounds3D(), seen = new Mat4(), at = new Mat4(), quick = Flow.quick;
		Flow.run(dt -> {
			elapsed += Math.max(0, dt);
			// Where it's going: the target's middle as it is now, without the sprites themselves when they're under it.
			holder.visible = false;
			var to = target.computeBounds(root, bounds);
			holder.visible = true;
			var toX, toY, toZ;
			if (to != null) {
				toX = to.centerX;
				toY = to.centerY;
				toZ = to.centerZ;
			} else {
				root.computeWorld(seen);
				seen.makeInverse(seen);
				at.makeProduct(seen, target.computeWorld(at));
				toX = at.get(12);
				toY = at.get(13);
				toZ = at.get(14);
			}
			for (i in 0...count) {
				if (landed[i])
					continue;
				var sprite = sprites[i];
				if (quick || elapsed >= leaves[i] + flySeconds) {
					landed[i] = true;
					sprite.visible = false;
					left--;
					if (arrived != null)
						arrived(i);
					continue;
				}
				if (elapsed < scatterSeconds) {
					// Out from the point, slowing.
					var t = 1 - Math.pow(1 - elapsed / scatterSeconds, 3);
					sprite.setPosition(x + (spreadX[i] - x) * t, y + (spreadY[i] - y) * t, z + (spreadZ[i] - z) * t);
				} else if (elapsed >= leaves[i]) {
					// In along an arc bowed upward, speeding up: a quadratic from where it scattered to, over a point above the line between.
					var t = (elapsed - leaves[i]) / flySeconds, eased = t * t;
					var dx = toX - spreadX[i],
						dy = toY - spreadY[i],
						dz = toZ - spreadZ[i];
					var cx = spreadX[i] + dx / 2,
						cy = spreadY[i] + dy / 2 + Math.sqrt(dx * dx + dy * dy + dz * dz) * .3,
						cz = spreadZ[i] + dz / 2;
					var a = (1 - eased) * (1 - eased),
						b = 2 * (1 - eased) * eased,
						c = eased * eased;
					sprite.setPosition(a * spreadX[i] + b * cx + c * toX, a * spreadY[i] + b * cy + c * toY, a * spreadZ[i] + b * cz + c * toZ);
					var shrink = 1 - .4 * eased;
					sprite.setScale(shrink, shrink, shrink);
				}
			}
			if (left > 0)
				return true;
			holder.parent = null;
			running = false;
			if (done != null)
				done();
			return false;
		});
		return true;
	}
}
