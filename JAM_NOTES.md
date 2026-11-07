# Jam notes (ATL Gamedevs Jam, 2026-10-23): what broke or was missing, for after

The full list is the game's: `gamejams/katawami/docs/issues/FRICTION.md` (each entry with its workaround and fix; everything
below is in it too, under "From HeliX's jam notes"). Work from that; these are the notes as they were taken.

- **`init .`**: let init write into the current directory (`haxelib run helix-legacy init .`), e.g. a freshly cloned
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
- **Doc comments are hard to read**: many are disjointed and unclear (the user, during the jam): long run-on sentences
  chained with colons, semicolons and parentheses, clauses dropped in out of order, terse nouns where a verb is meant
  (e.g. Stage.pick, Textures.load, Splash). Wanted: a pass over the shown API: lead with what it does in one plain
  sentence, then arguments, then what it returns, then the edge cases, in short sentences; an example where a call's
  shape isn't obvious. Write the style into CONVENTIONS, and let a cold-start reader judge a sample before and after.
  The user's example of what not to do: Splash's class doc as it is (src/helix/scene/Splash.hx). Below, a rewrite of it in the
  wanted style, the sample to follow (what it is, how to use it, what happens, why,
  the options):

      A splash screen: your logo, centered on the theme's background, before the game starts.

      Create one and call show(next). It stays up for at least `seconds`, and also until the player presses a key,
      clicks or taps, showing `prompt` ("press any key") meanwhile. Then it fades out (or uses the transition you
      gave) and calls next at the transition's middle; put your title screen on the stage there.

      Why wait for a press: a browser plays no sound and allows no fullscreen until the player has pressed something.
      A gamepad press doesn't count, because browsers ignore it for that.

      To go on without a press, set maxWait to a number of seconds. The splash runs itself; you don't update it.
- **Material3D's normal map doc mixes up two "linear"s**: `normalTexture` says "Load it linear (not sRGB), with
  mipmaps", and the class doc calls the map "linear". But a load can't choose a color space: Textures.load's linear is
  the filter (smooth with mipmaps), and a texture is uploaded as its bytes; the shader decodes the base color texture
  from sRGB and reads the normal map's bytes as directions. Say that: load it with Textures.load(path, true, ...) for
  smooth sampling; the map's colors are directions, not sRGB colors, and HeliX reads them so. Same fix as Loader.texture's
  doc; the Sampling enum for the Bool would end the confusion.
- **Statics and hot reload**: a static survives a reload only if marked `@:hot`, so a game keeping its state in statics
  lost it on each save, or had to mark everything. The user's way out: App a thin wrapper, a simple springboard (the user), the game a class of its own
  held in one `@:hot static`, App forwarding init/update to it; then nothing else needs marking. Consider: the starter
  (and GUIDE) showing it, or saying plainly "keep state in the game object's fields, not statics"; or the engine
  keeping a game object for you (App holding it). Check what the runner already keeps (hotApp migrates the App object).
- **Text2D has no vertical alignment**: `align` (Align2D: Left, Center, Right) places x only; y is always the top of
  the text. Centering it on a point means `y - text.measureHeight(font) / 2`, which needs the font in hand (null means
  the batch's built-in one). Text3D has setPivot(x, y) for both axes. Wanted: a vertical choice (top, middle, bottom,
  maybe baseline) on Text2D, or a pivot like Text3D's, one way for both kinds; the widgets' labels checked against it.
- **Text2D.measureWidth/measureHeight take a font**: they should measure with the text's own font (`font`, or the
  built-in one when null), no argument: `text.measureHeight()`. Today the caller passes one, and with font null has to
  find the built-in font itself. (Text3D the same, if it measures.)
- **A rolling ball (Katamari, Marble Madness) has little to stand on**: collision is 2D only (helix.collision); in 3D
  there's Ray3D against a plane or a height, and picks from a camera's pixel, but no ray or sphere against the world's
  meshes, no 3D body (velocity, gravity, friction, slopes), no 3D camera follow (CameraFollow2D only), no helper to
  turn a node by an axis and angle (setQuaternion only, the product by hand), and no reparenting that keeps a node
  where it is in the world (sticking things to the ball). Consider: Body3D/sphere against meshes or a height field,
  Node3D.turn(axisX, axisY, axisZ, angle), CameraFollow3D, addChild keeping the world transform.
- **Move HeliX's hotreload-hx pin to 5a7023f** (`dependencies.json`, now 58ed877). What it brings: hxml edits
  (a -lib or -cp added) built with while the server runs; `sidecars` (commands started and stopped with the server,
  e.g. an HTTPS proxy); a project-local `.haxelib/` no longer counted as the game's code, so HeliX's plain statics
  aren't restarted on every reload and its sources aren't watched; `hotreload: ready` once watching; one message style
  (`hotreload: <topic>: <state> (<details>)`); the first build's temp config out of the project root. Nothing in HeliX
  parses the old wording (checked 2026-10-24). After the bump: run the dev loop, the starter's tool tests and CI. Then
  see whether the statics note above still holds, since the restarted HeliX statics may have been part of it.
- **Check the starter's `watch.hotreload.hxml` against hotreload-hx's new options** (`--help`): whether `sidecars`
  belongs in it (commented out, an HTTPS proxy for testing on a phone over the LAN), whether a script waiting on the
  server should match `hotreload: ready`, and that the README's dev loop description matches the new messages.
