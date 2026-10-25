package helix.scene;

import helix.host.Screen;
import helix.input.Input;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.ui.Theme;

/** The built-in loading screen (docs/DISPLAY_MODEL.md): the theme's panel color or a picture (setImage: a level's art, covering the screen or
	centered), a caption ("Loading the caves", text; "Loading" unless given) over a bar of its loader's progress and the count, a tip along
	the bottom (tip), and what failed in the disabled text color. Shown on the stage (show) over what's there until its loader is done, then
	taken off and then called: put the level on the stage there. With holdForPress it stays once loaded, saying so, until a press (the
	"loaded, go" screen of a movie-like opening). It runs itself; quick (the run option quick=1) doesn't hold. */
class LoadingScreen {
	var cover = true;
	var drawing = new Drawing2D();

	/** A loading screen of loader's progress, in theme's look (a new Theme unless given). */
	public function new(loader:Loader, ?theme:Theme) {
		this.loader = loader;
		this.theme = theme != null ? theme : new Theme();
	}

	/** The loads it shows. */
	public var loader(default, null):Loader;

	/** The theme it draws with. */
	public var theme:Theme;

	/** Its picture, or null. */
	public var image(default, null):Null<Texture2D>;

	/** A picture behind the rest: covering the screen (cropped to its shape) when cover, else centered whole; null for the panel color alone. */
	public function setImage(value:Null<Texture2D>, cover = true):Void {
		image = value;
		this.cover = cover;
	}

	/** The caption over the bar: what's loading ("Loading the caves"). */
	public var text:String = "Loading";

	/** A line along the bottom (a hint, a credit), wrapped; "" for none. */
	public var tip:String = "";

	/** Whether it stays once the loads are done, showing the prompt, until a key, a button or a finger is pressed. */
	public var holdForPress:Bool = false;

	/** The line shown once loaded, while holding for a press. */
	public var prompt:String = "press any key";

	/** Whether it's on the stage now. */
	public var shown(default, null):Bool = false;

	/** Puts it on the stage, over what's there, until its loader is done (and a press, with holdForPress), then takes it off and calls then.
		False, doing nothing, while it's shown already. */
	public function show(then:Void->Void):Bool {
		if (shown)
			return false;
		shown = true;
		Stage.addChild(drawing);
		Flow.run(_ -> {
			var holding = holdForPress && !Flow.quick;
			if (loader.done && (!holding || Input.anyFramePressed)) {
				Stage.removeChild(drawing);
				shown = false;
				then();
				return false;
			}
			draw(holding);
			return true;
		});
		return true;
	}

	// The screen as it is now, drawn again.
	function draw(holding:Bool):Void {
		var p = Screen.instance;
		var vx = p.visibleX,
			vy = p.visibleY,
			vw = p.visibleWidth,
			vh = p.visibleHeight;
		var d = drawing;
		d.clear();
		d.rect(vx, vy, vw, vh, theme.panelColor);
		if (image != null) {
			// Covering: scaled to fill the visible area, its middle kept; else whole, centered, as large as fits.
			var iw = image.width, ih = image.height;
			var scale = cover ? Math.max(vw / iw, vh / ih) : Math.min(vw / iw, vh / ih);
			var w = iw * scale, h = ih * scale;
			d.image(image, vx + (vw - w) / 2, vy + (vh - h) / 2, w, h);
		}
		var barWidth = Math.min(360, vw - 80),
			x = vx + (vw - barWidth) / 2,
			y = vy + vh / 2;
		d.drawText(loader.done && holding ? "Loaded" : text, vx + vw / 2, y - 40, theme.textSize * 1.2, theme.textColor, Center, theme.font);
		d.rect(x, y, barWidth, 10, theme.faceColor);
		d.rect(x, y, barWidth * loader.progress, 10, theme.accentColor);
		var count = loader.done && holding ? prompt : '${loader.doneCount} of ${loader.count}';
		d.drawText(count, vx + vw / 2, y + 24, theme.textSize * .8, theme.disabledTextColor, Center, theme.font);
		if (tip != "")
			d.drawTextWrapped(tip, vx + vw / 2, vy + vh - 60, theme.textSize * .8, vw - 80, theme.disabledTextColor, Center, 1.25, theme.font);
		var line = y + 56;
		for (failure in loader.failures) {
			d.drawText(failure, vx + vw / 2, line, theme.textSize * .8, theme.disabledTextColor, Center, theme.font);
			line += theme.textSize;
		}
	}
}
