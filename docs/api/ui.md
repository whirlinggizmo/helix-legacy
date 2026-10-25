# helix.ui

[Back to the index](README.md)

## Alignment2D

*enum* in [`src/helix/ui/Alignment2D.hx`](../../src/helix/ui/Alignment2D.hx), `import helix.ui.Alignment2D;`

Where layouts go in the room they have, along an axis.

- `Start`: At its start: the left, or the top.
- `Center`: In its middle.
- `End`: At its end: the right, or the bottom.
- `Stretch`: Across a row or column only: filling it, for the children that grow that way or whose size that way nobody set (widthSizing, heightSizing; the theme's included); the others keep their size there, at their anchor that way or at its start. In a stack, as an anchor: filling it that way.

## Button

*class* in [`src/helix/ui/Button.hx`](../../src/helix/ui/Button.hx), `import helix.ui.Button;`

A button reading a line of text: clicked by the pointer (released over it, as pressed), or activated with focus by Enter, Space or a pad's South. Ask clicked once a frame.

```haxe
var clicked(default, null):Bool
var text(get, set):String
```

- `clicked`: Whether it was clicked or activated this frame.
- `text`: Its text.

## Chevron

*class* in [`src/helix/ui/Chevron.hx`](../../src/helix/ui/Chevron.hx), `import helix.ui.Chevron;`

A chevron drawn on a widget's face, pointing up or down (a color picker's format button, a dropdown's face): two arms meeting at its point, sized for the face's height, never picked. One part, so every widget's chevron looks alike. Its place is in its parent's units.

```haxe
function new(parent:Node2D, up:Bool)
var depth(default, null):Float
var color(get, set):Int
var visible(get, set):Bool
function setSize(height:Float):Void
function setPosition(x:Float, y:Float):Void
```

- `new`: Makes a chevron under parent, pointing up (up) or down, shaped by setSize.
- `depth`: How far it reaches from its point toward its open end, in units, as last shaped: its arms' reach and their thickness.
- `color`: Its color, 0xAARRGGBB.
- `visible`: Whether it's drawn.
- `setSize`: Shapes it for a face height units tall: its arms reaching .18 of it out to each side and back from its point, .08 of it thick (at least 1.5 units). Made again only when height changed.
- `setPosition`: Puts its point at x, y, in its parent's units.

## ColorFormat

*enum* in [`src/helix/ui/ColorFormat.hx`](../../src/helix/ui/ColorFormat.hx), `import helix.ui.ColorFormat;`

How a color picker's text field writes and reads its color (ColorPicker.format).

- `Hex`: Hex digits: RRGGBBAA, or RRGGBB without alpha (ColorPicker.formatHex, parseHex).
- `Rgba`: The channels in decimal, 0 to 255 each: r g b a, or r g b without alpha (ColorPicker.formatRgba, parseRgba).

## ColorPicker

*class* in [`src/helix/ui/ColorPicker.hx`](../../src/helix/ui/ColorPicker.hx), `import helix.ui.ColorPicker;`

A color, 0xAARRGGBB, chosen as hue, saturation and brightness (HSV's value). Top to bottom: a square of saturation (left to right) and brightness (bottom to top) in the hue, edge to edge across the picker and as tall as it's wide; under it a strip of a round swatch of the color (over a checkerboard, as its alpha shows it) beside thin bars, the hue's (left to right red, yellow, green, cyan, blue, magenta and red again) and with alpha the alpha's under it (clear at the left, opaque at the right), each with a round handle; then a text field writing the color in its format (textField, a TextField of its own), a button beside it cycling the format (formatButton) and the format's name under the field. The pointer drags in the square or a bar, the part it went down on, wherever it moves after. With focus, Enter, Space or a pad's South steps through the parts the arrows and the D-pad drive: the square (Left and Right saturation, Up and Down brightness), the hue bar, the alpha bar (Right and Up raise, Left and Down lower) and none, when they move focus again; each step a twentieth of the way. The part they drive has its handle in the theme's focus color. The field takes the color in its format (Hex: RRGGBBAA or RRGGBB, with or without a leading #, in either case; Rgba: r g b a or r g b, 0 to 255 each, apart by spaces or a comma), without alpha meaning 0xff: the color follows it as typed, text naming no color is marked invalid (TextField.invalid) and changes nothing, and once the field loses focus it shows the color again. Its hue (and saturation) are kept where the color doesn't say them: dragging through grey or black doesn't lose the hue. It's as wide as its layout is given: theme.colorPickerWidth (layout sized Fixed that wide, following the theme until the game sizes its layout's width itself, kept in a column stretching its children, a panel's), or what a column gives it sized Grow(1); the square takes a new width a frame later. Ask color, and changed once a frame.

```haxe
static function fromHsv(hue:Float, saturation:Float, brightness:Float, ?alpha:Int = 0xff):Int
static function parseHex(text:String):Null<Int>
static function formatHex(color:Int, alpha:Bool):String
static function parseRgba(text:String):Null<Int>
static function formatRgba(color:Int, alpha:Bool):String
var textField(default, null):TextField
var formatButton(default, null):Widget
var format(default, set):ColorFormat
var color(get, set):Int
var hue(get, set):Float
var saturation(get, set):Float
var brightness(get, set):Float
var changed(default, null):Bool
```

- `fromHsv`: The color 0xAARRGGBB of hue (0 to 1 around, red at both ends), saturation and brightness (0 to 1 each; out of range clamped) and alpha (0 to 255), each channel rounded to the nearest of 255.
- `parseHex`: The color text names, 0xAARRGGBB: RRGGBBAA, or RRGGBB meaning alpha 0xff, hex digits in either case, with or without a leading # and with spaces around. Null for anything else.
- `formatHex`: color as lowercase hex, RRGGBBAA, or RRGGBB without alpha.
- `parseRgba`: The color text names, 0xAARRGGBB: r g b a, or r g b meaning alpha 255, each a whole number 0 to 255 in decimal (at most 3 digits), apart by spaces, a comma, or a comma with spaces around it, with spaces around the whole. Null for anything else.
- `formatRgba`: color's channels in decimal, 0 to 255 each, apart by a space: r g b a, or r g b without alpha.
- `textField`: Its text field: the color in its format, typed in (a widget of its own, named after the picker with "-text"). Its layout is the picker's to size and pad, whatever the theme.
- `formatButton`: The button beside its text field cycling its format (a widget of its own, named after the picker with "-format"): clicked, or activated with focus by Enter, Space or a pad's South.
- `format`: How its text field writes and reads the color: Hex (to start) or Rgba. The field shows the color in it at once, its caption under it naming it (HEX, RGBA, or RGB without alpha).
- `color`: Its color, 0xAARRGGBB. Assigning one keeps the hue where the color doesn't say it (a grey, black), and the saturation where it's black; without alpha, the alpha is 0xff whatever is assigned.
- `hue`: Its hue, 0 to 1 around (red at 0 and 1, then yellow, green, cyan, blue and magenta at sixths); kept through greys and black. Clamped to 0 to 1.
- `saturation`: Its saturation, 0 (grey) to 1 (the full hue); kept through black. Clamped to 0 to 1.
- `brightness`: Its brightness (HSV's value), 0 (black) to 1. Clamped to 0 to 1.
- `changed`: Whether its color changed this frame: dragged, nudged by keys or typed.

## Dropdown

*class* in [`src/helix/ui/Dropdown.hx`](../../src/helix/ui/Dropdown.hx), `import helix.ui.Dropdown;`

A choice of one of its items, or none. Closed, a face showing the chosen item's text (its hint, in the theme's disabledTextColor, while none is chosen) and a chevron at its right. Open, a list of its items over everything (a Popup: drawn above every widget and panel, clipped by none, below the face or above it when there's no room below), its rows a list's (the theme's listRowHeight, listPadding and list corners), the chosen one in the accent color, the highlighted one hovered; at most maxRows of them, the rest scrolled to by the wheel or the shared Scrollbar, opening with the chosen one in view. The pointer: a click opens it; a click on an item chooses it and closes it; a press anywhere off the list closes it without changing the choice, and does nothing else. Keys and a pad, with focus: Enter, Space or South opens it, the chosen item highlighted; Up and Down move the highlight (the pointer moving over a row moves it there too); Enter, Space or South chooses the highlighted item and closes it; Escape or East closes it unchanged. While it's closed the arrows move focus as for any widget (they don't step the choice, so a column of them is walked by Up and Down); while it's open it has the keys (Ui.capturingKeys) and Tab doesn't move focus. Its face is drawn by its state (WidgetState: a face, pressed while open), disabled dimmed and never opened. As wide as its widest item (and its hint) and the chevron to start, as its layout is Fit (the theme's, so a column stretching its children, a panel's, leaves it so); a width the game gives its layout is kept, the text clipped short of the chevron. Its list is as wide as it, and a scrollbar's room wider when it scrolls. Ask selectedIndex, selected and changed once a frame.

```haxe
var items(get, set):Array<String>
var selectedIndex(get, set):Int
var selected(get, never):Null<String>
var hint(get, set):String
var maxRows(default, set):Int
var changed(default, null):Bool
var open(get, never):Bool
var highlightedIndex(get, never):Int
var popup(default, null):Popup
```

- `items`: Its items. Assigning them chooses none and closes its list.
- `selectedIndex`: The chosen item's index, or -1 for none; assigning one isn't counted as a change. Clamped to -1 to the last item's index.
- `selected`: The chosen item's text, or null for none.
- `hint`: What its face shows while no item is chosen. ("" to start.)
- `maxRows`: The most rows its list shows at once, the rest scrolled to. (8 to start.) At least 1 (under 1 is 1).
- `changed`: Whether the choice changed this frame, by the pointer or the keys (not by assigning selectedIndex).
- `open`: Whether its list is open.
- `highlightedIndex`: The index of the item its list highlights (the one Enter would choose), or -1; meaningful while it's open.
- `popup`: Its list, the popup it opens: where it was last placed (Popup.x, y, placedAbove) and its size (Popup.layout).

## FullscreenButton2D

*class* in [`src/helix/ui/FullscreenButton2D.hx`](../../src/helix/ui/FullscreenButton2D.hx), `import helix.ui.FullscreenButton2D;`

An icon that toggles fullscreen: four corner brackets, pointing out while windowed and in while fullscreen, brighter under the pointer. On the stage at the visible area's top right, margin in, whatever the window's shape; drawn nothing where the window can't go fullscreen (Window.canFullscreen: a page that may not). A click on it asks (Window.requestFullscreen), which the browser grants as it follows a click. It needs no Ui and runs itself: add it to the stage, over the game (added again after a screen that goes over it).

```haxe
function new(?size:Float = 18., ?color:Int = 0xc0e8e8e8)
var size(default, null):Float
var color:Int
var margin:Float
var hovered(default, null):Bool
function covers(x:Float, y:Float):Bool
```

- `new`: An icon size stage units across (18 unless given), in color (0xAARRGGBB, a light gray unless given).
- `size`: Its size across, the stage's units.
- `color`: Its color, 0xAARRGGBB; drawn opaque under the pointer.
- `margin`: How far in from the visible area's top-right corner it sits, the stage's units: 10 to start.
- `hovered`: Whether the pointer is over it, as of the last frame drawn: a game skips its own click there.
- `covers`: Whether stage point x, y is on the icon, as it was last placed: for a game's own controls to leave it be (a touch stick's touchStickBlocked, say).

## Handle

*class* in [`src/helix/ui/Handle.hx`](../../src/helix/ui/Handle.hx), `import helix.ui.Handle;`

The round handle a widget drags along a track (a slider's, a color picker's bars): a disc theme.handleSize across in theme.handleColor over a ring of theme.handleShadowColor a little wider, so it shows on any color under it; centered on its position, never picked. One part, so every widget's handle looks alike.

```haxe
function new(parent:Node2D, theme:Theme)
function readTheme(theme:Theme):Void
var color(get, set):Int
var visible(get, set):Bool
function setPosition(x:Float, y:Float):Void
```

- `new`: Makes a handle in theme's look under parent.
- `readTheme`: Takes its size and its ring's color from theme (its disc's color is its owner's to set: color). Its owner calls it as it reads the theme, every frame, so a changed theme shows at once.
- `color`: The disc's color, 0xAARRGGBB: its owner's, by the handle's state (WidgetState.handle).
- `visible`: Whether it's drawn.
- `setPosition`: Centers it on x, y in its parent's units.

## Label

*class* in [`src/helix/ui/Label.hx`](../../src/helix/ui/Label.hx), `import helix.ui.Label;`

A line of text: shown, never focused. Its size and color are the theme's unless given its own (textSize, color).

```haxe
var text(get, set):String
var textSize:Null<Float>
var color:Null<Int>
```

- `text`: Its text.
- `textSize`: Its text's height in units, or null (to start) for the theme's textSize: a value is kept whatever the theme becomes.
- `color`: Its text's color, 0xAARRGGBB, or null (to start) for the theme's textColor: a value is kept whatever the theme becomes.

## Layout2D

*class* in [`src/helix/ui/Layout2D.hx`](../../src/helix/ui/Layout2D.hx), `import helix.ui.Layout2D;`

A rectangle of a 2D layout: rows, columns and stacks of them, each sized fixed, fitted to its content, growing into the room left or as a share of its parent, with padding, gaps, margins and alignment (Clay's model, in Haxe, with CSS's margins). Padding is room inside a layout, around its children; a gap is room between a row's or column's children, the same between each; a margin is room outside one layout, per side, keeping its neighbours and its parent's padding edge away from it. A layout may place a node: arrange() writes its position (by its pivot) and, for a sprite or rectangle, its size, once a frame. Layouts only lay out; what's drawn is the nodes'. A widget's layout takes its sizing, padding, gap and margin from the theme (Theme) until the game sets that value itself (setSizing, widthSizing, heightSizing, setPadding, gap, setMargin): from then on the game's value is kept whatever the theme becomes, even one equal to the theme's, as an inline style wins over a stylesheet. Each value is decided apart: a game sizing a button's width leaves its height the theme's.

```haxe
function new(direction:LayoutDirection2D, ?node:Node2D)
static function row(?node:Node2D):Layout2D
static function column(?node:Node2D):Layout2D
static function stack(?node:Node2D):Layout2D
static function of(node:Node2D):Layout2D
static function arrange(root:Layout2D, x:Float, y:Float, width:Float, height:Float, font:Font):Void
function add(child:Layout2D):Void
function remove(child:Layout2D):Bool
var children(get, never):Array<Layout2D>
var node(default, null):Null<Node2D>
var widthSizing(get, set):Sizing2D
var heightSizing(get, set):Sizing2D
function setSizing(width:Sizing2D, height:Sizing2D):Void
var paddingLeft(default, null):Float
var paddingTop(default, null):Float
var paddingRight(default, null):Float
var paddingBottom(default, null):Float
function setPadding(left:Float, top:Float, right:Float, bottom:Float):Void
var gap(default, set):Float
var marginLeft(default, null):Float
var marginTop(default, null):Float
var marginRight(default, null):Float
var marginBottom(default, null):Float
function setMargin(left:Float, top:Float, right:Float, bottom:Float):Bool
var mainAlign(default, null):Alignment2D
var crossAlign(default, null):Alignment2D
function setAlign(main:Alignment2D, cross:Alignment2D):Void
var anchorX(get, never):Null<Alignment2D>
var anchorY(get, never):Null<Alignment2D>
var anchorOffsetX(get, never):Float
var anchorOffsetY(get, never):Float
function setAnchor(horizontal:Alignment2D, vertical:Alignment2D, ?offsetX:Float = 0., ?offsetY:Float = 0.):Void
var x(default, null):Float
var y(default, null):Float
var width(get, never):Float
var height(get, never):Float
```

- `new`: A layout placing its children direction's way, placing node (or none).
- `row`: A row, left to right.
- `column`: A column, top to bottom.
- `stack`: A stack, its children over one another, each by its own alignment.
- `of`: A layout holding node alone, sized to it unless sized otherwise.
- `arrange`: Lays root and everything in it out in the rectangle x, y, width x height (a screen's, a design resolution's; root's margins inside it) and writes the nodes' places: its content measured (texts in their fonts, font for those without one), then each layout placed. Once a frame, before drawing.
- `add`: Adds child as its last.
- `remove`: Takes child out.
- `children`: Its children, in order.
- `node`: The node it places, or null.
- `widthSizing`: How its width is decided (Fit, to start, or what the widget it places takes from the theme). Assigning it makes it the game's: the theme no longer changes it.
- `heightSizing`: How its height is decided, as widthSizing.
- `setSizing`: How its width and height are decided, both made the game's (widthSizing and heightSizing).
- `paddingLeft`: Its padding inside its left edge.
- `paddingTop`: Its padding inside its top edge.
- `paddingRight`: Its padding inside its right edge.
- `paddingBottom`: Its padding inside its bottom edge.
- `setPadding`: Its padding inside its edges (none, to start, or what the widget it places takes from the theme), made the game's: the theme no longer changes it.
- `gap`: The room between its children in a row or column (0, to start, or what the widget it places takes from the theme). Assigning it makes it the game's: the theme no longer changes it.
- `marginLeft`: Its margin outside its left edge: room between it and what's left of it (a neighbour, or its parent's padding edge).
- `marginTop`: Its margin outside its top edge.
- `marginRight`: Its margin outside its right edge.
- `marginBottom`: Its margin outside its bottom edge.
- `setMargin`: Its margins outside its edges in units (none, to start, or what the widget it places takes from the theme), made the game's: the theme no longer changes them. As CSS's in a flexbox: in a row or column a child's margins add to the gap between it and its neighbours (two neighbours' margins never collapse into one, as block flow's vertical margins do) and keep it from its parent's padding edge; they count in its parent's Fit; growing children share the room left after every child's margins, and a Percent is of the room its own margins leave; stretching across fills the room less its margins across, and Start, Center and End place its margin box; in a stack it's inset by them; an anchor's offset moves it inside them. The root's are kept inside arrange's rectangle. False, changing nothing, for a side under 0 or not finite: a negative margin would pull a layout over its neighbour or past its parent's padding, an overlap rows and columns don't lay out (a stack with an anchor's offset does), and it would shrink what a parent fits to.
- `mainAlign`: Where its children go along its row or column.
- `crossAlign`: Where its children go across its row or column.
- `setAlign`: Where its children go: along a row or column (main: Start, Center or End when none grows) and across it (cross; Stretch filling it with the children that grow across or whose size across nobody set, the rest keeping their size at their anchor across or its start); Start both, to start.
- `anchorX`: Where it goes across a stack, or null for its stack's alignment; across a column stretching its children (crossAlign Stretch) when it keeps its own width, where it goes across it (null: its start).
- `anchorY`: Where it goes down a stack, or null for its stack's alignment; down a row stretching its children when it keeps its own height, as anchorX across a column.
- `anchorOffsetX`: How far it's moved right from its anchor.
- `anchorOffsetY`: How far it's moved down from its anchor.
- `setAnchor`: Where it goes in a stack (horizontally, vertically; Stretch fills that way), moved by offsetX, offsetY: anchored to an edge, a corner or the middle.
- `x`: Where the last arrange put it, x of its left edge.
- `y`: Its top edge as last arranged.
- `width`: Its width as last arranged.
- `height`: Its height as last arranged.

## LayoutDirection2D

*enum* in [`src/helix/ui/LayoutDirection2D.hx`](../../src/helix/ui/LayoutDirection2D.hx), `import helix.ui.LayoutDirection2D;`

How a layout lays its children out.

- `Row`: Left to right.
- `Column`: Top to bottom.
- `Stack`: Over one another, each placed by its own alignment in the layout (anchored to an edge, a corner or the middle).

## ListView

*class* in [`src/helix/ui/ListView.hx`](../../src/helix/ui/ListView.hx), `import helix.ui.ListView;`

A list of items in a window rows tall: scrolled by the wheel over it, a drag or its scrollbar (Scrollbar, at its right edge as scrollbarVisibility says, the rows narrowing for it while it shows: its thumb dragged, its track pressed above or below the thumb for a page), an item chosen by a click or, with focus, by Up and Down (scrolled into view), and activated by a click on the chosen one or Enter, Space or a pad's South. Ask selectedIndex, changed and activated once a frame.

```haxe
var items(get, set):Array<String>
var selectedIndex(get, set):Int
var changed(default, null):Bool
var activated(default, null):Bool
var scrollbarVisibility:Null<ScrollbarVisibility>
var scrollbarShown(get, never):Bool
```

- `items`: Its items.
- `selectedIndex`: The chosen item's index, or -1 for none; assigning one scrolls it into view, not counted as a change. Clamped to -1 to the last item's index.
- `changed`: Whether the chosen item changed this frame.
- `activated`: Whether the chosen item was activated this frame: clicked again, or Enter, Space or South with focus.
- `scrollbarVisibility`: When its scrollbar is drawn, or null (to start) for the theme's scrollbarVisibility: a value is kept whatever the theme becomes.
- `scrollbarShown`: Whether its scrollbar is drawn, as last updated.

## Panel

*class* in [`src/helix/ui/Panel.hx`](../../src/helix/ui/Panel.hx), `import helix.ui.Panel;`

A background holding a column of widgets (add): hidden, they're hidden with it. A plain rectangle in the theme's panel color, or a nine-slice frame (setFrame); with a title, a band across its top holding it, the column under the band. Never focused; the pointer stops at it, so what's under a panel doesn't see it.

```haxe
var title(default, set):Null<String>
function add(widget:Widget):Void
var content(default, null):Layout2D
function adopt(widget:Widget):Void
function setFrame(texture:Null<Texture2D>, left:Float, top:Float, right:Float, bottom:Float, ?tint:Int = 0xffffffff):Bool
```

- `title`: Its title, drawn in a band across its top with its widgets under it, or null or "" (to start) for none.
- `add`: Puts widget in it, last in its column: its nodes under the panel's (hidden with it), its layout in the column.
- `content`: The column its widgets go in, for layouts of other kinds (a row of buttons: put the buttons' layouts in a row, and the buttons in the panel with adopt).
- `adopt`: Puts widget's nodes under the panel's (hidden with it) without placing it: its layout goes in one of the caller's inside this.content.
- `setFrame`: Draws it as texture's nine-slice frame, its corners left, top, right and bottom texels in, tinted tint. False, changing nothing, for no texture.

## Popup

*class* in [`src/helix/ui/Popup.hx`](../../src/helix/ui/Popup.hx), `import helix.ui.Popup;`

What a widget opens over everything else (Ui.popup): a dropdown's list, and later a menu or a tooltip. Its owner makes it (its nodes under root, their layout, the anchor it hangs from) and opens it through its Ui, which then draws it above every widget, panel and focus ring, clipped by none of its owner's clips, and places it by its anchor each frame: below the anchor, or above when the visible area has no room for it below and more above, and moved in to keep it on screen across. While it's open it has the pointer and the keys: a press anywhere off it closes it and does nothing else, Escape or a pad's East closes it, and focus stays on its owner, which takes the keys. One is open at a time; it closes too when its owner is hidden, disabled, loses focus or is taken out, and when the Ui is reset.

```haxe
var owner(default, null):Widget
var layout(default, null):Layout2D
var open(default, null):Bool
var x(default, null):Float
var y(default, null):Float
var placedAbove(default, null):Bool
var anchorX(default, null):Float
var anchorY(default, null):Float
var anchorWidth(default, null):Float
var anchorHeight(default, null):Float
function setAnchor(x:Float, y:Float, width:Float, height:Float):Void
```

- `owner`: The widget it belongs to: focus stays on it while it's open, and its update drives it.
- `layout`: Its content's layout, arranged by the Ui from 0, 0 in its own units each frame it's open: its size is the layout's.
- `open`: Whether it's open: from the Ui opening it until anything closes it (Ui.closePopup).
- `x`: Where it was last placed: its left edge, in the units of the Ui's root (the stage's world, unless the game moved the root).
- `y`: Where it was last placed: its top edge, in the units of the Ui's root.
- `placedAbove`: Whether it was last placed above its anchor, there being no room for it below.
- `anchorX`: Its anchor's left edge, in the units of the Ui's root (setAnchor).
- `anchorY`: Its anchor's top edge, in the units of the Ui's root.
- `anchorWidth`: Its anchor's width in units.
- `anchorHeight`: Its anchor's height in units.
- `setAnchor`: The rectangle it hangs from, in the units of the Ui's root (its owner's face, as drawn): left x, top y, width x height. Its owner sets it each frame, so it follows its owner (a scroll area scrolling under it).

## ProgressBar

*class* in [`src/helix/ui/ProgressBar.hx`](../../src/helix/ui/ProgressBar.hx), `import helix.ui.ProgressBar;`

How far along something is: a track filled from its left by a value, 0 to 1. Never focused.

```haxe
var value(default, set):Float
```

- `value`: How far along, 0 to 1.

## ScrollArea

*class* in [`src/helix/ui/ScrollArea.hx`](../../src/helix/ui/ScrollArea.hx), `import helix.ui.ScrollArea;`

A window onto a column of widgets (add; content), clipping them, drawn and picked, to what's in view and scrolling them up and down: by the wheel over it, a drag on its empty space, its scrollbar (Scrollbar: its thumb dragged, its track pressed above or below the thumb for a page), and keys: focus moving by keys or a pad to a widget out of view scrolls it into view, Page Up and Page Down page while focus is in it, and with no widget in it that takes focus it takes focus itself, Up and Down then stepping it. The widgets in it work as anywhere, the pointer reaching them only where they're in view. Its height is its layout's (the height it was made with, to start), its width what its layout is given (Grow, to start); the column's gap the theme's. The scrollbar at its right edge shows as scrollbarVisibility says, the column narrowing for it while it shows. A wheel over a list in it scrolls the list, not it. Ask scroll (or set it) once a frame.

```haxe
var content(default, null):Layout2D
function add(widget:Widget):Void
function adopt(widget:Widget):Void
var scroll(get, set):Float
var maxScroll(get, never):Float
var scrollbarVisibility:Null<ScrollbarVisibility>
var scrollbarShown(get, never):Bool
```

- `content`: The column its widgets go in (its gap the theme's until set), for layouts of other kinds (a row of widgets: put their layouts in a row, the row here, and the widgets in it with adopt). Its height is the content's: what's past the window is scrolled to.
- `add`: Puts widget in it, last in its column: its nodes under the area's (clipped to its window, hidden with it), its layout in the column.
- `adopt`: Puts widget's nodes under the area's (clipped to its window, hidden with it) without placing it: its layout goes in one of the caller's inside content.
- `scroll`: How far its content is scrolled, in units from its top: 0 to maxScroll as last arranged (out of that range is held to it by the next update).
- `maxScroll`: How far its content can scroll, in units, as last arranged: its height less the window's, 0 when it fits.
- `scrollbarVisibility`: When its scrollbar is drawn, or null (to start) for the theme's scrollbarVisibility: a value is kept whatever the theme becomes.
- `scrollbarShown`: Whether its scrollbar is drawn, as last updated.

## Scrollbar

*class* in [`src/helix/ui/Scrollbar.hx`](../../src/helix/ui/Scrollbar.hx), `import helix.ui.Scrollbar;`

The bar along a scrolling widget's right edge (a list's, a scroll area's): a track theme.scrollbarThickness wide in theme.scrollbarTrackColor, and on it a thumb as long as the share of the content in view and as far down as the content is scrolled, both with round ends. The thumb is colored as a handle by its state (WidgetState.handle: theme.handleColor, theme.accentColor under the pointer, theme.focusColor dragged), dimmed as disabled when its owner is disabled or has nothing to scroll. Never picked: its owner's face takes the pointer and hands it on (drive). One part, so every widget's scrollbar looks and works alike. Its places are in its parent's units.

```haxe
function new(parent:Node2D, theme:Theme)
static function isShown(visibility:ScrollbarVisibility, view:Float, total:Float):Bool
function readTheme(theme:Theme):Void
var visible(default, null):Bool
var width(get, never):Float
var thumbLength(default, null):Float
var thumbOffset(default, null):Float
var dragging(get, never):Bool
function setTrack(x:Float, y:Float, length:Float, view:Float, total:Float, shown:Bool):Void
function computePart(part:String, out:Array<Float>):Bool
function isOver(x:Float, y:Float):Bool
function drive(x:Float, y:Float, pressed:Bool, held:Bool, scroll:Float):Float
function place(scroll:Float, x:Float, y:Float, enabled:Bool, theme:Theme):Void
```

- `new`: Makes a scrollbar in theme's look under parent, hidden until placed (setTrack).
- `isShown`: Whether visibility shows a scrollbar for view units of content seen of total: Always; WhenNeeded only when total is more than view; Never not.
- `readTheme`: Takes its thickness, its track's color and its round ends from theme (its thumb's color is decided as it's placed: place). Its owner calls it as it reads the theme, every frame, so a changed theme shows at once.
- `visible`: Whether it's drawn: as setTrack was last told.
- `width`: Its width in units (theme.scrollbarThickness as last read): the room its owner leaves it.
- `thumbLength`: Its thumb's length in units, as last placed: the track's length times the share of the content in view, at least three times its width (or the track's whole length), the track's whole length when the content fits.
- `thumbOffset`: How far its thumb's top is below the track's top in units, as last placed: 0 at the top of the content, the track's length less the thumb's at its end.
- `dragging`: Whether the pointer holds its thumb (a drag).
- `setTrack`: Lays its track down from x, y (its top left) length long, for view units of content in view of total, drawn when shown. Its owner calls it first each frame, before drive and place.
- `computePart`: Its part named part as last placed, while it's drawn: "track" (all of it) or "thumb", its rectangle written to out as [left, top, width, height] in its parent's units. False, writing nothing, for another name or while it's hidden.
- `isOver`: Whether x, y is on it, while it's drawn.
- `drive`: The scroll (units of content scrolled past) after the pointer at x, y: a press beginning on its owner this frame (pressed) on the thumb takes it, and while it's held after that the thumb follows the pointer; one on the track above or below the thumb moves a page (the units in view) toward it. Unchanged otherwise, and let go once the pointer isn't held. Its owner clamps what it returns.
- `place`: Places the thumb for scroll and colors it: dragged, under the pointer at x, y (NaN: not over its owner), or at rest; dimmed when enabled is false or there's nothing to scroll.

## ScrollbarVisibility

*enum* in [`src/helix/ui/ScrollbarVisibility.hx`](../../src/helix/ui/ScrollbarVisibility.hx), `import helix.ui.ScrollbarVisibility;`

When a scrolling widget's scrollbar (a list's, a scroll area's) is drawn. Hidden or not, the widget scrolls alike: by the wheel, a drag and keys.

- `Always`: Always: with content that fits, its thumb the track's whole length, dimmed.
- `WhenNeeded`: Only while the content is longer than the view: there's more to scroll to.
- `Never`: Never: the content takes the bar's room too.

## Separator

*class* in [`src/helix/ui/Separator.hx`](../../src/helix/ui/Separator.hx), `import helix.ui.Separator;`

A thin line between widgets: across its column (horizontal, made so to start) or down its row (vertical), as told when made, spanning its parent that way (its layout grows that way: Grow(1)), as thick as the theme's focusWidth, in the theme's faceColor, with half the theme's gap of room either side of it. Never focused, never picked, no states.

```haxe
var vertical(default, null):Bool
```

- `vertical`: Whether it's a vertical line, down a row; false for a horizontal one, across a column.

## Sizing2D

*enum* in [`src/helix/ui/Sizing2D.hx`](../../src/helix/ui/Sizing2D.hx), `import helix.ui.Sizing2D;`

How a layout's width or height is decided.

- `Fixed(units:Float)`: This many units.
- `Fit`: Its content's: its children's (and gaps and padding), or its node's own (a text's measured width, a sprite's or rectangle's size).
- `Grow(weight:Float)`: A share of the room its row or column has left, by weight against its siblings' (across, the whole room).
- `Percent(fraction:Float)`: This fraction of its parent's room inside the padding, less its own margins that way (0 to 1).

## Slider

*class* in [`src/helix/ui/Slider.hx`](../../src/helix/ui/Slider.hx), `import helix.ui.Slider;`

A value from min to max in steps (0: any), beside a line of text: dragged along its track by the pointer, or stepped by Left and Right with focus (a tenth of the way without steps). Ask value, and changed once a frame.

```haxe
var value(default, set):Float
var valueShown:Bool
function formatValue():String
var changed(default, null):Bool
```

- `value`: Its value.
- `valueShown`: Whether its value is shown as a number after its track, to as many decimals as its step has (2 without steps, 3 at most). (False to start.)
- `formatValue`: Its value as valueShown writes it.
- `changed`: Whether its value changed this frame.

## TextField

*class* in [`src/helix/ui/TextField.hx`](../../src/helix/ui/TextField.hx), `import helix.ui.TextField;`

A line of text typed in: with focus, the characters typed (after the keyboard layout) are added, Backspace takes the last off and Enter submits; the caret is at its end. While it has focus the UI has the keys (Ui.capturingKeys) and asks for typed text (IInput.setTextEntry, so a platform's keyboard shows for it), however it got focus, so a game doesn't act on letters typed. Ask text, changed and submitted once a frame. No input method (IME) composition yet.

```haxe
var text(get, set):String
var hint(get, set):String
var centered(default, set):Bool
var changed(default, null):Bool
var submitted(default, null):Bool
var invalid:Bool
```

- `text`: Its text.
- `hint`: The text shown, dimmed, while it's empty.
- `centered`: Whether its text and hint are centered in it rather than at its start (false, to start).
- `changed`: Whether its text changed this frame.
- `submitted`: Whether Enter was pressed in it this frame.
- `invalid`: Whether its text is marked as not accepted (what reads it decides: a color picker's field holding no color): drawn in the theme's invalidTextColor.

## Theme

*class* in [`src/helix/ui/Theme.hx`](../../src/helix/ui/Theme.hx), `import helix.ui.Theme;`

How the UI's widgets look: their colors (0xAARRGGBB), font and sizes. Change any value at any time (a settings screen, a reloaded stylesheet): every widget, and the focus ring, reads its look from its Ui's theme at each Ui.update, so the change shows on the next frame with no widget made again; a size that moves the layout shows once the layout is next arranged (Layout2D.arrange). Ui.theme can also be given another theme whole. Every value is the theme's or the game's, decided by what the game set, never guessed from the value: a theme's value applies unless the game set that value itself, and a game's setting wins, as an inline style wins over a stylesheet. A widget's layout's sizing, padding, gap and margin are the game's once set through Layout2D (setSizing, widthSizing, heightSizing, setPadding, gap, setMargin), even to what the theme has; a widget's own look properties (Label.textSize, Label.color) are null for the theme's, a value for the game's. A widget's nodes are never changed directly: its properties are the way.

```haxe
function new()
var font:Null<Font>
var textSize(default, set):Float
var textColor(get, set):Int
var disabledTextColor(get, set):Int
var invalidTextColor(get, set):Int
var panelColor(get, set):Int
var faceColor(get, set):Int
var hoveredColor(get, set):Int
var pressedColor(get, set):Int
var accentColor(get, set):Int
var focusColor(get, set):Int
var focusWidth(default, set):Float
var listCornerRadius(default, set):Float
var listPadding(default, set):Float
var listRowHeight(default, set):Float
var listRowCornerRadius(default, set):Float
var cornerRadius(get, set):Float
var padding(default, set):Float
var gap(default, set):Float
var trackThickness(default, set):Float
var handleColor:Int
var handleShadowColor:Int
var handleSize(default, set):Float
var scrollbarThickness(default, set):Float
var scrollbarTrackColor:Int
var scrollbarVisibility(default, set):ScrollbarVisibility
var colorPickerWidth(default, set):Float
var widgetHeight(get, set):Float
```

- `new`: The colors and sizes as each getter says to start.
- `font`: The font text is drawn in, or null for the stage's (the batch's built-in one).
- `textSize`: Text's height in units. (18 to start.) At least 1e-6 (0 or less, or NaN, is 1e-6).
- `textColor`: Text's color. (0xfff0f2f8 to start.)
- `disabledTextColor`: The color of text on a widget that can't be used now. (0xff80869a to start.)
- `invalidTextColor`: The color of a text field's text marked as not accepted (TextField.invalid). (0xffff7070 to start.)
- `panelColor`: A panel's background color. (0xff1e2230 to start: opaque, so faces show on it whatever is behind.)
- `faceColor`: The color of a button's (and a toggle's box's, a track's) face at rest. (0xff2e3448 to start.)
- `hoveredColor`: The color of a face under the pointer. (0xff3e4660 to start.)
- `pressedColor`: The color of a face held down. (0xff56607e to start.)
- `accentColor`: The color of what's on, filled or chosen: a toggle's mark, a slider's fill and knob, a progress bar's fill, a list's selected row. (0xff4c8ef0 to start.)
- `focusColor`: The color of the ring around the focused widget, shown when focus was moved by keys or a pad. (0xffffd25a to start.)
- `focusWidth`: The focus ring's width in units. (2 to start.) 0 or more (under 0, or NaN, is 0).
- `listCornerRadius`: The radius of a list's corners in units, its frame's (cornerRadius for the others); 0 for square. (0 to start.) 0 or more (under 0, or NaN, is 0).
- `listPadding`: Room between a list's frame and its rows in units, so a chosen row's band keeps clear of the frame's round corners. (4 to start.) 0 or more (under 0, or NaN, is 0).
- `listRowHeight`: A list's rows' height in units. (40 to start.) At least 1 (under 1, or NaN, is 1).
- `listRowCornerRadius`: The radius of a list's rows' corners in units (their hover and selection), apart from the frames' cornerRadius; 0 for square. (0 to start.) 0 or more (under 0, or NaN, is 0).
- `cornerRadius`: The radius of a panel's and a button's corners in units (a list's is listCornerRadius) (a track's, a bar's and a box's at most half their height); 0 for square. The focus ring follows them. (8 to start.) 0 or more (under 0, or NaN, is 0).
- `padding`: Room inside a button or panel, around its content, in units. (8 to start.) 0 or more (under 0, or NaN, is 0).
- `gap`: Room between widgets in a panel, in units. (8 to start.) 0 or more (under 0, or NaN, is 0).
- `trackThickness`: A slider's track and a color picker's bars, their thickness in units. (6 to start.) At least 1 (under 1, or NaN, is 1).
- `handleColor`: A handle's color (a slider's, a color picker's bars'; Handle), 0xAARRGGBB. (White to start.)
- `handleShadowColor`: The ring around a handle, so it shows on any color under it, 0xAARRGGBB. (Black at half alpha to start.)
- `handleSize`: A handle's diameter in units (a slider's, a color picker's bars'; Handle). (14 to start.) At least 1 (under 1, or NaN, is 1).
- `scrollbarThickness`: A scrollbar's width in units (a list's, a scroll area's; Scrollbar), apart from a slider's trackThickness. (8 to start.) At least 1 (under 1, or NaN, is 1).
- `scrollbarTrackColor`: A scrollbar's track's color, 0xAARRGGBB, under its thumb (whose colors are a handle's: WidgetState.handle). (Black at a quarter alpha to start, so it shows on a list's face and a panel alike.)
- `scrollbarVisibility`: When a list's and a scroll area's scrollbars are drawn, unless the widget is given its own (scrollbarVisibility). (WhenNeeded to start.) Null is WhenNeeded.
- `colorPickerWidth`: A color picker's width (its square's side) in units, unless its layout is given another. (200 to start.) At least 1 (under 1, or NaN, is 1).
- `widgetHeight`: A button's (and a slider's, a field's) height in units. (40 to start.) At least 1e-6 (0 or less, or NaN, is 1e-6).

## Tile

*class* in [`src/helix/ui/Tile.hx`](../../src/helix/ui/Tile.hx), `import helix.ui.Tile;`

A picture with a caption under it, in a frame: an inventory's item, a character creator's choice, a level to pick. Clicked by the pointer, or activated with focus by Enter, Space or a pad's South; marked selected by the game (one of a group, as the game decides: clicked, then selected). Its picture can come later (a thumbnail still being made): until then, and with none, the frame shows the theme's face color. Ask clicked once a frame.

```haxe
var clicked(default, null):Bool
var selected:Bool
var texture(get, set):Null<Texture2D>
var caption(get, set):String
var side(default, null):Float
```

- `clicked`: Whether it was clicked or activated this frame.
- `selected`: Whether it's marked selected: drawn with an accent edge.
- `texture`: Its picture, or null while it has none.
- `caption`: Its caption, under the picture.
- `side`: The side of its picture's square, in units.

## Toggle

*class* in [`src/helix/ui/Toggle.hx`](../../src/helix/ui/Toggle.hx), `import helix.ui.Toggle;`

A box that's on or off, beside a line of text: switched by a click or by activating it with focus, on showing a check mark in the theme's accent color whose long stroke runs a little past the box's top right. Ask on, and changed once a frame.

```haxe
var on(get, set):Bool
var changed(default, null):Bool
```

- `on`: Whether it's on.
- `changed`: Whether it was switched this frame.

## TouchStick2D

*class* in [`src/helix/ui/TouchStick2D.hx`](../../src/helix/ui/TouchStick2D.hx), `import helix.ui.TouchStick2D;`

A touch stick drawn while it's held (Binding.TouchStick): a ring where the finger landed, its radius the stick's, and a knob under the finger, kept within the ring. Draws nothing while no finger holds it, so it shows only on a touch screen in use. It needs no Ui and runs itself: add it to the stage, over the game: Stage.addChild(new TouchStick2D(actions, "moveX")), naming an action bound to the stick. With hint on, a faint ring and knob say where a thumb goes while no finger holds it: the bottom left for the whole screen or the left half, the bottom right for the right half, a region's center, or at hintCorner when it's set.

```haxe
function new(actions:Actions, action:String, ?color:Int = 0x80e8e8e8)
var actions:Actions
var action:String
var color:Int
var hint:Bool
var hintMargin:Float
var hintCorner:Null<Anchor>
```

- `new`: The stick of action in actions drawn (its first touch stick binding that's held), in color (0xAARRGGBB: a light gray, half seen, unless given).
- `actions`: The actions it reads.
- `action`: The action whose stick it draws.
- `color`: Its color, 0xAARRGGBB: the ring's, and the knob's a little more opaque.
- `hint`: Whether to draw the idle hint while no finger holds it: off to start (a game turns it on once it has seen a touch, say).
- `hintMargin`: How far in from the visible area's corner the hint's ring sits, the stage's units: 40 to start.
- `hintCorner`: Where the hint's ring sits on the visible area, in from it by hintMargin (BottomRight for a stick on the whole screen that's held by the right thumb, say), or null to start: the place its area gives.

## Ui

*class* in [`src/helix/ui/Ui.hx`](../../src/helix/ui/Ui.hx), `import helix.ui.Ui;`

A screen's widgets on the stage, used by the pointer, keys and pads alike: made here, placed by their layouts (Layout2D.arrange), asked what happened. update() once a frame, after the pointer's: - Arrows and a pad's D-pad move focus to the nearest widget that way on screen (by the layouts' last arrangement: a grid of tiles moves in two dimensions), or, with none that way, in the order widgets were made: Down and Right to the next, Up and Left to the one before, wrapping; Left and Right only when the focused widget doesn't use them (a slider), Up and Down only when it doesn't (a list; a color picker uses all four while one of its parts is driven by them). Tab and Shift+Tab always go in that order. Enter, Space or a pad's South activates it; Escape or East is back (backPressed). - The ring around the focused widget shows only when keys or a pad moved focus, not the pointer (as the web's :focus-visible); after keys or a pad, something always has focus (the first widget, if nothing did). - A key or button already held when a screen begins (reset) does nothing until it's let go: a fire key held into a menu doesn't press its first button. One pressed after reset works at once. - While a widget has the keys (capturingKeys), a game should leave arrows and Enter be, or they drive the game and the menu at once. - A widget may open a popup (Popup: a dropdown's list), drawn over every widget and the ring and clipped by none of their clips, placed by its anchor in the visible area (below it, or above when there's no room below and more above; kept on screen across). While it's open (popup) it has the pointer and the keys: the widgets under it see no pointer, a press off it closes it and does nothing else until it's let go (not even reaching a world under the UI: the pointer is captured), Escape or East closes it instead of going back (backPressed stays false), Tab doesn't move focus, and its owner keeps focus and takes the arrows, Enter, Space and South (capturingKeys is true). The widgets' nodes are under one node (root) on the stage, in the order made, the ring above them and the open popup above it: what's added to the stage after it draws over it.

```haxe
function new(?theme:Theme, ?parent:Node2D, ?camera:Camera2D, ?pointer:Pointer, ?input:IInput)
var theme(default, set):Theme
var root(default, null):Node2D
var font(get, set):Null<Font>
var camera(default, null):Camera2D
var input(get, never):IInput
function label(text:String, ?name:String):Label
function panel(?name:String):Panel
function button(text:String, ?name:String):Button
function toggle(text:String, value:Bool, ?name:String):Toggle
function slider(text:String, min:Float, max:Float, value:Float, ?step:Float = 0., ?name:String):Slider
function separator(?vertical:Bool = false, ?name:String):Separator
function progress(value:Float, ?name:String):ProgressBar
function textField(value:String, ?hint:String = "", ?maxLength:Int = 64, ?name:String):TextField
function tile(texture:Null<Texture2D>, caption:String, side:Float, ?name:String):Tile
function list(items:Array<String>, rows:Int, ?name:String):ListView
function scrollArea(height:Float, ?name:String):ScrollArea
function dropdown(items:Array<String>, ?selected:Int = -1, ?name:String):Dropdown
function colorPicker(color:Int, ?alpha:Bool = true, ?name:String):ColorPicker
function remove(widget:Widget):Void
function find(name:String):Null<Widget>
function press(name:String):Bool
function computePoint(name:String, part:String, x:Float, y:Float, out:Array<Float>):Bool
var focused(default, set):Null<Widget>
var focusedName(get, never):String
var capturingKeys(get, never):Bool
var backPressed(get, never):Bool
var popup(default, null):Null<Popup>
function closePopup():Void
function reset():Void
function update():Void
```

- `new`: A UI on the stage (Stage, docs/DISPLAY_MODEL.md), in theme's look (a new Theme when not given): drawn through the stage's camera, with a pointer of its own looking at the stage (updated by update), read from Input as it is at each update (an autopilot made after it is read too). Given parent, camera, pointer and input, it's under parent instead (a UI in a View2D's tree, a test), drawn through camera, which pointer must look at (the app updates that pointer before update), read from input.
- `theme`: Its look, read by every widget (and the focus ring) at each update: a value changed, or another theme assigned (a settings screen switching themes), shows from the next update with no widget made again; a size that moves the layout once the layout is next arranged. Null is a new Theme.
- `root`: The node its widgets are under.
- `font`: The font text is drawn in without the theme's: the one assigned, else the stage's (the built-in one, there from the first frame).
- `camera`: The camera it's drawn through.
- `input`: The input it reads: the one it was given, or else the program's (Input) as it is now.
- `label`: A line of text.
- `panel`: A background holding a column of widgets (add their layouts to its content).
- `button`: A button reading text: clicked by the pointer, or activated with focus.
- `toggle`: A box that's on or off, beside text.
- `slider`: A value from min to max in steps of step (0: any), dragged along a track or stepped by Left and Right, beside text.
- `separator`: A thin line between widgets: across a column, or down a row when vertical (Separator).
- `progress`: How far along something is, 0 to 1.
- `textField`: A line of text typed in, at most maxLength characters, hint shown while it's empty.
- `tile`: A picture with a caption (a texture still to come: null), in a frame whose picture is side units square.
- `list`: A list of items rows tall, scrolled by the wheel, a drag or its scrollbar, an item chosen by the pointer or Up and Down.
- `scrollArea`: A window height units tall onto a column of widgets (add them: ScrollArea.add), scrolled up and down by the wheel over it, a drag, its scrollbar and keys, as wide as its layout is given (Grow, to start).
- `dropdown`: A choice of one of items (or none: selected -1, clamped to the items), shown on a face with a chevron and chosen from a list opening over everything (Dropdown), as wide as its widest item to start.
- `colorPicker`: A color (0xAARRGGBB) chosen on a square of saturation and brightness, a bar of hue and, with alpha, a bar of alpha, shown in a round swatch and typed in a text field under them as hex or decimal channels, a button beside it cycling which (the field and the button widgets of their own, named name + "-text" and name + "-format", after it in the focus order). Without alpha, its color's alpha is always 0xff.
- `remove`: Takes widget out, its nodes off the stage.
- `find`: The widget named name (Widget.name), or null.
- `press`: Uses the widget named name as a click would (a button clicked, a toggle switched, a list's choice activated), at the next update, when it's shown, enabled and can be: as a test or an autopilot does, by name rather than by place. False, doing nothing, when there's no such widget or it isn't usable now.
- `computePoint`: Writes to out[0] and out[1] the framebuffer pixel (the pointer's, through camera) at x, y of the widget named name, or of its part named part ("" for the whole widget): x and y fractions of its rectangle as last laid out and drawn, 0, 0 its top left and 1, 1 its bottom right, outside it past them. Where an autopilot's points name widgets (Autopilot), found again whenever they're used, so they follow a layout as it changes. False, writing nothing, while there's no such widget shown and laid out or it has no such part now. The parts: a Slider's "track", the line its value runs along (min at its left edge, max at its right); a ColorPicker's "square" (saturation 0 to 1 left to right, brightness 1 to 0 down), "hue" and, with alpha, "alpha" (each bar between the centers of its round ends, where its value runs 0 to 1 left to right) and "swatch", the disc showing the color; a ScrollArea's and a ListView's "track" and "thumb", their scrollbar's while it shows; a ListView's "row:<index>", that item's row where it's scrolled to, in view or not; and while a Dropdown's list is open, its "list", an item's "row:<index>" in it, and its scrollbar's "track" and "thumb".
- `focused`: The widget with focus, or null.
- `focusedName`: The focused widget's name, or "" (for a check's probe).
- `capturingKeys`: Whether a widget has the keys: a game should leave arrows, Enter and Space be.
- `backPressed`: Whether Escape or a pad's East was pressed this frame (not held over from before reset).
- `popup`: The open popup (a dropdown's list), or null.
- `closePopup`: Closes the open popup, if one is: its owner sees it closed at its next update, as when a press off it or Escape closes it.
- `reset`: A new screen begins: no focus, no popup open, and the keys and buttons held now do nothing until they're let go. Anything pressed after this works at once.
- `update`: Once a frame, after the pointer's update (its own pointer's, which it updates first) and before reading the widgets or the game's own keys: moves focus, activates, brings each widget up to date, and claims the keys it used (IInput.claim: a focused text field every key pressed), so the game reading after doesn't act on them too.

## Widget

*class* in [`src/helix/ui/Widget.hx`](../../src/helix/ui/Widget.hx), `import helix.ui.Widget;`

A piece of UI: nodes it owns (on the Ui's stage) and the layout (Layout2D) placing them. A widget is asked what happened (clicked, value ...), never calls anything (DECISIONS 61); the Ui updates it once a frame. Its look is its Ui's theme's (Theme), read every frame, except what the game set: its layout's sizing, padding, gap and margin once the game sets them (Layout2D), and the look properties a widget has for one of its own (Label.textSize and color: null for the theme's). Its nodes are its own: a game changes them through its properties, never directly.

```haxe
var name(default, null):String
var layout(default, null):Layout2D
var enabled(get, set):Bool
var interactive(get, set):Bool
var visible(get, set):Bool
var focusable(get, never):Bool
```

- `name`: Its name: what the focus is published as (Ui.focusedName), for checks.
- `layout`: The layout placing it: put it in another (a row, a column, a panel's content).
- `enabled`: Whether it can be used: a disabled one is drawn dimmed, can't take focus and does nothing, and still stops the pointer, so a click on it doesn't reach what's behind. Off for it and every widget in a panel set off; reading it says whether it's enabled now: it, and any panel holding it. On to start.
- `interactive`: Whether it takes input: off, it looks as it does but takes none of any kind (the pointer, focus, keys, pads), and the pointer passes through it to what's behind, so Pointer.pick finds the world under it (a HUD during a cutscene, a tooltip). Off for it and every widget in a panel set off; reading it says whether it's interactive now: it, and any panel holding it. On to start.
- `visible`: Whether it's shown: it, and any panel holding it.
- `focusable`: Whether focus can rest on it.

## WidgetState

*abstract* in [`src/helix/ui/WidgetState.hx`](../../src/helix/ui/WidgetState.hx), `import helix.ui.WidgetState;`

The state a widget's part is drawn in, one at a time, picked by a fixed priority: Disabled (its widget can't be used), then Down (held by the pointer), Over (under the pointer), Focused (its widget has focus, or the part is the one keys drive), else Normal. Every interactive widget colors its parts through it (of, then pick, or the palettes face, handle and text over pick), so they answer the pointer, the keys and enabled alike: a face in faceColor, hoveredColor under the pointer, pressedColor held and its own color at half alpha disabled (dim); a handle in handleColor, accentColor under the pointer, focusColor held; text in textColor, disabledTextColor disabled. What isn't state, a toggle's mark on, a list's or a tile's selection, is its widget's own and drawn over or beside it.

- `WidgetState.Normal`: At rest.
- `WidgetState.Focused`: Its widget has focus (or the part is the one the keys drive), not under the pointer.
- `WidgetState.Over`: Under the pointer, not held.
- `WidgetState.Down`: Held down by the pointer.
- `WidgetState.Disabled`: Its widget can't be used (Widget.enabled false).

```haxe
static function of(enabled:Bool, down:Bool, over:Bool, focused:Bool):WidgetState
function pick(normal:Int, over:Int, down:Int, focused:Int, disabled:Int):Int
function face(theme:Theme):Int
function handle(theme:Theme):Int
function text(theme:Theme):Int
static function dim(color:Int):Int
function toString():String
```

- `of`: The state of a part whose widget is enabled or not, held down by the pointer (down), under it (over) and focused: the first that holds of Disabled, Down, Over and Focused, else Normal.
- `pick`: Of the colors (0xAARRGGBB) given for each state, the one for this state.
- `face`: A face's color in this state (a button's, a toggle's box, a list's row's): theme's faceColor, hoveredColor Over, pressedColor Down, faceColor Focused (the focus ring shows focus) and faceColor dimmed Disabled.
- `handle`: A handle's color in this state (a slider's, a scrollbar's thumb, a color picker's): theme's handleColor, accentColor Over, focusColor Down and Focused (the part the keys drive), handleColor dimmed Disabled.
- `text`: A widget's text's color in this state: theme's textColor, disabledTextColor Disabled.
- `dim`: color (0xAARRGGBB) dimmed as a disabled part is: its own color at half its alpha.
- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.
