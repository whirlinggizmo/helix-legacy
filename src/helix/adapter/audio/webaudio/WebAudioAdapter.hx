package helix.adapter.audio.webaudio;

import haxe.io.Bytes;
import helix.asset.IAssets.AudioLocation;
import helix.audio.IAudio;
import helix.audio.StreamOpenResult;

/** IAudio in a browser over Web Audio: clips become AudioBuffers, streams are media elements routed through the audio graph, each voice a
	source through a gain and a stereo panner, its volume and pan changes ramped by setTargetAtTime (RAMP) and its pitch the source's playback
	rate. The page's first key, click or tap unlocks audio (browsers let it start only in a user gesture); the page losing focus or being
	hidden suspends it. */
@:noCompletion
class WebAudioAdapter implements IAudio {
	/** The time constant a volume or pan change approaches its target by, in seconds: short enough to follow a fade stepped once a frame,
		long enough not to click. */
	static inline var RAMP = .01;

	var context:Dynamic;
	var clips:Map<Int, Bytes> = [];
	var buffers:Map<Int, Dynamic> = [];
	var streams:Map<Int, {url:String, element:Null<js.html.AudioElement>}> = [];
	var playbacks:Map<Int, Dynamic> = [];
	var nextClip = 1;
	var nextPlayback = 1;

	/** The events that unlock audio. A key or a mouse button counts as it goes down, but a finger only as it lifts (pointerup, touchend,
		click): on a phone, a tap's pointerdown isn't a gesture the browser lets audio start in. */
	static final GESTURES = ["keydown", "pointerdown", "pointerup", "touchend", "click"];

	/** Listens for the page's gestures (as they reach the window, before the page's own handlers) and its visibility; no AudioContext until a
		gesture unlocks audio. */
	public function new() {
		for (name in GESTURES)
			js.Browser.window.addEventListener(name, _ -> unlock(), true);
		js.Browser.window.addEventListener("blur", _ -> suspend());
		js.Browser.document.addEventListener("visibilitychange", _ -> if (js.Browser.document.hidden) suspend());
	}

	/** Creates the AudioContext if needed and resumes it; it works only in a user gesture (the page's listeners call it). */
	public function unlock():Void {
		if (context == null)
			context = js.Syntax.code("new (window.AudioContext || window.webkitAudioContext)()");
		// Outside a gesture the browser keeps it suspended and may refuse: the next gesture tries again.
		js.Syntax.code("{0}.resume().catch(function() {})", context);
	}

	/** Suspends a running AudioContext, as when the page is hidden; the next gesture resumes it. */
	public function suspend():Void {
		if (context != null && context.state == "running")
			context.suspend();
	}

	public var available(get, never):Bool;

	function get_available():Bool
		return true;

	public var playsUrls(get, never):Bool;

	function get_playsUrls():Bool
		return true;

	public var running(get, never):Bool;

	function get_running():Bool
		return context != null && context.state == "running";

	public function createClip(samples:Bytes):Int {
		var id = nextClip++;
		clips[id] = samples.sub(0, samples.length);
		return id;
	}

	public function openStream(location:AudioLocation, done:StreamOpenResult->Void):Void->Void {
		var url = switch location {
			case Stored(value): value.location;
			case Remote(url): url;
			case Downloading(_): null;
		};
		// A media element plays a URL, so a remote stream is given as one (playsUrls), never as a download.
		if (url == null) {
			var aborted = false;
			js.Browser.window.setTimeout(() -> if (!aborted) done(Failed("A download isn't streamed in a browser; its URL is")), 0);
			return () -> aborted = true;
		}
		var element = js.Browser.document.createAudioElement(), settled = false, timer = 0, opened = 0;
		function dispose():Void {
			element.onloadedmetadata = null;
			element.onerror = null;
			element.pause();
			element.removeAttribute("src");
			element.load();
		}
		function finish(result:StreamOpenResult):Void {
			if (settled)
				return;
			settled = true;
			js.Browser.window.clearTimeout(timer);
			element.onloadedmetadata = null;
			element.onerror = null;
			done(result);
		}
		element.preload = "metadata";
		element.crossOrigin = "anonymous";
		element.onloadedmetadata = _ -> {
			opened = nextClip++;
			streams[opened] = {url: url, element: element};
			finish(Opened(opened));
		};
		element.onerror = _ -> {
			dispose();
			finish(Failed("Streamed audio failed: " + url));
		};
		timer = js.Browser.window.setTimeout(() -> {
			dispose();
			finish(Failed("Streamed audio metadata timeout"));
		}, 15000);
		element.src = url;
		element.load();
		return () -> {
			if (!settled) {
				settled = true;
				js.Browser.window.clearTimeout(timer);
				dispose();
			} else if (opened != 0 && streams.exists(opened))
				destroyStream(opened);
		};
	}

	function clipSource(id:Int, v:Dynamic):Void {
		var source:Dynamic = context.createBufferSource();
		source.buffer = v.buffer;
		source.loop = v.loop;
		source.playbackRate.value = v.pitch;
		source.connect(v.gain);
		v.source = source;
		v.started = context.currentTime;
		v.paused = false;
		source.onended = _ -> {
			if (playbacks[id] == v && !v.paused) {
				playbacks.remove(id);
				source.disconnect();
				disconnect(v);
			}
		};
		source.start(0, v.offset);
	}

	public function playClip(clip:Int, loop:Bool, volume:Float):Int {
		if (!clips.exists(clip))
			throw "Invalid audio clip";
		if (!this.running)
			return 0;
		var id = nextPlayback++;
		start(id, clip, loop, volume);
		return id;
	}

	public function playStream(stream:Int, loop:Bool, volume:Float):Int {
		if (!streams.exists(stream))
			throw "Invalid audio stream";
		if (!this.running)
			return 0;
		var id = nextPlayback++;
		start(id, stream, loop, volume);
		return id;
	}

	// A voice's gain and panner, out of the graph.
	function disconnect(v:Dynamic):Void {
		v.gain.disconnect();
		v.panner.disconnect();
	}

	function start(id:Int, resource:Int, loop:Bool, volume:Float):Void {
		var gain:Dynamic = context.createGain(),
			panner:Dynamic = context.createStereoPanner();
		gain.gain.value = volume;
		gain.connect(panner);
		panner.connect(context.destination);
		if (streams.exists(resource)) {
			var entry = streams[resource],
				element:js.html.AudioElement = entry.element;
			if (element == null) {
				element = js.Browser.document.createAudioElement();
				element.crossOrigin = "anonymous";
				element.src = entry.url;
			}
			entry.element = null;
			element.loop = loop;
			element.playbackRate = 1;
			// The rate changes the pitch too, as a clip's does.
			Reflect.setField(element, "preservesPitch", false);
			var source:Dynamic = context.createMediaElementSource(element);
			source.connect(gain);
			var v:Dynamic = {
				kind: "stream",
				source: element,
				node: source,
				gain: gain,
				panner: panner,
				resource: resource,
				pitch: 1.,
				paused: false
			};
			playbacks[id] = v;
			element.onended = _ -> finishStream(id, v);
			element.onerror = _ -> finishStream(id, v);
			element.play().catchError(error -> {
				finishStream(id, v);
				return null;
			});
		} else {
			var buffer = buffers[resource];
			if (buffer == null) {
				var data = clips[resource];
				buffer = context.createBuffer(1, Std.int(data.length / 4), 44100);
				buffer.copyToChannel(new js.lib.Float32Array(data.getData()), 0);
				buffers[resource] = buffer;
			}
			var v:Dynamic = {
				kind: "clip",
				source: null,
				gain: gain,
				panner: panner,
				resource: resource,
				pitch: 1.,
				buffer: buffer,
				loop: loop,
				offset: 0.,
				started: 0.,
				paused: false
			};
			playbacks[id] = v;
			clipSource(id, v);
		}
	}

	function finishStream(id:Int, v:Dynamic):Void {
		if (playbacks[id] != v)
			return;
		playbacks.remove(id);
		v.source.onended = null;
		v.source.onerror = null;
		v.source.pause();
		v.source.removeAttribute("src");
		v.source.load();
		v.node.disconnect();
		disconnect(v);
	}

	public function stop(id:Int):Void {
		var v = playbacks[id];
		if (v == null)
			return;
		if (v.kind == "stream")
			finishStream(id, v);
		else {
			playbacks.remove(id);
			v.source.onended = null;
			if (!v.paused)
				v.source.stop();
			v.source.disconnect();
			disconnect(v);
		}
	}

	public function pause(id:Int, paused:Bool):Void {
		var v = playbacks[id];
		if (v == null || v.paused == paused)
			return;
		if (v.kind == "stream") {
			v.paused = paused;
			if (paused)
				v.source.pause();
			else
				v.source.play().then(_ -> null, error -> {
					finishStream(id, v);
					return null;
				});
		} else if (paused) {
			played(v);
			v.paused = true;
			v.source.onended = null;
			v.source.stop();
			v.source.disconnect();
		} else {
			if (v.offset >= v.buffer.duration) {
				stop(id);
				return;
			}
			clipSource(id, v);
		}
	}

	public function setVolume(id:Int, volume:Float):Bool {
		var v = playbacks[id];
		if (v == null || !Math.isFinite(volume) || volume < 0 || volume > 1)
			return false;
		v.gain.gain.setTargetAtTime(volume, context.currentTime, RAMP);
		return true;
	}

	// Moves a playing clip voice's offset (in the buffer's seconds) on by what it played since it started or last moved, at its pitch.
	function played(v:Dynamic):Void {
		var now:Float = context.currentTime;
		v.offset += (now - v.started) * v.pitch;
		if (v.loop)
			v.offset %= v.buffer.duration;
		v.started = now;
	}

	public function setPitch(id:Int, pitch:Float):Bool {
		var v = playbacks[id];
		if (v == null)
			return false;
		if (v.kind == "stream")
			v.source.playbackRate = pitch;
		else if (!v.paused) {
			played(v);
			v.source.playbackRate.value = pitch;
		}
		v.pitch = pitch;
		return true;
	}

	public function setPan(id:Int, pan:Float):Bool {
		var v = playbacks[id];
		if (v == null)
			return false;
		v.panner.pan.setTargetAtTime(pan, context.currentTime, RAMP);
		return true;
	}

	public function isPlaying(id:Int):Bool
		return playbacks.exists(id);

	public function destroyClip(id:Int):Void {
		if (!clips.exists(id))
			throw "Invalid audio clip";
		for (playback in [for (p in playbacks.keys()) if (playbacks[p].resource == id) p])
			stop(playback);
		clips.remove(id);
		buffers.remove(id);
	}

	public function destroyStream(id:Int):Void {
		var entry = streams[id];
		if (entry == null)
			throw "Invalid audio stream";
		for (playback in [for (p in playbacks.keys()) if (playbacks[p].resource == id) p])
			stop(playback);
		if (entry.element != null) {
			entry.element.removeAttribute("src");
			entry.element.load();
		}
		streams.remove(id);
	}

	/** Nothing to keep fed: media elements and the audio graph run on their own. */
	public function poll():Void {}

	public function shutdown():Void {
		for (id in [for (p in playbacks.keys()) p])
			stop(id);
		for (id in [for (s in streams.keys()) s])
			destroyStream(id);
		clips.clear();
		buffers.clear();
		if (context != null) {
			context.close();
			context = null;
		}
	}
}
