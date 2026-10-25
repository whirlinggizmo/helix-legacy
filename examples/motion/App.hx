import helix.collision.Collide2D;
import helix.debug.FpsOverlay;
import helix.graphics.Color;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.math.Curve;
import helix.math.Random;
import helix.render2d.Drawing2D;
import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.ShapeShading2D;
import helix.render2d.Stage;
import helix.render2d.Text2D;
import helix.time.Time;
import helix.time.Timers;
import helix.tween.Ease;
import helix.tween.Tweens;
import helix.host.ScreenShape;

/** Motion from the game's clock (Time.clock), moving nodes on the stage: a column of squares each tweened across by one easing and back (yoyo, for ever); a ball
	following a closed curve through points at a steady speed (Curve, by distance); a timer dropping a spark every half second that falls and
	fades by two tweens onto a floor (counted there by Collide2D); and the squares' colors dealt by a seeded Random. Space pauses the clock,
	which stops all of it at once; - and = slow and quicken it; R deals the colors again from the seed. Escape quits where quitting means
	anything. */
class App extends helix.App {
	static var EASES:Array<{name:String, f:Float->Float}> = [
		{name: "linear", f: t -> Ease.linear(t)},
		{name: "quadInOut", f: t -> Ease.quadInOut(t)},
		{name: "cubicOut", f: t -> Ease.cubicOut(t)},
		{name: "sineInOut", f: t -> Ease.sineInOut(t)},
		{name: "expoOut", f: t -> Ease.expoOut(t)},
		{name: "backOut", f: t -> Ease.backOut(t)},
		{name: "elasticOut", f: t -> Ease.elasticOut(t)},
		{name: "bounceOut", f: t -> Ease.bounceOut(t)}
	];
	static var COLORS = [
		0xffe62937,
		0xffe8a33c,
		0xffffcb00,
		0xff2fa36b,
		0xff66bfff,
		0xff5a7bff,
		0xffc87aff,
		0xfff5f5f5
	];
	static inline var FLOOR_WIDTH = 360;
	static inline var FLOOR_Y = 200;

	// What moves, under the text.
	var field = new Node2D();
	var text = new Drawing2D();
	var fps = new FpsOverlay();
	var tweens = new Tweens();
	var timers = new Timers();
	var random = new Random(7);
	var squares:Array<Shape2D> = [];
	var labels:Array<Text2D> = [];
	// Each square's tweened offset across, 0 to 300, placed from the column's left each frame.
	var offsets:Array<Float> = [];
	var ball:Shape2D;
	var path:Shape2D;
	var floor:Shape2D;
	var curve:Curve;
	var along = 0.;
	var sparks:Array<Spark> = [];
	var caught = 0;

	override public function init():Void {
		Window.title = "HeliX motion";
		Window.requestSize(1000, 600);
		Stage.color = 0xff0c0e16;
		Stage.addChild(field);
		// A square a row, each tweened from 0 to 300 across and back by its easing, for ever, a little apart in time.
		for (i in 0...EASES.length) {
			var square = Shape2D.rectangle(24, 24, COLORS[i]);
			square.setPivot(.5, .5);
			square.cornerRadius = 4;
			field.addChild(square);
			squares.push(square);
			offsets.push(0);
			var label = new Text2D(EASES[i].name, 13, 0xff8a92a8);
			field.addChild(label);
			labels.push(label);
			var tween = tweens.to(0, 300, 1.6, EASES[i].f, x -> offsets[i] = x);
			tween.setRepeat(-1, true);
			tween.setDelay(i * .1);
		}
		// A closed path through five points, drawn from 80 samples, and a ball along it at 160 units a second.
		curve = Curve.through([0, 0, 180, -60, 300, 40, 200, 160, 40, 120], 2, true);
		var samples = [];
		for (i in 0...80) {
			samples.push(curve.getX(i / 80));
			samples.push(curve.getY(i / 80));
		}
		path = Shape2D.polygon(samples);
		path.outline = 1;
		path.color = 0xff3a4150;
		field.addChild(path);
		ball = Shape2D.circle(12, 0xff66bfff);
		field.addChild(ball);
		floor = Shape2D.rectangle(FLOOR_WIDTH, 6, 0xff3a4150);
		field.addChild(floor);
		// Every half second, a spark: it falls by a tween (bounceOut onto the floor) and fades by another, gone when faded.
		timers.every(.5, () -> {
			var spark = new Spark(Shape2D.circle(5, random.pick(COLORS)), random.nextRange(10, FLOOR_WIDTH - 10));
			field.addChild(spark.node);
			sparks.push(spark);
			tweens.to(0, FLOOR_Y - 4, 1.2, t -> Ease.bounceOut(t), y -> spark.y = y);
			var fade = tweens.to(1, 0, 2.5, t -> Ease.quadIn(t), a -> spark.alpha = a);
			fade.setComplete(() -> {
				field.removeChild(spark.node);
				sparks.remove(spark);
			});
		});
		// The text over what moves.
		Stage.addChild(text);
		Stage.addChild(fps);
		deal();
	}

	// The squares' colors dealt from the seed: the same deal each time.
	function deal():Void {
		random.seed = 7;
		var dealt = random.shuffle(COLORS.copy());
		for (i in 0...squares.length)
			squares[i].color = dealt[i];
	}

	override public function update(dt:Float):Void {
		var clock = Time.clock;
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		if (Input.isFramePressed(Key.Space))
			if (clock.paused)
				clock.resume();
			else
				clock.pause();
		if (Input.isFramePressed(Key.Minus))
			clock.timeScale = Math.max(.125, clock.timeScale / 2);
		if (Input.isFramePressed(Key.Equal))
			clock.timeScale = Math.min(4, clock.timeScale * 2);
		if (Input.isFramePressed(Key.R))
			deal();
		// Everything moves by the clock's delta: paused, it all stops.
		tweens.update(clock.delta);
		timers.update(clock.delta);
		along += clock.delta * 160;
		var t = curve.getParameterAtDistance(along);
		fps.update(dt, Time.frameCpu);

		// Laid out in the design for the window's shape: the squares down the left, the path and the floor on the right (below, upright).
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		var upright = Screen.portrait;
		var left = vx + 120, top = vy + 100;
		for (i in 0...squares.length) {
			var y = top + i * 40;
			squares[i].setPosition(left + offsets[i], y);
			labels[i].setPosition(vx + 16, y - 7);
		}
		var rightX = upright ? vx + vw / 2 - 150 : vx + vw - 380,
			rightY = upright ? top + 8 * 40 + 70 : top + 20;
		path.setPosition(rightX, rightY);
		ball.setPosition(rightX + curve.getX(t), rightY + curve.getY(t));
		var floorX = upright ? rightX - 30 : rightX - 30,
			floorY = rightY + FLOOR_Y;
		floor.setPosition(floorX, floorY);
		caught = 0;
		for (spark in sparks) {
			spark.node.setPosition(floorX + spark.x, floorY - FLOOR_Y + spark.y);
			spark.node.color = Color.withAlpha(spark.color, Math.round(spark.alpha * 255));
			// On the floor: a circle against the floor's rectangle.
			if (Collide2D.isCircleOverlappingRect(spark.node.x, spark.node.y, 5, floorX, floorY, FLOOR_WIDTH, 6))
				caught++;
		}

		var title = "HeliX motion: tweens, timers, a curve and the clock";
		text.clear();
		var y = vy + 36;
		y += text.drawTextWrapped(title, vx + 12, y, 20, vw - 24, 0xfff5f5f5) + 3;
		text.drawTextWrapped('Space: ${clock.paused ? "resume" : "pause"}   - =: time x${clock.timeScale}   R: deal again   ${sparks.length} sparks, $caught on the floor   clock ${Math.round(clock.time * 10) / 10} s',
			vx
			+ 12, y, 15, vw
			- 24, 0xffc8c8c8);
		fps.setPosition(vx + 12, vy + 10);
	}
}

/** A falling spark: its node, where it is from the floor's left and top, and how faded. */
private class Spark {
	/** Its circle. */
	public final node:Shape2D;

	/** Across the floor. */
	public final x:Float;

	/** Down from the floor's top edge less FLOOR_Y, tweened. */
	public var y = 0.;

	/** 1 bright to 0 gone, tweened. */
	public var alpha = 1.;

	/** Its color, with the alpha applied each frame. */
	public final color:Int;

	/** A spark drawn by node at x across. */
	public function new(node:Shape2D, x:Float) {
		this.node = node;
		this.x = x;
		color = node.color;
	}
}
