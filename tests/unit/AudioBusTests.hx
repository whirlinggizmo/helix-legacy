import haxe.io.Bytes;
import helix.asset.IAssets.AudioLocation;
import helix.asset.IStore;
import helix.asset.SaveService;
import helix.asset.Saves;
import helix.asset.Storage;
import helix.asset.StorageService;
import helix.asset.StorageResult;
import helix.asset.StorageWriteResult;
import helix.asset.StorageSourceResult;
import helix.audio.Audio;
import helix.audio.AudioClip;
import helix.audio.AudioResources;
import helix.audio.Fade;
import helix.audio.IAudio;
import helix.audio.StreamOpenResult;

/** An IAudio that records what it's told: each voice's last volume, pitch and pan, and every call in order. running starts false, so a
	playback waits until the test lets audio start. */
private class Recording implements IAudio {
	public var volumes:Map<Int, Float> = [];
	public var pitches:Map<Int, Float> = [];
	public var pans:Map<Int, Float> = [];
	public var playing:Map<Int, Bool> = [];
	public var calls:Array<String> = [];
	public var started = false;

	var next = 1;

	public function new() {}

	public var available(get, never):Bool;

	function get_available():Bool
		return true;

	public var playsUrls(get, never):Bool;

	function get_playsUrls():Bool
		return true;

	public var running(get, never):Bool;

	function get_running():Bool
		return started;

	public function createClip(samples:Bytes):Int
		return next++;

	public function destroyClip(clip:Int):Void {}

	public function openStream(source:AudioLocation, done:StreamOpenResult->Void):Void->Void
		return () -> {};

	public function destroyStream(stream:Int):Void {}

	public function playClip(clip:Int, loop:Bool, volume:Float):Int {
		var voice = next++;
		volumes[voice] = volume;
		playing[voice] = true;
		calls.push('play $voice $volume');
		return voice;
	}

	public function playStream(stream:Int, loop:Bool, volume:Float):Int
		return playClip(stream, loop, volume);

	public function stop(voice:Int):Void {
		playing.remove(voice);
		calls.push('stop $voice');
	}

	public function pause(voice:Int, paused:Bool):Void {}

	public function setVolume(voice:Int, volume:Float):Bool {
		if (!playing.exists(voice) || !(volume >= 0 && volume <= 1))
			return false;
		volumes[voice] = volume;
		calls.push('volume $voice $volume');
		return true;
	}

	public function setPitch(voice:Int, pitch:Float):Bool {
		if (!playing.exists(voice))
			return false;
		pitches[voice] = pitch;
		calls.push('pitch $voice $pitch');
		return true;
	}

	public function setPan(voice:Int, pan:Float):Bool {
		if (!playing.exists(voice))
			return false;
		pans[voice] = pan;
		calls.push('pan $voice $pan');
		return true;
	}

	public function isPlaying(voice:Int):Bool
		return playing.exists(voice);

	public function poll():Void {}

	public function shutdown():Void {}
}

/** A store in memory, answering at its poll. */
private class Memory implements IStore {
	public var files:Map<String, Bytes> = [];

	var pending:Array<Void->Void> = [];

	public function new() {}

	public function read(key:String, maxBytes:Int, done:helix.asset.StorageResult->Void):Void
		pending.push(() -> done(files.exists(key) ? Stored(files[key]) : Missing));

	public function write(key:String, bytes:Bytes, done:helix.asset.StorageWriteResult->Void):Void
		pending.push(() -> {
			files[key] = bytes;
			done(Written);
		});

	public function remove(key:String, done:helix.asset.StorageWriteResult->Void):Void
		pending.push(() -> {
			files.remove(key);
			done(Written);
		});

	public function clear(done:helix.asset.StorageWriteResult->Void):Void
		pending.push(() -> {
			files.clear();
			done(Written);
		});

	public function lease(key:String, done:helix.asset.StorageSourceResult->Void):Void
		pending.push(() -> done(Missing));

	public function poll():Void {
		var now = pending;
		pending = [];
		for (f in now)
			f();
	}

	public function shutdown():Void {}
}

/** Buses and playbacks over a recording IAudio (helix.audio.Bus, AudioPlayback, Audio's statics): heard volumes through buses and a mute,
	fades linear in decibels, stopWhenSilent, crossfade linear in power, pitch and pan clamped and sent, a bus made before any service is bound, saving and
	loading the buses through Storage. */
class AudioBusTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float, e = 1e-9):Bool
		return Math.abs(a - b) < e;

	static function main():Void {
		// Made before any service: a bus is plain engine data.
		check(@:privateAccess Audio.instance == null, "No service bound yet");
		var ambience = Audio.addBus("ambience", Audio.effects);
		check(ambience != null && ambience.parent == Audio.effects && ambience.volume == 1, "A bus made before the service is bound");
		check(Audio.addBus("ambience", Audio.master) == null
			&& Audio.addBus("", Audio.master) == null
			&& Audio.addBus("music", Audio.master) == null,
			"A used or empty name is refused");
		check(Audio.master.parent == null && Audio.music.parent == Audio.master && Audio.effects.parent == Audio.master, "The tree from the start");
		var refused = try {
			ambience.play(null);
			false;
		} catch (_:Dynamic)
			true;
		check(refused, "Playing with no service bound throws");
		var state = helix.audio.PlayState.Playing;
		check(Std.string(state) == "Playing" && '$state' == "Playing" && helix.audio.PlayState.Complete != state, "A playback's state reads as its name");

		var audio = new Recording();
		var sounds = new AudioResources(null, audio, null);
		@:privateAccess Audio.bind(sounds);
		var clip = new AudioClip(audio.createClip(null), audio);

		// Two buses and a mute: heard = own × ambience × effects × master.
		Audio.master.volume = .5;
		Audio.effects.volume = .8;
		ambience.volume = .5;
		var rain = ambience.play(clip, true, .5);
		check(rain.bus == ambience && rain.id == 0, "Waits while audio hasn't started");
		audio.started = true;
		sounds.poll(1 / 60);
		check(rain.id != 0
			&& near(audio.volumes[rain.id], .5 * .5 * .8 * .5), "Starts at its heard volume through two buses and the master");
		check(near(rain.heardVolume, .1), "heardVolume is its own times its buses'");
		Audio.effects.muted = true;
		sounds.poll(1 / 60);
		check(audio.volumes[rain.id] == 0 && ambience.heardVolume == 0, "A muted parent silences it");
		Audio.effects.muted = false;
		sounds.poll(1 / 60);
		check(near(audio.volumes[rain.id], .1), "Unmuting gives the kept volume back");
		var sent = audio.calls.length;
		sounds.poll(1 / 60);
		check(audio.calls.length == sent, "Nothing sent when nothing changed");
		rain.volume = 2;
		check(rain.volume == 1 && near(audio.volumes[rain.id], .2), "A playback's volume clamps and is sent at once");
		Audio.master.volume = 1;
		Audio.effects.volume = 1;
		ambience.volume = 1;

		// A fade linear in decibels: 1 to .01 (-40 dB) over 2 s is -20 dB, .1, halfway.
		rain.volume = 1;
		var faded = false;
		rain.fade(.01, 2, () -> faded = true);
		sounds.poll(1);
		check(near(rain.volume, .1, 1e-9)
			&& near(audio.volumes[rain.id], .1, 1e-9)
			&& !faded, "Halfway through a fade is halfway in decibels");
		sounds.poll(1);
		check(rain.volume == .01 && faded, "The fade ends on its value exactly and runs done");
		check(near(Fade.at(0, 1, .5), Math.pow(10, -30 / 20)), "A silent end is taken as -60 dB");

		// A bus's fade, then stopWhenSilent.
		var busDone = false;
		ambience.fade(.25, .5, () -> busDone = true);
		sounds.poll(.25);
		check(ambience.volume > .25 && ambience.volume < 1 && !busDone, "A bus fades over time");
		sounds.poll(.25);
		check(ambience.volume == .25 && busDone && near(audio.volumes[rain.id], .01 * .25), "A bus's fade reaches its playbacks");
		ambience.volume = 1;
		rain.fade(0, 1, null, true);
		sounds.poll(.5);
		check(!rain.finished, "Still playing mid fade-out");
		sounds.poll(.5);
		check(rain.finished && !audio.playing.exists(rain.id) && rain.volume == 0, "stopWhenSilent stops it at the end");
		var instant = Audio.play(clip, false, 1);
		instant.fade(.5, 0);
		check(instant.volume == .5 && near(audio.volumes[instant.id], .5), "A fade of 0 seconds sets it at once");
		check(instant.bus == Audio.effects, "Audio.play plays through effects");
		instant.stop();

		// Crossfade: the old one fades out and stops, the new one up to 1, linear in power: the two hold their summed power throughout.
		check(near(Fade.at(1, 0, .25, Power), Math.sqrt(.75)) && near(Fade.at(0, .5, .5, Power), Math.sqrt(.125)), "Linear in power");
		var old = Audio.music.play(clip, true, 1),
			next = Audio.music.play(clip, true, 0);
		Audio.crossfade(old, next, 2);
		sounds.poll(1);
		check(near(old.volume, Math.sqrt(.5)) && near(next.volume, Math.sqrt(.5)), "Crossfade's middle, each at half the power");
		sounds.poll(.5);
		check(near(old.volume * old.volume + next.volume * next.volume, 1), "Crossfade's summed power held");
		sounds.poll(.5);
		check(old.finished && next.volume == 1 && !next.finished, "Crossfade ends with the old stopped and the new at 1");

		// Pitch and pan, clamped and sent.
		next.pitch = 8;
		next.pan = -3;
		check(next.pitch == 4 && audio.pitches[next.id] == 4 && next.pan == -1 && audio.pans[next.id] == -1, "Pitch and pan clamp high and low");
		next.pitch = .1;
		next.pan = Math.NaN;
		check(next.pitch == .25 && audio.pitches[next.id] == .25 && next.pan == 0 && audio.pans[next.id] == 0, "Pitch clamps low, NaN pan is 0");
		next.pitch = Math.NaN;
		check(next.pitch == 1, "NaN pitch is 1");
		next.stop();
		audio.started = false;
		var waiting = Audio.effects.play(clip);
		waiting.pitch = 2;
		waiting.pan = .5;
		audio.started = true;
		sounds.poll(1 / 60);
		check(audio.pitches[waiting.id] == 2 && audio.pans[waiting.id] == .5, "A waiting playback's pitch and pan reach its voice as it starts");
		waiting.stop();

		// Saving and loading the buses as a save, apart from the asset cache; a saved name with no bus is skipped.
		var store = new Memory(),
			saves = new SaveService(store),
			cacheStore = new Memory(),
			cache = new StorageService(cacheStore);
		@:privateAccess Saves.bind(saves);
		@:privateAccess Storage.bind(cache);
		function settle()
			for (_ in 0...8) {
				store.poll();
				saves.poll();
				cacheStore.poll();
				cache.poll();
			}
		Audio.master.volume = .7;
		Audio.music.muted = true;
		ambience.volume = .3;
		var saved = false;
		Audio.saveBuses("audio", () -> saved = true);
		settle();
		check(saved && store.files.exists("audio"), "Saved under the key");
		var json:Dynamic = haxe.Json.parse(store.files["audio"].toString());
		json.gone = {volume: .1, muted: true};
		store.files["audio"] = Bytes.ofString(haxe.Json.stringify(json));
		Audio.master.volume = 1;
		Audio.music.muted = false;
		ambience.volume = 1;
		var loaded = false;
		Audio.loadBuses("audio", () -> loaded = true);
		settle();
		check(loaded && near(Audio.master.volume, .7) && Audio.music.muted && near(ambience.volume, .3), "Loaded back by name");
		Storage.clear(_ -> {});
		settle();
		check(store.files.exists("audio"), "Clearing the asset cache keeps the saved buses");
		var missing = false;
		Audio.loadBuses("nothing", () -> missing = true);
		settle();
		check(missing, "Nothing saved is no failure");
		store.files["bad"] = Bytes.ofString("[1]");
		var failure:String = null;
		Audio.loadBuses("bad", null, message -> failure = message);
		settle();
		check(failure != null, "A file that isn't the saved buses fails");

		sounds.shutdown();
		@:privateAccess Audio.bind(null);
		@:privateAccess Saves.bind(null);
		@:privateAccess Storage.bind(null);
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}
}
