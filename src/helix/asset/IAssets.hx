package helix.asset;

import haxe.io.Bytes;
import helix.asset.StorageService.Lease;
import helix.asset.StorageWriteResult;
import helix.asset.AssetCacheMode;
import helix.asset.AssetProgress;
import helix.asset.EnsureOptions;

/** Where a streamed audio asset is read from: a leased local copy, which its holder releases; a remote URL, which the platform plays itself (a
	browser's media element); or a file still arriving from the host, read as it downloads (natively, where the output can't play a URL). */
@:noCompletion
enum AudioLocation {
	Stored(value:Lease);
	Remote(url:String);
	Downloading(source:GrowingSource);
}

/** The asset service games load through (AssetService): assets by relative path through the cache, streamed audio locations, and hot reload subscriptions. Completions run on the host thread. */
@:noCompletion
interface IAssets {
	/** Loads path's bytes as ensure does, without progress or options. */
	function load(path:String, loaded:Bytes->Void, ?failed:String->Void):IRequest;

	/** Loads path's bytes: downloaded from the host when one is set and kept in the cache, or else read from the packaged files in place. A
		cached copy is used only while it's current: when a manifest (setManifest) lists the file, while the copy has the manifest's hash (else
		the file is downloaded past HTTP caches and kept only if it has it); otherwise while the host's Cache-Control says it's fresh, and then
		after asking the host (its ETag and Last-Modified sent): 304 keeps it, 200 replaces it, 4xx deletes it, and no answer (offline, a 5xx)
		uses it. One of loaded or failed runs once on the host thread, and neither once the request is cancelled; failed (else the log, with
		the path) for an invalid path, a closed service, a missing asset, an HTTP status outside 200-299 with no copy to use, a download that
		doesn't match its manifest, or a storage or transport error. progress, if given, reports each phase until the request settles. */
	function ensure(path:String, loaded:Bytes->Void, ?failed:String->Void, ?progress:AssetProgress->Void, ?options:EnsureOptions):IRequest;

	/** What's put before each path to download it, ending in "/": a URL, or a directory relative to the page (the browser's "assets/"); null
		when files are read from the program's packaged files (natively, unless HELIX_ASSET_HOST names a host). */
	var host(get, never):Null<String>;

	/** Downloads from host from now on (a "/" is added if it has none), or reads the packaged files with null. The cache keeps each host's files
		apart. False for an empty host. */
	function setHost(host:Null<String>):Bool;

	/** Whether host answers: it serves probePath (an asset it should have) within timeoutSeconds. complete runs once, on the host thread. */
	@:noCompletion
	function pingHost(host:String, probePath:String, timeoutSeconds:Float, complete:Bool->Void):IRequest;

	/** The root manifest's path under the host ("manifest.json"), or null for none (the default). */
	@:noCompletion
	var manifest(get, never):Null<String>;

	/** Uses the manifest tree under the host from path (tools/gen_manifest.py writes one): the root asked about once a run (its cached copy
		used offline), a directory's manifest loaded only when an asset under it is, and again only when its hash changes; a file it lists is
		used from the cache with no request while the copy has its hash. A host without one, and a file none lists, are treated as the cache mode
		says (cacheMode); a file its directory's manifest leaves out is asked about however fresh, as it has changed or gone. Null for none. False for a path that isn't a valid asset path. */
	@:noCompletion
	function setManifest(path:Null<String>):Bool;

	/** How downloaded copies no manifest lists are treated (AssetCacheMode); Revalidate by default. */
	var cacheMode(get, set):AssetCacheMode;

	/** Forgets every downloaded file, so the next load downloads it again, and what was read of the manifests, so the root is asked about
		again. complete runs once, on the host thread. */
	function clearCache(complete:StorageWriteResult->Void):IRequest;

	/** Locates path for streaming without loading it whole: a leased cached copy while it's current (as ensure says, without asking the host),
		else the remote URL (a base URL is set) or a leased packaged copy. With download (an output that can't play a URL, natively), a file
		that must come from the host is downloaded instead, as ensure would (a stale copy asked about: 304 leases it), and answered as
		Downloading as soon as its first part arrives with a 200 and a Content-Length, so it plays while it arrives; without a Content-Length
		it's answered once whole (a source already done). The download goes on after the answer, and when it ends the file is kept in the cache
		as ensure keeps one, so the next play is local; a download that fails after the answer is logged with the path and ends its source
		(GrowingSource.failure). One of located or failed runs once on the host thread, and neither once the request is cancelled; the caller
		releases a Stored lease, and one that arrives after cancellation is released for it. failed (else the log, with the path) for an
		invalid path, a closed service, a missing packaged asset, a storage error, or, downloading, what fails ensure. */
	@:noCompletion
	function streamSource(path:String, located:AudioLocation->Void, ?failed:String->Void, download:Bool = false):IRequest;

	/** Tells target each time path's file changes while the game runs in the dev loop: the file is loaded again and target.reloaded gets
		its new bytes. That's how a game reloads its own files, such as a level or a JSON of tuning values, the way HeliX reloads textures
		and sounds. Load the file as usual first; subscribing doesn't load it. Outside the dev loop nothing changes, so it's never called.
		A target is told once per change however often it subscribed. For example, a class implementing IReloadable calls
		`Assets.subscribe("tuning.json", this)` and reads the bytes in its `reloaded`. */
	function subscribe(path:String, target:IReloadable):Void;

	/** Stops telling target about path's changes. Does nothing if it wasn't subscribed. */
	function unsubscribe(path:String, target:IReloadable):Void;

	/** Whether a load is under way or its completion not yet run (Host.busy asks it, with the decoders). */
	var busy(get, never):Bool;
}
