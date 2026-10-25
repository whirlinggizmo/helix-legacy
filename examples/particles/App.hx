import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.particle.Emitter;
import helix.render2d.Drawing2D;
import helix.render2d.Particles2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.render3d.Camera3D;
import helix.render3d.Drawing3D;
import helix.render3d.Node3D;
import helix.render3d.Particles3D;
import helix.render3d.View3D;
import helix.time.Time;
import helix.host.ScreenShape;
import helix.render3d.Orbit3D;

/** Particle emitters (helix.particle.Emitter), drawn by the GPU from each particle's birth record and age. In a 3D level shown by a View3D, over a grid (a Drawing3D): a fountain
	(blended drops under gravity), sparks (added, from a point circling the fountain: they trail behind it, are thrown along by it, slowed by
	drag, and stretched along their motion), and a campfire: flames (added puffs from a flipbook, colored by a curve) under smoke (blended,
	with size and color curves: a dark puff that spreads, lightens and fades as it rises). The steady ones are prewarmed, so they're already
	going. Click or tap for a burst of 2D confetti there, on the stage over the 3D view: squares cut from the particle texture's middle (so their
	spin shows), each tinted by a color it picked from the palette. The camera turns slowly around the level.
	The presets (helix.particle.ParticlePreset, Particles3D's factories, drawn with the built-in dot): 1 to 5 burst an explosion, a smoke
	puff, sparks, dust and confetti on the grid, each taken off once it's spent; 6 lets it snow.

	Click or tap: confetti; 1 to 5: a preset's burst; 6: snow; Space: pause the steady emitters (the particles alive finish their lives); O:
	the camera; Escape: quit, where quitting means anything. */
class App extends helix.App {
	static inline var ORBIT = 14;

	var level = new Node3D();
	// The snow when it falls (the presets' one-shots take themselves off once spent).
	var snow:Null<Particles3D>;
	var view:View3D;
	var camera = new Camera3D();
	var text = new Drawing2D();
	var fps = new FpsOverlay();
	var fountain:Emitter;
	var sparks:Emitter;
	var smoke:Emitter;
	var flame:Emitter;
	var confetti:Emitter;
	var sparksNode:Node3D;
	var confettiNode:Particles2D;
	var paused = false;
	// The camera, circling.
	var orbit = new Orbit3D(ORBIT, 6, .15, 3);

	function place(emitter:Emitter, x:Float, y:Float, z:Float):Node3D {
		var node = new Particles3D(emitter);
		node.setPosition(x, y, z);
		level.addChild(node);
		return node;
	}

	override public function init():Void {
		Window.title = "HeliX particles";
		Window.requestSize(1000, 600);
		Stage.color = 0xff0e1018;
		var grid = new Drawing3D();
		grid.grid(24, 1, 0xff50505a);
		level.addChild(grid);
		view = new View3D(level, camera);
		Stage.addChild(view);
		// Framed for 16:9: the fountain and the fire both in view on a phone held upright too.
		camera.minAspect = 16 / 9;

		fountain = new Emitter(null, 4096);
		fountain.rate = 1200;
		fountain.setLife(1.4, 1.9);
		fountain.setSpawnBox(.15, 0, .15);
		fountain.setVelocity(0, 9, 0, .22, .15);
		fountain.setGravity(0, -9.8, 0);
		fountain.setSize(.22, .12, .4);
		fountain.setColor(0xe696d2ff, 0x003c78ff);
		fountain.setAlphaMode(Blend);
		place(fountain, 0, .2, 0);
		fountain.prewarm(2);

		sparks = new Emitter(null, 2048);
		sparks.rate = 600;
		sparks.setLife(.5, 1.2);
		sparks.setVelocity(0, 4, 0, 1.2, .6);
		sparks.setGravity(0, -6, 0);
		sparks.drag = 1.5;
		sparks.inheritVelocity = .4;
		sparks.stretch = .04;
		sparks.setSize(.08, .02, .5);
		sparks.setColor(0xffffdc78, 0x00ff3c0a);
		sparksNode = place(sparks, 3.5, 1.5, 0);

		smoke = new Emitter(null, 512);
		smoke.rate = 30;
		smoke.setLife(3, 4.5);
		smoke.setSpawnSphere(.3);
		smoke.setVelocity(0, 1.4, 0, .35, .3);
		smoke.setGravity(.35, 0, 0);
		smoke.setSpin(-.8, .8);
		smoke.clearSizeKeys();
		smoke.addSizeKey(0, .3);
		smoke.addSizeKey(.15, 1.4);
		smoke.addSizeKey(1, 3.6);
		smoke.clearColorKeys();
		smoke.addColorKey(0, 0x00282422);
		smoke.addColorKey(.1, 0xbe322e2c);
		smoke.addColorKey(.5, 0x7882828c);
		smoke.addColorKey(1, 0x00aaaab4);
		smoke.setAlphaMode(Blend);
		place(smoke, -5, 1.5, -2);
		smoke.prewarm(5);

		flame = new Emitter(null, 1024);
		flame.setFrames(4, 4);
		flame.rate = 40;
		flame.setLife(.7, 1.1);
		flame.setSpawnSphere(.3);
		flame.setVelocity(0, 1.8, 0, .2, .3);
		flame.drag = .8;
		flame.setSpin(-1.5, 1.5);
		flame.clearSizeKeys();
		flame.addSizeKey(0, .6);
		flame.addSizeKey(.3, 1.1);
		flame.addSizeKey(1, .4);
		flame.clearColorKeys();
		flame.addColorKey(0, 0x00ffebbe);
		flame.addColorKey(.08, 0x6effebbe);
		flame.addColorKey(.25, 0x64ff9628);
		flame.addColorKey(.65, 0x3cc8320f);
		flame.addColorKey(1, 0x00500f05);
		place(flame, -5, .3, -2);
		flame.prewarm(1);

		// The confetti, flat: on the stage, in the presentation's units.
		confetti = new Emitter(null, 4096, true);
		confetti.setRegion(24, 24, 16, 16);
		confetti.setLife(1.2, 2.2);
		confetti.setVelocity(0, -420, 0, 1.3, .7);
		confetti.setGravity(0, 700, 0);
		confetti.drag = .8;
		confetti.setSize(12, 6, .5);
		confetti.setSpin(-8, 8);
		confetti.setColor(0xffffffff, 0x00ffffff);
		for (c in [0xffe62937, 0xffffcb00, 0xff00e430, 0xff66bfff, 0xff873cbe])
			confetti.addPaletteColor(c);
		confetti.setAlphaMode(Blend);
		confettiNode = new Particles2D(confetti);
		Stage.addChild(confettiNode);
		Stage.addChild(text);
		Stage.addChild(fps);

		Textures.load("textures/particle.png", Linear, texture -> dot(texture));
		Textures.load("textures/flame.png", Linear, texture -> flame.texture = texture);
	}

	// The particle texture in: every emitter but the flame draws it, and a first burst of confetti shows it.
	function dot(texture:Texture2D):Void {
		for (e in [fountain, sparks, smoke, confetti])
			e.texture = texture;
		burst(Screen.visibleX + Screen.visibleWidth / 2, Screen.visibleY + Screen.visibleHeight / 3);
	}

	// A burst of confetti at x, y units: no trail from where the last one was.
	function burst(x:Float, y:Float):Void {
		confettiNode.setPosition(x, y);
		confetti.jump(x, y, 0);
		confetti.burst(300);
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		if (Input.isFramePressed(Key.Space)) {
			paused = !paused;
			for (e in [fountain, sparks, smoke, flame])
				e.emitting = !paused;
		}
		// The presets: a one-shot each key, off the level once it's spent; snow on and off.
		var presets = [
			size -> Particles3D.explosion(size),
			size -> Particles3D.smokePuff(size),
			size -> Particles3D.sparks(size),
			size -> Particles3D.dust(size),
			size -> Particles3D.confetti(size)
		];
		for (i in 0...presets.length)
			if (Input.isFramePressed([Key.Digit1, Key.Digit2, Key.Digit3, Key.Digit4, Key.Digit5][i])) {
				var shot = presets[i](2);
				shot.setPosition(3, .1, 3);
				level.addChild(shot);
			}
		if (Input.isFramePressed(Key.Digit6)) {
			if (snow == null) {
				snow = Particles3D.snow(16);
				snow.setPosition(0, 8, 0);
				level.addChild(snow);
			} else {
				level.removeChild(snow);
				snow = null;
			}
		}
		if (Input.isFramePressed(Key.O))
			orbit.running = !orbit.running;
		// The HUD and the confetti in the design for the window's shape; the pointer comes back in its units.
		ScreenShape.update();
		if (Input.pointerFramePressed)
			burst(Screen.toUnitsX(Input.pointerX), Screen.toUnitsY(Input.pointerY));
		// The game's clock: paused, the motion stops.
		var time = Time.clock.time;
		orbit.update(dt);
		// The sparks' source circles the fountain; the sparks stay where they were born.
		sparksNode.setPosition(3.5 * Math.cos(time * 1.3), 1.5 + .8 * Math.sin(time * 2.1), 3.5 * Math.sin(time * 1.3));
		fps.update(dt, Time.frameCpu);
		orbit.apply(camera);
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		var title = "HeliX particles";
		text.clear();
		var y = vy + 36;
		y += text.drawTextWrapped(title, vx + 12, y, 24, vw - 24, 0xfff5f5f5) + 4;
		text.drawTextWrapped('click / tap: confetti   1-5: presets   6: snow   space: ${paused ? "resume" : "pause"}   O: the camera   ${view.drawCallCount} draws',
			vx
			+ 12,
			y, 16, vw
			- 24, 0xffc8c8c8);
		fps.setPosition(vx + 12, vy + 10);
	}

	override public function cleanup():Void
		view.destroy();
}
