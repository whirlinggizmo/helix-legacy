# Making a game with HeliX

The pieces of a 2D game, each a recipe you can copy, with its imports. Every call here is from a game that was built and run to check
them. For everything a type can do, its page in the [API reference](api/README.md) (online: https://whirlinggizmo.github.io/helix/api/)
lists it; the reference prints each type's `import` line.

Start with `haxelib run helix init my-game` (README.md, "Try it"): `src/Game.hx` is the game, `haxe hxml/dev.hxml` runs it at
http://localhost:8064/ and takes your changes as you save, keeping the running game: what's on the stage, the fields' values (a new
field starts from its initializer). `init` ran when the page started, so a change to it shows after a refresh, or override
`afterReload`, which runs after each reload, to build what an edit added. Keep the game's state in `Game`'s fields: a plain static starts
over at each reload (one marked `@:hot` is kept).

## The shape of a game

```haxe
import helix.host.PresentationMode;
import helix.host.Screen;
import helix.host.Window;
import helix.render2d.Stage;

class Game extends helix.App {
	override public function init():Void {
		Window.title = "My Game";
		Stage.color = 0xff202840;                       // colors are 0xAARRGGBB
		Screen.set(PresentationMode.Fit, 800, 600);     // design for 800 x 600 units; the window shows them scaled, bars at the sides
	}

	override public function update(dt:Float):Void {
		// once a frame, dt seconds since the last (the frames' time, which a pause doesn't stop: below)
	}
}
```

- **Make things in `init`, not in field initializers**, when they use HeliX: a field's `= new ...` runs before HeliX's services
  exist. Plain values and nodes are fine as fields; `Actions`, textures, sounds are made in `init` (an `Actions` made as a field
  never sees a key).
- **Time:** `dt` is the frames' time and keeps running. `Time.clock.delta` (`import helix.time.Time;`) is the game's: 0 while paused,
  which it is while the window is in the background (`AppOptions.pauseOnBlur`, on unless set off) or when the game says
  (`Time.clock.pause()`, `resume()`; `Time.clock.timeScale = .5` for slow motion). Move the game, its timers and tweens by
  `Time.clock.delta`, so they stop together; a pause menu's own animation by `dt`.
- **What runs itself, and what you update:** particles, decals' fading, Tiled's animated tiles, transitions, `Collect2D` and the
  `FullscreenButton2D` run by themselves once on the stage or started. A `SpriteAnimator2D`, `Tweens`, `Timers`, a `CameraFollow2D`
  (`update` then `apply`), an `FpsOverlay` and a `Ui` you update in `update`, each once a frame. Forgetting one compiles and does nothing.
- **Units:** positions in the design's units (`Screen.set`'s), from the top left, y down; angles in radians, clockwise; times in seconds.
- **What's on the stage is drawn after each `update`.** Nothing is drawn by hand: add nodes (`Stage.addChild`) and change them.
- `PresentationMode`: `Fit` (bars to keep the shape), `Expand` (shows more past the design on one axis), `Fill` (crops), `Stretch`,
  `Integer` (whole-number scale, pixel art), `None` (one unit a logical pixel, the window's size). Values of every enum are listed in the reference (`Key`, `PadButton`, ...).

## Things on screen

```haxe
import helix.render2d.Align2D;
import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.Sprite2D;
import helix.render2d.Text2D;
import helix.texture.Textures;

var box = Shape2D.rectangle(120, 40, 0xff66bfff);   // also Shape2D.circle(r, color), line, polygon
box.setPosition(40, 40);
Stage.addChild(box);

var label = new Text2D("Score: 0", 24, 0xffffffff, Align2D.Center);
label.setPosition(400, 30);
Stage.addChild(label);
label.text = "Score: 1";                              // change it any time

Textures.load("player.png", false, texture -> {      // false: sharp (pixel art); true: smooth
	var player = new Sprite2D(texture);              // centered on its position (setPivot to change)
	player.setPosition(400, 300);
	player.rotation = Math.PI / 4;
	player.setScale(2, 2);
	player.alpha = .8;
	Stage.addChild(player);
});
```

- Files load from `assets/` by their path in it (`assets/player.png` is `"player.png"`). Loads finish later: the callback runs when
  it's there, so keep a `Null<...>` field and check it before use.
- **Draw order is add order:** a node added later is drawn over. `addChild` of one already there moves it to the top.
- **Groups:** a `Node2D` holds others; move, scale, fade (`alpha`), hide (`visible = false`), freeze (`paused`), make unclickable (`pickable = false`) or remove the group and its children follow. Something that should differ from its parent goes beside it under a group instead. A clickable area that isn't drawn is a `Node2D` with a `hitArea` (`HitArea2D.rectangle(x, y, width, height)`).
- **Layers:** make empty `Node2D` layers first (ground, things, HUD) and add into them, so what loads late doesn't land over everything.
- `removeChild(node)` takes it off. `Sprite2D.tint` colors it.

## Animation from a sprite sheet

```haxe
import helix.render2d.SpriteAnimator2D;
import helix.render2d.SpriteSheet2D;

Textures.load("hero.png", false, texture -> {
	var sheet = SpriteSheet2D.grid(texture, 16, 16);  // cells of 16 x 16 texels, numbered 0.. left to right, then down
	sheet.addAnimation("walk", [0, 1, 2, 3]);
	var sprite = new Sprite2D(sheet.texture);
	looks = new SpriteAnimator2D(sheet, sprite);      // a field: looks.update(dt) every frame
	looks.play("walk");
	things.addChild(sprite);
});
```

`SpriteSheet2D.load("hero.json", sheet -> ...)` reads a TexturePacker or Aseprite JSON (with its image beside it) and its animations.

## Input

```haxe
import helix.input.Input;
import helix.input.Key;

if (Input.isDown(Key.Left)) x -= 200 * dt;                 // held
if (Input.isFramePressed(Key.Space)) jump();               // pressed this frame
if (Input.pointerFramePressed) click(Input.pointerX, Input.pointerY);   // mouse or finger, in framebuffer pixels
```

Actions name what the player does and bind keys and pads to it, so `update` reads one name:

```haxe
import helix.input.Actions;
import helix.input.Binding;
import helix.input.PadAxis;
import helix.input.PadButton;

actions = new Actions();                                    // in init
actions.bind("moveX", KeyboardPair(Key.Left, Key.Right));   // -1 .. 1
actions.bind("moveX", KeyboardPair(Key.A, Key.D));
actions.bind("moveX", Axis(PadAxis.LeftX, 0, .2));          // the stick, its dead zone .2
actions.bind("fire", Keyboard(Key.Space));
actions.bind("fire", Mouse(MouseButton.Left));               // import helix.input.MouseButton;
actions.bind("fire", Pad(PadButton.South));

x += actions.axis("moveX") * 200 * dt;
if (actions.isFramePressed("fire")) fire();
```

- In `update`, use **`isFramePressed`** for "pressed": it's this frame's. `isPressed` and `Input.consume()` are for a fixed-step
  simulation (`helix.time.Ticker`, which calls `consume` itself); a game without one never calls `consume`.
- Key names: `Key`'s page (`A`..`Z`, `Digit0`..`Digit9`, `Left`, `Up`, `Space`, `Enter`, `Escape`, `Shift`, ...). Pad buttons
  are named by place (`South` is Xbox A / PlayStation cross).
- **In a browser the page needs a click before keys reach it** (on itch.io too): say "click to start" on the title.

## Sound and music

```haxe
import helix.audio.Audio;
import helix.audio.AudioClip;

Audio.loadClip("coin.wav", clip -> coinSound = clip);           // a short sound, whole in memory
if (coinSound != null) Audio.play(coinSound);                    // or Audio.play(sound, loop, volume)
Audio.loadStream("music.ogg", music -> Audio.music.play(music, true, .5));   // long music, streamed, looping
Audio.music.volume = .3;  Audio.effects.muted = true;           // buses: master, music, effects
```

WAV (any rate, mono or stereo), Ogg (Vorbis, Opus) and MP3. A clip is at most about 47 seconds; music goes through `loadStream`.
Browsers start sound only after the player's first click or key.

## Collisions

```haxe
import helix.collision.Collide2D;

if (Collide2D.circleCircle(px, py, 12, cx, cy, 8)) collect();
if (Collide2D.rectRect(ax, ay, aw, ah, bx, by, bw, bh)) hit();
```

Also `rectCircle`, `pointInRect`, `pointInCircle`, `polygonPolygon`, rays and sweeps. For a platformer on tiles, `helix.collision.Body2D`
(gravity, `step(dt, tileSize, solid)`, `grounded`) and `Collide2D.moveAndSlide`.

## Timers, tweens, random

```haxe
import helix.math.Random;
import helix.time.Timers;
import helix.tween.Ease;
import helix.tween.Tweens;

var timers = new Timers();       // fields; then timers.update(Time.clock.delta) and tweens.update(Time.clock.delta) in update
var tweens = new Tweens();
var random = new Random(42);     // a seed: the same numbers each run

timers.after(2, () -> spawnBoss());
timers.every(.5, () -> spawnCoin());
tweens.to(0, 300, 1, t -> Ease.backOut(t), v -> box.x = v);   // from, to, seconds, ease, each value
random.nextInt(6) + 1;  random.nextRange(-1, 1);  random.pick(items);  random.nextBool(.25);
```

Write a function you pass as a **lambda** (`t -> Ease.backOut(t)`, `() -> spawnBoss()`), not by name (`Ease.backOut`): the dev
loop's hot reload reaches code called from a lambda, and keeps the old code of one passed by name.

## Screens and transitions

A screen is a `Node2D`; one is on the stage at a time.

```haxe
import helix.scene.transition.Fade;

var title = new Node2D();
var playing = new Node2D();

new Fade(.6).run(() -> {          // at the middle, covered: swap what's shown
	Stage.removeChild(title);
	Stage.addChild(playing);
	Stage.addChild(fullscreen);   // keep what goes over every screen on top
}, () -> started = true);         // at the end
```

`update` keeps running through a transition: what `atMiddle` sets is live from the next frame, before `done` runs, so start a round in
one of them, not both. `new Fade(.6).swap(title, playing)` does the remove and add for you, but puts `playing` over what was on top
(the fullscreen button); `run` with the re-add keeps it there. Other transitions in `helix.scene.transition`: `Slide`
(`new Slide(.5, SlideDirection.Right)`), `Iris`, `Diamond`, `Noise`; each takes `delay`, `hold`, `coverSeconds`, `uncoverSeconds`, `coverEase` and
`uncoverEase`.

## Effects

```haxe
import helix.render2d.Decals2D;
import helix.render2d.Particles2D;

var burst = Particles2D.explosion(24);      // also smokePuff, sparks, dust, confetti (once); fire, smoke, rain, snow (steady)
burst.setPosition(x, y);
things.addChild(burst);                     // a one-shot takes itself off once it's done (removeWhenSpent)

var torch = Particles2D.fire(16);           // a steady one runs until you remove it
torch.setPosition(100, 200);
things.addChild(torch);

var marks = new Decals2D(texture, 32);      // marks left behind (scorch, footprints): the oldest reused past 32
ground.addChild(marks);
marks.place(x, y, angle, 16);
marks.lifeSeconds = 5;  marks.fadeSeconds = 1;
```

`helix.scene.Collect2D` flies sprites from a point to a node (coins to the score); a `CameraFollow2D`'s `follow.shake(.5)` shakes the
view it follows with (below).

## A scrolling world

The stage shows the design area; a world bigger than it goes in a `View2D` whose camera moves:

```haxe
import helix.render2d.Camera2D;
import helix.render2d.CameraFollow2D;
import helix.render2d.View2D;

var world = new Node2D();          // fields
var camera = new Camera2D();
var follow = new CameraFollow2D();

Stage.addChild(new View2D(world, camera));   // in init; the HUD after it, on the stage, stays put

// in update:
camera.zoom = Screen.scaleX;                  // one world unit a design unit: a camera's zoom is framebuffer pixels a unit,
camera.zoomY = Screen.scaleY;                 // and Screen's scale is how many the design's units take
follow.update(heroX, heroY, dt, camera);      // follow.setBounds(0, 0, worldWidth, worldHeight) keeps the edges in
follow.apply(camera);
var worldX = camera.screenToWorldX(Input.pointerX);   // a click, in the world (bars and all), from the view's first frame
// what's in view: follow.x - Screen.width / 2 .. follow.x + Screen.width / 2 (and y by height): spawn just past it
```

## Maps from Tiled

```haxe
import helix.tiled.TiledMap2D;

TiledMap2D.load("level.tmj", map -> {           // Tiled's JSON map (.tmj), tilesets embedded or .tsj beside it
	var level = map.instantiate(ground);        // its layers as sprites, under ground
	for (spawn in level.getObjects("enemy"))    // an object layer's objects by class
		addEnemy(spawn.x, spawn.y);
	var walls = level.getTileLayer("walls");
	if (walls != null && walls.isFilled(walls.columnAt(x), walls.rowAt(y))) blocked();
});
```

Objects have `name`, `className`, `x`, `y`, `width`, `height` and `properties` (`getString`, `getFloat`, ...). Animated tiles play by
themselves; `setTile` changes a cell.

## Saving

```haxe
import helix.asset.Saves;

Saves.write("best", Std.string(best));
Saves.read("best", text -> best = Std.parseInt(text) ?? 0, () -> best = 0);   // the second: nothing saved yet
```

Text under a name, kept across runs (a browser keeps it for the page's site). For more than a number, `haxe.Json.stringify` and `parse`.
A Tiled layer the game changed (`setTile`, `setTerrain`) is saved and put back whole:

```haxe
Saves.write("level1-land", haxe.Json.stringify(land.getTiles()));
Saves.read("level1-land", text -> land.setTiles(haxe.Json.parse(text)));   // after instantiate
```

## Building and shipping

```console
haxe hxml/dev.hxml            # develop: http://localhost:8064/, changes taken as you save
haxe hxml/build.dist.hxml     # release: out/dist/ and out/<name>-web.zip
haxe hxml/serve.dist.hxml     # try the release at http://localhost:8095/
```

On itch.io: a new project, Kind of project **HTML**, upload the zip, check **This file will be played in the browser**, set the
viewport to your design size (800 x 600 here), and tick the fullscreen button if you like (the starter has its own,
`helix.ui.FullscreenButton2D`). Click the game before pressing keys.

## When something's wrong

- **Nothing happens on a key:** the page hasn't been clicked; or the `Actions` was made in a field, not in `init`.
- **Something's missing on screen:** it's under something added later (layers), off the design area, or its load failed (the console
  says; pass a `failed` callback to see it: `Textures.load(path, false, loaded, message -> trace(message))`).
- **"Type not found":** import it by the line its reference page gives.
- **A change didn't take in the dev loop:** a change to `init` shows after a refresh (it ran when the page started), or build it in
  `afterReload`. A static lost its value: a plain one starts over at each reload; keep it in a field, or mark it `@:hot`. A function passed
  by name keeps its old code; pass a lambda. A field's initializer runs once, for a new field too: a changed one shows after a refresh,
  or set it again in code.
