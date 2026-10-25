import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.IInput;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.scene.Loader;
import helix.scene.Loading;
import helix.scene.Splash;
import helix.scene.transition.Transition;
import helix.scene.transition.Fade;
import helix.time.Time;
import helix.tween.Ease;
import helix.host.ScreenShape;

/** A game's flow of screens on the stage (docs/DISPLAY_MODEL.md), a movie-like opening. There is no stack of screens: a screen is a node on
	the stage, the app's update holds the logic, and a small state says which screen is up. Swapping screens is taking one off the stage
	and putting the next on, at the middle of a transition (Fade.run, Fade.swap); the built-in screens put themselves on the stage and call
	back as they leave. The flow:
	- the built-in Splash (Splash.show), faded in: the logo, "press any key" until a press unlocks audio, or three seconds for the impatient;
	  it calls back at the middle of its fade out, where the title goes on the stage
	- a title: Enter or a tap fades to the level
	- the level's files load behind the built-in Loading screen (Loading.show, put up at the fade's middle), which holds once loaded until a
	  press ("loaded, go"), then calls back, where the level goes on the stage
	- a pause menu (Escape) added over the level, which is paused under it (Node2D.paused); Escape takes the menu off and resumes the level,
	  T goes back to the title
	The window losing focus pauses the game's clock (the app's pauseOnBlur), which the level moves by. Its settings come from its
	config.json beside the program (Host.config, read as the program starts): showSplash, splashSeconds, splashMaxWait, clickToContinue (the
	loading screen's hold) and tip, with a "development" profile that skips the splash and the hold (the run option config=development, or
	the file's "profile"), and the run option quick=1 skips every wait and transition. Options: autopilot (a script under assets/), fast (1:
	up to 120 ticks a frame under autopilot) and autoclose (1: quit once the script is done); the probes are scene, count, loaded, loading,
	visited, activated and transitioning. The built-in screens and the transitions run on the frames' time and read the program's input,
	which is the autopilot's while it plays. Escape on the title quits where quitting means anything. */
class App extends helix.App {
	/** Every screen entered, in order: what the autopilot's run is judged by. Kept across a hot reload (@:hot). */
	@:hot public static var visited:Array<String> = [];

	// Which screen is up ("" before the first, "Splash", "Title", "Play" or "Pause"), and the screens.
	var state = "";
	var title:Page;
	var pause:Page;
	var play:Null<Play>;
	var loading:Null<Loading>;
	// The transition running, if any: no screen takes keys while one does.
	var transition:Null<Transition>;

	override public function init():Void {
		Window.title = "HeliX scenes";
		Window.requestSize(960, 540);
		Stage.color = 0xff14161c;
		title = new Page("Title", 0xff1c1e26, "HeliX scenes", "Enter or tap: play" + (Host.canQuit() ? "   Escape: quit" : ""));
		pause = new Page("Pause", 0xff262c3c, "Paused", "Escape: resume   T: title");
		start();
	}

	// The splash first, with the logo once it's in (or without it), unless the config skips it.
	function start():Void {
		if (!Host.getOptionBool("showSplash", true)) {
			enter("Title", title);
			return;
		}
		Textures.load("sprites/logo/wg-logo-white-alpha.png", true, logo -> showSplash(logo), _ -> showSplash(null));
	}

	// The splash, faded in, showing logo (or nothing, when it didn't load), then the title at the middle of its fade out.
	function showSplash(logo:Null<Texture2D>):Void {
		var shown = new Splash(logo, Host.getOptionFloat("splashSeconds", 1));
		shown.maxWait = Host.getOptionFloat("splashMaxWait", 0);
		state = "Splash";
		fade(new Fade(.8), () -> shown.show(() -> {
			enter("Title", title);
		}));
	}

	// screen put on the stage as the one up, named name.
	function enter(name:String, screen:Node2D):Void {
		state = name;
		visited.push(name);
		Stage.addChild(screen);
	}

	// Runs by, atMiddle at its middle, remembered so no screen takes keys until it's done.
	function fade(by:Transition, atMiddle:Void->Void):Void {
		transition = by;
		by.run(atMiddle);
	}

	// From the title to the level: its loads made and shown behind the loading screen, put up at the fade's middle; the level on the stage
	// once they're done (and pressed through).
	function startPlay():Void {
		var level = new Play();
		play = level;
		var screen = new Loading(level.loader);
		screen.holdForPress = Host.getOptionBool("clickToContinue", true);
		screen.text = "Loading the field";
		screen.tip = Host.getOption("tip", "");
		loading = screen;
		fade(new Fade(.6), () -> {
			Stage.removeChild(title);
			state = "Play";
			visited.push("Play");
			screen.show(() -> {
				loading = null;
				Stage.addChild(level);
			});
		});
	}

	// The screens' keys for a tick of dt seconds, read from input (the window's, or the autopilot's).
	function step(dt:Float):Void {
		if (transition != null && transition.running)
			return;
		switch state {
			case "Title":
				if (Input.isFramePressed(Key.Enter) || Input.pointerFramePressed)
					startPlay();
				else if (Input.isFramePressed(Key.Escape) && Host.canQuit())
					Host.quit();
			case "Play":
				var level = play;
				if (level == null || loading != null)
					return;
				level.advance(dt);
				if (Input.isFramePressed(Key.Escape))
					fade(new Fade(.3, 0x80000000), () -> {
						// The level waits under the menu, still drawn.
						level.paused = true;
						enter("Pause", pause);
					});
			case "Pause":
				var level = play;
				if (Input.isFramePressed(Key.Escape))
					fade(new Fade(.3, 0x80000000), () -> {
						Stage.removeChild(pause);
						if (level != null)
							level.paused = false;
						state = "Play";
					});
				else if (Input.isFramePressed(Key.T))
					fade(new Fade(.6), () -> {
						Stage.removeChild(pause);
						if (level != null)
							Stage.removeChild(level);
						play = null;
						enter("Title", title);
					});
			default:
		}
	}

	override public function probe(name:String):Dynamic {
		return switch name {
			case "scene": state;
			case "count": state == "Pause" ? 2 : state == "" ? 0 : 1;
			case "loaded": play == null || play.loader.done;
			case "loading": loading != null;
			case "visited": visited.length;
			case "activated": Input.activated;
			case "transitioning": transition != null && transition.running;
			default: throw 'Unknown probe ' + name;
		}
	}

	override public function update(dt:Float):Void {
		// A step of the screens: under an autopilot, one of its ticks (dt a sixtieth of a second, App.probe), many a frame when fast; a press
		// ends the frame's ticks, so the splash, the loading screen and the transitions, which run once a frame after this, read it. Otherwise
		// the game's clock's step (held while it's paused).
		step(autopilot != null && !autopilot.done ? dt : Time.clock.delta);
		// The screens drawn again for the visible area as it is now.
		ScreenShape.update();
		title.layout();
		pause.layout();
		if (play != null)
			play.layout();
	}
}

/** A screen: a node on the stage covering the visible area in its color, with a title and a line of help in the design for the window's
	shape. */
class Page extends Node2D {
	var drawing = new Drawing2D();
	var color:Int;
	var title:String;
	var help:String;

	/** A screen named name, in color, showing title and help. */
	public function new(name:String, color:Int, title:String, help:String) {
		super();
		this.name = name;
		this.color = color;
		this.title = title;
		this.help = help;
		addChild(drawing);
	}

	/** Draws it again for the visible area as it is now. */
	public function layout():Void {
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth,
			vh = Screen.visibleHeight;
		drawing.clear();
		drawing.rect(vx, vy, vw, vh, color);
		var y = vy + 36;
		y += drawing.drawTextWrapped(title, vx + 12, y, 22, vw - 24, 0xfff5f5f5) + 4;
		drawing.drawTextWrapped(help, vx + 12, y, 15, vw - 24, 0xffc8c8c8);
	}
}

/** The level: its two textures load first (loader), behind the loading screen; then the logo bounces about, the tiles sheet in the
	corner. */
class Play extends Page {
	var logo = new Sprite2D(null);
	var tiles = new Sprite2D(null);
	var time = 0.;

	/** Its loads. */
	public var loader(default, null) = new Loader();

	/** The level, its loads started. */
	public function new() {
		super("Play", 0xff10281c, "Playing", "Escape: pause");
		logo.setSize(120, 120);
		tiles.setSize(120, 120);
		logo.setPivot(.5, .5);
		tiles.setPivot(.5, .5);
		addChild(logo);
		addChild(tiles);
		loader.texture("sprites/logo/wg-logo-white-alpha.png", true, texture -> logo.texture = texture);
		loader.texture("textures/tiles.png", false, texture -> tiles.texture = texture);
	}

	/** dt seconds of play. */
	public function advance(dt:Float):Void
		time += dt;

	override public function layout():Void {
		super.layout();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth,
			vh = Screen.visibleHeight;
		// The logo bouncing across, the tiles sheet in the corner.
		logo.setPosition(vx + 60 + (vw - 120 - 120) * (.5 + .5 * Math.sin(time * 1.2)), vy + vh * .45 + Ease.bounceOut((time * .7) % 1) * 80 - 40);
		tiles.setPosition(vx + vw - 140, vy + vh - 140);
	}
}
