package helix.ui;

import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.Text2D;

/** A button reading a line of text: clicked by the pointer (released over it, as pressed), or activated with focus by Enter, Space or a pad's
	South. Ask clicked once a frame. */
class Button extends Widget {
	var face:Shape2D;
	var label:Text2D;

	@:allow(helix.ui.Ui)
	function new(ui:Ui, name:String, text:String) {
		super(ui, name);
		var theme = ui.theme;
		face = Shape2D.rectangle(1, 1, theme.faceColor);
		face.setPivot(0, 0);
		label = new Text2D(text, theme.textSize, theme.textColor, theme.font);
		label.setPivot(.5, 0);
		root.addChild(face);
		root.addChild(label);
		layout = Layout2D.stack(face);
		var text = Layout2D.of(label);
		text.setAnchor(Center, Center);
		layout.add(text);
		readTheme(theme);
	}

	/** Whether it was clicked or activated this frame. */
	public var clicked(default, null):Bool = false;

	/** Its text. */
	public var text(get, set):String;

	function get_text():String
		return label.text;

	function set_text(value:String):String {
		label.text = value;
		return value;
	}

	override function get_focusable():Bool
		return true;

	override function target():Null<Node2D>
		return face;

	override function readTheme(theme:Theme):Void {
		face.cornerRadius = theme.cornerRadius;
		label.textSize = theme.textSize;
		label.font = theme.font;
		themeFixed(layout, Math.NaN, theme.widgetHeight);
		layout.themePadding(theme.padding * 2, 0, theme.padding * 2, 0);
	}

	override function update(hovered:Bool, held:Bool, clicked:Bool, focused:Bool, activated:Bool, stepX:Int, stepY:Int):Void {
		var theme = ui.theme,
			state = WidgetState.of(enabled, held, hovered, focused);
		this.clicked = enabled && (clicked || activated);
		face.color = state.face(theme);
		label.color = state.text(theme);
	}
}
