import helix.collision.Body2D;
import helix.collision.Collide2D;
import helix.collision.Hit2D;
import helix.collision.Move2D;
import helix.collision.SpatialHash2D;

/** 2D collision (helix.collision): overlaps of rectangles, circles and polygons, points inside, segments and rays with where and the
	normal, sweeps, a box moved and slid over tiles, a spatial hash narrowing the pairs, and an arcade body falling, landing, walking into a wall,
	hitting its head and drawn between its steps. */
class CollisionTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float, e = 1e-9):Bool
		return Math.abs(a - b) < e;

	static function main():Void {
		// Overlaps.
		check(Collide2D.isRectOverlappingRect(0, 0, 10, 10, 5, 5, 10, 10)
			&& !Collide2D.isRectOverlappingRect(0, 0, 10, 10, 10, 0, 10, 10)
			&& !Collide2D.isRectOverlappingRect(0, 0, 10, 10, 11, 0, 1, 1),
			"Rectangles overlap, not when touching");
		check(Collide2D.isCircleOverlappingCircle(0, 0, 5, 8, 0, 4) && !Collide2D.isCircleOverlappingCircle(0, 0, 5, 9, 0, 4),
			"Circles overlap, not when touching");
		check(Collide2D.isCircleOverlappingRect(12, 5, 3, 0, 0, 10, 10)
			&& !Collide2D.isCircleOverlappingRect(13, 5, 3, 0, 0, 10, 10)
			&& Collide2D.isCircleOverlappingRect(5, 5, 1, 0, 0, 10, 10),
			"A circle and a rectangle: by the nearest point, and a circle inside");
		check(!Collide2D.isCircleOverlappingRect(12, 12, 2.8, 0, 0, 10, 10)
			&& Collide2D.isCircleOverlappingRect(12, 12, 2.9, 0, 0, 10, 10),
			"at a corner, by distance (sqrt 8 away)");
		var pushed = new Hit2D();
		check(Collide2D.isCircleOverlappingCircle(8, 0, 4, 0, 0, 5, pushed)
			&& near(pushed.normalX, 1)
			&& near(pushed.normalY, 0)
			&& near(pushed.depth, 1)
			&& near(pushed.x, 5),
			"Circles: the first pushed out of the second along the line between them, by the overlap, from b's rim");
		check(Collide2D.isCircleOverlappingRect(12, 5, 3, 0, 0, 10, 10, pushed)
			&& near(pushed.normalX, 1)
			&& near(pushed.depth, 1)
			&& near(pushed.x, 10)
			&& near(pushed.y, 5),
			"A circle on a rectangle's side: pushed out right by 1, the side's point");
		check(Collide2D.isCircleOverlappingRect(12, 12, 3, 0, 0, 10, 10, pushed)
			&& near(pushed.normalX, Math.sqrt(.5))
			&& near(pushed.normalY, Math.sqrt(.5))
			&& near(pushed.depth, 3 - Math.sqrt(8)),
			"At a corner, out along the diagonal");
		check(Collide2D.isCircleOverlappingRect(5, 2, 1, 0, 0, 10, 10, pushed)
			&& near(pushed.normalY, -1)
			&& near(pushed.depth, 3)
			&& near(pushed.y, 0),
			"A circle inside, out across the nearest edge (the top), the radius and the way to it");
		check(Collide2D.isCircleOverlappingSegment(5, 1, 2, 0, 0, 10, 0, pushed)
			&& near(pushed.normalY, 1)
			&& near(pushed.depth, 1)
			&& near(pushed.x, 5)
			&& !Collide2D.isCircleOverlappingSegment(5, 2, 2, 0, 0, 10, 0)
			&& Collide2D.isCircleOverlappingSegment(11, 1, 1.5, 0, 0, 10, 0, pushed)
			&& near(pushed.x, 10),
			"A circle on a wall: off it along its normal, not when touching; past its end, off the end point");
		check(Collide2D.isPointInRect(0, 0, 0, 0, 10, 10)
			&& !Collide2D.isPointInRect(10, 5, 0, 0, 10, 10)
			&& Collide2D.isPointInCircle(3, 4, 0, 0, 5.1)
			&& !Collide2D.isPointInCircle(3, 4, 0, 0, 5),
			"Points in a rectangle (its left and top edges in, right and bottom out) and a circle");
		var square = [0., 0, 10, 0, 10, 10, 0, 10],
			arrow = [0., 0, 10, 5, 0, 10, 4, 5];
		check(Collide2D.isPointInPolygon(5, 5, square)
			&& !Collide2D.isPointInPolygon(15, 5, square)
			&& Collide2D.isPointInPolygon(6, 5, arrow)
			&& Collide2D.isPointInPolygon(1.5, 1, arrow)
			&& !Collide2D.isPointInPolygon(1, 5, arrow)
			&& !Collide2D.isPointInPolygon(3, 1, arrow),
			"Points in polygons, concave too");
		var hit = new Hit2D();
		var diamond = [13., 3, 18, 8, 13, 13, 8, 8];
		check(Collide2D.isPolygonOverlappingPolygon(square, [8., 8, 18, 8, 18, 18, 8, 18])
			&& !Collide2D.isPolygonOverlappingPolygon(square, [10., 0, 20, 0, 20, 10, 10, 10])
			&& Collide2D.isPolygonOverlappingPolygon(square, diamond)
			&& !Collide2D.isPolygonOverlappingPolygon(square, [5., 10, 15, 20, 5, 30, -5, 20]),
			"Convex polygons overlap by the separating axis theorem; a diamond's tip in, or just touching, out");
		Collide2D.isPolygonOverlappingPolygon(square, [8., 0, 18, 0, 18, 10, 8, 10], hit);
		check(near(hit.depth, 2) && near(hit.normalX, -1) && near(hit.normalY, 0), "The least move apart, out of the other");
		check(Collide2D.isCircleOverlappingPolygon(12, 5, 3, square)
			&& !Collide2D.isCircleOverlappingPolygon(13.5, 5, 3, square)
			&& Collide2D.isCircleOverlappingPolygon(5, 5, 1, square),
			"A circle and a polygon: by its edges, and a circle inside");
		check(Collide2D.isCircleOverlappingPolygon(12, 5, 3, square, pushed) && near(pushed.normalX, 1) && near(pushed.depth, 1),
			"A circle on a polygon's edge: out of it");
		check(Collide2D.isCircleOverlappingPolygon(3, 5, 1, arrow, pushed) && Collide2D.isCircleOverlappingPolygon(5, 5, 1, arrow, pushed),
			"A concave polygon: its notch's edges, and inside it");
		check(Collide2D.isCircleOverlappingPolygon(8, 5, 1, square, pushed)
			&& near(pushed.normalX, 1)
			&& near(pushed.depth, 3)
			&& near(pushed.x, 10),
			"Inside: out across the nearest edge");
		check(Collide2D.isRectOverlappingPolygon(0, 0, 10, 10, diamond)
			&& !Collide2D.isRectOverlappingPolygon(0, 0, 10, 10, [20., 0, 30, 0, 25, 10]),
			"A rectangle and a polygon");

		// Segments and rays.
		check(Collide2D.isSegmentCrossingSegment(0, 0, 10, 10, 0, 10, 10, 0, hit)
			&& near(hit.time, .5)
			&& near(hit.x, 5)
			&& near(hit.y, 5),
			"Crossing segments, where along the first");
		check(near(hit.normalX, -Math.sqrt(.5)) && near(hit.normalY, -Math.sqrt(.5)), "The crossed segment's normal faces the first's start");
		check(!Collide2D.isSegmentCrossingSegment(0, 0, 10, 0, 0, 1, 10, 1)
			&& !Collide2D.isSegmentCrossingSegment(0, 0, 10, 0, 5, 0, 5, 10),
			"Parallel, or only touching: no crossing");
		check(Collide2D.isRayHittingRect(-5, 5, 20, 0, 0, 0, 10, 10, hit)
			&& near(hit.time, .25)
			&& near(hit.x, 0)
			&& near(hit.y, 5)
			&& hit.normalX == -1
			&& hit.normalY == 0,
			"A ray meets a rectangle's left side with its normal");
		check(Collide2D.isRayHittingRect(5, 20, 0, -30, 0, 0, 10, 10, hit)
			&& near(hit.time, 1 / 3)
			&& hit.normalY == 1, "from below, the bottom's normal");
		check(!Collide2D.isRayHittingRect(-5, 15, 20, 0, 0, 0, 10, 10, hit) && !Collide2D.isRayHittingRect(-5, 5, 2, 0, 0, 0, 10, 10, hit),
			"A miss, and a ray too short");
		check(Collide2D.isRayHittingRect(5, 5, 20, 0, 0, 0, 10, 10, hit)
			&& hit.time == 0
			&& hit.normalX == 0, "From inside: time 0, no normal");
		check(Collide2D.isRayHittingCircle(-10, 0, 20, 0, 0, 0, 5, hit)
			&& near(hit.time, .25)
			&& near(hit.x, -5)
			&& near(hit.normalX, -1),
			"A ray meets a circle with its normal");
		check(!Collide2D.isRayHittingCircle(-10, 6, 20, 0, 0, 0, 5, hit)
			&& !Collide2D.isRayHittingCircle(-10, 0, 4, 0, 0, 0, 5, hit), "A miss, and too short");
		check(Collide2D.isRayHittingCircle(1, 1, 20, 0, 0, 0, 5, hit) && hit.time == 0, "From inside: time 0");

		// Sweeps.
		check(Collide2D.isSweptRectHittingRect(0, 0, 4, 4, 20, 0, 10, 0, 4, 4, hit)
			&& near(hit.time, .3)
			&& near(hit.x, 6)
			&& hit.normalX == -1,
			"A rectangle swept into another stops at its side");
		check(!Collide2D.isSweptRectHittingRect(0, 0, 4, 4, 20, 0, 10, 5, 4, 4, hit)
			&& Collide2D.isSweptRectHittingRect(0, 0, 4, 4, 20, 0, 2, 2, 4, 4, hit)
			&& hit.time == 0,
			"A sweep that misses, and one already overlapping");
		check(Collide2D.isSweptCircleHittingCircle(0, 0, 2, 20, 0, 10, 0, 3, hit) && near(hit.time, .25) && near(hit.x, 5),
			"Circles swept together meet at their radii");

		// Move and slide over tiles: a floor at row 2 (y 20 to 30), a wall at column 5 (x 50 to 60).
		var solid = (col:Int, row:Int) -> row == 2 || col == 5;
		var move = new Move2D();
		Collide2D.moveAndSlide(10, 5, 8, 8, 0, 20, 10, solid, move);
		check(near(move.x, 10) && near(move.y, 12) && move.bottom && !move.top && !move.left && !move.right,
			"Falling onto the floor stops on it, bottom touching");
		Collide2D.moveAndSlide(10, 12, 8, 8, 100, 0, 10, solid, move);
		check(near(move.x, 42) && near(move.y, 12) && move.right && !move.bottom, "Running into the wall stops at it, right touching");
		Collide2D.moveAndSlide(42, 12, 8, 8, -100, 0, 10, solid, move);
		check(near(move.x, -58) && !move.left, "Nothing to the left: all the way");
		Collide2D.moveAndSlide(70, 12, 8, 8, -30, 0, 10, solid, move);
		check(near(move.x, 60) && move.left, "From the right, the wall's other side, left touching");
		Collide2D.moveAndSlide(10, 35, 8, 8, 0, -20, 10, solid, move);
		check(near(move.y, 30) && move.top, "Jumping into the floor from below, top touching");
		Collide2D.moveAndSlide(10, 12, 8, 8, 3, 5, 10, solid, move);
		check(near(move.x, 13) && near(move.y, 12) && move.bottom, "A slide along the floor: across, down stopped");
		Collide2D.moveAndSlide(10, 12, 8, 8, 0, 0, 10, solid, move);
		check(near(move.x, 10) && near(move.y, 12) && !move.bottom, "Not moving touches nothing");
		Collide2D.moveAndSlide(10, 12, 8, 8, 50, 8, 10, solid, move);
		check(near(move.x, 42) && near(move.y, 12) && move.right && move.bottom, "Both at once: the wall and the floor");

		// A spatial hash narrows the pairs.
		var hash = new SpatialHash2D<{name:String}>(10);
		var a = {name: "a"}, b = {name: "b"}, c = {name: "c"};
		hash.insert(a, 0, 0, 5, 5);
		hash.insert(b, 12, 12, 5, 5);
		hash.insert(c, 8, 8, 30, 30);
		var found = [];
		hash.query(0, 0, 10, 10, found);
		var names = found.map(i -> i.name);
		names.sort((x, y) -> x < y ? -1 : 1);
		check(hash.count == 3 && names.join(",") == "a,c", "A query gives the items in the cells it covers, each once");
		hash.query(50, 50, 5, 5, found);
		check(found.length == 0, "Nothing far away");
		hash.update(a, 50, 50, 5, 5);
		hash.query(50, 50, 5, 5, found);
		check(found.length == 1 && found[0] == a && hash.count == 3, "A moved item is found at its new place");
		hash.query(0, 0, 5, 5, found);
		check(found.indexOf(a) < 0, "and not at its old one");
		check(hash.remove(b) && !hash.remove(b) && hash.count == 2, "Removed once");
		hash.query(0, 0, 100, 100, found);
		check(found.length == 2, "A wide query finds each of the rest once");
		hash.clear();
		hash.query(0, 0, 100, 100, found);
		check(found.length == 0 && hash.count == 0, "Cleared");
		var threw = false;
		try
			new SpatialHash2D<{}>(0)
		catch (e:Dynamic)
			threw = true;
		check(threw, "A cell size of 0 is refused");

		// An arcade body over a floor (row 10) with a wall (column 8) and a ceiling tile (column 2, row 7), tiles 1 across.
		var level = (column:Int, row:Int) -> row == 10 || column == 8 || column == 2 && row == 7;
		var body = new Body2D(4, 5, .5, 1);
		body.gravity = 20;
		body.maxFallSpeed = 12;
		for (_ in 0...120)
			body.step(1 / 60, 1, level);
		check(body.grounded && body.bottom == 10 && body.velocityY == 0 && body.airTime == 0, "It falls and lands on the floor, still");
		body.velocityY = -100;
		body.step(1 / 60, 1, level);
		check(body.velocityY == -100 + 20 / 60 && !body.grounded && body.airTime == 1 / 60, "Off the ground, its air time counts");
		body.place(4, 9);
		check(body.x == 4 && body.previousX == 4 && body.velocityY == 0 && !body.grounded, "Placed, still");
		body.step(1 / 60, 1, level);
		check(body.grounded, "Standing on the floor, gravity keeps it grounded");
		// Walking right, as a game sets its speed each step.
		for (_ in 0...30) {
			body.velocityX = 30;
			body.step(1 / 60, 1, level);
		}
		check(body.x + body.width == 8 && body.blockedRight && body.velocityX == 0 && body.grounded, "It walks into the wall and stops there");
		body.step(1 / 60, 1, level);
		check(!body.blockedRight, "Not pushing, it isn't blocked");
		var fall = new Body2D(0, 0, .5, 1);
		fall.gravity = 1000;
		fall.maxFallSpeed = 12;
		fall.step(1 / 60, 1, (_, _) -> false);
		check(fall.velocityY == 12, "Its fall is held to its top speed");
		var head = new Body2D(2.25, 8.5, .5, 1);
		head.place(2.25, 8.5);
		head.velocityY = -40;
		head.step(1 / 60, 1, level);
		check(head.blockedAbove && head.y == 8 && head.velocityY == 0, "Jumping into a ceiling stops it there");
		var drawn = new Body2D(0, 0, 1, 1);
		drawn.velocityX = 60;
		drawn.step(1 / 60, 1, (_, _) -> false);
		check(drawn.previousX == 0 && drawn.x == 1 && drawn.getDrawnX(.25) == .25 && drawn.getDrawnY(.5) == 0, "Drawn between its steps");
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}
}
