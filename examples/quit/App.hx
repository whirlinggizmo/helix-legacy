import helix.audio.Audio;
import helix.audio.AudioStream;
import helix.debug.TestHarness;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Textures;
import helix.time.Time;
import helix.host.ScreenShape;

/** Quitting while audio plays and files are loading. Plays music, and after a second starts loading files, keeps the frame busy for half a second
	(like a long synchronous load) and quits: shutdown runs with the loads still in progress, and nothing that was in flight may run after it.
	In a browser quitting stops the frame loop and runs the shutdown, and the canvas keeps the last frame. Q quits now, everywhere; Escape where
	quitting closes a window (in a browser Escape is the browser's: it leaves fullscreen). */
class App extends helix.App {
	var text = new Drawing2D();
	var quitAt = 0.;
	var quitting = false;

	override public function init():Void {
		Window.title = "HeliX quit";
		Window.requestSize(640, 200);
		Stage.color = 0xff1e2430;
		Stage.addChild(text);
		quitAt = Time.time + 1;
		Audio.loadStream("audio/music/a_hero_is_born.mp3", stream -> play(stream));
	}

	// The music opened: played, the playback holding the stream.
	function play(stream:AudioStream):Void {
		Audio.music.play(stream, true, .5);
		stream.release();
	}

	override public function update(dt:Float):Void {
		if (Input.isFramePressed(Key.Q) || Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		// The quit, before this frame is drawn: its text says so, and it's the frame the canvas keeps.
		if (!quitting && Time.time >= quitAt) {
			quitting = true;
			// Only in flight at the quit: loads begun and never used.
			Textures.load("sprites/logo/wg-logo-white-alpha.png", Linear, _ -> {});
			Textures.load("textures/tiles.png", Nearest, _ -> {});
			Audio.loadStream("audio/music/a_hero_is_born.mp3", _ -> {});
			// A long synchronous frame.
			var busyUntil = Time.time + .5;
			while (Time.time < busyUntil) {}
			Host.quit();
		}
		// The text in the design for the window's shape, wrapped to what's visible of it, drawn again each update.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		text.clear();
		var y = vy + 12;
		y += text.drawTextWrapped("HeliX quit   Q: quit now", vx + 12, y, 16, vw - 24, 0xfff5f5f5) + 8;
		text.drawTextWrapped(quitting ? "quit requested: shutdown runs after this frame" : 'loading, stalling and quitting in ${Math.round(Math.max(0, quitAt - Time.time) * 10) / 10} s',
			vx
			+ 12, y, 16, vw
			- 24, 0xffc8c8c8);
	}

	override public function cleanup():Void {
		trace("quit: shutdown");
		TestHarness.publish({shutdown: true});
	}
}
