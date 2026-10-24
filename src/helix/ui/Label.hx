package helix.ui;

import helix.render2d.Text2D;

/** A line of text: shown, never focused. Its size and color are the theme's unless given its own (textSize, color). */
class Label extends Widget {
	@:allow(helix.ui.Ui)
	function new(ui:Ui, name:String, text:String) {
		super(ui, name);
		var theme = ui.theme;
		node = new Text2D(text, theme.textSize, theme.textColor, theme.font);
		root.addChild(node);
		layout = Layout2D.of(node);
		readTheme(theme);
	}

	/** Its text. */
	public var text(get, set):String;

	function get_text():String
		return node.text;

	function set_text(value:String):String {
		node.text = value;
		return value;
	}

	// Its text node, its size, color and font from textSize, color and the theme at each update.
	var node:Text2D;

	/** Its text's height in units, or null (to start) for the theme's textSize: a value is kept whatever the theme becomes. */
	public var textSize:Null<Float> = null;

	/** Its text's color, 0xAARRGGBB, or null (to start) for the theme's textColor: a value is kept whatever the theme becomes. */
	public var color:Null<Int> = null;

	override function readTheme(theme:Theme):Void {
		node.textSize = textSize != null ? textSize : theme.textSize;
		node.color = color != null ? color : theme.textColor;
		node.font = theme.font;
	}
}
