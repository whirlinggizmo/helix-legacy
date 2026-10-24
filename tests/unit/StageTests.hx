import Render2DTests.CountingGraphics;
import helix.host.Presentation;
import helix.render2d.Shape2D;
import helix.render2d.StageService;

/** The stage (helix.render2d.StageService): a frame drawn whole, cleared to its color, its children in order through the presentation's
	camera; children added (again: to the top) and taken off; nothing drawn of an empty stage but the clear;
	a paused node's emitter held still. */
@:access(helix)
class StageTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function main():Void {
		var gpu = new CountingGraphics(), presentation = new Presentation();
		@:privateAccess presentation.refit(800, 600, 1);
		var stage = new StageService(gpu, presentation);
		stage.draw(0);
		check(gpu.framesEnded == 1 && gpu.clearColor == 0xff000000 && gpu.draws.length == 0, "An empty stage: the frame cleared to black, nothing drawn");
		var back = Shape2D.rectangle(100, 50, 0xff102030),
			front = Shape2D.circle(10, 0xff66bfff);
		stage.addChild(back);
		stage.addChild(front);
		check(stage.childCount == 2, "Children added");
		stage.addChild(back);
		check(stage.childCount == 2 && stage.getChild(1) == back && stage.getChild(0) == front && stage.getChild(2) == null,
			"A child added again: moved to the top, as Flash's addChild does");
		// Found by name and kind, anywhere on the stage; put under the rest by addChildAt.
		var label = new helix.render2d.Text2D("Score", 12, 0xffffffff),
			group = new helix.render2d.Node2D();
		label.name = "score";
		group.addChild(label);
		stage.addChildAt(group, 0);
		check(stage.getChild(0) == group && stage.getChild(1) == front && stage.childCount == 3, "addChildAt(0): drawn under the rest");
		check(stage.find("score", helix.render2d.Text2D) == label && stage.find("score", helix.render2d.Node2D) == label,
			"Found below the stage's children, as its kind or any 2D node");
		check(stage.find("score", Shape2D) == null
			&& stage.find("nothing", helix.render2d.Node2D) == null, "Of another kind, or not there: null");
		stage.removeChild(group);
		stage.color = 0xff14161c;
		stage.draw(0);
		check(gpu.framesEnded == 2 && gpu.clearColor == 0xff14161c, "Cleared to the stage's color");
		check(gpu.draws.length > 0 && stage.drawnNodeCount == 2, "Its children drawn");
		check(stage.removeChild(back) && stage.childCount == 1 && !stage.removeChild(back), "A child taken off, once");
		stage.draw(0);
		check(stage.drawnNodeCount == 1, "What's left drawn");
		// A drawing: calls kept and drawn where the node is, cleared; picked by the box around them.
		var drawing = new helix.render2d.Drawing2D();
		drawing.rect(0, 0, 40, 20, 0xffff0000);
		drawing.circle(60, 10, 10, 0xff00ff00);
		drawing.line(0, 30, 70, 30, 2, 0xffffffff);
		check(drawing.callCount == 3 && drawing.polygon([0, 0, 10, 0], 0xffffffff) == false && drawing.callCount == 3,
			"Calls kept; a polygon of two points refused");
		drawing.setPosition(500, 400);
		stage.addChild(drawing);
		stage.draw(0);
		check(stage.drawnNodeCount == 2 && @:privateAccess drawing.holds(65, 12, null) && ! @:privateAccess drawing.holds(200, 200, null),
			"Drawn, and its box holds what it drew");
		drawing.clear();
		check(drawing.callCount == 0 && ! @:privateAccess drawing.holds(5, 5, null), "Cleared");
		stage.removeChild(drawing);
		// Alpha: a group's fades its children, multiplied down the tree, as the batch writes their colors.
		var group = new helix.render2d.Node2D(),
			dot = Shape2D.circle(5, 0xffffffff);
		group.alpha = .5;
		dot.alpha = .5;
		group.addChild(dot);
		check(group.alpha == .5 && (dot.alpha = 3) == 1 && dot.alpha == 1, "Alpha clamped to 0..1");
		dot.alpha = .5;
		stage.addChild(group);
		var batch = new helix.render2d.Batch2D(gpu),
			cam = new helix.render2d.Camera2D();
		cam.setViewport(800, 600);
		cam.pixels(1);
		gpu.beginFrame(800, 600, 0);
		batch.begin(cam);
		@:privateAccess stage.tree.draw(batch, cam);
		var data:haxe.io.Bytes = @:privateAccess batch.data;
		var last = @:privateAccess batch.vertices - 1,
			vertexAlpha = data.getFloat(last * Sprite2DProgram.stride + Sprite2DProgram.colorOffset + 12);
		check(Math.abs(vertexAlpha - .25) < 1e-5 && batch.alpha == 1, "The dot drawn at a quarter alpha (a half of a half); the batch's alpha put back");
		batch.end();
		batch.destroy();
		stage.removeChild(group);
		// A paused node holds its emitters still, still drawn.
		var sparks = new helix.particle.Emitter(null),
			node = new helix.render2d.Particles2D(sparks);
		sparks.rate = 100;
		sparks.setLife(10, 10);
		stage.addChild(node);
		stage.draw(0);
		stage.draw(1);
		var made = sparks.particleCount;
		check(made > 0, "An emitter on the stage moves on with the clock");
		node.paused = true;
		stage.draw(2);
		check(sparks.particleCount == made && stage.drawnNodeCount == 2, "Paused: held as it is, still drawn");
		node.paused = false;
		stage.draw(3);
		check(sparks.particleCount > made, "Unpaused: on again");
		stage.destroy();
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}
}
