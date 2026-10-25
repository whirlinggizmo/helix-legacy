import helix.asset.Assets;
import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.time.Time;
import helix.host.ScreenShape;

/** The desktop pulls its files from the same site the browser does. In the browser the page fetches each file beside it and caches it; natively,
	files are read from the program's packaged directory unless HELIX_ASSET_HOST names a host (python3 -m http.server in examples/assets, say), which
	is asked first whether it answers: then a cache miss downloads the file into the program's cache. Fetch asset (F) loads the logo again, and says
	whether it came from the cache or was downloaded; Clear cache (C) forgets what was downloaded, so the next fetch downloads it again. Escape quits
	where quitting means anything. The page is a Drawing2D on the stage, drawn again each update; the two buttons are drawn and hit-tested
	here. */
class App extends helix.App {
	static inline var TEXTURE = "sprites/logo/wg-logo-white-alpha.png";

	var page = new Drawing2D();
	var fps = new FpsOverlay();
	var logo:Null<Texture2D>;
	var source = "";
	var state = "";
	var asking = false;
	var waiting = false;

	override public function init():Void {
		Window.title = "HeliX asset fetch";
		Window.requestSize(800, 520);
		Stage.color = 0xff1c1e26;
		Stage.addChild(page);
		Stage.addChild(fps);
		var url = Assets.host;
		if (url == null) {
			source = "the packaged files";
			fetch();
		} else if (url.indexOf("://") < 0) {
			// The browser: the page fetches files beside it.
			source = url + " beside the page";
			fetch();
		} else {
			asking = true;
			state = 'asking $url...';
			Assets.pingHost(url, TEXTURE, 2, answered -> {
				asking = false;
				if (answered)
					source = url;
				else {
					Assets.setHost(null);
					source = 'the packaged files ($url didn\'t answer)';
				}
				fetch();
			});
		}
	}

	/** Loads the logo again, watching whether it's downloaded or read from the cache. */
	function fetch():Void {
		if (logo != null)
			Textures.release(logo);
		logo = null;
		waiting = true;
		state = 'fetching $TEXTURE...';
		var downloaded = false;
		// Now cached: the texture reads it from there.
		Assets.ensure(TEXTURE, _ -> Textures.load(TEXTURE, Linear, texture -> show(texture, downloaded), message -> fail(message)), message -> fail(message),
			progress -> if (progress.phase == "downloading") downloaded = true);
	}

	// The logo in, from where it came.
	function show(texture:Texture2D, downloaded:Bool):Void {
		logo = texture;
		waiting = false;
		state = Assets.host == null ? 'read $TEXTURE from the packaged files' : downloaded ? 'downloaded $TEXTURE into the cache' : 'loaded $TEXTURE from the cache';
	}

	// The fetch failed: said on the screen.
	function fail(message:String):Void {
		waiting = false;
		state = message;
	}

	function clearCache():Void
		Assets.clearCache(result -> state = switch result {
			case Written: "cache cleared: the next fetch downloads";
			case Failed(message): "cache not cleared: " + message;
			case Cancelled: state;
		});

	override public function update(dt:Float):Void {
		// The design for the window's shape: the text wrapped to what's visible of it, the buttons under it (laid out before the pointer is
		// tested against them), the logo centered below.
		ScreenShape.update();
		var font = Stage.font;
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		fps.update(dt, Time.frameCpu);
		fps.setPosition(vx + 12, vy + 8);
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		var from = "from: " + (asking ? "..." : source);
		var titleY = vy + 40;
		var fromY = titleY + font.measureWrapped("HeliX asset fetch", 24, vw - 24) + 10;
		var stateY = fromY + font.measureWrapped(from, 16, vw - 24) + 10;
		var buttonY = stateY + font.measureWrapped(state, 16, vw - 24) + 20;
		var camera = Stage.camera;
		var x = camera.screenToWorldX(Input.pointerX),
			y = camera.screenToWorldY(Input.pointerY);
		var clicked = Input.pointerFramePressed;
		if ((Input.isFramePressed(Key.F) || clicked && inside(x, y, vx + 12, buttonY)) && !waiting && !asking)
			fetch();
		if (Input.isFramePressed(Key.C) || clicked && inside(x, y, vx + 204, buttonY))
			clearCache();
		page.clear();
		page.drawTextWrapped("HeliX asset fetch", vx + 12, titleY, 24, vw - 24, 0xfff5f5f5);
		page.drawTextWrapped(from, vx + 12, fromY, 16, vw - 24, 0xffc8c8c8);
		page.drawTextWrapped(state, vx + 12, stateY, 16, vw - 24, 0xffffcb00);
		button("Fetch asset", vx + 12, buttonY, inside(x, y, vx + 12, buttonY));
		button("Clear cache", vx + 204, buttonY, inside(x, y, vx + 204, buttonY));
		if (logo != null)
			page.image(logo, vx + vw / 2 - 110, buttonY + BUTTON_HEIGHT + 60, 220, 220);
	}

	static inline var BUTTON_WIDTH = 180;
	static inline var BUTTON_HEIGHT = 40;

	static function inside(x:Float, y:Float, left:Float, top:Float):Bool
		return x >= left && x < left + BUTTON_WIDTH && y >= top && y < top + BUTTON_HEIGHT;

	function button(label:String, x:Float, y:Float, hover:Bool):Void {
		page.roundedRect(x, y, BUTTON_WIDTH, BUTTON_HEIGHT, 6, hover ? 0xff3d4a66 : 0xff2b3448);
		page.drawText(label, x + BUTTON_WIDTH / 2, y + 11, 17, 0xfff5f5f5, Center);
	}
}
