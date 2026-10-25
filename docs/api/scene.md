# helix.scene

[Back to the index](README.md)

## Collect2D

*class* in [`src/helix/scene/Collect2D.hx`](../../src/helix/scene/Collect2D.hx), `import helix.scene.Collect2D;`

Things collected flying to where they count: a chest's coins to the score, gems to a counter, hearts to the health bar. Sprites of a texture burst out from a point on the stage, scatter for a moment, then each curves in to a target node, one after another, a callback as each arrives (a ding, a score tick) and another once all have. It runs itself (run), on the frames' time as a Transition does, and takes itself off the stage when done; from a 3D world, the point is a View3D's project of where the chest is. In the stage's units.

```haxe
function new(texture:Texture2D, ?count:Int = 12)
var texture(default, null):Texture2D
var count(default, null):Int
var size:Float
var tint:Int
var scatter:Float
var scatterSeconds:Float
var flySeconds:Float
var stagger:Float
var running(default, null):Bool
function run(x:Float, y:Float, target:Node2D, ?arrived:Int -> Void, ?done:() -> Void):Bool
```

- `new`: Sprites of texture, count of them (at least 1), each texture's size unless sized (size).
- `texture`: Their texture.
- `count`: How many fly.
- `size`: Each sprite's size, the stage's units, square; 0 (the default) for its texture's size.
- `tint`: Their tint, 0xAARRGGBB: white (the texture as it is) by default.
- `scatter`: How far they scatter from the point before they fly, the stage's units: 48 by default.
- `scatterSeconds`: Seconds they scatter for: .35 by default.
- `flySeconds`: Seconds each takes to fly in once it sets off: .6 by default.
- `stagger`: Seconds between one setting off and the next: .05 by default.
- `running`: Whether it's running now.
- `run`: Bursts them from x, y (the stage's units) to target, each flying to where target's bounds' center is as it arrives (its position when it has none: a group), arrived (when given) called as each arrives with its index, done (when given) once all have. False, running nothing, while it's running already. With the run option quick=1, they arrive at once.

## Loader

*class* in [`src/helix/scene/Loader.hx`](../../src/helix/scene/Loader.hx), `import helix.scene.Loader;`

A group of loads with one progress: a scene's files gathered so a loading screen shows how far they are (progress, from how many have ended) and the scene starts once they're done (done), with what failed by name (failures). Each load goes through the service it always did, its own lambdas kept (a failure with no failed lambda logged with its path, as the service would); the loader only counts: loader.loadTexture(path, Linear, texture -> ...). countLoad counts any other load the game makes. Nothing here cancels: a scene that exits early cancels its own requests, and a cancelled load is never counted as ended.

```haxe
function new()
var count(get, never):Int
var doneCount(get, never):Int
var progress(get, never):Float
var done(get, never):Bool
var failures(get, never):Array<String>
function countLoad(name:String, complete:T -> Void, failed:T -> Null<String>):T -> Void
function loadAsset(path:String, loaded:haxe.io.Bytes -> Void, ?failed:String -> Void):IRequest
function loadTexture(path:String, filter:Filter, loaded:Texture2D -> Void, ?failed:String -> Void):IRequest
function loadClip(path:String, loaded:AudioClip -> Void, ?failed:String -> Void):IRequest
function loadStream(path:String, loaded:AudioStream -> Void, ?failed:String -> Void):IRequest
function loadEnvironment(path:String, loaded:EnvironmentMap3D -> Void, ?failed:String -> Void):IRequest
function loadModel(path:String, loaded:ModelFile3D -> Void, ?failed:String -> Void, ?models:ModelCache3D):IRequest
```

- `new`: No loads yet: done, at progress 1.
- `count`: How many loads were added.
- `doneCount`: How many have ended, failed ones included.
- `progress`: How far along, 0 to 1 (1 with nothing to load).
- `done`: Whether every load has ended.
- `failures`: What failed, each as its name and the reason.
- `countLoad`: Counts a load the game makes itself, named name: returns its completion to call with the result in place of complete, which it calls in turn; failed gives the reason for a result that failed, or null.
- `loadAsset`: An asset's bytes through Assets.
- `loadTexture`: A texture through Textures, filtered by filter (Linear smooth, with mipmaps; Nearest sharp, for pixel art).
- `loadClip`: A sound clip through Audio.
- `loadStream`: A sound stream through Audio.
- `loadEnvironment`: An environment through Environments3D (loaded once it's prepared).
- `loadModel`: A model file through Models3D (or models, a cache of a test's).

## Loading

*class* in [`src/helix/scene/Loading.hx`](../../src/helix/scene/Loading.hx), `import helix.scene.Loading;`

The built-in loading screen (docs/DISPLAY_MODEL.md): the theme's panel color or a picture (setImage: a level's art, covering the screen or centered), a caption ("Loading the caves", text; "Loading" unless given) over a bar of its loader's progress and the count, a tip along the bottom (tip), and what failed in the disabled text color. Shown on the stage (show) over what's there until its loader is done, then taken off and then called: put the level on the stage there. With holdForPress it stays once loaded, saying so, until a press (the "loaded, go" screen of a movie-like opening). It runs itself; quick (the run option quick=1) doesn't hold.

```haxe
function new(loader:Loader, ?theme:Theme)
var loader(default, null):Loader
var theme:Theme
var image(default, null):Null<Texture2D>
function setImage(value:Null<Texture2D>, ?cover:Bool = true):Void
var text:String
var tip:String
var holdForPress:Bool
var prompt:String
var shown(default, null):Bool
function show(then:() -> Void):Bool
```

- `new`: A loading screen of loader's progress, in theme's look (a new Theme unless given).
- `loader`: The loads it shows.
- `theme`: The theme it draws with.
- `image`: Its picture, or null.
- `setImage`: A picture behind the rest: covering the screen (cropped to its shape) when cover, else centered whole; null for the panel color alone.
- `text`: The caption over the bar: what's loading ("Loading the caves").
- `tip`: A line along the bottom (a hint, a credit), wrapped; "" for none.
- `holdForPress`: Whether it stays once the loads are done, showing the prompt, until a key, a button or a finger is pressed.
- `prompt`: The line shown once loaded, while holding for a press.
- `shown`: Whether it's on the stage now.
- `show`: Puts it on the stage, over what's there, until its loader is done (and a press, with holdForPress), then takes it off and calls then. False, doing nothing, while it's shown already.

## Node

*class* in [`src/helix/scene/Node.hx`](../../src/helix/scene/Node.hx), `import helix.scene.Node;`

What every node shares, in a 3D tree (Node3D) or a 2D one: a name, the flags (visible, paused, pickable), a parent and children, and find. It has no transform: Node3D and Node2D add their own, each taking children of its own kind only (its addChild and removeChild). Never made bare and never subclassed by a game: the framework's kinds are its classes, and game state lives elsewhere, the node its view (docs/DECISIONS.md, 61 and 130).

```haxe
var name:String
function find(name:String, kind:Class<T>):Null<T>
var visible:Bool
var paused:Bool
var pickable:Bool
var childCount(get, never):Int
function getChild(index:Int):Null<Node>
function contains(node:Null<Node>):Bool
function getChildIndex(child:Node):Int
```

- `name`: Its name: a model file's node name, or what the game gave it; "" for none.
- `find`: The first node named name below it (depth first, in drawing order), as kind, or null when there's none or it isn't a kind: `var greeting = root.find("greeting", Text2D);`, `var wheel = car.find("wheel_rl", Model3D);`, or the tree's own class (Node2D, Node3D) for any node. Never a path. For picking out a part of a loaded model or a scene once and keeping it, not for every frame.
- `visible`: Whether it and everything under it are shown: off, none of it is drawn or picked (a light doesn't shine or cast), though it all still runs (behaviors, emitters) and stays placed. A child's own visible is kept, so showing it again brings each back as set. On to start.
- `paused`: Whether it and everything under it are frozen: on, still drawn and picked, but their behaviors don't update and what moves by itself (emitters, decals fading, animated tiles) holds still (a level frozen under a pause menu, docs/DISPLAY_MODEL.md). Off to start.
- `pickable`: Whether it and everything under it can be picked: off, a pick passes through them all to what's behind. What a node is hit by is what it draws, or its hitArea when it has one. On to start, but for text.
- `childCount`: How many children it has.
- `getChild`: Its child at index, in drawing order; null past the end.
- `contains`: Whether node is this one or anywhere below it: `if (ball.contains(Stage.pick(x, y)))`, a pick's node (the deepest hit) inside a group. By the node itself, not its name (find); null is in nothing.
- `getChildIndex`: child's index among its children, in drawing order (0 is drawn first), or -1 when it isn't one of them.

## Pointer

*class* in [`src/helix/scene/Pointer.hx`](../../src/helix/scene/Pointer.hx), `import helix.scene.Pointer;`

The pointer over stages: which node it's over, and what it pressed and clicked, asked of it, never told to the nodes (DECISIONS 61). The stages it looks at are added in draw order, each with the camera it's drawn through; update() picks them topmost (last added) first, once a frame after input is polled, so a HUD drawn over the world takes the pointer first. A press on a 2D node captures the pointer: until it's released, the stages under it see nothing (captured, for an app's own use of the pointer too). Edges (isPressed, isClicked) last the frame they happen in. Nodes are compared by identity: a 3D stage's are Node3Ds, a 2D stage's Node2Ds. With no stages added, it looks at the Stage (helix.render2d.Stage) and the views on it, in their drawing order (docs/DISPLAY_MODEL.md).

```haxe
function new(?input:IInput)
function update():Void
var hovered(default, null):Null<Any>
function isHovered(node:Any):Bool
function isPressed(node:Any):Bool
function isDown(node:Any):Bool
function isClicked(node:Any):Bool
var held(default, null):Null<Any>
var captured(default, null):Bool
var hit3D(get, never):Null<PickHit3D>
```

- `new`: The pointer of input, or of the program's (Input) when not given, read as it's used, so a pointer made before the program runs (a field's initial value) works.
- `update`: Once a frame, after input is polled and before the stages' nodes are read: picks under the pointer, topmost stage first, and works out the frame's press and click.
- `hovered`: The node under the pointer, topmost stage first, or null.
- `isHovered`: Whether node is under the pointer.
- `isPressed`: Whether the pointer went down on node this frame.
- `isDown`: Whether node is held: the pointer went down on it and hasn't come up, wherever it is now (a drag).
- `isClicked`: Whether node was clicked this frame: the pointer came up over the node it went down on.
- `held`: The node held (isDown), or null.
- `captured`: Whether a press on a 2D stage holds the pointer: the stages under it, and the app's own world controls, should leave it be.
- `hit3D`: The last hit in a 3D stage (its point, normal, distance), when the hovered node is a 3D stage's; null otherwise.

## SceneBehavior

*class* in [`src/helix/scene/SceneBehavior.hx`](../../src/helix/scene/SceneBehavior.hx), `import helix.scene.SceneBehavior;`

A behavior as a .scene3d file attaches it to a node: the behavior class's name and its props by name, as data. The file says which behaviors a node gets; at run time they live in the behaviors pass, never on the node.

```haxe
function new(kind:String)
var kind:String
var props:Map<String, SceneValue>
```

- `new`: A behavior of class kind with no props set.
- `kind`: The behavior class's name, as the registry knows it.
- `props`: Its props by name: numbers, text, flags, lists, colors and references to nodes of the file.

## SceneEnvironment3D

*class* in [`src/helix/scene/SceneEnvironment3D.hx`](../../src/helix/scene/SceneEnvironment3D.hx), `import helix.scene.SceneEnvironment3D;`

A .scene3d file's environment section: the place's light (helix.render3d.Environment3D), set on the node the file is instantiated as (its root group, or a prefab's node), lighting what's under it. Each null means the default and is not written. How a camera photographs the place (exposure, tone mapping) is the view's (View3D), not the file's.

```haxe
function new()
var ambientColor:Null<Int>
var ambientIntensity:Null<Float>
var mapFile:Null<String>
var mapIntensity:Null<Float>
var rotation:Null<Float>
var backgroundFile:Null<String>
var backgroundBlur:Null<Float>
```

- `new`: A section that says nothing.
- `ambientColor`: The ambient light's color, 0xAARRGGBB; null for white.
- `ambientIntensity`: The ambient light's intensity, 0 or more; null for 0.
- `mapFile`: The environment map's file (an HDR, loaded through Environments3D), lighting and reflecting; null for none.
- `mapIntensity`: How strongly the map lights, 1 as its file has it; null for 1.
- `rotation`: How far the map and the background turn about +y, in radians; null for 0.
- `backgroundFile`: The background's file (an HDR, loaded through Environments3D); null for none.
- `backgroundBlur`: How blurred the background is, 0 sharp to 1; null for 0.

## SceneFile3D

*class* in [`src/helix/scene/SceneFile3D.hx`](../../src/helix/scene/SceneFile3D.hx), `import helix.scene.SceneFile3D;`

A .scene3d file as parsed: HeliX's own JSON, one tree. Its version ("helix-scene3d"), its environment section and its nodes, each a SceneNode3D with its kind's properties as SceneSchema3D's tables say. Parsed from bytes, every problem logged through Failure and the whole refused, so a file either loads as written or says why; written back canonically (write), so load, write, load gives the same bytes and a hand edit stays where it was made; instantiated under a 3D node (instantiate) and captured back from a live instance (capture). A scene is a tree of nodes: a level and a prefab are the same thing used two ways, the root of what a View3D shows or a node inside another tree.

```haxe
function new()
static inline var VERSION:Int
static function parse(bytes:haxe.io.Bytes, ?path:String):Null<SceneFile3D>
static function capture(instance:SceneInstance3D):SceneFile3D
var version:Int
var environment:Null<SceneEnvironment3D>
var nodes:Array<SceneNode3D>
function instantiate(parent:Node3D, ?behaviors:BehaviorPass, ?ready:() -> Void):SceneInstance3D
var path(default, null):Null<String>
function write():haxe.io.Bytes
```

- `new`: An empty file of the current version: no environment section, no nodes.
- `VERSION`: The format version read and written: the file's "helix-scene3d" value.
- `parse`: The file in bytes (JSON), parsed; path names it in the log. Null, with every problem logged through Failure naming the node's path or the key, for a file that isn't a JSON object, a missing or other "helix-scene3d" version, an unknown key at the root, in the environment section or in a material, a node without a name, two siblings with one name, a node with both "kind" and "scene" or neither, a kind no table has, a key no table has on a node or an override, a value of the wrong shape, a file, a mesh or a material on a kind that isn't a Model3D, a Model3D with both a file and a mesh, a mesh without a shape or of a shape no generator makes, with a key its shape hasn't, a required argument missing or one that isn't a number, overrides on a node with no file and no scene, an override with a name, a kind, a mesh or an empty path, or a behavior without a kind.
- `capture`: The file that would instantiate to what instance is now: the environment section from its root's environment (what isn't the default), each of the instance's own nodes from the live node (its kind, name, transform, flags, properties, material where the file gave one, the behaviors the instance attached with their props away from their defaults, its props), a node from a model file or a prefab as the reference plus an override for every node under it whose values differ from what the file gave (what differs only, with the children and behaviors attached there; a file that hasn't landed keeps its overrides as written), and a node a game added at run time as its class with its properties (a Model3D whose mesh came from one of Mesh3D's generators as its mesh entry; one whose mesh has no record of what made it, from arrays or a file, has no file and loads back as an empty Model3D: logged once). A reference is written as the node's name when one node of the instance has it, else its path. The defaults rule: a capture says only what differs from the defaults, so the environment section holds what isn't the default, a behavior's prop at its schema default is left out, a kind's property at its class's default is left out, and a flag at its kind's own default is left out; a default a hand wrote into the file vanishes on capture. Capturing an untouched instance gives the file it was made from, written canonically.
- `version`: The file's "helix-scene3d" version: VERSION, the only one read.
- `environment`: Its environment section (the place's light, set on the node it's instantiated as), or null when the file has none.
- `nodes`: Its nodes at the root, in drawing order.
- `instantiate`: Makes the file's tree under parent, its behaviors on behaviors (the program's, Behaviors, unless given another): a new group named after the file (its path without directory and extension) added as parent's last child, lit by the environment section (its Node3D.environment: the ambient light at once, the map and background once their files land through Environments3D), then every node at once under the group, a Model3D's file and a prefab landing later through Models3D and SceneFiles3D (their nodes moved under the entry's node, which is then the file's root, the entry's overrides applied by path), each node's behaviors made from BehaviorRegistry and attached once everything has landed. ready, when given, is called at the pass's next update after that, once the behaviors have started: never inside this call. A missing model, prefab or environment, a prefab naming itself (directly or through another), an unknown behavior, a refused prop or property, and an override naming no node are each logged through Failure with this file's path and the node's, the rest made, and ready still comes. The instance remembers where each node came from, for capture.
- `path`: The path it was parsed under, as parse was given it; "scene" for none. What instantiate names the instance by.
- `write`: The file as canonical JSON: keys in a fixed order, two-space indentation, one key per line, number lists on one line, a trailing newline, numbers with at most six decimals and no trailing zeros, written alike on every target. Absent keys mean defaults: a transform at identity, a node's flag at its kind's own default (an override's is written whenever said), a property at its class's default, a mesh's argument at its generator's default, an unsaid environment or material value, and a property no table has, are not written.

## SceneFiles3D

*class* in [`src/helix/scene/SceneFiles3D.hx`](../../src/helix/scene/SceneFiles3D.hx), `import helix.scene.SceneFiles3D;`

Scene files (.scene3d), parsed once and shared by path (SceneFileCache3D). The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from SceneFileCache3D's public members with their doc comments.

```haxe
static function load(path:String, loaded:SceneFile3D -> Void, ?failed:String -> Void):IRequest
static function find(path:String):Null<SceneFile3D>
static function isLoaded(path:String):Bool
static function isLoading(path:String):Bool
static var loadingCount(get, never):Int
static function put(path:String, file:SceneFile3D):Void
static function forget(path:String):Void
```

- `load`: Loads path (a .scene3d) into a SceneFile3D, parsed with SceneFile3D.parse under its path. One of loaded or failed runs once: during this call when the file is loaded already (or failed before; forget clears a failure), else on the host thread when its load ends; failed (else the log, with the path) for a load failure or a file the parser refuses, with its reason (each problem the parser found is logged as well). Neither runs once the request is cancelled (the shared load goes on for the others) or the cache shuts down.
- `find`: The file at path if it's loaded, else null.
- `isLoaded`: Whether path is loaded.
- `isLoading`: Whether path is loading.
- `loadingCount`: How many files are loading.
- `put`: Adds a file parsed some other way under path, as if loaded from there (a test's, a generated one).
- `forget`: Forgets path: its file (the instances made from it stay) or its failure, so it's loaded again when next asked for.

## SceneInstance3D

*class* in [`src/helix/scene/SceneInstance3D.hx`](../../src/helix/scene/SceneInstance3D.hx), `import helix.scene.SceneInstance3D;`

What instantiating a .scene3d file gives (SceneFile3D.instantiate): its root, a group named after the file under the node it was put in, holding every node the file made, the nodes by path, the behaviors it attached, the game's props by node, and whether every load has landed (ready). It remembers where each node came from (the file's own entry, a model file by path, a prefab by path) and the values the origin gave it, so SceneFile3D.capture writes back a file that instantiates to what the tree is now, a node from a file or a prefab as the reference plus what differs. destroy takes it all out again.

```haxe
static function baseName(path:String):String
var path(default, null):String
var root(default, null):Node3D
var parent(default, null):Node3D
var behaviors(default, null):Array<Behavior>
var ready(default, null):Bool
function node(path:String):Null<Node3D>
function pathOf(node:Node3D):Null<String>
function props(node:Node3D):Null<Map<String, SceneValue>>
function destroy():Void
```

- `baseName`: The file's name without directory and extension: "levels/track.scene3d" gives "track".
- `path`: The file's path, as it was loaded.
- `root`: The node holding everything the file made: a group named after the file (its path without directory and extension), under the node it was instantiated in, lit by the file's environment section (its environment).
- `parent`: The node the file was instantiated in, its root's parent then.
- `behaviors`: The behaviors it attached, in the order the file gave them, prefabs' included.
- `ready`: Whether every model, prefab, texture, font and environment the file names has landed or failed, and the behaviors are attached to the pass: false until then. The ready lambda given to instantiate follows at the pass's next update, once they have started.
- `node`: The node at path, slash-separated names from the root (never the root's own name), through nodes a file or a prefab made; null for none. The first of two siblings named alike.
- `pathOf`: Node's path from the root, as node takes it; null for the root itself or a node not under it.
- `props`: The game's own values the file gave node ("props"), kept here, never on the node; null for a node the file didn't make.
- `destroy`: Takes it out: its behaviors from the pass (stopping the started ones), its root from the node it was put in, and the textures, fonts and environments it loaded released to their caches (the last release frees each). Its model and scene files stay in their caches, which keep files until told to forget them. A load still under way is cancelled.

## SceneMaterial3D

*class* in [`src/helix/scene/SceneMaterial3D.hx`](../../src/helix/scene/SceneMaterial3D.hx), `import helix.scene.SceneMaterial3D;`

A material as a .scene3d file writes it inline on a Model3D: Material3D's values, each null when the file doesn't say it, so an override changes one value and leaves the rest.

```haxe
function new()
var baseColor:Null<Int>
var metallic:Null<Float>
var roughness:Null<Float>
var texture:Null<String>
var normalTexture:Null<String>
var normalScale:Null<Float>
var emissive:Null<Int>
var emissiveStrength:Null<Float>
var doubleSided:Null<Bool>
```

- `new`: A material saying nothing.
- `baseColor`: The base color, 0xAARRGGBB; null for unsaid.
- `metallic`: How metallic, 0..1; null for unsaid.
- `roughness`: How rough, 0..1; null for unsaid.
- `texture`: The base color texture's path; null for unsaid.
- `normalTexture`: The normal map's path; null for unsaid.
- `normalScale`: How strongly the normal map bends the surface, 0 or more; null for unsaid.
- `emissive`: The light it gives off, 0xAARRGGBB; null for unsaid.
- `emissiveStrength`: How bright its emissive light is, 0 or more; null for unsaid.
- `doubleSided`: Whether both sides of its triangles draw; null for unsaid.

## SceneMesh3D

*class* in [`src/helix/scene/SceneMesh3D.hx`](../../src/helix/scene/SceneMesh3D.hx), `import helix.scene.SceneMesh3D;`

A generated mesh as a .scene3d file writes it on a Model3D ("mesh", in place of a file): the shape's name (plane, cube, sphere, cylinder, cone, capsule or torus: SceneSchema3D.shapes) and its numbers by the generator's own argument names (a plane's width, length and subdivisions; a sphere's radius, rings and segments), an optional one absent when the generator's default.

```haxe
function new(shape:String)
var shape:String
var arguments:Map<String, Float>
```

- `new`: A mesh of shape with no argument said yet.
- `shape`: The shape's name, one of SceneSchema3D.shapes.
- `arguments`: Its arguments by name, those said; one absent is the generator's default.

## SceneNode3D

*class* in [`src/helix/scene/SceneNode3D.hx`](../../src/helix/scene/SceneNode3D.hx), `import helix.scene.SceneNode3D;`

A node as a .scene3d file has it, not a live one: its kind (or the prefab it instantiates), name, a Model3D's glTF or generated mesh, its transform and flags (each null when unsaid), its kind's properties by name, an inline material, overrides by path for the nodes its file or prefab makes, its children, the behaviors to attach and the game's own props. Each absent part means the default: a null transform is identity, a null flag true, a property its class's. An override is a SceneNode3D too, with no name, kind or scene: only what it changes, plus children and behaviors to add. Phase 3 of the file's plan makes live nodes from these and captures them back.

```haxe
function new(?kind:String, ?name:String)
var name:Null<String>
var kind:Null<String>
var scene:Null<String>
var file:Null<String>
var mesh:Null<SceneMesh3D>
var position:Null<Array<Float>>
var rotation:Null<Array<Float>>
var scale:Null<Array<Float>>
var visible:Null<Bool>
var pickable:Null<Bool>
var paused:Null<Bool>
var properties:Map<String, SceneValue>
var material:Null<SceneMaterial3D>
var overrides:Map<String, SceneNode3D>
var children:Array<SceneNode3D>
var behaviors:Array<SceneBehavior>
var props:Map<String, SceneValue>
var isOverride(get, never):Bool
```

- `new`: A node of kind (null for a prefab node or an override), named name (null for an override), everything else at its default.
- `name`: Its name, unique among its siblings (paths depend on it); null for an override.
- `kind`: The class it is (Node3D for a group, else a kind's name from SceneSchema3D); null for a prefab node or an override.
- `scene`: The .scene3d file instantiated here as a prefab; null for a node of a kind or an override.
- `file`: A Model3D's glTF, instantiated under it; null for none. A Model3D has a file or a mesh, never both.
- `mesh`: A Model3D's generated mesh, made by one of Mesh3D's generators as its first part; null for none.
- `position`: Its position, x, y, z in its parent's units; null for the origin.
- `rotation`: Its rotation, Euler x, y, z in radians as Node3D.setRotation takes them; null for none.
- `scale`: Its scale, x, y, z; null for 1, 1, 1.
- `visible`: Whether it and everything under it are shown (Node.visible), as the file says it; null for unsaid: true for a node, unchanged for an override, which may say true to bring a prefab's hidden node back.
- `pickable`: Whether it and everything under it can be picked (Node.pickable), as the file says it; null for unsaid: true for a node, unchanged for an override.
- `paused`: Whether it and everything under it are frozen (Node.paused), as the file says it; null for unsaid: false for a node, unchanged for an override.
- `properties`: Its kind's properties by name (intensity, fovY, tint), from its kind's table in SceneSchema3D; one absent is the class's default. An override's name any kind's property.
- `material`: A Model3D's inline material, replacing the mesh's or the file's root material; null for none.
- `overrides`: By path from this node ("road/line"), what changes on the nodes its file or prefab makes: each an override node.
- `children`: The nodes under it, in drawing order; under an override, the nodes added.
- `behaviors`: The behaviors attached to it when the scene is instantiated.
- `props`: The game's own values by name, kept by the instance for this node, never on the live node.
- `isOverride`: Whether it is an override: no name, no kind and no prefab, only what changes on a node another file made.

## SceneValue

*enum* in [`src/helix/scene/SceneValue.hx`](../../src/helix/scene/SceneValue.hx), `import helix.scene.SceneValue;`

A value as a .scene3d file holds it: a kind's property, a behavior's prop, or one of a node's own props. JSON's own shapes (a number, text, a bool, a list of numbers), and two shapes of string the file gives a meaning: a color, "#RRGGBB" or "#RRGGBBAA", and a reference to a node of the file, "@name" or "@path/from/root".

- `Number(value:Float)`: A number.
- `Text(value:String)`: Text: a path to an asset, a named choice ("camera"), or what a behavior wants.
- `Flag(value:Bool)`: A bool.
- `Numbers(values:Array<Float>)`: A list of numbers.
- `Color(rgba:Int)`: A color, 0xAARRGGBB; "#RRGGBB" in the file is alpha ff.
- `Reference(path:String)`: A reference to a node of the file: the name or path after the "@", resolved once every node is made.

## Splash

*class* in [`src/helix/scene/Splash.hx`](../../src/helix/scene/Splash.hx), `import helix.scene.Splash;`

The built-in splash (docs/DISPLAY_MODEL.md): a logo (or none) centered on the theme's panel color, shown on the stage (show) for at least its seconds, then taken off through its transition (a half-second fade unless given), then called at the transition's middle: put the next screen on the stage there. It leaves once the user has pressed a key, a button or a finger (IInput.activated: a browser lets audio start and fullscreen be asked for only after that; the same rule everywhere), or after maxWait's seconds without one: "press any key" shows until then, or, where a press came already, nothing. A pad's press doesn't count (a browser can't unlock with one), so the line stays for a tap. It runs itself; quick (the run option quick=1) skips its wait. theme for its colors and font, prompt for the line.

```haxe
function new(logo:Null<Texture2D>, seconds:Float, ?transition:Transition)
var theme:Theme
var prompt:String
var elapsed(default, null):Float
var maxWait(default, set):Float
function show(next:() -> Void):Bool
```

- `new`: A splash of logo (null: the theme's colors alone), shown at least seconds, leaving by transition (a half-second fade unless given).
- `theme`: The theme it draws with.
- `prompt`: The line that asks for the press, shown until one comes ("press any key" to start).
- `elapsed`: Seconds shown so far.
- `maxWait`: The most seconds it waits for a press before going on without one (a game that needs no audio unlock, or one that unlocks later); 0, the default, waits for one as long as it takes. 0 or more (under 0, or NaN, is 0).
- `show`: Puts it on the stage, over what's there, until it leaves, calling next at its transition's middle as it's taken off. False, doing nothing, once shown.
