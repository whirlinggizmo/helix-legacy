package helix.collision;

/** 2D collision tests on plain numbers: rectangles (x, y the top-left, then width and height), circles, segments, rays and polygons
	(points as x, y pairs in either winding). Each says what it answers: isCircleOverlappingRect, isSegmentCrossingSegment, isPointInRect,
	isRayHittingCircle. The first shape is the one a Hit2D says how to move.

	Shapes overlap when they share some area; shapes that only touch, edge to edge, don't. A box resting on a floor or standing in a grid
	of tiles isn't overlapping its neighbors. A point on a rectangle's left or top edge is in it, and on its right or bottom edge isn't, so
	a point on a shared edge is in one tile.

	A test given a Hit2D fills it: for an overlap, the way to move the first shape out (normal), how far (depth) and the second's point
	nearest it; for a ray or a sweep, where along it (time), the point and the surface's normal. The tests are in floats with nothing
	transcendental, so they give the same answers on every target. Polygon against polygon needs convex ones (split a concave one first);
	a circle against a polygon takes any that doesn't cross itself. moveAndSlide moves a box over a grid of solid tiles; a SpatialHash2D
	narrows which pairs to test. */
class Collide2D {
	/** Whether two rectangles overlap. */
	public static function isRectOverlappingRect(ax:Float, ay:Float, aw:Float, ah:Float, bx:Float, by:Float, bw:Float, bh:Float):Bool
		return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by;

	/** Whether circle a and circle b overlap. With hit: its normal is the way to move a out of b, depth how far, and x, y the point of b
		nearest a's center (a's center on b's: moved up). */
	public static function isCircleOverlappingCircle(ax:Float, ay:Float, ar:Float, bx:Float, by:Float, br:Float, ?hit:Hit2D):Bool {
		var dx = ax - bx, dy = ay - by, r = ar + br, d2 = dx * dx + dy * dy;
		if (d2 >= r * r)
			return false;
		if (hit != null) {
			var d = Math.sqrt(d2),
				nx = d > 0 ? dx / d : 0.,
				ny = d > 0 ? dy / d : -1.;
			fill(hit, bx + nx * br, by + ny * br, nx, ny, r - d);
		}
		return true;
	}

	/** Whether the circle and the rectangle overlap. With hit: its normal is the way to move the circle out of the rectangle, depth how far,
		and x, y the rectangle's point nearest the circle's center (with the center inside, the nearest edge's, the move out across it). */
	public static function isCircleOverlappingRect(cx:Float, cy:Float, r:Float, rx:Float, ry:Float, rw:Float, rh:Float, ?hit:Hit2D):Bool {
		var nx = cx < rx ? rx : cx > rx + rw ? rx + rw : cx,
			ny = cy < ry ? ry : cy > ry + rh ? ry + rh : cy;
		var dx = cx - nx, dy = cy - ny, d2 = dx * dx + dy * dy;
		var inside = cx > rx && cx < rx + rw && cy > ry && cy < ry + rh;
		if (!inside && d2 >= r * r)
			return false;
		if (hit != null) {
			if (!inside) {
				var d = Math.sqrt(d2);
				fill(hit, nx, ny, dx / d, dy / d, r - d);
			} else {
				// The nearest edge: out across it.
				var left = cx - rx, right = rx + rw - cx, top = cy - ry, bottom = ry + rh - cy;
				var least = Math.min(Math.min(left, right), Math.min(top, bottom));
				if (least == left)
					fill(hit, rx, cy, -1, 0, left + r);
				else if (least == right)
					fill(hit, rx + rw, cy, 1, 0, right + r);
				else if (least == top)
					fill(hit, cx, ry, 0, -1, top + r);
				else
					fill(hit, cx, ry + rh, 0, 1, bottom + r);
			}
		}
		return true;
	}

	/** Whether the circle and the segment from ax, ay to bx, by overlap (a wall, a polyline's piece). With hit: its normal is the way to move
		the circle off the segment, depth how far, and x, y the segment's point nearest the circle's center (on it: moved off to the
		segment's left, as it runs). */
	public static function isCircleOverlappingSegment(cx:Float, cy:Float, r:Float, ax:Float, ay:Float, bx:Float, by:Float, ?hit:Hit2D):Bool {
		var ex = bx - ax, ey = by - ay, len2 = ex * ex + ey * ey;
		var t = len2 == 0 ? 0 : ((cx - ax) * ex + (cy - ay) * ey) / len2;
		t = t < 0 ? 0 : t > 1 ? 1 : t;
		var qx = ax + ex * t, qy = ay + ey * t, dx = cx - qx, dy = cy - qy, d2 = dx * dx + dy * dy;
		if (d2 >= r * r)
			return false;
		if (hit != null) {
			var d = Math.sqrt(d2);
			if (d > 0)
				fill(hit, qx, qy, dx / d, dy / d, r - d);
			else {
				var len = Math.sqrt(len2);
				fill(hit, qx, qy, len > 0 ? ey / len : 0, len > 0 ? -ex / len : -1, r);
			}
		}
		return true;
	}

	/** Whether the point is inside the rectangle (on its left or top edge counts, its right or bottom doesn't). */
	public static function isPointInRect(px:Float, py:Float, rx:Float, ry:Float, rw:Float, rh:Float):Bool
		return px >= rx && px < rx + rw && py >= ry && py < ry + rh;

	/** Whether the point is inside the circle. */
	public static function isPointInCircle(px:Float, py:Float, cx:Float, cy:Float, r:Float):Bool {
		var dx = px - cx, dy = py - cy;
		return dx * dx + dy * dy < r * r;
	}

	/** Whether the point is inside the polygon (convex or not, by crossings). */
	public static function isPointInPolygon(px:Float, py:Float, points:Array<Float>):Bool {
		var n = points.length >> 1, inside = false, j = n - 1;
		for (i in 0...n) {
			var xi = points[i * 2],
				yi = points[i * 2 + 1],
				xj = points[j * 2],
				yj = points[j * 2 + 1];
			if ((yi > py) != (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi)
				inside = !inside;
			j = i;
		}
		return inside;
	}

	/** Whether two convex polygons overlap (the separating axis theorem). With hit, its normal is the way to move a out of b by its depth, the
		least such move. */
	public static function isPolygonOverlappingPolygon(a:Array<Float>, b:Array<Float>, ?hit:Hit2D):Bool {
		var least = Math.POSITIVE_INFINITY, nx = 0., ny = 0.;
		for (pass in 0...2) {
			var edges = pass == 0 ? a : b, n = edges.length >> 1;
			for (i in 0...n) {
				var j = (i + 1) % n;
				// The edge's normal, as an axis; both polygons projected onto it.
				var ex = edges[j * 2] - edges[i * 2],
					ey = edges[j * 2 + 1] - edges[i * 2 + 1];
				var len = Math.sqrt(ex * ex + ey * ey);
				if (len == 0)
					continue;
				var ax = -ey / len, ay = ex / len;
				var aMin = Math.POSITIVE_INFINITY,
					aMax = Math.NEGATIVE_INFINITY,
					bMin = Math.POSITIVE_INFINITY,
					bMax = Math.NEGATIVE_INFINITY;
				var k = 0;
				while (k < a.length) {
					var p = a[k] * ax + a[k + 1] * ay;
					if (p < aMin)
						aMin = p;
					if (p > aMax)
						aMax = p;
					k += 2;
				}
				k = 0;
				while (k < b.length) {
					var p = b[k] * ax + b[k + 1] * ay;
					if (p < bMin)
						bMin = p;
					if (p > bMax)
						bMax = p;
					k += 2;
				}
				if (aMax <= bMin || bMax <= aMin)
					return false;
				var overlap = Math.min(aMax - bMin, bMax - aMin);
				if (overlap < least) {
					least = overlap;
					// Out of b: away from b's middle along the axis.
					var aMid = (aMin + aMax) / 2, bMid = (bMin + bMax) / 2;
					var sign = aMid < bMid ? -1 : 1;
					nx = ax * sign;
					ny = ay * sign;
				}
			}
		}
		if (hit != null) {
			hit.reset();
			hit.normalX = nx;
			hit.normalY = ny;
			hit.depth = least;
		}
		return true;
	}

	/** Whether the circle and the polygon overlap (convex or not, as long as its edges don't cross). With hit: its normal is the way to move
		the circle out of the polygon, depth how far, and x, y the polygon's edge point nearest the circle's center (with the center inside,
		the move out across that edge). */
	public static function isCircleOverlappingPolygon(cx:Float, cy:Float, r:Float, points:Array<Float>, ?hit:Hit2D):Bool {
		var inside = isPointInPolygon(cx, cy, points);
		// The edge point nearest the center.
		var n = points.length >> 1, best = Math.POSITIVE_INFINITY, qx = 0., qy = 0., ex = 0., ey = 0.;
		for (i in 0...n) {
			var j = (i + 1) % n,
				ax = points[i * 2],
				ay = points[i * 2 + 1],
				bx = points[j * 2],
				by = points[j * 2 + 1];
			var sx = bx - ax, sy = by - ay, len2 = sx * sx + sy * sy;
			var t = len2 == 0 ? 0 : ((cx - ax) * sx + (cy - ay) * sy) / len2;
			t = t < 0 ? 0 : t > 1 ? 1 : t;
			var px = ax + sx * t,
				py = ay + sy * t,
				d2 = (cx - px) * (cx - px) + (cy - py) * (cy - py);
			if (d2 < best) {
				best = d2;
				qx = px;
				qy = py;
				ex = sx;
				ey = sy;
			}
		}
		if (!inside && best >= r * r)
			return false;
		if (hit != null && n > 0) {
			var d = Math.sqrt(best);
			if (d > 0)
				// Outside, away from the edge; inside, toward it and across.
				fill(hit, qx, qy, (inside ? qx - cx : cx - qx) / d, (inside ? qy - cy : cy - qy) / d, inside ? r + d : r - d);
			else {
				// On the edge: its normal that points out of the polygon.
				var len = Math.sqrt(ex * ex + ey * ey),
					nx = len > 0 ? ey / len : 0.,
					ny = len > 0 ? -ex / len : -1.;
				if (isPointInPolygon(qx + nx * 1e-6, qy + ny * 1e-6, points)) {
					nx = -nx;
					ny = -ny;
				}
				fill(hit, qx, qy, nx, ny, r);
			}
		}
		return true;
	}

	// hit filled with a point, a normal and a depth, its time 0.
	static function fill(hit:Hit2D, x:Float, y:Float, normalX:Float, normalY:Float, depth:Float):Void {
		hit.reset();
		hit.x = x;
		hit.y = y;
		hit.normalX = normalX;
		hit.normalY = normalY;
		hit.depth = depth;
	}

	/** Whether a rectangle and a convex polygon overlap. */
	public static function isRectOverlappingPolygon(rx:Float, ry:Float, rw:Float, rh:Float, points:Array<Float>, ?hit:Hit2D):Bool
		return isPolygonOverlappingPolygon([rx, ry, rx + rw, ry, rx + rw, ry + rh, rx, ry + rh], points, hit);

	/** The square of the distance from a point to a segment. */
	public static function segmentDistanceSquared(ax:Float, ay:Float, bx:Float, by:Float, px:Float, py:Float):Float {
		var dx = bx - ax, dy = by - ay, len = dx * dx + dy * dy;
		var t = len == 0 ? 0 : ((px - ax) * dx + (py - ay) * dy) / len;
		t = t < 0 ? 0 : t > 1 ? 1 : t;
		var qx = ax + dx * t - px, qy = ay + dy * t - py;
		return qx * qx + qy * qy;
	}

	/** Whether segment a to b crosses segment c to d (not when they only touch or lie along each other); with hit, where along a to b (time)
		and the point. */
	public static function isSegmentCrossingSegment(ax:Float, ay:Float, bx:Float, by:Float, cx:Float, cy:Float, dx:Float, dy:Float, ?hit:Hit2D):Bool {
		var rx = bx - ax, ry = by - ay, sx = dx - cx, sy = dy - cy;
		var cross = rx * sy - ry * sx;
		if (cross == 0)
			return false;
		var qx = cx - ax, qy = cy - ay;
		var t = (qx * sy - qy * sx) / cross, u = (qx * ry - qy * rx) / cross;
		if (t <= 0 || t >= 1 || u <= 0 || u >= 1)
			return false;
		if (hit != null) {
			hit.reset();
			hit.time = t;
			hit.x = ax + rx * t;
			hit.y = ay + ry * t;
			var len = Math.sqrt(sx * sx + sy * sy);
			// The crossed segment's normal, facing the way the first came from.
			var nx = -sy / len, ny = sx / len;
			if (nx * rx + ny * ry > 0) {
				nx = -nx;
				ny = -ny;
			}
			hit.normalX = nx;
			hit.normalY = ny;
		}
		return true;
	}

	/** Whether the ray from ox, oy along dx, dy (its whole length: time 1 is its end) meets the rectangle: into hit the time, point and
		normal (0, 0 and time 0 from inside). */
	public static function isRayHittingRect(ox:Float, oy:Float, dx:Float, dy:Float, rx:Float, ry:Float, rw:Float, rh:Float, hit:Hit2D):Bool {
		var tMin = 0., tMax = 1., nx = 0., ny = 0.;
		for (axis in 0...2) {
			var o = axis == 0 ? ox : oy,
				d = axis == 0 ? dx : dy,
				lo = axis == 0 ? rx : ry,
				hi = axis == 0 ? rx + rw : ry + rh;
			if (d == 0) {
				if (o < lo || o > hi)
					return false;
				continue;
			}
			var inv = 1 / d, t1 = (lo - o) * inv, t2 = (hi - o) * inv, n = -1.;
			if (t1 > t2) {
				var t = t1;
				t1 = t2;
				t2 = t;
				n = 1;
			}
			if (t1 > tMin) {
				tMin = t1;
				nx = axis == 0 ? n : 0;
				ny = axis == 1 ? n : 0;
			}
			if (t2 < tMax)
				tMax = t2;
			if (tMin > tMax)
				return false;
		}
		hit.reset();
		hit.time = tMin;
		hit.x = ox + dx * tMin;
		hit.y = oy + dy * tMin;
		hit.normalX = nx;
		hit.normalY = ny;
		return true;
	}

	/** Whether the ray from ox, oy along dx, dy (time 1 its end) meets the circle: into hit the time, point and normal (time 0 and no normal
		from inside). */
	public static function isRayHittingCircle(ox:Float, oy:Float, dx:Float, dy:Float, cx:Float, cy:Float, r:Float, hit:Hit2D):Bool {
		var fx = ox - cx, fy = oy - cy;
		if (fx * fx + fy * fy < r * r) {
			hit.reset();
			hit.x = ox;
			hit.y = oy;
			return true;
		}
		var a = dx * dx + dy * dy;
		if (a == 0)
			return false;
		var b = 2 * (fx * dx + fy * dy), c = fx * fx + fy * fy - r * r;
		var disc = b * b - 4 * a * c;
		if (disc < 0)
			return false;
		var t = (-b - Math.sqrt(disc)) / (2 * a);
		if (t < 0 || t > 1)
			return false;
		hit.reset();
		hit.time = t;
		hit.x = ox + dx * t;
		hit.y = oy + dy * t;
		hit.normalX = (hit.x - cx) / r;
		hit.normalY = (hit.y - cy) / r;
		return true;
	}

	/** Whether rectangle a, moved by dx, dy, meets rectangle b on the way: into hit the time of the meeting, a's top-left then, and the normal
		(a already overlapping b: time 0, no normal). */
	public static function isSweptRectHittingRect(ax:Float, ay:Float, aw:Float, ah:Float, dx:Float, dy:Float, bx:Float, by:Float, bw:Float, bh:Float,
			hit:Hit2D):Bool {
		if (isRectOverlappingRect(ax, ay, aw, ah, bx, by, bw, bh)) {
			hit.reset();
			hit.x = ax;
			hit.y = ay;
			return true;
		}
		// a's corner as a ray against b grown by a's size (their Minkowski sum).
		return isRayHittingRect(ax, ay, dx, dy, bx - aw, by - ah, bw + aw, bh + ah, hit);
	}

	/** Whether circle a, moved by dx, dy, meets circle b on the way: into hit the time, a's center then, and the normal. */
	public static function isSweptCircleHittingCircle(ax:Float, ay:Float, ar:Float, dx:Float, dy:Float, bx:Float, by:Float, br:Float, hit:Hit2D):Bool
		return isRayHittingCircle(ax, ay, dx, dy, bx, by, ar + br, hit);

	/** Moves the box at x, y (its top-left), width by height, by dx, dy over a grid of tiles of tileSize, each solid or not by solid(column,
		row), sliding along what it meets: first across, stopped at a solid tile's side, then down or up the same; into out the place it ended and
		which sides met a solid. A box starting inside a solid tile is left where it is on that axis. */
	public static function moveAndSlide(x:Float, y:Float, width:Float, height:Float, dx:Float, dy:Float, tileSize:Float, solid:(Int, Int) -> Bool,
			out:Move2D):Move2D {
		out.left = out.right = out.top = out.bottom = false;
		var eps = 1e-6;
		// Across: the rows the box spans now, the columns its new span covers; the nearest solid the way it moves stops it.
		var nx = x + dx;
		if (dx != 0) {
			var row0 = Math.floor(y / tileSize),
				row1 = Math.floor((y + height - eps) / tileSize);
			var col0 = Math.floor(nx / tileSize),
				col1 = Math.floor((nx + width - eps) / tileSize);
			if (dx > 0) {
				// From the column past its leading edge now to the one its leading edge reaches.
				var col = Math.floor((x + width - eps) / tileSize) + 1;
				while (col <= col1) {
					if (columnSolid(col, row0, row1, solid)) {
						nx = col * tileSize - width;
						out.right = true;
						break;
					}
					col++;
				}
			} else {
				var col = Math.floor(x / tileSize) - 1;
				while (col >= col0) {
					if (columnSolid(col, row0, row1, solid)) {
						nx = (col + 1) * tileSize;
						out.left = true;
						break;
					}
					col--;
				}
			}
		}
		// Then down or up, at the new x.
		var ny = y + dy;
		if (dy != 0) {
			var col0 = Math.floor(nx / tileSize),
				col1 = Math.floor((nx + width - eps) / tileSize);
			var row0 = Math.floor(ny / tileSize),
				row1 = Math.floor((ny + height - eps) / tileSize);
			if (dy > 0) {
				var row = Math.floor((y + height - eps) / tileSize) + 1;
				while (row <= row1) {
					if (rowSolid(row, col0, col1, solid)) {
						ny = row * tileSize - height;
						out.bottom = true;
						break;
					}
					row++;
				}
			} else {
				var row = Math.floor(y / tileSize) - 1;
				while (row >= row0) {
					if (rowSolid(row, col0, col1, solid)) {
						ny = (row + 1) * tileSize;
						out.top = true;
						break;
					}
					row--;
				}
			}
		}
		out.x = nx;
		out.y = ny;
		return out;
	}

	static function columnSolid(col:Int, row0:Int, row1:Int, solid:(Int, Int) -> Bool):Bool {
		for (row in row0...row1 + 1)
			if (solid(col, row))
				return true;
		return false;
	}

	static function rowSolid(row:Int, col0:Int, col1:Int, solid:(Int, Int) -> Bool):Bool {
		for (col in col0...col1 + 1)
			if (solid(col, row))
				return true;
		return false;
	}
}
