package helix.render3d;

import helix.asset.Failure;
import helix.asset.IAssets;
import helix.asset.IRequest;
import helix.asset.Request;
import helix.texture.TextureCache;
import helix.render3d.ImageSource3D;

/** Model files (glTF 2.0, GLB or .gltf) loaded through the assets into ModelFiles: the file read with the buffers it keeps beside it, its images
	decoded or loaded into textures (base color decoded from sRGB, normal maps read as they are), then complete. All of it Haxe, the same on every target; images decode
	through a TextureCache. A file loads once and is shared: a path asked for again is the file already loaded (or its failure, remembered), and asking
	while it loads joins the load. Each caller instantiates its own copy of the file's nodes, so copies share meshes, materials and textures. The runner's is what the Models3D static forwards to. */
@:build(helix.macro.Facade.record())
@:noCompletion
class ModelCache3D {
	var assets:IAssets;
	var textures:TextureCache;
	var files:Map<String, ModelFile3D> = [];
	var failures:Map<String, String> = [];
	var waiting:Map<String, Array<{request:Request, loaded:ModelFile3D->Void, failed:Null<String->Void>}>> = [];
	var loads:Map<String, IRequest> = [];

	/** Loads through assets, decoding images with textures. */
	public function new(assets:IAssets, textures:TextureCache) {
		this.assets = assets;
		this.textures = textures;
	}

	/** Loads path (a .glb or .gltf) into a ModelFile3D: the file, then any buffers it keeps in files beside it, then its images (decoded from the
		file, or loaded from files beside it through the textures, which reload them when they change). One of loaded or failed runs once: during
		this call when the file is loaded already (or failed before; forget clears a failure), else on the host thread when its load ends: loaded
		once its images are in (one that fails leaves its material untextured, with a warning), failed (else the log, with the path) for a load
		failure, a buffer that won't load, or a file it can't read. Neither runs once the request is cancelled (the shared load goes on for the
		others) or the service shuts down. */
	public function load(path:String, loaded:ModelFile3D->Void, ?failed:String->Void):IRequest {
		var settled = new Request(() -> {});
		if (files.exists(path)) {
			settled.finish();
			loaded(files[path]);
			return settled;
		}
		if (failures.exists(path)) {
			settled.finish();
			Failure.report(path, failures[path], failed);
			return settled;
		}
		var request:Request = null;
		request = new Request(() -> {
			var callers = waiting[path];
			if (callers != null)
				for (caller in callers.copy())
					if (caller.request == request)
						callers.remove(caller);
		});
		var caller = {request: request, loaded: loaded, failed: failed};
		if (waiting.exists(path)) {
			waiting[path].push(caller);
			return request;
		}
		waiting[path] = [caller];
		loads[path] = read(path, (file, message) -> {
			loads.remove(path);
			if (file != null)
				files[path] = file;
			else if (message != null)
				failures[path] = message;
			var callers = waiting[path];
			waiting.remove(path);
			if (callers != null)
				for (caller in callers)
					if (caller.request.finish())
						if (file != null)
							caller.loaded(file);
						else if (message != null)
							Failure.report(path, message, caller.failed);
		});
		return request;
	}

	/** The file at path if it's loaded, else null. */
	public function find(path:String):Null<ModelFile3D>
		return files[path];

	/** Whether path is loaded. */
	public function isLoaded(path:String):Bool
		return files.exists(path);

	/** Whether path is loading. */
	public function isLoading(path:String):Bool
		return waiting.exists(path);

	/** How many files are loading. */
	public var loadingCount(get, never):Int;

	function get_loadingCount():Int {
		var n = 0;
		for (_ in waiting)
			n++;
		return n;
	}

	/** Adds a file loaded some other way under path, as if loaded from there (a test's, a generated one). */
	public function put(path:String, file:ModelFile3D):Void {
		files[path] = file;
		failures.remove(path);
	}

	/** Forgets path: its file (the copies instantiated from it stay) or its failure, so it's loaded again when next asked for. */
	public function forget(path:String):Void {
		files.remove(path);
		failures.remove(path);
	}

	/** Cancels every load (telling none of its callers) and forgets every file. */
	public function shutdown():Void {
		for (load in [for (l in loads) l])
			load.cancel();
		files.clear();
		failures.clear();
	}

	// One load of path, unshared: the file, its buffers, its images. done gets the file, or else why it failed, or neither when it was cancelled.
	function read(path:String, done:(Null<ModelFile3D>, Null<String>) -> Void):IRequest {
		var children:Array<IRequest> = [], request:Request = null;
		request = new Request(() -> {
			for (child in children)
				child.cancel();
			done(null, null);
		});
		function failed(message:String):Void
			if (request.finish())
				done(null, Failure.named(path, message));
		children.push(assets.load(path, bytes -> {
			if (request.settled)
				return;
			var gltf = try Gltf.read(bytes) catch (e:Dynamic) {
				failed(Std.string(e));
				return;
			}
			var missing = gltf.missingBuffers, waiting = missing.length;
			if (waiting == 0)
				build(path, gltf, request, children, done);
			for (buffer in missing) {
				var file = helix.asset.AssetPath.resolve(path, buffer.uri);
				if (file == null) {
					failed('buffer ${buffer.index}\'s uri ${buffer.uri} isn\'t a file beside the model');
					return;
				}
				children.push(assets.load(file, data -> {
					if (request.settled)
						return;
					if (!gltf.setBuffer(buffer.index, data)) {
						failed('$file is shorter than buffer ${buffer.index}\'s byteLength');
						return;
					}
					if (--waiting == 0)
						build(path, gltf, request, children, done);
				}, message -> failed(Failure.named(file, message))));
			}
		}, message -> failed(message)));
		return request;
	}

	// The file read, its buffers all in: the ModelFile3D, then its images.
	function build(path:String, gltf:Gltf, request:Request, children:Array<IRequest>, done:(Null<ModelFile3D>, Null<String>) -> Void):Void {
		var file = try new ModelFile3D(gltf) catch (e:Dynamic) {
			if (request.finish())
				done(null, '$path: $e');
			return;
		}
		var images = file.images(), waiting = images.length;
		if (waiting == 0) {
			if (request.finish())
				done(file, null);
			return;
		}
		for (image in images) {
			function next():Void {
				waiting--;
				if (waiting == 0 && request.finish())
					done(file, null);
			}
			function loaded(texture:helix.texture.Texture2D):Void {
				texture.sampling = image.sampling;
				for (set in image.set)
					set(texture);
				next();
			}
			function failed(message:String):Void {
				@:privateAccess file.warn('an image failed to load: $message');
				next();
			}
			var filter = image.sampling.filter;
			switch image.source {
				case InView(view):
					children.push(textures.decode(gltf.viewBytes(view), filter, texture -> loaded(texture), message -> failed(message)));
				case Inline(bytes):
					children.push(textures.decode(bytes, filter, texture -> loaded(texture), message -> failed(message)));
				case File(uri):
					var resolved = helix.asset.AssetPath.resolve(path, uri);
					if (resolved == null)
						failed('its uri $uri isn\'t a file beside the model');
					else
						children.push(textures.load(resolved, filter, texture -> loaded(texture), message -> failed(message)));
			}
		}
	}
}
