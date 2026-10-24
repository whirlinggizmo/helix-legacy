package helix.render2d;

import helix.scene.Node;
import helix.font.Font;
import helix.math.Bounds2D;

/** What a Renderer2D holds: a transform in a tree, with children of its own kind. A bare one is a group: it draws nothing, only a transform for
	its children (an empty in Blender, a dummy in 3ds Max, a null in Cinema 4D), a handle that moves or hides a set of things together, or a
	pivot to turn them about. The framework's kinds are its classes (Sprite2D, Shape2D, Text2D, Particles2D), each holding only its own data;
	a game never subclasses one, and game state lives elsewhere, the node its view (docs/DECISIONS.md, 61 and 130). Its transform is a
	position, a rotation in radians (clockwise on screen, y growing down) and a scale, relative to its parent; its world transform is worked
	out when a stage draws it, only after it or a node above it changed. Any node can clip its children (setClip). */
@:allow(helix.render2d.Renderer2D)
class Node2D extends Node {
	var px = 0.;
	var py = 0.;
	var angle = 0.;
	var sx = 1.;
	var sy = 1.;
	var localDirty = true;
	// At a tree's top, counted up by every addChild and removeChild below it: a stage keeps its drawing order until its root's count moves.
	var structure = 0;

	// The world transform: a point x, y of its own is at wa * x + wc * y + wx, wb * x + wd * y + wy.
	var wa = 1.;
	var wb = 0.;
	var wc = 0.;
	var wd = 1.;
	var wx = 0.;
	var wy = 0.;

	/** How opaque it and everything under it are drawn, 0 (not seen) to 1, multiplied down the tree: fading a group fades its children, as a
		Flash display object's alpha did. Clamped to 0..1; 1 to start. Particles aren't faded by it. Picking doesn't follow it: a node faded
		to 0 is still picked (pickable = false or visible = false for one that isn't). */
	public var alpha(default, set):Float = 1.;

	function set_alpha(value:Float):Float {
		alpha = value > 0 ? (value < 1 ? value : 1) : 0;
		return alpha;
	}

	/** The shape it's picked by in place of what it draws, in its own units, never drawn; null (the default) for what it draws. A group with
		one is picked by it; its children are picked as ever, over it. */
	public var hitArea:Null<HitArea2D> = null;

	// A kind that draws itself, not the walk (an emitter, a drawing, a view: each linked only into a program that makes one): into batch,
	// through camera, at the walk's time with dt since its last draw, held still when frozen (under a paused node), shown only when shown (an
	// emitter moves on hidden too). Whether it is one; a group isn't.

	@:allow(helix.render2d.Renderer2D)
	function drawOwn(batch:Batch2D, camera:Camera2D, time:Float, dt:Float, frozen:Bool, shown:Bool):Bool
		return false;

	// Whether it picks itself (pickOwn) rather than by the walk's areas for its kind.
	@:allow(helix.render2d.Renderer2D)
	var picksOwn(get, never):Bool;

	function get_picksOwn():Bool
		return false;

	// The box around its own drawing, not its children's, in its own units, into out, and whether it draws anything: a text measured in font
	// when it has none of its own. The 2D renderer's culling and computeBounds both read it, so they never disagree.

	@:allow(helix.render2d)
	function measureOwn(font:Null<Font>, out:Bounds2D):Bool
		return false;

	// A kind that picks itself: what it has under framebuffer pixel x, y (its own point lx, ly; font for text without its own), itself or a
	// node it shows, or null.

	@:allow(helix.render2d.Renderer2D)
	function pickOwn(x:Float, y:Float, lx:Float, ly:Float, font:Null<Font>):Null<Node2D>
		return null;

	/** The effect its own drawing goes through (a sprite shader: helix.shader's SpriteOutline, SpriteFlash, SpriteDissolve, PaletteSwap, or an
		app's SpriteEffect), or null (the default) for the framework's sprite program: a sprite's quad, a shape's, a text's glyphs (their distance
		field as the effect reads it), a drawing's every call. Its own, not its children's; an emitter and a view draw through their own
		programs. An effect is shared: the nodes given one draw with its values, and those drawn one after another with one effect and texture
		are one draw. */
	public var effect:Null<helix.graphics.SpriteEffect>;

	/** A group at the origin, unturned and unscaled, with no children. */
	public function new()
		super();

	/** Its parent, or null at a tree's top. Assigning a node makes this its last child as that node's addChild does, keeping this one's
		local transform (addChildInPlace keeps the world one); assigning null takes it from its parent as the parent's removeChild does. A
		node under itself or one of its own descendants is refused, leaving the tree as it was. */
	public var parent(get, set):Null<Node2D>;

	function get_parent():Null<Node2D>
		return cast parentNode;

	function set_parent(value:Null<Node2D>):Null<Node2D> {
		if (value != null)
			value.addChild(this);
		else if (parentNode != null)
			get_parent().removeChild(this);
		return get_parent();
	}

	/** Its child at index, in drawing order; null past the end. */
	override public function getChild(index:Int):Null<Node2D>
		return cast super.getChild(index);

	/** Makes child its last child (drawn over the others), taking it from any parent it had, keeping child's local transform: it moves
		with this node as it sat under its old parent (a hat onto a head joint). addChildInPlace keeps its world transform instead. False,
		changing nothing, for itself or one of its own ancestors. */
	public function addChild(child:Node2D):Bool
		return addChildAt(child, -1);

	/** Makes child its child at index in drawing order (0 is drawn first, under the others; those from index on move up one), taking it
		from any parent it had and keeping its local transform, as addChild does; an index past the end, or -1, makes it the last. A child
		of this node already moves to index. False, changing nothing, for itself or one of its own ancestors. */
	public function addChildAt(child:Node2D, index:Int):Bool {
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
		transforms make together is lost. False, changing nothing, for itself or one of its own ancestors, or this scaled to nothing. */
	public function addChildInPlace(child:Node2D):Bool {
		if (!canLink(child))
			return false;
		var c = worldOf(child), p = worldOf(this);
		var det = p[0] * p[3] - p[1] * p[2];
		if (det == 0 || !Math.isFinite(det))
			return false;
		// The parent's inverse times the child's world: the child's new local transform.
		var ia = p[3] / det,
			ib = -p[1] / det,
			ic = -p[2] / det,
			id = p[0] / det;
		var ix = -(ia * p[4] + ic * p[5]), iy = -(ib * p[4] + id * p[5]);
		var la = ia * c[0] + ic * c[1], lb = ib * c[0] + id * c[1];
		var lc = ia * c[2] + ic * c[3], ld = ib * c[2] + id * c[3];
		var lx = ia * c[4] + ic * c[5] + ix, ly = ib * c[4] + id * c[5] + iy;
		addChild(child);
		child.px = lx;
		child.py = ly;
		child.angle = Math.atan2(lb, la);
		child.sx = Math.sqrt(la * la + lb * lb);
		var cos = Math.cos(child.angle), sin = Math.sin(child.angle);
		child.sy = cos * ld - sin * lc;
		child.localDirty = true;
		return true;
	}

	/** Takes its child at index (in drawing order) from its children and returns it, or null past the end, changing nothing. */
	public function removeChildAt(index:Int):Null<Node2D> {
		var child = getChild(index);
		return child != null && removeChild(child) ? child : null;
	}

	/** Takes child from its children. False when it isn't one. */
	public function removeChild(child:Node2D):Bool {
		if (!unlink(child))
			return false;
		changed();
		child.localDirty = true;
		return true;
	}

	// Its tree's shape changed: counted at the top.
	function changed():Void {
		var top:Node2D = this;
		while (top.parentNode != null)
			top = cast top.parentNode;
		top.structure++;
	}

	// node's world transform as it is now, a, b, c, d, x, y (as update keeps it), worked out afresh from its own and every one above it.
	static function worldOf(node:Node2D):Array<Float> {
		var w = [1., 0., 0., 1., 0., 0.];
		var at = node;
		while (at != null) {
			var cos = Math.cos(at.angle), sin = Math.sin(at.angle);
			var la = cos * at.sx,
				lb = sin * at.sx,
				lc = -sin * at.sy,
				ld = cos * at.sy;
			w = [
				la * w[0] + lc * w[1],
				lb * w[0] + ld * w[1],
				la * w[2] + lc * w[3],
				lb * w[2] + ld * w[3],
				la * w[4] + lc * w[5] + at.px,
				lb * w[4] + ld * w[5] + at.py
			];
			at = at.parent;
		}
		return w;
	}

	/** The box around it and everything under it as they are now, into out (a new one when not given), or null for nothing drawn: in its
		tree's world (the stage's units on the stage; inside a View2D's content, the world its camera looks at), or in relativeTo's own units
		when given (Flash's getBounds), as relativeTo's children are placed, to fit a panel around a group. Each sprite, shape, text, drawing
		and sized view counts by its own box, placed by the transforms as they are now (a draw needn't have run). A disabled or hidden node and
		what's under it are left out, as an emitter is; a text without a font of its own is measured in the stage's (Stage.font), and left out
		where there's no stage. Null too for a relativeTo scaled to nothing. relativeTo may be anywhere in the same tree, this node included.
		`computeBounds(scratch)` is the world into scratch: Haxe skips relativeTo for a Bounds2D. Given out, it allocates nothing. */
	public function computeBounds(?relativeTo:Node2D, ?out:Bounds2D):Null<Bounds2D> {
		if (relativeTo == null) {
			above(this);
			return gather(this, ta, tb, tc, td, tx, ty, out != null ? out.clear() : new Bounds2D());
		}
		// relativeTo's world transform, then its inverse.
		above(relativeTo);
		var c = Math.cos(relativeTo.angle), s = Math.sin(relativeTo.angle);
		var la = c * relativeTo.sx,
			lb = s * relativeTo.sx,
			lc = -s * relativeTo.sy,
			ld = c * relativeTo.sy;
		var sa = ta * la + tc * lb,
			sb = tb * la + td * lb,
			sc = ta * lc + tc * ld,
			sd = tb * lc + td * ld;
		var sx = ta * relativeTo.px + tc * relativeTo.py + tx,
			sy = tb * relativeTo.px + td * relativeTo.py + ty;
		var det = sa * sd - sb * sc;
		if (det == 0 || !Math.isFinite(det))
			return null;
		var ia = sd / det, ib = -sb / det, ic = -sc / det, id = sa / det;
		var ix = -(ia * sx + ic * sy), iy = -(ib * sx + id * sy);
		// Then the transform above this node, carried into relativeTo's units.
		above(this);
		return gather(this, ia * ta
			+ ic * tb, ib * ta
			+ id * tb, ia * tc
			+ ic * td, ib * tc
			+ id * td, ia * tx
			+ ic * ty
			+ ix, ib * tx
			+ id * ty
			+ iy,
			out != null ? out.clear() : new Bounds2D());
	}

	// The transform above node (its parents', root first), afresh from their own transforms, into ta ... ty.
	static var ta = 1.;
	static var tb = 0.;
	static var tc = 0.;
	static var td = 1.;
	static var tx = 0.;
	static var ty = 0.;

	static function above(node:Node2D):Void {
		ta = 1;
		tb = 0;
		tc = 0;
		td = 1;
		tx = 0;
		ty = 0;
		var at = node.parent;
		while (at != null) {
			var c = Math.cos(at.angle), s = Math.sin(at.angle);
			var la = c * at.sx, lb = s * at.sx, lc = -s * at.sy, ld = c * at.sy;
			var a = la * ta + lc * tb,
				b = lb * ta + ld * tb,
				cc = la * tc + lc * td,
				d = lb * tc + ld * td;
			var x = la * tx + lc * ty + at.px, y = lb * tx + ld * ty + at.py;
			ta = a;
			tb = b;
			tc = cc;
			td = d;
			tx = x;
			ty = y;
			at = at.parent;
		}
	}

	// What gather measures each node into, reused.
	static var measured = new Bounds2D();

	// node's and its subtree's boxes, placed by the transform a ... y above node, into out; null when it stays empty.
	static function gather(node:Node2D, a:Float, b:Float, c:Float, d:Float, x:Float, y:Float, out:Bounds2D):Null<Bounds2D> {
		walk(node, a, b, c, d, x, y, out, Stage.instance != null ? Stage.font : null);
		return out.isEmpty ? null : out;
	}

	static function walk(node:Node2D, a:Float, b:Float, c:Float, d:Float, x:Float, y:Float, out:Bounds2D, font:Null<Font>):Void {
		if (!node.visible)
			return;
		var cos = Math.cos(node.angle), sin = Math.sin(node.angle);
		var la = cos * node.sx,
			lb = sin * node.sx,
			lc = -sin * node.sy,
			ld = cos * node.sy;
		// Its world transform: the one above it, then its own (as updateWorld).
		var wa = a * la + c * lb,
			wb = b * la + d * lb,
			wc = a * lc + c * ld,
			wd = b * lc + d * ld;
		var wx = a * node.px + c * node.py + x,
			wy = b * node.px + d * node.py + y;
		if (node.measureOwn(font, measured)) {
			var m = measured;
			out.expand(wa * m.minX + wc * m.minY + wx, wb * m.minX + wd * m.minY + wy);
			out.expand(wa * m.maxX + wc * m.minY + wx, wb * m.maxX + wd * m.minY + wy);
			out.expand(wa * m.minX + wc * m.maxY + wx, wb * m.minX + wd * m.maxY + wy);
			out.expand(wa * m.maxX + wc * m.maxY + wx, wb * m.maxX + wd * m.maxY + wy);
		}
		for (i in 0...node.childCount)
			walk(node.getChild(i), wa, wb, wc, wd, wx, wy, out, font);
	}

	/** Whether its children are clipped (setClip). */
	public var clipping(get, never):Bool;

	function get_clipping():Bool
		return clipWidth >= 0;

	/** The clip's width in its own units, or -1 without one. */
	public var clipWidth(default, null):Float = -1.;

	/** The clip's height in its own units, or -1 without one. */
	public var clipHeight(default, null):Float = -1.;

	/** Clips its children (drawn and picked) to the rectangle width x height from its own origin, in its own units: a scrolling list's window. A
		turned node clips to the turned rectangle's bounds. Its own output isn't clipped. False, changing nothing, for a size below 0. */
	public function setClip(width:Float, height:Float):Bool {
		if (!(width >= 0 && height >= 0))
			return false;
		clipWidth = width;
		clipHeight = height;
		return true;
	}

	/** Stops clipping its children. */
	public function clearClip():Void
		clipWidth = clipHeight = -1;

	/** Its position's x, relative to its parent. */
	public var x(get, set):Float;

	function get_x():Float
		return px;

	function set_x(value:Float):Float {
		px = value;
		localDirty = true;
		return value;
	}

	/** Its position's y, relative to its parent (down the screen). */
	public var y(get, set):Float;

	function get_y():Float
		return py;

	function set_y(value:Float):Float {
		py = value;
		localDirty = true;
		return value;
	}

	/** Places it at x, y, relative to its parent. */
	public function setPosition(x:Float, y:Float):Void {
		px = x;
		py = y;
		localDirty = true;
	}

	/** Its rotation in radians, clockwise on screen, relative to its parent. */
	public var rotation(get, set):Float;

	function get_rotation():Float
		return angle;

	function set_rotation(radians:Float):Float {
		angle = radians;
		localDirty = true;
		return radians;
	}

	/** Its scale along its own x; a negative scale mirrors it. */
	public var scaleX(get, set):Float;

	function get_scaleX():Float
		return sx;

	function set_scaleX(value:Float):Float {
		sx = value;
		localDirty = true;
		return value;
	}

	/** Its scale along its own y; a negative scale mirrors it. */
	public var scaleY(get, set):Float;

	function get_scaleY():Float
		return sy;

	function set_scaleY(value:Float):Float {
		sy = value;
		localDirty = true;
		return value;
	}

	/** Scales it along its own x and y; a negative scale mirrors it. */
	public function setScale(x:Float, y:Float):Void {
		sx = x;
		sy = y;
		localDirty = true;
	}

	/** The world x of its own point x, y, as the last draw placed it. */
	public function toWorldX(x:Float, y:Float):Float
		return wa * x + wc * y + wx;

	/** The world y of its own point x, y, as the last draw placed it. */
	public function toWorldY(x:Float, y:Float):Float
		return wb * x + wd * y + wy;

	/** The x in its own units of world point x, y, as the last draw placed it; NaN when it is scaled to nothing. */
	public function toLocalX(x:Float, y:Float):Float {
		var det = wa * wd - wb * wc;
		return (wd * (x - wx) - wc * (y - wy)) / det;
	}

	/** The y in its own units of world point x, y, as the last draw placed it; NaN when it is scaled to nothing. */
	public function toLocalY(x:Float, y:Float):Float {
		var det = wa * wd - wb * wc;
		return (wa * (y - wy) - wb * (x - wx)) / det;
	}

	/** Brings its world transform up to date from its parent's when it or its parent changed; whether it changed. A stage calls this as it walks. */
	function updateWorld(parentChanged:Bool):Bool {
		if (!localDirty && !parentChanged)
			return false;
		localDirty = false;
		var c = Math.cos(angle), s = Math.sin(angle);
		// Scale, then turn, then place: its own transform.
		var la = c * sx, lb = s * sx, lc = -s * sy, ld = c * sy;
		var p:Null<Node2D> = cast parentNode;
		if (p == null) {
			wa = la;
			wb = lb;
			wc = lc;
			wd = ld;
			wx = px;
			wy = py;
		} else {
			wa = p.wa * la + p.wc * lb;
			wb = p.wb * la + p.wd * lb;
			wc = p.wa * lc + p.wc * ld;
			wd = p.wb * lc + p.wd * ld;
			wx = p.wa * px + p.wc * py + p.wx;
			wy = p.wb * px + p.wd * py + p.wy;
		}
		return true;
	}
}
