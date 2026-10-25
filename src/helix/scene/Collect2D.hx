package helix.scene;

import helix.math.Bounds2D;
import helix.math.Random;
import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;

/** Things collected flying to where they count: a chest's coins to the score, gems to a counter, hearts to the health bar. Sprites of a
	texture burst out from a point on the stage, scatter for a moment, then each curves in to a target node, one after another, a callback
	as each arrives (a ding, a score tick) and another once all have. It runs itself (run), on the frames' time as a Transition does, and
	takes itself off the stage when done; from a 3D world, the point is a View3D's project of where the chest is (Collect3D flies them through the world instead). In the stage's units. */
class Collect2D {
	/** Sprites of texture, count of them (at least 1), each texture's size unless sized (size). */
	public function new(texture:Texture2D, count = 12) {
		this.texture = texture;
		this.count = count > 1 ? count : 1;
	}

	/** Their texture. */
	public var texture(default, null):Texture2D;

	/** How many fly. */
	public var count(default, null):Int;

	/** Each sprite's size, the stage's units, square; 0 (the default) for its texture's size. */
	public var size:Float = 0;

	/** Their tint, 0xAARRGGBB: white (the texture as it is) by default. */
	public var tint:Int = 0xffffffff;

	/** How far they scatter from the point before they fly, the stage's units: 48 by default. */
	public var scatter:Float = 48;

	/** Seconds they scatter for: .35 by default. */
	public var scatterSeconds:Float = .35;

	/** Seconds each takes to fly in once it sets off: .6 by default. */
	public var flySeconds:Float = .6;

	/** Seconds between one setting off and the next: .05 by default. */
	public var stagger:Float = .05;

	/** Whether it's running now. */
	public var running(default, null):Bool = false;

	/** Bursts them from x, y (the stage's units) to target, each flying to where target's bounds' center is as it arrives (its position
		when it has none: a group), arrived (when given) called as each arrives with its index, done (when given) once all have. False,
		running nothing, while it's running already. With the run option quick=1, they arrive at once. */
	public function run(x:Float, y:Float, target:Node2D, ?arrived:Int->Void, ?done:Void->Void):Bool {
		if (running)
			return false;
		running = true;
		var holder = new Node2D(), random = new Random(Std.int(x * 31 + y * 17) + count), sprites = [];
		holder.pickable = false;
		// Where each scatters to, and when it sets off.
		var spreadX = [], spreadY = [], leaves = [], landed = [];
		for (i in 0...count) {
			var sprite = new Sprite2D(texture, tint);
			sprite.setPivot(.5, .5);
			if (size > 0)
				sprite.setSize(size, size);
			sprite.setPosition(x, y);
			holder.addChild(sprite);
			sprites.push(sprite);
			var angle = random.nextFloat() * Math.PI * 2,
				reach = scatter * (.4 + .6 * random.nextFloat());
			spreadX.push(x + Math.cos(angle) * reach);
			spreadY.push(y + Math.sin(angle) * reach);
			leaves.push(scatterSeconds + i * stagger);
			landed.push(false);
		}
		Stage.addChild(holder);
		var elapsed = 0., left = count, bounds = new Bounds2D(), quick = Flow.quick;
		Flow.run(dt -> {
			elapsed += Math.max(0, dt);
			// Where it's going: the target's middle as it is now.
			var to = target.computeBounds(bounds);
			var toX = to != null ? to.centerX : target.toWorldX(0, 0),
				toY = to != null ? to.centerY : target.toWorldY(0, 0);
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
					sprite.setPosition(x + (spreadX[i] - x) * t, y + (spreadY[i] - y) * t);
				} else if (elapsed >= leaves[i]) {
					// In along a curve bowed sideways, speeding up: a quadratic from where it scattered to, over a point off the line between.
					var t = (elapsed - leaves[i]) / flySeconds, eased = t * t;
					var cx = (spreadX[i] + toX) / 2 + (spreadY[i] - toY) * .3,
						cy = (spreadY[i] + toY) / 2 - (spreadX[i] - toX) * .3;
					var a = (1 - eased) * (1 - eased),
						b = 2 * (1 - eased) * eased,
						c = eased * eased;
					sprite.setPosition(a * spreadX[i] + b * cx + c * toX, a * spreadY[i] + b * cy + c * toY);
					sprite.setScale(1 - .4 * eased, 1 - .4 * eased);
				}
			}
			if (left > 0)
				return true;
			Stage.removeChild(holder);
			running = false;
			if (done != null)
				done();
			return false;
		});
		return true;
	}
}
