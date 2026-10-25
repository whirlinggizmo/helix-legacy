import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.ScreenShape;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.math.Interpolate;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.render3d.Camera3D;
import helix.render3d.CameraFollow3D;
import helix.render3d.DirectionalLight3D;
import helix.render3d.Environment3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.Node3D;
import helix.render3d.PickHit3D;
import helix.render3d.Ray3D;
import helix.render3d.View3D;
import helix.texture.Sampling;
import helix.texture.Texture2D;
import helix.time.Time;

/** A ball driven over a floor, a ramp and a step, the camera behind it: the 3D pieces a game moving something round a world stands on. The
	ground under the ball is what a ray straight down meets (View3D.pickAlong), so it rides up the ramp and onto the step by their triangles,
	sitting on a slope as a sphere would; a ray ahead stops it at a wall (the L) where its surface meets it. Rays, not a sphere body (that
	comes with physics): over an edge it drops once its center is past. It rolls by the distance it went, about the axis across its way (Node3D.rotateOnAxis, a
	world axis), its checks showing the turn. The camera (CameraFollow3D) follows it smoothly from behind, a distance and a pitch away, swinging
	round as the arrows turn (headingSmoothing) and coming in front of the L when it's between them (setWalls); Space shakes it. Up and down (or W, S) push the ball, left and right (A, D) turn; Escape quits where quitting means anything. The
	ball is only pushed and slowed. */
class App extends helix.App {
	static inline var RADIUS = .5;

	var level = new Node3D();
	var camera = new Camera3D();
	var view:View3D;
	var ball:Model3D;
	var follow = new CameraFollow3D();
	var text = new Drawing2D();
	var fps = new FpsOverlay();
	var ray = new Ray3D();
	var hit = new PickHit3D();
	// The way the camera and the arrows face, radians about up (0 toward -z), and the ball's speed along x and z, world units a second.
	var heading = 0.;
	var speedX = 0.;
	var speedZ = 0.;

	override public function init():Void {
		Window.title = "HeliX follow3d";
		Window.requestSize(1000, 600);
		Stage.color = 0xff14161c;
		level.environment = new Environment3D();
		level.environment.setAmbient(0xffffffff, .3);
		var sun = new DirectionalLight3D();
		sun.intensity = 3;
		sun.lookAt(-.5, -1, -.4);
		level.addChild(sun);

		var checks = checker();
		var ground = new Material3D();
		ground.baseColor = 0xff474a4d;
		ground.roughness = .9;
		level.addChild(new Model3D(Mesh3D.plane(24, 24), ground));
		var stone = new Material3D();
		stone.baseColor = 0xff9aa4b0;
		stone.roughness = .7;
		// A ramp rising toward -z, its low end at the floor.
		var ramp = new Model3D(Mesh3D.cube(3, .4, 6), stone);
		ramp.setRotation(.25, 0, 0);
		ramp.setPosition(4, Math.sin(.25) * 3 - .2 * Math.cos(.25), -2);
		level.addChild(ramp);
		// A low step to climb, and the L as a wall too high to, tall enough to come between the camera and the ball.
		var step = new Model3D(Mesh3D.extrude([0., 0, 3, 0, 3, 3, 0, 3], .25), stone);
		step.setPosition(-5, 0, -1);
		level.addChild(step);
		var wall = new Model3D(Mesh3D.extrude([0., 0, 4, 0, 4, 1, 1, 1, 1, 2.5, 0, 2.5], 2.4), stone);
		wall.setPosition(-2, 0, -7);
		level.addChild(wall);

		var paint = new Material3D();
		paint.texture = checks;
		paint.roughness = .5;
		ball = new Model3D(Mesh3D.sphere(RADIUS, 24, 48), paint);
		// The ray down looks for the ground, not the ball.
		ball.pickable = false;
		ball.setPosition(0, RADIUS, 4);
		level.addChild(ball);
		view = new View3D(level, camera);
		// 5.5 away, looking down about 25 degrees, coming in front of a wall behind the ball.
		follow.setDistance(5.5, .45);
		follow.setWalls(view, ball);
		follow.snap(ball.x, ball.y, ball.z);

		Stage.addChild(view);
		Stage.addChild(text);
		Stage.addChild(fps);
	}

	// Checks, two round the ball, smooth and with mipmaps.
	function checker():Texture2D {
		var pixels = haxe.io.Bytes.alloc(32 * 32 * 4);
		for (y in 0...32)
			for (x in 0...32)
				pixels.setInt32((y * 32 + x) * 4, (x < 16) == (y < 16) ? 0xff5ad2ff : 0xff283c50);
		var texture = Texture2D.fromRgba(32, 32, pixels, Linear, -1, -1, true);
		texture.sampling = new Sampling(Linear, Repeat, Repeat);
		return texture;
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		if (Input.isFramePressed(Key.Space))
			follow.shake(.6);
		var turn = (Input.isDown(Key.Left) || Input.isDown(Key.A) ? 1 : 0) - (Input.isDown(Key.Right) || Input.isDown(Key.D) ? 1 : 0),
			push = (Input.isDown(Key.Up) || Input.isDown(Key.W) ? 1 : 0) - (Input.isDown(Key.Down) || Input.isDown(Key.S) ? 1 : 0);
		heading += turn * 2.2 * dt;
		// Pushed along the way the camera faces, slowed as it rolls.
		speedX += -Math.sin(heading) * push * 12 * dt;
		speedZ += -Math.cos(heading) * push * 12 * dt;
		speedX = Interpolate.damp(speedX, 0, 1.2, dt);
		speedZ = Interpolate.damp(speedZ, 0, 1.2, dt);
		roll(speedX * dt, speedZ * dt);

		follow.heading = heading;
		follow.update(ball.x, ball.y, ball.z, dt);
		follow.apply(camera);
		fps.update(dt, Time.frameCpu);
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		text.clear();
		var y = vy + 36;
		y += text.drawTextWrapped("HeliX follow3d: the ground by a ray down, a roll about a world axis, a camera following", vx + 12, y, 20, vw - 24,
			0xfff5f5f5)
			+ 3;
		text.drawTextWrapped("Arrows or WASD: push and turn   Space: shake" + (Host.canQuit() ? "   ESC: quit" : ""), vx + 12, y, 16, vw - 24, 0xffc8c8c8);
		fps.setPosition(vx + 12, vy + 10);
	}

	// Moves the ball by dx, dz onto the ground there, rolling it that far. Rays, not a sphere: one ahead from its center stops it at a wall
	// (a face too steep to roll up) its surface would reach; one down finds the ground, the ball sitting on its slope as a sphere sits on a
	// plane; a rise higher than a step, or no ground (off the floor), stops it too. Over an edge it drops once its center is past.
	function roll(dx:Float, dz:Float):Void {
		var distance = Math.sqrt(dx * dx + dz * dz);
		if (distance == 0)
			return;
		ray.set(ball.x, ball.y, ball.z, dx / distance, 0, dz / distance);
		if (view.pickAlong(ray, hit) != null && hit.distance < RADIUS + distance && Math.abs(hit.getNormal(1)) < .7) {
			speedX = speedZ = 0;
			return;
		}
		var x = ball.x + dx, z = ball.z + dz;
		ray.set(x, ball.y + 1, z, 0, -1, 0);
		if (view.pickAlong(ray, hit) == null || hit.getPoint(1) - (ball.y - RADIUS) > .3) {
			speedX = speedZ = 0;
			return;
		}
		// On a slope the center sits the radius from the plane, along its normal: radius / normal y above the point under it.
		ball.setPosition(x, hit.getPoint(1) + RADIUS / hit.getNormal(1), z);
		// Rolling: about the axis across the way it went (up x the way), as far round as it went over its radius.
		ball.rotateOnAxis(dz, 0, -dx, distance / RADIUS);
	}
}
