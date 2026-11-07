# HeliX

HeliX is a Haxe game framework. One Haxe program runs in the browser (Haxe → JS, WebGL2, Web Audio, Fetch, IndexedDB) and on the desktop (Haxe → hxcpp/C++, Sokol, libsndfile, evdev or XInput gamepads). Games use the same Haxe interfaces on both. Thin adapters supply each platform's services underneath them; a named profile picks the adapters for a build. Framework and game code have no target conditionals.

> **Work in progress: caveat emptor.** HeliX is not yet stable, and backward compatibility is not a consideration. Any API, name or file layout may change in any commit, with every caller in this repository changed alongside and no deprecation period. There are no releases or versions to pin yet. If you build on it, pin a commit and expect to update your code when you move.

**Status:** milestones 1–13 are done (the platform, 2D and services; 3D through skinning and animation; scene and pick; UI; Windows, macOS and CI; SDL3 as a second native profile, its graphics on GL or SDL_GPU (Vulkan, Direct3D 12, Metal); the small utilities; scenes and flow; the scene file and behaviors; input actions, audio buses and native streaming; the shader library, screen effects and the UI's widgets), and the API reworked in Haxe's own terms (properties, kinds as classes, services as static classes). Milestone 14, HeliX as a haxelib a game takes with `-lib helix-legacy`, is under way ([docs/ROADMAP.md](docs/ROADMAP.md)). Every example runs in the browser and natively on Linux/X11, and builds natively on Windows and macOS; on Windows both games have run in a window. macOS is built for in full; beyond CI's builds and unit tests, only CI's virtual Mac has run it (both games under SDL_GPU on Metal), not a real one; iOS waits for a Mac that can run it. CI checks all three. Mobile has not run.

## Try it

In the browser: **[the examples](https://whirlinggizmo.github.io/helix/)**, each running on WebGL2, and **[the API reference](https://whirlinggizmo.github.io/helix/api/)**.

A game of your own, with Haxe 4.3.7 and HeliX as a haxelib (BUILDING.md, "A game on `-lib helix-legacy`"):

```console
haxelib run helix-legacy init my-game && cd my-game
haxe hxml/dev.hxml                      # http://localhost:8064/, hot reload as you edit (hotreload-hx), shaders packed as they change
haxe hxml/build.dist.hxml               # the release build for hosting, out/dist/ and a zip for itch.io
```

HeliX's own examples, from a checkout, with Haxe 4.3.7 and Python 3 (the shader compiler is fetched the first time; the rest, and the native toolchain: [BUILDING.md](BUILDING.md)):

```console
python3 tools/example.py animation dev   # http://localhost:8060/, hot reload as you edit
python3 tools/example.py animation build release-sokol-gl         # out/linux-x64/release-sokol-gl/bin/animation/animation
```

## Documents

- [docs/DISPLAY_MODEL.md](docs/DISPLAY_MODEL.md): how a program shows things: the stage, nodes and their flags, views through cameras, a place's light, scene files, where logic lives, and a frame in order.
- [docs/GUIDE.md](docs/GUIDE.md): making a game, piece by piece: screens, sprites, input, sound, collisions, transitions, effects, Tiled maps, saving and shipping to itch.io, each a recipe with its imports.
- [GOALS.md](GOALS.md): what HeliX is for, why Haxe, and why a framework at all.
- [docs/benchmarks.md](docs/benchmarks.md): web sizes, measured: the feature cost ladder, and where the bytes are.
- [BUILDING.md](BUILDING.md): prerequisites and pins, building, the dev loop, the checks, the repository's layout.
- [docs/EXAMPLES.md](docs/EXAMPLES.md): every example, and the larger games (Asteroids, Blocks).
- [docs/ROADMAP.md](docs/ROADMAP.md): what comes next.
- [docs/HISTORY.md](docs/HISTORY.md): what was built, milestone by milestone.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md): the engine, the platform contracts and their adapters, and the rule for what an adapter may hold.
- [docs/INTERFACE.md](docs/INTERFACE.md): the contracts and their limits.
- [docs/SHADERS.md](docs/SHADERS.md): writing a game's own shader: the sprite, screen and surface kinds, what each block gives, parameters, colors and errors.
- [docs/SCENE_FILE.md](docs/SCENE_FILE.md): the `.scene3d` file's format, its loading and capture, and a behavior's shape.
- [docs/api/](docs/api/README.md): the API reference, a file a package, generated from the doc comments (the site's HTML is the same).
- [docs/CONVENTIONS.md](docs/CONVENTIONS.md): names, units, layout, and how examples are developed.
- [docs/DECISIONS.md](docs/DECISIONS.md): why things are the way they are, numbered, in order.
- [docs/API_FINDINGS.md](docs/API_FINDINGS.md): known API problems, fixed and open.
- [docs/PACKAGING.md](docs/PACKAGING.md): tooling, autopilot and the road to a haxelib.
- [docs/ADAPTER_AUDIT.md](docs/ADAPTER_AUDIT.md): the adapter audit of 2026-10-14, what it found and how each step landed.

## License

MIT: [LICENSE](LICENSE). Third-party code, fonts and assets keep their own licenses: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md); the examples' assets: [examples/assets/CREDITS.md](examples/assets/CREDITS.md).

HeliX began as experiment 05 of whirlinggizmo's framework architecture study. That study keeps its comparison and measurements; this repository carries HeliX's history from it ([docs/HISTORY.md](docs/HISTORY.md)).
