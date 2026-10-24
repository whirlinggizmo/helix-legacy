package helix.ui;

import helix.graphics.Color;

/** The state a widget's part is drawn in, one at a time, picked by a fixed priority: Disabled (its widget can't be used), then Down (held by
	the pointer), Over (under the pointer), Focused (its widget has focus, or the part is the one keys drive), else Normal. Every interactive
	widget colors its parts through it (of, then pick, or the palettes face, handle and text over pick), so they answer the pointer, the keys
	and enabled alike: a face in faceColor, hoveredColor under the pointer, pressedColor held and its own color at half alpha disabled (dim); a
	handle in handleColor, accentColor under the pointer, focusColor held; text in textColor, disabledTextColor disabled. What isn't state, a
	toggle's mark on, a list's or a tile's selection, is its widget's own and drawn over or beside it. */
@:build(helix.macro.EnumNames.build())
enum abstract WidgetState(Int) {
	/** At rest. */
	var Normal = 0;

	/** Its widget has focus (or the part is the one the keys drive), not under the pointer. */
	var Focused = 1;

	/** Under the pointer, not held. */
	var Over = 2;

	/** Held down by the pointer. */
	var Down = 3;

	/** Its widget can't be used (Widget.enabled false). */
	var Disabled = 4;

	/** The state of a part whose widget is enabled or not, held down by the pointer (down), under it (over) and focused: the first that holds of
		Disabled, Down, Over and Focused, else Normal. */
	public static function of(enabled:Bool, down:Bool, over:Bool, focused:Bool):WidgetState
		return !enabled ? Disabled : down ? Down : over ? Over : focused ? Focused : Normal;

	/** Of the colors (0xAARRGGBB) given for each state, the one for this state. */
	public function pick(normal:Int, over:Int, down:Int, focused:Int, disabled:Int):Int
		return switch (cast this : WidgetState) {
			case Disabled: disabled;
			case Down: down;
			case Over: over;
			case Focused: focused;
			case Normal: normal;
		}

	/** A face's color in this state (a button's, a toggle's box, a list's row's): theme's faceColor, hoveredColor Over, pressedColor Down, faceColor
		Focused (the focus ring shows focus) and faceColor dimmed Disabled. */
	public function face(theme:Theme):Int
		return pick(theme.faceColor, theme.hoveredColor, theme.pressedColor, theme.faceColor, dim(theme.faceColor));

	/** A handle's color in this state (a slider's, a scrollbar's thumb, a color picker's): theme's handleColor, accentColor Over, focusColor Down
		and Focused (the part the keys drive), handleColor dimmed Disabled. */
	public function handle(theme:Theme):Int
		return pick(theme.handleColor, theme.accentColor, theme.focusColor, theme.focusColor, dim(theme.handleColor));

	/** A widget's text's color in this state: theme's textColor, disabledTextColor Disabled. */
	public function text(theme:Theme):Int
		return pick(theme.textColor, theme.textColor, theme.textColor, theme.textColor, theme.disabledTextColor);

	/** color (0xAARRGGBB) dimmed as a disabled part is: its own color at half its alpha. */
	public static function dim(color:Int):Int
		return Color.withAlpha(color, Color.getAlpha(color) >> 1);
}
