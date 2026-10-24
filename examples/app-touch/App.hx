import helix.graphics.Color;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Camera2D;
import helix.render2d.Drawing2D;
import helix.render2d.Sprite2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.host.ScreenShape;

/** Fingers, the two-finger gesture, and the pointer: every finger gets a numbered ring (its id) while it's down, and a fading one where it lifted;
	two fingers pan, pinch and twist the logo about the point between them, so it stays under the fingers; one finger is also the pointer: drag the
	coin. A second finger lets the drag go, so a pinch never drops the coin somewhere. Without a touch screen: drag with the mouse, and the wheel
	zooms the logo about the mouse. The logo and the coin are sprites on the stage, the rings and the text a drawing over them made again
	each update. Escape quits where quitting means anything. */
class App extends helix.App {
	static inline var RING = 38.;
	static inline var COIN = 96.;
	static inline var FINGERS = 8;

	// The stage's units, fitted as the stage's camera is: what the pointer and the fingers are taken into.
	var camera = new Camera2D();
	var logo = new Sprite2D(null);
	var coin = new Sprite2D(null);
	var drawing = new Drawing2D();

	/** The window's shape the logo and the coin were placed for: they go back to the middle when it changes. */
	var shaped = "";

	var logoX = 0.;
	var logoY = 0.;
	var logoScale = 1.;
	var logoRotation = 0.;
	var coinX = 0.;
	var coinY = 0.;
	var coinHeld = false;

	/** Where each finger id last lifted, x and y, and how much of its ring is left to fade (1 down to 0). */
	var lifted = [for (_ in 0...FINGERS) [0., 0., 0.]];

	override public function init():Void {
		Window.title = "HeliX touch";
		logo.setPivot(.5, .5);
		coin.setPivot(.5, .5);
		Window.requestSize(900, 700);
		Stage.color = 0xff161921;
		logo.setSize(240, 240);
		// The coin: 16x16 texels at 42, 22 in the tile sheet.
		coin.setRegion(42, 22, 16, 16);
		coin.setSize(COIN, COIN);
		Stage.addChild(logo);
		Stage.addChild(coin);
		Stage.addChild(drawing);
		Textures.load("sprites/logo/wg-logo-white-alpha.png", true, texture -> logo.texture = texture);
		// Pixel art: nearest, no smoothing.
		Textures.load("textures/tiles.png", false, (texture:Texture2D) -> coin.texture = texture);
	}

	/** Scales and turns the logo about x, y, so the point under the fingers stays put. */
	function transformLogo(x:Float, y:Float, scale:Float, rotation:Float):Void {
		var c = Math.cos(rotation), s = Math.sin(rotation);
		var ox = (logoX - x) * scale, oy = (logoY - y) * scale;
		logoX = x + ox * c - oy * s;
		logoY = y + ox * s + oy * c;
		logoScale = Math.min(Math.max(logoScale * scale, .2), 8);
		logoRotation += rotation;
	}

	override public function update(dt:Float):Void {
		// The design for the window's shape; the logo and the coin start in the middle of what's visible of it, and go back there when
		// the shape changes (a phone turned), as they might be past the new edges.
		var shape = ScreenShape.update();
		Screen.apply(camera);
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth,
			vh = Screen.visibleHeight;
		if (shape != shaped) {
			shaped = shape;
			logoX = coinX = vx + vw / 2;
			logoY = vy + vh * .45;
			coinY = vy + vh * .8;
		}
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		// Two fingers move the logo; the wheel zooms it about the mouse.
		if (Input.touchGesture) {
			logoX += Input.getTouchGesturePanX() / Screen.scaleX;
			logoY += Input.getTouchGesturePanY() / Screen.scaleY;
			transformLogo(camera.screenToWorldX(Input.touchGestureCenterX), camera.screenToWorldY(Input.touchGestureCenterY), Input.getTouchGestureScale(),
				Input.getTouchGestureRotation());
		}
		var mouseX = camera.screenToWorldX(Input.pointerX),
			mouseY = camera.screenToWorldY(Input.pointerY);
		if (Input.wheelY != 0)
			transformLogo(mouseX, mouseY, Math.pow(1.1, Input.wheelY), 0);
		// The pointer (the mouse, or one finger) drags the coin: picked where it was before this frame moved it.
		if (Input.pointerFramePressed)
			coinHeld = Math.abs(mouseX - coinX) < COIN / 2 && Math.abs(mouseY - coinY) < COIN / 2;
		else if (!Input.pointerDown)
			coinHeld = false;
		if (coinHeld) {
			coinX = mouseX;
			coinY = mouseY;
		}
		// Where fingers lifted: a ring that fades.
		for (ring in lifted)
			ring[2] = Math.max(ring[2] - .033, 0);
		for (touch in Input.touches)
			if (touch.released && touch.id >= 0) {
				var ring = lifted[touch.id % FINGERS];
				ring[0] = camera.screenToWorldX(touch.x);
				ring[1] = camera.screenToWorldY(touch.y);
				ring[2] = 1;
			}

		logo.setPosition(logoX, logoY);
		logo.setScale(logoScale, logoScale);
		logo.rotation = logoRotation;
		coin.setPosition(coinX, coinY);
		coin.tint = coinHeld ? 0xffffe696 : 0xffffffff;
		drawing.clear();
		for (i in 0...FINGERS) {
			var ring = lifted[i];
			if (ring[2] > 0)
				drawing.circleLines(ring[0], ring[1], RING * (2 - ring[2]), 1, color(i, Std.int(200 * ring[2])));
		}
		for (touch in Input.touches) {
			if (!touch.down)
				continue;
			var x = camera.screenToWorldX(touch.x),
				y = camera.screenToWorldY(touch.y),
				id = touch.id % FINGERS;
			drawing.circle(x, y, RING, color(id, 90));
			drawing.circleLines(x, y, RING, 1, color(id, 255));
			drawing.drawText(Std.string(touch.id), x - 6, y - RING - 26, 22, color(id, 255));
		}
		if (Input.touchGesture)
			drawing.circle(camera.screenToWorldX(Input.touchGestureCenterX), camera.screenToWorldY(Input.touchGestureCenterY), 6, 0xffffffff);
		var fingers = 0;
		for (touch in Input.touches)
			if (touch.down)
				fingers++;
		var y = vy + 16, counts = 'fingers: $fingers   pointer: ' + (Input.pointerDown ? "down" : "up"),
			placed = 'logo: scale ${Math.round(logoScale * 100) / 100}, turn ${Math.round(logoRotation * 180 / Math.PI)} deg';
		y += drawing.drawTextWrapped(counts, vx + 16, y, 18, vw - 32, 0xffffffff) + 1.5;
		y += drawing.drawTextWrapped(placed, vx + 16, y, 18, vw - 32, 0xffffffff) + 1.5;
		drawing.drawTextWrapped("two fingers: pan, pinch, twist the logo; one finger drags the coin", vx + 16, y, 16, vw - 32, 0xff969eaf);
	}

	/** A finger's color, by its id, with alpha. */
	static function color(id:Int, alpha:Int):Int
		return Color.fromChannels(90 + 20 * id, 200 - 15 * id, 120 + 17 * id, alpha);
}
