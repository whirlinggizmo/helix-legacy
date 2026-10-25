package helix.render3d;

import haxe.io.Bytes;
import helix.graphics.IGraphics;

/** Triangles for lit models: each vertex a position, a normal, texture coordinates and a tangent (Lit3DProgram's packing; the tangent's w its
	bitangent's sign, glTF's convention), indexed, with the box around them; a skinned one also each vertex's four joints and their weights
	(Skinned3DProgram's skin buffer), its box its bind pose's. Made once and never changed; a Renderer3D uploads it the first time it draws it. The shapes made here are centered on the origin, y up,
	counter-clockwise from outside (the front face), in world units, as the earlier frameworks' generated meshes. */
class Mesh3D {
	// Kept across a hot reload: ids made after one mustn't repeat those of meshes still drawn.
	@:hot static var nextId = 1;

	// Which one it is, for sorting alike draws together.
	@:allow(helix.render3d.Renderer3D) var id = nextId++;
	var vertexData:Bytes;
	var indexData:Bytes;
	var loX = 0.;
	var loY = 0.;
	var loZ = 0.;
	var hiX = 0.;
	var hiY = 0.;
	var hiZ = 0.;
	var gpu:IGraphics;
	var vertexBuffer = 0;
	var indexBuffer = 0;
	var skinBuffer = 0;
	var passBuffer = 0;
	var passData:Null<Bytes>;
	var reaches:Array<{skin:Skin3D, reach:haxe.ds.Vector<Float>}> = [];

	/** A mesh of vertexCount vertices in vertices (Lit3DProgram.stride bytes each) and indexCount uint32 indices (whole triangles) in indices.
		Throws for a count of 0 or less, too few bytes, or an index past the vertices. */
	public function new(vertices:Bytes, vertexCount:Int, indices:Bytes, indexCount:Int) {
		if (vertexCount <= 0
			|| indexCount <= 0
			|| indexCount % 3 != 0
			|| vertices.length < vertexCount * Lit3DProgram.stride
			|| indices.length < indexCount * 4)
			throw "Invalid mesh";
		for (i in 0...indexCount)
			if (indices.getInt32(i * 4) < 0 || indices.getInt32(i * 4) >= vertexCount)
				throw "Mesh index out of range";
		vertexData = vertices;
		this.vertexCount = vertexCount;
		indexData = indices;
		this.indexCount = indexCount;
		loX = loY = loZ = Math.POSITIVE_INFINITY;
		hiX = hiY = hiZ = Math.NEGATIVE_INFINITY;
		for (i in 0...vertexCount) {
			var at = i * Lit3DProgram.stride + Lit3DProgram.positionOffset;
			var x = vertices.getFloat(at),
				y = vertices.getFloat(at + 4),
				z = vertices.getFloat(at + 8);
			loX = Math.min(loX, x);
			loY = Math.min(loY, y);
			loZ = Math.min(loZ, z);
			hiX = Math.max(hiX, x);
			hiY = Math.max(hiY, y);
			hiZ = Math.max(hiZ, z);
		}
	}

	/** Its vertices. */
	public var vertexCount(default, null):Int;

	/** Its indices: three a triangle. */
	public var indexCount(default, null):Int;

	/** The vertex data, Lit3DProgram.stride bytes a vertex. */
	public var vertices(get, never):Bytes;

	function get_vertices():Bytes
		return vertexData;

	/** The indices, uint32 each. */
	public var indices(get, never):Bytes;

	function get_indices():Bytes
		return indexData;

	/** The box around it: its smallest x. */
	public var minX(get, never):Float;

	function get_minX():Float
		return loX;

	/** Its smallest y. */
	public var minY(get, never):Float;

	function get_minY():Float
		return loY;

	/** Its smallest z. */
	public var minZ(get, never):Float;

	function get_minZ():Float
		return loZ;

	/** Its largest x. */
	public var maxX(get, never):Float;

	function get_maxX():Float
		return hiX;

	/** Its largest y. */
	public var maxY(get, never):Float;

	function get_maxY():Float
		return hiY;

	/** Its largest z. */
	public var maxZ(get, never):Float;

	function get_maxZ():Float
		return hiZ;

	/** Whether its vertices follow joints (a skin's): a Model3D showing it needs one (Model3D.skin). */
	public var skinned(get, never):Bool;

	function get_skinned():Bool
		return skinData != null;

	/** A skinned mesh's joints and weights, Skinned3DProgram.skinStride bytes a vertex: four joint indices (as floats), then their four
		weights, summing to 1. Null for one that isn't skinned. */
	public var skinData(default, null):Null<Bytes>;

	/** What made it, for a mesh from plane, cube, sphere, cylinder, cone, capsule or torus: the generator's name and its arguments as it
		was called. Null for a mesh from arrays (fromArrays, a file's meshes), which nothing can write back as a shape. */
	public var shape(default, null):Null<MeshShape3D>;

	/** How far each of skin's joints reaches in this skinned mesh as bound: the farthest of the vertices it weights from its bind position
		(Skin3D.getBindPosition), -1 for a joint that weights none; worked out the first time it's asked for each skin, for culling a posed model.
		Null for a mesh that isn't skinned. */
	public function getJointReach(skin:Skin3D):Null<haxe.ds.Vector<Float>> {
		if (skinData == null)
			return null;
		for (r in reaches)
			if (r.skin == skin)
				return r.reach;
		var count = skin.jointCount, reach = new haxe.ds.Vector<Float>(count);
		for (j in 0...count)
			reach[j] = -1;
		for (i in 0...vertexCount) {
			var at = i * Lit3DProgram.stride + Lit3DProgram.positionOffset,
				x = vertexData.getFloat(at),
				y = vertexData.getFloat(at + 4),
				z = vertexData.getFloat(at + 8);
			for (k in 0...4) {
				var s = i * Skinned3DProgram.skinStride;
				if (skinData.getFloat(s + Skinned3DProgram.weightsOffset + k * 4) <= 0)
					continue;
				var j = Std.int(skinData.getFloat(s + Skinned3DProgram.jointsOffset + k * 4) + .5);
				if (j >= count)
					continue;
				var dx = x - skin.getBindPosition(j, 0),
					dy = y - skin.getBindPosition(j, 1),
					dz = z - skin.getBindPosition(j, 2);
				var d = Math.sqrt(dx * dx + dy * dy + dz * dz);
				if (d > reach[j])
					reach[j] = d;
			}
		}
		reaches.push({skin: skin, reach: reach});
		return reach;
	}

	/** Its vertices as a model's passes (ModelPass3D: an outline, a silhouette) draw them, Flat3DProgram.stride bytes each: its position, then its
		normal averaged over every vertex at that position (the distinct normals of the vertices at exactly that place summed, then made unit
		length; the vertex's own normal where they cancel out). A hard edge splits a vertex into copies, one a face, each with its face's
		normal; pushed out along those, an outline's shell would crack into separate faces, so the copies move together instead. Worked out the
		first time it's read (a mesh no pass draws never has it), Flat3DProgram.stride bytes a vertex more. Vertices of separate meshes (a
		model's parts) aren't averaged together. */
	public var passVertices(get, never):Bytes;

	function get_passVertices():Bytes {
		if (passData == null)
			passData = averageNormals();
		return passData;
	}

	// Each vertex's position and its normal averaged over the vertices at its position: the vertices sorted by position, then by normal, so
	// those at one place are a run and its alike normals neighbours, each distinct one counted once.
	function averageNormals():Bytes {
		var data = vertexData;
		inline function at(i:Int, k:Int):Float
			return data.getFloat(i * Lit3DProgram.stride + k * 4);
		var position = Std.int(Lit3DProgram.positionOffset / 4),
			normal = Std.int(Lit3DProgram.normalOffset / 4);
		function compare(a:Int, b:Int, from:Int):Int {
			for (k in from...from + 3) {
				var x = at(a, k), y = at(b, k);
				if (x != y)
					return x < y ? -1 : 1;
			}
			return 0;
		}
		var order = [for (i in 0...vertexCount) i];
		order.sort((a, b) -> {
			var c = compare(a, b, position);
			if (c == 0)
				c = compare(a, b, normal);
			return c != 0 ? c : a - b;
		});
		var out = Bytes.alloc(vertexCount * Flat3DProgram.stride), start = 0;
		while (start < vertexCount) {
			var end = start + 1;
			while (end < vertexCount && compare(order[start], order[end], position) == 0)
				end++;
			var x = 0., y = 0., z = 0.;
			for (k in start...end)
				if (k == start || compare(order[k - 1], order[k], normal) != 0) {
					x += at(order[k], normal);
					y += at(order[k], normal + 1);
					z += at(order[k], normal + 2);
				}
			var length = Math.sqrt(x * x + y * y + z * z);
			for (k in start...end) {
				var i = order[k], o = i * Flat3DProgram.stride, n = o + Flat3DProgram.normalOffset;
				for (c in 0...3)
					out.setFloat(o + Flat3DProgram.positionOffset + c * 4, at(i, position + c));
				if (length > 1e-6) {
					out.setFloat(n, x / length);
					out.setFloat(n + 4, y / length);
					out.setFloat(n + 8, z / length);
				} else
					for (c in 0...3)
						out.setFloat(n + c * 4, at(i, normal + c));
			}
			start = end;
		}
		return out;
	}

	/** Its pass vertices (passVertices) as a static vertex buffer on gpu, made the first time it's asked for. */
	@:noCompletion
	public function getPassVertexBuffer(gpu:IGraphics):Int {
		upload(gpu);
		if (passBuffer == 0)
			passBuffer = gpu.createStaticBuffer(passVertices, vertexCount * Flat3DProgram.stride, false);
		return passBuffer;
	}

	/** A skinned mesh's static skin buffer on gpu, made the first time it's asked for; 0 for one that isn't skinned. */
	@:noCompletion
	public function getSkinBuffer(gpu:IGraphics):Int {
		upload(gpu);
		return skinBuffer;
	}

	/** Its static vertex buffer on gpu, made the first time it's asked for. */
	@:noCompletion
	public function getVertexBuffer(gpu:IGraphics):Int {
		upload(gpu);
		return vertexBuffer;
	}

	/** Its static index buffer on gpu, made the first time it's asked for. */
	@:noCompletion
	public function getIndexBuffer(gpu:IGraphics):Int {
		upload(gpu);
		return indexBuffer;
	}

	function upload(gpu:IGraphics):Void {
		if (this.gpu == gpu && vertexBuffer != 0)
			return;
		if (this.gpu != null && this.gpu != gpu)
			throw "A mesh lives on one IGraphics";
		this.gpu = gpu;
		vertexBuffer = gpu.createStaticBuffer(vertexData, vertexCount * Lit3DProgram.stride, false);
		indexBuffer = gpu.createStaticBuffer(indexData, indexCount * 4, true);
		if (skinData != null)
			skinBuffer = gpu.createStaticBuffer(skinData, vertexCount * Skinned3DProgram.skinStride, false);
	}

	/** Frees its buffers, if it was uploaded; drawing it again uploads it again. */
	public function destroy():Void {
		if (gpu == null)
			return;
		gpu.destroyBuffer(vertexBuffer);
		gpu.destroyBuffer(indexBuffer);
		if (skinBuffer != 0)
			gpu.destroyBuffer(skinBuffer);
		if (passBuffer != 0)
			gpu.destroyBuffer(passBuffer);
		vertexBuffer = indexBuffer = skinBuffer = passBuffer = 0;
		gpu = null;
	}

	/** A mesh from arrays: positions (x, y, z each), normals (one a position, unit length; null to work them out from the triangles), texture
		coordinates (u, v each; null for zeros), tangents (x, y, z, w each, w the bitangent's sign; null to work them out) and indices (whole
		triangles; null for each three positions a triangle, in order); skinned when joints (four joint indices a vertex) and weights (their four
		weights, normalized here) are given. Throws for arrays that don't agree. */
	public static function fromArrays(positions:Array<Float>, normals:Null<Array<Float>>, uvs:Null<Array<Float>>, tangents:Null<Array<Float>>,
			indices:Null<Array<Int>>, ?joints:Array<Float>, ?weights:Array<Float>):Mesh3D {
		var count = Std.int(positions.length / 3);
		if (count == 0 || positions.length != count * 3 || normals != null && normals.length != count * 3 || uvs != null && uvs.length != count * 2
			|| tangents != null && tangents.length != count * 4)
			throw "Mesh arrays disagree";
		var b = new MeshBuilder();
		for (i in 0...count)
			b.vertex(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2], normals == null ? 0 : normals[i * 3],
				normals == null ? 0 : normals[i * 3 + 1], normals == null ? 0 : normals[i * 3 + 2], uvs == null ? 0 : uvs[i * 2],
				uvs == null ? 0 : uvs[i * 2 + 1]);
		var order = indices == null ? [for (i in 0...count) i] : indices;
		if (order.length % 3 != 0)
			throw "Mesh indices aren't whole triangles";
		// The file's winding is the truth here: triangles go in as given, not turned to their normals.
		for (i in order)
			if (i < 0 || i >= count)
				throw "Mesh index out of range";
		b.raw(order);
		if (normals == null)
			b.smoothNormals();
		var mesh = b.build(tangents);
		if (joints != null || weights != null) {
			if (joints == null || weights == null || joints.length != count * 4 || weights.length != count * 4)
				throw "Mesh arrays disagree";
			var skin = Bytes.alloc(count * Skinned3DProgram.skinStride);
			for (i in 0...count) {
				var at = i * Skinned3DProgram.skinStride, sum = 0.;
				for (k in 0...4)
					sum += weights[i * 4 + k];
				for (k in 0...4) {
					if (joints[i * 4 + k] < 0)
						throw "A negative joint";
					skin.setFloat(at + Skinned3DProgram.jointsOffset + k * 4, joints[i * 4 + k]);
					// Weights summing to 0 (an unweighted vertex) follow the first joint.
					skin.setFloat(at + Skinned3DProgram.weightsOffset + k * 4, sum > 0 ? weights[i * 4 + k] / sum : k == 0 ? 1 : 0);
				}
			}
			mesh.skinData = skin;
		}
		return mesh;
	}

	/** A block raised from a 2D outline: points (x and y in turn, at least 3, either winding, convex or not, not crossing itself) laid on the
		ground, a point's x as x and its y as z, raised height up y from 0. It has a top, a bottom, and a flat side for each edge, each face
		its own vertices (sharp edges). Texture coordinates are in world units over uvScale (a repeat every uvScale units): the top and bottom
		by x and z, the sides along the outline and down from the top, so blocks side by side with the same uvScale are patterned alike. A
		Tiled polygon's points (TiledObject2D.computePoints) become a wall or a raised floor. Throws for fewer than 3 points or one that
		can't be filled. */
	public static function extrude(points:Array<Float>, height:Float, uvScale = 1.):Mesh3D {
		var n = points.length >> 1;
		var cap = n >= 3 ? helix.render2d.Polygon2D.triangulate(points) : [];
		if (cap.length == 0)
			throw "An outline to extrude needs 3 points or more, not crossing itself";
		var b = new MeshBuilder(), scale = uvScale > 0 ? uvScale : 1.;
		// The top and the bottom, each the outline filled (MeshBuilder turns each triangle to face its normals).
		for (face in 0...2) {
			var y = face == 0 ? height : 0.,
				up = face == 0 ? 1 : -1,
				first = b.vertexCount;
			for (i in 0...n)
				b.vertex(points[i * 2], y, points[i * 2 + 1], 0, up, 0, points[i * 2] / scale, points[i * 2 + 1] / scale);
			var k = 0;
			while (k + 2 < cap.length) {
				b.triangle(first + cap[k], first + cap[k + 1], first + cap[k + 2]);
				k += 3;
			}
		}
		// The sides: each edge's outward normal, by the outline's winding (its signed area).
		var area = 0.;
		for (i in 0...n) {
			var j = (i + 1) % n;
			area += points[i * 2] * points[j * 2 + 1] - points[j * 2] * points[i * 2 + 1];
		}
		var outward = area > 0 ? 1 : -1, along = 0.;
		for (i in 0...n) {
			var j = (i + 1) % n,
				ax = points[i * 2],
				az = points[i * 2 + 1],
				bx = points[j * 2],
				bz = points[j * 2 + 1];
			var dx = bx - ax, dz = bz - az, length = Math.sqrt(dx * dx + dz * dz);
			if (length == 0)
				continue;
			var nx = dz / length * outward,
				nz = -dx / length * outward,
				first = b.vertexCount;
			var u0 = along / scale,
				u1 = (along + length) / scale,
				bottom = height / scale;
			b.vertex(ax, height, az, nx, 0, nz, u0, 0);
			b.vertex(bx, height, bz, nx, 0, nz, u1, 0);
			b.vertex(bx, 0, bz, nx, 0, nz, u1, bottom);
			b.vertex(ax, 0, az, nx, 0, nz, u0, bottom);
			b.quad(first, first + 1, first + 2, first + 3);
			along += length;
		}
		return b.build();
	}

	/** Flat in x and z, facing +y, width along x and length along z, subdivisions (0..256) more cells each way; texture coordinates span it
		once. */
	public static function plane(width:Float, length:Float, subdivisions = 0):Mesh3D {
		var cells = clamp(subdivisions, 0, 256) + 1, b = new MeshBuilder();
		for (j in 0...cells + 1)
			for (i in 0...cells + 1)
				b.vertex((i / cells - .5) * width, 0, (j / cells - .5) * length, 0, 1, 0, i / cells, j / cells);
		for (j in 0...cells)
			for (i in 0...cells)
				b.quad(j * (cells + 1) + i, j * (cells + 1) + i + 1, (j + 1) * (cells + 1) + i + 1, (j + 1) * (cells + 1) + i);
		return made(b, "plane", ["width" => width, "length" => length, "subdivisions" => subdivisions]);
	}

	/** A box width along x, height along y and length along z, each face its own vertices (sharp edges), textured 0..1 a face. */
	public static function cube(width:Float, height:Float, length:Float):Mesh3D {
		var b = new MeshBuilder(), x = width / 2, y = height / 2, z = length / 2;
		// Each face: its normal, then its u and v axes (scaled to the half extents), so corners are center -u-v, +u-v, +u+v, -u+v.
		var faces = [
			[0, 0, 1, x, 0, 0, 0, y, 0],
			[0, 0, -1, -x, 0, 0, 0, y, 0],
			[1, 0, 0, 0, 0, -z, 0, y, 0],
			[-1, 0, 0, 0, 0, z, 0, y, 0],
			[0, 1, 0, x, 0, 0, 0, 0, -z],
			[0, -1, 0, x, 0, 0, 0, 0, z]
		];
		for (f in faces) {
			var nx = f[0], ny = f[1], nz = f[2], cx = nx * x, cy = ny * y, cz = nz * z;
			var first = b.vertexCount;
			for (corner in [[-1, -1, 0, 1], [1, -1, 1, 1], [1, 1, 1, 0], [-1, 1, 0, 0]])
				b.vertex(cx
					+ corner[0] * f[3] + corner[1] * f[6], cy
					+ corner[0] * f[4] + corner[1] * f[7], cz
					+ corner[0] * f[5] + corner[1] * f[8], nx, ny,
					nz, corner[2], corner[3]);
			b.quad(first, first + 1, first + 2, first + 3);
		}
		return made(b, "cube", ["width" => width, "height" => height, "length" => length]);
	}

	/** A sphere of radius, rings (2..256) from pole to pole and segments (3..512) around; u around, v from the top pole to the bottom. */
	public static function sphere(radius:Float, rings = 16, segments = 32):Mesh3D {
		var b = new MeshBuilder();
		band(b, clamp(rings, 2, 256), clamp(segments, 3, 512), radius, 0, Math.PI, 0, 0, 1);
		return made(b, "sphere", ["radius" => radius, "rings" => rings, "segments" => segments]);
	}

	/** A capped cylinder along y, of radius and height, segments (3..512) around. */
	public static function cylinder(radius:Float, height:Float, segments = 32):Mesh3D {
		var b = new MeshBuilder(), n = clamp(segments, 3, 512), h = height / 2;
		side(b, n, radius, radius, -h, h);
		cap(b, n, radius, h, 1);
		cap(b, n, radius, -h, -1);
		return made(b, "cylinder", ["radius" => radius, "height" => height, "segments" => segments]);
	}

	/** A cone along y, tip up, of base radius and height, its base capped, segments (3..512) around. */
	public static function cone(radius:Float, height:Float, segments = 32):Mesh3D {
		var b = new MeshBuilder(), n = clamp(segments, 3, 512), h = height / 2;
		side(b, n, radius, 0, -h, h);
		cap(b, n, radius, -h, -1);
		return made(b, "cone", ["radius" => radius, "height" => height, "segments" => segments]);
	}

	/** A capsule along y: height from end to end (at least twice the radius; less is a sphere), rings (2..256) across both round ends, segments
		(3..512) around. */
	public static function capsule(radius:Float, height:Float, rings = 16, segments = 32):Mesh3D {
		var b = new MeshBuilder(),
			n = clamp(segments, 3, 512),
			half = Std.int(Math.max(1, clamp(rings, 2, 256) / 2));
		var straight = Math.max(0, height / 2 - radius);
		var total = 2 * (radius + straight);
		band(b, half, n, radius, 0, Math.PI / 2, straight, 0, radius / total);
		side(b, n, radius, radius, -straight, straight, (radius + straight) / total, (radius + straight * 3) / total);
		band(b, half, n, radius, Math.PI / 2, Math.PI, -straight, (total - radius) / total, 1);
		return made(b, "capsule", ["radius" => radius, "height" => height, "rings" => rings, "segments" => segments]);
	}

	/** A ring around y: radius to the middle of the tube, thickness the tube's radius, rings (3..512) around the ring and segments (3..512)
		around the tube. */
	public static function torus(radius:Float, thickness:Float, rings = 32, segments = 16):Mesh3D {
		var b = new MeshBuilder(),
			nr = clamp(rings, 3, 512),
			ns = clamp(segments, 3, 512);
		for (i in 0...nr + 1) {
			// su = -sin, so u runs left to right seen from outside, as the sphere's.
			var u = i / nr * Math.PI * 2, cu = Math.cos(u), su = -Math.sin(u);
			for (j in 0...ns + 1) {
				var v = j / ns * Math.PI * 2,
					cv = Math.cos(v),
					sv = Math.sin(v);
				b.vertex((radius + thickness * cv) * cu, thickness * sv, (radius + thickness * cv) * su, cv * cu, sv, cv * su, i / nr, j / ns);
			}
		}
		for (i in 0...nr)
			for (j in 0...ns)
				b.quad(i * (ns + 1) + j, (i + 1) * (ns + 1) + j, (i + 1) * (ns + 1) + j + 1, i * (ns + 1) + j + 1);
		return made(b, "torus", [
			"radius" => radius,
			"thickness" => thickness,
			"rings" => rings,
			"segments" => segments
		]);
	}

	// The builder's mesh, recorded as made by the generator name called with arguments.
	static function made(b:MeshBuilder, name:String, arguments:Map<String, Float>):Mesh3D {
		var mesh = b.build();
		mesh.shape = new MeshShape3D(name, arguments);
		return mesh;
	}

	static function clamp(value:Int, min:Int, max:Int):Int
		return value < min ? min : value > max ? max : value;

	// Part of a sphere from latitude from to to (0 the top pole, pi the bottom), raised by lift, v from v0 to v1.
	static function band(b:MeshBuilder, rings:Int, segments:Int, radius:Float, from:Float, to:Float, lift:Float, v0:Float, v1:Float):Void {
		var first = b.vertexCount;
		for (r in 0...rings + 1) {
			var a = from + (to - from) * r / rings,
				y = Math.cos(a),
				ring = Math.sin(a);
			for (s in 0...segments + 1) {
				var t = s / segments * Math.PI * 2,
					nx = ring * Math.cos(t), // z = -sin, so u runs left to right seen from outside: a texture reads the right way round.
					nz = -ring * Math.sin(t);
				b.vertex(nx * radius, y * radius + lift, nz * radius, nx, y, nz, s / segments, v0 + (v1 - v0) * r / rings);
			}
		}
		for (r in 0...rings)
			for (s in 0...segments)
				b.quad(first
					+ r * (segments + 1)
					+ s, first
					+ r * (segments + 1)
					+ s
					+ 1, first
					+ (r + 1) * (segments + 1)
					+ s
					+ 1,
					first
					+ (r + 1) * (segments + 1)
					+ s);
	}

	// A side around y from radius bottom at y0 to radius top at y1, normals tilted by the slope, v from v0 at the top to v1 at the bottom.
	static function side(b:MeshBuilder, segments:Int, bottom:Float, top:Float, y0:Float, y1:Float, v0 = 0., v1 = 1.):Void {
		var first = b.vertexCount,
			slope = (bottom - top) / (y1 - y0),
			length = Math.sqrt(1 + slope * slope);
		for (s in 0...segments + 1) {
			var t = s / segments * Math.PI * 2,
				c = Math.cos(t),
				sn = -Math.sin(t);
			// sn = -sin, so u runs left to right seen from outside, as the sphere's.
			b.vertex(c * top, y1, sn * top, c / length, slope / length, sn / length, s / segments, v0);
			b.vertex(c * bottom, y0, sn * bottom, c / length, slope / length, sn / length, s / segments, v1);
		}
		for (s in 0...segments)
			b.quad(first + s * 2, first + s * 2 + 2, first + s * 2 + 3, first + s * 2 + 1);
	}

	// A flat disc of radius at y, facing up (1) or down (-1).
	static function cap(b:MeshBuilder, segments:Int, radius:Float, y:Float, facing:Int):Void {
		var center = b.vertexCount;
		b.vertex(0, y, 0, 0, facing, 0, .5, .5);
		for (s in 0...segments + 1) {
			var t = s / segments * Math.PI * 2,
				c = Math.cos(t),
				sn = Math.sin(t);
			b.vertex(c * radius, y, sn * radius, 0, facing, 0, .5 + c / 2, .5 + sn / 2);
		}
		for (s in 0...segments)
			b.triangle(center, center + 1 + s, center + 2 + s);
	}
}

/** Collects a mesh's vertices and triangles; each triangle is wound counter-clockwise from the side its vertices' normals face. */
private class MeshBuilder {
	var positions:Array<Float> = [];
	var normals:Array<Float> = [];
	var uvs:Array<Float> = [];
	var indices:Array<Int> = [];

	/** An empty builder. */
	public function new() {}

	/** The vertices so far. */
	public var vertexCount(get, never):Int;

	function get_vertexCount():Int
		return Std.int(positions.length / 3);

	/** A vertex: its position, its normal (unit length) and its texture coordinates. */
	public function vertex(x:Float, y:Float, z:Float, nx:Float, ny:Float, nz:Float, u:Float, v:Float):Void {
		positions.push(x);
		positions.push(y);
		positions.push(z);
		normals.push(nx);
		normals.push(ny);
		normals.push(nz);
		uvs.push(u);
		uvs.push(v);
	}

	/** The triangle, its winding turned to face its normals; nothing for one of no area (a pole's). */
	public function triangle(a:Int, b:Int, c:Int):Void {
		var ax = positions[a * 3],
			ay = positions[a * 3 + 1],
			az = positions[a * 3 + 2];
		var ux = positions[b * 3] - ax,
			uy = positions[b * 3 + 1] - ay,
			uz = positions[b * 3 + 2] - az;
		var vx = positions[c * 3] - ax,
			vy = positions[c * 3 + 1] - ay,
			vz = positions[c * 3 + 2] - az;
		var cx = uy * vz - uz * vy,
			cy = uz * vx - ux * vz,
			cz = ux * vy - uy * vx;
		if (cx * cx + cy * cy + cz * cz < 1e-20)
			return;
		var nx = normals[a * 3] + normals[b * 3] + normals[c * 3],
			ny = normals[a * 3 + 1] + normals[b * 3 + 1] + normals[c * 3 + 1],
			nz = normals[a * 3 + 2] + normals[b * 3 + 2] + normals[c * 3 + 2];
		indices.push(a);
		if (cx * nx + cy * ny + cz * nz >= 0) {
			indices.push(b);
			indices.push(c);
		} else {
			indices.push(c);
			indices.push(b);
		}
	}

	/** Triangles as given, winding and all. */
	public function raw(order:Array<Int>):Void
		for (i in order)
			indices.push(i);

	/** Each vertex's normal: the area-weighted sum of its triangles' normals, made unit length. */
	public function smoothNormals():Void {
		for (i in 0...normals.length)
			normals[i] = 0;
		var k = 0;
		while (k + 2 < indices.length) {
			var a = indices[k], b = indices[k + 1], c = indices[k + 2];
			k += 3;
			var ux = positions[b * 3] - positions[a * 3],
				uy = positions[b * 3 + 1] - positions[a * 3 + 1],
				uz = positions[b * 3 + 2] - positions[a * 3 + 2];
			var vx = positions[c * 3] - positions[a * 3],
				vy = positions[c * 3 + 1] - positions[a * 3 + 1],
				vz = positions[c * 3 + 2] - positions[a * 3 + 2];
			var nx = uy * vz - uz * vy,
				ny = uz * vx - ux * vz,
				nz = ux * vy - uy * vx;
			for (v in [a, b, c]) {
				normals[v * 3] += nx;
				normals[v * 3 + 1] += ny;
				normals[v * 3 + 2] += nz;
			}
		}
		for (v in 0...vertexCount) {
			var x = normals[v * 3],
				y = normals[v * 3 + 1],
				z = normals[v * 3 + 2],
				l = Math.sqrt(x * x + y * y + z * z);
			normals[v * 3] = l > 0 ? x / l : 0;
			normals[v * 3 + 1] = l > 0 ? y / l : 1;
			normals[v * 3 + 2] = l > 0 ? z / l : 0;
		}
	}

	/** Two triangles: a, b, c and a, c, d. */
	public function quad(a:Int, b:Int, c:Int, d:Int):Void {
		triangle(a, b, c);
		triangle(a, c, d);
	}

	/** Tangents for normal mapping (the earlier frameworks' way): from each triangle's positions and texture coordinates, averaged at each
		vertex and made perpendicular to its normal, following increasing u; w is the bitangent's sign, the bitangent cross(normal, tangent) * w
		pointing toward decreasing v (the texture's up). A vertex with no usable mapping gets any tangent perpendicular to its normal. */
	function tangentsOf():Array<Float> {
		var count = this.vertexCount,
			tangents = [for (_ in 0...count * 4) 0.],
			bitangents = [for (_ in 0...count * 3) 0.];
		var k = 0;
		while (k + 2 < indices.length) {
			var i0 = indices[k], i1 = indices[k + 1], i2 = indices[k + 2];
			k += 3;
			var e1x = positions[i1 * 3] - positions[i0 * 3],
				e1y = positions[i1 * 3 + 1] - positions[i0 * 3 + 1],
				e1z = positions[i1 * 3 + 2] - positions[i0 * 3 + 2];
			var e2x = positions[i2 * 3] - positions[i0 * 3],
				e2y = positions[i2 * 3 + 1] - positions[i0 * 3 + 1],
				e2z = positions[i2 * 3 + 2] - positions[i0 * 3 + 2];
			var du1 = uvs[i1 * 2] - uvs[i0 * 2],
				dv1 = uvs[i1 * 2 + 1] - uvs[i0 * 2 + 1],
				du2 = uvs[i2 * 2] - uvs[i0 * 2],
				dv2 = uvs[i2 * 2 + 1] - uvs[i0 * 2 + 1];
			var det = du1 * dv2 - du2 * dv1;
			if (Math.abs(det) < 1e-12)
				continue;
			det = 1 / det;
			var sx = (e1x * dv2 - e2x * dv1) * det,
				sy = (e1y * dv2 - e2y * dv1) * det,
				sz = (e1z * dv2 - e2z * dv1) * det;
			var tx = (e2x * du1 - e1x * du2) * det,
				ty = (e2y * du1 - e1y * du2) * det,
				tz = (e2z * du1 - e1z * du2) * det;
			for (v in [i0, i1, i2]) {
				tangents[v * 4] += sx;
				tangents[v * 4 + 1] += sy;
				tangents[v * 4 + 2] += sz;
				bitangents[v * 3] += tx;
				bitangents[v * 3 + 1] += ty;
				bitangents[v * 3 + 2] += tz;
			}
		}
		for (i in 0...count) {
			var nx = normals[i * 3],
				ny = normals[i * 3 + 1],
				nz = normals[i * 3 + 2];
			var tx = tangents[i * 4],
				ty = tangents[i * 4 + 1],
				tz = tangents[i * 4 + 2];
			var d = nx * tx + ny * ty + nz * tz;
			tx -= nx * d;
			ty -= ny * d;
			tz -= nz * d;
			var w = 1.;
			if (tx * tx + ty * ty + tz * tz < 1e-12) {
				// No texture mapping here: any direction perpendicular to the normal.
				tx = Math.abs(nx) < .9 ? 1 : 0;
				ty = Math.abs(nx) < .9 ? 0 : 1;
				tz = 0;
				d = nx * tx + ny * ty;
				tx -= nx * d;
				ty -= ny * d;
				tz -= nz * d;
			} else {
				// cross(n, t) against the bitangent: the map's up (green) points toward decreasing v.
				var cx = ny * tz - nz * ty,
					cy = nz * tx - nx * tz,
					cz = nx * ty - ny * tx;
				if (cx * bitangents[i * 3] + cy * bitangents[i * 3 + 1] + cz * bitangents[i * 3 + 2] > 0)
					w = -1;
			}
			var l = Math.sqrt(tx * tx + ty * ty + tz * tz);
			tangents[i * 4] = tx / l;
			tangents[i * 4 + 1] = ty / l;
			tangents[i * 4 + 2] = tz / l;
			tangents[i * 4 + 3] = w;
		}
		return tangents;
	}

	/** The mesh of everything added, with given tangents or, without, its tangents worked out from the triangles' positions and texture
		coordinates. */
	public function build(?given:Array<Float>):Mesh3D {
		var count = this.vertexCount,
			data = Bytes.alloc(count * Lit3DProgram.stride),
			tangents = given != null ? given : tangentsOf();
		for (i in 0...count) {
			var at = i * Lit3DProgram.stride;
			data.setFloat(at + Lit3DProgram.positionOffset, positions[i * 3]);
			data.setFloat(at + Lit3DProgram.positionOffset + 4, positions[i * 3 + 1]);
			data.setFloat(at + Lit3DProgram.positionOffset + 8, positions[i * 3 + 2]);
			data.setFloat(at + Lit3DProgram.normalOffset, normals[i * 3]);
			data.setFloat(at + Lit3DProgram.normalOffset + 4, normals[i * 3 + 1]);
			data.setFloat(at + Lit3DProgram.normalOffset + 8, normals[i * 3 + 2]);
			data.setFloat(at + Lit3DProgram.uvOffset, uvs[i * 2]);
			data.setFloat(at + Lit3DProgram.uvOffset + 4, uvs[i * 2 + 1]);
			for (k in 0...4)
				data.setFloat(at + Lit3DProgram.tangentOffset + k * 4, tangents[i * 4 + k]);
		}
		var index = Bytes.alloc(indices.length * 4);
		for (i in 0...indices.length)
			index.setInt32(i * 4, indices[i]);
		return new Mesh3D(data, count, index, indices.length);
	}
}
