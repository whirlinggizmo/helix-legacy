package helix.ui;

import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.Text2D;

/** A box that's on or off, beside a line of text: switched by a click or by activating it with focus, on showing a check mark in the
	theme's accent color whose long stroke runs a little past the box's top right. Ask on, and changed once a frame. */
class Toggle extends Widget {
	var face:Shape2D;
	var check:Shape2D;
	var mark:Shape2D;
	var square:Layout2D;
	var markSide = -1.;
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
		// The mark a child of the box, in the box's own units, drawn over it.
		mark = Shape2D.polygon([0, 0, 1, 0, 0, 1], theme.accentColor);
		mark.pickable = false;
		check.addChild(mark);
		label = new Text2D(text, theme.textSize, theme.textColor, theme.font);
		for (n in [face, check, label])
			root.addChild(n);
		square = Layout2D.of(check);
		row = Layout2D.row();
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

	// The box textSize - 4 square, the mark made again for it when that changes.
	override function readTheme(theme:Theme):Void {
		var side = theme.textSize - 4;
		themeFixed(square, side, side);
		if (side != markSide) {
			markSide = side;
			mark.setPoints(checkMark(side));
		}
		check.cornerRadius = theme.cornerRadius / 2;
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

	// A check mark for a box side units square, as a filled outline in the box's units: a short stroke down to the right, then a long one
	// up past the box's top right, a sixth of the side thick, mitred where they meet.
	static function checkMark(side:Float):Array<Float> {
		var ax = .2 * side,
			ay = .5 * side,
			bx = .42 * side,
			by = .76 * side,
			cx = 1.1 * side,
			cy = -.1 * side;
		var half = side / 12;
		// Each stroke's unit normal (to its left as drawn), and the mitre at the bend: along the normals' bisector, as far as keeps both
		// strokes half as thick.
		var n1x = -(by - ay), n1y = bx - ax, l1 = Math.sqrt(n1x * n1x + n1y * n1y);
		n1x /= l1;
		n1y /= l1;
		var n2x = -(cy - by), n2y = cx - bx, l2 = Math.sqrt(n2x * n2x + n2y * n2y);
		n2x /= l2;
		n2y /= l2;
		var mx = n1x + n2x, my = n1y + n2y, ml = Math.sqrt(mx * mx + my * my);
		mx /= ml;
		my /= ml;
		var miter = half / (mx * n1x + my * n1y);
		return [
			ax + n1x * half, ay + n1y * half,
			bx + mx * miter, by + my * miter,
			cx + n2x * half, cy + n2y * half,
			cx - n2x * half, cy - n2y * half,
			bx - mx * miter, by - my * miter,
			ax - n1x * half, ay - n1y * half
		];
	}
}
