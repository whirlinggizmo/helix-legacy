# Building HeliX

How to build, run and check HeliX and its examples. What HeliX is: [README.md](README.md); the examples: [docs/EXAMPLES.md](docs/EXAMPLES.md).

## Prerequisites

Executed on Linux, Windows 11 and macOS (CI's runners, and a Windows machine: decisions 99–101):
- **Haxe 4.3.7.**
- **hxcpp 4.3.2.** Installed on the first native build into the repository's own `build/haxelib`, so the global haxelib is untouched. `tools/pins.py` stops a native build that would resolve another version.
- **Python 3.12** with PyYAML (`python3 -m pip install -r requirements-build.txt`).
- **FFmpeg** with the libvorbis and libopus encoders, only to make Asteroids' sounds or the test fixtures anew (both are committed).
- **Node 26**, with Terser, Playwright and pngjs for release builds and browser checks:
  ```console
  npm install --prefix build/tools terser@5.44.1 playwright@1.64.0 pngjs@7.0.0
  ```
- **The dev loop:** [hotreload-hx](https://github.com/whirlinggizmo/hotreload-hx) at `c5ed8cd` or later, pinned in `dependencies.json` (`hotreloadHx`: `DevServer.serve` from an hxml's macro, its port from `-D hotreload-port`, and `restart`, which the starter's `hxml/dev.hxml` uses; a static survives a reload only if it says `@:hot`, on both targets) (`haxelib git hotreload-hx https://github.com/whirlinggizmo/hotreload-hx`).
- **The shader compiler:** `sokol-shdc` from sokol-tools-bin `11d0cf678105d614d675e6d9bd2aaf3eeff12f8c`. `src/helix/tool/shader/Shdc.hx` downloads it for this system into the user's cache the first time (`~/.cache/helix/tools`, `~/Library/Caches/helix/tools` or `%LOCALAPPDATA%\helix\tools`), checks its SHA-256 as it arrives and records it there (hashing it again each use would take seconds in Haxe's interpreter); nothing is installed globally. `HELIX_SHDC` names a sokol-shdc of your own instead (a machine without a network; its version is then yours to keep right).
- **SDL_GPU's shader translators:** glslang 16.6.0 (its official release for the system: Linux x86_64, Windows x64, macOS universal) and SPIRV-Cross `vulkan-sdk-1.4.363.0` (its source, built once by hxcpp with the system's compiler, as it publishes no programs), pinned in `dependencies.json` (`gpuShaders`), fetched into the same cache and hash-checked by `src/helix/tool/shader/GpuShaders.hx` the first time SDL_GPU's dialects are made. Only SDL_GPU builds (`sdl3-gpu`) run them; other builds, the browser's included, never fetch or build them. There's no Linux arm64 glslang release. `HELIX_GLSLANG` and `HELIX_SPIRV_CROSS` name programs of your own instead; without hxcpp, SPIRV-Cross's build is refused before anything is fetched.
- **Native builds:** no CMake: hxcpp compiles the adapters' C with each app, from the build XML on each adapter's extern bridge (`internal/*Bridge.hx`).
  - Linux: GCC/G++ 13 and ALSA headers; X11/Xrandr/Xi/Xcursor and GL libraries; the libsndfile 1.2.2 runtime with Vorbis/Opus and mpg123 (MP3). Its header is vendored.
  - Windows: Visual Studio's C++ tools (MSVC, which hxcpp finds itself; MinGW isn't supported). libsndfile's official 1.2.2 win64 release is downloaded and hash-checked into the user's cache, and its DLL copied beside each program.
  - macOS: Xcode's command-line tools and Homebrew's `libsndfile` (for FFmpeg, if ever, Homebrew's `ffmpeg-full`: its `ffmpeg` has no Vorbis encoder). Apple silicon builds arm64.
  - **The SDL3 backends** (`sdl3-gl`, sokol_gfx drawing GL in SDL's window; `sdl3-gpu`, SDL_GPU on Vulkan, Direct3D 12 or Metal): SDL 3.4.18, found or fetched by `tools/sdl3.py` into `build/deps` on its first build. On Linux, the system's SDL3 when pkg-config finds 3.4.18 or newer; else the pinned source release, checked and built once with **CMake** (needed for that build alone) against the X11, Wayland and audio development headers it finds. Missing CMake, or headers enough to open a window, it stops and prints the install command (Debian/Ubuntu's, CI's list; Fedora's, after SDL's `docs/README-linux.md`); missing only optional parts (Wayland, PipeWire, PulseAudio), it builds and says which, and what would add them. On Windows and macOS, SDL's official release, checked, its DLL or framework copied beside each program. The headers are vendored (`vendor/sdl3`).
  - `python3 tools/remote_windows.py HOST` builds and checks this checkout on a Windows machine over ssh; `--desktop` runs in its logged-in session, where windows can open.
- **Pinned in `vendor/`, hashes in `dependencies.json`:**
  - the Sokol headers, from the Whirling Gizmo fork [whirlinggizmo/sokol](https://github.com/whirlinggizmo/sokol) at `c237609` (upstream to `5e94d12`)
  - [whirlinggizmo/sokol_utils](https://github.com/whirlinggizmo/sokol_utils) at `8e85d19` (window position, size, displays, style and visibility)
  - stb_image
  - SDL 3.4.18's headers (`vendor/sdl3`)
  - JetBrains Mono, baked into the built-in distance-field font by `tools/bake_fonts.py` (HeliX's own TrueType reader and baker, under the Haxe interpreter)

Third-party licenses, and what builds ship with: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Example asset credits: [examples/assets/CREDITS.md](examples/assets/CREDITS.md).

## A game on `-lib helix`

A game anywhere on disk takes HeliX as a haxelib (`haxelib dev helix /path/to/helix`, or `haxelib git helix https://github.com/whirlinggizmo/helix`) and names it in its hxml with `-lib helix`. `haxelib.json` declares no dependencies, so installing the library pulls nothing else; a game installs what its own builds use:

- **Haxe 4.3.7** for a browser build, and nothing else: the generated code a build needs (the framework's programs, the shader library packed, the built-in font) is in the library (`generated/`, below).
- **hxcpp 4.3.2** (the version `dependencies.json` pins) for a native build, with the system's compiler and libraries listed above (Linux: GCC, X11, GL, ALSA, libsndfile).
- **hotreload-hx** for the dev loop: its DevServer serves the browser build with hot reload (`hxml/dev.hxml`, below).
- Nothing more for its build steps and `haxelib run helix` (below): they are Haxe, run in the compiler or Haxe's interpreter. Packing shaders fetches sokol-shdc the first time, and for SDL_GPU glslang and SPIRV-Cross (built once by hxcpp); `haxelib run helix setup` does it ahead; the framework's shaders are packed already.

`-lib helix` adds `src/` to the class path and runs `extraParams.hxml`, one line, `--macro helix.macro.Haxelib.configure()`: it adds the generated code's class paths (`generated/shaders`, `generated/fonts`, and for an `sdl3-gpu` build `generated/shaders-sdlgpu`, SDL_GPU's dialects, defining `helix_sdl3_gpu`, which the programs carry them under) and, natively, hxcpp's architecture define for the machine building (`HXCPP_M64`, or `HXCPP_ARM64` on arm64) when the build sets none (hxcpp picks 32-bit on Windows by itself). The game's hxml holds only what's its own: its class paths, `-main`, `-D helix-backend=<backend>` (the profile `helix.App` runs: `webgl2`, `sokol-gl`, `sdl3-gl` or `sdl3-gpu`), the target and its choices, `-dce full -D analyzer-optimize` for a release and `-debug` to find faults, natively `-D HXCPP_COMPILE_THREADS=4` to compile faster. The hello game that dogfoods the library builds from these, the starter's layout (`haxelib run helix init`): the builds in `hxml/`, each run from the game's directory as `haxe hxml/<file>.hxml` (the paths in an hxml are read from the directory haxe runs in, not the hxml's), what they share in `common.hxml`:

```hxml
# hxml/common.hxml: what every build shares
-lib helix
-cp src
-main Main
--macro helix.tool.Build.packShaders()
```

```hxml
# hxml/web.hxml: the browser build's settings, without where it's written
hxml/common.hxml
-D helix-backend=webgl2
-debug
```

```hxml
# hxml/build.web.hxml: the browser build for development -> out/web/app.js, the page beside it
hxml/web.hxml
-js out/web/app.js
```

```hxml
# hxml/build.native.hxml -> out/native/Main; hxcpp compiles HeliX's adapters' C with it
hxml/common.hxml
-D helix-backend=sokol-gl
-dce full
-D analyzer-optimize
-cpp out/native
```

```hxml
# hxml/build.dist.hxml: the release build made ready to host in out/dist/, zipped
hxml/common.hxml
-D helix-backend=webgl2
-dce full
-D analyzer-optimize
-js out/dist/app.js
--macro helix.tool.Build.cleanOutput()
--macro helix.tool.Build.generateWebPage()
--macro helix.tool.Build.copyAssets()
--macro helix.tool.Build.zipOutput("out/my-game-web.zip")
```

The starter's other two are run rather than built: `hxml/dev.hxml`, the dev loop (below), and `hxml/serve.dist.hxml`, `out/dist/` served on this machine to try before uploading.


- **The page.** `templates/index.html` is the page a browser build runs in, the one the examples are served from and the one `helix.tool.Build.generateWebPage` writes beside a build: `{{title}}` is the game's name and `{{meta}}` nothing, or `<meta name="helix-config" content="config.json">` when a `config.json` sits beside the page (`Config`, decision 131). What the framework needs of a page: a `<canvas id="canvas">` to draw in (the template sizes it to the viewport, focusable for the keyboard), a `<div id="status">` for its messages (a lost context, a failed start), and `app.js` loaded after them. A browser build on `-lib helix` writes it beside its `-js` output when no `index.html` is there (one there is the game's and kept; not for `--no-output` or an editor's completion), so the dev loop's server has a page to serve. The template links its icon, `favicon.svg` beside the page: the game's own (the starter carries the Whirling Gizmo logo there, `templates/starter/favicon.svg`, for the game to replace), or the library's when the game has none; the build puts it beside the page. Every path in it is relative, so the site runs from any directory of a host (itch.io serves a game under a path of its own; checked under one in headless Chrome, the assets fetched relative to the page).
- **Assets.** A game keeps its files in one directory beside what it ships and names it in `AppOptions.assets`, or takes the default: in the browser `assets/` beside `index.html` (fetched relative to the page; a manifest there, `tools/gen_manifest.py`'s, named in `AppOptions.manifest`, lets the asset cache follow changes; a game naming none needs none), natively `assets` beside the program (the profiles resolve the directory relative to the program, not the working directory). `Build.copyAssets` copies the directory beside the page or the program (`build.dist.hxml` beside the page; a native distribution beside its copied program); a native build run where hxcpp wrote it reads `assets` beside `out/native/Main`, so a copy (or a link) of the directory goes there. Nothing is packed into the program. The repository's examples share one directory beside their own (`../assets`), which is `tools/example.py`'s doing, not the library's.
- **The generated code**, `generated/`, is committed and shipped: `generated/shaders` holds the framework's programs (`<Name>Program.hx`, sokol-shdc's output of `src/helix/graphics/shaders` as data) and the shader library packed (`<Name>Packed.hx` and `PackedShaders.hx`, from `src/helix/shader`), `generated/shaders-sdlgpu` their SDL_GPU dialects (on the class path of `sdl3-gpu` builds alone, 2.7 MB no other build carries), `generated/fonts` the built-in font (`GeneratedFont.hx`, JetBrains Mono baked by `tools/bake_fonts.py`). `tools/gen_code.py` remakes what's older than its source, and every build path and the dev loop call it, so an edited shader is current when it compiles; `--regenerate` remakes all of it, `--check` fails when the committed code isn't what the sources give now (the first thing `helix.py test` does, so CI refuses a stale commit). sokol-shdc, glslang and SPIRV-Cross are the generators' (fetched by the tools); a game needs none of them.

### Build steps: `helix.tool`

A build's steps are macros an hxml lists (`--macro helix.tool.<Class>.<step>(...)`), run by the compiler from the game's directory, so a build needs nothing but Haxe. A step's directory, when it takes one, is relative to the game's and defaults to the build's output directory (the `-js` file's, natively the `-cpp` one); a step that fails ends the build with its message. The API reference has each in full.

- **`Build`**, the steps of a build, run once it has written its output, in the order listed (`packShaders` before it compiles):
  - `packShaders(?directory)` packs `shaders/<name>.glsl` into `assets/shaders/<name>.hxshader`, which the game loads as `shaders.load("shaders/<name>.hxshader", ...)` (`helix.graphics.Shaders`), as the examples' are packed (how a shader is written: [docs/SHADERS.md](docs/SHADERS.md)); each only when its source is newer, with SDL_GPU's dialects when the build names the `sdl3-gpu` backend; nothing without a `shaders/` directory. When the assets carry manifests (`tools/gen_manifest.py`'s `manifest.json`, which a game names in `AppOptions.manifest` for the browser's asset cache), they're rewritten from their root down to the shaders' directory (each other directory's kept), as `tools/gen_manifest.py` writes them.
  - `cleanOutput(?directory)` removes everything in the browser build's output directory but the JavaScript just written; it refuses a native build's (`-cpp` is hxcpp's working directory) and one holding the game.
  - `generateWebPage(?directory)` generates `index.html` from the template and copies `favicon.svg` (the game's, or the library's) beside the JavaScript, each when it isn't there, and the game's `config.json` each build (the page told of it). Every browser build on `-lib helix` runs it.
  - `copyAssets(?directory)` copies `assets/` beside the page or the program.
  - `copyProgram(directory)` copies the native program (and the libraries beside it) into a directory of its own: a native distribution is `copyProgram("out/dist-native")`, `copyAssets("out/dist-native")` and `zipOutput(..., "out/dist-native")`.
  - `zipOutput(path, ?directory)` writes the directory as a zip, its files at the root (`index.html` at the root, what itch.io's HTML upload takes).
- **`Watchers`**, run beside the dev loop until Ctrl+C: `watchShaders(?directory, sdlGpu = false)` packs the game's shaders as `packShaders` does, then again as each changes and as new ones appear; a shader that fails is reported and its last packed file kept.
- **`WebServer`**: `serveDirectory(directory, port = 8095)` serves a directory on this machine over HTTP, as a host serves it (each file with its type, a directory's `index.html`, nothing outside it; no building, no reloading), until Ctrl+C.

### `haxelib run helix`

`haxelib run helix <command>` runs what a game needs before it has an hxml, or outside one (`Run.hx`, `haxelib.json`'s `main`: haxelib starts it in the library's directory and appends the directory the command was given from, which the command works in; `helix.tool.setup.Commands`, run by Haxe's interpreter). `haxelib run helix --help` lists them; from a checkout, `haxe -cp src --run Run <command>` works in the current directory.

```console
haxelib run helix init my-game     # a starter game in my-game/ (new or empty): src/Main.hx, src/Game.hx, hxml/, assets/, favicon.svg, .gitignore, README.md
haxelib run helix init racer --example scene-file   # one of the library's examples as a game, the starter around it
haxelib run helix setup            # the shader tools fetched ahead and listed (version, where, size); --sdl-gpu adds SDL_GPU's
```


- **`init <directory>`** writes a starter game, `templates/starter/` with the directory's name and title in it: the hello's shape (`Game extends helix.App` setting the window's title and putting a rectangle and a greeting on the stage; `Main` giving it its `AppOptions`, the product named for the directory), its builds in `hxml/` (above: `common.hxml`, `web.hxml`, `build.web`, `build.native`, `build.dist`, `dev`, `serve.dist`), an empty `assets/` (the README says what goes there, so nothing but the game's files ships), `favicon.svg` (the page's icon, the logo until the game's replaces it), `.gitignore` (`out/`, `.haxelib/`) and a README with the commands, and how to keep the game's libraries to itself (`haxelib newrepo`, then `haxelib git` for HeliX and hotreload-hx: `.haxelib/`, used only by builds run from the game's directory, which `.gitignore` leaves out). It refuses a directory with anything in it. With `--example <name>` it writes one of the library's examples (a directory of a checkout's `examples/`) as a game instead of the hello: the example's `App.hx` (or every file of its `src/`) in `src/`, `Main` starting `App`; the examples' shared assets and the example's own in `assets/`, its autopilot scripts as `assets/autopilot/<name>/` where the example loads them; its `shaders/` and `config.json`. A name it hasn't is refused with the list of those it has.
- **`setup [--sdl-gpu]`** makes ready what packing shaders would fetch or build on its first use, for a machine about to go offline or a CI's cache: sokol-shdc, and with `--sdl-gpu` SPIRV-Cross (built by hxcpp, which it checks for first) and glslang. Then it lists each tool, those not asked for as they stand: its version (or the variable naming one of your own), where it is and the room it takes, and the cache's directory.

**The dev loop** is one hxml run in the game's directory, `haxe hxml/dev.hxml`, two macros: hotreload-hx's server (`DevServer.serve`) builds the browser build (`hxml/web.hxml`) on save into `out/dev/`, a directory no other build writes (so `build.web` run meanwhile never writes over the page it serves), and swaps the code into the page it serves (the assets at `/assets`, where the page fetches them), first stopping a server this game left on the port (`restart`; another project's is left running, and it says whose), and `Watchers.watchShaders` repacks the game's shaders as they change, which the page reloads as an asset. Ctrl+C stops both:

```hxml
-lib hotreload-hx
-lib helix
-D hotreload-port=8064
--macro hotreload.DevServer.serve(["hxml/web.hxml", "-js", "out/dev/app.js"], {mounts: {"/assets": "assets"}, restart: true})
--macro helix.tool.Watchers.watchShaders()
```


## Build and develop

Work happens in the browser with hot reload: edit, save, and the running page takes the new code (or the changed asset, shader or font) without restarting.

Every build is named `<platform>-<config>-<backend>` ([docs/CONVENTIONS.md](docs/CONVENTIONS.md#build)): the platform what it links against (`linux-x64`, `linux-arm64`, `macos-arm64`, `macos-x64`, `windows-x64-msvc`, or `js` in the browser), the config `release` or `debug`, the backend the API it draws with:

| Backend | Draws with | Profile | Platforms |
| --- | --- | --- | --- |
| `webgl2` | WebGL2 | `WebGL2Profile` | `js` |
| `sokol-gl` | sokol_gfx on GL 4.1 core, in a sokol_app window | `SokolGLProfile` | Linux (GLX), Windows (WGL), macOS (Cocoa) |
| `sdl3-gl` | sokol_gfx on GL 4.1 core, in SDL3's window | `Sdl3GLProfile` | Linux, Windows, macOS |
| `sdl3-gpu` | SDL_GPU (Vulkan, Direct3D 12 or Metal, as SDL picks) | `Sdl3GpuProfile` | Linux, Windows, macOS |

The tools take `<config>-<backend>`, the platform this machine's (`js` for `webgl2`), or the whole name. A build's results go to `out/<platform>/<config>-<backend>/`: natively `bin/<example>/<example>` (`.exe` on Windows, with what it loads beside it: `config.json`, the DLLs, the licenses), in the browser `site/<example>/`; beside the examples' directories one `assets/` they share, which each loads as `../assets`, so `bin/` or `site/` is what ships. Its scratch (the HXML, hxcpp's generated C++ and objects) is in `build/<platform>-<config>-<backend>/`. Deleting `out/` is a clean.

```console
python3 tools/example.py app-hello dev                     # js-debug-webgl2-dev: hotreload-hx dev server, http://localhost:8060/
python3 tools/example.py app-hello build                   # js-release-webgl2: out/js/release-webgl2/site/app-hello/
python3 tools/example.py app-hello build release-sokol-gl  # out/linux-x64/release-sokol-gl/bin/app-hello/app-hello
python3 tools/example.py app-hello build release-sdl3-gl   # out/linux-x64/release-sdl3-gl/bin/app-hello/app-hello
python3 tools/example.py app-hello build release-sdl3-gpu  # out/linux-x64/release-sdl3-gpu/bin/app-hello/app-hello
python3 tools/example.py app-hello build debug-sokol-gl    # out/linux-x64/debug-sokol-gl/bin/app-hello/app-hello
python3 tools/example.py all build release-sdl3-gpu        # every example
python3 tools/pages.py --browser /path/to/chromium   # the examples' site in out/js/release-webgl2/site: every example, thumbnails, the index
python3 tools/check_cache.py --browser /path/to/chromium [--native]   # the asset cache across visits (after sprite2d's release-webgl2 and release-sokol-gl builds)
python3 tools/measure_sizes.py [--write] [--check]   # the web size ladder (tests/sizes/), as a game builds it: docs/benchmarks.md; --check against the baseline (helix.py test)
```

`release` is what ships: full dead-code elimination and the analyzer's optimizations, and Terser in the browser. `debug` is for finding faults: Haxe's `-debug` (a source map beside `app.js`; natively hxcpp's debug runtime, its stack traces with lines and its null checks, `HXCPP_CHECK_POINTER`, the program `Main-debug` before it's named for its example), the standard library's dead-code elimination, no optimizer or Terser, and natively the adapters' C unoptimized with its assertions and sokol_gfx's validation on. `dev` serves the browser's build with hot reload built in (`js-<config>-webgl2-dev`, `debug` unless told `release-webgl2`), in a directory of its own no build writes, so building or replaying the example while it runs never replaces the page it serves.

The examples' site is built and deployed to GitHub Pages daily and on demand (`.github/workflows/pages.yml`: `gh workflow run pages`, about 15 minutes): <https://whirlinggizmo.github.io/helix/>.

SDL_GPU picks its backend (Direct3D 12 on Windows, Metal on macOS, Vulkan elsewhere); `SDL_GPU_DRIVER=vulkan` (or `direct3d12`, `metal`) chooses another. On a machine without a Vulkan GPU, such as the private display, Mesa's software driver runs it: `VK_DRIVER_FILES=/usr/share/vulkan/icd.d/lvp_icd.json` (package `mesa-vulkan-drivers`).

**F9 saves a screenshot** in every example: a download in the browser, natively a PNG in `~/Pictures/<example>/` (or `HELIX_EXPORT`). Autopilot scripts take them too (`{"op": "screenshot"}`).

Examples, their files and how each one is run: [docs/EXAMPLES.md](docs/EXAMPLES.md).

## Checks


```console
python3 tools/check_types.py --no-output    # every entry point, both targets, in seconds
python3 tools/format.py --check           # haxe-formatter, pinned
python3 tools/check_docs.py                 # public API without a doc comment
python3 tools/gen_code.py --check           # the generated code (generated/, committed) is what the sources give; --regenerate remakes it
python3 tools/gen_apidoc.py                   # the API reference: docs/api (committed, checked by the tests) and build/api/index.html
python3 tools/gltf2scene.py export.glb out.scene3d   # a Blender glTF export as a .scene3d: one Model3D node, its custom properties as overrides; --check
python3 tools/fbx2glb.py in.fbx out/ --opaque --smooth-angle 75   # FBX files or directories as GLBs, by Blender run headless (examples/assets/CREDITS.md)
python3 helix.py test --native
python3 helix.py services --browser /path/to/chromium --native
```

- **Unit tests** run under the Haxe interpreter: input, host and frame timing, asset paths, 3D math, trigonometry, Blocks and the Asteroids simulation. `helix.math.Trig` must also give the same bits in JS and, with `--native`, in hxcpp.
- **`services`** runs the asset, storage, fetch and audio services on both targets against local HTTP fixtures; natively `--native` builds `release-sokol-gl`'s (sokol_audio), `--native release-sdl3-gl` SDL3's (its dummy driver), either in `debug` too, in `build/<build>/services`.
- **Autopilot** (`tools/example.py <name> autopilot [<config>-<backend>]`, `release-sokol-gl` when not told) replays an example's scripts in a headless browser and natively under that build, against the browser's build in the same config, and requires the same final game, and the same pixels where a script samples the frame (`{"op": "sample", "name": "lit", "points": [[x, y], ...]}`, in the design's units; within 3 per channel, or the sample's `"tolerance"`). A sample can also require the frame unlike an earlier one (`"differsFrom": "off", "by": 10`), so an effect that draws nothing fails.
- **Native window checks** run on a private Xvfb display (`tools/private_display.py`), never on the desktop in use.


## Tools

Every tool answers `--help` with what it does (its docstring) and its arguments, and does nothing else; it refuses an argument it doesn't
take. A module, which the others import, says so when it's run. `tools/check_tools.py` checks both, and that this table names every tool.

| Tool | What it does |
|---|---|
| `helix.py` | the front door: `test` (the tool, package and unit tests; `--native` adds the native ones) and `services` |
| `tools/example.py` | develop an example under hotreload-hx (`dev`), build it (`build`), or run its autopilot natively against the browser (`autopilot`) |
| `tools/check_types.py` | type-check every example and test on every target, or the browser's alone (`--web`), without building |
| `tools/check_adapters.py` | the adapter rule, where it can be checked mechanically (docs/ARCHITECTURE.md) |
| `tools/check_names.py` | the rule that 2D and 3D are named apart (docs/CONVENTIONS.md) |
| `tools/check_tools.py` | the tools themselves: each answers `--help` with its usage and refuses what it doesn't take, and this table names each |
| `tools/check_docs.py` | every public type and member documented, every doc's links resolving |
| `tools/check_cache.py` | the browser asset cache across visits, as a returning visitor meets it |
| `tools/format.py` | lay out the Haxe source with haxe-formatter, or `--check` it |
| `tools/gen_code.py` | the generated Haxe the library ships, in `generated/` (`--check` fails when stale) |
| `tools/gen_apidoc.py` | the API reference from the doc comments, `docs/api` (`--check` fails when stale): what a game writes against, anything `@:noCompletion` (the adapters, profiles and services behind the static classes) left out, each type linked to its source; fails unless js and cpp describe the same types and members |
| `tools/gen_manifest.py` | asset manifests through an assets directory, as the browser's cache reads them |
| `tools/gen_fixtures.py` | the test fixtures: tones as WAV, Ogg/Vorbis and Ogg/Opus, and a stream |
| `tools/gen_sprite_sheet.py` | the examples' sprite sheet, `examples/assets/sheets/gizmos.png` and `.json` |
| `tools/bake_fonts.py` | the built-in font baked into a distance-field atlas, as generated Haxe |
| `tools/gltf2scene.py` | a Blender glTF export as a `.scene3d` file |
| `tools/fbx2glb.py` | FBX models as GLB files, through Blender run headless |
| `tools/measure_sizes.py` | the web size ladder (`tests/sizes`), against the committed baseline (`--write` remakes it) |
| `tools/measure_cpu.py` | the CPU a program keeps busy, case by case |
| `tools/bench_stage.py` | a `Renderer3D`'s CPU work by case and model count, natively and in V8 |
| `tools/pages.py` | the examples' site for GitHub Pages, with thumbnails |
| `tools/services.py` | the async service tests against a local HTTP server, in the browser and natively |
| `tools/remote_windows.py` | build and check this checkout on a Windows machine over ssh, leaving nothing behind |
| `tools/sdl3.py` | SDL3 for the SDL3 backends, found or made into `build/deps` |
| `tools/autopilot.cjs` | an autopilot script in a headless browser: an example's (run by `example.py autopilot`), or a game's built release (run by `haxelib run helix autopilot`, serving it) |
| `tools/check_cache.cjs` | one visit of `check_cache.py`'s |
| `tools/pages_shots.cjs` | the site's thumbnails (run by `pages.py`) |
| `tools/service_browser.cjs` | the browser's half of `services.py` |
| `tools/cli.py` | a module: the tools' command lines (`--help` from the docstring; unknown arguments refused) |
| `tools/cli.cjs` | a module: the Node tools' command lines, as `cli.py` |
| `tools/native_build.py` | a module: native builds without CMake, hxcpp compiling the adapters' C |
| `tools/pins.py` | a module: the repository-local haxelib holding the pinned hxcpp, and the vendored headers' pins |
| `tools/private_display.py` | a module: a private X display (Xvfb and Openbox) for native window checks |
| `tools/shader_tool.py` | a module: the shader packer and translators as the Python tools reach them |
| `tools/shader_metadata.py` | a module: sokol-shdc's reflection read into the framework shaders' fixed layout |
| `tools/variants.py` | a module: a build's name and its directories |

## Layout

```text
src/helix/                 the framework: contracts, policy, render2d, render3d, math, input, audio, assets
  adapter/<contract>/<api>/   one platform API behind one contract (<Api><Contract>Adapter); internal/ holds C glue and externs
  profile/                one per backend: WebGL2Profile, SokolGLProfile, Sdl3GLProfile, Sdl3GpuProfile
generated/                 committed and shipped: the framework's programs, the shader library packed, SDL_GPU's dialects, the built-in font (tools/gen_code.py)
templates/index.html       the page a browser build runs in: the examples' and a game's
templates/starter/         the starter game haxelib run helix init writes
examples/<name>/App.hx      the catalog: one feature each, sharing examples/shared/launch/Main.hx and examples/assets (once a build, in its assets/)
examples/asteroids/src/     larger examples: whole games, built the same way, with autopilot scripts
examples/blocks/src/
tests/                    unit (Haxe interpreter), services (both targets), native, consumer, shader checks
tools/                    example/build/check/format/doc tools (Python, some Node)
docs/                     EXAMPLES, ROADMAP, HISTORY, ARCHITECTURE, INTERFACE, CONVENTIONS, DECISIONS, API_FINDINGS, ADAPTER_AUDIT, PACKAGING
vendor/                   pinned third-party headers, fonts and their licenses
helix.py                  front door for the tests and the services checks
src/helix/tool/           a game's build steps (Build, Watchers, WebServer: macros its hxml lists), haxelib run helix's commands (setup/),
                          the shader packer, sokol-shdc and SDL_GPU's translators (shader/; the repository's tools reach it through
                          tools/shader_tool.py), what they share (shared/); in Haxe, run in the compiler or its interpreter
Run.hx                    haxelib run helix (init, setup)
haxelib.json, extraParams.hxml   the library: classPath src/, and what -lib helix adds (src/helix/macro/Haxelib.hx)
out/                      ignored: builds' results, out/<platform>/<config>-<backend>/ (deleting it is a clean)
build/                    ignored: the generators' scratch, builds' scratch (build/<build>/), caches, check output
```

