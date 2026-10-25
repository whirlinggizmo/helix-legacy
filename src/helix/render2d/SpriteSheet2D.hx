package helix.render2d;

import haxe.io.Bytes;
import helix.asset.Assets;
import helix.asset.Failure;
import helix.asset.IReloadable;
import helix.asset.IRequest;
import helix.asset.Request;
import helix.texture.Texture2D;
import helix.texture.Textures;

/** A texture holding many pictures (an atlas), with where each one is (its frames) and the runs of them that animate (its animations). Read from the
	JSON TexturePacker and Aseprite write (their "JSON Hash" and "JSON Array" layouts: trimmed and rotated frames, pivots, Aseprite's tags and
	frame durations), or cut from a grid of equal cells. Without tags, frames whose names differ only by a number make an animation ("run_01.png",
	"run_02.png": "run"). A Sprite2D shows a frame (Sprite2D.setFrame), a Batch2D draws one (Batch2D.sheetFrame), a SpriteAnimator2D plays them. */
class SpriteSheet2D implements IReloadable {
	var frameList:Array<SpriteFrame2D> = [];
	var animationList:Array<SpriteAnimation2D> = [];
	var defaultDuration:Float;
	var path:Null<String>;

	/** Its texture. */
	public var texture(default, null):Texture2D;

	/** How many times its file has been read again (a hot reload): an animator playing it finds its animation again by name. */
	public var reloadCount(default, null) = 0;

	function new(texture:Texture2D, secondsPerFrame:Float) {
		this.texture = texture;
		defaultDuration = secondsPerFrame;
	}

	/** A sheet over texture from a TexturePacker or Aseprite JSON file's text; a frame without its own duration shows for secondsPerFrame.
		Throws, saying why, for text it can't read. */
	public static function parse(texture:Texture2D, text:String, secondsPerFrame = .1):SpriteSheet2D {
		var sheet = new SpriteSheet2D(texture, secondsPerFrame);
		sheet.read(text);
		return sheet;
	}

	/** A sheet over texture cut into cells of frameWidth x frameHeight texels, left to right then down, margin texels in from its edges and
		spacing texels apart: count of them (every whole cell for 0), named by number from "0", each shown for secondsPerFrame. It has no
		animations until given them (addAnimation). */
	public static function grid(texture:Texture2D, frameWidth:Int, frameHeight:Int, count = 0, secondsPerFrame = .1, margin = 0, spacing = 0):SpriteSheet2D {
		if (frameWidth <= 0 || frameHeight <= 0)
			throw 'A grid\'s cells need a size: $frameWidth x $frameHeight';
		var sheet = new SpriteSheet2D(texture, secondsPerFrame);
		var columns = Std.int((texture.width - margin * 2 + spacing) / (frameWidth + spacing)),
			rows = Std.int((texture.height - margin * 2 + spacing) / (frameHeight + spacing));
		var total = count > 0 && count < columns * rows ? count : columns * rows;
		for (i in 0...total) {
			var x = margin + (i % columns) * (frameWidth + spacing),
				y = margin + Std.int(i / columns) * (frameHeight + spacing);
			sheet.frameList.push(new SpriteFrame2D(Std.string(i), x, y, frameWidth, frameHeight, false, 0, 0, frameWidth, frameHeight, Math.NaN, Math.NaN,
				secondsPerFrame));
		}
		return sheet;
	}

	/** Loads a TexturePacker or Aseprite JSON file at path and the image it names (its meta.image, beside it), filtered by filter (Linear smooth, Nearest
		sharp for pixel art: TextureCache.load); a frame without its own duration shows for secondsPerFrame. The file reads again in place when it
		changes during development, as the image does. One of loaded or failed runs once (failed, else the log, for a file that doesn't load or
		read, or an image that doesn't), neither once the request is cancelled. destroy frees what it loaded. */
	public static function load(path:String, loaded:SpriteSheet2D->Void, ?failed:String->Void, filter:helix.texture.Filter = Nearest,
			secondsPerFrame = .1):IRequest {
		var step:Null<IRequest> = null, request:Request = null;
		request = new Request(() -> if (step != null) step.cancel());
		step = Assets.load(path, bytes -> {
			if (request.settled)
				return;
			var text = bytes.toString(), image:Null<String> = null;
			try {
				image = imageOf(path, text);
			} catch (e:Dynamic) {
				if (request.finish())
					Failure.report(path, '$path: $e', failed);
				return;
			}
			step = Textures.load(image, filter, texture -> {
				if (request.settled) {
					Textures.release(texture);
					return;
				}
				var sheet = new SpriteSheet2D(texture, secondsPerFrame);
				try
					sheet.read(text)
				catch (e:Dynamic) {
					Textures.release(texture);
					if (request.finish())
						Failure.report(path, '$path: $e', failed);
					return;
				}
				request.finish();
				sheet.path = path;
				Assets.subscribe(path, sheet);
				loaded(sheet);
			},
				message -> if (request.finish()) Failure.report(path, Failure.named(path, message), failed));
		},
			message -> if (request.finish()) Failure.report(path, Failure.named(path, message), failed));
		return request;
	}

	// The asset path of the image a sheet's file at path names (its meta.image, beside it). Throws for a file that names none, or one outside the assets.
	static function imageOf(path:String, text:String):String {
		var file:Dynamic = haxe.Json.parse(text);
		var image:Null<String> = file.meta == null ? null : file.meta.image;
		if (image == null)
			throw "it names no image (meta.image)";
		var resolved = helix.asset.AssetPath.resolve(path, image);
		if (resolved == null)
			throw 'its image "$image" isn\'t a path beside it in the assets';
		return resolved;
	}

	/** How many frames it has. */
	public var frameCount(get, never):Int;

	function get_frameCount():Int
		return frameList.length;

	/** Its frame at index (0 up to frameCount), or null. */
	public function getFrame(index:Int):Null<SpriteFrame2D>
		return index >= 0 && index < frameList.length ? frameList[index] : null;

	/** The index of its frame named name (as its file names it: "run_01.png"), or -1. */
	public function findFrame(name:String):Int {
		for (i in 0...frameList.length)
			if (frameList[i].name == name)
				return i;
		return -1;
	}

	/** Its animations' names, in the order its file gives them. */
	public var animationNames(get, never):Array<String>;

	function get_animationNames():Array<String>
		return [for (a in animationList) a.name];

	/** Its animation named name, or null. */
	public function findAnimation(name:String):Null<SpriteAnimation2D> {
		for (a in animationList)
			if (a.name == name)
				return a;
		return null;
	}

	/** Adds an animation named name over its frames by index, played in direction, in place of one of that name. False, changing nothing, for no
		frames or an index it hasn't. */
	public function addAnimation(name:String, frames:Array<Int>, direction:AnimationDirection2D = Forward):Bool {
		if (frames.length == 0)
			return false;
		for (f in frames)
			if (f < 0 || f >= frameList.length)
				return false;
		var animation = new SpriteAnimation2D(name, frames.copy(), direction);
		for (i in 0...animationList.length)
			if (animationList[i].name == name) {
				animationList[i] = animation;
				return true;
			}
		animationList.push(animation);
		return true;
	}

	/** Frees what load loaded (its texture through Textures) and stops reading its file again; a sheet made from a texture leaves the texture to
		its maker. */
	public function destroy():Void {
		if (path == null)
			return;
		Assets.unsubscribe(path, this);
		Textures.release(texture);
		path = null;
	}

	/** Its file changed: its frames and animations are read again (its image reloads on its own). A file that doesn't read leaves it as it
		was, and throws. */
	public function reloaded(path:String, bytes:Bytes):Void {
		read(bytes.toString());
		reloadCount++;
	}

	// Reads its frames and animations from a file's text, in place of what it had: all of them, or (throwing, saying why) none.
	function read(text:String):Void {
		var file:Dynamic = try haxe.Json.parse(text) catch (e:Dynamic) throw 'not JSON: $e';
		if (file.frames == null)
			throw "not a sprite sheet: it has no frames";
		var entries:Array<{name:String, data:Dynamic}> = [];
		if (Std.isOfType(file.frames, Array)) {
			var list:Array<Dynamic> = file.frames;
			for (i in 0...list.length)
				entries.push({name: list[i].filename == null ? Std.string(i) : list[i].filename, data: list[i]});
		} else
			// A hash's order is the file's: Aseprite's tags count frames in it, and a parsed object's fields have no order on every target.
			for (name in frameKeys(text))
				entries.push({name: name, data: Reflect.field(file.frames, name)});
		var frames = [for (e in entries) frameOf(e.name, e.data)];
		var animations:Array<SpriteAnimation2D> = [];
		var tags:Array<Dynamic> = file.meta == null || file.meta.frameTags == null ? [] : file.meta.frameTags;
		for (tag in tags) {
			var from:Null<Int> = tag.from, to:Null<Int> = tag.to;
			if (tag.name == null || from == null || to == null || from < 0 || to >= frames.length || from > to)
				throw 'tag ${tag.name}: frames $from to $to of ${frames.length}';
			var direction = switch (tag.direction : Null<String>) {
				case "reverse": AnimationDirection2D.Reverse;
				case "pingpong": AnimationDirection2D.PingPong;
				case "pingpong_reverse": AnimationDirection2D.PingPongReverse;
				case _: AnimationDirection2D.Forward;
			}
			animations.push(new SpriteAnimation2D(tag.name, [for (f in from...to + 1) f], direction));
		}
		for (a in numbered(frames))
			if (!Lambda.exists(animations, b -> b.name == a.name))
				animations.push(a);
		frameList = frames;
		animationList = animations;
	}

	// One frame of a file: its rectangle (as drawn upright: TexturePacker writes a rotated frame's upright size), its trim, pivot and duration.
	function frameOf(name:String, data:Dynamic):SpriteFrame2D {
		var rect:Dynamic = data.frame;
		if (rect == null || rect.x == null || rect.y == null || rect.w == null || rect.h == null)
			throw 'frame $name has no rectangle';
		var w:Int = rect.w, h:Int = rect.h;
		var trim:Dynamic = data.spriteSourceSize,
			source:Dynamic = data.sourceSize,
			pivot:Dynamic = data.pivot;
		var offsetX = 0, offsetY = 0, sourceWidth = w, sourceHeight = h;
		if (trim != null && source != null) {
			offsetX = trim.x;
			offsetY = trim.y;
			sourceWidth = source.w;
			sourceHeight = source.h;
		}
		var duration:Null<Float> = data.duration;
		return new SpriteFrame2D(name, rect.x, rect.y, w, h, data.rotated == true, offsetX, offsetY, sourceWidth, sourceHeight,
			pivot == null ? Math.NaN : pivot.x, pivot == null ? Math.NaN : pivot.y, duration == null ? defaultDuration : duration / 1000);
	}

	// The animations of frames named alike but for a number ("run_01.png", "run_02.png": "run"), each in its numbers' order, in the order their
	// first frames come.
	static function numbered(frames:Array<SpriteFrame2D>):Array<SpriteAnimation2D> {
		var pattern = ~/^(.*?)[ _\-.\/]*([0-9]+)(\.[A-Za-z0-9]+)?$/;
		var names:Array<String> = [],
			members = new Map<String, Array<{index:Int, number:Int}>>();
		for (i in 0...frames.length)
			if (pattern.match(frames[i].name)) {
				var name = pattern.matched(1),
					number = Std.parseInt(pattern.matched(2));
				if (name == "")
					continue;
				if (!members.exists(name)) {
					names.push(name);
					members[name] = [];
				}
				members[name].push({index: i, number: number});
			}
		return [
			for (name in names) {
				var list = members[name];
				list.sort((a, b) -> a.number - b.number);
				new SpriteAnimation2D(name, [for (m in list) m.index], Forward);
			}
		];
	}

	// The keys of the file's "frames" object, in the order the text gives them: a scan of the JSON (already parsed, so well formed).
	static function frameKeys(text:String):Array<String> {
		var keys:Array<String> = [], depth = 0, i = 0, n = text.length, framesDepth = -1, lastString:Null<String> = null;
		while (i < n) {
			var c = StringTools.fastCodeAt(text, i);
			if (c == '"'.code) {
				var start = ++i;
				while (StringTools.fastCodeAt(text, i) != '"'.code)
					i += StringTools.fastCodeAt(text, i) == "\\".code ? 2 : 1;
				lastString = text.substring(start, i);
			} else if (c == ":".code) {
				if (lastString != null) {
					if (depth == framesDepth)
						keys.push(haxe.Json.parse('"$lastString"'));
					else if (depth == 1 && lastString == "frames")
						framesDepth = -2;
				}
			} else if (c == "{".code || c == "[".code) {
				depth++;
				if (framesDepth == -2)
					framesDepth = depth;
			} else if (c == "}".code || c == "]".code) {
				if (depth == framesDepth)
					break;
				depth--;
			} else if (c != " ".code && c != "\t".code && c != "\n".code && c != "\r".code && c != ",".code)
				framesDepth = framesDepth == -2 ? -1 : framesDepth;
			if (c != '"'.code)
				lastString = c == " ".code || c == "\t".code || c == "\n".code || c == "\r".code ? lastString : null;
			i++;
		}
		return keys;
	}
}
