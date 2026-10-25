package helix.host;

/** What the game runs on, as far as the platform says (Host.device): a browser or native, the operating system, a touch screen, a fine
	pointer. For what a game shows by device: touch controls on a phone, "tap" or "click" in a prompt, a landscape lock asked for. A browser
	can be wrong about a laptop with a touch screen (both a touch screen and a fine pointer), so show touch controls on the first touch too
	(Input.touches), not by device alone. */
class Device {
	/** Whether it runs in a browser page (true) or natively. */
	public final browser:Bool;

	/** The operating system, lowercase: "windows", "macos", "linux", "android", "ios", "chromeos"; "" when the platform doesn't say. */
	public final os:String;

	/** Whether it has a touch screen. Natively, false: no host reports one yet. */
	public final touchScreen:Bool;

	/** Whether it has a fine pointer (a mouse, a trackpad, a pen): false on a phone or a tablet alone. */
	public final finePointer:Bool;

	/** A phone or a tablet: a touch screen, and no fine pointer. */
	public var mobile(get, never):Bool;

	function get_mobile():Bool
		return touchScreen && !finePointer;

	/** A device as described (made by the host adapters). */
	@:noCompletion
	public function new(browser:Bool, os:String, touchScreen:Bool, finePointer:Bool) {
		this.browser = browser;
		this.os = os;
		this.touchScreen = touchScreen;
		this.finePointer = finePointer;
	}
}
