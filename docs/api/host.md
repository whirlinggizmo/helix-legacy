# helix.host

[Back to the index](README.md)

## Config

*class* in [`src/helix/host/Config.hx`](../../src/helix/host/Config.hx), `import helix.host.Config;`

A game's settings from config.json beside the program (beside the page on the web; never among the assets or in their cache, DECISIONS 131), fetched as the program starts (so a deployed game changes them without a build): a "default" object, and named profiles over it ("development", "production", any the game names), each a partial that layers on the default; "profile" at the root names the one in force, and the run option config=<name> overrides that. Host.getOption reads the profile, by dotted names into nested objects ("renderer.background"), after the run options. The keys and their meanings are the game's: whether to show a splash, play music, where assets are.

```haxe
static function parse(bytes:haxe.io.Bytes, ?profileName:String):Null<Config>
static function toBool(text:Null<String>, fallback:Bool):Bool
static function toFloat(text:Null<String>, fallback:Float):Float
static function toInt(text:Null<String>, fallback:Int):Int
var profileName(default, null):String
var profileNames(get, never):Array<String>
function get(name:String):Null<Dynamic>
function getString(name:String):Null<String>
```

- `parse`: The config in bytes (JSON), with the profile chosen (the root's "profile", else "default") unless profileName names one. Null for bytes that aren't a JSON object.
- `toBool`: text as a bool: 1, true, yes and on are true, 0, false, no and off are false (any case); fallback for anything else or null.
- `toFloat`: text as a number; fallback for anything that isn't one, or null.
- `toInt`: text as a whole number; fallback for anything that isn't one, or null.
- `profileName`: The profile in force.
- `profileNames`: The profiles the file has, in name order, "default" among them when it does.
- `get`: The value at name (dotted into nested objects) in the profile, else in the default; null for none. A number, a string, a bool, an array or an object, as the JSON has it.
- `getString`: The value at name as text: a string as it is, a number or bool as JSON writes it ("1.5", "true"); null for none or an object.

## Host

*class* in [`src/helix/host/Host.hx`](../../src/helix/host/Host.hx), `import helix.host.Host;`

The program on its platform: whether it runs, whether anything is still loading, its run options and settings, and quitting. The program's one, a static class: canQuit and quit forward to instance, written by helix.macro.Facade from IHost's with their doc comments; the loop, the window (Window) and the clock (Time) are reached elsewhere, and reportBusy is the App's to call.

```haxe
static var config(default, null):Null<Config>
static var running(get, never):Bool
static var busy(get, never):Bool
static function getOption(name:String, fallback:String):String
static function getOptionBool(name:String, fallback:Bool):Bool
static function getOptionFloat(name:String, fallback:Float):Float
static function getOptionInt(name:String, fallback:Int):Int
static function canQuit():Bool
static function quit():Void
static function loadConfig(done:Null<haxe.io.Bytes> -> Void):Void
```

- `config`: The game's settings from config.json beside the program (Config; DECISIONS 131), or null without one. Kept across a hot reload (@:hot), as instance is.
- `running`: Whether the runner is running the program: false in a test, which makes what it needs itself.
- `busy`: Whether anything is still loading: an asset, an image or sound being decoded, an environment being prepared. A loading screen waits for it to be false (with the app's own loads in view); so does a tool taking the frame's picture once it's in.
- `getOption`: A run option, or fallback when it isn't given: in a browser the URL query parameter name, natively the environment variable HELIX_ and name in capitals; else the config's value at name (its profile over its default, dotted into nested objects), as text.
- `getOptionBool`: getOption as a bool: 1, true, yes and on are true, 0, false, no and off are false; fallback for anything else.
- `getOptionFloat`: getOption as a number; fallback for anything that isn't one.
- `getOptionInt`: getOption as a whole number; fallback for anything that isn't one.
- `canQuit`: Whether quitting closes anything, so whether an app should offer a quit key: not in a browser page, where quit stops the program but the page stays.
- `quit`: Closes after the current frame: cleanup runs. Natively the window closes; in a browser page the frames stop and the canvas keeps its last one.
- `loadConfig`: Reads the game's config.json, the one beside the program (beside the page on the web, where the page says it has one; beside the executable natively), and gives done its bytes, or null when there is none: none is no error, the defaults stand. Fetched fresh each start, outside the asset cache, so a deployed game's settings change without a build (DECISIONS 131).

## Identity

*class* in [`src/helix/host/Identity.hx`](../../src/helix/host/Identity.hx), `import helix.host.Identity;`

Who the program is, for what HeliX keeps for it: a company and a product, each one safe file name. Natively it names the cache directory (<user cache>/<company>/<product>); in the browser, the page's cache database.

```haxe
function new(product:String, ?company:String = "DefaultCompany")
static function cleanName(name:String):Null<String>
var company(default, null):String
var product(default, null):String
```

- `new`: product and company, cleaned (cleanName). Throws for a name that cleans to nothing or is too long.
- `cleanName`: name as one file name every desktop accepts: characters no file system takes (<>:"/\|? *, control characters) become _, leading and trailing dots and spaces go, and a Windows device name (CON, PRN, AUX, NUL, COM1-9, LPT1-9, with any extension) gets a leading _. null for a name that's empty once cleaned, or 128 characters or more (refused, never cut).
- `company`: The company, cleaned; "DefaultCompany" unless given.
- `product`: The product, cleaned: the program's own name.

## PresentationMode

*enum* in [`src/helix/host/PresentationMode.hx`](../../src/helix/host/PresentationMode.hx), `import helix.host.PresentationMode;`

How a game's design is fitted to the window (Godot's stretch modes and aspects).

- `None`: The default: a unit is a logical pixel (a framebuffer pixel over the pixel ratio), and the visible area is the window.
- `Stretch`: The design scaled to the window on each axis apart, its aspect lost.
- `Fit`: Scaled alike on both axes, as large as it fits whole, centered; the framebuffer around it is bars, nothing drawn in them.
- `Fill`: Scaled alike, as small as covers the window, centered; what's past the window's edges is cropped.
- `Expand`: Scaled as Fit is, but the visible area grows past the design to the window's edges, centered on it: the design is the least the game shows, and a layout arranged into the visible area keeps to the window's edges.
- `Integer`: As Fit, at a whole number of framebuffer pixels to a unit (at least 1), for pixel art; bars around it.

## Screen

*class* in [`src/helix/host/Screen.hx`](../../src/helix/host/Screen.hx), `import helix.host.Screen;`

The app's design fitted to the window (Presentation): its units, what's visible of them, and a 2D camera to show them (None, logical pixels, until the app sets a mode). The runner refits it to the window before every frame. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from Presentation's public members with their doc comments.

```haxe
static var framebufferWidth(get, never):Int
static var framebufferHeight(get, never):Int
static function set(mode:PresentationMode, width:Float, height:Float):Bool
static var mode(get, never):PresentationMode
static var width(get, never):Float
static var height(get, never):Float
static var scaleX(get, never):Float
static var scaleY(get, never):Float
static var visibleX(get, never):Float
static var visibleY(get, never):Float
static var visibleWidth(get, never):Float
static var visibleHeight(get, never):Float
static var portrait(get, never):Bool
static var areaX(get, never):Int
static var areaY(get, never):Int
static var areaWidth(get, never):Int
static var areaHeight(get, never):Int
static function toUnitsX(x:Float):Float
static function toUnitsY(y:Float):Float
static function toPixelsX(x:Float):Float
static function toPixelsY(y:Float):Float
static function apply(camera:Camera2D):Void
```

- `framebufferWidth`: The framebuffer's width in pixels, as last refitted (the window's, under the runner); 1 before.
- `framebufferHeight`: The framebuffer's height in pixels, as last refitted; 1 before.
- `set`: Fits the design, width x height units, to the window by mode, from the next frame (None takes no size: give 0, 0). False, changing nothing, for a size under 1 but for None.
- `mode`: How the design is fitted.
- `width`: The design's width in units: the window's logical width under None.
- `height`: The design's height in units: the window's logical height under None.
- `scaleX`: Framebuffer pixels to a unit, across (under Stretch, each axis has its own).
- `scaleY`: Framebuffer pixels to a unit, down.
- `visibleX`: The visible area's left edge in units: 0 under None, Stretch, Fit and Integer; more under Fill, which crops; less under Expand, which grows. A HUD anchored to an edge places itself from the visible area.
- `visibleY`: The visible area's top edge in units.
- `visibleWidth`: The visible area's width in units.
- `visibleHeight`: The visible area's height in units.
- `portrait`: Whether the visible area is taller than wide: a phone held upright, for a game with a layout for each.
- `areaX`: The visible area's left edge in framebuffer pixels: past 0 where Fit and Integer have bars.
- `areaY`: The visible area's top edge in framebuffer pixels, from the framebuffer's top.
- `areaWidth`: The visible area's width in framebuffer pixels.
- `areaHeight`: The visible area's height in framebuffer pixels.
- `toUnitsX`: The unit across at framebuffer pixel x (input's pointer and touches are framebuffer pixels).
- `toUnitsY`: The unit down at framebuffer pixel y.
- `toPixelsX`: The framebuffer pixel across at unit x (toUnitsX's inverse).
- `toPixelsY`: The framebuffer pixel down at unit y (toUnitsY's inverse).
- `apply`: Sets camera to show the visible area on the framebuffer pixels it covers: its viewport the area, a unit its zoom.

## ScreenShape

*class* in [`src/helix/host/ScreenShape.hx`](../../src/helix/host/ScreenShape.hx), `import helix.host.ScreenShape;`

A design per window shape, as a page's breakpoints (Defold's display profiles): 1280 x 720 for a desktop window, 1000 x 560 for a short one (a phone on its side), 560 x 960 upright (a phone held so), each grown to the window's edges (Presentation's Expand), so text at one size stays readable on a phone in each. The examples' choice, called at the top of their frame; a game with designs of its own sets Screen itself.

```haxe
static function update():String
```

- `update`: The window's shape now, the design set for it: "landscape", "short" or "portrait". Once a frame, before the presentation is used: the design changes only when the shape does.

## Window

*class* in [`src/helix/host/Window.hx`](../../src/helix/host/Window.hx), `import helix.host.Window;`

The window the app draws in (the page, on the web): its drawing surface's size, pixel ratio and focus too, and what may be asked of it (a size, a position, fullscreen). The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from IWindow's public members with their doc comments.

```haxe
static var framebufferWidth(get, never):Int
static var framebufferHeight(get, never):Int
static var pixelRatio(get, never):Float
static var focused(get, never):Bool
static var title(get, set):String
static var width(get, never):Int
static var height(get, never):Int
static function requestSize(width:Int, height:Int):Bool
static function canMove():Bool
static var x(get, never):Int
static var y(get, never):Int
static function requestPosition(x:Int, y:Int):Bool
static function canFullscreen():Bool
static var fullscreen(get, never):Bool
static function requestFullscreen(enabled:Bool, ?done:() -> Void, ?failed:String -> Void):Bool
static var visible(get, never):Bool
static function requestVisible(visible:Bool):Bool
static var monitorCount(get, never):Int
static var monitorIndex(get, never):Int
static function requestMonitorIndex(index:Int):Bool
static function getMonitorName(index:Int):String
static function getMonitorX(index:Int):Int
static function getMonitorY(index:Int):Int
static function getMonitorWidth(index:Int):Int
static function getMonitorHeight(index:Int):Int
```

- `framebufferWidth`: The drawable area's width in framebuffer pixels (the width and height sizes are logical pixels).
- `framebufferHeight`: The drawable area's height in framebuffer pixels.
- `pixelRatio`: Framebuffer pixels per logical pixel.
- `focused`: Whether the window has the keyboard and is shown: false while it's in the background, minimized, or (on the web) the page is hidden.
- `title`: The title bar's text (the document's title, on the web).
- `width`: The window's inner width in logical pixels (the viewport's, on the web).
- `height`: The window's inner height in logical pixels (the viewport's, on the web).
- `requestSize`: Asks for an inner size in logical pixels; width and height answer on a later frame, with what the window manager gave (it may give another size, or none). False, asking nothing, where a program can't size its window (the web), or for a size under 1.
- `canMove`: Whether requestPosition and requestMonitorIndex can ask: not on the web, nor where the compositor places windows (XWayland).
- `x`: The window's left edge on the desktop in logical pixels; natively 0 where it can't move (canMove), on the web the browser window's.
- `y`: The window's top edge on the desktop in logical pixels; natively 0 where it can't move (canMove), on the web the browser window's.
- `requestPosition`: Asks for the window's left and top edges on the desktop in logical pixels; x and y answer on a later frame, with what the window manager gave. False, asking nothing, where the window can't move (canMove).
- `canFullscreen`: Whether requestFullscreen can ask: always natively; on the web, where the page may go fullscreen.
- `fullscreen`: Whether the window is fullscreen now (the canvas, on the web).
- `requestFullscreen`: Asks for fullscreen (enabled) or a window; fullscreen answers on a later frame, and done is called once it's granted. On the web the browser grants it only soon after a key press, click or tap: refused (none was recent, or the page may not), failed is called with its reason, or without failed it's traced, and the page stays as it was; natively it's granted. False, calling neither, where it can't ask (canFullscreen).
- `visible`: Whether the window is shown (the canvas, on the web).
- `requestVisible`: Asks to show or hide the window (the canvas, on the web); visible answers on a later frame (natively, once the window manager has shown it). Always asks: true.
- `monitorCount`: How many monitors there are, at least 1; the web sees one screen.
- `monitorIndex`: The monitor holding the window.
- `requestMonitorIndex`: Asks for the window on monitor index; monitorIndex answers on a later frame. False, asking nothing, for an index out of range, or where the window can't move (canMove).
- `getMonitorName`: "" for an index out of range, as the other monitor getters answer 0.
- `getMonitorX`: The monitor's left edge on the desktop in logical pixels; 0 for an index out of range, and on the web.
- `getMonitorY`: The monitor's top edge on the desktop in logical pixels; 0 for an index out of range, and on the web.
- `getMonitorWidth`: The monitor's width in logical pixels; 0 for an index out of range.
- `getMonitorHeight`: The monitor's height in logical pixels; 0 for an index out of range.

## WindowOptions

*class* in [`src/helix/host/WindowOptions.hx`](../../src/helix/host/WindowOptions.hx), `import helix.host.WindowOptions;`

What's fixed when the window opens, given to a profile's run before it does: an app starts after, too late to change them.

```haxe
function new()
var msaaSamples(default, null):Int
function requestMsaaSamples(count:Int):Bool
```

- `new`: The defaults: 4 multisampling samples a pixel.
- `msaaSamples`: The multisampling samples a pixel asked for: 4 unless requested otherwise.
- `requestMsaaSamples`: Asks for count samples a pixel to smooth edges (multisampling): 1 for none, else 2, 4 or 8. A request: the platform may give fewer (a browser chooses its own count, nearly always 4, for anything over 1), and IGraphics.msaaSamples answers what it gave (maxMsaaSamples, the most this GPU has, for a settings menu to offer at the next start). False, changing nothing, for another count.
