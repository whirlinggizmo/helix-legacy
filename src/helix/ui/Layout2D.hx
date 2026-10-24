package helix.ui;

import helix.font.Font;
import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.ShapeShading2D;
import helix.render2d.ShapeForm2D;
import helix.render2d.Sprite2D;
import helix.render2d.Text2D;
import helix.ui.Sizing2D;
import helix.ui.Alignment2D;
import helix.ui.LayoutDirection2D;

/** A rectangle of a 2D layout: rows, columns and stacks of them, each sized fixed, fitted to its content, growing into the room left or as a
	share of its parent, with padding, gaps, margins and alignment (Clay's model, in Haxe, with CSS's margins). Padding is room inside a layout,
	around its children; a gap is room between a row's or column's children, the same between each; a margin is room outside one layout, per
	side, keeping its neighbours and its parent's padding edge away from it. A layout may place a node: arrange() writes its position (by its
	pivot) and, for a sprite or rectangle, its size, once a frame. Layouts only lay out; what's drawn is the nodes'. A widget's layout takes its
	sizing, padding, gap and margin from the theme (Theme) until the game sets that value itself (setSizing, widthSizing, heightSizing,
	setPadding, gap, setMargin): from then on the game's value is kept whatever the theme becomes, even one equal to the theme's, as an inline
	style wins over a stylesheet. Each value is decided apart: a game sizing a button's width leaves its height the theme's. */
class Layout2D {
	var direction:LayoutDirection2D;
	var childLayouts:Array<Layout2D> = [];
	var widthRule:Sizing2D = Fit;
	var heightRule:Sizing2D = Fit;
	var selfX:Null<Alignment2D>;
	var selfY:Null<Alignment2D>;
	var offsetX = 0.;
	var offsetY = 0.;
	// Which of its values a game set (setSizing, widthSizing, heightSizing, setPadding, gap, setMargin): the theme's (themeSizing,
	// themePadding, themeGap, themeMargin) never replace those.
	var gameWidth = false;
	var gameHeight = false;
	var gamePadding = false;
	var gameGap = false;
	var gameMargin = false;
	// Which of its sizings anyone set, the game or the theme (themeSizing): one nobody set is the Fit it starts with, filled by a column or row
	// stretching across.
	var askedWidth = false;
	var askedHeight = false;
	var fitWidth = 0.;
	var fitHeight = 0.;
	var w = 0.;
	var h = 0.;

	/** A layout placing its children direction's way, placing node (or none). */
	public function new(direction:LayoutDirection2D, ?node:Node2D) {
		this.direction = direction;
		this.node = node;
	}

	/** A row, left to right. */
	public static function row(?node:Node2D):Layout2D
		return new Layout2D(Row, node);

	/** A column, top to bottom. */
	public static function column(?node:Node2D):Layout2D
		return new Layout2D(Column, node);

	/** A stack, its children over one another, each by its own alignment. */
	public static function stack(?node:Node2D):Layout2D
		return new Layout2D(Stack, node);

	/** A layout holding node alone, sized to it unless sized otherwise. */
	public static function of(node:Node2D):Layout2D
		return new Layout2D(Stack, node);

	/** Adds child as its last. */
	public function add(child:Layout2D):Void
		childLayouts.push(child);

	/** Takes child out. */
	public function remove(child:Layout2D):Bool
		return childLayouts.remove(child);

	/** Its children, in order. */
	public var children(get, never):Array<Layout2D>;

	function get_children():Array<Layout2D>
		return childLayouts.copy();

	/** The node it places, or null. */
	public var node(default, null):Null<Node2D>;

	/** How its width is decided (Fit, to start, or what the widget it places takes from the theme). Assigning it makes it the game's: the
		theme no longer changes it. */
	public var widthSizing(get, set):Sizing2D;

	function get_widthSizing():Sizing2D
		return widthRule;

	function set_widthSizing(value:Sizing2D):Sizing2D {
		widthRule = value;
		gameWidth = askedWidth = true;
		return value;
	}

	/** How its height is decided, as widthSizing. */
	public var heightSizing(get, set):Sizing2D;

	function get_heightSizing():Sizing2D
		return heightRule;

	function set_heightSizing(value:Sizing2D):Sizing2D {
		heightRule = value;
		gameHeight = askedHeight = true;
		return value;
	}

	/** How its width and height are decided, both made the game's (widthSizing and heightSizing). */
	public function setSizing(width:Sizing2D, height:Sizing2D):Void {
		set_widthSizing(width);
		set_heightSizing(height);
	}

	/** Its padding inside its left edge. */
	public var paddingLeft(default, null):Float = 0.;

	/** Its padding inside its top edge. */
	public var paddingTop(default, null):Float = 0.;

	/** Its padding inside its right edge. */
	public var paddingRight(default, null):Float = 0.;

	/** Its padding inside its bottom edge. */
	public var paddingBottom(default, null):Float = 0.;

	/** Its padding inside its edges (none, to start, or what the widget it places takes from the theme), made the game's: the theme no longer
		changes it. */
	public function setPadding(left:Float, top:Float, right:Float, bottom:Float):Void {
		applyPadding(left, top, right, bottom);
		gamePadding = true;
	}

	function applyPadding(left:Float, top:Float, right:Float, bottom:Float):Void {
		paddingLeft = left;
		paddingTop = top;
		paddingRight = right;
		paddingBottom = bottom;
	}

	/** The room between its children in a row or column (0, to start, or what the widget it places takes from the theme). Assigning it makes
		it the game's: the theme no longer changes it. */
	public var gap(default, set):Float = 0.;

	function set_gap(value:Float):Float {
		gap = value;
		gameGap = true;
		return value;
	}

	/** Its margin outside its left edge: room between it and what's left of it (a neighbour, or its parent's padding edge). */
	public var marginLeft(default, null):Float = 0.;

	/** Its margin outside its top edge. */
	public var marginTop(default, null):Float = 0.;

	/** Its margin outside its right edge. */
	public var marginRight(default, null):Float = 0.;

	/** Its margin outside its bottom edge. */
	public var marginBottom(default, null):Float = 0.;

	/** Its margins outside its edges in units (none, to start, or what the widget it places takes from the theme), made the game's: the theme
		no longer changes them. As CSS's in a flexbox: in a row or column a child's margins add to the gap between it and its neighbours (two
		neighbours' margins never collapse into one, as block flow's vertical margins do) and keep it from its parent's padding edge; they count
		in its parent's Fit; growing children share the room left after every child's margins, and a Percent is of the room its own margins
		leave; stretching across fills the room less its margins across, and Start, Center and End place its margin box; in a stack it's inset
		by them; an anchor's offset moves it inside them. The root's are kept inside arrange's rectangle. False, changing nothing, for a side under
		0 or not finite: a negative margin would pull a layout over its neighbour or past its parent's padding, an overlap rows and columns don't
		lay out (a stack with an anchor's offset does), and it would shrink what a parent fits to. */
	public function setMargin(left:Float, top:Float, right:Float, bottom:Float):Bool {
		if (!validMargin(left, top, right, bottom))
			return false;
		applyMargin(left, top, right, bottom);
		gameMargin = true;
		return true;
	}

	// Whether each side is one setMargin takes: 0 or more and finite.
	static function validMargin(left:Float, top:Float, right:Float, bottom:Float):Bool
		return isMargin(left) && isMargin(top) && isMargin(right) && isMargin(bottom);

	static function isMargin(side:Float):Bool
		return side >= 0 && Math.isFinite(side);

	function applyMargin(left:Float, top:Float, right:Float, bottom:Float):Void {
		marginLeft = left;
		marginTop = top;
		marginRight = right;
		marginBottom = bottom;
	}

	// The theme's values, from widgets (their readTheme, and the defaults their constructors give their layouts): each applied only while the
	// game hasn't set that value itself, and never making it the game's, so a theme changed later still reaches it. A widget's own sizes for a
	// widget it holds (a color picker's field) are its, as a game's: set through the game's calls.
	// Its width's and height's sizing from the theme (null: that way's left be).

	@:allow(helix.ui)
	function themeSizing(width:Null<Sizing2D>, height:Null<Sizing2D>):Void {
		if (width != null && !gameWidth) {
			widthRule = width;
			askedWidth = true;
		}
		if (height != null && !gameHeight) {
			heightRule = height;
			askedHeight = true;
		}
	}

	// Its padding from the theme.

	@:allow(helix.ui)
	function themePadding(left:Float, top:Float, right:Float, bottom:Float):Void {
		if (!gamePadding)
			applyPadding(left, top, right, bottom);
	}

	// Its gap from the theme.

	@:allow(helix.ui)
	function themeGap(value:Float):Void {
		if (!gameGap)
			@:bypassAccessor gap = value;
	}

	// Its margins from the theme (no widget takes one yet; the same path as the others, so one a widget takes later can't claim it), left be
	// when one isn't a margin setMargin would take.

	@:allow(helix.ui)
	function themeMargin(left:Float, top:Float, right:Float, bottom:Float):Void {
		if (!gameMargin && validMargin(left, top, right, bottom))
			applyMargin(left, top, right, bottom);
	}

	/** Where its children go along its row or column. */
	public var mainAlign(default, null):Alignment2D = Start;

	/** Where its children go across its row or column. */
	public var crossAlign(default, null):Alignment2D = Start;

	/** Where its children go: along a row or column (main: Start, Center or End when none grows) and across it (cross; Stretch filling it
		with the children that grow across or whose size across nobody set, the rest keeping their size at their anchor across or its start);
		Start both, to start. */
	public function setAlign(main:Alignment2D, cross:Alignment2D):Void {
		mainAlign = main;
		crossAlign = cross;
	}

	/** Where it goes across a stack, or null for its stack's alignment; across a column stretching its children (crossAlign Stretch) when
		it keeps its own width, where it goes across it (null: its start). */
	public var anchorX(get, never):Null<Alignment2D>;

	function get_anchorX():Null<Alignment2D>
		return selfX;

	/** Where it goes down a stack, or null for its stack's alignment; down a row stretching its children when it keeps its own height, as
		anchorX across a column. */
	public var anchorY(get, never):Null<Alignment2D>;

	function get_anchorY():Null<Alignment2D>
		return selfY;

	/** How far it's moved right from its anchor. */
	public var anchorOffsetX(get, never):Float;

	function get_anchorOffsetX():Float
		return offsetX;

	/** How far it's moved down from its anchor. */
	public var anchorOffsetY(get, never):Float;

	function get_anchorOffsetY():Float
		return offsetY;

	/** Where it goes in a stack (horizontally, vertically; Stretch fills that way), moved by offsetX, offsetY: anchored to an edge, a corner
		or the middle. */
	public function setAnchor(horizontal:Alignment2D, vertical:Alignment2D, offsetX = 0., offsetY = 0.):Void {
		selfX = horizontal;
		selfY = vertical;
		this.offsetX = offsetX;
		this.offsetY = offsetY;
	}

	/** Where the last arrange put it, x of its left edge. */
	public var x(default, null):Float = 0.;

	/** Its top edge as last arranged. */
	public var y(default, null):Float = 0.;

	/** Its width as last arranged. */
	public var width(get, never):Float;

	function get_width():Float
		return w;

	/** Its height as last arranged. */
	public var height(get, never):Float;

	function get_height():Float
		return h;

	/** Lays root and everything in it out in the rectangle x, y, width x height (a screen's, a design resolution's; root's margins inside it)
		and writes the nodes' places: its content measured (texts in their fonts, font for those without one), then each layout placed. Once a
		frame, before drawing. */
	public static function arrange(root:Layout2D, x:Float, y:Float, width:Float, height:Float, font:Font):Void {
		root.measure(font);
		root.x = x + root.marginLeft;
		root.y = y + root.marginTop;
		root.w = sized(root.widthRule, root.fitWidth, Math.max(0, width - root.marginLeft - root.marginRight));
		root.h = sized(root.heightRule, root.fitHeight, Math.max(0, height - root.marginTop - root.marginBottom));
		root.place(font);
	}

	static function sized(sizing:Sizing2D, fit:Float, room:Float):Float
		return switch sizing {
			case Fixed(units): units;
			case Fit: fit;
			case Grow(_): room;
			case Percent(f): room * f;
		}

	// Its content's size, bottom up: its children's (their margins included) along and across its direction, or its node's.
	function measure(font:Font):Void {
		for (c in childLayouts)
			c.measure(font);
		var cw = 0., ch = 0.;
		if (childLayouts.length == 0 && node != null) {
			var text = Std.downcast(node, Text2D),
				shape = Std.downcast(node, Shape2D),
				sprite = Std.downcast(node, Sprite2D);
			if (text != null) {
				cw = text.widthIn(font);
				ch = text.heightIn(font);
			} else if (shape != null && shape.form == Circle)
				cw = ch = shape.radius * 2;
			else if (shape != null) {
				cw = shape.width;
				ch = shape.height;
			} else if (sprite != null) {
				cw = sprite.width;
				ch = sprite.height;
			}
		} else
			for (c in childLayouts) {
				var fw = own(c.widthRule, c.fitWidth) + c.marginLeft + c.marginRight,
					fh = own(c.heightRule, c.fitHeight) + c.marginTop + c.marginBottom;
				switch direction {
					case Row:
						cw += fw;
						ch = Math.max(ch, fh);
					case Column:
						ch += fh;
						cw = Math.max(cw, fw);
					case Stack:
						cw = Math.max(cw, fw);
						ch = Math.max(ch, fh);
				}
			}
		var gaps = childLayouts.length > 1 && direction != Stack ? gap * (childLayouts.length - 1) : 0;
		fitWidth = cw + paddingLeft + paddingRight + (direction == Row ? gaps : 0);
		fitHeight = ch + paddingTop + paddingBottom + (direction == Column ? gaps : 0);
	}

	// What a child asks for before the room is shared: fixed or fitted, nothing yet for growing or a share.
	static function own(sizing:Sizing2D, fit:Float):Float
		return switch sizing {
			case Fixed(units): units;
			case Fit: fit;
			case _: 0;
		}

	// Places its node, then its children in its room, top down.
	function place(font:Font):Void {
		if (node != null) {
			// Its position is its pivot's: a circle's its center; a text, a sprite or a rectangle by its pivot, the latter two sized to it.
			var text = Std.downcast(node, Text2D),
				shape = Std.downcast(node, Shape2D),
				sprite = Std.downcast(node, Sprite2D);
			var px = 0., py = 0.;
			if (text != null) {
				px = text.pivotX * w;
				py = text.pivotY * h;
			} else if (shape != null && shape.form == Circle) {
				px = w / 2;
				py = h / 2;
			} else if (shape != null) {
				shape.setSize(w, h);
				px = shape.pivotX * w;
				py = shape.pivotY * h;
			} else if (sprite != null) {
				sprite.setSize(w, h);
				px = sprite.pivotX * w;
				py = sprite.pivotY * h;
			}
			node.setPosition(x + px, y + py);
		}
		var innerX = x + paddingLeft, innerY = y + paddingTop;
		var innerW = Math.max(0, w - paddingLeft - paddingRight),
			innerH = Math.max(0, h - paddingTop - paddingBottom);
		if (direction == Stack) {
			// Each in the room inside the padding less its margins.
			for (c in childLayouts) {
				var ax = c.selfX != null ? c.selfX : mainAlign,
					ay = c.selfY != null ? c.selfY : crossAlign;
				var roomW = Math.max(0, innerW - c.marginLeft - c.marginRight),
					roomH = Math.max(0, innerH - c.marginTop - c.marginBottom);
				c.w = ax == Stretch ? roomW : sized(c.widthRule, c.fitWidth, roomW);
				c.h = ay == Stretch ? roomH : sized(c.heightRule, c.fitHeight, roomH);
				c.x = innerX + c.marginLeft + offset(ax, roomW, c.w) + c.offsetX;
				c.y = innerY + c.marginTop + offset(ay, roomH, c.h) + c.offsetY;
				c.place(font);
			}
			return;
		}
		var row = direction == Row,
			room = row ? innerW : innerH,
			across = row ? innerH : innerW;
		// The room left after the fixed, fitted and shared children, the gaps and every child's margins along, shared by the growing ones by
		// weight.
		var used = childLayouts.length > 1 ? gap * (childLayouts.length - 1) : 0., weights = 0.;
		for (c in childLayouts) {
			var sizing = row ? c.widthRule : c.heightRule,
				margins = row ? c.marginLeft + c.marginRight : c.marginTop + c.marginBottom;
			used += margins;
			switch sizing {
				case Grow(weight):
					weights += weight;
				case Percent(f):
					used += Math.max(0, room - margins) * f;
				case _:
					used += own(sizing, row ? c.fitWidth : c.fitHeight);
			}
		}
		var left = Math.max(0, room - used),
			at = (row ? innerX : innerY) + (weights > 0 ? 0 : offset(mainAlign, room, used));
		for (c in childLayouts) {
			var sizing = row ? c.widthRule : c.heightRule,
				crossSizing = row ? c.heightRule : c.widthRule;
			// Its margins along (before and after it) and across (at the start and the end).
			var before = row ? c.marginLeft : c.marginTop,
				after = row ? c.marginRight : c.marginBottom,
				crossStart = row ? c.marginTop : c.marginLeft,
				crossEnd = row ? c.marginBottom : c.marginRight;
			var along = switch sizing {
				case Grow(weight): weights > 0 ? left * weight / weights : 0;
				case _: sized(sizing, row ? c.fitWidth : c.fitHeight, Math.max(0, room - before - after));
			}
			// Stretching across fills a child growing across or one whose size across nobody set; one that asked for a size keeps it, at its
			// own anchor across or the start.
			var crossAlignment = crossAlign != Stretch ? crossAlign : switch crossSizing {
				case Grow(_): Stretch;
				case _ if (!(row ? c.askedHeight : c.askedWidth)): Stretch;
				case _:
					var anchor = row ? c.selfY : c.selfX;
					anchor != null ? anchor : Start;
			}
			// Across, in the room less its margins there.
			var crossRoom = Math.max(0, across - crossStart - crossEnd);
			var thick = crossAlignment == Stretch ? crossRoom : sized(crossSizing, row ? c.fitHeight : c.fitWidth, crossRoom);
			var crossAt = (row ? innerY : innerX) + crossStart + offset(crossAlignment, crossRoom, thick);
			at += before;
			if (row) {
				c.x = at;
				c.y = crossAt;
				c.w = along;
				c.h = thick;
			} else {
				c.y = at;
				c.x = crossAt;
				c.h = along;
				c.w = thick;
			}
			c.x += c.offsetX;
			c.y += c.offsetY;
			at += along + after + gap;
			c.place(font);
		}
	}

	static function offset(alignment:Alignment2D, room:Float, size:Float):Float
		return switch alignment {
			case Center: (room - size) / 2;
			case End: room - size;
			case _: 0;
		}
}
