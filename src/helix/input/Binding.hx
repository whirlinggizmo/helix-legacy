package helix.input;

/** What drives an action (Actions), each giving a value from -1 to 1; the action is the binding pushed furthest. */
enum Binding {
	/** A key: 1 while it is down. */
	Keyboard(key:Key);

	/** A pair of keys as an axis: -1 while negative is down, 1 while positive is, 0 for both or neither. */
	KeyboardPair(negative:Key, positive:Key);

	/** A pad button on any connected pad: 1 while it is down. */
	Pad(button:PadButton);

	/** A pair of pad buttons as an axis, across the pads: -1 for negative, 1 for positive, 0 for both or neither (the d-pad's Left and Right
		as steering). */
	PadPair(negative:PadButton, positive:PadButton);

	/** A pad axis, past the dead zone (Gamepad.getAxis), the pad pushed furthest: side 0 reads both directions (-1..1, a trigger 0..1), 1 or
		-1 only that side, as 0..1; under threshold (0..1) it reads 0, and at or past a non-zero threshold the action is down. */
	Axis(axis:PadAxis, side:Int, threshold:Float);

	/** A mouse button: 1 while it is down. */
	Mouse(button:MouseButton);

	/** A touch region: 1 while a finger is down in it. In the game's units (Screen's): the anchor's point on the visible area, then x, y from
		it to the region's top left, width x height across and down; so it scales with the design and follows the visible area's edges. */
	TouchRegion(anchor:Anchor, x:Float, y:Float, width:Float, height:Float);

	/** A floating stick for a thumb, in area (the whole screen, a half of it, or a region). A finger landing in it holds the stick, centered
		where it landed, and its offset from there, radius units for all the way, is the stick's push, clamped to a circle and 0 within
		Actions.touchStickDeadZone of the middle. Another finger landing in it takes it over, centered where it lands; the holding finger
		lifting hands it to one still down in it, centered where that one is (so what it steers doesn't lurch). A finger landing where
		Actions.touchStickBlocked says (a button) doesn't take it, nor one holding another stick. The action reads its axis (X right, Y down,
		as a pad's stick); an action bound to X and one bound to Y of the same area and radius read one stick:
		actions.bind("moveX", TouchStick(Anywhere, 80, X)), or for two sticks LeftHalf and RightHalf. */
	TouchStick(area:StickArea, radius:Float, axis:StickAxis);
}
