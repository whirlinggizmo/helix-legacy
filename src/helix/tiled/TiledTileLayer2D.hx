package helix.tiled;

import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.texture.Sampling;

/** A Tiled map's tile layer on the stage: a sprite a cell, drawn from its tileset (nearest sampled), flipped and turned as the map says,
	in the map's pixels from its top-left. The game reads it (getTile, isFilled, getTileProperties: a wall, water, a ladder), changes it
	(setTile), and paints terrain into it as Tiled's Terrain brush does (setTerrain: dig, build, flood), the neighbors made to fit.
	Animated tiles step on the game's clock (TiledInstance2D). Body2D.step takes isFilled as its solid tiles: (column, row) ->
	walls.isFilled(column, row), the body in the same pixels with a tile size of the map's. */
class TiledTileLayer2D extends Node2D {
	@:allow(helix.tiled)
	function new(map:TiledMap2D, layer:TiledLayer2D) {
		super();
		this.map = map;
		reset(layer);
	}

	/** Shows layer's tiles in place of what it showed: the map's file read again (TiledMap2D's reload), its changes at run time (setTile,
		setTerrain) gone with the rest. */
	@:allow(helix.tiled)
	function reset(layer:TiledLayer2D):Void {
		for (sprite in sprites)
			if (sprite != null)
				removeChild(sprite);
		columns = layer.columns;
		rows = layer.rows;
		tiles = layer.tiles.copy();
		sprites = [for (_ in 0...tiles.length) null];
		animated.clear();
		terrains.clear();
		for (cell in 0...tiles.length)
			show(cell);
	}

	/** The map it's from. */
	public var map(default, null):TiledMap2D;

	/** Its width in tiles. */
	public var columns(default, null):Int;

	/** Its height in tiles. */
	public var rows(default, null):Int;

	var tiles:Array<Int> = [];
	var sprites:Array<Null<Sprite2D>> = [];
	// The cells showing an animated tile, and the animations' clock (TiledInstance2D advances it).
	var animated:Map<Int, Bool> = new Map<Int, Bool>();
	var clock = 0.;
	// Each terrain set's grid of corners or edges, as painted (setTerrain), made from the tiles the first time it's painted; any other change
	// (setTile) throws them away, to be made again.
	var terrains:haxe.ds.ObjectMap<TiledTerrainSet2D, Array<Int>> = new haxe.ds.ObjectMap<TiledTerrainSet2D, Array<Int>>();
	var region = [0., 0, 0, 0];

	/** The global id at column, row, flip bits and all (TiledMap2D.GID_MASK takes them off); 0 for an empty cell or outside the layer. */
	public function getTile(column:Int, row:Int):Int
		return inside(column, row) ? tiles[row * columns + column] : 0;

	/** Whether column, row has a tile (false outside the layer): a collision layer's solid cells. */
	public function isFilled(column:Int, row:Int):Bool
		return getTile(column, row) != 0;

	/** The custom properties of the tile at column, row (none for an empty cell or outside). */
	public function getTileProperties(column:Int, row:Int):TiledProperties2D {
		var gid = getTile(column, row), tileset = map.findTileset(gid);
		return tileset != null ? tileset.getTileProperties((gid & TiledMap2D.GID_MASK) - tileset.firstGid) : new TiledProperties2D();
	}

	/** The class of the tile at column, row, "" for none, an empty cell or outside. */
	public function getTileClass(column:Int, row:Int):String {
		var gid = getTile(column, row), tileset = map.findTileset(gid);
		return tileset != null ? tileset.getClass((gid & TiledMap2D.GID_MASK) - tileset.firstGid) : "";
	}

	/** The column at x, in its own pixels (outside it too: below 0, or columns and past). */
	public function columnAt(x:Float):Int
		return Math.floor(x / map.tileWidth);

	/** The row at y, in its own pixels, down. */
	public function rowAt(y:Float):Int
		return Math.floor(y / map.tileHeight);

	/** Puts global id gid at column, row (flip bits and all; 0 empties it). False, changing nothing, outside the layer or for an id none of
		the map's tilesets holds. */
	public function setTile(column:Int, row:Int, gid:Int):Bool {
		if (!inside(column, row) || (gid & TiledMap2D.GID_MASK != 0 && map.findTileset(gid) == null))
			return false;
		put(row * columns + column, gid);
		terrains.clear();
		return true;
	}

	/** Its cells' global ids, flip bits and all, row by row from the top-left (columns x rows of them; 0 an empty cell): a copy, to save what
		the game changed (Saves, as JSON) and put back with setTiles. */
	public function getTiles():Array<Int>
		return tiles.copy();

	/** Puts tiles, as getTiles gives them, in its cells, all at once. False, changing nothing, for a count other than columns x rows or an
		id none of the map's tilesets holds. */
	public function setTiles(tiles:Array<Int>):Bool {
		if (tiles == null || tiles.length != columns * rows)
			return false;
		for (gid in tiles)
			if (gid & TiledMap2D.GID_MASK != 0 && map.findTileset(gid) == null)
				return false;
		for (cell in 0...tiles.length)
			if (this.tiles[cell] != tiles[cell])
				put(cell, tiles[cell]);
		terrains.clear();
		return true;
	}

	/** Paints terrain (set's, numbered from 1, TiledTerrainSet2D.findTerrain; 0 none) into column, row as Tiled's Terrain brush does: a corner
		set's cell takes it at its four corners, an edge set's at its four edges, and the cell and its neighbors sharing them take the tile of
		the set that fits what's around them. Where none of the set's tiles fits, a cell is left as it was; where nothing of the set is left,
		it's emptied. False, painting nothing, outside the layer, for a terrain the set hasn't, or for a mixed set (not painted at run time);
		true once painted, whether every cell found its tile or not (each fits when the set has a tile for every arrangement). */
	public function setTerrain(column:Int, row:Int, set:TiledTerrainSet2D, terrain:Int):Bool {
		if (!inside(column, row) || terrain < 0 || terrain > set.terrains.length || set.kind == Mixed)
			return false;
		var grid = gridOf(set);
		if (set.kind == Corner) {
			for (dy in 0...2)
				for (dx in 0...2)
					grid[(row + dy) * (columns + 1) + column + dx] = terrain;
			for (r in row - 1...row + 2)
				for (c in column - 1...column + 2)
					fit(c, r, set, grid);
		} else {
			var vertical = (rows + 1) * columns;
			grid[row * columns + column] = terrain;
			grid[(row + 1) * columns + column] = terrain;
			grid[vertical + row * (columns + 1) + column] = terrain;
			grid[vertical + row * (columns + 1) + column + 1] = terrain;
			fit(column, row, set, grid);
			fit(column - 1, row, set, grid);
			fit(column + 1, row, set, grid);
			fit(column, row - 1, set, grid);
			fit(column, row + 1, set, grid);
		}
		return true;
	}

	/** Moves its animated tiles on by seconds: what TiledInstance2D does each frame on the game's clock. */
	@:allow(helix.tiled)
	function advance(seconds:Float):Void {
		clock += seconds;
		for (cell in animated.keys())
			frame(cell);
	}

	inline function inside(column:Int, row:Int):Bool
		return column >= 0 && row >= 0 && column < columns && row < rows;

	// Cell's tile changed to gid, and shown.
	function put(cell:Int, gid:Int):Void {
		tiles[cell] = gid;
		show(cell);
	}

	// Cell drawn as its tile is: a sprite of its tileset's region, placed and turned, or none for an empty cell.
	function show(cell:Int):Void {
		var gid = tiles[cell], tileset = map.findTileset(gid);
		var sprite = sprites[cell];
		animated.remove(cell);
		if (tileset == null) {
			if (sprite != null) {
				removeChild(sprite);
				sprites[cell] = null;
			}
			return;
		}
		if (sprite == null) {
			sprite = new Sprite2D(null);
			sprite.setPivot(.5, .5);
			sprite.sampling = Sampling.NEAREST;
			sprites[cell] = sprite;
			addChild(sprite);
		}
		sprite.texture = tileset.texture;
		var id = (gid & TiledMap2D.GID_MASK) - tileset.firstGid,
			column = cell % columns,
			row = Std.int(cell / columns);
		tileset.getDrawnRegion(id, region);
		sprite.setRegion(region[0], region[1], region[2], region[3]);
		sprite.setSize(tileset.tileWidth, tileset.tileHeight);
		// Its tile bottom-left on the cell's, as Tiled draws a tile taller or wider than the map's cells, from its middle so a flip stays put.
		var left = column * map.tileWidth + tileset.offsetX,
			top = (row + 1) * map.tileHeight - tileset.tileHeight + tileset.offsetY;
		sprite.setPosition(left + tileset.tileWidth / 2, top + tileset.tileHeight / 2);
		orient(sprite, gid);
		if (tileset.getAnimation(id) != null) {
			animated.set(cell, true);
			frame(cell);
		}
	}

	// An animated cell's sprite at the frame its clock is in, all the tile's cells in step.
	function frame(cell:Int):Void {
		var gid = tiles[cell], tileset = map.findTileset(gid);
		if (tileset == null)
			return;
		var frames = tileset.getAnimation((gid & TiledMap2D.GID_MASK) - tileset.firstGid);
		if (frames == null || frames.length == 0)
			return;
		var total = 0.;
		for (f in frames)
			total += f.seconds;
		var at = total > 0 ? clock % total : 0.,
			shown = frames[frames.length - 1];
		for (f in frames) {
			if (at < f.seconds) {
				shown = f;
				break;
			}
			at -= f.seconds;
		}
		tileset.getDrawnRegion(shown.tile, region);
		sprites[cell].setRegion(region[0], region[1], region[2], region[3]);
	}

	/** A sprite turned and flipped as global id gid's bits say, about its middle: Tiled flips across the diagonal first, then left for
		right, then top for bottom; each is a turn by a quarter or a half and, where an odd number of flips are left, a mirror. */
	@:allow(helix.tiled)
	static function orient(sprite:Sprite2D, gid:Int):Void {
		// The flips as a matrix, columns (a, c) and (b, d): where right and down end up.
		var a = 1, b = 0, c = 0, d = 1;
		if (gid & TiledMap2D.GID_FLIP_DIAGONAL != 0) {
			a = 0;
			b = 1;
			c = 1;
			d = 0;
		}
		if (gid & TiledMap2D.GID_FLIP_X != 0) {
			a = -a;
			b = -b;
		}
		if (gid & TiledMap2D.GID_FLIP_Y != 0) {
			c = -c;
			d = -d;
		}
		if (a * d - b * c > 0) {
			sprite.rotation = Math.atan2(c, a);
			sprite.setScale(1, 1);
		} else {
			// A mirror across, then the turn that leaves.
			sprite.rotation = Math.atan2(-c, -a);
			sprite.setScale(-1, 1);
		}
	}

	// Set's grid as painted, made from the tiles when it isn't yet: a corner set's (columns + 1) x (rows + 1) corners; an edge set's
	// horizontal edges ((rows + 1) x columns) then its vertical ones (rows x (columns + 1)).
	function gridOf(set:TiledTerrainSet2D):Array<Int> {
		var grid = terrains.get(set);
		if (grid != null)
			return grid;
		var vertical = (rows + 1) * columns;
		grid = set.kind == Corner ? [for (_ in 0...(columns + 1) * (rows + 1)) 0] : [for (_ in 0...vertical + rows * (columns + 1)) 0];
		for (row in 0...rows)
			for (column in 0...columns) {
				var gid = tiles[row * columns + column];
				if (!set.tileset.holds(gid))
					continue;
				var id = (gid & TiledMap2D.GID_MASK) - set.tileset.firstGid;
				if (!set.holds(id))
					continue;
				if (set.kind == Corner) {
					grid[row * (columns + 1) + column] = set.getTerrainAt(id, 7);
					grid[row * (columns + 1) + column + 1] = set.getTerrainAt(id, 1);
					grid[(row + 1) * (columns + 1) + column + 1] = set.getTerrainAt(id, 3);
					grid[(row + 1) * (columns + 1) + column] = set.getTerrainAt(id, 5);
				} else {
					grid[row * columns + column] = set.getTerrainAt(id, 0);
					grid[(row + 1) * columns + column] = set.getTerrainAt(id, 4);
					grid[vertical + row * (columns + 1) + column] = set.getTerrainAt(id, 6);
					grid[vertical + row * (columns + 1) + column + 1] = set.getTerrainAt(id, 2);
				}
			}
		terrains.set(set, grid);
		return grid;
	}

	// Cell column, row given set's tile that fits its corners or edges in grid: emptied when none has a terrain (and its tile was the set's),
	// left as it was when no tile fits.
	function fit(column:Int, row:Int, set:TiledTerrainSet2D, grid:Array<Int>):Void {
		if (!inside(column, row))
			return;
		var eight = [0, 0, 0, 0, 0, 0, 0, 0];
		if (set.kind == Corner) {
			eight[7] = grid[row * (columns + 1) + column];
			eight[1] = grid[row * (columns + 1) + column + 1];
			eight[3] = grid[(row + 1) * (columns + 1) + column + 1];
			eight[5] = grid[(row + 1) * (columns + 1) + column];
		} else {
			var vertical = (rows + 1) * columns;
			eight[0] = grid[row * columns + column];
			eight[4] = grid[(row + 1) * columns + column];
			eight[6] = grid[vertical + row * (columns + 1) + column];
			eight[2] = grid[vertical + row * (columns + 1) + column + 1];
		}
		var cell = row * columns + column;
		if (eight.join(",") == "0,0,0,0,0,0,0,0") {
			if (set.tileset.holds(tiles[cell]))
				put(cell, 0);
			return;
		}
		var id = set.find(eight);
		if (id >= 0)
			put(cell, set.tileset.firstGid + id);
	}
}
