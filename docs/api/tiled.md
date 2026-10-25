# helix.tiled

[Back to the index](README.md)

## TiledFrame2D

*class* in [`src/helix/tiled/TiledFrame2D.hx`](../../src/helix/tiled/TiledFrame2D.hx), `import helix.tiled.TiledFrame2D;`

A frame of an animated tile: which tile of its tileset shows, for how long.

```haxe
var tile(default, null):Int
var seconds(default, null):Float
```

- `tile`: The tile shown, its id in the tileset.
- `seconds`: How long it shows, seconds.

## TiledInstance2D

*class* in [`src/helix/tiled/TiledInstance2D.hx`](../../src/helix/tiled/TiledInstance2D.hx), `import helix.tiled.TiledInstance2D;`

A Tiled map on the stage (TiledMap2D.instantiate): a node named for its file under the parent it was given (on the stage when none), its layers' nodes under it in drawing order (a tile layer a TiledTileLayer2D, an object layer a node holding its tile objects' sprites, an image layer a sprite, a group a node of its layers), each named, shown, faded and offset as in Tiled, in the map's pixels from its top-left. It finds layers and objects by name and class for the game, and steps the tile layers' animated tiles on the game's clock (paused with the game) until it's destroyed. When the map's files change during development (TiledMap2D.load's maps reload), it's built again under the same root: a tile layer of the same name is the same TiledTileLayer2D, showing the file's tiles (what setTile and setTerrain changed is gone); objects, other layers' nodes and terrain sets are new, to be looked up again (TiledMap2D.reloadCount says when).

```haxe
var map(default, null):TiledMap2D
var root(default, null):Node2D
function getLayer(name:String):Null<Node2D>
function getTileLayer(name:String):Null<TiledTileLayer2D>
function findObject(name:String):Null<TiledObject2D>
function getObjects(?className:String):Array<TiledObject2D>
function getObjectSprite(object:TiledObject2D):Null<Sprite2D>
function destroy():Void
```

- `map`: The map it's of.
- `root`: Its node, under the parent it was given or on the stage: move or scale it to place the map.
- `getLayer`: The node of the layer named name (through groups too), or null: a tile layer's is a TiledTileLayer2D (getTileLayer).
- `getTileLayer`: The tile layer named name, or null when there's none (or that layer holds something else).
- `findObject`: The first object named name in any object layer, in drawing order, or null.
- `getObjects`: Every object of every object layer, in drawing order; only those of class className when it's given (spawns, coins, exits).
- `getObjectSprite`: A tile object's sprite (to move it, hide it once collected), or null for an object that isn't a tile.
- `destroy`: Takes the map off its parent and stops its animations.

## TiledLayer2D

*class* in [`src/helix/tiled/TiledLayer2D.hx`](../../src/helix/tiled/TiledLayer2D.hx), `import helix.tiled.TiledLayer2D;`

A layer of a Tiled map as read: its kind and what that holds, its name, whether it's shown, its opacity, its offset and its custom properties. A map's layers are drawn in their order, the first under the rest; a group's are under it, its offset and opacity applying to them (TiledMap2D.instantiate).

```haxe
var kind(default, null):TiledLayerKind2D
var name(default, null):String
var className(default, null):String
var visible(default, null):Bool
var opacity(default, null):Float
var offsetX(default, null):Float
var offsetY(default, null):Float
var columns(default, null):Int
var rows(default, null):Int
var tiles(default, null):Array<Int>
var objects(default, null):Array<TiledObject2D>
var image(default, null):String
var texture(default, null):Null<Texture2D>
var layers(default, null):Array<TiledLayer2D>
var properties(default, null):TiledProperties2D
function getTile(column:Int, row:Int):Int
```

- `kind`: What it holds.
- `name`: Its name in Tiled.
- `className`: Its class in Tiled, "" when it has none.
- `visible`: Whether it's shown.
- `opacity`: Its opacity, 0 to 1.
- `offsetX`: Its offset, pixels: where it's drawn from its parent's place.
- `offsetY`: Its offset's y, pixels, down.
- `columns`: A tile layer's columns.
- `rows`: A tile layer's rows.
- `tiles`: A tile layer's global ids, row by row from the top-left, flip bits and all; 0 for an empty cell.
- `objects`: An object layer's objects, in Tiled's order.
- `image`: An image layer's image path among the assets, "" otherwise.
- `texture`: An image layer's image once the map has loaded, or null.
- `layers`: A group's layers, in their order.
- `properties`: Its custom properties.
- `getTile`: A tile layer's global id at column, row, flip bits and all; 0 outside it or for an empty cell.

## TiledLayerKind2D

*enum* in [`src/helix/tiled/TiledLayerKind2D.hx`](../../src/helix/tiled/TiledLayerKind2D.hx), `import helix.tiled.TiledLayerKind2D;`

What a Tiled layer holds.

- `Tiles`: A grid of tiles (tiles, columns, rows).
- `Objects`: Objects (objects).
- `Image`: One image (image).
- `Group`: Other layers (layers).

## TiledMap2D

*class* in [`src/helix/tiled/TiledMap2D.hx`](../../src/helix/tiled/TiledMap2D.hx), `import helix.tiled.TiledMap2D;`

A map made in Tiled (mapeditor.org), as its JSON (Tiled's File > Export As or Save As, .tmj; its tilesets embedded or .tsj files beside it): an orthogonal grid of tiles, finite, its layers (tiles, objects, images and groups of them), its tilesets (one image each, their tiles' classes, properties, animations and terrain sets) and its custom properties. load reads it with its tilesets and images; instantiate puts it under a node (TiledInstance2D), a tile a sprite, in the map's pixels from its top-left, y down. Isometric and hexagonal maps, infinite ones, image-collection tilesets and zstd-compressed layers aren't read (each refused, saying so). A map load read is read again when its file or a tileset file of its own changes during development (saved in Tiled, the dev loop running): the same object takes the new contents once its images are in, and its instances are built again (TiledInstance2D).

```haxe
static inline var GID_MASK:Int
static inline var GID_FLIP_X:Int
static inline var GID_FLIP_Y:Int
static inline var GID_FLIP_DIAGONAL:Int
static function load(path:String, loaded:TiledMap2D -> Void, ?failed:String -> Void):IRequest
static function parse(text:String, path:String, ?files:Map<String, String>):TiledMap2D
static function parseColor(text:String):Null<Int>
var path(default, null):String
var columns(default, null):Int
var rows(default, null):Int
var tileWidth(default, null):Int
var tileHeight(default, null):Int
var backgroundColor(default, null):Null<Int>
var layers(default, null):Array<TiledLayer2D>
var tilesets(default, null):Array<TiledTileset2D>
var properties(default, null):TiledProperties2D
var reloadCount(default, null):Int
function reloaded(path:String, bytes:haxe.io.Bytes):Void
function destroy():Void
function findTileset(gid:Int):Null<TiledTileset2D>
function findLayer(name:String):Null<TiledLayer2D>
function findTerrainSet(name:String):Null<TiledTerrainSet2D>
function instantiate(?parent:Node2D):TiledInstance2D
```

- `GID_MASK`: The bits of a global id that are the tile's: the rest are its flips (GID_FLIP_X, GID_FLIP_Y, GID_FLIP_DIAGONAL).
- `GID_FLIP_X`: A global id's bit for a tile flipped across, left for right.
- `GID_FLIP_Y`: A global id's bit for a tile flipped top for bottom.
- `GID_FLIP_DIAGONAL`: A global id's bit for a tile flipped across its top-left to bottom-right diagonal (with the others, Tiled's turns by 90 degrees).
- `load`: Loads the map at path (.tmj) with its tilesets (.tsj beside it, when not embedded) and their images and any image layers' (nearest sampled, for pixel art): loaded once all are in, failed (else the log) saying what couldn't be read.
- `parse`: Reads a map's JSON text, the file at path, its tilesets in files of their own given by path among the assets in files (load reads them). Its images aren't loaded: its tilesets' textures are null. Throws, saying why, for a map it can't read.
- `parseColor`: A color as Tiled writes it, "#AARRGGBB" or "#RRGGBB" (opaque), as 0xAARRGGBB; null for anything else.
- `path`: Its path among the assets.
- `columns`: Its width in tiles.
- `rows`: Its height in tiles.
- `tileWidth`: A cell's width, pixels.
- `tileHeight`: A cell's height, pixels.
- `backgroundColor`: Its background color, 0xAARRGGBB, or null when it has none.
- `layers`: Its layers, in drawing order (the first under the rest).
- `tilesets`: Its tilesets, by first global id.
- `properties`: Its custom properties.
- `reloadCount`: How many times its files have been read again since load (0 until one changes): a game holding its objects or terrain sets looks them up again when it rises.
- `reloaded`: One of its files changed (the map's or a tileset's of its own): the map is read again with it, and once its images are in, takes the new contents and its instances are built again. A file that doesn't read leaves it as it was, and throws; an image that doesn't load leaves it as it was, said in the log.
- `destroy`: Stops reading its files again when they change (load's maps do during development); its instances stay as they are.
- `findTileset`: The tileset global id gid (its flips ignored) is in, or null for 0 or an id none holds.
- `findLayer`: The layer named name, looked for through groups too, or null.
- `findTerrainSet`: The terrain set named name in any of its tilesets, or null.
- `instantiate`: Puts the map under parent, or on the stage when none is given (a node of its own, named for the file, its layers' under it in their order), a tile a sprite: what it returns finds its layers and objects, steps its animated tiles on the game's clock and edits its tile layers. Its tilesets' textures are drawn as loaded (load); a tile of one not loaded draws nothing.

## TiledObject2D

*class* in [`src/helix/tiled/TiledObject2D.hx`](../../src/helix/tiled/TiledObject2D.hx), `import helix.tiled.TiledObject2D;`

An object of a Tiled object layer: a spawn point, a trigger area, a path, a placed tile. Its place is the map's pixels, from its top-left; what it means is the game's, from its name, class and custom properties (TiledInstance2D.findObject, getObjects).

```haxe
var id(default, null):Int
var name(default, null):String
var className(default, null):String
var shape(default, null):TiledShape2D
var x(default, null):Float
var y(default, null):Float
var width(default, null):Float
var height(default, null):Float
var rotation(default, null):Float
var visible(default, null):Bool
var points(default, null):Array<Float>
var gid(default, null):Int
var properties(default, null):TiledProperties2D
var closed(get, never):Bool
function computePoints(?out:Array<Float>):Array<Float>
```

- `id`: Its id, unique in its map.
- `name`: Its name, "" when it has none.
- `className`: Its class (Tiled's Class, or Type before 1.9), "" when it has none: what kind of thing the game should make of it.
- `shape`: Its shape.
- `x`: Its x, map pixels: a tile object's left edge, anything else's left or the point.
- `y`: Its y, map pixels, down: a tile object's bottom edge (as Tiled places them), anything else's top or the point.
- `width`: Its width, pixels (0 for a point, a polygon or a polyline).
- `height`: Its height, pixels.
- `rotation`: Its turn about x, y, radians, clockwise on screen.
- `visible`: Whether it's shown in Tiled (a tile object hidden is drawn hidden).
- `points`: A polygon's or a polyline's points relative to x, y, x and y in turn; empty for the other shapes.
- `gid`: A tile object's global id, flip bits and all (TiledMap2D.GID_MASK takes them off); 0 for the other shapes.
- `properties`: Its custom properties.
- `closed`: Whether its outline (computePoints) is closed: true for every shape but a polyline (and a point, a single point).
- `computePoints`: Its outline as points in the map's pixels, x and y in turn, turned by its rotation: ready to collide against (Collide2D) or draw (Drawing2D.polyline, polygonLines), with no sums of the game's own. A rectangle, a tile and a text give their four corners, a polygon and a polyline their points, an ellipse 16 points round it, and a point itself. Map pixels are the TiledInstance2D's own units, so with the instance placed elsewhere, add its position; an object layer's offset isn't in them. Fills out (resized) and returns it when given (nothing allocated), else a new array.

## TiledProperties2D

*class* in [`src/helix/tiled/TiledProperties2D.hx`](../../src/helix/tiled/TiledProperties2D.hx), `import helix.tiled.TiledProperties2D;`

A Tiled map's, layer's, tile's or object's custom properties (Tiled's Custom Properties panel), read by name with what it is when missing. Colors come as 0xAARRGGBB; a file property is its path as Tiled wrote it (relative to the file it's in); a class property is its members as a JSON object (getRaw).

```haxe
function new()
function has(name:String):Bool
function getNames():Array<String>
function getString(name:String, ?otherwise:String = ""):String
function getInt(name:String, ?otherwise:Int = 0):Int
function getFloat(name:String, ?otherwise:Float = 0.):Float
function getBool(name:String, ?otherwise:Bool = false):Bool
function getColor(name:String, ?otherwise:Int = 0xffffffff):Int
function getRaw(name:String):Dynamic
function getType(name:String):Null<String>
```

- `new`: None: what a thing without custom properties has.
- `has`: Whether it has the property name.
- `getNames`: The names it has, in no particular order.
- `getString`: Property name as text (a number or bool written out), or otherwise when missing.
- `getInt`: Property name as a whole number (a float's whole part, a bool 1 or 0), or otherwise when missing or not a number.
- `getFloat`: Property name as a number, or otherwise when missing or not a number.
- `getBool`: Property name as a bool (true, or a number not 0), or otherwise when missing.
- `getColor`: Property name as a color, 0xAARRGGBB (Tiled writes "#AARRGGBB", or "#RRGGBB" opaque), or otherwise when missing or not a color.
- `getRaw`: Property name as Tiled's JSON has it (a class property's members as an object), or null when missing.
- `getType`: Property name's Tiled type ("string", "int", "float", "bool", "color", "file", "object" or "class"), or null when missing.

## TiledShape2D

*enum* in [`src/helix/tiled/TiledShape2D.hx`](../../src/helix/tiled/TiledShape2D.hx), `import helix.tiled.TiledShape2D;`

What a Tiled object is: its shape in Tiled's toolbar.

- `Rectangle`: A rectangle, x and y its top-left corner.
- `Point`: A point: x and y alone, no size.
- `Ellipse`: An ellipse in the rectangle at x, y, width x height.
- `Polygon`: A closed polygon through points, relative to x, y.
- `Polyline`: An open line through points, relative to x, y.
- `Tile`: A tile placed as an object (gid), x and y its bottom-left corner as Tiled places it; drawn on its layer.
- `Text`: Text, drawn in Tiled only: its rectangle as a Rectangle's.

## TiledTerrainKind2D

*enum* in [`src/helix/tiled/TiledTerrainKind2D.hx`](../../src/helix/tiled/TiledTerrainKind2D.hx), `import helix.tiled.TiledTerrainKind2D;`

How a terrain set's tiles meet: at their corners, their edges, or both (Tiled's terrain set types).

- `Corner`: Each tile's four corners carry a terrain: the common one for ground.
- `Edge`: Each tile's four edges carry a terrain: paths, roads, fences.
- `Mixed`: Corners and edges both: drawn as Tiled stored it, but not painted at run time (TiledTileLayer2D.setTerrain refuses it).

## TiledTerrainSet2D

*class* in [`src/helix/tiled/TiledTerrainSet2D.hx`](../../src/helix/tiled/TiledTerrainSet2D.hx), `import helix.tiled.TiledTerrainSet2D;`

A tileset's terrain set (Tiled's "Terrain Set", its file's "wangset"): the terrains it has, numbered from 1 (0 is none), and for each tile that takes part which terrain is at each corner or edge, so a layer can pick the tile that fits its neighbors (TiledTileLayer2D.setTerrain).

```haxe
var name(default, null):String
var kind(default, null):TiledTerrainKind2D
var tileset(default, null):TiledTileset2D
var terrains(default, null):Array<String>
function findTerrain(name:String):Int
function getTerrainAt(id:Int, place:Int):Int
function holds(id:Int):Bool
```

- `name`: Its name in Tiled.
- `kind`: How its tiles meet.
- `tileset`: The tileset it's in.
- `terrains`: Its terrains' names, the terrain numbered n at n - 1.
- `findTerrain`: The terrain numbered name's number (from 1), or 0 when it has none of that name.
- `getTerrainAt`: Tile id's terrain at place (0 to 7 in Tiled's order, from the top clockwise: edges even, corners odd), or 0 when it isn't in the set.
- `holds`: Whether tile id is in the set.

## TiledTileLayer2D

*class* in [`src/helix/tiled/TiledTileLayer2D.hx`](../../src/helix/tiled/TiledTileLayer2D.hx), `import helix.tiled.TiledTileLayer2D;`

A Tiled map's tile layer on the stage: a sprite a cell, drawn from its tileset (nearest sampled), flipped and turned as the map says, in the map's pixels from its top-left. The game reads it (getTile, isFilled, getTileProperties: a wall, water, a ladder), changes it (setTile), and paints terrain into it as Tiled's Terrain brush does (setTerrain: dig, build, flood), the neighbors made to fit. Animated tiles step on the game's clock (TiledInstance2D). Body2D.step takes isFilled as its solid tiles: (column, row) -> walls.isFilled(column, row), the body in the same pixels with a tile size of the map's.

```haxe
var map(default, null):TiledMap2D
var columns(default, null):Int
var rows(default, null):Int
function getTile(column:Int, row:Int):Int
function isFilled(column:Int, row:Int):Bool
function getTileProperties(column:Int, row:Int):TiledProperties2D
function getTileClass(column:Int, row:Int):String
function columnAt(x:Float):Int
function rowAt(y:Float):Int
function setTile(column:Int, row:Int, gid:Int):Bool
function getTiles():Array<Int>
function setTiles(tiles:Array<Int>):Bool
function setTerrain(column:Int, row:Int, set:TiledTerrainSet2D, terrain:Int):Bool
```

- `map`: The map it's from.
- `columns`: Its width in tiles.
- `rows`: Its height in tiles.
- `getTile`: The global id at column, row, flip bits and all (TiledMap2D.GID_MASK takes them off); 0 for an empty cell or outside the layer.
- `isFilled`: Whether column, row has a tile (false outside the layer): a collision layer's solid cells.
- `getTileProperties`: The custom properties of the tile at column, row (none for an empty cell or outside).
- `getTileClass`: The class of the tile at column, row, "" for none, an empty cell or outside.
- `columnAt`: The column at x, in its own pixels (outside it too: below 0, or columns and past).
- `rowAt`: The row at y, in its own pixels, down.
- `setTile`: Puts global id gid at column, row (flip bits and all; 0 empties it). False, changing nothing, outside the layer or for an id none of the map's tilesets holds.
- `getTiles`: Its cells' global ids, flip bits and all, row by row from the top-left (columns x rows of them; 0 an empty cell): a copy, to save what the game changed (Saves, as JSON) and put back with setTiles.
- `setTiles`: Puts tiles, as getTiles gives them, in its cells, all at once. False, changing nothing, for a count other than columns x rows or an id none of the map's tilesets holds.
- `setTerrain`: Paints terrain (set's, numbered from 1, TiledTerrainSet2D.findTerrain; 0 none) into column, row as Tiled's Terrain brush does: a corner set's cell takes it at its four corners, an edge set's at its four edges, and the cell and its neighbors sharing them take the tile of the set that fits what's around them. Where none of the set's tiles fits, a cell is left as it was; where nothing of the set is left, it's emptied. False, painting nothing, outside the layer, for a terrain the set hasn't, or for a mixed set (not painted at run time); true once painted, whether every cell found its tile or not (each fits when the set has a tile for every arrangement).

## TiledTileset2D

*class* in [`src/helix/tiled/TiledTileset2D.hx`](../../src/helix/tiled/TiledTileset2D.hx), `import helix.tiled.TiledTileset2D;`

A Tiled tileset as a map uses it: one image cut into a grid of tiles (an image-collection tileset, a file a tile, isn't read), the global ids from firstGid on its tiles in order, and what its tiles carry: a class, custom properties, an animation, and the terrain sets auto-tiling picks from (TiledTerrainSet2D, the "Terrain Sets" Tiled draws with). Its texture is in once the map has loaded.

```haxe
static inline var INSET:Float
var name(default, null):String
var firstGid(default, null):Int
var tileWidth(default, null):Int
var tileHeight(default, null):Int
var tileCount(default, null):Int
var columns(default, null):Int
var margin(default, null):Int
var spacing(default, null):Int
var image(default, null):String
var texture(default, null):Null<Texture2D>
var offsetX(default, null):Int
var offsetY(default, null):Int
var terrainSets(default, null):Array<TiledTerrainSet2D>
var properties(default, null):TiledProperties2D
function holds(gid:Int):Bool
function getRegion(id:Int, out:Array<Float>):Array<Float>
function getClass(id:Int):String
function getTileProperties(id:Int):TiledProperties2D
function getAnimation(id:Int):Null<Array<TiledFrame2D>>
function findTerrainSet(name:String):Null<TiledTerrainSet2D>
```

- `INSET`: How far inside its texels a tile's region is drawn, each side: a tile edge on its neighbor's in the image would otherwise sample a line of the neighbor when the map is scaled or between pixels (the atlas's bleed).
- `name`: Its name in Tiled.
- `firstGid`: The global id of its first tile in the map; its tile n is firstGid + n.
- `tileWidth`: Each tile's size, pixels.
- `tileHeight`: Each tile's height, pixels.
- `tileCount`: How many tiles it has.
- `columns`: How many tiles a row of its image holds.
- `margin`: Pixels round the image's edge before the first tile.
- `spacing`: Pixels between tiles.
- `image`: Its image's path among the assets.
- `texture`: Its image, nearest-sampled for pixel art; null until the map has loaded (or when it's parsed alone).
- `offsetX`: Where its tiles are drawn from their cell, pixels (Tiled's Drawing Offset).
- `offsetY`: The drawing offset's y, pixels, down.
- `terrainSets`: Its terrain sets, in Tiled's order.
- `properties`: Its own custom properties.
- `holds`: Whether global id gid (its flip bits ignored) is one of its tiles.
- `getRegion`: Tile id's (counted from 0 in this tileset) region of the image, x, y, width and height in pixels, into out (4 numbers).
- `getClass`: Tile id's class (Tiled's Class, or Type before 1.9), "" when it has none.
- `getTileProperties`: Tile id's custom properties (none when it has none).
- `getAnimation`: Tile id's animation, its frames in order, or null when it isn't animated.
- `findTerrainSet`: The terrain set named name, or null.
