package helix.ui;

import helix.input.IInput;
import helix.input.Key;
import helix.input.PadButton;
import helix.render2d.Camera2D;
import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.ShapeShading2D;
import helix.scene.Pointer;

/** A screen's widgets on the stage, used by the pointer, keys and pads alike: made here,
	placed by their layouts (Layout2D.arrange), asked what happened. update() once a frame, after the pointer's:

	- Arrows and a pad's D-pad move focus to the nearest widget that way on screen (by the layouts' last arrangement: a grid of tiles moves in
	  two dimensions), or, with none that way, in the order widgets were made: Down and Right to the next, Up and Left to the one before,
	  wrapping; Left and Right only when the focused widget doesn't use them (a slider), Up and Down only when it doesn't (a list; a color
	  picker uses all four while one of its parts is driven by them). Tab and Shift+Tab always go in that order. Enter, Space or a pad's South activates it; Escape or East is back (backPressed).
	- The ring around the focused widget shows only when keys or a pad moved focus, not the pointer (as the web's :focus-visible); after keys or
	  a pad, something always has focus (the first widget, if nothing did).
	- A key or button already held when a screen begins (reset) does nothing until it's let go: a fire key held into a menu doesn't press its
	  first button. One pressed after reset works at once.
	- While a widget has the keys (capturingKeys), a game should leave arrows and Enter be, or they drive the game and the menu at once.
	- A widget may open a popup (Popup: a dropdown's list), drawn over every widget and the ring and clipped by none of their clips, placed by
	  its anchor in the visible area (below it, or above when there's no room below and more above; kept on screen across). While it's open
	  (popup) it has the pointer and the keys: the widgets under it see no pointer, a press off it closes it and does nothing else until it's
	  let go (not even reaching a world under the UI: the pointer is captured), Escape or East closes it instead of going back (backPressed
	  stays false), Tab doesn't move focus, and its owner keeps focus and takes the arrows, Enter, Space and South (capturingKeys is true).

	The widgets' nodes are under one node (root) on the stage, in the order made, the ring above them and the open popup above it: what's
	added to the stage after it draws over it. */
class Ui {
	// Whether it made its pointer (looking at the stage): then it updates it, at the start of its own update.
	var ownsPointer = false;
	var givenFont:Null<helix.font.Font>;
	// The pointer and the widgets, and whether the ring shows (keys or a pad moved focus): read by a scroll area too (what's under the
	// pointer, which widgets are inside it, whether to scroll the focused one into view).
	@:allow(helix.ui)
	var pointer:Pointer;
	var ring:Shape2D;
	@:allow(helix.ui)
	var widgets:Array<Widget> = [];
	// Each widget by its root node: what a widget's enabled and interactive look up the panels holding it in.
	@:allow(helix.ui)
	var owners:Map<Node2D, Widget> = new Map();
	var textEntry = false;
	@:allow(helix.ui)
	var showFocus = false;
	var keys = false;
	// What was held at reset, each ignored until it's let go.
	var guardEnter = false;
	var guardSpace = false;
	var guardEscape = false;
	var guardSouth = false;
	var guardEast = false;
	var guardPointer = false;
	// The input it last asked for typed text on (IInput.textEntry): the program's can change under it (an autopilot playing).
	var textInput:Null<IInput>;
	var givenInput:Null<IInput>;
	var back = false;
	var lastX = -1.;
	var lastY = -1.;
	var pressing:Null<Widget>;
	// Over the widgets and the ring: a clear rectangle over the visible area under the open popup, taking every press off the popup (and held
	// until a press it took is let go), then the popup's nodes.
	var layer:Node2D;
	var scrim:Shape2D;

	/** A UI on the stage (Stage, docs/DISPLAY_MODEL.md), in theme's look (a new Theme when not given): drawn through the stage's camera,
		with a pointer of its own looking at the stage (updated by update), read from Input as it is at each update (an autopilot made after
		it is read too). Given parent, camera, pointer and input, it's
		under parent instead (a UI in a View2D's tree, a test), drawn through camera, which pointer must look at (the app updates that
		pointer before update), read from input. */
	public function new(?theme:Theme, ?parent:Node2D, ?camera:Camera2D, ?pointer:Pointer, ?input:IInput) {
		givenInput = input;
		if (pointer == null) {
			pointer = new Pointer(input);
			ownsPointer = true;
		}
		this.camera = camera != null ? camera : helix.render2d.Stage.camera;
		this.pointer = pointer;
		this.theme = theme;
		ring = Shape2D.rectangle(1, 1, this.theme.focusColor);
		ring.outline = this.theme.focusWidth;
		ring.pickable = false;
		ring.visible = false;
		root.addChild(ring);
		layer = new Node2D();
		scrim = Shape2D.rectangle(1, 1, 0);
		scrim.setPivot(0, 0);
		scrim.visible = false;
		layer.addChild(scrim);
		root.addChild(layer);
		if (parent != null)
			parent.addChild(root);
		else
			helix.render2d.Stage.addChild(root);
	}

	/** Its look, read by every widget (and the focus ring) at each update: a value changed, or another theme assigned (a settings screen
		switching themes), shows from the next update with no widget made again; a size that moves the layout once the layout is next arranged.
		Null is a new Theme. */
	public var theme(default, set):Theme;

	function set_theme(value:Theme):Theme {
		theme = value != null ? value : new Theme();
		return theme;
	}

	/** The node its widgets are under. */
	public var root(default, null):Node2D = new Node2D();

	/** The font text is drawn in without the theme's: the one assigned, else the stage's (the built-in one, there from the first frame). */
	public var font(get, set):Null<helix.font.Font>;

	function get_font():Null<helix.font.Font> {
		if (givenFont != null)
			return givenFont;
		var stage = helix.render2d.Stage.instance;
		return stage != null ? stage.font : null;
	}

	function set_font(value:Null<helix.font.Font>):Null<helix.font.Font>
		return givenFont = value;

	/** The camera it's drawn through. */
	public var camera(default, null):Camera2D;

	/** The input it reads: the one it was given, or else the program's (Input) as it is now. */
	public var input(get, never):IInput;

	function get_input():IInput
		return givenInput != null ? givenInput : helix.input.Input.instance;

	/** A line of text. */
	public function label(text:String, ?name:String):Label
		return adopt(new Label(this, name != null ? name : text, text));

	/** A background holding a column of widgets (add their layouts to its content). */
	public function panel(?name:String):Panel
		return adopt(new Panel(this, name != null ? name : "panel"));

	/** A button reading text: clicked by the pointer, or activated with focus. */
	public function button(text:String, ?name:String):Button
		return adopt(new Button(this, name != null ? name : text, text));

	/** A box that's on or off, beside text. */
	public function toggle(text:String, value:Bool, ?name:String):Toggle
		return adopt(new Toggle(this, name != null ? name : text, text, value));

	/** A value from min to max in steps of step (0: any), dragged along a track or stepped by Left and Right, beside text. */
	public function slider(text:String, min:Float, max:Float, value:Float, step = 0., ?name:String):Slider
		return adopt(new Slider(this, name != null ? name : text, text, min, max, value, step));

	/** A thin line between widgets: across a column, or down a row when vertical (Separator). */
	public function separator(vertical = false, ?name:String):Separator
		return adopt(new Separator(this, name != null ? name : "separator", vertical));

	/** How far along something is, 0 to 1. */
	public function progress(value:Float, ?name:String):ProgressBar
		return adopt(new ProgressBar(this, name != null ? name : "progress", value));

	/** A line of text typed in, at most maxLength characters, hint shown while it's empty. */
	public function textField(value:String, hint = "", maxLength = 64, ?name:String):TextField
		return adopt(new TextField(this, name != null ? name : "text", value, hint, maxLength));

	/** A picture with a caption (a texture still to come: null), in a frame whose picture is side units square. */
	public function tile(texture:Null<helix.texture.Texture2D>, caption:String, side:Float, ?name:String):Tile
		return adopt(new Tile(this, name == null ? caption : name, texture, caption, side));

	/** A list of items rows tall, scrolled by the wheel, a drag or its scrollbar, an item chosen by the pointer or Up and Down. */
	public function list(items:Array<String>, rows:Int, ?name:String):ListView
		return adopt(new ListView(this, name != null ? name : "list", items, rows));

	/** A window height units tall onto a column of widgets (add them: ScrollArea.add), scrolled up and down by the wheel over it, a drag, its
		scrollbar and keys, as wide as its layout is given (Grow, to start). */
	public function scrollArea(height:Float, ?name:String):ScrollArea
		return adopt(new ScrollArea(this, name != null ? name : "scroll", height));

	/** A choice of one of items (or none: selected -1, clamped to the items), shown on a face with a chevron and chosen from a list opening
		over everything (Dropdown), as wide as its widest item to start. */
	public function dropdown(items:Array<String>, selected = -1, ?name:String):Dropdown {
		var dropdown = adopt(new Dropdown(this, name != null ? name : "dropdown", items));
		dropdown.selectedIndex = selected;
		return dropdown;
	}

	/** A color (0xAARRGGBB) chosen on a square of saturation and brightness, a bar of hue and, with alpha, a bar of alpha, shown in a round
		swatch and typed in a text field under them as hex or decimal channels, a button beside it cycling which (the field and the button
		widgets of their own, named name + "-text" and name + "-format", after it in the focus order). Without alpha, its color's alpha is
		always 0xff. */
	public function colorPicker(color:Int, alpha = true, ?name:String):ColorPicker {
		var picker = adopt(new ColorPicker(this, name != null ? name : "color", color, alpha));
		var field = textField(ColorPicker.formatHex(picker.color, alpha), "", 20, picker.name + "-text");
		picker.attach(field, adopt(picker.makeFormatButton(picker.name + "-format")));
		return picker;
	}

	function adopt<T:Widget>(widget:T):T {
		widgets.push(widget);
		owners.set(widget.root, widget);
		root.removeChild(ring);
		root.removeChild(layer);
		root.addChild(widget.root);
		root.addChild(ring);
		root.addChild(layer);
		return widget;
	}

	/** Takes widget out, its nodes off the stage. */
	public function remove(widget:Widget):Void {
		for (part in widget.parts)
			remove(part);
		if (popup != null && popup.owner == widget)
			closePopup();
		widgets.remove(widget);
		owners.remove(widget.root);
		root.removeChild(widget.root);
		if (focused == widget)
			@:bypassAccessor focused = null;
	}

	/** The widget named name (Widget.name), or null. */
	public function find(name:String):Null<Widget> {
		for (w in widgets)
			if (w.name == name)
				return w;
		return null;
	}

	/** Uses the widget named name as a click would (a button clicked, a toggle switched, a list's choice activated), at the next update, when
		it's shown, enabled and can be: as a test or an autopilot does, by name rather than by place. False, doing nothing, when there's no such
		widget or it isn't usable now. */
	public function press(name:String):Bool {
		var w = find(name);
		if (w == null || !w.enabled || !w.interactive || !w.visible || !w.focusable)
			return false;
		pressing = w;
		return true;
	}

	/** Writes to out[0] and out[1] the framebuffer pixel (the pointer's, through camera) at x, y of the widget named name, or of its part named
		part ("" for the whole widget): x and y fractions of its rectangle as last laid out and drawn, 0, 0 its top left and 1, 1 its bottom
		right, outside it past them. Where an autopilot's points name widgets (Autopilot), found again whenever they're used, so they follow a
		layout as it changes. False, writing nothing, while there's no such widget shown and laid out or it has no such part now. The parts: a
		Slider's "track", the line its value runs along (min at its left edge, max at its right); a ColorPicker's "square" (saturation 0 to 1
		left to right, brightness 1 to 0 down), "hue" and, with alpha, "alpha" (each bar between the centers of its round ends, where its value
		runs 0 to 1 left to right) and "swatch", the disc showing the color; a ScrollArea's and a ListView's "track" and "thumb", their
		scrollbar's while it shows; a ListView's "row:<index>", that item's row where it's scrolled to, in view or not; and while a Dropdown's
		list is open, its "list", an item's "row:<index>" in it, and its scrollbar's "track" and "thumb". */
	public function computePoint(name:String, part:String, x:Float, y:Float, out:Array<Float>):Bool {
		var w = find(name), rectangle = [0., 0., 0., 0.];
		if (w == null || !w.visible || w.layout.width <= 0 && w.layout.height <= 0)
			return false;
		var node = w.locatePart(part, rectangle);
		if (node == null)
			return false;
		var lx = rectangle[0] + rectangle[2] * x,
			ly = rectangle[1] + rectangle[3] * y;
		out[0] = camera.worldToScreenX(node.toWorldX(lx, ly));
		out[1] = camera.worldToScreenY(node.toWorldY(lx, ly));
		return true;
	}

	/** The widget with focus, or null. */
	public var focused(default, set):Null<Widget>;

	function set_focused(widget:Null<Widget>):Null<Widget> {
		focused = widget;
		showFocus = widget != null;
		syncTextEntry();
		return widget;
	}

	/** The focused widget's name, or "" (for a check's probe). */
	public var focusedName(get, never):String;

	function get_focusedName():String
		return focused == null ? "" : focused.name;

	/** Whether a widget has the keys: a game should leave arrows, Enter and Space be. */
	public var capturingKeys(get, never):Bool;

	function get_capturingKeys():Bool
		return popup != null || focused != null && (keys || focused.takesText());

	/** Whether Escape or a pad's East was pressed this frame (not held over from before reset). */
	public var backPressed(get, never):Bool;

	function get_backPressed():Bool
		return back;

	/** The open popup (a dropdown's list), or null. */
	public var popup(default, null):Null<Popup>;

	// Opens p over everything, closing the one open: its owner focused (shown as it was) and given the keys.

	@:allow(helix.ui)
	function openPopup(p:Popup):Void {
		if (popup == p)
			return;
		if (popup != null)
			closePopup();
		popup = p;
		p.open = true;
		layer.addChild(p.root);
		scrim.visible = true;
		@:bypassAccessor focused = p.owner;
		syncTextEntry();
	}

	/** Closes the open popup, if one is: its owner sees it closed at its next update, as when a press off it or Escape closes it. */
	public function closePopup():Void {
		if (popup == null)
			return;
		popup.open = false;
		layer.removeChild(popup.root);
		popup = null;
	}

	/** A new screen begins: no focus, no popup open, and the keys and buttons held now do nothing until they're let go. Anything pressed
		after this works at once. */
	public function reset():Void {
		closePopup();
		@:bypassAccessor focused = null;
		showFocus = false;
		guardEnter = input.isDown(Key.Enter);
		guardSpace = input.isDown(Key.Space);
		guardEscape = input.isDown(Key.Escape);
		guardSouth = input.isPadDown(PadButton.South);
		guardEast = input.isPadDown(PadButton.East);
		guardPointer = input.pointerDown;
		syncTextEntry();
	}

	/** Once a frame, after the pointer's update (its own pointer's, which it updates first) and before reading the widgets or the game's own keys: moves focus, activates, brings each
		widget up to date, and claims the keys it used (IInput.claim: a focused text field every key pressed), so the game reading after
		doesn't act on them too. */
	public function update():Void {
		if (ownsPointer)
			pointer.update();
		// What was held at reset is usable again once it's let go.
		guardEnter = guardEnter && input.isDown(Key.Enter);
		guardSpace = guardSpace && input.isDown(Key.Space);
		guardEscape = guardEscape && input.isDown(Key.Escape);
		guardSouth = guardSouth && input.isPadDown(PadButton.South);
		guardEast = guardEast && input.isPadDown(PadButton.East);
		guardPointer = guardPointer && input.pointerDown;
		// The pointer moving or pressing hides the ring and hands back the keys.
		var x = input.pointerX, y = input.pointerY;
		if ((x != lastX || y != lastY) && x >= 0 || input.pointerFramePressed) {
			showFocus = false;
			keys = false;
		}
		lastX = x;
		lastY = y;
		// The popup closes when its owner can't hold it now, and on a press off it (on the scrim, which keeps the pointer till it's let go).
		if (popup != null) {
			var owner = popup.owner;
			if (!owner.enabled || !owner.interactive || !owner.visible || focused != owner || widgets.indexOf(owner) < 0 || pointer.isPressed(scrim))
				closePopup();
		}
		var shift = input.isDown(Key.Shift),
			sideways = focused != null && focused.takesSideways(),
			vertical = focused != null && focused.takesUpDown();
		// move: along the order (1 or -1); dx, dy: the direction on screen an arrow or the D-pad asked for (0, 0 for Tab); stepX, stepY: what
		// the focused widget takes itself.
		var stepX = 0, stepY = 0, move = 0, dx = 0, dy = 0;
		if (input.isFramePressed(Key.Tab))
			move = shift ? -1 : 1;
		if (!vertical) {
			if (input.isFramePressed(Key.Down) || pad(PadButton.Down)) {
				move = 1;
				dy = 1;
			}
			if (input.isFramePressed(Key.Up) || pad(PadButton.Up)) {
				move = -1;
				dy = -1;
			}
		}
		var left = input.isFramePressed(Key.Left) || pad(PadButton.Left),
			right = input.isFramePressed(Key.Right) || pad(PadButton.Right);
		if (sideways)
			stepX = right ? 1 : left ? -1 : 0;
		else if (left || right) {
			move = right ? 1 : -1;
			dx = right ? 1 : -1;
			dy = 0;
		}
		if (vertical) {
			var up = input.isFramePressed(Key.Up) || pad(PadButton.Up),
				down = input.isFramePressed(Key.Down) || pad(PadButton.Down);
			stepY = down ? 1 : up ? -1 : 0;
		}
		// The widget the keys were pressed on: a key moving focus onto a list doesn't also move in it.
		var stepped = stepX != 0 || stepY != 0 ? focused : null;
		var navigated = move != 0 || stepX != 0 || stepY != 0;
		if (navigated) {
			keys = true;
			showFocus = true;
		}
		if (focused != null && (!focused.focusable || !focused.enabled || !focused.interactive || !focused.visible))
			@:bypassAccessor focused = null;
		// Focus stays on a popup's owner while it's open.
		if (popup != null)
			move = 0;
		if (move != 0) {
			var toward = focused != null && (dx != 0 || dy != 0) ? nearest(focused, dx, dy) : null;
			@:bypassAccessor focused = toward != null ? toward : focused == null ? first() : next(focused, move);
		} else if (keys && focused == null) {
			// Keys or a pad in use and nothing focused (a new screen): the first widget, shown.
			@:bypassAccessor focused = first();
			showFocus = focused != null;
		}
		var activated = focused != null
			&& (input.isFramePressed(Key.Enter) && !guardEnter || !focused.takesText() && input.isFramePressed(Key.Space) && !guardSpace
				|| pad(PadButton.South) && !guardSouth);
		if (activated) {
			keys = true;
			showFocus = true;
		}
		back = input.isFramePressed(Key.Escape) && !guardEscape || pad(PadButton.East) && !guardEast;
		// Escape or East closes a popup rather than going back.
		var escapedPopup = back && popup != null;
		if (back && popup != null) {
			closePopup();
			back = false;
		}
		for (w in widgets) {
			// usable: by keys and by name; pointing: by the pointer too, unless it was held at reset.
			var target = w.target(),
				usable = w.enabled && w.interactive && w.visible,
				pointing = usable && !guardPointer;
			var hovered = target != null && pointer.isHovered(target),
				held = target != null && pointer.isDown(target),
				clicked = pointing && target != null && pointer.isClicked(target);
			// The pointer pressing a widget gives it focus, unshown.
			if (pointing && target != null && pointer.isPressed(target) && w.focusable)
				@:bypassAccessor focused = w;
			if (w == pressing && usable) {
				clicked = true;
				@:bypassAccessor focused = w;
			}
			var steps = w == stepped && usable;
			w.readTheme(theme);
			w.update(hovered && pointing, held && pointing, clicked, w == focused, activated && w == focused && usable, steps ? stepX : 0, steps ? stepY : 0);
		}
		pressing = null;
		claimKeys(navigated, activated, escapedPopup);
		placePopup();
		// The ring around the focused widget, a little outside it, when keys or a pad moved focus.
		ring.color = theme.focusColor;
		ring.outline = theme.focusWidth;
		if (showFocus && focused != null) {
			var b = focused.layout, out = theme.focusWidth * 2;
			ring.setSize(b.width + out * 2, b.height + out * 2);
			ring.setPivot(0, 0);
			ring.setPosition(b.x - out, b.y - out);
			// Its corners round about the widget's corners' centers, square around a square widget (a text field).
			var face = Std.downcast(@:privateAccess focused.target(), Shape2D),
				radius = face != null ? face.cornerRadius : theme.cornerRadius;
			ring.cornerRadius = radius > 0 ? radius + out : 0;
			ring.visible = true;
		} else
			ring.visible = false;
		syncTextEntry();
	}

	// The keys it used this frame, claimed for the rest of it (IInput.claim), so the game reading after doesn't act on them too: a focused
	// text field takes every key pressed (typing); else, with a widget focused, the keys that moved focus or stepped it and the ones that
	// activated it, and Escape when it closed a popup.
	function claimKeys(navigated:Bool, activated:Bool, escapedPopup:Bool):Void {
		if (focused != null && focused.enabled && focused.takesText()) {
			for (k in 0...Key.COUNT)
				if (input.isFramePressed(cast k))
					input.claim(cast k);
			return;
		}
		if (focused != null && navigated)
			for (k in [Key.Tab, Key.Up, Key.Down, Key.Left, Key.Right])
				if (input.isFramePressed(k))
					input.claim(k);
		if (focused != null && activated)
			for (k in [Key.Enter, Key.Space])
				if (input.isFramePressed(k))
					input.claim(k);
		if (escapedPopup)
			input.claim(Key.Escape);
	}

	// The open popup laid out and placed by its anchor in the visible area: below it, or above when there's no room below and more above,
	// held inside the area as far as it fits; the scrim over the area while the popup is open or a press the scrim took is held.
	function placePopup():Void {
		var vx = camera.viewportX, vy = camera.viewportY;
		var x0 = camera.screenToWorldX(vx),
			y0 = camera.screenToWorldY(vy),
			x1 = camera.screenToWorldX(vx + camera.viewportWidth),
			y1 = camera.screenToWorldY(vy + camera.viewportHeight);
		var lx0 = root.toLocalX(x0, y0),
			ly0 = root.toLocalY(x0, y0),
			lx1 = root.toLocalX(x1, y1),
			ly1 = root.toLocalY(x1, y1);
		var left = Math.min(lx0, lx1),
			top = Math.min(ly0, ly1),
			right = Math.max(lx0, lx1),
			bottom = Math.max(ly0, ly1);
		scrim.visible = popup != null || pointer.isDown(scrim);
		scrim.setPosition(left, top);
		scrim.setSize(right - left, bottom - top);
		if (popup == null)
			return;
		Layout2D.arrange(popup.layout, 0, 0, right - left, bottom - top, theme.font != null ? theme.font : font);
		var w = popup.layout.width,
			h = popup.layout.height,
			below = popup.anchorY + popup.anchorHeight,
			above = bottom - below < h && popup.anchorY - top > bottom - below;
		var py = above ? popup.anchorY - h : below;
		py = Math.max(top, Math.min(py, bottom - h));
		var px = Math.max(left, Math.min(popup.anchorX, right - w));
		popup.place(px, py, above);
	}

	// Typed text is asked for (IInput.textEntry) while the focused widget takes it, a text field, and let go when none does.
	function syncTextEntry():Void {
		var want = focused != null && focused.takesText(), now = input;
		if (now != textInput) {
			if (textEntry && textInput != null)
				textInput.textEntry = false;
			textEntry = false;
			textInput = now;
		}
		if (want != textEntry) {
			textEntry = want;
			now.textEntry = want;
		}
	}

	// Whether a pad's button went down this frame, on any pad.
	function pad(button:PadButton):Bool {
		for (i in 0...input.padCount) {
			var p = input.getPad(i);
			if (p != null && p.connected && p.isFramePressed(button))
				return true;
		}
		return false;
	}

	function first():Null<Widget> {
		for (w in widgets)
			if (w.focusable && w.enabled && w.interactive && w.visible)
				return w;
		return null;
	}

	// The focusable widget nearest from on screen in direction (dx, dy), or null when none lies that way: one whose layout's center is past from's
	// along that axis, the closest by the distance along it plus twice the offset across it (so the next in a row or column beats a nearer
	// one off to the side). Layouts not yet arranged (all at the origin) find none.
	function nearest(from:Widget, dx:Int, dy:Int):Null<Widget> {
		var b = from.layout, cx = b.x + b.width / 2, cy = b.y + b.height / 2;
		var best:Null<Widget> = null, bestScore = Math.POSITIVE_INFINITY;
		for (w in widgets) {
			if (w == from || !w.focusable || !w.enabled || !w.interactive || !w.visible)
				continue;
			var o = w.layout, ox = o.x + o.width / 2 - cx, oy = o.y + o.height / 2 - cy;
			var along = dx != 0 ? ox * dx : oy * dy,
				across = Math.abs(dx != 0 ? oy : ox);
			if (along <= .5)
				continue;
			var score = along + across * 2;
			if (score < bestScore) {
				bestScore = score;
				best = w;
			}
		}
		return best;
	}

	// The focusable widget after from (direction 1) or before it (-1), wrapping.
	function next(from:Widget, direction:Int):Null<Widget> {
		var n = widgets.length, at = widgets.indexOf(from);
		for (k in 1...n + 1) {
			var w = widgets[((at + direction * k) % n + n) % n];
			if (w.focusable && w.enabled && w.interactive && w.visible)
				return w;
		}
		return from;
	}
}
