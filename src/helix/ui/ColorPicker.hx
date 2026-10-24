package helix.ui;

import helix.graphics.Color;
import helix.font.Font;
import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.ShapeShading2D;
import helix.render2d.Text2D;

/** A color, 0xAARRGGBB, chosen as hue, saturation and brightness (HSV's value). Top to bottom: a square of saturation (left to right) and
	brightness (bottom to top) in the hue, edge to edge across the picker and as tall as it's wide; under it a strip of a round swatch of
	the color (over a checkerboard, as its alpha shows it) beside thin bars, the hue's (left to right red, yellow, green, cyan, blue, magenta
	and red again) and with alpha the alpha's under it (clear at the left, opaque at the right), each with a round handle; then a text field
	writing the color in its format (textField, a TextField of its own), a button beside it cycling the format (formatButton) and the format's
	name under the field. The pointer drags in the square or a bar, the part it went down on, wherever it moves after. With focus, Enter,
	Space or a pad's South steps through the parts the arrows and the D-pad drive: the square (Left and Right saturation, Up and Down
	brightness), the hue bar, the alpha bar (Right and Up raise, Left and Down lower) and none, when they move focus again; each step a
	twentieth of the way. The part they drive has its handle in the theme's focus color. The field takes the color in its format (Hex:
	RRGGBBAA or RRGGBB, with or without a leading #, in either case; Rgba: r g b a or r g b, 0 to 255 each, apart by spaces or a comma),
	without alpha meaning 0xff: the color follows it as typed, text naming no color is marked invalid (TextField.invalid) and changes nothing,
	and once the field loses focus it shows the color again. Its hue (and saturation) are kept where the color doesn't say them: dragging
	through grey or black doesn't lose the hue. It's as wide as its layout is given: theme.colorPickerWidth (layout sized Fixed that wide,
	following the theme until the game sizes its layout's width itself, kept in a column stretching its children, a panel's), or what
	a column gives it sized Grow(1); the square takes a new width a frame later.
	Ask color, and changed once a frame. */
class ColorPicker extends Widget {
	// The parts the pointer or the keys work in.
	static inline var NONE = 0;
	static inline var SQUARE = 1;
	static inline var HUE = 2;
	static inline var ALPHA = 3;
	// Held on nothing it drags (the strip's padding, the swatch).
	static inline var ELSEWHERE = -1;
	// A key's step, as a fraction of the way.
	static inline var STEP = 1 / 20;
	// The checkerboard's light and dark squares under what has alpha.
	static inline var LIGHT = 0xffcccccc;
	static inline var DARK = 0xff888888;

	var face:Shape2D;
	var squareHue:Shape2D;
	var whiteRamp:Shape2D;
	var blackRamp:Shape2D;
	var hueGroup = new Node2D();
	var hueBands:Array<Shape2D> = [];
	var hueStart:Shape2D;
	var hueEnd:Shape2D;
	var alphaGroup = new Node2D();
	var alphaBase:Shape2D;
	var alphaChecks = new Node2D();
	var alphaChecksPool:Array<Shape2D> = [];
	var alphaRamp:Shape2D;
	var alphaEnd:Shape2D;
	var swatchGroup = new Node2D();
	var swatchBase:Shape2D;
	var swatchChecks = new Node2D();
	var swatchChecksPool:Array<Shape2D> = [];
	var swatchColor:Shape2D;
	var swatchEdge:Shape2D;
	var squareShadow:Shape2D;
	var squareMark:Shape2D;
	var hueKnob:Handle;
	var alphaKnob:Handle;
	var caption:Text2D;
	var squareLayout:Layout2D;
	var hueLayout:Layout2D;
	var alphaLayout:Null<Layout2D>;
	var swatchLayout:Layout2D;
	var strip:Layout2D;
	var bars:Layout2D;
	var textRow:Layout2D;
	var fieldColumn:Layout2D;
	// The field's width and height as last sized, and what its widest text was measured for (font, size): measured again when one changes.
	var fieldWidth = 0.;
	var fieldHeight = Math.NaN;
	var fieldFont:Null<Font>;
	var fieldSize = -1.;
	var widest = 0.;
	var alphaChecked = -1.;
	var swatchChecked = -1.;
	// From the theme (readTheme): a bar's thickness, a handle's radius, the height of a bar's row (a handle and its shadow), the swatch's
	// diameter, the field's height.
	var thickness:Float;
	var knob = 0.;
	var lane = 0.;
	var diameter = 0.;
	var compact = 0.;
	// The square's side: the width the picker was last given.
	var side:Float;
	var hasAlpha:Bool;
	var h = 0.;
	var s = 0.;
	var v = 0.;
	var a = 1.;
	var dragging = NONE;
	var editing = NONE;

	@:allow(helix.ui.Ui)
	function new(ui:Ui, name:String, color:Int, alpha:Bool) {
		super(ui, name);
		hasAlpha = alpha;
		var theme = ui.theme;
		// The bars' ends are made for this thickness, made again by readTheme when it changes.
		thickness = theme.trackThickness;
		side = theme.colorPickerWidth;
		face = rectangle(0);
		face.pickable = true;
		squareHue = rectangle(0xffff0000);
		whiteRamp = rectangle(0xffffffff);
		whiteRamp.shading = Across;
		whiteRamp.endColor = 0x00ffffff;
		blackRamp = rectangle(0x00000000);
		blackRamp.shading = Down;
		blackRamp.endColor = 0xff000000;
		for (n in [face, squareHue, whiteRamp, blackRamp, hueGroup, alphaGroup, swatchGroup])
			root.addChild(n);
		// The hue bar: six bands, red through yellow, green, cyan, blue and magenta to red, between round ends of red.
		for (k in 0...6) {
			var band = rectangle(fromHsv(k / 6, 1, 1));
			band.shading = Across;
			band.endColor = fromHsv((k + 1) / 6, 1, 1);
			hueBands.push(band);
			hueGroup.addChild(band);
		}
		hueStart = end(hueGroup, false, 0xffff0000);
		hueEnd = end(hueGroup, true, 0xffff0000);
		// The alpha bar: a checkerboard in its rounded shape, under the color from clear to opaque, its right end round in the opaque color.
		alphaBase = Shape2D.polygon(capsule(0, 0, thickness * 2, thickness), LIGHT);
		alphaBase.pickable = false;
		alphaRamp = rectangle(0);
		alphaRamp.shading = Across;
		for (n in [alphaBase, alphaChecks, alphaRamp])
			alphaGroup.addChild(n);
		alphaEnd = end(alphaGroup, true, 0);
		alphaGroup.visible = hasAlpha;
		// The swatch: a disc of the color, with alpha over a checkerboard in its round shape (its size readTheme's).
		swatchBase = round(swatchGroup, 1, LIGHT);
		swatchGroup.addChild(swatchChecks);
		swatchColor = round(swatchGroup, 1, 0);
		// Its edge in the faces' color, so a color like the panel's still shows a disc.
		swatchEdge = round(swatchGroup, 1, theme.faceColor);
		swatchEdge.outline = 1.5;
		swatchBase.visible = swatchChecks.visible = hasAlpha;
		// The handles: the square's a ring, the bars' discs, white over a dark shadow so they show on any color.
		squareShadow = mark(Shape2D.circle(6, 0x90000000), 4);
		squareMark = mark(Shape2D.circle(6, 0xffffffff), 2);
		hueKnob = new Handle(root, theme);
		alphaKnob = new Handle(root, theme);
		alphaKnob.visible = hasAlpha;
		caption = new Text2D("HEX", theme.textSize * .6, theme.disabledTextColor, theme.font);
		caption.setPivot(.5, 0);
		root.addChild(caption);
		// A column: the square; a padded strip of the swatch beside the bars; a row of the field (its caption under it) and the format button
		// (attach). Their sizes, padding and gaps readTheme's.
		squareLayout = Layout2D.of(squareHue);
		swatchLayout = Layout2D.of(swatchGroup);
		bars = Layout2D.column();
		bars.themeSizing(Grow(1), Fit);
		bars.setAlign(Start, Stretch);
		hueLayout = Layout2D.of(hueGroup);
		bars.add(hueLayout);
		if (hasAlpha) {
			alphaLayout = Layout2D.of(alphaGroup);
			bars.add(alphaLayout);
		}
		strip = Layout2D.row();
		strip.setAlign(Start, Center);
		strip.add(swatchLayout);
		strip.add(bars);
		fieldColumn = Layout2D.column();
		fieldColumn.themeGap(2);
		fieldColumn.setAlign(Start, Center);
		textRow = Layout2D.row();
		textRow.setAlign(Center, Start);
		textRow.add(fieldColumn);
		var column = Layout2D.column();
		column.setAlign(Start, Stretch);
		column.setAnchor(Stretch, Start);
		column.add(squareLayout);
		column.add(strip);
		column.add(textRow);
		layout = Layout2D.stack(face);
		layout.add(column);
		squareLayout.themeSizing(null, Fixed(side));
		this.color = color;
		readTheme(theme);
	}

	// Its sizes from the theme (the bars' ends made again for a new thickness, the checkerboards for a new size as they're drawn), its
	// field's and button's layouts, its caption, the swatch's edge and the handles; its width the theme's colorPickerWidth unless its layout was
	// given another.
	override function readTheme(theme:Theme):Void {
		var pad = theme.padding;
		if (theme.trackThickness != thickness) {
			thickness = theme.trackThickness;
			var right = arc(0, 0, thickness / 2, -Math.PI / 2),
				left = arc(0, 0, thickness / 2, Math.PI / 2);
			hueStart.setPoints(left);
			hueEnd.setPoints(right);
			alphaEnd.setPoints(right);
			alphaChecked = -1;
		}
		knob = theme.handleSize / 2;
		lane = (knob + 1.5) * 2;
		diameter = hasAlpha ? lane * 2 + theme.gap / 2 : lane * 1.6;
		compact = theme.textSize + pad / 2;
		swatchBase.radius = swatchColor.radius = diameter / 2;
		swatchEdge.radius = diameter / 2 - .75;
		swatchEdge.color = theme.faceColor;
		themeFixed(swatchLayout, diameter, diameter);
		themeFixed(hueLayout, Math.NaN, lane);
		if (alphaLayout != null)
			themeFixed(alphaLayout, Math.NaN, lane);
		bars.themeGap(theme.gap / 2);
		strip.themeGap(pad);
		strip.themePadding(pad, pad, pad, pad);
		textRow.themeGap(theme.gap / 2);
		textRow.themePadding(pad, 0, pad, pad);
		caption.textSize = theme.textSize * .6;
		caption.color = theme.disabledTextColor;
		caption.font = theme.font;
		hueKnob.readTheme(theme);
		alphaKnob.readTheme(theme);
		// The field's padding and size are the picker's, set as a game sets a layout's (its owner's, so its own theme's never replace them).
		if (textField != null)
			textField.layout.setPadding(pad / 2, 0, pad / 2, 0);
		themeFixed(layout, theme.colorPickerWidth, Math.NaN);
	}

	// A rectangle of the widget, its top-left at its position, not picked (the face is what the pointer uses).
	function rectangle(color:Int):Shape2D {
		var shape = Shape2D.rectangle(1, 1, color);
		shape.setPivot(0, 0);
		shape.pickable = false;
		return shape;
	}

	// A disc of radius under group, not picked.
	function round(group:Node2D, radius:Float, color:Int):Shape2D {
		var shape = Shape2D.circle(radius, color);
		shape.pickable = false;
		group.addChild(shape);
		return shape;
	}

	// A bar's round end under group, the half of a disc as wide as the bar is thick, its straight side through its position: the right half
	// (right) or the left.
	function end(group:Node2D, right:Bool, color:Int):Shape2D {
		var shape = Shape2D.polygon(arc(0, 0, thickness / 2, right ? -Math.PI / 2 : Math.PI / 2), color);
		shape.pickable = false;
		group.addChild(shape);
		return shape;
	}

	// A handle, outlined width wide (0: filled), centered on its position, over the parts.
	function mark(shape:Shape2D, width:Float):Shape2D {
		shape.outline = width;
		shape.pickable = false;
		root.addChild(shape);
		return shape;
	}

	// The text field and the format button: their layouts in the row under the strip (the field over its caption), their nodes with the
	// picker's (hidden with it), taken out with it.

	@:allow(helix.ui.Ui)
	function attach(field:TextField, button:Widget):Void {
		textField = field;
		formatButton = button;
		field.centered = true;
		// Its layout the picker's to size and pad (readTheme, fitField), not the theme's: until its text is measured, three widgets' heights wide.
		fieldWidth = ui.theme.widgetHeight * 3;
		readTheme(ui.theme);
		fitField();
		for (part in [field, button]) {
			parts.push(part);
			part.root.parent = null;
			root.addChild(part.root);
		}
		fieldColumn.add(field.layout);
		fieldColumn.add(Layout2D.of(caption));
		textRow.add(button.layout);
		set_format(format);
	}

	// The format button, for the Ui to adopt (named name).

	@:allow(helix.ui.Ui)
	function makeFormatButton(name:String):Widget
		return new FormatButton(ui, name, this);

	/** Its text field: the color in its format, typed in (a widget of its own, named after the picker with "-text"). Its layout is the picker's
		to size and pad, whatever the theme. */
	public var textField(default, null):TextField;

	/** The button beside its text field cycling its format (a widget of its own, named after the picker with "-format"): clicked, or activated
		with focus by Enter, Space or a pad's South. */
	public var formatButton(default, null):Widget;

	/** How its text field writes and reads the color: Hex (to start) or Rgba. The field shows the color in it at once, its caption under it
		naming it (HEX, RGBA, or RGB without alpha). */
	public var format(default, set):ColorFormat = Hex;

	function set_format(value:ColorFormat):ColorFormat {
		format = value;
		caption.text = value == Hex ? "HEX" : hasAlpha ? "RGBA" : "RGB";
		if (textField != null) {
			textField.text = formatText(get_color());
			textField.invalid = false;
			textField.hint = value == Hex ? (hasAlpha ? "RRGGBBAA" : "RRGGBB") : hasAlpha ? "r g b a" : "r g b";
		}
		return value;
	}

	// The next format, as the button asks.
	function cycleFormat():Void
		format = format == Hex ? Rgba : Hex;

	function formatText(color:Int):String
		return format == Hex ? formatHex(color, hasAlpha) : formatRgba(color, hasAlpha);

	/** Its color, 0xAARRGGBB. Assigning one keeps the hue where the color doesn't say it (a grey, black), and the saturation where it's black;
		without alpha, the alpha is 0xff whatever is assigned. */
	public var color(get, set):Int;

	function get_color():Int
		return fromHsv(h, s, v, Math.round(a * 255));

	function set_color(value:Int):Int {
		if (!hasAlpha)
			value = Color.withAlpha(value, 255);
		// The color it shows already: nothing to work out (hue 1 and 0 are both red).
		if (value == get_color())
			return value;
		var r = Color.getRed(value) / 255,
			g = Color.getGreen(value) / 255,
			b = Color.getBlue(value) / 255;
		var max = Math.max(r, Math.max(g, b)), min = Math.min(r, Math.min(g, b)), d = max - min;
		a = Color.getAlpha(value) / 255;
		v = max;
		if (max > 0)
			s = d / max;
		if (d > 0) {
			var sixths = max == r ? (g - b) / d : max == g ? (b - r) / d + 2 : (r - g) / d + 4;
			h = (sixths < 0 ? sixths + 6 : sixths) / 6;
		}
		return value;
	}

	/** Its hue, 0 to 1 around (red at 0 and 1, then yellow, green, cyan, blue and magenta at sixths); kept through greys and black. Clamped to 0
		to 1. */
	public var hue(get, set):Float;

	function get_hue():Float
		return h;

	function set_hue(value:Float):Float {
		h = clamp(value);
		return h;
	}

	/** Its saturation, 0 (grey) to 1 (the full hue); kept through black. Clamped to 0 to 1. */
	public var saturation(get, set):Float;

	function get_saturation():Float
		return s;

	function set_saturation(value:Float):Float {
		s = clamp(value);
		return s;
	}

	/** Its brightness (HSV's value), 0 (black) to 1. Clamped to 0 to 1. */
	public var brightness(get, set):Float;

	function get_brightness():Float
		return v;

	function set_brightness(value:Float):Float {
		v = clamp(value);
		return v;
	}

	/** Whether its color changed this frame: dragged, nudged by keys or typed. */
	public var changed(default, null):Bool = false;

	/** The color 0xAARRGGBB of hue (0 to 1 around, red at both ends), saturation and brightness (0 to 1 each; out of range clamped) and
		alpha (0 to 255), each channel rounded to the nearest of 255. */
	public static function fromHsv(hue:Float, saturation:Float, brightness:Float, alpha = 0xff):Int {
		hue = clamp(hue);
		saturation = clamp(saturation);
		brightness = clamp(brightness);
		alpha = alpha < 0 ? 0 : alpha > 255 ? 255 : alpha;
		return Color.fromChannels(channel(5, hue, saturation, brightness), channel(3, hue, saturation, brightness), channel(1, hue, saturation, brightness),
			alpha);
	}

	// One channel of an HSV color, 0 to 255: n 5 for red, 3 for green, 1 for blue.
	static function channel(n:Int, hue:Float, saturation:Float, brightness:Float):Int {
		var k = (n + hue * 6) % 6, f = Math.min(k, 4 - k);
		f = f < 0 ? 0 : f > 1 ? 1 : f;
		return Math.round((brightness - brightness * saturation * f) * 255);
	}

	/** The color text names, 0xAARRGGBB: RRGGBBAA, or RRGGBB meaning alpha 0xff, hex digits in either case, with or without a leading # and
		with spaces around. Null for anything else. */
	public static function parseHex(text:String):Null<Int> {
		text = StringTools.trim(text);
		if (StringTools.startsWith(text, "#"))
			text = text.substr(1);
		if (text.length != 6 && text.length != 8)
			return null;
		var value = 0;
		for (i in 0...text.length) {
			var c = text.charCodeAt(i);
			var digit = c >= "0".code
				&& c <= "9".code ? c - "0".code : c >= "a".code
					&& c <= "f".code ? c - "a".code + 10 : c >= "A".code && c <= "F".code ? c - "A".code + 10 : -1;
			if (digit < 0)
				return null;
			value = (value << 4) | digit;
		}
		return Color.fromRgba(text.length == 6 ? (value << 8) | 0xff : value);
	}

	/** color as lowercase hex, RRGGBBAA, or RRGGBB without alpha. */
	public static function formatHex(color:Int, alpha:Bool):String
		return alpha ? StringTools.hex(Color.toRgba(color), 8).toLowerCase() : StringTools.hex(color & 0xffffff, 6).toLowerCase();

	/** The color text names, 0xAARRGGBB: r g b a, or r g b meaning alpha 255, each a whole number 0 to 255 in decimal (at most 3 digits),
		apart by spaces, a comma, or a comma with spaces around it, with spaces around the whole. Null for anything else. */
	public static function parseRgba(text:String):Null<Int> {
		text = StringTools.trim(text);
		var values:Array<Int> = [], value = 0, digits = 0, commas = 0;
		for (i in 0...text.length) {
			var c = text.charCodeAt(i);
			if (c >= "0".code && c <= "9".code) {
				if (digits == 3)
					return null;
				value = value * 10 + c - "0".code;
				digits++;
				commas = 0;
			} else if (c == " ".code || c == ",".code) {
				if (digits > 0) {
					if (value > 255)
						return null;
					values.push(value);
					value = digits = 0;
				}
				if (c == ",".code && (values.length == 0 || ++commas > 1))
					return null;
			} else
				return null;
		}
		if (digits == 0 || value > 255 || commas > 0)
			return null;
		values.push(value);
		if (values.length != 3 && values.length != 4)
			return null;
		return Color.fromChannels(values[0], values[1], values[2], values.length == 4 ? values[3] : 255);
	}

	/** color's channels in decimal, 0 to 255 each, apart by a space: r g b a, or r g b without alpha. */
	public static function formatRgba(color:Int, alpha:Bool):String {
		var text = '${Color.getRed(color)} ${Color.getGreen(color)} ${Color.getBlue(color)}';
		return alpha ? '$text ${Color.getAlpha(color)}' : text;
	}

	static function clamp(value:Float):Float
		return value > 0 ? (value < 1 ? value : 1) : 0;

	override function get_focusable():Bool
		return true;

	override function target():Null<Node2D>
		return face;

	// The arrows are its own while a part is being driven by them.

	override function takesSideways():Bool
		return editing != NONE;

	override function takesUpDown():Bool
		return editing != NONE;

	// The part under world point x, y (as the last draw placed the parts), or ELSEWHERE: a bar's whole row, its handle's height.
	function partAt(x:Float, y:Float):Int {
		var lx = squareHue.toLocalX(x, y), ly = squareHue.toLocalY(x, y);
		if (lx >= 0 && ly >= 0 && lx <= squareHue.width && ly <= squareHue.height)
			return SQUARE;
		for (part in [HUE, ALPHA]) {
			var group = part == HUE ? hueGroup : alphaGroup,
				at = part == HUE ? hueLayout : alphaLayout;
			if (at == null)
				continue;
			lx = group.toLocalX(x, y);
			ly = group.toLocalY(x, y);
			if (lx >= 0 && ly >= 0 && lx <= at.width && ly <= at.height)
				return part;
		}
		return ELSEWHERE;
	}

	// "square": saturation 0 to 1 left to right, brightness 1 to 0 top to bottom. "hue" and, with alpha, "alpha": the bar between the centers
	// of its round ends, where its value runs 0 to 1 left to right, as tall as the bar. "swatch": the disc showing the color, its square.
	override function locatePart(part:String, out:Array<Float>):Null<Node2D> {
		var bar = part == "hue" ? hueLayout : part == "alpha" ? alphaLayout : null;
		if (part == "square")
			Widget.setRectangle(out, squareLayout.x, squareLayout.y, squareLayout.width, squareLayout.height);
		else if (part == "swatch")
			Widget.setRectangle(out, swatchLayout.x, swatchLayout.y, diameter, diameter);
		else if (bar != null)
			Widget.setRectangle(out, bar.x + thickness / 2, bar.y + (lane - thickness) / 2, Math.max(0, bar.width - thickness), thickness);
		else
			return super.locatePart(part, out);
		return root;
	}

	// How far along a bar of width (as the layout last placed it) local x is, 0 to 1: between the centers of its round ends.
	function along(x:Float, width:Float):Float {
		var span = width - thickness;
		return span > 0 ? clamp((x - thickness / 2) / span) : 0;
	}

	override function update(hovered:Bool, held:Bool, clicked:Bool, focused:Bool, activated:Bool, stepX:Int, stepY:Int):Void {
		var input = ui.input, camera = ui.camera, was = get_color();
		if (!focused)
			editing = NONE;
		// The pointer: the part it went down on follows it while it's held.
		if (enabled && held) {
			var wx = camera.screenToWorldX(input.pointerX),
				wy = camera.screenToWorldY(input.pointerY);
			if (dragging == NONE) {
				dragging = partAt(wx, wy);
				if (dragging != ELSEWHERE)
					editing = dragging;
			}
			switch dragging {
				case SQUARE:
					s = clamp(squareHue.toLocalX(wx, wy) / squareHue.width);
					v = clamp(1 - squareHue.toLocalY(wx, wy) / squareHue.height);
				case HUE:
					h = along(hueGroup.toLocalX(wx, wy), hueLayout.width);
				case ALPHA:
					a = along(alphaGroup.toLocalX(wx, wy), alphaLayout.width);
				default:
			}
		} else
			dragging = NONE;
		// Keys and the D-pad: activating steps through the parts, the arrows drive the one stepped to.
		if (enabled && activated)
			editing = editing == SQUARE ? HUE : editing == HUE ? (hasAlpha ? ALPHA : NONE) : editing == ALPHA ? NONE : SQUARE;
		if (enabled && (stepX != 0 || stepY != 0))
			switch editing {
				case SQUARE:
					s = clamp(s + stepX * STEP);
					v = clamp(v - stepY * STEP);
				case HUE:
					h = clamp(h + (stepX - stepY) * STEP);
				case ALPHA:
					a = clamp(a + (stepX - stepY) * STEP);
				default:
			}
		// The field: what was typed in it last frame, when it names a color; shown again as the color once it's left.
		fitSquare();
		if (textField != null) {
			fitField();
			textField.enabled = formatButton.enabled = enabled;
			if (textField.changed) {
				var typed = format == Hex ? parseHex(textField.text) : parseRgba(textField.text);
				textField.invalid = typed == null;
				if (typed != null)
					set_color(typed);
			}
			if (ui.focused != textField) {
				var text = formatText(get_color());
				if (textField.text != text)
					textField.text = text;
				textField.invalid = false;
			}
		}
		var color = get_color();
		changed = color != was;
		// The part under the pointer, for its handle's look.
		var over = ELSEWHERE;
		if (hovered)
			over = partAt(camera.screenToWorldX(input.pointerX), camera.screenToWorldY(input.pointerY));
		draw(color, focused, over);
	}

	// The square as tall as the picker was last made wide (its layout Fixed, or grown across a column): taken up by the next arrangement, so a
	// new width shows the square's new height a frame later.
	function fitSquare():Void {
		if (layout.width > 0 && layout.width != side) {
			side = layout.width;
			squareLayout.themeSizing(null, Fixed(side));
		}
	}

	// The field compact tall, as wide as the widest text of either format needs, with the caret, and no wider than the row has room for beside
	// the button: that text measured again only when the font or the text's size changed.
	function fitField():Void {
		var theme = ui.theme,
			font = theme.font != null ? theme.font : ui.font,
			wanted = fieldWidth;
		if (font != null) {
			if (font != fieldFont || theme.textSize != fieldSize) {
				fieldFont = font;
				fieldSize = theme.textSize;
				widest = Math.max(font.measure(hasAlpha ? "00000000" : "000000", theme.textSize),
					font.measure(hasAlpha ? "255 255 255 255" : "255 255 255", theme.textSize));
			}
			var room = side - theme.padding * 2 - textRow.gap - compact * .8;
			wanted = Math.min(widest + theme.padding + 4, room);
		}
		if (wanted != fieldWidth || compact != fieldHeight) {
			fieldWidth = wanted;
			fieldHeight = compact;
			textField.layout.setSizing(Fixed(wanted), Fixed(compact));
		}
	}

	// The parts where the layout last placed them, in the color now, the handles by their states (over: the part under the pointer).
	function draw(color:Int, focused:Bool, over:Int):Void {
		var theme = ui.theme,
			x = squareLayout.x,
			y = squareLayout.y,
			w = squareLayout.width,
			height = squareLayout.height;
		squareHue.color = fromHsv(h, 1, 1);
		for (n in [whiteRamp, blackRamp]) {
			n.setPosition(x, y);
			n.setSize(w, height);
		}
		// The bars, thickness tall in the middle of their rows, their ends round: what they choose runs between the ends' centers.
		var r = thickness / 2, top = (lane - thickness) / 2, middle = lane / 2;
		var hw = hueLayout.width, span = Math.max(0, hw - thickness);
		for (k in 0...hueBands.length) {
			hueBands[k].setPosition(r + span * k / 6, top);
			hueBands[k].setSize(span / 6, thickness);
		}
		hueStart.setPosition(r, middle);
		hueEnd.setPosition(hw - r, middle);
		var opaque = Color.withAlpha(color, 255),
			clear = Color.withAlpha(color, 0);
		if (alphaLayout != null) {
			var aw = alphaLayout.width;
			alphaRamp.setPosition(r, top);
			alphaRamp.setSize(Math.max(0, aw - thickness), thickness);
			alphaRamp.color = clear;
			alphaRamp.endColor = opaque;
			alphaEnd.setPosition(aw - r, middle);
			alphaEnd.color = opaque;
			if (alphaChecked != aw) {
				alphaChecked = aw;
				var outline = capsule(0, top, aw, thickness);
				alphaBase.setPoints(outline);
				checker(alphaChecks, alphaChecksPool, outline, 0, top, aw, thickness, r);
			}
		}
		// The swatch: the color over a checkerboard in its disc, as its alpha shows it.
		var radius = diameter / 2;
		swatchBase.setPosition(radius, radius);
		swatchColor.setPosition(radius, radius);
		swatchEdge.setPosition(radius, radius);
		swatchColor.color = color;
		if (hasAlpha && swatchChecked != diameter) {
			swatchChecked = diameter;
			checker(swatchChecks, swatchChecksPool, capsule(0, 0, diameter, diameter), 0, 0, diameter, diameter, diameter / 6);
		}
		// The handles by their parts' states: held while dragged, over under the pointer, focused while the keys drive it.
		squareShadow.setPosition(x + s * w, y + (1 - v) * height);
		squareMark.setPosition(x + s * w, y + (1 - v) * height);
		squareMark.color = handleState(SQUARE, focused, over).handle(theme);
		var hx = hueLayout.x + r + h * span, hy = hueLayout.y + middle;
		hueKnob.setPosition(hx, hy);
		hueKnob.color = handleState(HUE, focused, over).handle(theme);
		if (alphaLayout != null) {
			var ax = alphaLayout.x + r + a * Math.max(0, alphaLayout.width - thickness),
				ay = alphaLayout.y + middle;
			alphaKnob.setPosition(ax, ay);
			alphaKnob.color = handleState(ALPHA, focused, over).handle(theme);
		}
	}

	// The state of part's handle: down while the pointer drags it, over while it's under the pointer (over), focused while the keys drive it.
	function handleState(part:Int, focused:Bool, over:Int):WidgetState
		return WidgetState.of(enabled, dragging == part, over == part, focused && editing == part);

	// The outline of a rectangle x, y, w x h with round ends across its shorter side (a disc when it's square), as a polygon's points: fine
	// enough that the checkerboard cut to it meets the round shapes drawn over its edge.
	static function capsule(x:Float, y:Float, w:Float, h:Float):Array<Float> {
		var r = Math.min(w, h) / 2;
		return w >= h ? arc(x + w - r, y + r, r,
			-Math.PI / 2).concat(arc(x + r, y + r, r, Math.PI / 2)) : arc(x + r, y + h - r, r, 0).concat(arc(x + r, y + r, r, Math.PI));
	}

	// Half a circle of radius about cx, cy as points, from angle start (radians, clockwise on screen) round to start + pi.
	static function arc(cx:Float, cy:Float, r:Float, start:Float):Array<Float> {
		var steps = 24, points = [];
		for (i in 0...steps + 1) {
			var angle = start + i * Math.PI / steps;
			points.push(cx + Math.cos(angle) * r);
			points.push(cy + Math.sin(angle) * r);
		}
		return points;
	}

	// The dark squares of a checkerboard of cells cell wide over x, y, w x h (the light ones the base under them), each cut to the convex
	// outline, as polygons from pool under group: those past what it needs hidden, the pool grown as needed.
	function checker(group:Node2D, pool:Array<Shape2D>, outline:Array<Float>, x:Float, y:Float, w:Float, h:Float, cell:Float):Void {
		var used = 0;
		if (cell > 0) {
			var columns = Math.ceil(w / cell), rows = Math.ceil(h / cell);
			for (row in 0...rows)
				for (column in 0...columns) {
					if ((row + column) % 2 == 0)
						continue;
					var points = cut(outline, x + column * cell, y + row * cell, x + (column + 1) * cell, y + (row + 1) * cell);
					if (points.length < 6)
						continue;
					if (used == pool.length) {
						var square = Shape2D.polygon(points, DARK);
						square.pickable = false;
						pool.push(square);
						group.addChild(square);
					} else
						pool[used].setPoints(points);
					pool[used++].visible = true;
				}
		}
		for (i in used...pool.length)
			pool[i].visible = false;
	}

	// The convex polygon points cut to the rectangle x0, y0 to x1, y1 (Sutherland and Hodgman's clipping, an edge at a time), points on an edge
	// within rounding taken as on it, then points as good as their neighbours and points in a line between their neighbours left out, so it
	// triangulates cleanly (a cell's corner on the outline comes out alike on every target); fewer than 3 points when they don't meet.
	static function cut(points:Array<Float>, x0:Float, y0:Float, x1:Float, y1:Float):Array<Float> {
		var out = points;
		for (edge in 0...4) {
			var given = out, n = given.length >> 1;
			out = [];
			// How far inside this edge a point is (below 0: outside; within rounding of it, on it).
			function inside(px:Float, py:Float):Float {
				var d = switch edge {
					case 0: px - x0;
					case 1: x1 - px;
					case 2: py - y0;
					default: y1 - py;
				}
				return Math.abs(d) < 1e-9 ? 0 : d;
			}
			for (i in 0...n) {
				var j = (i + 1) % n,
					ax = given[i * 2],
					ay = given[i * 2 + 1],
					bx = given[j * 2],
					by = given[j * 2 + 1];
				var da = inside(ax, ay), db = inside(bx, by);
				if (da >= 0) {
					out.push(ax);
					out.push(ay);
				}
				if (da > 0 && db < 0 || da < 0 && db > 0) {
					var t = da / (da - db);
					out.push(ax + (bx - ax) * t);
					out.push(ay + (by - ay) * t);
				}
			}
		}
		// A point taken out while it's as good as the one before it or in a line between the points either side, until none is.
		var kept = out.copy(), taken = true;
		while (taken && kept.length >= 6) {
			taken = false;
			var n = kept.length >> 1;
			for (i in 0...n) {
				var p = (i + n - 1) % n, q = (i + 1) % n;
				var ax = kept[i * 2] - kept[p * 2],
					ay = kept[i * 2 + 1] - kept[p * 2 + 1],
					bx = kept[q * 2] - kept[p * 2],
					by = kept[q * 2 + 1] - kept[p * 2 + 1];
				if (ax * ax + ay * ay < 1e-12 || Math.abs(ax * by - ay * bx) < 1e-9) {
					kept.splice(i * 2, 2);
					taken = true;
					break;
				}
			}
		}
		return kept.length >= 6 ? kept : [];
	}
}

/** The button beside a color picker's text field cycling its format: up and down chevrons on a square face, clicked or activated with focus. */
private class FormatButton extends Widget {
	var picker:ColorPicker;
	var face:Shape2D;
	var up:Chevron;
	var down:Chevron;

	@:allow(helix.ui.ColorPicker)
	function new(ui:Ui, name:String, picker:ColorPicker) {
		super(ui, name);
		this.picker = picker;
		var theme = ui.theme;
		face = Shape2D.rectangle(1, 1, theme.faceColor);
		face.setPivot(0, 0);
		root.addChild(face);
		up = new Chevron(root, true);
		down = new Chevron(root, false);
		layout = Layout2D.of(face);
		readTheme(theme);
	}

	// As tall as the picker's field (its compact height, from the theme), four fifths as wide, the chevrons shaped for its height.
	override function readTheme(theme:Theme):Void {
		var height = @:privateAccess picker.compact;
		themeFixed(layout, height * .8, height);
		up.setSize(height);
		down.setSize(height);
	}

	override function get_focusable():Bool
		return true;

	override function target():Null<Node2D>
		return face;

	override function update(hovered:Bool, held:Bool, clicked:Bool, focused:Bool, activated:Bool, stepX:Int, stepY:Int):Void {
		var theme = ui.theme,
			state = WidgetState.of(enabled, held, hovered, focused);
		if (enabled && (clicked || activated))
			@:privateAccess picker.cycleFormat();
		face.color = state.face(theme);
		up.color = down.color = state.text(theme);
		// The chevrons a little above and below the middle, as the layout last placed it.
		var cx = layout.x + layout.width / 2,
			cy = layout.y + layout.height / 2,
			gap = layout.height * .1;
		up.setPosition(cx, cy - gap - layout.height * .18);
		down.setPosition(cx, cy + gap + layout.height * .18);
	}
}
