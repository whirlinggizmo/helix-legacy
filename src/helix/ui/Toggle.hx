package helix.ui;

import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.Text2D;

/** A box that's on or off, beside a line of text: switched by a click or by activating it with focus. Ask on, and changed once a
	frame. */
class Toggle extends Widget {
	var face:Shape2D;
	var check:Shape2D;
	var mark:Shape2D;
	var label:Text2D;
	var value:Bool;
	var row:Layout2D;

	@:allow(helix.ui.Ui)
	function new(ui:Ui, name:String, text:String, value:Bool) {
		super(ui, name);
		this.value = value;
		var theme = ui.theme;
		face = Shape2D.rectangle(1, 1, 0);
		face.setPivot(0, 0);
		check = Shape2D.rectangle(1, 1, theme.faceColor);
		check.setPivot(0, 0);
		check.pickable = false;
		mark = Shape2D.rectangle(1, 1, theme.accentColor);
		mark.setPivot(0, 0);
		mark.pickable = false;
		label = new Text2D(text, theme.textSize, theme.textColor, theme.font);
		for (n in [face, check, mark, label])
			root.addChild(n);
		var tick = Layout2D.of(mark), square = Layout2D.of(check);
		row = Layout2D.row();
		tick.setAnchor(Center, Center);
		square.add(tick);
		row.setAlign(Start, Center);
		row.setAnchor(Start, Center);
		row.add(square);
		row.add(Layout2D.of(label));
		layout = Layout2D.stack(face);
		layout.add(row);
		readTheme(theme);
	}

	/** Whether it's on. */
	public var on(get, set):Bool;

	function get_on():Bool
		return value;

	function set_on(on:Bool):Bool {
		value = on;
		return on;
	}

	/** Whether it was switched this frame. */
	public var changed(default, null):Bool = false;

	override function get_focusable():Bool
		return true;

	override function target():Null<Node2D>
		return face;

	// The mark textSize - 4 square, the box around it sized by the layout to it.
	override function readTheme(theme:Theme):Void {
		var side = theme.textSize - 4;
		if (mark.width != side)
			mark.setSize(side, side);
		check.cornerRadius = theme.cornerRadius / 2;
		mark.cornerRadius = theme.cornerRadius / 4;
		label.textSize = theme.textSize;
		label.font = theme.font;
		row.themeGap(theme.gap);
		themeFixed(layout, Math.NaN, theme.widgetHeight);
	}

	override function update(hovered:Bool, held:Bool, clicked:Bool, focused:Bool, activated:Bool, stepX:Int, stepY:Int):Void {
		var theme = ui.theme,
			state = WidgetState.of(enabled, held, hovered, focused);
		changed = enabled && (clicked || activated);
		if (changed)
			value = !value;
		check.color = state.face(theme);
		mark.visible = value;
		mark.color = state == Disabled ? WidgetState.dim(theme.accentColor) : theme.accentColor;
		label.color = state.text(theme);
	}
}
