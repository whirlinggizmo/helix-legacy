package helix.render2d;

import helix.decal.DecalPool;
import helix.texture.Texture2D;

/** Marks left on the ground of a game seen from above: skid marks, footsteps, scorch marks, a target ring. A fixed pool of a texture's
	sprites, drawn together (alike sprites beside each other in the draw order are one draw): each place puts one down, and once the pool is
	full the oldest is taken up and put down again, so a trail never grows past its capacity. Given a life (lifeSeconds), each mark fades out
	over fadeSeconds once it has lived it, on the game's clock (a paused game's marks stay as they are), and is taken up; without one it
	stays until the pool comes round to it. Either way the ones next to be taken up for reuse (fadeCount) fade by how soon, so a full pool's
	trail thins out where it ends instead of losing a mark at a time. In its own space: add it under what walks over the marks (before them,
	as a child drawn first). Decals are never picked: a click passes to what's under them. */
class Decals2D extends Node2D {
	/** A pool of capacity (at least 1) decals of texture. */
	public function new(texture:Texture2D, capacity = 64) {
		super();
		this.texture = texture;
		pool = new DecalPool<Sprite2D>(capacity, (mark, tint) -> mark.tint = tint, mark -> removeChild(mark));
	}

	var pool:DecalPool<Sprite2D>;

	/** Their texture. */
	public var texture(default, null):Texture2D;

	/** How many it holds before the oldest is put down again. */
	public var capacity(get, never):Int;

	function get_capacity():Int
		return pool.capacity;

	/** How many are down now: up to capacity. */
	public var count(get, never):Int;

	function get_count():Int
		return pool.marks.length;

	/** Each decal's size, its own units, square (place may give its own): 0 to start, for its texture's size (or its region's). */
	public var size:Float = 0;

	/** Their tint, 0xAARRGGBB: white (the texture as it is) to start. place may give its own. */
	public var tint:Int = 0xffffffff;

	/** How many of the decals next to be taken up for reuse fade, by how soon: the next at 1 in fadeCount + 1 of its alpha (none fade while
		the pool has that many places free). A quarter of the capacity to start; 0 for none. Clamped to 0..capacity. Takes effect at the next
		place. */
	public var fadeCount(get, set):Int;

	function get_fadeCount():Int
		return pool.fadeCount;

	function set_fadeCount(value:Int):Int
		return pool.fadeCount = value;

	/** Seconds on the game's clock each decal stays as placed before it fades out (over fadeSeconds) and is taken up: 0 (the default, and for
		less) for as long as the pool lets it. Applies to every decal down, as old as each is. */
	public var lifeSeconds(get, set):Float;

	function get_lifeSeconds():Float
		return pool.lifeSeconds;

	function set_lifeSeconds(value:Float):Float
		return pool.lifeSeconds = value;

	/** Seconds a decal takes to fade out once it has lived its life (lifeSeconds): .5 to start; 0 (and for less) to vanish at once. */
	public var fadeSeconds(get, set):Float;

	function get_fadeSeconds():Float
		return pool.fadeSeconds;

	function set_fadeSeconds(value:Float):Float
		return pool.fadeSeconds = value;

	/** Puts a decal down at x, y (its own space), turned angle radians (clockwise, as the stage's y is down), size across (0, the default,
		for the pool's size), tinted (0xAARRGGBB; null for the pool's tint), over the others. Returns its sprite, to set its region (a variant
		from an atlas) or effect now: it's the pool's, put down again once taken up, its region and effect cleared then. */
	public function place(x:Float, y:Float, angle = 0., size = 0., ?tint:Int):Sprite2D {
		var mark = pool.next();
		if (mark == null) {
			mark = new Sprite2D(texture);
			mark.setPivot(.5, .5);
			mark.pickable = false;
		} else {
			mark.setRegion(0, 0, 0, 0);
			mark.effect = null;
		}
		// Last in the draw order: over the rest.
		addChild(mark);
		var across = size > 0 ? size : this.size;
		mark.setSize(across, across);
		mark.setPosition(x, y);
		mark.rotation = angle;
		pool.add(mark, tint != null ? tint : this.tint);
		return mark;
	}

	/** Takes every decal up. */
	public function clear():Void
		pool.clear();
}
