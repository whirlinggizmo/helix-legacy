package helix.render3d;

import haxe.ds.ObjectMap;
import haxe.ds.Vector;
import helix.render3d.Track3D;
import helix.render3d.TrackPath3D;

/** Plays AnimationClips on the nodes under a root (a character's skeleton): each track moves the node of its name at or under the root, so a
	clip from one file plays on a skeleton from another with the same names, and a clip naming a node the root hasn't is refused. play()
	crossfades from the clip before over the seconds given; a node the clips don't both move blends with its rest pose (where it was when the
	Animator3D first moved it). queue() plays a clip next, when the one playing ends (a one-shot back to its idle). update() advances the time and poses the nodes; a Renderer3D draws them as they're left. One clip plays at a time
	(layers, playing an upper body's clip over a lower body's, aren't here yet). */
class Animator3D {
	var root:Node3D;
	var bindings = new ObjectMap<AnimationClip3D, Array<Node3D>>();
	var rests = new ObjectMap<Node3D, Vector<Float>>();
	var current:Null<Playing>;
	var previous:Null<Playing>;
	var next:Null<Queued>;
	var fade = 0.;
	var faded = 0.;
	var channels:Array<Channel> = [];
	var sampled = new Vector<Float>(4);
	var other = new Vector<Float>(4);

	/** Plays on the nodes at and under root. */
	public function new(root:Node3D)
		this.root = root;

	/** The clip playing, or null. */
	public var clip(get, never):Null<AnimationClip3D>;

	function get_clip():Null<AnimationClip3D>
		return current == null ? null : current.clip;

	/** Where the clip playing is, in seconds from its start (within its duration). */
	public var time(get, never):Float;

	function get_time():Float
		return current == null ? 0 : current.time;

	/** Moves the clip playing to seconds (wrapped into its duration when it loops, held between 0 and its end when not). False, changing nothing, with no
		clip playing or for a time that isn't finite. */
	public function setTime(seconds:Float):Bool {
		if (current == null || !Math.isFinite(seconds))
			return false;
		current.time = current.at(seconds);
		return true;
	}

	/** How fast time runs: 1 as the clip was made, 0 held, below 0 backwards. A speed that isn't finite is taken as 0. */
	public var speed(default, set):Float = 1.;

	function set_speed(value:Float):Float {
		value = Math.isFinite(value) ? value : 0;
		speed = value;
		return value;
	}

	/** Whether a clip that doesn't loop has reached its end (false while one loops, or with none). */
	public var finished(get, never):Bool;

	function get_finished():Bool
		return current != null && !current.loop && current.time >= current.clip.duration;

	/** Whether a crossfade is under way. */
	public var fading(get, never):Bool;

	function get_fading():Bool
		return previous != null;

	/** Plays clip from its start, looping or not, crossfading from the clip playing over fade seconds (0: at once); playing the clip already
		playing does nothing to it. Either way a queued clip is dropped. False, changing nothing, for a clip a track of which moves a node not at
		or under the root, or a fade below 0. */
	public function play(clip:AnimationClip3D, loop = true, fade = 0.):Bool {
		if (!(fade >= 0) || !Math.isFinite(fade))
			return false;
		if (current != null && current.clip == clip) {
			current.loop = loop;
			next = null;
			return true;
		}
		var nodes = bind(clip);
		if (nodes == null)
			return false;
		next = null;
		start(clip, nodes, loop, fade);
		return true;
	}

	/** Plays clip next, as play would, once the clip playing ends: at the update a clip that doesn't loop reaches its end, crossfading from its
		last frame over fade seconds; at once when none is playing or the one playing has finished. A looping clip doesn't end, so a clip queued
		behind one waits (until the clip playing is played again not looping). One clip waits at a time, a later queue replacing it; play and stop
		drop it. False, changing nothing, for a clip play would refuse. */
	public function queue(clip:AnimationClip3D, loop = true, fade = 0.):Bool {
		if (!(fade >= 0) || !Math.isFinite(fade))
			return false;
		if (current == null || finished)
			return play(clip, loop, fade);
		var nodes = bind(clip);
		if (nodes == null)
			return false;
		next = new Queued(clip, nodes, loop, fade);
		return true;
	}

	/** The clip waiting to play next (queue), or null. */
	public var queued(get, never):Null<AnimationClip3D>;

	function get_queued():Null<AnimationClip3D>
		return next == null ? null : next.clip;

	/** Stops playing: the nodes stay as the last update left them, and a queued clip is dropped. */
	public function stop():Void {
		current = previous = null;
		next = null;
		channels = [];
	}

	// Plays clip on nodes from its start, crossfading from the clip playing over fade seconds.
	function start(clip:AnimationClip3D, nodes:Array<Node3D>, loop:Bool, fade:Float):Void {
		previous = fade > 0 ? current : null;
		current = new Playing(clip, nodes, loop);
		this.fade = fade;
		faded = 0;
		rebuild();
	}

	/** Advances time by seconds (times the speed) and poses the nodes: call once a frame, before drawing. */
	public function update(seconds:Float):Void {
		if (current == null || !Math.isFinite(seconds))
			return;
		var step = seconds * speed;
		current.time = current.at(current.time + step);
		// The queued clip starts as the one playing reaches its end, from its own start.
		if (next != null && finished) {
			var n = next;
			next = null;
			start(n.clip, n.nodes, n.loop, n.fade);
		} else if (previous != null) {
			previous.time = previous.at(previous.time + step);
			faded += Math.abs(seconds);
			if (faded >= fade) {
				previous = null;
				rebuild();
			}
		}
		var weight = previous == null ? 1 : faded / fade;
		for (c in channels) {
			var width = c.path == Rotation ? 4 : 3, rest = rests.get(c.node);
			if (c.track != null)
				c.track.sample(current.time, sampled);
			else
				restValue(rest, c.path, sampled);
			if (weight < 1) {
				if (c.previousTrack != null)
					c.previousTrack.sample(previous.time, other);
				else
					restValue(rest, c.path, other);
				if (c.path == Rotation)
					Track3D.slerp(other[0], other[1], other[2], other[3], sampled[0], sampled[1], sampled[2], sampled[3], weight, sampled);
				else
					for (i in 0...width)
						sampled[i] = other[i] + (sampled[i] - other[i]) * weight;
			}
			switch c.path {
				case Translation:
					c.node.setPosition(sampled[0], sampled[1], sampled[2]);
				case Rotation:
					c.node.setQuaternion(sampled[0], sampled[1], sampled[2], sampled[3]);
				case Scale:
					c.node.setScale(sampled[0], sampled[1], sampled[2]);
			}
		}
	}

	// The nodes clip's tracks move, in track order, each remembered at rest the first time; null when one isn't at or under the root.
	function bind(clip:AnimationClip3D):Null<Array<Node3D>> {
		var nodes = bindings.get(clip);
		if (nodes != null)
			return nodes;
		nodes = [];
		for (i in 0...clip.trackCount) {
			var name = clip.getTrack(i).target;
			var node = root.name == name ? root : root.find(name, Node3D);
			if (node == null)
				return null;
			nodes.push(node);
		}
		for (node in nodes)
			if (!rests.exists(node)) {
				var rest = new Vector<Float>(10);
				rest[0] = node.x;
				rest[1] = node.y;
				rest[2] = node.z;
				rest[3] = node.quaternionX;
				rest[4] = node.quaternionY;
				rest[5] = node.quaternionZ;
				rest[6] = node.quaternionW;
				rest[7] = node.scaleX;
				rest[8] = node.scaleY;
				rest[9] = node.scaleZ;
				rests.set(node, rest);
			}
		bindings.set(clip, nodes);
		return nodes;
	}

	static function restValue(rest:Vector<Float>, path:TrackPath3D, out:Vector<Float>):Void {
		var from = path == Translation ? 0 : path == Rotation ? 3 : 7;
		for (i in 0...(path == Rotation ? 4 : 3))
			out[i] = rest[from + i];
	}

	// What each node and path the playing clips move takes its value from: the clip playing's track, the one before's, or its rest.
	function rebuild():Void {
		channels = [];
		function add(playing:Playing, isCurrent:Bool):Void
			for (i in 0...playing.clip.trackCount) {
				var track = playing.clip.getTrack(i), node = playing.nodes[i];
				var channel = null;
				for (c in channels)
					if (c.node == node && c.path == track.path)
						channel = c;
				if (channel == null) {
					channel = new Channel(node, track.path);
					channels.push(channel);
				}
				if (isCurrent)
					channel.track = track;
				else
					channel.previousTrack = track;
			}
		add(current, true);
		if (previous != null)
			add(previous, false);
	}
}

/** A clip playing: its nodes and where it is. */
private class Playing {
	/** The clip. */
	public var clip:AnimationClip3D;

	/** The node each of its tracks moves. */
	public var nodes:Array<Node3D>;

	/** Whether it loops. */
	public var loop:Bool;

	/** Where it is, seconds from its start. */
	public var time = 0.;

	/** clip playing on nodes, from its start. */
	public function new(clip:AnimationClip3D, nodes:Array<Node3D>, loop:Bool) {
		this.clip = clip;
		this.nodes = nodes;
		this.loop = loop;
	}

	/** seconds within the clip: wrapped into its duration when it loops, else held between 0 and its end. */
	public function at(seconds:Float):Float {
		var duration = clip.duration;
		if (duration <= 0)
			return 0;
		if (!loop)
			return seconds < 0 ? 0 : seconds > duration ? duration : seconds;
		var t = seconds % duration;
		return t < 0 ? t + duration : t;
	}
}

/** One node's path, and the tracks moving it: the clip playing's and the one before's (null where a clip doesn't move it). */
private class Channel {
	/** The node. */
	public var node:Node3D;

	/** What of it moves. */
	public var path:TrackPath3D;

	/** The clip playing's track for it, or null. */
	public var track:Null<Track3D>;

	/** The clip before's track for it, or null. */
	public var previousTrack:Null<Track3D>;

	/** No tracks yet for node's path. */
	public function new(node:Node3D, path:TrackPath3D) {
		this.node = node;
		this.path = path;
	}
}

/** A clip waiting to play (Animator3D.queue), its nodes bound when it was queued. */
private class Queued {
	/** The clip. */
	public final clip:AnimationClip3D;

	/** The nodes its tracks move. */
	public final nodes:Array<Node3D>;

	/** Whether it loops. */
	public final loop:Bool;

	/** The crossfade into it, in seconds. */
	public final fade:Float;

	/** A clip to play next, bound to nodes. */
	public function new(clip:AnimationClip3D, nodes:Array<Node3D>, loop:Bool, fade:Float) {
		this.clip = clip;
		this.nodes = nodes;
		this.loop = loop;
		this.fade = fade;
	}
}
