package helix.ui;

import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.render2d.Shape2D;
import helix.render2d.Text2D;
import helix.texture.Texture2D;

/** A background holding a column of widgets (add): hidden, they're hidden with it. A plain rectangle in the theme's panel color, or a nine-slice
	frame (setFrame); with a title, a band across its top holding it, the column under the band. Never focused; the pointer stops at it, so
	what's under a panel doesn't see it. */
class Panel extends Widget {
	var background:Node2D;
	var rectangle:Shape2D;
	// The band and the column, top to bottom, over the background.
	var body:Layout2D;
	// The title's band: its face clipped to the band (band, its clip) so only its top corners are round, its text in the band's layout.
	var band:Node2D;
	var bandFace:Shape2D;
	var bandText:Text2D;
	var bandLayout:Layout2D;

	@:allow(helix.ui.Ui)
	function new(ui:Ui, name:String) {
		super(ui, name);
		var theme = ui.theme;
		rectangle = Shape2D.rectangle(1, 1, theme.panelColor);
		rectangle.setPivot(0, 0);
		background = rectangle;
		root.addChild(background);
		band = new Node2D();
		bandFace = Shape2D.rectangle(1, 1, theme.faceColor);
		bandFace.setPivot(0, 0);
		bandFace.pickable = false;
		bandText = new Text2D("", theme.textSize, theme.textColor, theme.font);
		bandText.pickable = false;
		band.addChild(bandFace);
		band.visible = false;
		root.addChild(band);
		root.addChild(bandText);
		bandText.visible = false;
		bandLayout = Layout2D.stack();
		var words = Layout2D.of(bandText);
		words.setAnchor(Start, Center);
		bandLayout.add(words);
		content = Layout2D.column();
		content.setAlign(Start, Stretch);
		body = Layout2D.column();
		body.setAlign(Start, Stretch);
		body.setAnchor(Stretch, Stretch);
		body.add(content);
		layout = Layout2D.stack(background);
		layout.add(body);
		readTheme(theme);
	}

	// The rectangle's color and corners (unused under a frame), the column's padding and gap, the theme's unless a game set its own; the title's
	// band in the faces' color, its text the theme's, as tall as a line of text and a padding, its text a padding in.
	override function readTheme(theme:Theme):Void {
		rectangle.color = theme.panelColor;
		rectangle.cornerRadius = theme.cornerRadius;
		var pad = theme.padding;
		content.themePadding(pad, pad, pad, pad);
		content.themeGap(theme.gap);
		bandFace.color = theme.faceColor;
		bandFace.cornerRadius = theme.cornerRadius;
		bandText.textSize = theme.textSize;
		bandText.color = theme.textColor;
		bandText.font = theme.font;
		themeFixed(bandLayout, Math.NaN, theme.textSize + pad);
		bandLayout.themePadding(pad, 0, pad, 0);
	}

	/** Its title, drawn in a band across its top with its widgets under it, or null or "" (to start) for none. */
	public var title(default, set):Null<String> = null;

	function set_title(value:Null<String>):Null<String> {
		title = value;
		var shown = value != null && value != "";
		bandText.text = shown ? value : "";
		bandText.visible = band.visible = shown;
		var has = body.children.indexOf(bandLayout) >= 0;
		if (shown && !has) {
			body.remove(content);
			body.add(bandLayout);
			body.add(content);
		} else if (!shown && has)
			body.remove(bandLayout);
		return value;
	}

	// The band where the layout last placed it: its face as wide as the band and a corner taller, clipped to the band, so its bottom corners
	// are cut square and its top ones follow the panel's.
	override function update(hovered:Bool, held:Bool, clicked:Bool, focused:Bool, activated:Bool, stepX:Int, stepY:Int):Void {
		if (!band.visible)
			return;
		band.setPosition(bandLayout.x, bandLayout.y);
		band.setClip(bandLayout.width, bandLayout.height);
		bandFace.setSize(bandLayout.width, bandLayout.height + bandFace.cornerRadius);
	}

	/** Puts widget in it, last in its column: its nodes under the panel's (hidden with it), its layout in the column. */
	public function add(widget:Widget):Void {
		widget.root.parent = null;
		root.addChild(widget.root);
		content.add(widget.layout);
	}

	/** The column its widgets go in, for layouts of other kinds (a row of buttons: put the buttons' layouts in a row, and the buttons in the
		panel with adopt). */
	public var content(default, null):Layout2D;

	/** Puts widget's nodes under the panel's (hidden with it) without placing it: its layout goes in one of the caller's inside this.content. */
	public function adopt(widget:Widget):Void {
		widget.root.parent = null;
		root.addChild(widget.root);
	}

	// Its nine-slice frame (setFrame), or null for the theme's rectangle.
	var frame:Null<Sprite2D>;

	/** Draws it as texture's nine-slice frame, its corners left, top, right and bottom texels in, tinted tint. False, changing nothing, for no texture. */
	public function setFrame(texture:Null<Texture2D>, left:Float, top:Float, right:Float, bottom:Float, tint = 0xffffffff):Bool {
		if (texture == null)
			return false;
		frame = new Sprite2D(texture);
		frame.tint = tint;
		frame.setPivot(0, 0);
		frame.setNineSlice(left, top, right, bottom);
		// In the background's place, first: under its widgets.
		root.removeChild(background);
		var others = [for (i in 0...root.childCount) root.getChild(i)];
		for (n in others)
			root.removeChild(n);
		root.addChild(frame);
		for (n in others)
			root.addChild(n);
		background = frame;
		layout = Layout2D.stack(background);
		layout.add(body);
		return true;
	}

	override function target():Null<Node2D>
		return background;
}
