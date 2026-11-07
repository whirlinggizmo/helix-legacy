# helix.tool

[Back to the index](README.md)

## Build

*class* in [`src/helix/tool/Build.hx`](../../src/helix/tool/Build.hx), `import helix.tool.Build;`

The steps a game's build hxml lists after what it builds, as macros (`--macro helix.tool.Build.<step>(...)`), run by the compiler from the game's directory: `packShaders` before the build compiles, the others once it has written its output, in the order listed. A step's directory, when it takes one, is relative to the game's and defaults to the build's output directory: the `-js` file's, or the `-cpp` one natively. A step that fails ends the build with its message.

- `packShaders(?directory)`: the game's `shaders/*.glsl` packed into `assets/shaders/<name>.hxshader` (or directory), each only when its source is newer, with SDL_GPU's dialects when the build names the `sdl3-gpu` backend; nothing without a `shaders/` directory. When the assets carry manifests (`tools/gen_manifest.py`'s), they're rewritten from their root down to the shaders' directory. - `cleanOutput(?directory)`: everything in the browser build's output directory removed but the JavaScript just written, so what's there is what the steps after it put there. Refuses a native build's: a `-cpp` directory is hxcpp's working directory. - `generateWebPage(?directory)`: the page a browser build runs in, beside its JavaScript: `index.html` generated from the library's template (titled with the game directory's name, loading the build's file, told of `config.json` when the game has one), and `favicon.svg` (the game's, or the library's) copied, each when it isn't there (one there is the game's, and kept); the game's `config.json` copied each build. Every browser build on `-lib helix-legacy` runs it (helix.macro.Haxelib), so the dev loop has a page. - `copyAssets(?directory)`: the game's `assets/` copied into directory as `assets/`, beside the page or the program, where both read it. - `copyProgram(directory)`: the native program (the main class's, `-debug` in a debug build) and the libraries beside it copied from the build's output into directory, a distribution of its own away from hxcpp's working directory. - `zipOutput(path, ?directory)`: directory written as a zip at path, its files at the zip's root (`index.html` at the root, as itch.io takes a web game).

## Watchers

*class* in [`src/helix/tool/Watchers.hx`](../../src/helix/tool/Watchers.hx), `import helix.tool.Watchers;`

What runs beside a game's dev loop, repacking a source as it changes, as macros an hxml of its own calls (`--macro helix.tool.Watchers.<watcher>(...)`), run by the compiler from the game's directory until Ctrl+C.

- `watchShaders(?directory, sdlGpu = false)`: the game's `shaders/*.glsl` packed into `assets/shaders/<name>.hxshader` (or directory), those changed since they were last packed at once, then again as each changes and as new ones appear; with sdlGpu, SDL_GPU's dialects too. A shader that fails is reported and its last packed file kept, so the running page keeps it. When the assets carry manifests (`tools/gen_manifest.py`'s), they're rewritten from their root down to the shaders' directory.

## WebServer

*class* in [`src/helix/tool/WebServer.hx`](../../src/helix/tool/WebServer.hx), `import helix.tool.WebServer;`

A web server for a directory of files, as a macro an hxml of its own calls (`--macro helix.tool.WebServer.serveDirectory(...)`), run by the compiler from the game's directory until Ctrl+C: a built game served on this machine as a host serves it, to try before uploading.

- `serveDirectory(directory, port = 8095)`: directory served at http://localhost:port/ over HTTP, GET and HEAD, each file with its type (what a browser needs to take an SVG icon, a module, a WebAssembly file), a directory's index.html, nothing outside the directory. No building, no watching, no script added: the page is what ships.
