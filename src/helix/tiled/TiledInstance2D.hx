package helix.tiled;

import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.texture.Sampling;

/** A Tiled map on the stage (TiledMap2D.instantiate): a node named for its file under the parent it was given (on the stage when none), its layers' nodes under it
	in drawing order (a tile layer a TiledTileLayer2D, an object layer a node holding its tile objects' sprites, an image layer a sprite,
	a group a node of its layers), each named, shown, faded and offset as in Tiled, in the map's pixels from its top-left. It finds layers
	and objects by name and class for the game, and steps the tile layers' animated tiles on the game's clock (paused with the game) until
	it's destroyed. When the map's files change during development (TiledMap2D.load's maps reload), it's built again under the same root:
	a tile layer of the same name is the same TiledTileLayer2D, showing the file's tiles (what setTile and setTerrain changed is gone);
	objects, other layers' nodes and terrain sets are new, to be looked up again (TiledMap2D.reloadCount says when). */
class TiledInstance2D {
	@:allow(helix.tiled)
	function new(map:TiledMap2D, ?parent:Node2D) {
		this.map = map;
		root = new Node2D();
		var file = map.path.split("/").pop();
		root.name = file.indexOf(".") > 0 ? file.substr(0, file.lastIndexOf(".")) : file;
		for (layer in map.layers)
			build(layer, root, []);
		map.instances.push(this);
		if (parent != null)
			parent.addChild(root);
		else {
			onStage = true;
			helix.render2d.Stage.addChild(root);
		}
		helix.scene.Flow.run(dt -> {
			if (destroyed)
				return false;
			var clock = helix.time.Time.clock;
			var seconds = clock != null ? clock.delta : dt;
			for (tiles in tileLayers)
				tiles.advance(seconds);
			return true;
		});
	}

	/** The map it's of. */
	public var map(default, null):TiledMap2D;

	/** Its node, under the parent it was given or on the stage: move or scale it to place the map. */
	public var root(default, null):Node2D;

	var layerNodes:Array<{layer:TiledLayer2D, node:Node2D}> = [];
	var tileLayers:Array<TiledTileLayer2D> = [];
	var objectNodes:Map<TiledObject2D, Sprite2D> = new Map<TiledObject2D, Sprite2D>();
	var destroyed = false;
	var onStage = false;

	/** The node of the layer named name (through groups too), or null: a tile layer's is a TiledTileLayer2D (getTileLayer). */
	public function getLayer(name:String):Null<Node2D> {
		for (entry in layerNodes)
			if (entry.layer.name == name)
				return entry.node;
		return null;
	}

	/** The tile layer named name, or null when there's none (or that layer holds something else). */
	public function getTileLayer(name:String):Null<TiledTileLayer2D> {
		for (layer in tileLayers)
			if (layer.name == name)
				return layer;
		return null;
	}

	/** The first object named name in any object layer, in drawing order, or null. */
	public function findObject(name:String):Null<TiledObject2D> {
		for (object in getObjects())
			if (object.name == name)
				return object;
		return null;
	}

	/** Every object of every object layer, in drawing order; only those of class className when it's given (spawns, coins, exits). */
	public function getObjects(?className:String):Array<TiledObject2D> {
		var found = [];
		for (entry in layerNodes)
			if (entry.layer.kind == Objects)
				for (object in entry.layer.objects)
					if (className == null || object.className == className)
						found.push(object);
		return found;
	}

	/** A tile object's sprite (to move it, hide it once collected), or null for an object that isn't a tile. */
	public function getObjectSprite(object:TiledObject2D):Null<Sprite2D>
		return objectNodes.get(object);

	/** Takes the map off its parent and stops its animations. */
	public function destroy():Void {
		destroyed = true;
		map.instances.remove(this);
		if (onStage)
			helix.render2d.Stage.removeChild(root);
		else if (root.parent != null)
			root.parent.removeChild(root);
	}

	/** Built again from its map, which was read again (TiledMap2D's reload): its tile layers kept by name, showing the new tiles; the rest
		made anew. */
	@:allow(helix.tiled)
	function rebuild():Void {
		var kept = tileLayers.copy();
		for (entry in layerNodes)
			if (entry.node.parent != null)
				entry.node.parent.removeChild(entry.node);
		layerNodes = [];
		tileLayers = [];
		objectNodes = new Map<TiledObject2D, Sprite2D>();
		for (layer in map.layers)
			build(layer, root, kept);
	}

	// Layer's node made under parent, its own under it for a group; a tile layer one of kept when one has its name, shown again.
	function build(layer:TiledLayer2D, parent:Node2D, kept:Array<TiledTileLayer2D>):Void {
		var node:Node2D = switch layer.kind {
			case Tiles:
				var tiles:Null<TiledTileLayer2D> = null;
				for (old in kept)
					if (old.name == layer.name) {
						tiles = old;
						break;
					}
				if (tiles != null) {
					kept.remove(tiles);
					tiles.reset(layer);
				} else
					tiles = new TiledTileLayer2D(map, layer);
				tileLayers.push(tiles);
				tiles;
			case Objects:
				var group = new Node2D();
				for (object in layer.objects)
					if (object.shape == Tile)
						group.addChild(tileObject(object));
				group;
			case Image:
				var image = new Sprite2D(layer.texture);
				image.sampling = Sampling.NEAREST;
				image;
			case Group:
				var group = new Node2D();
				for (inner in layer.layers)
					build(inner, group, kept);
				group;
		}
		node.name = layer.name;
		node.visible = layer.visible;
		node.alpha = layer.opacity;
		node.setPosition(layer.offsetX, layer.offsetY);
		layerNodes.push({layer: layer, node: node});
		parent.addChild(node);
	}

	// A tile object's sprite: its tile, sized as the object, turned about its bottom-left corner as Tiled does, flipped in place.
	function tileObject(object:TiledObject2D):Sprite2D {
		var sprite = new Sprite2D(null);
		sprite.setPivot(.5, .5);
		sprite.sampling = Sampling.NEAREST;
		sprite.visible = object.visible;
		var tileset = map.findTileset(object.gid);
		if (tileset != null) {
			var region = tileset.getDrawnRegion((object.gid & TiledMap2D.GID_MASK) - tileset.firstGid, [0., 0, 0, 0]);
			sprite.texture = tileset.texture;
			sprite.setRegion(region[0], region[1], region[2], region[3]);
		}
		sprite.setSize(object.width, object.height);
		// Its middle: half its size up and across from the bottom-left corner, turned with it.
		var cos = Math.cos(object.rotation),
			sin = Math.sin(object.rotation),
			hw = object.width / 2,
			hh = object.height / 2;
		sprite.setPosition(object.x + hw * cos + hh * sin, object.y + hw * sin - hh * cos);
		TiledTileLayer2D.orient(sprite, object.gid & (TiledMap2D.GID_FLIP_X | TiledMap2D.GID_FLIP_Y));
		sprite.rotation += object.rotation;
		objectNodes.set(object, sprite);
		return sprite;
	}
}
