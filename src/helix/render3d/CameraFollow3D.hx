package helix.render3d;

import helix.math.Interpolate;
import helix.math.Random;

/** A 3D camera following a target: it looks at a point that follows the target, the target moving freely inside a dead zone around it and
	the point catching up smoothly (at the same speed at any frame rate) when it leaves, and sits at an offset from that point, turned about
	the up axis by heading (behind a player as it turns), swinging round to it smoothly. Given walls (setWalls), it comes in front of what's
	between it and the point, so a wall behind the player never hides them. It's shaken (shake), a trauma that decays, the view thrown across and up by the
	square of it. update follows, apply places a camera there. Follow where the target is drawn (between simulation ticks, where it's
	interpolated), not where it's simulated, or the view jitters against it. The shake is the view's only, never the game's: its random
	numbers are its own. In world units throughout. */
class CameraFollow3D {
	var halfDeadWidth = 0.;
	var halfDeadHeight = 0.;
	var halfDeadDepth = 0.;
	var random:Random;
	// The shake's noise: a point now and the next, each axis, picked shakeFrequency times a second and moved between.
	var shakeTime = 0.;
	var fromX = 0.;
	var fromY = 0.;
	var toX = 0.;
	var toY = 0.;
	// What it comes in front of, what's left out of that, and the share of its offset it's out at now (1: all of it).
	var walls:Null<View3D>;
	var ignored:Null<Node3D>;
	var reach = 1.;
	var ray = new Ray3D();
	var hit = new PickHit3D();

	/** A follow looking at x, y, z, with no dead zone, from 6 back and 3 up; seed seeds its shake. */
	public function new(x = 0., y = 0., z = 0., seed = 1) {
		this.x = x;
		this.y = y;
		this.z = z;
		random = new Random(seed);
	}

	/** The point followed to and looked at, before the shake, x. */
	public var x(default, null):Float;

	/** The point followed to and looked at, before the shake, y. */
	public var y(default, null):Float;

	/** The point followed to and looked at, before the shake, z. */
	public var z(default, null):Float;

	/** Where the camera sits from the point, across, before heading turns it: 0 by default. */
	public var offsetX = 0.;

	/** Where the camera sits from the point, up: 3 by default. */
	public var offsetY = 3.;

	/** Where the camera sits from the point, along z, before heading turns it: 6 by default (behind a target facing -z). */
	public var offsetZ = 6.;

	/** The way it wants to face, radians about the up axis (the offset turned by it): 0 by default, from +z looking toward -z. Set it to a
		player's heading to stay behind them; the camera swings round to it at headingSmoothing. */
	public var heading = 0.;

	/** The way it faces now, radians about the up axis, swinging toward heading. */
	public var currentHeading(default, null) = 0.;

	/** How quickly it swings round to heading, the shorter way: the rate of Interpolate.dampAngle, per second, 6 by default. 0 or less
		turns at once. */
	public var headingSmoothing = 6.;

	/** How far in front of a wall it stays when it comes in (setWalls), in world units: 0.2 by default. */
	public var wallMargin = .2;

	/** How quickly the point catches up with the target when it leaves the dead zone: the rate of Interpolate.damp, per second (about a fifth
		of the way left after 1.6 / rate seconds). 0 or less catches up at once. */
	public var smoothing = 8.;

	/** How far the view is thrown at full trauma, as a share of the camera's distance from the point (0.04: 0.27 of a camera 6.7 away), so
		a shake looks the same close up or far off. */
	public var shakeDistance = .04;

	/** How much trauma it loses a second: 1 settles a full shake in a second. */
	public var shakeRecovery = 1.5;

	/** How many times a second the shake changes direction. */
	public var shakeFrequency = 25.;

	/** The shake's trauma, 0 (still) to 1, falling by shakeRecovery a second; the view is thrown by its square, so small shakes are gentle. */
	public var trauma(default, null) = 0.;

	/** Where the shake throws the view now, across the view, in world units. */
	public var shakeX(default, null) = 0.;

	/** Where the shake throws the view now, up the view, in world units. */
	public var shakeY(default, null) = 0.;

	/** Sets where the camera sits from the point (x across, y up, z along before heading turns it). */
	public function setOffset(x:Float, y:Float, z:Float):Void {
		offsetX = x;
		offsetY = y;
		offsetZ = z;
	}

	/** Sets the offset by how far the camera is from the point and how steeply it looks down at it (radians: 0 level, pi / 2 straight
		down, which a camera can't look, so keep under it): `setDistance(6, .45)` 6 away, looking down about 25 degrees. False, changing
		nothing, for a distance below 0. */
	public function setDistance(distance:Float, pitch:Float):Bool {
		if (!(distance >= 0))
			return false;
		setOffset(0, distance * Math.sin(pitch), distance * Math.cos(pitch));
		return true;
	}

	/** Makes it come in front of what's in view's tree between the point and where it sits, as View3D.pickAlong meets it, staying
		wallMargin off it; it comes in at once and goes back out at smoothing. ignore (the target, usually) and what's under it are left out,
		as the target would otherwise stand in its own way. Null stops it. */
	public function setWalls(view:Null<View3D>, ?ignore:Node3D):Void {
		walls = view;
		ignored = ignore;
		if (view == null)
			reach = 1;
	}

	/** The target moves freely within width x height x depth world units around the point (0, 0, 0: none, the point always catching up).
		False, changing nothing, for a size below 0. */
	public function setDeadZone(width:Float, height:Float, depth:Float):Bool {
		if (!(width >= 0 && height >= 0 && depth >= 0))
			return false;
		halfDeadWidth = width / 2;
		halfDeadHeight = height / 2;
		halfDeadDepth = depth / 2;
		return true;
	}

	/** Adds amount to the trauma (held to 1): 0.3 a bump, 1 an explosion. */
	public function shake(amount:Float):Void
		if (amount > 0)
			trauma = Math.min(1, trauma + amount);

	/** Puts the point at x, y, z at once (a respawn, a new level), facing heading. */
	public function snap(x:Float, y:Float, z:Float):Void {
		this.x = x;
		this.y = y;
		this.z = z;
		currentHeading = heading;
	}

	/** Follows the target at targetX, targetY, targetZ for dt seconds, and advances the shake. */
	public function update(targetX:Float, targetY:Float, targetZ:Float, dt:Float):Void {
		x = follow(x, targetX, halfDeadWidth, dt);
		y = follow(y, targetY, halfDeadHeight, dt);
		z = follow(z, targetZ, halfDeadDepth, dt);
		currentHeading = headingSmoothing > 0 ? Interpolate.dampAngle(currentHeading, heading, headingSmoothing, dt) : heading;
		if (walls != null)
			comeIn(dt);
		advanceShake(dt);
	}

	/** Where the camera sits now, before the shake, x. */
	public var eyeX(get, never):Float;

	function get_eyeX():Float
		return x + reach * (offsetX * Math.cos(currentHeading) + offsetZ * Math.sin(currentHeading));

	/** Where the camera sits now, before the shake, y. */
	public var eyeY(get, never):Float;

	function get_eyeY():Float
		return y + reach * offsetY;

	/** Where the camera sits now, before the shake, z. */
	public var eyeZ(get, never):Float;

	function get_eyeZ():Float
		return z + reach * (-offsetX * Math.sin(currentHeading) + offsetZ * Math.cos(currentHeading));

	/** Places camera at its seat, looking at the point, both thrown across and up the view by the shake. Leaves camera as it was when the
		seat is the point itself or straight above it (an offset of 0, or only up). */
	public function apply(camera:Camera3D):Void {
		var ex = eyeX, ey = eyeY, ez = eyeZ;
		// Across and up the view: right = forward x up, up' = right x forward.
		var fx = x - ex, fy = y - ey, fz = z - ez;
		var rx = -fz, rz = fx, rLength = Math.sqrt(rx * rx + rz * rz);
		var sx = 0., sy = 0., sz = 0.;
		if (rLength > 0 && (shakeX != 0 || shakeY != 0)) {
			rx /= rLength;
			rz /= rLength;
			var ux = -rz * fy, uy = rz * fx - rx * fz, uz = rx * fy;
			var uLength = Math.sqrt(ux * ux + uy * uy + uz * uz);
			if (uLength > 0) {
				ux /= uLength;
				uy /= uLength;
				uz /= uLength;
			}
			sx = rx * shakeX + ux * shakeY;
			sy = uy * shakeY;
			sz = rz * shakeX + uz * shakeY;
		}
		camera.setView(ex + sx, ey + sy, ez + sz, x + sx, y + sy, z + sz);
	}

	// The share of the offset it can sit out at: a ray from the point out to its seat, short of what it meets; in at once, out smoothly.
	function comeIn(dt:Float):Void {
		var ox = offsetX * Math.cos(currentHeading) + offsetZ * Math.sin(currentHeading),
			oz = -offsetX * Math.sin(currentHeading) + offsetZ * Math.cos(currentHeading);
		var length = Math.sqrt(ox * ox + offsetY * offsetY + oz * oz);
		var want = 1.;
		if (length > 0 && ray.set(x, y, z, ox, offsetY, oz)) {
			var was = ignored != null ? ignored.pickable : false;
			if (ignored != null)
				ignored.pickable = false;
			if (walls.pickAlong(ray, hit) != null && hit.distance < length)
				want = Math.max(0, hit.distance - wallMargin) / length;
			if (ignored != null)
				ignored.pickable = was;
		}
		reach = want < reach || smoothing <= 0 ? want : Interpolate.damp(reach, want, smoothing, dt);
	}

	// One axis toward the target: the target, less what the dead zone lets it stray, damped.
	function follow(at:Float, target:Float, halfDead:Float, dt:Float):Float {
		var want = at;
		if (target > at + halfDead)
			want = target - halfDead;
		else if (target < at - halfDead)
			want = target + halfDead;
		return smoothing > 0 ? Interpolate.damp(at, want, smoothing, dt) : want;
	}

	// The trauma falls; the throw moves smoothly between random points, scaled by the trauma's square and the camera's distance.
	function advanceShake(dt:Float):Void {
		if (!(dt > 0))
			return;
		trauma = Math.max(0, trauma - shakeRecovery * dt);
		if (trauma == 0) {
			shakeX = shakeY = 0;
			return;
		}
		shakeTime += dt * (shakeFrequency > 0 ? shakeFrequency : 0);
		while (shakeTime >= 1) {
			shakeTime -= 1;
			fromX = toX;
			fromY = toY;
			toX = random.nextRange(-1, 1);
			toY = random.nextRange(-1, 1);
		}
		var strength = trauma * trauma * shakeDistance * Math.sqrt(offsetX * offsetX + offsetY * offsetY + offsetZ * offsetZ);
		shakeX = Interpolate.lerp(fromX, toX, shakeTime) * strength;
		shakeY = Interpolate.lerp(fromY, toY, shakeTime) * strength;
	}
}
