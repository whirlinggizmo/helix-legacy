# helix

[Back to the index](README.md)

## App

*class* in [`src/helix/App.hx`](../../src/helix/App.hx), `import helix.App;`

HeliX's entry point. A game is a class extending it, overriding init, update and cleanup, and its Main is `new Game()`: the constructor starts HeliX, picking the profile by the backend the build names (`-D helix-backend=webgl2`, `sokol-gl`, `sdl3-gl` or `sdl3-gpu`; a build naming none fails, naming the choices), so one Main serves every target: `class Game extends helix.App { override public function init():Void {...} override public function update(dt:Float):Void {...} }` (init once, the services bound: Window, Input, Graphics and the others; update once a display refresh, the game's logic), and `class Main { static function main() new Game(); }`. The drawing is the runner's: after update it draws the Stage (helix.render2d.Stage), what the game put on it (docs/DISPLAY_MODEL.md).

The object exists before HeliX does: a field initializer runs before the services are bound, so what needs them (a Batch2D, a texture) is made in init. Natively the constructor returns only when the window closes. Options (AppOptions: the identity, where the assets are, a manifest, the window, the development extras) are given to the constructor, `super(options)` or `new Game(options)`.

Hot reload (the dev loop, in the browser): the app is the object that's kept. After a reload it's the same object with its fields as they were, running the new code, so keep the game's state in the app's fields (or objects they hold), not in plain statics, which start over at each reload. Override afterReload to build what an edit added to init, and beforeReload to let go of what it will build again. The Runner reaches the app only through `@:hot` static functions that helix.macro.AppBuild writes into the game's class (`hotApp`, the object, and the calls to it), as hotreload-hx needs for a native reload; HeliX doesn't run native reloads yet. The game class is therefore not Main, which hotreload-hx never reloads and refuses `@:hot` in.

```haxe
function new(?options:AppOptions)
var options(default, null):AppOptions
function init():Void
function update(dt:Float):Void
function cleanup():Void
function beforeReload():Void
function afterReload():Void
function probe(name:String):Dynamic
function pressWidget(name:String):Bool
function locateWidget(target:String, part:String, x:Float, y:Float, out:Array<Float>):Bool
var autopilot(default, null):Null<Autopilot>
```

- `new`: Starts HeliX with this app, with options (the defaults when not given): the profile of the build's backend runs, binds the services, calls init once the game's config.json (if any) has come, then update once a display refresh, and cleanup when the window closes (the page goes away). Throws for an identity (product, company) that isn't a file name. Natively returns when the window has closed.
- `options`: The options it started with.
- `init`: Once, before the first frame, with the app's services bound (Window, Input, Graphics and the others). Nothing by default.
- `update`: Once a display refresh, before the frame is drawn: the game's logic. dt is the measured seconds since the last frame, held between 1e-6 and 0.1, and 1/60 on the first: for animation. A fixed-rate simulation takes Time.frameElapsed instead (helix.host.FrameClock). Nothing by default.
- `cleanup`: Once, when the window closes (on the web, at the page's pagehide). Nothing by default.
- `beforeReload`: Just before a hot reload swaps in the new code, still running the old: let go of what afterReload will build again. Only between init and cleanup. Nothing by default.
- `afterReload`: Just after a hot reload: this is the same object, its fields kept, now running the new code. Build here what an edit added to init (init doesn't run again), or rebuild what it changed. Only between init and cleanup. Nothing by default.
- `probe`: A named value of the game for an autopilot script (helix.debug.Autopilot) to wait on and assert, and to publish as the game's final state, which tools/example.py and tools/autopilot.cjs compare between the browser and natively. Overriding it makes the game scriptable: run with the option autopilot naming a script under assets/ (?autopilot=autopilot/run.json in the page's URL, HELIX_AUTOPILOT natively), HeliX loads it before init, so every run starts alike, then plays it as the input a tick of 1/60 s at a time, each tick an update(1 / 60) (up to 120 a frame with fast=1, a press ending the frame's ticks), and once it's done publishes the probes it names, and quits with autoclose=1. Throw for a name it doesn't know: the script fails, naming it.
- `pressWidget`: Presses the widget named name for a script's click (Ui.press, say): false while there's none to press, which the script waits for. False to start.
- `locateWidget`: The framebuffer pixel at x, y fractions of the widget named target, or of its part named part, into out, for a script's point naming a widget (Ui.computePoint, say): false while there's none, which the script waits for. False to start.
- `autopilot`: The autopilot script playing (its seed for the game's random numbers), from init on, or null without one (probe).

## AppOptions

*class* in [`src/helix/AppOptions.hx`](../../src/helix/AppOptions.hx), `import helix.AppOptions;`

What an App starts with, given to its constructor (`super(options)`, or `new Game(options)` from Main); the defaults when none is given. Read once, as the app starts: a change after is too late.

```haxe
function new()
var product:String
var company:String
var assets:Null<String>
var manifest:Null<String>
var window:WindowOptions
var devKeys:Bool
var pageState:Bool
var pauseOnBlur:Bool
```

- `new`: The defaults: product "Game" by "DefaultCompany", the assets beside the program, no manifest, a window of 4 samples a pixel, and the development extras on in a debug build (-debug) and off otherwise.
- `product`: The program's own name: with company, its identity (helix.host.Identity), which names what HeliX keeps for it (its cache directory natively, its cache database in the browser, its screenshots' directory). One safe file name; cleaned as Identity cleans it.
- `company`: The company, the other half of the identity.
- `assets`: Where the assets are: in the browser the URL the asset paths are fetched under ("assets/", beside the page, by default), natively a directory relative to the program's ("assets", beside it, by default). Null for the platform's default.
- `manifest`: A manifest among the assets (tools/gen_manifest.py; "manifest.json" for the examples), read in the browser so a returning page re-fetches only what changed; null (the default) fetches each file as it's asked for. Natively a manifest comes from HELIX_ASSET_MANIFEST instead, with HELIX_ASSET_HOST.
- `window`: The window as it opens: the multisampling samples a pixel.
- `devKeys`: The development keys around every frame: F9 saves a screenshot of the frame (a download in a browser, a file in the user's pictures natively), logged where it went. On in a debug build (-debug), off otherwise, unless set. A game chooses its own keys for what it ships.
- `pageState`: Whether the page is told the program's state, for the tools driving it: in a browser, window.helixBusy says after each frame whether the services are still loading (Host.busy), and false once the program has quit, so a tool captures the page once it has settled (tools/pages_shots.cjs); natively nothing. On in a debug build (-debug), off otherwise, unless set.
- `pauseOnBlur`: Whether the game's clock (Time.clock) pauses while the window doesn't have the focus, and goes on when it's back: a game left in another tab or behind another window waits. On unless set off; a clock the game paused itself stays paused either way.
