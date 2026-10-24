package helix.input;

/** Physical keys by place on a US layout, numbered as GLFW numbers them; each input adapter maps its platform's codes to them. Left and
	right Shift, Control, Alt and Super are one key each. */
@:build(helix.macro.EnumNames.build())
enum abstract Key(Int) to Int {
	var Space = 32;
	var Apostrophe = 39;
	var Comma = 44;
	var Minus = 45;
	var Period = 46;
	var Slash = 47;
	var Digit0 = 48;
	var Digit1 = 49;
	var Digit2 = 50;
	var Digit3 = 51;
	var Digit4 = 52;
	var Digit5 = 53;
	var Digit6 = 54;
	var Digit7 = 55;
	var Digit8 = 56;
	var Digit9 = 57;
	var Semicolon = 59;
	var Equal = 61;
	var A = 65;
	var B = 66;
	var C = 67;
	var D = 68;
	var E = 69;
	var F = 70;
	var G = 71;
	var H = 72;
	var I = 73;
	var J = 74;
	var K = 75;
	var L = 76;
	var M = 77;
	var N = 78;
	var O = 79;
	var P = 80;
	var Q = 81;
	var R = 82;
	var S = 83;
	var T = 84;
	var U = 85;
	var V = 86;
	var W = 87;
	var X = 88;
	var Y = 89;
	var Z = 90;
	var LeftBracket = 91;
	var Backslash = 92;
	var RightBracket = 93;
	var Grave = 96;
	var Escape = 256;
	var Enter = 257;
	var Tab = 258;
	var Backspace = 259;
	var Insert = 260;
	var Delete = 261;
	var Right = 262;
	var Left = 263;
	var Down = 264;
	var Up = 265;
	var PageUp = 266;
	var PageDown = 267;
	var Home = 268;
	var End = 269;
	var F1 = 290;
	var F2 = 291;
	var F3 = 292;
	var F4 = 293;
	var F5 = 294;
	var F6 = 295;
	var F7 = 296;
	var F8 = 297;
	var F9 = 298;
	var F10 = 299;
	var F11 = 300;
	var F12 = 301;
	var World1 = 161;
	var World2 = 162;
	var CapsLock = 280;
	var ScrollLock = 281;
	var NumLock = 282;
	var PrintScreen = 283;
	var Pause = 284;
	var F13 = 302;
	var F14 = 303;
	var F15 = 304;
	var F16 = 305;
	var F17 = 306;
	var F18 = 307;
	var F19 = 308;
	var F20 = 309;
	var F21 = 310;
	var F22 = 311;
	var F23 = 312;
	var F24 = 313;
	var F25 = 314;
	var Keypad0 = 320;
	var Keypad1 = 321;
	var Keypad2 = 322;
	var Keypad3 = 323;
	var Keypad4 = 324;
	var Keypad5 = 325;
	var Keypad6 = 326;
	var Keypad7 = 327;
	var Keypad8 = 328;
	var Keypad9 = 329;
	var KeypadDecimal = 330;
	var KeypadDivide = 331;
	var KeypadMultiply = 332;
	var KeypadSubtract = 333;
	var KeypadAdd = 334;
	var KeypadEnter = 335;
	var KeypadEqual = 336;
	var Shift = 340;
	var Control = 341;
	var Alt = 342;
	var Super = 343;
	var Menu = 348;

	/** One past the largest value, for arrays indexed by key. */
	public static inline var COUNT = 349;

	/** Every key, in order of value. */
	public static final all:Array<Key> = [
		Space,
		Apostrophe,
		Comma,
		Minus,
		Period,
		Slash,
		Digit0,
		Digit1,
		Digit2,
		Digit3,
		Digit4,
		Digit5,
		Digit6,
		Digit7,
		Digit8,
		Digit9,
		Semicolon,
		Equal,
		A,
		B,
		C,
		D,
		E,
		F,
		G,
		H,
		I,
		J,
		K,
		L,
		M,
		N,
		O,
		P,
		Q,
		R,
		S,
		T,
		U,
		V,
		W,
		X,
		Y,
		Z,
		LeftBracket,
		Backslash,
		RightBracket,
		Grave,
		Escape,
		Enter,
		Tab,
		Backspace,
		Insert,
		Delete,
		Right,
		Left,
		Down,
		Up,
		PageUp,
		PageDown,
		Home,
		End,
		F1,
		F2,
		F3,
		F4,
		F5,
		F6,
		F7,
		F8,
		F9,
		F10,
		F11,
		F12,
		World1,
		World2,
		CapsLock,
		ScrollLock,
		NumLock,
		PrintScreen,
		Pause,
		F13,
		F14,
		F15,
		F16,
		F17,
		F18,
		F19,
		F20,
		F21,
		F22,
		F23,
		F24,
		F25,
		Keypad0,
		Keypad1,
		Keypad2,
		Keypad3,
		Keypad4,
		Keypad5,
		Keypad6,
		Keypad7,
		Keypad8,
		Keypad9,
		KeypadDecimal,
		KeypadDivide,
		KeypadMultiply,
		KeypadSubtract,
		KeypadAdd,
		KeypadEnter,
		KeypadEqual,
		Shift,
		Control,
		Alt,
		Super,
		Menu
	];

	/** Each key's name, in the order of all: its own spelling, a digit's its digit. */
	static final names:Array<String> = [
		"Space",
		"Apostrophe",
		"Comma",
		"Minus",
		"Period",
		"Slash",
		"0",
		"1",
		"2",
		"3",
		"4",
		"5",
		"6",
		"7",
		"8",
		"9",
		"Semicolon",
		"Equal",
		"A",
		"B",
		"C",
		"D",
		"E",
		"F",
		"G",
		"H",
		"I",
		"J",
		"K",
		"L",
		"M",
		"N",
		"O",
		"P",
		"Q",
		"R",
		"S",
		"T",
		"U",
		"V",
		"W",
		"X",
		"Y",
		"Z",
		"LeftBracket",
		"Backslash",
		"RightBracket",
		"Grave",
		"Escape",
		"Enter",
		"Tab",
		"Backspace",
		"Insert",
		"Delete",
		"Right",
		"Left",
		"Down",
		"Up",
		"PageUp",
		"PageDown",
		"Home",
		"End",
		"F1",
		"F2",
		"F3",
		"F4",
		"F5",
		"F6",
		"F7",
		"F8",
		"F9",
		"F10",
		"F11",
		"F12",
		"World1",
		"World2",
		"CapsLock",
		"ScrollLock",
		"NumLock",
		"PrintScreen",
		"Pause",
		"F13",
		"F14",
		"F15",
		"F16",
		"F17",
		"F18",
		"F19",
		"F20",
		"F21",
		"F22",
		"F23",
		"F24",
		"F25",
		"Keypad0",
		"Keypad1",
		"Keypad2",
		"Keypad3",
		"Keypad4",
		"Keypad5",
		"Keypad6",
		"Keypad7",
		"Keypad8",
		"Keypad9",
		"KeypadDecimal",
		"KeypadDivide",
		"KeypadMultiply",
		"KeypadSubtract",
		"KeypadAdd",
		"KeypadEnter",
		"KeypadEqual",
		"Shift",
		"Control",
		"Alt",
		"Super",
		"Menu"
	];

	/** The key a name spells, ignoring case ("A", "space", "KeypadEnter", "0"); throws for an unknown name. */
	public static function named(name:String):Key {
		var upper = name.toUpperCase();
		for (i in 0...names.length)
			if (names[i].toUpperCase() == upper)
				return all[i];
		throw 'Unknown key ' + name;
	}

	/** The key's name as named reads it: its own spelling ("Space", "PageUp", "KeypadEnter"), a digit's its digit ("0"). */
	public static function getName(key:Key):String
		return names[all.indexOf(key)];
}
