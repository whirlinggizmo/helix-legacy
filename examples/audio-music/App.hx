import helix.audio.Audio;
import helix.audio.AudioClip;
import helix.audio.AudioPlayback;
import helix.asset.Assets;
import helix.audio.AudioStream;
import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.time.Time;
import helix.host.ScreenShape;

/** Looping music and a one-shot click. The music is streamed (decoded as it plays), the click decoded as it loads. The sound plays off the frame's
	thread on both targets (natively the mixer's, on the web the browser's), so it plays on through a slow frame: S stalls one for 300 ms.
	Space plays the click, M pauses and resumes the music, F fades the music bus out over 2 s and in again, C crossfades over 3 s to the other
	track (a pad loop beside the example) and back, Left and Right pan the music a quarter at a time, Up and Down pitch it a semitone, 0 sets
	both back, Escape quits where quitting means anything. Natively with HELIX_ASSET_HOST set (and nothing cached yet), the music is a download
	played as it arrives; in the browser the page streams it from beside it. */
class App extends helix.App {
	static inline var HERO = "audio/music/a_hero_is_born.mp3";
	static inline var PAD = "audio/music/pad_loop.ogg";
	// The crossfade's and the bus fade's seconds.
	static inline var CROSSFADE = 3.;
	static inline var FADE = 2.;

	var text = new Drawing2D();
	var fps = new FpsOverlay();
	var click:Null<AudioClip>;
	// The two tracks, kept for playing again; the one heard, and its playback.
	var hero:Null<AudioStream>;
	var pad:Null<AudioStream>;
	var onPad = false;
	var music:Null<AudioPlayback>;
	// Seconds left of a crossfade, during which C waits.
	var crossfading = 0.;
	// Semitones from the recording, and the pan, carried from one track to the other.
	var semitones = 0;
	var pan = 0.;
	var busFadedOut = false;

	override public function init():Void {
		Window.title = "HeliX audio";
		Window.requestSize(720, 360);
		Stage.color = 0xff12141c;
		Stage.addChild(text);
		Stage.addChild(fps);
		Audio.loadStream(HERO, stream -> {
			hero = stream;
			music = start(stream, .5);
		});
		Audio.loadStream(PAD, stream -> pad = stream);
		Audio.loadClip("audio/sfx/click_004.ogg", clip -> click = clip);
	}

	// Plays stream through the music bus from its start, looping, at volume, with the pitch and pan set.
	function start(stream:AudioStream, volume:Float):AudioPlayback {
		var playback = Audio.music.play(stream, true, volume);
		playback.pitch = Math.pow(2, semitones / 12);
		playback.pan = pan;
		return playback;
	}

	// Crossfades to the other track, started at 0.
	function swap():Void {
		var next = onPad ? hero : pad;
		if (music == null || next == null || crossfading > 0)
			return;
		var to = start(next, 0);
		Audio.crossfade(music, to, CROSSFADE, .5);
		music = to;
		onPad = !onPad;
		crossfading = CROSSFADE;
	}

	// The pitch and pan onto what's playing.
	function shape():Void {
		if (music == null)
			return;
		music.pitch = Math.pow(2, semitones / 12);
		music.pan = pan;
	}

	override public function update(dt:Float):Void {
		if (Input.isFramePressed(Key.Space) && click != null)
			Audio.play(click);
		if (Input.isFramePressed(Key.S)) {
			// A deliberately slow frame.
			var until = Time.time + .3;
			while (Time.time < until) {}
		}
		if (Input.isFramePressed(Key.M) && music != null && !music.pause())
			music.resume();
		if (Input.isFramePressed(Key.F)) {
			busFadedOut = !busFadedOut;
			Audio.music.fade(busFadedOut ? 0 : 1, FADE);
		}
		crossfading = Math.max(0, crossfading - dt);
		if (Input.isFramePressed(Key.C))
			swap();
		if (Input.isFramePressed(Key.Left) || Input.isFramePressed(Key.Right)) {
			pan = Math.max(-1, Math.min(1, pan + (Input.isFramePressed(Key.Left) ? -.25 : .25)));
			shape();
		}
		if (Input.isFramePressed(Key.Up) || Input.isFramePressed(Key.Down)) {
			semitones = Std.int(Math.max(-12, Math.min(12, semitones + (Input.isFramePressed(Key.Up) ? 1 : -1))));
			shape();
		}
		if (Input.isFramePressed(Key.Digit0)) {
			semitones = 0;
			pan = 0;
			shape();
		}
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		fps.update(dt, Time.frameCpu);
		// The text in the design for the window's shape, wrapped to what's visible of it.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		text.clear();
		var y = vy + 30;
		y += text.drawTextWrapped("HeliX audio", vx + 24, y, 28, vw - 48, 0xfff5f5f5) + 15;
		var track = onPad ? "the pad loop (ogg" : "A Hero Is Born (mp3";
		y += text.drawTextWrapped(music == null ? "music: loading..." : switch (music.state) {
			case Playing: 'music: $track, streamed, looping)${crossfading > 0 ? ", crossfading" : ""}';
			case Paused: "music: paused";
			case Stopped: "music: couldn't start";
			case Complete: "music: ended";
		}, vx + 24, y, 18, vw - 48, 0xff66bfff) + 7.5;
		var host = Assets.host;
		y += text.drawTextWrapped(host == null ? "from the packaged files" : host.indexOf("://") < 0 ? "from beside the page" : 'from $host (played as it downloads, until cached)',
			vx
			+ 24, y, 16, vw
			- 48, 0xff66bfff)
			+ 7.5;
		y += text.drawTextWrapped('pitch ${semitones > 0 ? "+" : ""}$semitones semitones   pan ${pan == 0 ? "centre" : (pan < 0 ? "left " : "right ") + Math.round(Math.abs(pan) * 100) + "%"}   music bus ${Math.round(Audio.music.volume * 100)}%',
			vx
			+ 24, y, 16, vw
			- 48, 0xfff5f5f5)
			+ 7.5;
		y += text.drawTextWrapped(click != null ? "click: ready (ogg)" : "click: loading...", vx + 24, y, 18, vw - 48, 0xff00e430) + 17.5;
		text.drawTextWrapped("[SPACE] click   [M] pause   [F] fade bus   [C] crossfade   [LEFT/RIGHT] pan   [UP/DOWN] pitch   [0] reset   [S] stall 300 ms"
			+ (Host.canQuit() ? "   [ESC] quit" : ""),
			vx
			+ 24, y, 16, vw
			- 48, 0xffc8c8c8);
		fps.setPosition(vx + 24, vy + 8);
	}
}
