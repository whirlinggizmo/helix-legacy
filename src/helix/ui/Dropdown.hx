package helix.ui;

import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.ShapeShading2D;
import helix.render2d.Text2D;

/** A choice of one of its items, or none. Closed, a face showing the chosen item's text (its hint, in the theme's disabledTextColor, while
	none is chosen) and a chevron at its right. Open, a list of its items over everything (a Popup: drawn above every widget and panel,
	clipped by none, below the face or above it when there's no room below), its rows a list's (the theme's listRowHeight, listPadding and
	list corners), the chosen one in the accent color, the highlighted one hovered; at most maxRows of them, the rest scrolled to by the
	wheel or the shared Scrollbar, opening with the chosen one in view.
	The pointer: a click opens it; a click on an item chooses it and closes it; a press anywhere off the list closes it without changing the
	choice, and does nothing else. Keys and a pad, with focus: Enter, Space or South opens it, the chosen item highlighted; Up and Down move the
	highlight (the pointer moving over a row moves it there too); Enter, Space or South chooses the highlighted item and closes it; Escape or
	East closes it unchanged. While it's closed the arrows move focus as for any widget (they don't step the choice, so a column of them is
	walked by Up and Down); while it's open it has the keys (Ui.capturingKeys) and Tab doesn't move focus. Its face is drawn by its state
	(WidgetState: a face, pressed while open), disabled dimmed and never opened. As wide as its widest item (and its hint) and the chevron to
	start, as its layout is Fit (the theme's, so a column stretching its children, a panel's, leaves it so); a width the game gives its layout is
	kept, the text clipped short of the chevron. Its list is as wide as it,
	and a scrollbar's room wider when it scrolls. Ask selectedIndex, selected and changed once a frame. */
class Dropdown extends Widget {
	var face:Shape2D;
	var chevron:Chevron;
	// The chosen item's text (or the hint), clipped to the room left of the chevron.
	var textWindow:Node2D;
	var shownText:Text2D;
	// Every item's text (and the hint) measured by the layout and never drawn: the face is as wide as the widest.
	var measured:Null<Layout2D>;
	var measures:Array<Text2D> = [];
	var hintMeasure:Text2D;
	var chevronRoom:Layout2D;
	// The list, its rows in a window clipped inside its padding, scrolled.
	var popFace:Shape2D;
	var popLayout:Layout2D;
	var window:Node2D;
	var content:Node2D;
	var rows:Array<{face:Shape2D, text:Text2D}> = [];
	var bar:Scrollbar;
	var itemList:Array<String> = [];
	var chosen = -1;
	var highlight = -1;
	var scroll = 0.;
	// Whether the press held on the list began on its scrollbar; where the pointer was last frame (the highlight follows it only as it moves).
	var onBar = false;
	var lastX = Math.NaN;
	var lastY = Math.NaN;

	@:allow(helix.ui.Ui)
	function new(ui:Ui, name:String, items:Array<String>) {
		super(ui, name);
		var theme = ui.theme;
		face = Shape2D.rectangle(1, 1, theme.faceColor);
		face.setPivot(0, 0);
		root.addChild(face);
		textWindow = new Node2D();
		shownText = new Text2D("", theme.textSize, theme.textColor, theme.font);
		shownText.pickable = false;
		textWindow.addChild(shownText);
		root.addChild(textWindow);
		chevron = new Chevron(root, false);
		hintMeasure = measure("");
		chevronRoom = Layout2D.stack();
		layout = Layout2D.row(face);
		layout.setAlign(Start, Center);
		layout.themeSizing(Fit, null);
		layout.add(chevronRoom);
		popFace = Shape2D.rectangle(1, 1, theme.faceColor);
		popFace.setPivot(0, 0);
		window = new Node2D();
		content = new Node2D();
		window.addChild(content);
		popLayout = Layout2D.of(popFace);
		popup = new Popup(this, popLayout);
		popup.root.addChild(popFace);
		popup.root.addChild(window);
		bar = new Scrollbar(popup.root, theme);
		// Its look from the theme, with its rows' (readTheme).
		this.items = items;
	}

	// A text measured for the face's width, never drawn or picked.
	function measure(text:String):Text2D {
		var node = new Text2D(text);
		node.visible = false;
		root.addChild(node);
		return node;
	}

	/** Its items. Assigning them chooses none and closes its list. */
	public var items(get, set):Array<String>;

	function get_items():Array<String>
		return itemList.copy();

	function set_items(value:Array<String>):Array<String> {
		if (popup.open)
			ui.closePopup();
		itemList = value.copy();
		for (r in rows) {
			content.removeChild(r.face);
			content.removeChild(r.text);
		}
		rows = [];
		for (m in measures)
			root.removeChild(m);
		measures = [];
		if (measured != null)
			layout.remove(measured);
		measured = Layout2D.stack();
		measured.add(Layout2D.of(hintMeasure));
		for (item in itemList) {
			// Sized, placed and styled from the theme by readTheme and update.
			var rowFace = Shape2D.rectangle(1, 1, 0);
			rowFace.setPivot(0, 0);
			rowFace.pickable = false;
			var text = new Text2D(item);
			text.pickable = false;
			content.addChild(rowFace);
			content.addChild(text);
			rows.push({face: rowFace, text: text});
			var m = measure(item);
			measures.push(m);
			measured.add(Layout2D.of(m));
		}
		layout.remove(chevronRoom);
		layout.add(measured);
		layout.add(chevronRoom);
		chosen = -1;
		scroll = 0;
		readTheme(ui.theme);
		showChoice();
		return value;
	}

	/** The chosen item's index, or -1 for none; assigning one isn't counted as a change. Clamped to -1 to the last item's index. */
	public var selectedIndex(get, set):Int;

	function get_selectedIndex():Int
		return chosen;

	function set_selectedIndex(index:Int):Int {
		index = index < -1 ? -1 : index >= itemList.length ? itemList.length - 1 : index;
		chosen = index;
		showChoice();
		return index;
	}

	/** The chosen item's text, or null for none. */
	public var selected(get, never):Null<String>;

	function get_selected():Null<String>
		return chosen >= 0 ? itemList[chosen] : null;

	/** What its face shows while no item is chosen. ("" to start.) */
	public var hint(get, set):String;

	function get_hint():String
		return hintMeasure.text;

	function set_hint(value:String):String {
		hintMeasure.text = value;
		showChoice();
		return value;
	}

	/** The most rows its list shows at once, the rest scrolled to. (8 to start.) At least 1 (under 1 is 1). */
	public var maxRows(default, set):Int = 8;

	function set_maxRows(value:Int):Int {
		value = value >= 1 ? value : 1;
		maxRows = value;
		return value;
	}

	/** Whether the choice changed this frame, by the pointer or the keys (not by assigning selectedIndex). */
	public var changed(default, null):Bool = false;

	/** Whether its list is open. */
	public var open(get, never):Bool;

	function get_open():Bool
		return popup.open;

	/** The index of the item its list highlights (the one Enter would choose), or -1; meaningful while it's open. */
	public var highlightedIndex(get, never):Int;

	function get_highlightedIndex():Int
		return highlight;

	/** Its list, the popup it opens: where it was last placed (Popup.x, y, placedAbove) and its size (Popup.layout). */
	public var popup(default, null):Popup;

	override function get_focusable():Bool
		return true;

	override function target():Null<Node2D>
		return face;

	override function takesUpDown():Bool
		return popup.open;

	override function takesSideways():Bool
		return popup.open;

	// The face's text: the chosen item's, or the hint.
	function showChoice():Void
		shownText.text = chosen >= 0 ? itemList[chosen] : hintMeasure.text;

	// The rows the list shows at once.
	function shownRows():Int
		return Std.int(Math.max(1, Math.min(itemList.length, maxRows)));

	// While its list is open: "list", the whole of it; "row:<index>", that item's row where it's scrolled to (in view or not); "track" and
	// "thumb", its scrollbar's while it shows. In the popup's units.
	override function locatePart(part:String, out:Array<Float>):Null<Node2D> {
		if (part == "")
			return super.locatePart(part, out);
		if (!popup.open)
			return null;
		var theme = ui.theme,
			pad = theme.listPadding,
			height = theme.listRowHeight,
			row = Widget.rowPart(part);
		if (part == "list")
			Widget.setRectangle(out, popLayout.x, popLayout.y, popLayout.width, popLayout.height);
		else if (row >= 0 && row < itemList.length) {
			var inside = Math.max(0, popLayout.width - pad * 2 - (bar.visible ? bar.width + pad : 0));
			Widget.setRectangle(out, pad, pad + row * height - scroll, inside, height);
		} else if (row >= 0 || !bar.computePart(part, out))
			return null;
		return popup.root;
	}

	// Scrolls row into view, as little as it takes.
	function reveal(row:Int):Void {
		var height = ui.theme.listRowHeight;
		if (row >= 0)
			scroll = Math.max(Math.min(scroll, row * height), (row + 1) * height - shownRows() * height);
	}

	override function readTheme(theme:Theme):Void {
		face.cornerRadius = theme.cornerRadius;
		shownText.textSize = theme.textSize;
		shownText.font = theme.font;
		hintMeasure.textSize = theme.textSize;
		hintMeasure.font = theme.font;
		for (m in measures) {
			m.textSize = theme.textSize;
			m.font = theme.font;
		}
		themeFixed(layout, Math.NaN, theme.widgetHeight);
		layout.themePadding(theme.padding, 0, theme.padding, 0);
		layout.themeGap(theme.padding / 2);
		themeFixed(chevronRoom, theme.widgetHeight * .4, Math.NaN);
		popFace.cornerRadius = theme.listCornerRadius;
		for (r in rows) {
			r.face.cornerRadius = theme.listRowCornerRadius;
			r.text.textSize = theme.textSize;
			r.text.font = theme.font;
		}
		bar.readTheme(theme);
	}

	override function update(hovered:Bool, held:Bool, clicked:Bool, focused:Bool, activated:Bool, stepX:Int, stepY:Int):Void {
		var theme = ui.theme,
			input = ui.input,
			pointer = ui.pointer,
			height = theme.listRowHeight,
			pad = theme.listPadding,
			count = itemList.length;
		changed = false;
		var view = shownRows() * height,
			total = count * height,
			scrolls = Scrollbar.isShown(theme.scrollbarVisibility, view, total);
		var listWidth = layout.width + (scrolls ? bar.width + pad : 0),
			inside = Math.max(0, listWidth - pad * 2 - (scrolls ? bar.width + pad : 0));
		// The pointer in the list's units (its face's, at its top left), as the list was last drawn.
		var wx = ui.camera.screenToWorldX(input.pointerX),
			wy = ui.camera.screenToWorldY(input.pointerY);
		var px = popFace.toLocalX(wx, wy), py = popFace.toLocalY(wx, wy);
		var moved = input.pointerX != lastX || input.pointerY != lastY;
		lastX = input.pointerX;
		lastY = input.pointerY;
		// The row under the pointer, on the list, off its scrollbar and its padding, or -1.
		var pointed = -1;
		bar.setTrack(listWidth - pad - bar.width, pad, view, view, total, scrolls);
		if (popup.open && pointer.isHovered(popFace) && !bar.dragging && !bar.isOver(px, py) && px >= pad && px < pad + inside && py >= pad && py < pad
			+ view) {
			var row = Math.floor((py - pad + scroll) / height);
			pointed = row >= 0 && row < count ? row : -1;
		}
		if (!popup.open) {
			// Closed: a click, or Enter, Space or South, opens it at the chosen item.
			if (enabled && (clicked || activated) && count > 0) {
				highlight = chosen;
				scroll = 0;
				reveal(chosen);
				onBar = false;
				ui.openPopup(popup);
			}
		} else if (clicked) {
			// Used by name again (Ui.press) while open: closed.
			ui.closePopup();
		} else {
			if (input.wheelY != 0 && pointer.isHovered(popFace))
				scroll -= input.wheelY * height;
			// The scrollbar has a press that began on it; a click elsewhere on the list chooses the row under it.
			if (pointer.isPressed(popFace)) {
				onBar = bar.isOver(px, py);
				if (onBar)
					scroll = bar.drive(px, py, true, true, scroll);
			} else if (pointer.isDown(popFace) && onBar)
				scroll = bar.drive(px, py, false, true, scroll);
			else
				bar.drive(px, py, false, false, scroll);
			if (moved && pointed >= 0)
				highlight = pointed;
			if (stepY != 0 && count > 0) {
				highlight = highlight < 0 ? 0 : Std.int(Math.max(0, Math.min(count - 1, highlight + stepY)));
				reveal(highlight);
			}
			var choice = -2;
			if (pointer.isClicked(popFace) && !onBar && pointed >= 0)
				choice = pointed;
			else if (activated && highlight >= 0)
				choice = highlight;
			if (!pointer.isDown(popFace))
				onBar = false;
			if (choice >= 0) {
				changed = choice != chosen;
				chosen = choice;
				showChoice();
				ui.closePopup();
			}
		}
		scroll = Math.max(0, Math.min(scroll, Math.max(0, total - view)));
		// The face by its state (pressed while its list is open), its text left of the chevron, clipped short of it.
		var state = WidgetState.of(enabled, held || popup.open, hovered, focused);
		face.color = state.face(theme);
		shownText.color = chosen < 0 ? theme.disabledTextColor : state.text(theme);
		chevron.color = state.text(theme);
		var room = chevronRoom.width;
		textWindow.setPosition(layout.x + layout.paddingLeft, layout.y);
		textWindow.setClip(Math.max(0, layout.width - layout.paddingLeft - layout.paddingRight - layout.gap - room), layout.height);
		shownText.setPosition(0, (layout.height - theme.textSize) / 2);
		chevron.setSize(layout.height);
		chevron.setPosition(layout.x + layout.width - layout.paddingRight - room / 2, layout.y + (layout.height + chevron.depth) / 2);
		if (!popup.open)
			return;
		// The list: as wide as the face (and the scrollbar's room), its rows a list's; hung from the face as drawn.
		var x0 = face.toWorldX(0, 0),
			y0 = face.toWorldY(0, 0),
			x1 = face.toWorldX(layout.width, layout.height),
			y1 = face.toWorldY(layout.width, layout.height);
		var ax = ui.root.toLocalX(x0, y0), ay = ui.root.toLocalY(x0, y0);
		popup.setAnchor(ax, ay, ui.root.toLocalX(x1, y1) - ax, ui.root.toLocalY(x1, y1) - ay);
		themeFixed(popLayout, listWidth, view + pad * 2);
		popFace.color = theme.faceColor;
		window.setPosition(pad, pad);
		window.setClip(inside, view);
		content.setPosition(0, -scroll);
		var textX = Math.max(0, theme.padding - pad);
		for (i in 0...rows.length) {
			var r = rows[i];
			r.face.setSize(inside, height);
			r.face.setPosition(0, i * height);
			var rowState = WidgetState.of(enabled, i == pointed && pointer.isDown(popFace) && !onBar, i == highlight, false);
			r.face.color = i == chosen ? theme.accentColor : rowState.pick(0, theme.hoveredColor, theme.pressedColor, 0, 0);
			r.text.color = rowState.text(theme);
			r.text.setPosition(textX, i * height + (height - theme.textSize) / 2);
		}
		bar.place(scroll, pointer.isHovered(popFace) || bar.dragging ? px : Math.NaN, py, enabled, theme);
	}
}
