package helix.graphics;

import helix.debug.Log;
import haxe.io.Bytes;
import helix.asset.Failure;
import helix.asset.IAssets;
import helix.asset.IReloadable;
import helix.asset.IRequest;
import helix.asset.Request;

/** Apps' shaders (.hxshader files, packed from GLSL by src/helix/tool/shader/ShaderPacker.hx; how one is written: docs/SHADERS.md) loaded through the assets and built on the GPU, and built again in
	place when a file changes during development. The caller releases what it loads. */
class Shaders implements IReloadable {
	// What it was given, or null for the program's, read when used.
	var givenAssets:Null<IAssets>;
	var givenGpu:Null<IGraphics>;
	var assets(get, never):IAssets;
	var gpu(get, never):IGraphics;

	function get_assets():IAssets
		return givenAssets != null ? givenAssets : helix.asset.Assets.instance;

	function get_gpu():IGraphics
		return givenGpu != null ? givenGpu : Graphics.instance;

	var entries:Array<{path:String, shader:Shader}> = [];

	/** Loads through assets and builds on gpu: the program's (Assets, Graphics) for those not given, read as they're used, so a cache made
		before the program runs (a field's initial value) works. */
	public function new(?assets:IAssets, ?gpu:IGraphics) {
		givenAssets = assets;
		givenGpu = gpu;
	}

	/** Loads path (a .hxshader) into a shader. One of loaded or failed runs once on the host thread, and neither once the request is
		cancelled: loaded once its program is built; failed (else the log, with the path) for a load failure, a file it can't read or a program
		that doesn't build (with the compiler's log). */
	public function load(path:String, loaded:Shader->Void, ?failed:String->Void):IRequest {
		var loading:IRequest = null, request:Request = null;
		request = new Request(() -> if (loading != null) loading.cancel());
		loading = assets.load(path, bytes -> {
			if (request.settled)
				return;
			var shader = try Shader.fromText(bytes.toString(), gpu) catch (e:Dynamic) {
				if (request.finish())
					Failure.report(path, '$path: $e', failed);
				return;
			}
			if (!request.finish()) {
				shader.destroy();
				return;
			}
			entries.push({path: path, shader: shader});
			assets.subscribe(path, this);
			loaded(shader);
		},
			message -> if (request.finish()) Failure.report(path, Failure.named(path, message), failed));
		return request;
	}

	/** Frees a shader this service loaded (after the pipelines made with it), and stops reloading it. */
	public function release(shader:Shader):Void
		for (entry in entries.copy())
			if (entry.shader == shader) {
				entries.remove(entry);
				shader.destroy();
				if (!Lambda.exists(entries, e -> e.path == entry.path))
					assets.unsubscribe(entry.path, this);
			}

	/** The file behind loaded shaders changed: they're built again in place. One that no longer builds stays as it was, its log logged as an error. */
	public function reloaded(path:String, bytes:Bytes):Void
		for (entry in entries)
			if (entry.path == path)
				try
					@:privateAccess entry.shader.replace(bytes.toString())
				catch (e:Dynamic)
					Log.error('$path: $e', "shader");
}
