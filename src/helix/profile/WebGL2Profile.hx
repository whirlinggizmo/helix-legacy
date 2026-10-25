package helix.profile;

import helix.adapter.audio.webaudio.WebAudioAdapter;
import helix.adapter.export.download.DownloadExportAdapter;
import helix.adapter.audiodecoder.webaudio.WebAudioDecoderAdapter;
import helix.adapter.http.fetchapi.FetchApiHttpAdapter;
import helix.adapter.graphics.webgl2.WebGL2GraphicsAdapter;
import helix.adapter.testharness.dom.DomTestHarnessAdapter;
import helix.adapter.host.dom.DomHostAdapter;
import helix.adapter.imagedecoder.canvas.CanvasImageDecoderAdapter;
import helix.adapter.inputsource.dom.DomInputSourceAdapter;
import helix.adapter.store.indexeddb.IndexedDbStoreAdapter;
import helix.hotreload.AppRouter;
import helix.host.Runner;

/** The browser on WebGL2 (the `webgl2` backend): the page's host and canvas, Web Audio, fetch, IndexedDB and the page's image decoder. */
@:noCompletion
class WebGL2Profile {
	/** Runs the app router reaches (its init once its services are bound) on the page's canvas, for identity: assets fetched from assetBase and cached in IndexedDB
		as "<company>/<product>", following the manifest tree from assetManifest under it when given ("manifest.json"; tools/gen_manifest.py), the canvas made as options ask (the defaults when not given). The tick option keeps the drawing buffer between
		frames, for checks that read it. */
	public static function run(identity:helix.host.Identity, assetBase:String, assetManifest:Null<String>, router:AppRouter,
			?options:helix.host.WindowOptions):Void {
		if (options == null)
			options = new helix.host.WindowOptions();
		helix.debug.Log.start(new helix.adapter.logoutput.console.ConsoleLogOutputAdapter());
		var host = new DomHostAdapter(),
			cacheName = identity.company + "/" + identity.product;
		var runner = new Runner(host, () -> {
			var graphics = new WebGL2GraphicsAdapter(host.canvas, host.getOption("tick") != null, options.msaaSamples);
			return {
				graphics: graphics,
				input: new DomInputSourceAdapter(host.canvas),
				audio: new WebAudioAdapter(),
				audioDecoder: new WebAudioDecoderAdapter(),
				images: new CanvasImageDecoderAdapter(),
				http: new FetchApiHttpAdapter(),
				storage: new IndexedDbStoreAdapter(cacheName),
				packaged: new IndexedDbStoreAdapter(cacheName + "-packaged"),
				saves: () -> new IndexedDbStoreAdapter(cacheName + "-saves"),
				base: assetBase,
				manifest: assetManifest,
				harness: new DomTestHarnessAdapter(),
				export: new DownloadExportAdapter(),
				name: identity.product
			};
		});
		#if hotreload new helix.adapter.host.dom.AssetWatcher(assetBase, path -> runner.assetChanged(path)); #end
		runner.run(router);
	}
}
