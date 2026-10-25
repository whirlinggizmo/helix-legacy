# The display model

How a HeliX program shows things: one stage, drawn every frame, holding trees of nodes; views showing trees through cameras; logic in
the app's update, never on what's drawn. It reads much like Flash's display list. Every type named here has its page in the
[API reference](api/README.md); [GUIDE.md](GUIDE.md) builds a game with it, piece by piece.

## The pieces

### `App`: the program

A game extends `helix.App` and overrides `init()` (once, with HeliX's services bound), `update(dt)` (once a frame, the game's logic)
and `cleanup()` (once, as the window closes). It draws nothing itself: after `update`, the runner draws the stage.

### `Stage`: what's drawn

- `Stage` is the root of everything shown: `Stage.addChild(node)`, `Stage.removeChild(node)`. Its children draw in the order added, a
  later one over an earlier; `addChild` of one already there moves it to the top.
- `Stage.color` is what the frame is cleared to. `Stage.camera` shows the design's units on the window as `Screen.set` fits them; the
  stage refits it each frame, so a game doesn't move it (a scrolling world is a view, below).
- `Stage.postProcess` runs screen effects (`helix.graphics.PostProcess`) over everything drawn.

### Nodes

- `Node2D` is a 2D display object and a container: `addChild`, `removeChild`, `x`, `y`, `rotation` (radians, clockwise), `scaleX`,
  `scaleY`, `alpha` (fading it and everything under it), `name`. Its children move, turn and scale with it.
- 2D kinds: `Sprite2D` (an image, or a frame of a sprite sheet), `Shape2D` (rectangles, circles, lines, polygons), `Text2D`,
  `Drawing2D` (drawing calls: `rect`, `circle`, `line`, `polygon`, `image`, `drawText`, ...; `clear()` and drawing again each `update` is
  drawing by hand), `Particles2D`, `Decals2D`.
- `Node3D` is a 3D node and container, with the 3D kinds under it: `Model3D`, lights, `Sprite3D`, `Text3D`, `Particles3D`.
- A node's own class is never subclassed for game logic: a node is what's drawn, and the game's state lives in the game.

### Flags every node has (`helix.scene.Node`)

Each reaches the node and everything under it; a child's own is kept, so turning one back brings each child back as it was set.

| Flag | Off (or on, for `paused`) |
|---|---|
| `visible` | Not drawn and not picked (a light doesn't shine); it still runs: behaviors update, emitters move on. |
| `paused` | Frozen: behaviors don't update and what moves by itself holds still; still drawn and picked. |
| `pickable` | A pick passes through to what's behind. |

`alpha` (2D) fades it and everything under it, multiplied down the tree; a transparent node is still picked. A node is picked by what it
draws, or by its `hitArea` (`HitArea2D`, `HitArea3D`) in place of that: a shape never drawn, so a bare group with one is a hotspot. A
node that should differ from its parent (a trigger beside its door, a ship's body beside its flame) is a sibling under a group.

UI widgets (`helix.ui`) aren't nodes and have their own: `visible`, `enabled` (off: drawn dimmed, does nothing, still takes the click so it
doesn't reach what's behind) and `interactive` (off: looks the same, takes no input of any kind, the pointer passes through), each reaching
the widgets in a panel.

### Views: a tree through a camera

- `View2D(content, camera)` and `View3D(content, camera)` are 2D display objects showing a tree's children through a camera, in a
  rectangle (`width` x `height`, or 0 for the whole area of what shows them). They're placed like any node: on the stage, or inside a 2D
  tree another view shows (a minimap in a panel). A view is never drawn inside the tree it shows; one that would be is skipped and logged.
- A scrolling 2D world is a `View2D` whose camera the game moves (`Camera2D.setPosition`, `zoom`; `CameraFollow2D` follows and shakes).
  What's added to the stage after the view (a HUD) stays put over it.
- One tree can be shown by several views (split screen, a minimap): each draws it for itself.
- A `View3D` holds how its tree is photographed: its `camera`, `exposure` and `tonemap`. It lights the tree by its own `environment` if
  set, else by the first `Node3D.environment` in its tree.
- `View3D` content draws under all 2D in the frame. A view with a `postProcess` chain (`View.postProcess`) is drawn into a texture first,
  its effects run over it, and the result drawn in the 2D order like any 2D thing, so a 3D view with a chain can sit between 2D things.
- `View3D.computeRay(x, y)` and `project(x, y, z)` turn between the stage's units and the 3D world.

### `Environment3D`: a place's light

Data, not a node: the ambient light, the environment map that lights and reflects, and the background drawn behind. Set as a 3D node's
`environment` (a level's root carries its level's; a scene file's `environment` section sets it), or as a `View3D`'s, which overrides
what it shows.

### Scene files: trees, saved

A `.scene3d` file is a saved tree of 3D nodes ([SCENE_FILE.md](SCENE_FILE.md)). `SceneFiles3D.load(path, loaded)` reads it;
`instantiate(parent)` puts a copy under a node, as often as wanted: a level is one put under what a view shows, a prefab one put
inside another tree. Its behaviors start with it. 2D maps come from Tiled (`helix.tiled`).

### Logic: in the app and in behaviors

- Nodes have no update, no events and no listeners. Logic lives in `App.update`, or in behaviors (`helix.behavior.Behavior`) that scene
  files and code attach to nodes; the runner runs the behaviors on the stage's trees each frame, skipping paused and disabled subtrees.
- Some things advance on the game's clock by themselves once they're on the stage or started: particles, decals' fading, Tiled's animated
  tiles, transitions, `Collect2D` and `Collect3D`, the `FullscreenButton2D`. Others the game moves in `update`: `SpriteAnimator2D.update`,
  `Tweens.update`, `Timers.update`, `CameraFollow2D.update` and `apply`, `Ui.update` (GUIDE.md says which with each).

### Screens

A screen is what's on the stage: a game swaps screens by removing one node and adding another, and pauses by setting `paused` on its
level and adding a menu over it (the level's `pickable` off too, or the menu covering it, so clicks don't reach it). `helix.scene.transition` (`Fade`, `Slide`, `Iris`, `Diamond`, `Noise`) covers the swap; `SplashScreen` and
`LoadingScreen` are ready-made screens.

### Input: asked, not delivered

- `Input` (keys, the pointer, pads, touches) and `Actions` (names bound to them) are read where logic runs.
- `Pointer` picks what's under the pointer through the stage and the views on it, topmost first, so a HUD over the world takes a click
  before the world does; a press on a 2D node captures the pointer until it's released.
- `Input.claim(key)` takes a key for the rest of the frame: the UI, reading first, claims what it uses, so typing a space in a text field
  doesn't make the player jump.

### Units

Radians, seconds, colors `0xAARRGGBB`; on the stage, the design's units (`Screen.set`; logical pixels with none); in a view, its camera's
world units.

## A frame

1. Input is polled; the game clock (`Time.clock`) moves on, unless paused.
2. `App.update(dt)`; then the behaviors on the stage's trees.
3. Each `View3D` about to draw draws its shadow maps; each view with a post-processing chain draws into its texture.
4. The frame is cleared to `Stage.color`, and the stage draws: every `View3D` without a chain first, then all 2D in display order (views
   with a chain in place).
5. The stage's post-processing, if any; the frame is shown.

## Examples

The smallest game:

```haxe
import helix.render2d.Shape2D;
import helix.render2d.Stage;

class Game extends helix.App {
	var ball = Shape2D.circle(20, 0xff66bfff);

	override public function init():Void {
		Stage.addChild(ball);
	}

	override public function update(dt:Float):Void {
		ball.x += 100 * dt;
	}
}
```

A 3D level with a HUD and a pause menu:

```haxe
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Node2D;
import helix.render2d.Stage;
import helix.render2d.Text2D;
import helix.render3d.Camera3D;
import helix.render3d.Node3D;
import helix.render3d.View3D;
import helix.scene.SceneFiles3D;

class Game extends helix.App {
	var level = new Node3D();
	var score = new Text2D("0", 24, 0xffffffff);
	var menu = new Node2D();
	var paused = false;

	override public function init():Void {
		Stage.color = 0xff14161c;
		Stage.addChild(new View3D(level, new Camera3D()));
		Stage.addChild(score);                                 // over the 3D, in the stage's units
		SceneFiles3D.load("levels/track.scene3d", file -> file.instantiate(level));   // its root's environment lights it
	}

	override public function update(dt:Float):Void {
		if (Input.isFramePressed(Key.Escape)) {
			paused = !paused;
			level.paused = paused;                             // behaviors and particles hold still; still drawn
			if (paused)
				Stage.addChild(menu);
			else
				Stage.removeChild(menu);
		}
	}
}
```
