# helix.behavior

[Back to the index](README.md)

## Behavior

*class* in [`src/helix/behavior/Behavior.hx`](../../src/helix/behavior/Behavior.hx), `import helix.behavior.Behavior;`

What a game's logic on a node extends: a behavior drives the node a BehaviorPass pass gave it (node), from start to stop, its update run each frame by the pass while it's enabled and its node isn't paused, until it sets done. It is never on the node: nodes draw, behaviors act, the pass runs them, and the game's state stays the truth (docs/DECISIONS.md, 61 and 130). Nothing else is on it: no signals, no children, no lookups through the node; a behavior reaches the game as any code does, through statics, the scene, what it was given.

Its props, the fields a scene file or an inspector sets, are `@:prop public var` fields with an initializer (`@:prop public var radius = 4.;`), of Int, Float, Bool, String, Array<Float>, a color (an Int marked `@:prop("color")`) or Node3D (a reference); an optional `@:range(min, max)` on the field gives an inspector its range. `@:phase(Late)` on the class says when in a frame it runs (Phase: Input, Simulate, Resolve, Late; Simulate without it). The build macro helix.macro.Behaviors runs on each subclass: it generates `schema()` and the typed setters the registry uses, and registers the class in BehaviorRegistry by its name, or the string in `@:behavior("Name")` on the class, as the program starts (so a class the game's code never names, one only a file names, must be in the build: a class path's `--macro include("pack")`, or an import). A class marked `@:abstract`, or whose constructor takes arguments, is built but not registered: it is a base for others.

Across a hot reload, as docs/DECISIONS.md 130 says of closures: in the browser a reload re-points its methods as any class's, so an instance in a pass runs the new update from the next frame, keeping its fields; natively an old instance runs its old module until the pass is remade (a scene re-entered).

```haxe
function new()
var pass(default, null):Null<BehaviorPass>
var node(default, null):Null<Node3D>
var enabled:Bool
var done:Bool
var phase(get, never):Phase
function start():Void
function update(dt:Float):Void
function stop():Void
```

- `new`: One in no pass yet.
- `pass`: The pass it's in, from add until it's dropped, null outside: how a behavior reaches another through a node it was given (`pass.on(node, Race)`), with no lookup through the node itself. Add refuses one already in a pass, anywhere.
- `node`: The node it drives: set by the pass it's added to, before start, and null until then and once it's dropped.
- `enabled`: Whether its update runs: off, the pass skips it (start and stop still come). On to start.
- `done`: Set true to end it: at the end of that update the pass calls stop and drops it. False to start.
- `phase`: When in a frame the pass updates it: the class's `@:phase(...)`, its base's without one, Simulate when none says. The build macro generates the getter for a class that says, so the pass reads it without reflection.
- `start`: Once, on the pass's first update after it's added, its node set: what it needs from the node and the game.
- `update`: A frame, dt seconds since the last, while it's enabled and its node (with every node above it) isn't paused.
- `stop`: Once, when it ends (done), is removed or the pass is cleared, after start: undo what start did. Not called for one never started.

## BehaviorEntry

*class* in [`src/helix/behavior/BehaviorEntry.hx`](../../src/helix/behavior/BehaviorEntry.hx), `import helix.behavior.BehaviorEntry;`

One registered behavior class: its schema, a new instance by make, and its props set and read by name through the setters and getters the build macro generated for the class, typed, with no reflection.

```haxe
var name(get, never):String
var schema(default, null):BehaviorSchema
function make():Behavior
function setProp(behavior:Behavior, name:String, value:Dynamic):Bool
function getProp(behavior:Behavior, name:String):Dynamic
```

- `name`: The name it's registered under: the schema's.
- `schema`: Its props: names, types, defaults and ranges.
- `make`: A new behavior of the class, its props at their defaults, in no pass.
- `setProp`: Sets behavior's prop name to value. False, changing nothing, for a name the schema doesn't have, a value of the wrong type (a Float for an Int, a String for a number, a list with something but numbers in it, a node reference that isn't a Node3D or null), or a behavior that isn't of this class.
- `getProp`: Behavior's prop name as it is now; null for a name the schema doesn't have or a behavior that isn't of this class.

## BehaviorPass

*class* in [`src/helix/behavior/BehaviorPass.hx`](../../src/helix/behavior/BehaviorPass.hx), `import helix.behavior.BehaviorPass;`

A pass that runs behaviors: add puts a behavior on a node, update each frame starts the ones added since the last update (in order, so a scene file can attach many and they start together), then updates each enabled one whose node runs (not paused, with every node above it: a paused group stops what's under it, Node.paused; a hidden one runs) phase by phase, Input, Simulate, Resolve, Late (Phase, the class's `@:phase`), each phase's in the order added, then stops and drops the ones done. The program's one is Behaviors, run by the runner after the app's update and before the frame is drawn (docs/DISPLAY_MODEL.md); a test makes its own and updates it. Adding, removing and clearing inside a behavior's start, update or stop are safe: the pass walks copies, and a change takes effect from the next step.

Behaviors don't signal each other. One that decides across entities is a resolver (a Combat in Resolve, found with find): the others report to it or queue on it, and it gathers what has a say on an entity with allUnder (gear on the entity's child nodes implementing an interface, an IDamageModifier) and applies them in an order of its own, so the order lives in one place a test can read.

```haxe
function new()
function add(behavior:Behavior, node:Node3D):Bool
function remove(behavior:Behavior):Bool
var count(get, never):Int
function find(cls:Class<T>):Null<T>
function findAll(cls:Class<T>):Array<T>
function on(node:Node3D, cls:Class<T>):Null<T>
function of(node:Node3D):Array<Behavior>
function allUnder(node:Node3D, cls:Class<T>):Array<T>
function clear():Void
function update(dt:Float):Void
```

- `new`: No behaviors yet.
- `add`: Puts behavior on node: it starts on the next update. False, changing nothing, for one already in a pass (this or another) or a null node.
- `remove`: Takes behavior out: stopped first if it had started. False when it isn't in this pass.
- `count`: How many it holds: started, or waiting for the next update to start.
- `find`: The first behavior of class cls (or a subclass) in it, started ones first (by phase, then in the order added), or null.
- `findAll`: Every behavior of class cls (or a subclass) in it, started ones first (by phase, then in the order added).
- `on`: The first behavior of class cls (or a subclass) on node, started ones first (by phase, then in the order added), or null: how a behavior given a node reference reaches the behavior on it.
- `of`: The behaviors on node, started ones first (by phase, then in the order added).
- `allUnder`: Every behavior of class or interface cls on node or on a node under it, started ones first (by phase, then in the order added), then the pending: how a resolver gathers what has a say on an entity, the gear on its child nodes implementing an interface (`allUnder(target, IDamageModifier)`). Each behavior's node is walked up to node; the tree isn't walked down.
- `clear`: Takes every behavior out, stopping each started one (by phase, then in the order added).
- `update`: A frame: starts the ones added since the last update, updates the enabled ones under nodes not paused by dt seconds (a clock's delta), every Input one, then every Simulate, Resolve and Late one, each phase's in the order added; then stops and drops the ones done. Once a frame.

## BehaviorProp

*typedef* in [`src/helix/behavior/BehaviorProp.hx`](../../src/helix/behavior/BehaviorProp.hx), `import helix.behavior.BehaviorProp;`

One `@:prop` of a behavior class: the field's name, what it holds, the value it starts with (the field's initializer, read by the macro) and, from `@:range(min, max)`, the least and most an inspector offers; null for no range. The range is for an inspector's slider: setting a prop through the registry doesn't clamp to it.

- `value:Dynamic`: The field's initializer: what a fresh behavior has until the file or the game sets it (a node reference's is null).
- `type:BehaviorPropType`: What the field holds.
- `name:String`: The field's name, which the file and the registry use.
- `min:Null<Float>`: The least from `@:range`, or null.
- `max:Null<Float>`: The most from `@:range`, or null.

## BehaviorPropType

*enum* in [`src/helix/behavior/BehaviorPropType.hx`](../../src/helix/behavior/BehaviorPropType.hx), `import helix.behavior.BehaviorPropType;`

The types a `@:prop` field can have, as a scene file writes them: a number, a string, a bool, a list of numbers, a color or a node reference. A field of any other type is a compile error naming it.

- `IntProp`: An `Int`.
- `FloatProp`: A `Float`.
- `BoolProp`: A `Bool`.
- `StringProp`: A `String`.
- `FloatsProp`: An `Array<Float>` (the type declared on the field).
- `ColorProp`: An `Int` holding a color, 0xAARRGGBB, marked `@:prop("color")`: a file writes it `"#RRGGBB"` or `"#RRGGBBAA"`.
- `NodeProp`: A `helix.render3d.Node3D`, a reference to a node of the file (`"@name"` or `"@path/from/root"`), null until resolved.

## BehaviorRegistry

*class* in [`src/helix/behavior/BehaviorRegistry.hx`](../../src/helix/behavior/BehaviorRegistry.hx), `import helix.behavior.BehaviorRegistry;`

The program's behavior classes by name, for a scene file's loader and an inspector: each subclass of Behavior registers itself as the program starts (its registration is generated by the build macro helix.macro.Behaviors), with its schema, how to make one and how to set and read its props by name, so nothing is found by reflection at run time. A file naming a behavior no class registered finds nothing here, and the loader logs it.

```haxe
static function register(name:String, make:() -> Behavior, schema:BehaviorSchema, setProp:(Behavior, String, Dynamic) -> Bool, getProp:(Behavior, String) -> Dynamic):Void
static function find(name:String):Null<BehaviorEntry>
static var names(get, never):Array<String>
static var schemas(get, never):Array<BehaviorSchema>
```

- `register`: Registers a behavior class under name with its schema, make (a new instance), setProp and getProp (the generated setters and getters, by prop name). A later registration under the same name replaces the earlier: a hot reload registers each class again. Called by the generated code as the program starts; a game doesn't call it.
- `find`: The class registered under name, or null.
- `names`: The registered names, sorted (registration order differs between targets).
- `schemas`: Every registered class's schema, by name sorted: what an inspector lists.

## BehaviorSchema

*typedef* in [`src/helix/behavior/BehaviorSchema.hx`](../../src/helix/behavior/BehaviorSchema.hx), `import helix.behavior.BehaviorSchema;`

What a behavior class takes from a scene file or an inspector: its name (the class's, or what `@:behavior("Name")` gave it), its phase and its props, each a `@:prop` field with its type, its default and its range. Generated on each subclass by the build macro (helix.macro.Behaviors, its `schema()`), and kept by BehaviorRegistry by name.

- `props:Array<BehaviorProp>`: Its props, a superclass's first, each in the order declared.
- `phase:Phase`: When in a frame it runs: `@:phase` on the class, its superclass's without one, Simulate when none says.
- `name:String`: The name a file or the registry knows the class by.

## Behaviors

*class* in [`src/helix/behavior/Behaviors.hx`](../../src/helix/behavior/Behaviors.hx), `import helix.behavior.Behaviors;`

The program's behaviors: one pass (BehaviorPass) the runner updates after the app's update and before the frame is drawn, with the game's clock, so a behavior attached to a node on the stage runs with nothing more (docs/DISPLAY_MODEL.md); what a scene file attaches goes here unless it's given another pass. Installed by its first use. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from BehaviorPass's public members with their doc comments.

```haxe
static var pass(get, never):BehaviorPass
static function find(cls:Class<T>):Null<T>
static function findAll(cls:Class<T>):Array<T>
static function on(node:Node3D, cls:Class<T>):Null<T>
static function allUnder(node:Node3D, cls:Class<T>):Array<T>
static function add(behavior:Behavior, node:Node3D):Bool
static function remove(behavior:Behavior):Bool
static var count(get, never):Int
static function of(node:Node3D):Array<Behavior>
static function clear():Void
```

- `pass`: The program's pass itself, installed if it wasn't: what SceneFile3D.instantiate attaches to unless given another.
- `find`: The first behavior of class cls (or a subclass) in the pass, started ones first (by phase, then in the order added), or null.
- `findAll`: Every behavior of class cls (or a subclass) in the pass, started ones first (by phase, then in the order added).
- `on`: The first behavior of class cls (or a subclass) on node, started ones first (by phase, then in the order added), or null: how a behavior given a node reference reaches the behavior on it.
- `allUnder`: Every behavior of class or interface cls on node or on a node under it, started ones first (by phase, then in the order added), then the pending: how a resolver gathers what has a say on an entity (BehaviorPass.allUnder).
- `add`: Puts behavior on node: it starts on the next update. False, changing nothing, for one already in a pass (this or another) or a null node.
- `remove`: Takes behavior out: stopped first if it had started. False when it isn't in this pass.
- `count`: How many it holds: started, or waiting for the next update to start.
- `of`: The behaviors on node, started ones first (by phase, then in the order added).
- `clear`: Takes every behavior out, stopping each started one (by phase, then in the order added).

## Phase

*abstract* in [`src/helix/behavior/Phase.hx`](../../src/helix/behavior/Phase.hx), `import helix.behavior.Phase;`

When in a frame a behavior runs: the BehaviorPass pass updates every behavior of one phase before any of the next, in this order, and within a phase in the order they were added (a scene file's order). A class says its phase with `@:phase(Late)` on the class; without it, Simulate, and a subclass has its base's. Fixed and few on purpose: a reader knows what a frame does from the class alone, and every target runs it alike (docs/DECISIONS.md 134).

- `Phase.Input`: First: reads the devices and decides intent (a player's controller, an AI's choice of what to do), moving nothing yet.
- `Phase.Simulate`: Moves the world: a car, a projectile, an AI acting on its intent. The phase of a behavior that doesn't say.
- `Phase.Resolve`: Settles what Simulate produced: checkpoints seeing where the car now is, combat applying the hits queued this frame, triggers.
- `Phase.Late`: Last: follows the settled world (cameras, HUD anchors, effects), changing nothing the others read.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.
