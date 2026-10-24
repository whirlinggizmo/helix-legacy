package helix.ui;

import helix.font.Font;
import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.Text2D;

/** A value from min to max in steps (0: any), beside a line of text: dragged along its track by the pointer, or stepped by Left and Right
	with focus (a tenth of the way without steps). Ask value, and changed once a frame. */
class Slider extends Widget {
	var face:Shape2D;
	var track:Shape2D;
	var fill:Shape2D;
	var knob:Handle;
	var label:Text2D;
	var readout:Text2D;
	var readoutLayout:Layout2D;
	var readoutWidth = -1.;
	// What the readout's width was measured for: its font and size, whether it's shown (measured again only when one changes).
	var readoutFont:Null<Font>;
	var readoutSize = -1.;
	var readoutShown = false;
	var trackLayout:Layout2D;
	var row:Layout2D;
	var min:Float;
	var max:Float;
	var step:Float;

	@:allow(helix.ui.Ui)
	function new(ui:Ui, name:String, text:String, min:Float, max:Float, value:Float, step:Float) {
		super(ui, name);
		this.min = min;
		this.max = max > min ? max : min;
		this.step = step;
		this.value = snap(value);
		var theme = ui.theme;
		face = Shape2D.rectangle(1, 1, 0);
		face.setPivot(0, 0);
		label = new Text2D(text, theme.textSize, theme.textColor, theme.font);
		track = Shape2D.rectangle(1, 1, theme.faceColor);
		track.setPivot(0, 0);
		track.pickable = false;
		fill = Shape2D.rectangle(1, 1, theme.accentColor);
		fill.setPivot(0, 0);
		fill.pickable = false;
		readout = new Text2D("", theme.textSize, theme.textColor, theme.font);
		readout.setPivot(1, 0);
		readout.visible = false;
		for (n in [face, track, fill, label, readout])
			root.addChild(n);
		knob = new Handle(root, theme);
		trackLayout = Layout2D.of(track);
		trackLayout.themeSizing(Grow(1), Fit);
		row = Layout2D.row();
		row.setAlign(Start, Center);
		row.setAnchor(Stretch, Center);
		row.add(Layout2D.of(label));
		row.add(trackLayout);
		readoutLayout = Layout2D.of(readout);
		readoutLayout.themeSizing(Fixed(0), Fit);
		row.add(readoutLayout);
		layout = Layout2D.stack(face);
		layout.themeSizing(Grow(1), Fit);
		layout.add(row);
		readTheme(theme);
	}

	/** Its value. */
	public var value(default, set):Float;

	function set_value(v:Float):Float {
		value = snap(v);
		return v;
	}

	/** Whether its value is shown as a number after its track, to as many decimals as its step has (2 without steps, 3 at most). (False to
		start.) */
	public var valueShown:Bool = false;

	/** Its value as valueShown writes it. */
	public function formatValue():String
		return format(value);

	function format(value:Float):String {
		var decimals = step > 0 ? Std.int(Math.max(0, Math.min(3, Math.ceil(-Math.log(step) / Math.log(10) - 1e-9)))) : 2;
		var scaled = Math.round(Math.abs(value) * Math.pow(10, decimals)),
			digits = Std.string(scaled);
		if (decimals > 0) {
			digits = StringTools.lpad(digits, "0", decimals + 1);
			digits = digits.substr(0, digits.length - decimals) + "." + digits.substr(digits.length - decimals);
		}
		return (value < 0 && scaled != 0 ? "-" : "") + digits;
	}

	/** Whether its value changed this frame. */
	public var changed(default, null):Bool = false;

	function snap(v:Float):Float {
		v = Math.max(min, Math.min(max, v));
		return step > 0 ? Math.max(min, Math.min(max, min + Math.round((v - min) / step) * step)) : v;
	}

	override function get_focusable():Bool
		return true;

	override function takesSideways():Bool
		return true;

	override function target():Null<Node2D>
		return face;

	// "track": the line its value runs along, min at its left edge, max at its right.
	override function locatePart(part:String, out:Array<Float>):Null<Node2D> {
		if (part != "track")
			return super.locatePart(part, out);
		Widget.setRectangle(out, trackLayout.x, trackLayout.y, trackLayout.width, trackLayout.height);
		return root;
	}

	override function readTheme(theme:Theme):Void {
		label.textSize = readout.textSize = theme.textSize;
		label.font = readout.font = theme.font;
		track.cornerRadius = fill.cornerRadius = theme.trackThickness / 2;
		themeFixed(trackLayout, Math.NaN, theme.trackThickness);
		row.themeGap(theme.gap * 2);
		knob.readTheme(theme);
		themeFixed(layout, Math.NaN, theme.widgetHeight);
	}

	override function update(hovered:Bool, held:Bool, clicked:Bool, focused:Bool, activated:Bool, stepX:Int, stepY:Int):Void {
		var theme = ui.theme, was = value;
		if (enabled && held) {
			// The pointer's place along the track, in the track's own units.
			var camera = ui.camera, input = ui.input;
			var wx = camera.screenToWorldX(input.pointerX),
				wy = camera.screenToWorldY(input.pointerY);
			var along = trackLayout.width > 0 ? track.toLocalX(wx, wy) / trackLayout.width : 0;
			value = snap(min + Math.max(0, Math.min(1, along)) * (max - min));
		}
		if (enabled && stepX != 0)
			value = snap(value + stepX * (step > 0 ? step : (max - min) / 10));
		changed = value != was;
		// The fill and knob where the value is along the track, as the layout last placed it.
		var fraction = max > min ? (value - min) / (max - min) : 0;
		fill.setSize(Math.max(0, trackLayout.width * fraction), trackLayout.height);
		fill.setPosition(trackLayout.x, trackLayout.y);
		knob.setPosition(trackLayout.x + trackLayout.width * fraction, trackLayout.y + trackLayout.height / 2);
		// The knob is over or held wherever the pointer is on the slider, as a press anywhere on it moves the knob there; focus shows in the ring,
		// not the knob.
		var state = WidgetState.of(enabled, held, hovered, focused);
		knob.color = WidgetState.of(enabled, held, hovered, false).handle(theme);
		track.color = state == Disabled ? WidgetState.dim(theme.faceColor) : theme.faceColor;
		fill.color = state == Disabled ? WidgetState.dim(theme.accentColor) : theme.accentColor;
		label.color = state.text(theme);
		// The number after the track, as wide as the widest of min's and max's, so the track doesn't move as it changes: measured when it's
		// shown, its font or its size changed.
		readout.visible = valueShown;
		var font = theme.font != null ? theme.font : ui.font;
		if (valueShown != readoutShown || font != readoutFont || theme.textSize != readoutSize) {
			readoutShown = valueShown;
			readoutFont = font;
			readoutSize = theme.textSize;
			var width = !valueShown
				|| font == null ? 0. : Math.max(font.measure(format(min), theme.textSize), font.measure(format(max), theme.textSize));
			if (width != readoutWidth) {
				readoutWidth = width;
				readoutLayout.themeSizing(Fixed(width), null);
			}
		}
		if (valueShown) {
			readout.text = formatValue();
			readout.color = label.color;
		}
	}
}
