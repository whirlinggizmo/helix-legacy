import helix.behavior.Behavior;
import helix.input.Input;
import helix.input.Key;
import helix.input.PadAxis;
import helix.math.Trig;
import helix.render3d.Node3D;

/** A kinematic car on its node, driven by the keys (UP / DOWN or W / S throttle and brake, LEFT / RIGHT or A / D steering) or a pad (the
	left stick steers, the right trigger drives, the left brakes), read from the program's input (Input: the window's, or an autopilot's while it plays). A bicycle model:
	the speed from the throttle's acceleration, drag (the speed settles at topSpeed under full throttle) and the brake, the steering angle
	moving toward the wheel's at a fixed rate and narrowing as the speed grows, the heading turned by speed / wheelbase x tan(angle) and the
	position moved along it. Deterministic (helix.math.Trig for every sine, cosine and tangent), so an autopilot's drive replays alike in
	the browser and natively. It writes the node's position and yaw (y rotation), turns the front wheels (the model's wheel-front-left and
	wheel-front-right, found by name once) to the steering angle and spins all four by the distance over wheelRadius. Nothing keeps it on the
	road. It waits for its race (race, a Race behavior's node) to be racing, and stands still until then. */
class Car extends Behavior {
	/** The node the Race behavior is on; the car moves once that race is racing. Null: it drives at once. */
	@:prop public var race:Node3D = null;

	/** The speed the car settles at under full throttle, m/s. */
	@:prop @:range(1, 100) public var topSpeed = 32.;

	/** How fast full throttle accelerates from rest, m/s². */
	@:prop @:range(1, 50) public var acceleration = 12.;

	/** How fast the brake slows it, m/s². */
	@:prop @:range(1, 80) public var brake = 24.;

	/** The front wheels' full lock at rest, radians (0.22 turns this car in about 6 m); it narrows toward 30% of this at topSpeed. */
	@:prop @:range(0.05, 1.2) public var steerAngle = .22;

	/** How fast the steering angle moves toward the wheel's, radians a second. */
	@:prop @:range(0.1, 20) public var steerSpeed = 4.;

	/** The wheels' radius, m: how far a turn of a wheel carries. */
	@:prop @:range(0.01, 5) public var wheelRadius = .3;

	/** The distance between the axles, m: the bicycle model's wheelbase. */
	@:prop @:range(0.1, 20) public var wheelbase = 1.32;

	/** How fast it goes in reverse at most, as a share of topSpeed. */
	@:prop @:range(0, 1) public var reverseShare = .25;

	/** Its speed along its heading, m/s; negative in reverse. */
	public var speed(default, null) = 0.;

	/** Its heading, radians: a yaw about +y, 0 along +z, left turns adding. */
	public var heading(default, null) = 0.;

	/** The front wheels' angle, radians, left positive. */
	public var steering(default, null) = 0.;

	var x = 0.;
	var z = 0.;
	var y = 0.;
	var spin = 0.;
	var front:Array<Node3D> = [];
	var wheels:Array<Node3D> = [];

	/** The car's position and heading from the node as the file placed it; its wheels found by name. */
	override public function start():Void {
		x = node.x;
		y = node.y;
		z = node.z;
		heading = Trig.atan2(2 * (node.quaternionX * node.quaternionZ + node.quaternionW * node.quaternionY),
			1 - 2 * (node.quaternionX * node.quaternionX + node.quaternionY * node.quaternionY));
		for (name in ["wheel-front-left", "wheel-front-right"]) {
			var wheel = node.find(name, Node3D);
			if (wheel != null) {
				front.push(wheel);
				wheels.push(wheel);
			}
		}
		for (name in ["wheel-back-left", "wheel-back-right"]) {
			var wheel = node.find(name, Node3D);
			if (wheel != null)
				wheels.push(wheel);
		}
	}

	/** Reads the input, moves the car by dt seconds and places the node and its wheels. */
	override public function update(dt:Float):Void {
		var held = race != null ? pass.on(race, Race) : null;
		var racing = held == null || held.racing;
		var throttle = 0., braking = 0., steer = 0.;
		if (racing) {
			if (Input.isDown(Key.Up) || Input.isDown(Key.W))
				throttle = 1;
			if (Input.isDown(Key.Down) || Input.isDown(Key.S))
				braking = 1;
			if (Input.isDown(Key.Left) || Input.isDown(Key.A))
				steer += 1;
			if (Input.isDown(Key.Right) || Input.isDown(Key.D))
				steer -= 1;
			var stick = Input.getPadAxis(PadAxis.LeftX);
			if (stick > .2 || stick < -.2)
				steer -= stick;
			var gas = Input.getPadAxis(PadAxis.RightTrigger);
			if (gas > throttle)
				throttle = gas;
			var pedal = Input.getPadAxis(PadAxis.LeftTrigger);
			if (pedal > braking)
				braking = pedal;
		}
		if (steer > 1)
			steer = 1;
		if (steer < -1)
			steer = -1;
		// The speed: throttle against drag (full throttle settles at topSpeed), the brake slowing it and then backing up.
		var drag = acceleration / topSpeed;
		var change = throttle * acceleration - drag * speed;
		if (braking > 0)
			change -= speed > 0 ? braking * brake : braking * acceleration * reverseShare;
		speed += change * dt;
		if (!racing || (throttle == 0 && braking == 0 && speed > -.05 && speed < .05))
			speed = 0;
		// The steering: toward the wheel's at steerSpeed, within a lock that narrows with speed.
		var share = speed < 0 ? -speed / topSpeed : speed / topSpeed;
		var lock = steerAngle * (1 - .7 * (share > 1 ? 1 : share));
		var wanted = steer * lock;
		var step = steerSpeed * dt;
		if (steering < wanted - step)
			steering += step;
		else if (steering > wanted + step)
			steering -= step;
		else
			steering = wanted;
		// The bicycle model: the heading turns by speed over the wheelbase times the tangent of the angle; the position moves along it.
		heading += speed / wheelbase * Trig.tan(steering) * dt;
		if (heading > Math.PI)
			heading -= 2 * Math.PI;
		else if (heading < -Math.PI)
			heading += 2 * Math.PI;
		var distance = speed * dt;
		x += distance * Trig.sin(heading);
		z += distance * Trig.cos(heading);
		node.setPosition(x, y, z);
		node.setRotation(0, heading, 0);
		spin += distance / wheelRadius;
		if (spin > 2 * Math.PI)
			spin -= 2 * Math.PI;
		else if (spin < 0)
			spin += 2 * Math.PI;
		for (wheel in wheels)
			wheel.setRotation(spin, front.indexOf(wheel) >= 0 ? steering : 0, 0);
	}

	/** The car's position, x. */
	public var carX(get, never):Float;

	function get_carX():Float
		return x;

	/** The car's position, z. */
	public var carZ(get, never):Float;

	function get_carZ():Float
		return z;
}
