package helix.tiled;

import helix.asset.Assets;
import helix.asset.AssetPath;
import helix.asset.IReloadable;
import helix.asset.IRequest;
import helix.render2d.Node2D;
import helix.texture.Textures;

/** A map made in Tiled (mapeditor.org), as its JSON (Tiled's File > Export As or Save As, .tmj; its tilesets embedded or .tsj files beside
	it): an orthogonal grid of tiles, finite, its layers (tiles, objects, images and groups of them), its tilesets (one image each, their
	tiles' classes, properties, animations and terrain sets) and its custom properties. load reads it with its tilesets and images;
	instantiate puts it under a node (TiledInstance2D), a tile a sprite, in the map's pixels from its top-left, y down. Isometric and
	hexagonal maps, infinite ones, image-collection tilesets and zstd-compressed layers aren't read (each refused, saying so). A map load
	read is read again when its file or a tileset file of its own changes during development (saved in Tiled, the dev loop running): the
	same object takes the new contents once its images are in, and its instances are built again (TiledInstance2D). */
class TiledMap2D implements IReloadable {
	/** The bits of a global id that are the tile's: the rest are its flips (GID_FLIP_X, GID_FLIP_Y, GID_FLIP_DIAGONAL). */
	public static inline var GID_MASK = 0x0fffffff;

	/** A global id's bit for a tile flipped across, left for right. */
	public static inline var GID_FLIP_X = 0x80000000;

	/** A global id's bit for a tile flipped top for bottom. */
	public static inline var GID_FLIP_Y = 0x40000000;

	/** A global id's bit for a tile flipped across its top-left to bottom-right diagonal (with the others, Tiled's turns by 90 degrees). */
	public static inline var GID_FLIP_DIAGONAL = 0x20000000;

	@:allow(helix.tiled)
	function new() {}

	/** Its path among the assets. */
	public var path(default, null):String = "";

	/** Its width in tiles. */
	public var columns(default, null):Int = 0;

	/** Its height in tiles. */
	public var rows(default, null):Int = 0;

	/** A cell's width, pixels. */
	public var tileWidth(default, null):Int = 0;

	/** A cell's height, pixels. */
	public var tileHeight(default, null):Int = 0;

	/** Its background color, 0xAARRGGBB, or null when it has none. */
	public var backgroundColor(default, null):Null<Int>;

	/** Its layers, in drawing order (the first under the rest). */
	public var layers(default, null):Array<TiledLayer2D> = [];

	/** Its tilesets, by first global id. */
	public var tilesets(default, null):Array<TiledTileset2D> = [];

	/** Its custom properties. */
	public var properties(default, null):TiledProperties2D = new TiledProperties2D();

	/** How many times its files have been read again since load (0 until one changes): a game holding its objects or terrain sets looks
		them up again when it rises. */
	public var reloadCount(default, null) = 0;

	// Its instances, built again when it's read again; the map's text and its tilesets' files (by asset path), kept to read it again.
	@:allow(helix.tiled)
	var instances:Array<TiledInstance2D> = [];
	var text = "";
	var files = new Map<String, String>();
	var subscribed:Array<String> = [];

	/** Loads the map at path (.tmj) with its tilesets (.tsj beside it, when not embedded) and their images and any image layers' (nearest
		sampled, for pixel art): loaded once all are in, failed (else the log) saying what couldn't be read. */
	public static function load(path:String, loaded:TiledMap2D->Void, ?failed:String->Void):IRequest {
		var fail = (message:String) -> if (failed != null) failed(message) else trace('Tiled map $path: $message');
		var outer:Null<IRequest> = null, cancelled = false;
		var request = Assets.load(path, bytes -> {
			var text = bytes.toString(), json:Dynamic = null;
			try
				json = haxe.Json.parse(text)
			catch (e:Dynamic) {
				fail('not JSON: $e');
				return;
			}
			// The tilesets in files of their own first, then the map read with them, then its images.
			var files = new Map<String, String>(), sources = externalTilesets(json, path), left = sources.length;
			function read():Void {
				var map:TiledMap2D;
				try
					map = parse(text, path, files)
				catch (e:Dynamic) {
					fail(Std.string(e));
					return;
				}
				loadImages(map, () -> if (!cancelled) {
					// Its files, to read it again when one changes.
					map.text = text;
					map.files = files;
					map.subscribed = [path].concat(sources);
					for (file in map.subscribed)
						Assets.subscribe(file, map);
					loaded(map);
				}, fail);
			}
			if (left == 0)
				read();
			for (source in sources)
				Assets.load(source, tileset -> {
					files.set(source, tileset.toString());
					if (--left == 0 && !cancelled)
						read();
				}, message -> fail('tileset $source: $message'));
		}, message -> fail(message));
		return new helix.asset.Request(() -> {
			cancelled = true;
			request.cancel();
		});
	}

	/** Reads a map's JSON text, the file at path, its tilesets in files of their own given by path among the assets in files (load reads
		them). Its images aren't loaded: its tilesets' textures are null. Throws, saying why, for a map it can't read. */
	public static function parse(text:String, path:String, ?files:Map<String, String>):TiledMap2D {
		var json:Dynamic = haxe.Json.parse(text);
		if (json.orientation != null && json.orientation != "orthogonal")
			throw 'The map $path is ${json.orientation}: only orthogonal maps are read';
		if (json.infinite == true)
			throw 'The map $path is infinite, which isn\'t read: untick Infinite in its properties';
		var map = new TiledMap2D();
		map.path = path;
		map.columns = Std.int(json.width);
		map.rows = Std.int(json.height);
		map.tileWidth = Std.int(json.tilewidth);
		map.tileHeight = Std.int(json.tileheight);
		map.backgroundColor = json.backgroundcolor != null ? parseColor(json.backgroundcolor) : null;
		map.properties = TiledProperties2D.read(json.properties);
		if (json.tilesets != null)
			for (t in (json.tilesets : Array<Dynamic>)) {
				var first = Std.int(t.firstgid);
				if (t.source != null) {
					var source = AssetPath.resolve(path, t.source);
					var found = source != null && files != null ? files.get(source) : null;
					if (found == null)
						throw 'The map $path names a tileset that isn\'t given: ${t.source}${StringTools.endsWith(t.source, ".tsx") ? " (save it as JSON, .tsj)" : ""}';
					map.tilesets.push(TiledTileset2D.read(haxe.Json.parse(found), source, first));
				} else
					map.tilesets.push(TiledTileset2D.read(t, path, first));
			}
		map.tilesets.sort((a, b) -> a.firstGid - b.firstGid);
		if (json.layers != null)
			for (l in (json.layers : Array<Dynamic>))
				map.layers.push(TiledLayer2D.read(l, path));
		return map;
	}

	/** One of its files changed (the map's or a tileset's of its own): the map is read again with it, and once its images are in, takes
		the new contents and its instances are built again. A file that doesn't read leaves it as it was, and throws; an image that doesn't
		load leaves it as it was, said in the log. */
	public function reloaded(path:String, bytes:haxe.io.Bytes):Void {
		var text = path == this.path ? bytes.toString() : this.text,
			files = this.files.copy();
		if (path != this.path)
			files.set(path, bytes.toString());
		var fresh = parse(text, this.path, files);
		loadImages(fresh, () -> {
			this.text = text;
			this.files = files;
			adopt(fresh);
		}, message -> trace('Tiled map ${this.path} not read again: $message'));
	}

	// Takes fresh's contents, the map read again, and builds its instances again.
	function adopt(fresh:TiledMap2D):Void {
		columns = fresh.columns;
		rows = fresh.rows;
		tileWidth = fresh.tileWidth;
		tileHeight = fresh.tileHeight;
		backgroundColor = fresh.backgroundColor;
		layers = fresh.layers;
		tilesets = fresh.tilesets;
		properties = fresh.properties;
		reloadCount++;
		for (instance in instances.copy())
			instance.rebuild();
	}

	/** Stops reading its files again when they change (load's maps do during development); its instances stay as they are. */
	public function destroy():Void {
		for (file in subscribed)
			Assets.unsubscribe(file, this);
		subscribed = [];
	}

	/** The tileset global id gid (its flips ignored) is in, or null for 0 or an id none holds. */
	public function findTileset(gid:Int):Null<TiledTileset2D> {
		var id = gid & GID_MASK, found:Null<TiledTileset2D> = null;
		if (id == 0)
			return null;
		for (tileset in tilesets)
			if (tileset.firstGid <= id)
				found = tileset;
		return found != null && found.holds(id) ? found : null;
	}

	/** The layer named name, looked for through groups too, or null. */
	public function findLayer(name:String):Null<TiledLayer2D> {
		function look(list:Array<TiledLayer2D>):Null<TiledLayer2D> {
			for (layer in list) {
				if (layer.name == name)
					return layer;
				var inside = look(layer.layers);
				if (inside != null)
					return inside;
			}
			return null;
		}
		return look(layers);
	}

	/** The terrain set named name in any of its tilesets, or null. */
	public function findTerrainSet(name:String):Null<TiledTerrainSet2D> {
		for (tileset in tilesets) {
			var found = tileset.findTerrainSet(name);
			if (found != null)
				return found;
		}
		return null;
	}

	/** Puts the map under parent, or on the stage when none is given (a node of its own, named for the file, its layers' under it in their
		order), a tile a sprite: what it
		returns finds its layers and objects, steps its animated tiles on the game's clock and edits its tile layers. Its tilesets' textures
		are drawn as loaded (load); a tile of one not loaded draws nothing. */
	public function instantiate(?parent:Node2D):TiledInstance2D
		return new TiledInstance2D(this, parent);

	/** A color as Tiled writes it, "#AARRGGBB" or "#RRGGBB" (opaque), as 0xAARRGGBB; null for anything else. */
	public static function parseColor(text:String):Null<Int> {
		if (text == null || !StringTools.startsWith(text, "#") || (text.length != 7 && text.length != 9))
			return null;
		var value = Std.parseInt("0x" + text.substr(1));
		if (value == null)
			return null;
		return text.length == 7 ? value | 0xff000000 : value;
	}

	// The tilesets the map's JSON names as files of their own, as asset paths beside it.
	static function externalTilesets(json:Dynamic, path:String):Array<String> {
		var found = [];
		if (json.tilesets != null)
			for (t in (json.tilesets : Array<Dynamic>))
				if (t.source != null) {
					var source = AssetPath.resolve(path, t.source);
					if (source != null && found.indexOf(source) < 0)
						found.push(source);
				}
		return found;
	}

	// Every tileset's image and image layer's, nearest-sampled, then done; failed for the first that doesn't load.
	static function loadImages(map:TiledMap2D, done:Void->Void, failed:String->Void):Void {
		var wanted:Array<{path:String, use:helix.texture.Texture2D->Void}> = [];
		for (tileset in map.tilesets)
			wanted.push({path: tileset.image, use: t -> tileset.setTexture(t)});
		function images(list:Array<TiledLayer2D>):Void
			for (layer in list) {
				if (layer.kind == Image && layer.image != "")
					wanted.push({path: layer.image, use: t -> layer.setTexture(t)});
				images(layer.layers);
			}
		images(map.layers);
		var left = wanted.length, broken = false;
		if (left == 0)
			done();
		for (w in wanted)
			Textures.load(w.path, Nearest, texture -> {
				w.use(texture);
				if (--left == 0 && !broken)
					done();
			}, message -> {
				if (!broken) {
					broken = true;
					failed('image ${w.path}: $message');
				}
			});
	}
}
