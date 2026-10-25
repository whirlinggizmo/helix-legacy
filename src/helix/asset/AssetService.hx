package helix.asset;

import helix.debug.Log;
import helix.core.WorkQueue;
import helix.asset.IAssets;
import helix.asset.AssetCacheMode;
import helix.asset.AssetProgress;
import helix.asset.EnsureOptions;
import helix.asset.StorageService;
import helix.asset.StorageResult;
import helix.asset.StorageWriteResult;
import helix.asset.StorageSourceResult;
import helix.asset.FetchService;
import helix.asset.FetchResult;
import helix.asset.AssetManifest;

/** How obtain treats a cached copy: Revalidate uses a fresh one and asks about a stale one; Ask always asks; Force downloads past it. */
private enum Obtain {
	Revalidate;
	Ask;
	Force;
}

/** How a step of a load ended, inside the service: the bytes, a failure, or a cancellation (from a store or the fetcher shutting down), which
	ends the load telling no one. */
private enum Outcome {
	Loaded(bytes:haxe.io.Bytes);
	Failed(message:String);
	Cancelled;
}

/** One load's state: its request, the step it waits on (cancelled with it), how it ends and how it reports progress. */
private class Attempt {
	/** The load's request. */
	public final request:Request;

	/** The step the load waits on, cancelled with the request. */
	public var child:Null<IRequest> = null;

	/** Ends the load. */
	public final finish:Outcome->Void;

	/** Reports a phase of it. */
	public final report:(String, Int, Null<Int>) -> Void;

	/** A load of request, ending with finish and reporting through report. */
	public function new(request:Request, finish:Outcome->Void, report:(String, Int, Null<Int>) -> Void) {
		this.request = request;
		this.finish = finish;
		this.report = report;
	}

	/** Whether the load has ended (or was cancelled). */
	public function settled():Bool
		return request.settled;
}

/** Asset identity/cache policy stays shared. No target conditionals. */
@:noCompletion
class AssetService implements IAssets {
	// A streamed download's limits (streamSource's download): a file is played as it arrives, so a slow connection takes the time it takes.
	static inline var STREAM_MAX_BYTES = 256 * 1024 * 1024;
	static inline var STREAM_TIMEOUT = 600.;

	var fetcher:FetchService;
	var cache:StorageService;
	var packaged:StorageService;
	var base:Null<String>;
	var queue = new WorkQueue();
	var live = true;
	var requests:Array<IRequest> = [];
	var subscribers:Map<String, Array<IReloadable>> = [];
	// Each directory's manifest this run, by its path ("" the root's; null when there's none), and the loads waiting for one.
	var manifests:Map<String, Null<AssetManifest>> = [];
	var waiting:Map<String, Array<Null<AssetManifest>->Void>> = [];
	// With the cache Off, this run's downloads, by key: nothing persists, but a file loads once a run.
	var session:Map<String, haxe.io.Bytes> = [];

	/** Loads through fetcher when base (the URL put before each path) is set, or else from the read-only packaged store, keeping each asset in cache under a key of base and path. It polls and shuts down all three. */
	public function new(fetcher:FetchService, cache:StorageService, packaged:StorageService, base:Null<String>) {
		this.fetcher = fetcher;
		this.cache = cache;
		this.packaged = packaged;
		this.base = base;
	}

	public function load(path:String, loaded:haxe.io.Bytes->Void, ?failed:String->Void):IRequest
		return ensure(path, loaded, failed);

	public function ensure(path:String, loaded:haxe.io.Bytes->Void, ?failed:String->Void, ?progress:AssetProgress->Void, ?options:EnsureOptions):IRequest {
		var source = options != null && options.source != null ? options.source : path,
			force = options != null && options.forceFetch == true;
		function complete(result:Outcome):Void
			switch result {
				case Loaded(bytes):
					loaded(bytes);
				case Failed(message):
					Failure.report(path, message, failed);
				case Cancelled:
			}
		var attempt:Attempt = null, request:Request = null;
		request = new Request(() -> {
			if (attempt.child != null)
				attempt.child.cancel();
			requests.remove(request);
		});
		attempt = new Attempt(request, result -> if (request.finish()) {
			requests.remove(request);
			queue.add(() -> complete(result));
		},
			(phase, received, total) -> if (progress != null && !request.settled) progress({phase: phase, receivedBytes: received, totalBytes: total}));
		requests.push(request);
		queue.add(() -> {
			if (request.settled)
				return;
			if (!live || !AssetPath.isValid(path)) {
				attempt.finish(Failed("Invalid asset path or closed service"));
				return;
			}
			attempt.report("locating", 0, null);
			if (base == null) {
				attempt.child = packaged.read(source, result -> {
					if (request.settled)
						return;
					switch result {
						// The packaged files are already on this machine: read in place, not copied into the cache, unless they're
						// another path's bytes (options.source), which have to be found under the path asked for.
						case Stored(bytes):
							if (source != path) store(path, bytes, [], AssetManifest.hash(bytes), attempt, attempt.finish); else {
								attempt.report("ready", bytes.length, bytes.length);
								attempt.finish(Loaded(bytes));
							}
						case Missing: attempt.finish(Failed("Missing asset: " + source));
						case Failed(message): attempt.finish(Failed(message));
						case Cancelled: attempt.finish(Cancelled);
					}
				});
				return;
			}
			var url = source.indexOf("://") > 0 ? source : base + source;
			if (force)
				obtain(path, url, null, Force, attempt, attempt.finish);
			else if (source != path)
				obtain(path, url, null, Revalidate, attempt, attempt.finish);
			else
				hashOf(path, (expected, unlisted) -> if (!request.settled) obtain(path, url, expected, unlisted ? Ask : Revalidate, attempt, attempt.finish));
		});
		return request;
	}

	// The cache key of path's bytes, and of their record.
	function key(path:String):String
		return haxe.crypto.Sha256.encode((base == null ? "packaged" : base) + "\n" + path);

	function recordKey(path:String):String
		return key(path) + ".meta";

	static function now():Float
		return Date.now().getTime() / 1000;

	/** path's bytes from url, kept in the cache. expected is a manifest's hash for them, or null when none lists them: a copy with that hash is
		used with no request, and anything else is downloaded past HTTP caches and kept only if it has that hash. Unlisted, a fresh copy is used
		with no request, and a stale one is asked about (its ETag and Last-Modified sent): 304 keeps it, 200 replaces it, 4xx deletes it, and no
		answer (offline, a 5xx) uses it. Ask always asks (a manifest's root once a run, and a file its directory's manifest leaves out); Force
		downloads past every cache. */
	function obtain(path:String, url:String, expected:Null<String>, mode:Obtain, attempt:Attempt, done:Outcome->Void):Void {
		if (mode == Force || cacheMode == Off) {
			if (mode != Force && session.exists(key(path)))
				copy(path, attempt, done, () -> {});
			else
				download(path, url, expected, null, mode, attempt, done);
			return;
		}
		attempt.child = cache.read(recordKey(path), result -> {
			if (attempt.settled())
				return;
			var record = switch result {
				case Stored(bytes): CacheRecords.parse(bytes);
				case Cancelled:
					done(Cancelled);
					return;
				case _: null;
			}
			// A copy brought from elsewhere (ensure's source) is asked about there, not at the path, where the host has nothing.
			var from = url, how = mode;
			if (record != null && record.source != null && expected == null && url == base + path) {
				from = record.source;
				how = Revalidate;
			}
			function fetch()
				download(path, from, expected, expected == null ? record : null, how, attempt, done);
			if (expected != null ? record != null && record.hash == expected : how == Revalidate
				&& (cacheMode == Trust || record != null && now() < record.freshUntil))
				copy(path, attempt, done, fetch);
			else
				fetch();
		});
	}

	// Downloads path from url, conditionally when record is the copy's; the answer decides (obtain).
	function download(path:String, url:String, expected:Null<String>, record:Null<CacheRecord>, mode:Obtain, attempt:Attempt, done:Outcome->Void):Void {
		var headers:Map<String, String> = [];
		if (record != null && record.etag != null)
			headers["If-None-Match"] = record.etag;
		if (record != null && record.lastModified != null)
			headers["If-Modified-Since"] = record.lastModified;
		// No answer: the copy, unless the download had to go past it.
		function unanswered(message:String)
			if (mode == Force)
				done(Failed(message));
			else
				copy(path, attempt, done, () -> done(Failed(message)));
		attempt.child = fetcher.fetch({url: url, noCache: expected != null || mode != Revalidate || record != null, headers: headers}, result -> {
			if (attempt.settled())
				return;
			switch result {
				case Response(value):
					if (value.status == 304 && record != null) copy(path, attempt, done, () -> download(path, url, expected, null, Force, attempt, done),
						() -> renew(path, record, value.headers)); else if (value.status >= 200 && value.status < 300) {
						var hash = AssetManifest.hash(value.bytes);
						if (expected != null && hash != expected)
							done(Failed('Asset does not match its manifest (a deploy still arriving?): $path'));
						else
							store(path, value.bytes, value.headers, hash, attempt, done, url == base + path ? null : url);
					} else if (value.status >= 400 && value.status < 500) {
						// The host says it's gone: so is the copy.
						forget(path);
						done(Failed('Asset HTTP ${value.status}: $path'));
					} else unanswered('Asset HTTP ${value.status}: $path');
				case Failed(message): unanswered(message);
				case Cancelled: done(Cancelled);
			}
		}, value -> attempt.report("downloading", value.receivedBytes, value.totalBytes));
	}

	// Keeps record fresh again from a 304's headers, their validators where they give new ones.
	function renew(path:String, record:CacheRecord, headers:Map<String, String>):Void {
		var renewed = CacheRecords.of(headers, record.hash, now());
		cache.write(recordKey(path), CacheRecords.encode({
			etag: renewed.etag != null ? renewed.etag : record.etag,
			lastModified: renewed.lastModified != null ? renewed.lastModified : record.lastModified,
			freshUntil: renewed.freshUntil,
			hash: record.hash,
			source: record.source
		}), _ -> {});
	}

	// Removes path's copy and its record (this run's, with the cache Off): the host says it's gone.
	function forget(path:String):Void
		if (cacheMode == Off)
			session.remove(key(path));
		else {
			cache.remove(key(path), _ -> {});
			cache.remove(recordKey(path), _ -> {});
		}

	// The cached copy of path (this run's, with the cache Off), or missing() when there's none; kept() once it's read.
	function copy(path:String, attempt:Attempt, done:Outcome->Void, missing:Void->Void, ?kept:Void->Void):Void {
		if (cacheMode == Off) {
			var bytes = session[key(path)];
			if (bytes == null)
				missing();
			else {
				attempt.report("ready", bytes.length, bytes.length);
				done(Loaded(bytes));
			}
			return;
		}
		attempt.child = cache.read(key(path), result -> {
			if (attempt.settled())
				return;
			switch result {
				case Stored(bytes):
					if (kept != null)
						kept();
					attempt.report("ready", bytes.length, bytes.length);
					done(Loaded(bytes));
				case Missing: missing();
				case Failed(message): done(Failed(message));
				case Cancelled: done(Cancelled);
			}
		});
	}

	// Keeps bytes (of hash) as path's copy, then their record from the response's headers (and source, the URL they came from when not the
	// path's); with the cache Off, for this run alone.
	function store(path:String, bytes:haxe.io.Bytes, headers:Map<String, String>, hash:String, attempt:Attempt, done:Outcome->Void, ?source:String):Void {
		attempt.report("storing", bytes.length, bytes.length);
		if (cacheMode == Off) {
			session[key(path)] = bytes;
			attempt.report("ready", bytes.length, bytes.length);
			done(Loaded(bytes));
			return;
		}
		attempt.child = cache.write(key(path), bytes, result -> {
			if (attempt.settled())
				return;
			switch result {
				case Written:
					attempt.child = cache.write(recordKey(path), CacheRecords.encode(CacheRecords.of(headers, hash, now(), source)), _ -> {
						if (attempt.settled())
							return;
						attempt.report("ready", bytes.length, bytes.length);
						done(Loaded(bytes));
					});
				case Failed(message): done(Failed(message));
				case Cancelled: done(Cancelled);
			}
		});
	}

	/** The manifest's hash for path, or null when no manifest lists it (none is set, the host has none, or it doesn't name the file); and
		whether its directory's manifest leaves it out, which says the file has changed or gone since it was kept: such a copy is always asked
		about, however fresh. */
	function hashOf(path:String, done:(Null<String>, Bool) -> Void):Void {
		if (manifest == null || base == null) {
			done(null, false);
			return;
		}
		var parts = path.split("/"), name = parts.pop();
		directory(parts, found -> done(found == null ? null : found.files[name], found != null && !found.files.exists(name)));
	}

	/** The manifest of the directory of parts (the root's for none), loaded once a run: the root asked about each run, a directory's fetched only
		when its hash in its parent's differs from the copy's. */
	function directory(parts:Array<String>, done:Null<AssetManifest>->Void):Void {
		var dir = parts.join("/");
		if (manifests.exists(dir)) {
			done(manifests[dir]);
			return;
		}
		if (waiting.exists(dir)) {
			waiting[dir].push(done);
			return;
		}
		waiting[dir] = [done];
		var root = haxe.io.Path.directory(manifest),
			name = haxe.io.Path.withoutDirectory(manifest);
		var file = haxe.io.Path.join([root, dir, name]);
		function settle(found:Null<AssetManifest>) {
			manifests[dir] = found;
			var callers = waiting[dir];
			waiting.remove(dir);
			for (caller in callers)
				caller(found);
		}
		function loaded(result:Outcome)
			settle(switch result {
				case Loaded(bytes): AssetManifest.parse(bytes);
				case _: null;
			});
		// The manifests' own loads belong to no one request: cancelling one ensure leaves them running.
		var own = new Attempt(new Request(() -> {}), loaded, (_, _, _) -> {});
		if (parts.length == 0)
			obtain(file, base + file, null, Ask, own, loaded);
		else
			directory(parts.slice(0, parts.length - 1), parent -> {
				var expected = parent == null ? null : parent.dirs[parts[parts.length - 1]];
				if (expected == null)
					settle(null);
				else
					obtain(file, base + file, expected, Revalidate, own, loaded);
			});
	}

	@:isVar public var manifest(get, null):Null<String>;

	function get_manifest():Null<String>
		return manifest;

	public function setManifest(path:Null<String>):Bool {
		if (path != null && !AssetPath.isValid(path))
			return false;
		manifest = path;
		manifests.clear();
		return true;
	}

	public var host(get, never):Null<String>;

	function get_host():Null<String>
		return base;

	public function setHost(host:Null<String>):Bool {
		if (host == "")
			return false;
		base = host == null || StringTools.endsWith(host, "/") ? host : host + "/";
		return true;
	}

	public function pingHost(host:String, probePath:String, timeoutSeconds:Float, complete:Bool->Void):IRequest {
		var root = StringTools.endsWith(host, "/") ? host : host + "/";
		return fetcher.fetch({url: root + probePath, timeoutSeconds: timeoutSeconds, noCache: true}, result -> complete(switch result {
			case Response(value): value.status >= 200 && value.status < 300;
			case _: false;
		}));
	}

	@:isVar public var cacheMode(get, set):AssetCacheMode = AssetCacheMode.Revalidate;

	function get_cacheMode():AssetCacheMode
		return cacheMode;

	function set_cacheMode(mode:AssetCacheMode):AssetCacheMode {
		cacheMode = mode;
		return mode;
	}

	public function clearCache(complete:StorageWriteResult->Void):IRequest {
		session.clear();
		manifests.clear();
		return cache.clear(complete);
	}

	public function streamSource(path:String, located:AudioLocation->Void, ?failed:String->Void, download:Bool = false):IRequest {
		var child:IRequest = null, request:Request = null;
		// Ends the request with a location, or a failure for null; a stored location that arrives too late is released.
		function finish(location:Null<AudioLocation>, ?message:String) {
			if (request.finish()) {
				requests.remove(request);
				queue.add(() -> if (location != null) located(location) else Failure.report(path, message, failed));
			} else if (location != null)
				switch location {
					case Stored(value):
						value.release();
					case _:
				}
		}
		// A store's cancellation (it shut down) ends the request telling no one.
		function stop()
			if (request.finish())
				requests.remove(request);
		request = new Request(() -> {
			if (child != null)
				child.cancel();
			requests.remove(request);
		});
		requests.push(request);
		var local:StorageSourceResult->Void = null;
		// The file from the host at url: its URL for the platform to play, or with download, the file arriving (grow); record is the copy's.
		function remote(url:String, record:Null<CacheRecord>, expected:Null<String>)
			if (!download)
				finish(Remote(url));
			else if (cacheMode == Off && session.exists(key(path)))
				finish(Downloading(GrowingSource.of(session[key(path)])));
			else
				child = grow(path, url, expected == null ? record : null, expected, request, finish, () -> child = cache.source(key(path), local));
		local = result -> {
			if (request.settled) {
				switch result {
					case Local(value):
						value.release();
					case _:
				}
				return;
			}
			switch result {
				case Local(value):
					finish(Stored(value));
				case Failed(message):
					finish(null, message);
				case Cancelled:
					stop();
				case Missing:
					if (base != null) remote(base + path, null, null); else child = packaged.source(path, result -> switch result {
						case Local(value): finish(Stored(value));
						case Missing: finish(null, "Missing streamed asset: " + path);
						case Failed(message): finish(null, message);
						case Cancelled: stop();
					});
			}
		}
		queue.add(() -> {
			if (request.settled)
				return;
			if (!live || !AssetPath.isValid(path)) {
				finish(null, "Invalid asset path or closed service");
				return;
			}
			if (base == null) {
				child = cache.source(key(path), local);
				return;
			}
			// A downloaded copy is streamed only while it's current (obtain's rules, without asking the host): the manifest's hash, else fresh.
			// Otherwise the host's URL, where the platform's own HTTP cache decides, or the download (remote).
			hashOf(path, (expected, unlisted) -> {
				if (request.settled)
					return;
				if (cacheMode == Off) {
					remote(base + path, null, expected);
					return;
				}
				child = cache.read(recordKey(path), result -> {
					if (request.settled)
						return;
					var record = switch result {
						case Stored(bytes): CacheRecords.parse(bytes);
						case _: null;
					}
					// A copy brought from elsewhere streams from the cache while fresh, else from where it came: the host has nothing at the path.
					if (record != null && record.source != null && expected == null) {
						if (cacheMode == Trust || now() < record.freshUntil)
							child = cache.source(key(path), local);
						else
							remote(record.source, record, null);
						return;
					}
					if (expected != null ? record != null && record.hash == expected : !unlisted
						&& (cacheMode == Trust || record != null && now() < record.freshUntil))
						child = cache.source(key(path), local);
					else
						remote(base + path, record, expected);
				});
			});
		});
		return request;
	}

	/** Downloads path from url into a GrowingSource for streamSource's request, finishing it with Downloading as soon as the first part arrives
		with a 200 and a Content-Length, or with a source already done once the file is whole without one; then keeps the file in the cache as a
		download does (store). expected is a manifest's hash, record the stale copy asked about (its ETag and Last-Modified sent): a 304 renews
		it and calls cached (which leases it), as does no answer (offline, a 5xx) with a copy. A download that fails after the answer ends its
		source (GrowingSource.failure) and is logged with the path. The download is tracked as a request of its own (busy, shutdown) until the
		file is kept; the IRequest returned cancels it while request hasn't been answered. */
	function grow(path:String, url:String, record:Null<CacheRecord>, expected:Null<String>, request:Request, finish:(Null<AudioLocation>, ?String) -> Void,
			cached:Void->Void):IRequest {
		var headers:Map<String, String> = [];
		if (record != null && record.etag != null)
			headers["If-None-Match"] = record.etag;
		if (record != null && record.lastModified != null)
			headers["If-Modified-Since"] = record.lastModified;
		var source:Null<GrowingSource> = null,
			fetch:IRequest = null,
			own:Request = null;
		own = new Request(() -> {
			fetch.cancel();
			requests.remove(own);
		});
		requests.push(own);
		function end()
			if (own.finish())
				requests.remove(own);
		// The download failed: before the answer, the request fails (or uses the copy, when there's one and the host didn't answer); after it,
		// the source ends and the log says why.
		function failed(message:String, answered:Bool) {
			end();
			if (source != null) {
				source.fail(message);
				Failure.report(path, message, null);
			} else if (!answered && record != null)
				cached();
			else
				finish(null, message);
		}
		fetch = fetcher.fetch({
			url: url,
			noCache: expected != null || record != null,
			headers: headers,
			maxBytes: STREAM_MAX_BYTES,
			timeoutSeconds: STREAM_TIMEOUT
		}, result -> switch result {
			case Response(value):
				if (value.status == 304 && record != null) {
					end();
					renew(path, record, value.headers);
					cached();
				} else if (value.status >= 200 && value.status < 300) {
					var hash = AssetManifest.hash(value.bytes);
					if (source != null && !source.done)
						failed('Download ended short of its Content-Length: $path', true);
					else if (expected != null && hash != expected)
						failed('Asset does not match its manifest (a deploy still arriving?): $path', true);
					else {
						if (source == null)
							finish(Downloading(GrowingSource.of(value.bytes)));
						store(path, value.bytes, value.headers, hash, new Attempt(own, _ -> end(), (_, _, _) -> {}), _ -> end(),
							url == base + path ? null : url);
					}
				} else if (value.status >= 400 && value.status < 500) {
					// The host says it's gone: so is the copy.
					forget(path);
					failed('Asset HTTP ${value.status}: $path', true);
				} else failed('Asset HTTP ${value.status}: $path', false);
			case Failed(message):
				failed(message, false);
			case Cancelled:
				if (source != null)
					source.fail("Download cancelled");
				end();
		}, null, part -> {
			if (source == null && !request.settled && part.status == 200 && part.totalBytes != null && part.totalBytes <= STREAM_MAX_BYTES) {
				source = new GrowingSource(part.totalBytes);
				source.append(part.bytes);
				finish(Downloading(source));
			} else if (source != null)
				source.append(part.bytes);
		});
		return new Request(() -> if (source == null) own.cancel());
	}

	public function subscribe(path:String, target:IReloadable):Void {
		var list = subscribers[path];
		if (list == null)
			subscribers[path] = list = [];
		if (list.indexOf(target) < 0)
			list.push(target);
	}

	public function unsubscribe(path:String, target:IReloadable):Void {
		var list = subscribers[path];
		if (list != null) {
			list.remove(target);
			if (list.length == 0)
				subscribers.remove(path);
		}
	}

	/** A file changed: load it again past every cache, keep the new copy, and tell the path's subscribers. A failure keeps what they have. */
	public function changed(path:String):Void {
		if (!live || !AssetPath.isValid(path) || !subscribers.exists(path))
			return;
		// A reload that fails says so (development): the subscribers keep what they have.
		function done(ok:Bool, message:String)
			if (!ok)
				Log.warn('Reload failed: $path: $message', "asset");
		function tell(bytes:haxe.io.Bytes) {
			var list = subscribers[path];
			if (list != null)
				for (target in list.copy())
					try
						target.reloaded(path, bytes)
					catch (error:Dynamic) {
						done(false, Std.string(error));
						return;
					}
			done(true, "");
		}
		// The new copy kept as a download is (this run's alone with the cache Off), then the subscribers told.
		function deliver(bytes:haxe.io.Bytes, headers:Map<String, String>)
			if (cacheMode == Off) {
				session[key(path)] = bytes;
				tell(bytes);
			} else
				cache.write(key(path), bytes, result -> switch result {
					case Written:
						cache.write(recordKey(path), CacheRecords.encode(CacheRecords.of(headers, AssetManifest.hash(bytes), now())), _ -> {});
						tell(bytes);
					case Failed(message): done(false, message);
					case Cancelled:
				});
		if (base != null)
			fetcher.fetch({url: base + path, noCache: true}, result -> switch result {
				case Response(value): if (value.status >= 200 && value.status < 300) deliver(value.bytes,
						value.headers); else done(false, 'Asset HTTP ' + value.status);
				case Failed(message): done(false, message);
				case Cancelled:
			});
		else
			packaged.read(path, result -> switch result {
				case Stored(bytes): deliver(bytes, []);
				case Missing: done(false, "Missing asset");
				case Failed(message): done(false, message);
				case Cancelled:
			});
	}

	public var busy(get, never):Bool;

	function get_busy():Bool
		return requests.length > 0 || !queue.empty;

	/** Polls the fetcher, cache and packaged store, then runs queued work and completions within the work budget. Call once per frame on the host thread. */
	public function poll():Void {
		fetcher.poll();
		cache.poll();
		packaged.poll();
		queue.poll();
	}

	/** Cancels every pending request (each telling no one), shuts down the fetcher, cache and packaged store, and runs queued completions. Later requests fail. */
	public function shutdown():Void {
		live = false;
		for (request in requests.copy())
			request.cancel();
		fetcher.shutdown();
		cache.shutdown();
		packaged.shutdown();
		queue.poll();
	}
}
