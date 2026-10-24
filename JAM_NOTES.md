# Jam notes (ATL Gamedevs Jam, 2026-10-23): what broke or was missing, for after

- **`init .`**: let init write into the current directory (`haxelib run helix init .`), e.g. a freshly cloned
  `gamejams-<name>` repo. Today it refuses any directory with something in it (a clone has `.git/`, maybe a README or
  LICENSE), and the game's name comes from the directory's path, which for `.` needs to be the current directory's
  name, not ".". Decide what existing files it tolerates (`.git/`, README/LICENSE/.gitignore: keep or merge?).
- **Collect3D**: a 3D counterpart of `helix.scene.Collect2D`. Today things collected fly only on the stage: from a 3D
  world, the burst starts at a View3D's project of the point and flies in 2D to a stage node. Wanted: the burst and the
  flight in the 3D world (Sprite3Ds, or models), to a 3D target node, with the same callbacks (each arrival, all
  arrived), running itself and taking itself off when done.
- **A log module**: HeliX has none; games and the engine use `trace`. Wanted: levels (debug, info, warn, error),
  a tag per source, a filter, output to the browser console (as console.warn/error) and natively to stderr, and
  development builds keeping more than release. Look at how wgrender-c logged first.
- **No way to find a child on the stage**: `Stage` has addChild, removeChild and childCount, but neither `find(name)` nor
  `getChild(index)`, which every node has (`Node.find`, depth first). Wanted: Stage.find and Stage.getChild, as a
  Node2D's, over the stage's own root (and check View2D's and View3D's trees have the same).
- **find needs a downcast**: `Std.downcast(root.find("greeting"), Text2D)` is awkward. Haxe 4 has no `find<Text2D>(...)`
  at a call site (no explicit type parameters on calls). Options: `find(name, ?kind:Class<T>):Null<T>`, checked
  (`root.find("greeting", Text2D)`, null when it isn't one), or a type parameter taken from the variable
  (`var g:Text2D = root.find("greeting")`), unchecked, which a wrong kind breaks later instead of there. Prefer the
  checked one; it fits the stage's find too.
- **Loader's methods read like properties**: `helix.scene.Loader`'s asset, texture, clip, stream, environment and model
  start loads but are named as things (`loader.texture(...)`), against CONVENTIONS (methods named for what they do)
  and the services (`Textures.load`, `Audio.loadClip`). Rename: loadAsset, loadTexture, loadClip, loadStream,
  loadEnvironment, loadModel, with every caller (examples, guide, the scene file's loading). `wrap` too: say what it
  wraps.
- **Textures.load's bare `true`, and Loader.texture's doc**: in `Textures.load(path, linear, ...)` linear is the
  filter (smooth with mipmaps; false is nearest, for pixel art), so the scenes example's `true` for the logo is right.
  But `Loader.texture`'s doc says linear means "not sRGB, for data such as normal maps": wrong, and the reason it looked
  wrong. A bare Bool at the call site says neither. Fix the doc; replace the Bool with what it chooses (the
  `Sampling` enum Texture2D already has, or a named option), so a call reads `Textures.load(path, Smooth, ...)`; check
  every texture load's doc says the same.
- **Loading and Splash name screens**: `helix.scene.Loading` is the built-in loading screen and `Splash` the splash
  screen, but the names read as a state (Loading) and a thing that isn't one (Splash), and Loading sits beside Loader,
  the asset counter it shows, one letter apart. Rename to LoadingScreen and SplashScreen (CONVENTIONS: classes named
  for their kind), every caller, the guide, DISPLAY_MODEL; consider helix.scene.screen for them, as the transitions
  have helix.scene.transition.
- **Transitions need finer control**: a Transition only runs whole (run: cover, atMiddle, uncover; swap). Missing:
  cover and stay (fade to black at the end, game over, before quitting), uncover alone (fade in from black at the
  start), and holding covered until the game says (a load under the cover) rather than a fixed hold. Wanted: cover(?done)
  and uncover(?done) as halves, run built from them, a covered state to read, and the color (black by default) easy to
  set. Check Closing, Fade and the wipes all work as halves.
- **Iris on the splash's logo**: Iris aims already (setPoint, from Closing), but Splash keeps where it drew its logo to
  itself, so there's nowhere to aim it. Wanted: Splash's logo place readable (logoX, logoY and its size, in the stage's
  units, or the logo node), so the splash's transition closes an iris onto its logo.
