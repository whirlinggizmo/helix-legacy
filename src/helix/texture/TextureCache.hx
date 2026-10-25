package helix.texture;

import haxe.io.Bytes;
import helix.asset.Failure;
import helix.asset.IAssets;
import helix.asset.IReloadable;
import helix.asset.IRequest;
import helix.asset.Request;
import helix.graphics.IGraphics;
import helix.graphics.ImageDecoding;
import helix.texture.Sampling;
import helix.texture.TextureFormat;

/** Textures from image files (PNG, JPEG, BMP, TGA, GIF) and compressed ones (KTX 1: BC7, ASTC 4x4, ETC2 RGBA8): loaded through the assets,
	decoded off the frame, uploaded, and replaced in place when a file changes during development. A path "name.ktx" picks the file this GPU
	can sample: name.bc7.ktx, name.astc.ktx or name.etc2.ktx, the first it can and that loads, else name.png (made beforehand, each with its
	mipmaps, by a texture compressor; keep the PNG). The runner's is what the Textures static forwards to; the caller releases what it loads. */
@:build(helix.macro.Facade.record())
@:noCompletion
class TextureCache implements IReloadable {
	static var VARIANTS:Array<{suffix:String, format:TextureFormat}> = [
		{suffix: ".bc7.ktx", format: Bc7},
		{suffix: ".astc.ktx", format: Astc4x4},
		{suffix: ".etc2.ktx", format: Etc2Rgba8}
	];

	var assets:IAssets;
	var images:ImageDecoding;
	var gpu:IGraphics;
	var live = true;
	// Textures loaded: each the file it came from, what it was asked for by (the path and filter: loads of both alike share it), whether it
	// has mipmaps, and how many loads hold it.
	var entries:Array<{
		path:String,
		key:String,
		texture:Texture2D,
		mipmaps:Bool,
		users:Int
	}> = [];
	// Loads under way, by what they were asked for: those waiting on each.
	var pending = new Map<String, {request:IRequest, waiting:Array<{request:Request, loaded:Texture2D->Void, failed:Null<String->Void>}>}>();

	/** Loads through assets, decodes with images (shared, polled by its owner) and uploads to gpu; shutdown shuts nothing down but this service. */
	public function new(assets:IAssets, images:ImageDecoding, gpu:IGraphics) {
		this.assets = assets;
		this.images = images;
		this.gpu = gpu;
	}

	/** The files path loads from, in order, the first that loads winning: a "name.ktx" this GPU's compressed variants then name.png; any other
		path itself. */
	public function getCandidates(path:String):Array<String> {
		if (!StringTools.endsWith(path, ".ktx"))
			return [path];
		for (variant in VARIANTS)
			if (StringTools.endsWith(path, variant.suffix))
				return [path];
		var base = path.substr(0, path.length - 4);
		return [
			for (variant in VARIANTS)
				if (gpu.canSample(variant.format)) base + variant.suffix
		].concat([base + ".png"]);
	}

	/** The file texture was loaded from (for a "name.ktx", the one chosen), or null for one this service didn't load. */
	public function getPath(texture:Texture2D):Null<String> {
		for (entry in entries)
			if (entry.texture == texture)
				return entry.path;
		return null;
	}

	/** Loads path into a texture filtered by filter: Linear samples it smoothly, with mipmaps so it can be drawn smaller without shimmering;
		Nearest sharp, for pixel art (Texture2D.sampling changes it later). A "name.ktx" loads this GPU's variant or else name.png (getCandidates). Loads of the
		same path and filter share one texture (a load under way is joined, not started again), so its sampling is theirs together; each load
		releases it once (release), and the last frees it. One of loaded or failed runs once on the host thread, and neither once the request
		is cancelled; failed (else the log, with the path) for a closed service, or when no candidate loads and decodes. */
	public function load(path:String, filter:Filter, loaded:Texture2D->Void, ?failed:String->Void):IRequest {
		var key = Std.string(filter) + ":" + path, request:Request = null, waiter = null;
		request = new Request(() -> {
			// One load giving up: the shared one goes on while another still waits.
			var shared = pending[key];
			if (shared != null) {
				shared.waiting.remove(waiter);
				if (shared.waiting.length == 0) {
					pending.remove(key);
					shared.request.cancel();
				}
			}
		});
		waiter = {request: request, loaded: loaded, failed: failed};
		if (!live) {
			request.finish();
			Failure.report(path, "Closed texture service", failed);
			return request;
		}
		for (entry in entries)
			if (entry.key == key) {
				entry.users++;
				request.finish();
				loaded(entry.texture);
				return request;
			}
		var shared = pending[key];
		if (shared != null) {
			shared.waiting.push(waiter);
			return request;
		}
		shared = {request: null, waiting: [waiter]};
		pending[key] = shared;
		shared.request = fetch(path, filter, (file, texture, message) -> {
			if (pending[key] != shared)
				return;
			pending.remove(key);
			if (texture != null) {
				entries.push({
					path: file,
					key: key,
					texture: texture,
					mipmaps: filter == Linear && texture.format == Rgba8,
					users: shared.waiting.length
				});
				assets.subscribe(file, this);
			}
			for (w in shared.waiting)
				if (w.request.finish())
					if (texture != null)
						w.loaded(texture);
					else
						Failure.report(path, message, w.failed);
		});
		return request;
	}

	// Loads path's first candidate that loads and decodes into a new texture; done gets the file it came from and the texture, or why none
	// did. Cancelled, it gives up silently.
	function fetch(path:String, filter:Filter, done:(String, Null<Texture2D>, Null<String>) -> Void):IRequest {
		var child:IRequest = null, request:Request = null;
		request = new Request(() -> if (child != null) child.cancel());
		var candidates = getCandidates(path), errors = [];
		function next():Void {
			if (candidates.length == 0) {
				if (request.finish())
					done(path, null, errors.join("; "));
				return;
			}
			var file = candidates.shift();
			function fail(message:String):Void {
				errors.push('$file: $message');
				next();
			}
			// A load that ends during the call may have set child to its decode already.
			child = null;
			var loading = assets.load(file, bytes -> {
				if (request.settled)
					return;
				if (StringTools.endsWith(file, ".ktx")) {
					var texture = try fromKtx(bytes, filter) catch (e:Dynamic) {
						fail(Std.string(e));
						return;
					}
					if (request.finish())
						done(file, texture, null);
					else
						texture.destroy(gpu);
					return;
				}
				child = images.decode(bytes, decoded -> switch decoded {
					case Decoded(width, height, rgba):
						if (request.finish()) done(file, Texture2D.fromRgba(width, height, rgba, filter, -1, -1, filter == Linear, gpu), null);
					case Failed(message):
						if (!request.settled) fail(message);
					case Cancelled:
				});
			}, message -> if (!request.settled) fail(message));
			if (child == null)
				child = loading;
		}
		next();
		return request;
	}

	function fromKtx(bytes:Bytes, filter:Filter):Texture2D {
		var ktx = Ktx.read(bytes);
		if (!gpu.canSample(ktx.format))
			throw "This GPU can't sample its format";
		return Texture2D.fromLevels(ktx.width, ktx.height, ktx.levels, ktx.format, new Sampling(filter), gpu);
	}

	/** Decodes encoded image bytes (a file's contents already in memory, such as a model's embedded image) into a texture, as load does but
		with nothing to reload: the caller owns the texture and destroys it. One of decoded or failed runs once on the host thread, and neither
		once the request is cancelled; failed (else the log) for a closed service or bytes that don't decode. */
	public function decode(encoded:Bytes, filter:Filter, decoded:Texture2D->Void, ?failed:String->Void):IRequest {
		var child:IRequest = null, request:Request = null;
		request = new Request(() -> if (child != null) child.cancel());
		if (!live) {
			request.finish();
			Failure.report("an image in memory", "Closed texture service", failed);
			return request;
		}
		child = images.decode(encoded, result -> switch result {
			case Decoded(width, height, rgba):
				if (request.finish()) decoded(Texture2D.fromRgba(width, height, rgba, filter, -1, -1, filter == Linear, gpu));
			case Failed(message):
				if (request.finish()) Failure.report("an image in memory", message, failed);
			case Cancelled:
		});
		return request;
	}

	/** Lets go of a texture this service loaded, once for each load that gave it: the last release frees it and stops reloading it. */
	public function release(texture:Texture2D):Void
		for (entry in entries.copy())
			if (entry.texture == texture) {
				if (--entry.users > 0)
					return;
				entries.remove(entry);
				texture.destroy(gpu);
				if (!Lambda.exists(entries, e -> e.path == entry.path))
					assets.unsubscribe(entry.path, this);
				return;
			}

	/** The file behind loaded textures changed: they're read and uploaded again, keeping their Texture2D objects and sampling, so what draws them
		shows the new image. A file that no longer reads leaves them as they were. */
	public function reloaded(path:String, bytes:Bytes):Void {
		if (StringTools.endsWith(path, ".ktx")) {
			var ktx = try Ktx.read(bytes) catch (e:Dynamic) return;
			if (!gpu.canSample(ktx.format))
				return;
			for (entry in entries)
				if (entry.path == path)
					@:privateAccess entry.texture.replace(gpu, ktx.width, ktx.height, ktx.levels, ktx.format);
			return;
		}
		images.decode(bytes, decoded -> switch decoded {
			case Decoded(width, height, rgba):
				for (entry in entries)
					if (entry.path == path)
						@:privateAccess entry.texture.replace(gpu, width, height, entry.mipmaps ? helix.texture.Mipmaps.build(width, height, rgba) : [rgba],
							Rgba8);
			case _:
		});
	}

	/** Refuses new loads; the textures already loaded stay until released. */
	public function shutdown():Void
		live = false;
}
