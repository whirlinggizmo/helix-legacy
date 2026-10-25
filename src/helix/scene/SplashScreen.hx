package helix.scene;

import helix.host.Screen;
import helix.input.Input;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.scene.transition.Fade;
import helix.scene.transition.Transition;
import helix.texture.Texture2D;
import helix.ui.Theme;

/** A splash screen: your logo, centered on the theme's background, before the game starts.

	Create one and call show(next). It stays up for at least `seconds`, and also until the player presses a key, clicks or taps, showing
	`prompt` ("press any key") meanwhile. Then it fades out (or uses the transition you gave) and calls next at the transition's middle; put
	your title screen on the stage there.

	Why wait for a press: a browser plays no sound and allows no fullscreen until the player has pressed something. A gamepad press doesn't
	count, because browsers ignore it for that.

	To go on without a press, set maxWait to a number of seconds. To fade it in, set entrance (new Fade()). An Iris as its exit closes on
	the logo (logoX, logoY say where it is). The splash runs itself; you don't update it. The run option quick=1 skips its wait. theme sets
	its colors and font (docs/DISPLAY_MODEL.md). */
class SplashScreen {
	var logo:Null<Texture2D>;
	var seconds:Float;
	var transition:Transition;
	var drawing = new Drawing2D();
	var left = false;

	/** A splash of logo (null: the theme's colors alone), shown at least seconds, leaving by transition (a half-second fade unless given). */
	public function new(logo:Null<Texture2D>, seconds:Float, ?transition:Transition) {
		this.logo = logo;
		this.seconds = seconds;
		this.transition = transition == null ? new Fade() : transition;
	}

	/** The theme it draws with. */
	public var theme:Theme = new Theme();

	/** A transition it comes in by, uncovered as it's shown (new Fade() fades it in from black), or null (the start) to show it at once. */
	public var entrance:Null<Transition> = null;

	/** Where its logo is drawn, its middle in the stage's units, as of the last frame: to aim an iris at it, say. Its exit transition, a
		Closing (Iris, Diamond) with no point of its own, closes on it already. NaN before it's drawn. */
	public var logoX(default, null):Float = Math.NaN;

	/** The logo's middle's y; NaN before it's drawn. */
	public var logoY(default, null):Float = Math.NaN;

	/** The logo's side in the stage's units (it's drawn square); 0 before it's drawn or without a logo. */
	public var logoSize(default, null):Float = 0.;

	/** The line that asks for the press, shown until one comes ("press any key" to start). */
	public var prompt:String = "press any key";

	/** Seconds shown so far. */
	public var elapsed(default, null):Float = 0.;

	/** The most seconds it waits for a press before going on without one (a game that needs no audio unlock, or one that unlocks later);
		0, the default, waits for one as long as it takes. 0 or more (under 0, or NaN, is 0). */
	public var maxWait(default, set):Float = 0.;

	function set_maxWait(seconds:Float):Float {
		seconds = seconds >= 0 ? seconds : 0;
		maxWait = seconds;
		return seconds;
	}

	/** Puts it on the stage, over what's there, until it leaves, calling next at its transition's middle as it's taken off. False, doing
		nothing, once shown. */
	public function show(next:Void->Void):Bool {
		if (left || elapsed > 0 || drawing.parent != null)
			return false;
		Stage.addChild(drawing);
		draw();
		if (entrance != null)
			entrance.uncover();
		Flow.run(dt -> {
			elapsed += Math.max(0, dt);
			var pressed = Input.activated || (maxWait > 0 && elapsed >= maxWait);
			if (!left && (Flow.quick || (elapsed >= seconds && pressed))) {
				left = true;
				// An iris (or another closing) with no point of its own closes on the logo, where it is as the splash leaves.
				var closing = Std.downcast(transition, helix.scene.transition.Closing);
				if (closing != null && Math.isNaN(closing.pointX) && closing.followed == null && !Math.isNaN(logoX))
					closing.setPoint(logoX, logoY);
				transition.run(() -> {
					Stage.removeChild(drawing);
					next();
				});
			}
			draw();
			return drawing.parent != null;
		});
		return true;
	}

	// The screen as it is now, drawn again.
	function draw():Void {
		var p = Screen.instance;
		var vx = p.visibleX,
			vy = p.visibleY,
			vw = p.visibleWidth,
			vh = p.visibleHeight;
		drawing.clear();
		drawing.rect(vx, vy, vw, vh, theme.panelColor);
		// The logo a little above the middle, room left for the prompt.
		var side = Math.min(vw, vh) * .4;
		logoX = vx + vw / 2;
		logoY = vy + vh / 2 - 20;
		logoSize = logo != null ? side : 0;
		if (logo != null)
			drawing.image(logo, logoX - side / 2, logoY - side / 2, side, side);
		if (!Input.activated)
			drawing.drawText(prompt, vx + vw / 2, vy + vh * .8, theme.textSize, theme.disabledTextColor, Center, theme.font);
	}
}
