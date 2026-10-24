import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.ScreenShape;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.AnimationDirection2D;
import helix.render2d.Camera2D;
import helix.render2d.Drawing2D;
import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.render2d.SpriteAnimator2D;
import helix.render2d.SpriteSheet2D;
import helix.render2d.Stage;
import helix.render2d.View2D;
import helix.time.Time;

/** A sprite sheet (the shared sheets/gizmos.json and .png, TexturePacker's JSON Hash, made by tools/gen_sprite_sheet.py: trimmed frames, five of them
	packed turned a quarter) and its animations, found from the frames' numbered names ("walk_01.png": "walk"):
	- a blob walking in low hops, a Sprite2D a SpriteAnimator2D shows its frames on, walking to and fro: facing its way by a negative x scale,
	  its feet on the ground by its frames' pivot
	- gears, Sprite2Ds shown a frame by setFrame with no animator of their own, following one SpriteAnimator2D: one bigger and turned as a whole
	- the sheet's texture beside them, an image in a Drawing2D, the blob's frame boxed in it (a turned frame's box is tall where the frame is
	  wide)
	The world is in framebuffer pixels, shown by a View2D; the text is on the stage.
	Space pauses, the up and down arrows change the speed, P plays the walk back and forth (an animation added by frame, PingPong). Escape quits
	where quitting means anything. */
class App extends helix.App {
	static inline var SCALE = 4.;

	// The world, in framebuffer pixels: the ground, the blob, the gears and the sheet, in that order.
	var world = new Node2D();
	var camera = new Camera2D();
	var groundLine = new Drawing2D();
	var sheetImage = new Drawing2D();
	var hud = new Drawing2D();
	var fps = new FpsOverlay();
	var sheet:Null<SpriteSheet2D>;
	var blob = new Sprite2D(null);
	var gear = new Sprite2D(null);
	var bigGear = new Sprite2D(null);
	var blobs:Null<SpriteAnimator2D>;
	var gears:Null<SpriteAnimator2D>;
	var walk = 0.;
	var heading = 1.;
	var paused = false;
	var pingPong = false;
	var failure:Null<String>;

	override public function init():Void {
		Window.title = "HeliX sprite-sheet";
		for (sprite in [blob, gear, bigGear])
			sprite.setPivot(.5, .5);
		Window.requestSize(960, 600);
		Stage.color = 0xff1d2230;
		blob.setScale(SCALE, SCALE);
		gear.setScale(SCALE, SCALE);
		bigGear.setScale(SCALE * 1.5, SCALE * 1.5);
		// Hidden until the sheet is in: a sprite with no texture would draw as a plain square.
		gear.visible = bigGear.visible = false;
		world.addChild(groundLine);
		world.addChild(blob);
		world.addChild(gear);
		world.addChild(bigGear);
		world.addChild(sheetImage);
		Stage.addChild(new View2D(world, camera));
		Stage.addChild(hud);
		Stage.addChild(fps);
		SpriteSheet2D.load("sheets/gizmos.json", loaded -> {
			sheet = loaded;
			var frames = loaded.findAnimation("walk").frames;
			loaded.addAnimation("walk-pingpong", frames, AnimationDirection2D.PingPong);
			blobs = new SpriteAnimator2D(loaded, blob);
			blobs.play("walk");
			gears = new SpriteAnimator2D(loaded);
			gears.play("gear");
		}, message -> failure = message);
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		fps.update(dt, Time.frameCpu);
		var width = Window.framebufferWidth, height = Window.framebufferHeight;
		// A world unit a framebuffer pixel, from the window's top-left.
		camera.zoom = 1;
		camera.setPosition(width / 2, height / 2);
		ScreenShape.update();

		var speed = blobs == null ? 1. : blobs.speed;
		if (Input.isFramePressed(Key.Space))
			paused = !paused;
		if (Input.isFramePressed(Key.Up))
			speed = Math.min(4, speed * 2);
		if (Input.isFramePressed(Key.Down))
			speed = Math.max(.125, speed / 2);
		if (Input.isFramePressed(Key.P) && blobs != null) {
			pingPong = !pingPong;
			blobs.play(pingPong ? "walk-pingpong" : "walk");
		}
		var step = paused ? 0. : dt;
		if (blobs != null) {
			blobs.speed = speed;
			gears.speed = speed;
			blobs.update(step);
			gears.update(step);
		}
		// To and fro along the ground, turning at the ends: a negative x scale faces it the other way about its pivot.
		var ground = height * .62, left = width * .1, right = width * .55;
		walk += heading * 60 * speed * step;
		if (walk > right - left || walk < 0)
			heading = -heading;
		walk = Math.max(0, Math.min(right - left, walk));
		blob.setPosition(left + walk, ground);
		blob.scaleX = heading * SCALE;
		groundLine.clear();
		groundLine.rect(0, ground, width, 2, 0xff4a5468);
		sheetImage.clear();
		if (sheet != null) {
			// The gears: the animated frame on both, one bigger and turned as a whole.
			gear.visible = bigGear.visible = true;
			gear.setFrame(sheet, gears.frame);
			gear.setPosition(width * .2, height * .25);
			bigGear.setFrame(sheet, gears.frame);
			bigGear.setPosition(width * .4, height * .25);
			bigGear.rotation = Time.time * .5;
			// The sheet itself, the blob's frame boxed where it's packed.
			var t = sheet.texture, sx = width * .66, sy = height * .12, s = 2.;
			sheetImage.rect(sx, sy, t.width * s, t.height * s, 0xff2a3142);
			sheetImage.image(t, sx, sy, t.width * s, t.height * s);
			var f = sheet.getFrame(blobs.frame);
			var fw = f.rotated ? f.height : f.width,
				fh = f.rotated ? f.width : f.height;
			sheetImage.frame(sx + f.x * s, sy + f.y * s, fw * s, fh * s, 1, 0xffffd040);
		}
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		var status = failure != null ? 'failed: $failure' : sheet == null ? "loading" : {
			var f = sheet.getFrame(blobs.frame);
			'walk frame ${blobs.frameIndex + 1} of ${blobs.animation.frames.length}: ${f.name}, ${f.width} x ${f.height} of ${f.sourceWidth} x ${f.sourceHeight}${f.rotated ? ", packed turned" : ""}';
		};
		hud.clear();
		hud.drawText("HeliX sprite-sheet: TexturePacker's JSON, trimmed and turned frames, animations", vx + 20, vy + 20, 20, 0xffebeef5);
		hud.drawText(status, vx + 20, vy + 46, 15, 0xff8c929e);
		hud.drawText('speed ${speed}x${paused ? " (paused)" : ""}   ${pingPong ? "back and forth" : "forward"}   space pause, up/down speed, P back and forth',
			vx + 20, vy + 66, 15, 0xff8c929e);
		fps.setPosition(vx + vw - 150, vy + 4);
	}

	override public function cleanup():Void {
		if (sheet != null)
			sheet.destroy();
	}
}
