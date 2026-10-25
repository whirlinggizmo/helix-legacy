package helix.render3d;

import helix.math.Bounds3D;
import helix.scene.Node;
import helix.render3d.Attachment3D;

/** What a 3D stage holds: a transform in a tree, with children of its own kind (Godot's Node3D). A bare one is a group: it draws nothing,
	only a transform for its children (an empty in Blender, a dummy in 3ds Max, a null in Cinema 4D), a handle that moves or hides a set of
	things together, or a pivot to turn them about. The framework's kinds are its classes (Model3D, DirectionalLight3D, PointLight3D, SpotLight3D,
	Camera3D, Sprite3D, Text3D, Particles3D), each holding only its own data; a game never subclasses one, and game state lives elsewhere, the
	node its view (docs/DECISIONS.md, 61 and 130). Its transform is a position, a rotation (a unit quaternion, set from angles or by lookAt) and
	a scale, relative to its parent; its world matrix is worked out when a stage draws it, only after it or a node above it changed. */
class Node3D extends Node {
	var px = 0.;
	var py = 0.;
	var pz = 0.;
	var qx = 0.;
	var qy = 0.;
	var qz = 0.;
	var qw = 1.;
	var sx = 1.;
	var sy = 1.;
	var sz = 1.;
	var local = new Mat4();
	var world = new Mat4();
	var localDirty = true;
	// At a tree's top, counted up by every addChild and removeChild below it: a stage keeps its lists of kinds until its root's count moves.
	@:allow(helix.render3d.Renderer3D)
	var structure = 0;

	// Whether it's a kind that draws itself (Drawing3D), drawn by drawOwn after the renderer's opaque models.
	@:allow(helix.render3d.Renderer3D)
	var drawsOwn(get, never):Bool;

	function get_drawsOwn():Bool
		return false;

	// Draws itself through camera with renderer's GPU, first beginning the batch the kinds share (Renderer3D.ownBatch), last ending it.

	@:allow(helix.render3d.Renderer3D)
	function drawOwn(camera:Camera3D, renderer:Renderer3D, first:Bool, last:Bool):Void {}

	// Whether it's a kind drawn through the renderer's sprites (Sprite3D and Text3D flat, Particles3D an emitter), and which: linked only
	// into a program that makes one. Listed, it makes the renderer's sprites if they aren't yet (attachSprites).
	@:allow(helix.render3d.Renderer3D)
	var spriteKind(get, never):SpriteKind3D;

	function get_spriteKind():SpriteKind3D
		return None;

	// Gives renderer its sprites (Renderer3D.sprites) if it has none.

	@:allow(helix.render3d.Renderer3D)
	function attachSprites(renderer:Renderer3D):Void {}

	// Into sprites (the renderer's Sprites3D) to draw, seen from the eye looking along forward, culled by planes; an emitter held still if
	// still.

	@:allow(helix.render3d.Renderer3D)
	function visitSprites(sprites:Any, planes:haxe.ds.Vector<Float>, eyeX:Float, eyeY:Float, eyeZ:Float, forwardX:Float, forwardY:Float, forwardZ:Float,
		still:Bool):Void {}

	// A hidden emitter moving on without drawing.

	@:allow(helix.render3d.Renderer3D)
	function advanceSprites(sprites:Any):Void {}

	// Tested against ray as sprites draws it: the distance along it, recorded in hit when nearer than best, else best.

	@:allow(helix.render3d.Renderer3D)
	function pickSprites(sprites:Any, ray:Ray3D, best:Float, hit:PickHit3D):Float
		return best;

	// The quad a pick tests, as sprites shows it (after its preparePick), its four corners in the world into out; false for none.

	@:allow(helix.debug.PickOverlay3D)
	function hitQuad(sprites:Any, out:Array<Float>):Bool
		return false;

	/** The light of the place under it (Environment3D: ambient light, environment map, background), or null: a level's root carries its
		level's (a scene file's "environment" section). A View3D lights its tree by its own environment if it has one, else by the first one
		in its tree (the root's, depth first); others are logged once and not used yet (the nearest ancestor's, docs/ROADMAP.md). */
	public var environment:Null<Environment3D>;

	/** The shape it's picked by in place of what it draws, in its own units, never drawn; null (the default) for what it draws. A group with
		one is picked by it; its children are picked as ever, the nearest hit winning. */
	public var hitArea:Null<HitArea3D> = null;

	/** A group at the origin, unturned and unscaled, with no children. */
	public function new()
		super();

	/** Makes child its last child, taking it from any parent it had, keeping child's local transform: it moves with this node as it sat
		under its old parent (a hat onto a head joint). addChildInPlace keeps its world transform instead. False, changing nothing, for
		itself or one of its own ancestors. */
	public function addChild(child:Node3D):Bool
		return addChildAt(child, -1);

	/** Makes child its child at index in drawing order (0 is drawn first, under the others; those from index on move up one), taking it
		from any parent it had and keeping its local transform, as addChild does; an index past the end, or -1, makes it the last. A child
		of this node already moves to index. False, changing nothing, for itself or one of its own ancestors. */
	public function addChildAt(child:Node3D, index:Int):Bool {
		var from = child.parent;
		if (!link(child, index))
			return false;
		if (from != null && from != this)
			from.changed();
		changed();
		child.localDirty = true;
		return true;
	}

	/** Puts child under this node without it moving: its world transform is kept and its local one recomputed from this node's (a dropped
		sword picked up by a hand). addChild keeps the child's local transform instead (a hat onto a head joint). A shear the two
		transforms make together is lost. False, changing nothing, for itself or one of its own ancestors, or a zero scale on this or above
		it. */
	public function addChildInPlace(child:Node3D):Bool {
		if (!canLink(child))
			return false;
		var world = new Mat4(), mine = new Mat4();
		child.computeWorld(world);
		computeWorld(mine);
		if (!mine.makeInverse(mine))
			return false;
		world.makeProduct(mine, world);
		var local = [for (i in 0...16) world.get(i)];
		var from = child.parent;
		if (!link(child))
			return false;
		if (from != null)
			from.changed();
		changed();
		child.setMatrix(local);
		child.localDirty = true;
		return true;
	}

	/** Takes its child at index (in drawing order) from its children and returns it, or null past the end, changing nothing. */
	public function removeChildAt(index:Int):Null<Node3D> {
		var child = getChild(index);
		return child != null && removeChild(child) ? child : null;
	}

	/** Takes child from its children. False when it isn't one. */
	public function removeChild(child:Node3D):Bool {
		if (!unlink(child))
			return false;
		changed();
		child.localDirty = true;
		return true;
	}

	// Its tree's shape changed: counted at the top.
	function changed():Void {
		var top:Node3D = this;
		while (top.parentNode != null)
			top = cast top.parentNode;
		top.structure++;
	}

	/** Its parent, or null at a tree's top. Assigning a node makes this its last child as that node's addChild does, keeping this one's
		local transform (addChildInPlace keeps the world one); assigning null takes it from its parent as the parent's removeChild does. A
		node under itself or one of its own descendants is refused, leaving the tree as it was. */
	public var parent(get, set):Null<Node3D>;

	function get_parent():Null<Node3D>
		return cast parentNode;

	function set_parent(value:Null<Node3D>):Null<Node3D> {
		if (value != null)
			value.addChild(this);
		else if (parentNode != null)
			get_parent().removeChild(this);
		return get_parent();
	}

	/** Its child at index, in drawing order; null past the end. */
	override public function getChild(index:Int):Null<Node3D>
		return cast super.getChild(index);

	/** The models at or under it, sorted: the skinned ones (bound to a skeleton by bindSkeleton) into skinned, the rigid ones into rigid, a
		rigid model's own children going with it (a sword's gem). A part file's own copy of an armature (an exporter's) is passed over, as only
		models are taken: with findAttachment, how a game dresses a character from files of their own (the examples' Outfit). */
	public function collectModels(skinned:Array<Model3D>, rigid:Array<Model3D>):Void {
		var model = Std.downcast(this, Model3D);
		if (model != null && model.mesh != null) {
			if (model.mesh.skinned)
				skinned.push(model);
			else {
				rigid.push(model);
				return;
			}
		}
		// Cast from children, not through getChild: hxcpp declares an override's return as the overridden one's (Node), which has no
		// collectModels.
		for (child in children)
			(cast child : Node3D).collectModels(skinned, rigid);
	}

	/** Where a rigid model under it (a part file's root, instantiated) attaches to skeleton: the piece to hang, the node just under model's
		nearest ancestor below this named as a joint skeleton has (an importer may split one mesh into several models, so the piece may be above
		model, and its siblings go with it), and that joint, which the piece keeps its offset from. A file whose models sit under no joint gives the
		node just under this as the piece and null as the joint, for a socket the game chooses. Null when model isn't under this. */
	public function findAttachment(model:Model3D, skeleton:Node3D):Null<Attachment3D> {
		var piece:Node3D = model, above = model.parent;
		while (above != null && above != this && jointOf(skeleton, above.name) == null) {
			piece = above;
			above = above.parent;
		}
		if (above == null)
			return null;
		return {piece: piece, joint: above == this ? null : jointOf(skeleton, above.name)};
	}

	static function jointOf(skeleton:Node3D, name:String):Null<Node3D>
		return name == "" ? null : skeleton.name == name ? skeleton : skeleton.find(name, Node3D);

	/** Its world matrix as it is now, into out (a new one when not given), returned: its own transform and every one above it, worked out
		afresh without touching what a stage keeps (a camera's view is found so, wherever it is). Given out, it allocates nothing. */
	public function computeWorld(?out:Mat4):Mat4 {
		if (out == null)
			out = new Mat4();
		out.makeTransform(px, py, pz, qx, qy, qz, qw, sx, sy, sz);
		var at = parent;
		while (at != null) {
			above.makeTransform(at.px, at.py, at.pz, at.qx, at.qy, at.qz, at.qw, at.sx, at.sy, at.sz);
			product.makeProduct(above, out);
			out.copyFrom(product);
			at = at.parent;
		}
		return out;
	}

	// The scratch matrices computeWorld and the bounds' walk reuse, and the walk's world matrix at each depth.
	static var above = new Mat4();
	static var product = new Mat4();
	static var worlds:Array<Mat4> = [];

	/** The box around it and everything under it as they are now, into out (a new one when not given), or null for nothing to bound: in the
		world, or in relativeTo's own units when given (as relativeTo's children are placed). Each model counts by its vertices (a skinned one's
		as posed), each sprite by the sphere its quad can turn in, placed by the transforms as they are now (a draw needn't have run). A disabled
		or hidden node and what's under it are left out, as text and emitters are. Null too for a relativeTo scaled to nothing. Exact where a
		stage's culling box is generous, for framing: a camera fitted to it. `computeBounds(scratch)` is the world into scratch: Haxe skips
		relativeTo for a Bounds3D. Given out, it allocates nothing once it has walked as deep a tree before. */
	public function computeBounds(?relativeTo:Node3D, ?out:Bounds3D):Null<Bounds3D> {
		var start = computeWorld(worldAt(0));
		if (relativeTo != null) {
			var seen = relativeTo.computeWorld(inverse);
			if (!seen.makeInverse(seen))
				return null;
			product.makeProduct(seen, start);
			start.copyFrom(product);
		}
		out = out != null ? out.clear() : new Bounds3D();
		gather(this, start, 0, out);
		return out.isEmpty ? null : out;
	}

	// relativeTo's world matrix, then its inverse, for computeBounds.
	static var inverse = new Mat4();

	static function worldAt(depth:Int):Mat4 {
		while (worlds.length <= depth)
			worlds.push(new Mat4());
		return worlds[depth];
	}

	static function gather(node:Node3D, world:Mat4, depth:Int, out:Bounds3D):Void {
		if (!node.visible)
			return;
		node.measureOwnWorld(world, out);
		for (i in 0...node.childCount) {
			var child = node.getChild(i), placed = worldAt(depth + 1);
			above.makeTransform(child.px, child.py, child.pz, child.qx, child.qy, child.qz, child.qw, child.sx, child.sy, child.sz);
			placed.makeProduct(world, above);
			gather(child, placed, depth + 1, out);
		}
	}

	// Grows out by what it draws itself (not its children), placed by world: a model's vertices, a sprite's turning quad. Nothing for a group. computeBounds.

	@:allow(helix.render3d)
	function measureOwnWorld(world:Mat4, out:Bounds3D):Void {}

	/** Its position's x, relative to its parent. */
	public var x(get, set):Float;

	function get_x():Float
		return px;

	function set_x(value:Float):Float {
		px = value;
		localDirty = true;
		return value;
	}

	/** Its position's y. */
	public var y(get, set):Float;

	function get_y():Float
		return py;

	function set_y(value:Float):Float {
		py = value;
		localDirty = true;
		return value;
	}

	/** Its position's z. */
	public var z(get, set):Float;

	function get_z():Float
		return pz;

	function set_z(value:Float):Float {
		pz = value;
		localDirty = true;
		return value;
	}

	/** Its rotation's quaternion x, relative to its parent. */
	public var quaternionX(get, never):Float;

	function get_quaternionX():Float
		return qx;

	/** Its rotation's quaternion y. */
	public var quaternionY(get, never):Float;

	function get_quaternionY():Float
		return qy;

	/** Its rotation's quaternion z. */
	public var quaternionZ(get, never):Float;

	function get_quaternionZ():Float
		return qz;

	/** Its rotation's quaternion w. */
	public var quaternionW(get, never):Float;

	function get_quaternionW():Float
		return qw;

	/** Its scale along its own x. */
	public var scaleX(get, set):Float;

	function get_scaleX():Float
		return sx;

	function set_scaleX(value:Float):Float {
		sx = value;
		localDirty = true;
		return value;
	}

	/** Its scale along its own y. */
	public var scaleY(get, set):Float;

	function get_scaleY():Float
		return sy;

	function set_scaleY(value:Float):Float {
		sy = value;
		localDirty = true;
		return value;
	}

	/** Its scale along its own z. */
	public var scaleZ(get, set):Float;

	function get_scaleZ():Float
		return sz;

	function set_scaleZ(value:Float):Float {
		sz = value;
		localDirty = true;
		return value;
	}

	/** Places it at x, y, z, relative to its parent. */
	public function setPosition(x:Float, y:Float, z:Float):Void {
		px = x;
		py = y;
		pz = z;
		localDirty = true;
	}

	/** Its rotation as angles in radians about x, then y, then z (setRotation's), x of them: worked out from its quaternion, so an equal
		turn, not always the angles set (y is kept within -pi/2..pi/2). */
	public var rotationX(get, never):Float;

	function get_rotationX():Float
		return euler(0);

	/** Its rotation's angle about y, radians, as rotationX. */
	public var rotationY(get, never):Float;

	function get_rotationY():Float
		return euler(1);

	/** Its rotation's angle about z, radians, as rotationX. */
	public var rotationZ(get, never):Float;

	function get_rotationZ():Float
		return euler(2);

	// One of the x, then y, then z angles turning as its quaternion does (the rotation matrix taken apart, as three.js does for this order).
	function euler(axis:Int):Float {
		var m11 = 1 - 2 * (qy * qy + qz * qz),
			m12 = 2 * (qx * qy - qz * qw),
			m21 = 2 * (qx * qy + qz * qw),
			m22 = 1 - 2 * (qx * qx + qz * qz),
			m31 = 2 * (qx * qz - qy * qw),
			m32 = 2 * (qy * qz + qx * qw),
			m33 = 1 - 2 * (qx * qx + qy * qy);
		var s = m31 < -1 ? -1 : m31 > 1 ? 1 : m31;
		var gimbal = Math.abs(s) >= .9999999;
		return switch axis {
			case 0: gimbal ? 0 : Math.atan2(m32, m33);
			case 1: Math.asin(-s);
			case _: gimbal ? Math.atan2(-m12, m22) : Math.atan2(m21, m11);
		}
	}

	/** Turns it by angles in radians about x, then y, then z, relative to its parent. */
	public function setRotation(x:Float, y:Float, z:Float):Void {
		var cx = Math.cos(x / 2),
			sx = Math.sin(x / 2),
			cy = Math.cos(y / 2),
			sy = Math.sin(y / 2),
			cz = Math.cos(z / 2),
			sz = Math.sin(z / 2);
		qx = sx * cy * cz - cx * sy * sz;
		qy = cx * sy * cz + sx * cy * sz;
		qz = cx * cy * sz - sx * sy * cz;
		qw = cx * cy * cz + sx * sy * sz;
		localDirty = true;
	}

	/** Turns it by the unit quaternion x, y, z, w, relative to its parent (normalized here; the identity for a zero one). */
	public function setQuaternion(x:Float, y:Float, z:Float, w:Float):Void {
		var length = Math.sqrt(x * x + y * y + z * z + w * w);
		if (length == 0) {
			qx = qy = qz = 0;
			qw = 1;
		} else {
			qx = x / length;
			qy = y / length;
			qz = z / length;
			qw = w / length;
		}
		localDirty = true;
	}

	/** Turns it by angle (radians) about the axis x, y, z, on top of the turn it has, the axis in the world's units when relativeTo is null
		(a ball rolling along the ground: the axis across its way), or in relativeTo's own units when given: `wheel.rotateOnAxis(1, 0, 0, a,
		wheel)` spins it about its own x, `rotateOnAxis(0, 1, 0, a, parent)` about its parent's up. The axis needn't be of length 1. False,
		changing nothing, for an axis of length 0. */
	public function rotateOnAxis(x:Float, y:Float, z:Float, angle:Float, ?relativeTo:Node3D):Bool {
		var length = Math.sqrt(x * x + y * y + z * z);
		if (!(length > 0))
			return false;
		// The axis into the parent's units: turned by relativeTo's turn in the world, then back by the parent's.
		turnBy(relativeTo, x / length, y / length, z / length, false);
		turnBy(parent, turnedX, turnedY, turnedZ, true);
		var half = angle / 2, sine = Math.sin(half);
		var rx = turnedX * sine,
			ry = turnedY * sine,
			rz = turnedZ * sine,
			rw = Math.cos(half);
		// The turn about it, then the one it had: r * q.
		var nx = rw * qx + rx * qw + ry * qz - rz * qy,
			ny = rw * qy - rx * qz + ry * qw + rz * qx,
			nz = rw * qz + rx * qy - ry * qx + rz * qw,
			nw = rw * qw - rx * qx - ry * qy - rz * qz;
		setQuaternion(nx, ny, nz, nw);
		return true;
	}

	// The direction x, y, z turned by node's turn in the world (each turn from the top down to it; none for null), or back by it when back,
	// into turnedX, turnedY, turnedZ.
	static var turnedX = 0.;
	static var turnedY = 0.;
	static var turnedZ = 0.;

	static function turnBy(node:Null<Node3D>, x:Float, y:Float, z:Float, back:Bool):Void {
		var wx = 0., wy = 0., wz = 0., ww = 1.;
		var at = node;
		while (at != null) {
			// The node's turn, then the world one so far above it, worked from the bottom up: q_at * w.
			var nx = at.qw * wx + at.qx * ww + at.qy * wz - at.qz * wy,
				ny = at.qw * wy - at.qx * wz + at.qy * ww + at.qz * wx,
				nz = at.qw * wz + at.qx * wy - at.qy * wx + at.qz * ww,
				nw = at.qw * ww - at.qx * wx - at.qy * wy - at.qz * wz;
			wx = nx;
			wy = ny;
			wz = nz;
			ww = nw;
			at = at.parent;
		}
		if (back) {
			wx = -wx;
			wy = -wy;
			wz = -wz;
		}
		// v' = v + 2w(u x v) + 2u x (u x v), u the quaternion's vector part.
		var cx = wy * z - wz * y, cy = wz * x - wx * z, cz = wx * y - wy * x;
		turnedX = x + 2 * (ww * cx + wy * cz - wz * cy);
		turnedY = y + 2 * (ww * cy + wz * cx - wx * cz);
		turnedZ = z + 2 * (ww * cz + wx * cy - wy * cx);
	}

	/** Its matrix relative to its parent (16 floats, column-major): its place, turn and scale put together. */
	public var matrix(get, never):Array<Float>;

	function get_matrix():Array<Float> {
		var m = new Mat4();
		m.makeTransform(px, py, pz, qx, qy, qz, qw, sx, sy, sz);
		return [for (i in 0...16) m.get(i)];
	}

	/** Places, turns and scales it by a matrix (16 floats, column-major) relative to its parent, taken apart into translation, rotation and
		scale; a shear is lost. False, changing nothing, for one of the wrong length or with a zero scale. */
	public function setMatrix(m:Array<Float>):Bool {
		if (m.length != 16)
			return false;
		var ax = Math.sqrt(m[0] * m[0] + m[1] * m[1] + m[2] * m[2]),
			ay = Math.sqrt(m[4] * m[4] + m[5] * m[5] + m[6] * m[6]),
			az = Math.sqrt(m[8] * m[8] + m[9] * m[9] + m[10] * m[10]);
		if (ax == 0 || ay == 0 || az == 0)
			return false;
		// A mirroring matrix: one axis negated.
		var det = m[0] * (m[5] * m[10] - m[9] * m[6]) - m[4] * (m[1] * m[10] - m[9] * m[2]) + m[8] * (m[1] * m[6] - m[5] * m[2]);
		if (det < 0)
			ax = -ax;
		px = m[12];
		py = m[13];
		pz = m[14];
		sx = ax;
		sy = ay;
		sz = az;
		// The rotation's columns are the axes over their scales: its quaternion (Shepperd's method).
		var xx = m[0] / ax,
			xy = m[1] / ax,
			xz = m[2] / ax,
			yx = m[4] / ay,
			yy = m[5] / ay,
			yz = m[6] / ay,
			zx = m[8] / az,
			zy = m[9] / az,
			zz = m[10] / az;
		var trace = xx + yy + zz;
		if (trace > 0) {
			var s = Math.sqrt(trace + 1) * 2;
			setQuaternion((yz - zy) / s, (zx - xz) / s, (xy - yx) / s, s / 4);
		} else if (xx > yy && xx > zz) {
			var s = Math.sqrt(1 + xx - yy - zz) * 2;
			setQuaternion(s / 4, (yx + xy) / s, (zx + xz) / s, (yz - zy) / s);
		} else if (yy > zz) {
			var s = Math.sqrt(1 + yy - xx - zz) * 2;
			setQuaternion((yx + xy) / s, s / 4, (zy + yz) / s, (zx - xz) / s);
		} else {
			var s = Math.sqrt(1 + zz - xx - yy) * 2;
			setQuaternion((zx + xz) / s, (zy + yz) / s, s / 4, (xy - yx) / s);
		}
		return true;
	}

	/** Scales it along its own x, y and z. */
	public function setScale(x:Float, y:Float, z:Float):Void {
		sx = x;
		sy = y;
		sz = z;
		localDirty = true;
	}

	/** Turns it so its -z looks from its position at x, y, z, up (0, 1, 0 by default) giving the roll; positions relative to its parent. False,
		changing nothing, when the point is its position or up is along the view. */
	public function lookAt(x:Float, y:Float, z:Float, upX = 0., upY = 1., upZ = 0.):Bool {
		// Its z axis points away from the target; x is up across z; y is z across x.
		var zx = px - x, zy = py - y, zz = pz - z, zl = Math.sqrt(zx * zx + zy * zy + zz * zz);
		if (zl == 0)
			return false;
		zx /= zl;
		zy /= zl;
		zz /= zl;
		var xx = upY * zz - upZ * zy,
			xy = upZ * zx - upX * zz,
			xz = upX * zy - upY * zx,
			xl = Math.sqrt(xx * xx + xy * xy + xz * xz);
		if (xl < 1e-12)
			return false;
		xx /= xl;
		xy /= xl;
		xz /= xl;
		var yx = zy * xz - zz * xy,
			yy = zz * xx - zx * xz,
			yz = zx * xy - zy * xx;
		// The rotation matrix's columns are x, y and z: its quaternion (Shepperd's method).
		var trace = xx + yy + zz;
		if (trace > 0) {
			var s = Math.sqrt(trace + 1) * 2;
			qw = s / 4;
			qx = (yz - zy) / s;
			qy = (zx - xz) / s;
			qz = (xy - yx) / s;
		} else if (xx > yy && xx > zz) {
			var s = Math.sqrt(1 + xx - yy - zz) * 2;
			qw = (yz - zy) / s;
			qx = s / 4;
			qy = (yx + xy) / s;
			qz = (zx + xz) / s;
		} else if (yy > zz) {
			var s = Math.sqrt(1 + yy - xx - zz) * 2;
			qw = (zx - xz) / s;
			qx = (yx + xy) / s;
			qy = s / 4;
			qz = (zy + yz) / s;
		} else {
			var s = Math.sqrt(1 + zz - xx - yy) * 2;
			qw = (xy - yx) / s;
			qx = (zx + xz) / s;
			qy = (zy + yz) / s;
			qz = s / 4;
		}
		localDirty = true;
		return true;
	}

	/** Its world matrix as the last update left it (Renderer3D.draw updates it). */
	public var worldMatrix(get, never):Mat4;

	function get_worldMatrix():Mat4
		return world;

	/** Brings its world matrix up to date from parentWorld when it or its parent changed; whether it changed. A stage calls this as it walks. */
	@:allow(helix.render3d.Renderer3D)
	function update(parentWorld:Null<Mat4>, parentChanged:Bool):Bool {
		if (!localDirty && !parentChanged)
			return false;
		if (localDirty) {
			local.makeTransform(px, py, pz, qx, qy, qz, qw, sx, sy, sz);
			localDirty = false;
		}
		if (parentWorld == null)
			world.copyFrom(local);
		else
			world.makeProduct(parentWorld, local);
		return true;
	}
}

/** Which of the kinds drawn through a renderer's sprites a node is (the engine's: Node3D.spriteKind). */
@:noCompletion
@:build(helix.macro.EnumNames.build())
enum abstract SpriteKind3D(Int) {
	/** None of them. */
	var None;

	/** A sprite or a text: a quad, or a quad a glyph. */
	var Flat;

	/** An emitter of particles. */
	var Emitter;
}
