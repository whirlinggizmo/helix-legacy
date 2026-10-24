import helix.host.Window;
import helix.render2d.Shape2D;
import helix.render2d.Stage;
import helix.render2d.Text2D;
import helix.ui.FullscreenButton2D;

/** The game: init once the services are bound, update once a display refresh (the game's logic), cleanup as the window closes. What's on
	the stage is drawn after each update, with nothing drawn by hand (docs/DISPLAY_MODEL.md in HeliX). What needs a service (a texture, a
	sound) is made in init, not in a field initializer: the object exists before HeliX does. */
class Game extends helix.App {
	// The fullscreen icon at the top right, over everything (hidden where the page can't go fullscreen).
	var fullscreen = new FullscreenButton2D();

	override public function init():Void {
		Window.title = "{title}";
		Stage.color = 0xff202840;
		// A world unit is a logical pixel, from the top left.
		var panel = Shape2D.rectangle(320, 160, 0xff66bfff);
		panel.setPosition(40, 40);
		Stage.addChild(panel);
		var greeting = new Text2D("{title}", 48, 0xff102030);
		greeting.setPosition(60, 90);
		Stage.addChild(greeting);
		Stage.addChild(fullscreen);
	}

	// After a hot reload in the dev loop: this object, its fields kept, now runs the new code, and init doesn't run again. Build here
	// what an edit added to init. Keep the game's state in fields, as here: a plain static starts over at each reload.
	override public function afterReload():Void {}

	override public function update(dt:Float):Void {
		// Once a frame, before the stage is drawn: the game's logic, dt seconds since the last frame.
	}
}
