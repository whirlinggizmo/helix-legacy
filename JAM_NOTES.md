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
