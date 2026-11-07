# Scope: what HeliX is, sorted against its goals

A draft for review (2026-10-25). Nothing has moved.

GOALS.md names five things:
1. small web delivery
2. the same code built natively
3. fast iteration with no cost in release
4. C libraries through their ABI
5. a clear, consistent API

Everything HeliX holds is sorted here by whether a goal needs it. Member counts are the API reference's: 2,304 in all, of which
katawami, a whole jam game, uses about 230.

## Core: the goals need it

| Package | Members | Why it's core |
| --- | --- | --- |
| `helix` (App, AppOptions) | 20 | the entry point; one `Main` for every target |
| `host` | 90 | window, screen, quitting, the page: what differs per platform |
| `input` (raw: keys, pointer, touches, gamepads) | part of 209 | per-platform input |
| `audio` | 46 | per-platform sound, buses |
| `asset`, `texture`, `font` | 82 | loading, decoding, caching per platform |
| `graphics` | 86 | the GPU, shaders, screen effects |
| `render2d`, `render3d` | 690 | the stage, nodes, views, cameras, models |
| `math`, `time` | 125 | units, deterministic trig, the frame clock |
| `debug` (Log, FpsOverlay) | 45 | logging per platform |
| the adapters, the profiles, hot reload's wiring | (hidden) | goals 2, 3 and 4 |

## Game kit: useful, but no goal needs it in the core

Small helpers a game would otherwise write. They're candidates for a `helix.kit` package, documented apart from the core, or for staying
where they are with the reference listing them after the core.

| What | Members |
| --- | --- |
| `tween`, timers | 43 |
| `particle` | 83 |
| `collision` (2D) | 63 |
| `scene-transition`, SplashScreen, LoadingScreen | 33+ |
| Collect2D, Collect3D, CameraFollow2D, CameraFollow3D, Orbit3D | ~60 |
| input's `Actions` | part of 209 |
| `shader` (the library's effects: bloom, CRT, outline, water...) | 105 |

## Subsystems: their own libraries

Large, with their own formats and lifecycles. A game that doesn't use them shouldn't see them in the reference.

| What | Members | Proposed home |
| --- | --- | --- |
| `ui` (widgets, themes, layout) | 243 | `helix-ui` |
| `tiled` (Tiled maps) | 129 | `helix-tiled` |
| scene files (`.scene3d`, SceneFile*, gltf2scene) | most of `scene`'s 153 | `helix-scene`, with the editor already planned as a separate package |
| `behavior` (behaviors in a pass) | 59 | with scene files |

## Tooling: where it has drifted

| What | Goal | Proposal |
| --- | --- | --- |
| Shader packing (`helix.tool.shader`, sokol-shdc fetched) | 1, 2 | keep: only HeliX can do it |
| The page, copying assets, manifests (`Build`) | 1 | keep |
| The dev loop's shader watcher (`Watchers`) | 3 | keep |
| `init` (the starter) | 5 | keep, small |
| `WebServer` (serving a build to try) | none | drop: any static server does this |
| The release zip for itch.io | none | drop, or a line in the README |
| Docker and nginx HTTPS for a phone (the starter's `docker-compose.yml`, `tls/`) | none | drop from the starter; a guide section instead |
| The autopilot (driver, `tools/autopilot.cjs`, `haxelib run helix-legacy autopilot`, Playwright fetched) | verification | keep the driver in the engine; the runner is a separate tool, used by HeliX's own CI |
| `tools/` (37 Python scripts: checks, generators, examples, pages, CI) | HeliX's development | fine: not shipped to games |

## Questions for review

1. Does the core table match what you mean by HeliX?
2. Should the game kit stay in HeliX, behind the core in the reference, or move out?
3. Should ui, tiled and scene files become separate libraries now, or after the trial (docs/TRIAL.md) says whether HeliX stays a full
   engine?
4. Which tooling rows do you agree to drop?
