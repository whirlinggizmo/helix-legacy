import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.tiled.TiledMap2D;

/** Tiled maps (helix.tiled): a map read from its JSON (tilesets embedded and in files of their own, layers as arrays and base64, plain,
	zlib and gzip, objects of every shape, properties of every type), what's refused, and a map put on a node (tiles flipped and turned,
	animated tiles stepping, collision, terrain painted as Tiled's brush does). */
@:access(helix)
class TiledTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float):Bool
		return Math.abs(a - b) < 1e-9;

	static function throws(f:Void->Void, part:String):Bool {
		try
			f()
		catch (e:Dynamic)
			return Std.string(e).indexOf(part) >= 0;
		return false;
	}

	// A tileset of 16 tiles on a 4-column sheet, each a corner set's arrangement of grass (1) and water (2): tile id = TL*8 + TR*4 + BR*2 + BL,
	// a 1 there water; plus an edge set (roads: 3) on tiles 0 to 3.
	static function terrainTileset():String {
		var tiles = [];
		for (id in 0...16) {
			var tl = (id >> 3 & 1) + 1,
				tr = (id >> 2 & 1) + 1,
				br = (id >> 1 & 1) + 1,
				bl = (id & 1) + 1;
			tiles.push('{"tileid":$id,"wangid":[0,$tr,0,$br,0,$bl,0,$tl]}');
		}
		return '{"name":"ground","image":"terrain.png","tilewidth":16,"tileheight":16,"tilecount":16,"columns":4,'
			+ '"wangsets":[{"name":"land","type":"corner","colors":[{"name":"grass"},{"name":"water"}],"wangtiles":[${tiles.join(",")}]},'
			+ '{"name":"roads","type":"edge","colors":[{"name":"road"}],"wangtiles":['
			+ '{"tileid":0,"wangid":[1,0,0,0,1,0,0,0]},{"tileid":1,"wangid":[0,0,1,0,0,0,1,0]},{"tileid":2,"wangid":[1,0,1,0,1,0,1,0]},'
			+ '{"tileid":3,"wangid":[1,0,0,0,0,0,0,0]},{"tileid":4,"wangid":[0,0,0,0,1,0,0,0]},{"tileid":5,"wangid":[0,0,1,0,0,0,0,0]},'
			+ '{"tileid":6,"wangid":[0,0,0,0,0,0,1,0]}]}]}';
	}

	static function main():Void {
		var cells = [1, 2, 0, 0, 0, 1, 1, 0, 3, 0, 0, 1];
		var text = '{"type":"map","orientation":"orthogonal","width":4,"height":3,"tilewidth":16,"tileheight":16,"backgroundcolor":"#203040",'
			+ '"properties":[{"name":"title","type":"string","value":"Level 1"},{"name":"gravity","type":"float","value":9.5},'
			+ '{"name":"lives","type":"int","value":3},{"name":"dark","type":"bool","value":true},{"name":"fog","type":"color","value":"#80ff0000"}],'
			+ '"tilesets":[{"firstgid":1,"name":"tiles","image":"../textures/tiles.png","tilewidth":16,"tileheight":16,"tilecount":8,"columns":4,'
			+ '"margin":2,"spacing":4,"tiles":[{"id":0,"type":"Wall","properties":[{"name":"solid","type":"bool","value":true}]},'
			+ '{"id":1,"animation":[{"tileid":1,"duration":100},{"tileid":2,"duration":200}]}]},'
			+ '{"firstgid":9,"source":"ground.tsj"}],'
			+ '"layers":[{"type":"tilelayer","name":"floor","width":4,"height":3,"data":[1,2,0,0,0,1,1,0,3,0,0,1]},'
			+
			'{"type":"tilelayer","name":"plain","width":4,"height":3,"encoding":"base64","data":"AQAAAAIAAAAAAAAAAAAAAAAAAAABAAAAAQAAAAAAAAADAAAAAAAAAAAAAAABAAAA"},'
			+ '{"type":"tilelayer","name":"zlib","width":4,"height":3,"encoding":"base64","compression":"zlib","data":"eJxjZGBgYGJABYxQDALMaOIAASAACg=="},'
			+
			'{"type":"tilelayer","name":"gzip","width":4,"height":3,"encoding":"base64","compression":"gzip","data":"H4sIAAAAAAACA2NkYGBgYkAFjFAMAsxo4gAgZI2KMAAAAA=="},'
			+ '{"type":"tilelayer","name":"turned","width":4,"height":1,"opacity":0.5,"offsetx":4,"offsety":-2,'
			+ '"data":[2147483649,1073741825,2684354561,1]},'
			+ '{"type":"objectgroup","name":"things","objects":['
			+ '{"id":1,"name":"start","point":true,"x":24,"y":40},'
			+
			'{"id":2,"name":"door","class":"Exit","x":48,"y":0,"width":16,"height":32,"rotation":90,"properties":[{"name":"to","type":"string","value":"level2"}]},'
			+ '{"id":3,"name":"path","x":0,"y":0,"polyline":[{"x":0,"y":0},{"x":10,"y":5}]},'
			+ '{"id":4,"name":"coin","type":"Coin","gid":2147483650,"x":32,"y":48,"width":16,"height":16},'
			+ '{"id":5,"name":"pond","ellipse":true,"x":0,"y":0,"width":8,"height":4}]},'
			+ '{"type":"group","name":"sky","layers":[{"type":"imagelayer","name":"clouds","image":"clouds.png","visible":false}]}]}';
		var files = ["maps/ground.tsj" => terrainTileset()];
		var map = TiledMap2D.parse(text, "maps/level1.tmj", files);
		check(map.columns == 4 && map.rows == 3 && map.tileWidth == 16 && map.tileHeight == 16 && map.backgroundColor == 0xff203040,
			"The map's size, cells and background");
		check(map.properties.getString("title") == "Level 1"
			&& near(map.properties.getFloat("gravity"), 9.5)
			&& map.properties.getInt("lives") == 3
			&& map.properties.getBool("dark")
			&& map.properties.getColor("fog") == 0x80ff0000,
			"Its properties, typed");
		check(map.properties.getInt("missing", 7) == 7 && map.properties.getType("gravity") == "float" && !map.properties.has("missing"),
			"A property missing is what's given; its type as Tiled's");
		var tiles = map.tilesets[0], ground = map.tilesets[1];
		check(tiles.image == "textures/tiles.png" && ground.image == "maps/terrain.png" && ground.firstGid == 9,
			"Tilesets' images beside their files, embedded and in a file of its own");
		var region = tiles.getRegion(5, [0., 0, 0, 0]);
		check(region[0] == 2 + 1 * 20 && region[1] == 2 + 1 * 20 && region[2] == 16, "A tile's region past the margin and spacing");
		check(tiles.getClass(0) == "Wall"
			&& tiles.getTileProperties(0).getBool("solid")
			&& tiles.getAnimation(1).length == 2
			&& near(tiles.getAnimation(1)[1].seconds, .2),
			"A tile's class, properties and animation");
		check(map.findTileset(1 | TiledMap2D.GID_FLIP_X) == tiles
			&& map.findTileset(10) == ground
			&& map.findTileset(0) == null
			&& map.findTileset(99) == null,
			"A global id's tileset, its flips ignored");
		var floor = map.findLayer("floor");
		check(floor.tiles.join(",") == cells.join(",")
			&& map.findLayer("plain").tiles.join(",") == cells.join(",")
			&& map.findLayer("zlib").tiles.join(",") == cells.join(",")
			&& map.findLayer("gzip").tiles.join(",") == cells.join(","),
			"Tile layers as an array, base64, zlib and gzip, alike");
		check(map.findLayer("turned").tiles[0] == (1 | TiledMap2D.GID_FLIP_X), "A flipped id's high bit kept");
		var things = map.findLayer("things").objects;
		check(things[0].shape == Point
			&& things[1].className == "Exit"
			&& near(things[1].rotation, Math.PI / 2)
			&& things[1].properties.getString("to") == "level2"
			&& things[2].shape == Polyline
			&& things[2].points.join(",") == "0,0,10,5"
			&& things[3].shape == Tile
			&& things[3].className == "Coin"
			&& things[4].shape == Ellipse,
			"Objects of every shape, classes, turns");
		var rounded = (points:Array<Float>) -> points.map(v -> Math.round(v)).join(",");
		var scratch = [];
		check(rounded(things[1].computePoints()) == "48,0,48,16,16,16,16,0"
			&& things[1].closed
			&& rounded(things[2].computePoints()) == "0,0,10,5"
			&& !things[2].closed
			&& rounded(things[3].computePoints()) == "32,32,48,32,48,48,32,48"
			&& rounded(things[0].computePoints()) == "24,40"
			&& things[4].computePoints(scratch) == scratch
			&& scratch.length == 32
			&& rounded(scratch.slice(0, 2)) == "8,2",
			"Objects' outlines in the map's pixels: a rectangle turned about its corner, a polyline open, a tile up from its bottom, a point, an ellipse into an out");
		check(map.findLayer("clouds").image == "maps/clouds.png" && !map.findLayer("clouds").visible && map.findLayer("sky").kind == Group,
			"A group's image layer, found through it");

		// What's refused, saying why.
		check(throws(() -> TiledMap2D.parse('{"orientation":"isometric","width":1,"height":1}', "a.tmj"), "only orthogonal"), "An isometric map");
		check(throws(() -> TiledMap2D.parse('{"orientation":"orthogonal","infinite":true}', "a.tmj"), "infinite"), "An infinite map");
		check(throws(() -> TiledMap2D.parse('{"width":1,"height":1,"tilesets":[{"firstgid":1,"source":"t.tsx"}]}', "a.tmj"), "save it as JSON"),
			"An XML tileset, the way out named");
		check(throws(() -> TiledMap2D.parse('{"width":1,"height":1,"layers":[{"type":"tilelayer","name":"z","width":1,"height":1,'
			+ '"encoding":"base64","compression":"zstd","data":"AA=="}]}',
			"a.tmj"),
			"zstd"),
			"A zstd layer");
		check(throws(() -> TiledMap2D.parse('{"width":1,"height":1,"tilesets":[{"firstgid":1,"name":"c","tiles":[]}]}', "a.tmj"), "image collection"),
			"An image-collection tileset");

		// On a node: the layers in order, their nodes named, faded, offset; a sprite a filled cell.
		var parent = new Node2D(), instance = map.instantiate(parent);
		check(parent.getChild(0) == instance.root && instance.root.name == "level1" && instance.root.childCount == 7, "Its layers under its node");
		var turned = instance.getTileLayer("turned");
		check(turned.childCount == 4 && near(turned.alpha, .5) && near(turned.x, 4) && near(turned.y, -2), "A layer's node as in Tiled");
		var x = cast(turned.getChild(0), Sprite2D),
			y = cast(turned.getChild(1), Sprite2D),
			cw = cast(turned.getChild(2), Sprite2D);
		check(x.scaleX == -1 && near(x.rotation, 0) && x.scaleY == 1, "Flipped across: mirrored");
		check(y.scaleX == -1 && near(Math.abs(y.rotation), Math.PI), "Flipped top for bottom: mirrored and turned half round");
		check(cw.scaleX == 1 && near(cw.rotation, Math.PI / 2), "Diagonal and across: Tiled's quarter turn clockwise");
		check(near(x.x, 8) && near(x.y, 8) && near(x.regionWidth, 16 - 2 * helix.tiled.TiledTileset2D.INSET),
			"A tile centered on its cell, its region its tile's, a hair inside");
		var floorNode = instance.getTileLayer("floor");
		check(floorNode.isFilled(0, 0)
			&& !floorNode.isFilled(2, 0)
			&& !floorNode.isFilled(-1, 0)
			&& floorNode.getTileProperties(0, 0).getBool("solid")
			&& floorNode.getTileClass(0, 0) == "Wall"
			&& floorNode.columnAt(17) == 1
			&& floorNode.rowAt(-1) == -1,
			"What a game asks of a cell");
		check(instance.findObject("door").className == "Exit"
			&& instance.getObjects("Coin").length == 1
			&& instance.getObjects().length == 5,
			"Objects by name and class");
		var coin = instance.getObjectSprite(instance.findObject("coin"));
		check(coin != null
			&& coin.scaleX == -1
			&& near(coin.x, 40)
			&& near(coin.y, 40)
			&& instance.getObjectSprite(instance.findObject("door")) == null,
			"A tile object's sprite, its corner at its bottom-left, flipped");

		// An animated tile (tile 1: 0.1 s of itself, 0.2 s of tile 2), in step wherever it is, on the frames' time in a test.
		var animated = cast(floorNode.getChild(1), Sprite2D);
		var before = animated.regionX;
		@:privateAccess helix.scene.Flow.tick(.15);
		check(animated.regionX == tiles.getDrawnRegion(2, [0., 0, 0, 0])[0] && before == tiles.getDrawnRegion(1, [0., 0, 0, 0])[0],
			"Animated: its second frame");
		@:privateAccess helix.scene.Flow.tick(.2);
		check(animated.regionX == before, "And round again");
		check(!floorNode.setTile(9, 9, 1) && !floorNode.setTile(0, 0, 999) && floorNode.setTile(2, 0, 1) && floorNode.isFilled(2, 0)
			&& floorNode.setTile(0, 0, 0) && !floorNode.isFilled(0, 0),
			"Tiles set and emptied; outside or unheld refused");

		// Its tiles out and back, as a game saves what it changed: a copy, put back at once; a wrong count or an unheld id refused.
		var saved = floorNode.getTiles();
		saved[0] = 99;
		check(floorNode.getTile(0, 0) == 0 && floorNode.getTiles().length == 12, "getTiles: a copy, every cell");
		saved = floorNode.getTiles();
		floorNode.setTile(1, 1, 0);
		floorNode.setTile(3, 2, 2);
		check(!floorNode.setTiles([1, 2]) && !floorNode.setTiles([for (_ in 0...12) 999]) && floorNode.getTile(3, 2) == 2,
			"setTiles refuses a wrong count or an unheld id, changing nothing");
		check(floorNode.setTiles(saved)
			&& floorNode.getTile(1, 1) == saved[5]
			&& floorNode.getTile(3, 2) == saved[11]
			&& floorNode.childCount == [for (g in saved) if (g != 0) g].length,
			"setTiles puts them back, a sprite a filled cell");

		// Read again, its file changed in the dev loop (TiledMap2D.reloaded, past loading its images): the same tile layer shows the file's
		// tiles, what setTile changed gone; a layer gone from the file goes; objects are the file's anew.
		var changed = StringTools.replace(text, '"name":"floor","width":4,"height":3,"data":[1,2,0,0', '"name":"floor","width":4,"height":3,"data":[1,2,0,3');
		changed = StringTools.replace(changed, '{"type":"tilelayer","name":"zlib"', '{"type":"tilelayer","name":"zlib2"');
		var oldDoor = instance.findObject("door");
		@:privateAccess map.adopt(TiledMap2D.parse(changed, "maps/level1.tmj", files));
		check(map.reloadCount == 1
			&& instance.getTileLayer("floor") == floorNode
			&& instance.root.childCount == 7
			&& parent.getChild(0) == instance.root,
			"Read again: the same root and tile layer");
		check(floorNode.isFilled(0, 0) && !floorNode.isFilled(2, 0) && floorNode.isFilled(3, 0) && floorNode.childCount == 7,
			"Its tiles the file's, run-time changes gone");
		check(instance.getTileLayer("zlib") == null
			&& instance.getTileLayer("zlib2") != null
			&& instance.findObject("door") != oldDoor
			&& instance.findObject("door").className == "Exit",
			"A renamed layer and the objects anew");
		instance.destroy();
		@:privateAccess map.adopt(TiledMap2D.parse(text, "maps/level1.tmj", files));
		check(map.reloadCount == 2 && instance.getTileLayer("zlib2") != null, "A destroyed instance isn't built again");
		instance = map.instantiate(parent);
		floorNode = instance.getTileLayer("floor");

		// Terrain, painted as Tiled's brush does: a cell of water in grass, its neighbors made to meet it.
		var landText = '{"orientation":"orthogonal","width":3,"height":3,"tilewidth":16,"tileheight":16,"tilesets":[{"firstgid":1,"source":"ground.tsj"}],'
			+ '"layers":[{"type":"tilelayer","name":"land","width":3,"height":3,"data":[1,1,1,1,1,1,1,1,1]}]}';
		var land = TiledMap2D.parse(landText, "maps/island.tmj", files),
			set = land.findTerrainSet("land");
		var painted = land.instantiate(new Node2D()).getTileLayer("land");
		check(set.findTerrain("water") == 2 && set.kind == Corner, "A corner set's terrains, by name");
		check(painted.setTerrain(1, 1, set, 2), "Painted");
		// Grass is 0 in the tile ids below, water 1: id = TL*8 + TR*4 + BR*2 + BL; a global id is its id + 1.
		check(painted.getTile(1, 1) == 16 && painted.getTile(0, 0) == 3 && painted.getTile(1, 0) == 4 && painted.getTile(2, 0) == 2
			&& painted.getTile(0, 1) == 7 && painted.getTile(2, 2) == 9,
			"Water in the middle, its eight neighbors meeting it");
		painted.setTerrain(1, 1, set, 1);
		check([for (r in 0...3) for (c in 0...3) painted.getTile(c, r)].join(",") == "1,1,1,1,1,1,1,1,1", "Grass painted back: all grass again");
		check(!painted.setTerrain(5, 5, set, 1) && !painted.setTerrain(0, 0, set, 9), "Outside, or a terrain it hasn't: refused");
		// An edge set: a road painted into an empty cell takes the tile with roads on all four edges, its neighbors their edge's.
		var roadsText = '{"orientation":"orthogonal","width":3,"height":3,"tilewidth":16,"tileheight":16,"tilesets":[{"firstgid":1,"source":"ground.tsj"}],'
			+ '"layers":[{"type":"tilelayer","name":"roads","width":3,"height":3,"data":[0,0,0,0,0,0,0,0,0]}]}';
		var roadMap = TiledMap2D.parse(roadsText, "maps/roads.tmj", files),
			roads = roadMap.findTerrainSet("roads");
		var road = roadMap.instantiate(new Node2D()).getTileLayer("roads");
		check(roads.kind == Edge && road.setTerrain(1, 1, roads, 1) && road.getTile(1, 1) == 3, "A crossing where it's painted");
		check(road.getTile(1, 0) == 5 && road.getTile(1, 2) == 4 && road.getTile(0, 1) == 6 && road.getTile(2, 1) == 7 && road.getTile(0, 0) == 0,
			"Its neighbors the road's ends (above it, a road at its bottom edge), corners left empty");
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}
}
