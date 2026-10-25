package helix.profile;

import helix.adapter.audiodecoder.libsndfile.LibsndfileAudioDecoderAdapter;
import helix.adapter.audiodecoder.libsndfile.LibsndfilePcmFiles;
import helix.adapter.audio.sdl3.Sdl3AudioAdapter;
import helix.adapter.http.haxehttp.HaxeHttpAdapter;
import helix.adapter.graphics.sdl3gpu.Sdl3GpuGraphicsAdapter;
import helix.adapter.testharness.stdio.StdioTestHarnessAdapter;
import helix.adapter.host.sdl3.Sdl3HostAdapter;
import helix.adapter.imagedecoder.stb.StbImageDecoderAdapter;
import helix.adapter.inputsource.sdl3.Sdl3InputSourceAdapter;
import helix.adapter.export.filesystem.FileSystemExportAdapter;
import helix.adapter.store.filesystem.FileSystemStoreAdapter;
import helix.hotreload.AppRouter;
import helix.host.Runner;

/** The desktop through SDL3, drawing with SDL_GPU (the `sdl3-gpu` backend): an SDL window, its input and gamepads, SDL_GPU (Vulkan, Direct3D 12 or Metal) presenting to it; built with -D helix_sdl3_gpu, so the
	framework's programs carry SDL_GPU's dialects; an SDL audio stream with libsndfile, haxe.Http and files, stb_image. */
@:noCompletion
class Sdl3GpuProfile {
	/** Runs the app router reaches (its init once its services are bound) for identity: assets from HELIX_ASSET_HOST when set (following the manifest tree from HELIX_ASSET_MANIFEST under it when that's set too,
		"manifest.json"), else from assetDirectory, a directory relative to the program's (a game's own: "assets", beside it);
		downloads cached in HELIX_CACHE, else the user's cache directory for identity (FileSystemStoreAdapter.getCacheDirectory), else cache/ beside the
		program; saves in HELIX_SAVES, else the user's data directory for identity (FileSystemStoreAdapter.getDataDirectory), else saves/ beside
		the program; files made for the user (screenshots) in HELIX_EXPORT, else the user's pictures directory for the product
		(FileSystemExportAdapter.getPicturesDirectory), else exports/ beside the program. The window opens as options ask (the defaults when not given). Returns when the window closes. */
	public static function run(identity:helix.host.Identity, assetDirectory:String, router:AppRouter, ?options:helix.host.WindowOptions):Void {
		helix.debug.Log.start(new helix.adapter.logoutput.stdio.StdioLogOutputAdapter());
		var host = new Sdl3HostAdapter(options != null ? options.msaaSamples : new helix.host.WindowOptions().msaaSamples, false);
		var runner = new Runner(host, () -> {
			var root = haxe.io.Path.directory(Sys.programPath()), cache = Sys.getEnv("HELIX_CACHE");
			if (cache == null)
				cache = FileSystemStoreAdapter.getCacheDirectory(identity.company, identity.product);
			if (cache == null)
				cache = haxe.io.Path.join([root, "cache"]);
			var exports = Sys.getEnv("HELIX_EXPORT");
			if (exports == null)
				exports = FileSystemExportAdapter.getPicturesDirectory(identity.product);
			if (exports == null)
				exports = haxe.io.Path.join([root, "exports"]);
			return {
				graphics: new Sdl3GpuGraphicsAdapter(),
				input: new Sdl3InputSourceAdapter(),
				audio: new Sdl3AudioAdapter(new LibsndfilePcmFiles()),
				audioDecoder: new LibsndfileAudioDecoderAdapter(),
				images: new StbImageDecoderAdapter(),
				http: new HaxeHttpAdapter(),
				storage: new FileSystemStoreAdapter(cache),
				packaged: new FileSystemStoreAdapter(haxe.io.Path.normalize(haxe.io.Path.join([root, assetDirectory]))),
				saves: () -> {
					var saves = Sys.getEnv("HELIX_SAVES");
					if (saves == null)
						saves = FileSystemStoreAdapter.getDataDirectory(identity.company, identity.product);
					new FileSystemStoreAdapter(saves == null ? haxe.io.Path.join([root, "saves"]) : saves);
				},
				base: Sys.getEnv("HELIX_ASSET_HOST"),
				manifest: Sys.getEnv("HELIX_ASSET_MANIFEST"),
				harness: new StdioTestHarnessAdapter(),
				export: new FileSystemExportAdapter(exports),
				name: identity.product
			};
		});
		runner.run(router);
	}
}
