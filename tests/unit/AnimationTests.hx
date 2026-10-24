import Render2DTests.CountingGraphics;
import haxe.ds.Vector;
import helix.render3d.AnimationClip3D;
import helix.render3d.TrackPath3D;
import helix.render3d.TrackInterpolation3D;
import helix.render3d.Track3D;
import helix.render3d.Animator3D;
import helix.render3d.Camera3D;
import helix.render3d.Gltf;
import helix.render3d.JointPalette3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.ModelFile3D;
import helix.render3d.ImageSource3D;
import helix.render3d.Node3D;
import helix.render3d.Skin3D;
import helix.render3d.Renderer3D;

/** Skinning and skeletal animation: tracks' sampling, skins and clips read from glTF (Quaternius's modular women, the animation example's),
	the Animator3D's binding, refusal and crossfade, joint matrices, and a posed model's culling box. */
@:access(helix)
class AnimationTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float):Bool
		return Math.abs(a - b) < 1e-5;

	static function file(name:String):ModelFile3D
		return @:privateAccess new ModelFile3D(Gltf.read(sys.io.File.getBytes('examples/assets/models/modular-women/$name.glb')));

	public static function main():Void {
		tracks();
		weights();
		files();
		animator();
		joints();
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}

	static function tracks():Void {
		var out = new Vector<Float>(4);
		var move = new Track3D("a", Translation, Linear, [0, 1], [0, 0, 0, 10, 20, 30]);
		move.sample(.25, out);
		check(near(out[0], 2.5) && near(out[1], 5) && near(out[2], 7.5), "Linear between keys");
		move.sample(-1, out);
		check(out[0] == 0, "Held before the first key");
		move.sample(5, out);
		check(out[0] == 10, "Held after the last");
		var step = new Track3D("a", Translation, Step, [0, 1], [0, 0, 0, 10, 0, 0]);
		step.sample(.99, out);
		check(out[0] == 0, "A step holds until the next key");
		// A cubic spline with flat tangents eases: a quarter of the way in time is less than a quarter of the way.
		var cubic = new Track3D("a", Translation, CubicSpline, [0, 1], [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 10, 0, 0, 0, 0, 0]);
		cubic.sample(.25, out);
		check(near(out[0], 10 * (3 * .0625 - 2 * .015625)), "A cubic spline through its values, flat tangents");
		// q and -q are one rotation: halfway takes the short way, and stays normalized.
		var s = Math.sqrt(.5);
		var turn = new Track3D("a", Rotation, Linear, [0, 1], [0, 0, 0, 1, 0, -s, 0, -s]);
		turn.sample(.5, out);
		var length = Math.sqrt(out[0] * out[0] + out[1] * out[1] + out[2] * out[2] + out[3] * out[3]);
		check(near(length, 1) && Math.abs(out[1]) < Math.abs(out[3]), "Rotation slerps the short way, normalized");
		var threw = try {
			new Track3D("a", Translation, Linear, [0, 1], [0, 0, 0]);
			false;
		} catch (_:Dynamic)
			true;
		check(threw, "Values that don't match the times throw");
	}

	static function weights():Void {
		// One triangle, its first vertex weighted .25 to joint 1 alone (normalized to 1), its second unweighted (follows joint 0).
		var mesh = Mesh3D.fromArrays([0, 0, 0, 1, 0, 0, 0, 1, 0], null, null, null, null, [1, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0],
			[.25, 0, 0, 0, 0, 0, 0, 0, .5, .5, 0, 0]);
		var skin = mesh.skinData;
		check(skin.getFloat(Skinned3DProgram.weightsOffset) == 1, "Weights normalized to sum to 1");
		check(skin.getFloat(Skinned3DProgram.skinStride + Skinned3DProgram.weightsOffset) == 1, "An unweighted vertex follows its first joint");
		check(skin.getFloat(2 * Skinned3DProgram.skinStride + Skinned3DProgram.weightsOffset + 4) == .5, "Split weights kept");
	}

	static function files():Void {
		var animations = file("Animations");
		check(animations.clips.length == 24 && animations.skins.length == 1, "24 clips and the skeleton's skin");
		var walk = animations.getClip("Walk");
		check(walk != null && walk.name == "CharacterArmature|Walk" && animations.getClip("CharacterArmature|Walk") == walk,
			"A clip found by the part after | or its whole name");
		check(animations.getClip("Moonwalk") == null && walk.duration > 0, "None for an unknown name; a length");
		var body = file("Casual_Body");
		check(body.warnings.length == 0, "Skins read without warnings: " + body.warnings.join("; "));
		var a = body.instantiate("a"), b = body.instantiate("b");
		// A node with a mesh is one model, its primitives its parts.
		var modelA = a.find("Casual_Body", Model3D),
			modelB = b.find("Casual_Body", Model3D);
		check(modelA != null && modelB != null && modelA.partCount > 0, "The file's skinned node is a model");
		if (modelA == null || modelB == null)
			return;
		check(modelA.jointCount == 62 && modelA.skin.getJointName(0) != "", "Each copy's skinned model bound to its 62 joints");
		check(modelA.getJoint(0) != modelB.getJoint(0) && modelA.getJoint(5) == a.find(modelA.skin.getJointName(5), Node3D),
			"Each copy follows its own skeleton");
		// Gear from another file binds to a skeleton by name; one asking for a joint the skeleton hasn't is refused.
		var skeleton = animations.instantiate("character");
		check(modelB.bindSkeleton(skeleton) && modelB.getJoint(3) == skeleton.find(modelB.skin.getJointName(3), Node3D),
			"A part binds to another file's skeleton by joint name");
		var partial = new Skin3D(["Hips", "NoSuchBone"]);
		check(!modelB.bindSkeleton(skeleton, partial) && modelB.jointCount == 62, "A missing joint is refused, the binding kept");
	}

	static function animator():Void {
		// A root "a" holding "b": clip one puts b at x 0, clip two at x 10; clip three moves only a.
		var a = new Node3D(), b = new Node3D();
		a.name = "a";
		b.name = "b";
		a.addChild(b);
		b.setPosition(2, 0, 0);
		var one = new AnimationClip3D("one", [new Track3D("b", Translation, Linear, [0, 1], [0, 0, 0, 0, 0, 0])]);
		var two = new AnimationClip3D("two", [new Track3D("b", Translation, Linear, [0, 1], [10, 0, 0, 10, 0, 0])]);
		var three = new AnimationClip3D("three", [new Track3D("a", Translation, Linear, [0, 1], [0, 5, 0, 0, 5, 0])]);
		var ghost = new AnimationClip3D("ghost", [new Track3D("nobody", Translation, Linear, [0], [0, 0, 0])]);
		var animator = new Animator3D(a);
		check(!animator.play(ghost) && animator.clip == null, "A clip moving a node the root hasn't is refused");
		check(animator.play(one), "A clip binds by name");
		animator.update(.1);
		check(b.x == 0, "Posed by the clip");
		check(animator.play(two, true, 1), "Crossfades over a second");
		animator.update(.5);
		check(near(b.x, 5) && animator.fading, "Halfway through the fade, halfway between the clips");
		animator.update(.6);
		check(b.x == 10 && !animator.fading, "The fade ends on the new clip");
		// Into a clip that doesn't move b: b blends back to its rest (x 2, where it was first bound), a to its new place.
		animator.play(three, true, 1);
		animator.update(.5);
		check(near(b.x, 6) && near(a.y, 2.5), "A node the new clip doesn't move fades to its rest");
		animator.play(one, false);
		animator.update(5);
		check(animator.finished && animator.time == 1, "A clip that doesn't loop holds at its end");
		check(animator.play(two) && animator.setTime(2.5) && near(animator.time, .5), "A looping clip's time wraps");
		check(!animator.play(two, true, -1), "A negative fade is refused");
		animator.speed = Math.NaN;
		check(animator.speed == 0, "A speed not finite is taken as 0");
		// A queued clip: it waits for a one-shot's end, then fades in from its last frame; play and stop drop it; behind a loop it waits.
		var queuer = new Animator3D(a);
		check(queuer.queue(two) && queuer.clip == two && queuer.queued == null, "Queued with nothing playing, it plays at once");
		queuer.play(one, false);
		check(queuer.queue(two, true, .5) && queuer.queued == two && !queuer.queue(ghost) && queuer.queued == two,
			"A clip waits behind a one-shot; one play refuses is refused");
		queuer.update(.5);
		check(queuer.clip == one && b.x == 0, "The one-shot plays on");
		queuer.update(.6);
		check(queuer.clip == two && queuer.queued == null && queuer.fading && b.x == 0, "At its end the queued clip starts, from the end's pose");
		queuer.update(.25);
		check(near(b.x, 5), "Fading in over its seconds");
		queuer.update(.3);
		check(b.x == 10 && !queuer.fading, "Then playing alone");
		check(queuer.queue(one) && queuer.queued == one, "Behind a loop a clip is queued");
		queuer.update(5);
		check(queuer.clip == two && queuer.queued == one, "And waits, as a loop doesn't end");
		queuer.play(three);
		check(queuer.queued == null, "play drops it");
		queuer.play(one, false);
		queuer.queue(two);
		queuer.stop();
		check(queuer.queued == null && queuer.clip == null, "As stop does");
		queuer.play(one, false);
		queuer.update(2);
		check(queuer.queue(three) && queuer.clip == three, "Behind a finished one-shot it plays at once");
	}

	static function joints():Void {
		// A strip from x 0 to 2 along two joints: joint 0 at the origin weighting x <= 1, joint 1 at x 1 weighting beyond, bound in place.
		var positions = [0., 0, 0, 1, 0, 0, 0, 1, 0, 1, 0, 0, 2, 0, 0, 1, 1, 0];
		var mesh = Mesh3D.fromArrays(positions, null, null, null, null, [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0],
			[1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0]);
		// Joint 1's inverse bind takes the mesh's space to the joint's: a move of -1 along x.
		var skin = new Skin3D(["hip", "knee"], [
			1., 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -1, 0, 0, 1
		]);
		check(near(skin.getBindPosition(1, 0), 1) && near(skin.getBindPosition(0, 0), 0), "A joint's bind position, its inverse bind's inverse");
		var reach = mesh.getJointReach(skin);
		check(near(reach[0], 1) && near(reach[1], 1), "Each joint reaches as far as the vertices it weights");
		var gpu = new CountingGraphics(), stage = new Renderer3D(gpu);
		var character = new Node3D(), hip = new Node3D(), knee = new Node3D();
		hip.name = "hip";
		knee.name = "knee";
		knee.setPosition(1, 0, 0);
		hip.addChild(knee);
		character.addChild(hip);
		var model = new Model3D(mesh, new Material3D());
		character.addChild(model);
		check(model.bindSkeleton(character, skin) && model.jointCount == 2, "Bound to its joints");
		stage.add(character);
		// The knee swung far out of the bind pose's box, out to x 40: the posed box follows it.
		knee.setPosition(40, 0, 0);
		var view = new Camera3D();
		view.setViewport(800, 600);
		view.setView(40, 0, 10, 40, 0, 0);
		gpu.beginFrame(800, 600, 0);
		stage.draw(view);
		check(stage.drawnNodeCount == 1, "A model posed out of its rest box is drawn where its joints are");
		var palette:JointPalette3D = @:privateAccess stage.palette,
			data = @:privateAccess palette.data;
		// Joint 1's matrix: the model's space moved to the knee at x 40, its inverse bind's -1 applied: x + 39.
		check(palette.jointCount == 2 && near(data.getFloat(48 + 12), 39) && near(data.getFloat(48), 1) && near(data.getFloat(12), 0),
			"Joint matrices: inverse(model) x joint x inverse bind, their top rows");
		var record = @:privateAccess stage.records;
		check(record.getFloat(Lit3DProgram.normal2Offset + 12) == 0, "The model's first joint in its record");
		var box = new Vector<Float>(6);
		check(JointPalette3D.computePosedBox(model, model.mesh, box)
			&& box[0] + box[3] > 41
			&& box[0] - box[3] < 0, "The posed box holds both joints' reach");
		var bounds = new helix.math.Bounds3D();
		check(model.computeBounds(bounds) != null && near(bounds.minX, 0) && near(bounds.maxX, 41) && near(bounds.minY, 0) && near(bounds.maxY, 1)
			&& near(bounds.minZ, 0) && near(bounds.maxZ, 0),
			"The world bounds are the vertices as posed: the knee's out at 40 and 41");
		// The model moved far off while its joints stay: it draws where its joints are, so nothing is drawn there.
		knee.setPosition(1, 0, 0);
		model.setPosition(500, 0, 0);
		view.setView(500, 0, 10, 500, 0, 0);
		stage.draw(view);
		check(stage.drawnNodeCount == 0, "A skinned model's own placement doesn't move it: its joints do");
		check(model.computeBounds(bounds) != null && near(bounds.minX, 0) && near(bounds.maxX, 2), "Nor its world bounds: back in its bind pose, 0 to 2");
	}
}
