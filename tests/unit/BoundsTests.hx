import helix.math.Bounds2D;
import helix.math.Bounds3D;
import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render3d.Material3D;
import helix.render3d.Mat4;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.Node3D;
import helix.render3d.Sprite3D;

/** Bounds (helix.math.Bounds2D, Bounds3D) and what's measured into them: a 2D tree's (Node2D.computeBounds), each kind by its own box placed
	by the transforms as they are now, in the world or relative to a node; a 3D tree's (Node3D.computeBounds), models by their vertices and
	sprites by the sphere their quad turns in; hidden and disabled nodes left out; a given out filled and returned, null for nothing. */
class BoundsTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float):Bool
		return Math.abs(a - b) < 1e-6;

	static function main():Void {
		// The types themselves.
		var b = new Bounds2D();
		check(b.isEmpty && b.width == 0 && Math.isNaN(b.centerX), "Made empty: no size, no center");
		b.expand(2, 3);
		check(!b.isEmpty && b.minX == 2 && b.maxX == 2 && b.width == 0, "A first point makes it that point");
		b.expand(-1, 7);
		check(b.minX == -1 && b.maxY == 7 && b.width == 3 && b.height == 4 && b.centerX == .5 && b.centerY == 5, "Expanded by a second");
		check(b.contains(0, 4) && b.contains(-1, 7) && !b.contains(3, 4), "Holds its inside and faces, not what's past them");
		var other = new Bounds2D().set(1, 6, 9, 9);
		check(b.intersects(other) && !b.intersects(new Bounds2D()) && !new Bounds2D().intersects(b), "Overlaps another; never an empty one");
		check(b.union(other).maxX == 9 && b.union(new Bounds2D()).maxX == 9, "A union grows to hold both; an empty one changes nothing");
		var c = new Bounds3D().set(0, 0, 0, 1, 2, 3);
		check(c.depth == 3 && c.centerZ == 1.5 && c.clear().isEmpty, "3D: a depth, a center on z, and cleared");

		// 2D: a rectangle pivoted at its center, under a parent moved, turned a quarter and doubled.
		var group = new Node2D(),
			panel = new Node2D(),
			rect = Shape2D.rectangle(10, 4, 0xffffffff);
		rect.setPivot(.5, .5);
		group.setPosition(100, 50);
		group.rotation = Math.PI / 2;
		group.setScale(2, 2);
		group.addChild(rect);
		var world = group.computeBounds();
		check(world != null && near(world.minX, 96) && near(world.maxX, 104) && near(world.minY, 40) && near(world.maxY, 60),
			"A child's box placed by its parent's turn and scale, as they are now");
		var scratch = new Bounds2D();
		check(group.computeBounds(scratch) == scratch
			&& near(scratch.minX, 96), "The world into a given one, returned: relativeTo skipped");
		check(near(group.computeBounds(group).minX, -5) && near(group.computeBounds(group).maxY, 2), "Relative to itself: its own units");
		panel.setPosition(90, 40);
		panel.addChild(group);
		var inPanel = group.computeBounds(panel, scratch);
		check(inPanel == scratch && near(inPanel.minX, 96) && near(inPanel.maxX, 104) && near(inPanel.minY, 40),
			"Relative to its parent: placed by its own transform, not the parent's");
		check(near(group.computeBounds().minX, 186), "The world now includes the panel's place");
		rect.visible = false;
		check(group.computeBounds(scratch) == null && scratch.isEmpty, "A hidden node is left out: nothing, the given one emptied");
		rect.visible = true;
		var flat = new Node2D();
		flat.setScale(0, 1);
		check(group.computeBounds(flat) == null, "Relative to a node scaled to nothing: none");

		// 3D: a unit cube moved under a parent turned a quarter about y.
		var root = new Node3D(),
			parent = new Node3D(),
			cube = new Model3D(Mesh3D.cube(2, 2, 2), new Material3D());
		parent.setPosition(10, 0, 0);
		parent.setRotation(0, Math.PI / 2, 0);
		cube.setPosition(0, 0, 3);
		root.addChild(parent);
		parent.addChild(cube);
		var box = root.computeBounds();
		check(box != null && near(box.minX, 12) && near(box.maxX, 14) && near(box.minY, -1) && near(box.minZ, -1) && near(box.maxZ, 1),
			"A model's vertices placed by its parents' turn, as they are now");
		var reused = new Bounds3D();
		check(root.computeBounds(reused) == reused && near(reused.maxX, 14), "Into a given one, returned");
		check(near(cube.computeBounds(parent).minZ, 2)
			&& near(cube.computeBounds(parent).maxZ, 4), "Relative to its parent: its own placement only");
		cube.visible = false;
		check(root.computeBounds() == null, "A hidden model is left out");
		cube.visible = true;
		var sprite = new Sprite3D(helix.texture.Texture2D.fromRgba(1, 1, haxe.io.Bytes.alloc(4), Nearest, -1, -1, false, new Render2DTests.CountingGraphics()));
		sprite.setSpriteSize(2, 2);
		sprite.setPosition(0, 5, 0);
		root.addChild(sprite);
		var withSprite = root.computeBounds();
		check(near(withSprite.maxY, 5 + Math.sqrt(2))
			&& near(withSprite.minX, -Math.sqrt(2)), "A camera-facing sprite by the sphere its quad can turn in");
		var only = new Bounds3D();
		sprite.facing = Upright;
		@:privateAccess sprite.measureOwnWorld(sprite.computeWorld(), only.clear());
		check(near(only.maxY, 6) && near(only.minY, 4) && near(only.minX, -1) && near(only.maxZ, 1), "An upright one by the cylinder it turns in");
		sprite.facing = Free;
		sprite.setRotation(0, Math.PI / 2, 0);
		@:privateAccess sprite.measureOwnWorld(sprite.computeWorld(), only.clear());
		check(near(only.minX, 0) && near(only.maxX, 0) && near(only.minZ, -1) && near(only.maxZ, 1) && near(only.maxY, 6),
			"A free one by its corners, as it's turned");
		sprite.facing = Ground;
		sprite.setRotation(0, 0, 0);
		@:privateAccess sprite.measureOwnWorld(sprite.computeWorld(), only.clear());
		check(near(only.minY, 5) && near(only.maxY, 5) && near(only.minZ, -1) && near(only.maxZ, 1), "One on the ground, flat");
		var w = cube.computeWorld();
		check(near(w.get(12), 13) && cube.computeWorld(new Mat4()) != w, "computeWorld: a new matrix when none is given");
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}
}
