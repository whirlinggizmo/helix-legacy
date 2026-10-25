# helix.asset

[Back to the index](README.md)

## AssetCacheMode

*enum* in [`src/helix/asset/AssetCacheMode.hx`](../../src/helix/asset/AssetCacheMode.hx), `import helix.asset.AssetCacheMode;`

How the cache treats a downloaded copy no manifest lists (IAssets.cacheMode); a listed one follows its manifest in every mode, and ensure's forceFetch downloads past the cache in every mode.

- Revalidate, the default: a copy fresh by the host's Cache-Control (max-age not passed, or immutable) is used with no request; any other is asked about first: 304, the copy is used (and fresh again); 200, the new file replaces it; 4xx, the copy is deleted and the load fails; no answer (offline, a timeout) or a 5xx, the copy is used. no-cache and no-store make a copy never fresh, but it's kept, for the next check and for starting offline. - Trust: a copy is used without asking, however old: offline-first play, files that never change, or a game that evicts by itself. - Off: nothing is kept between runs, and what earlier runs kept is neither used nor deleted (development); this run's downloads are held in memory, so a file loads once a run.

- `Revalidate`
- `Trust`
- `Off`

## AssetPath

*class* in [`src/helix/asset/AssetPath.hx`](../../src/helix/asset/AssetPath.hx), `import helix.asset.AssetPath;`

Validates asset and storage keys, for the asset service, the shared StorageService and model files, and resolves a path one file names relative to itself.

```haxe
static function isValid(path:String):Bool
static function resolve(path:String, uri:String):Null<String>
```

- `isValid`: Whether path is a safe relative path: 1 to 256 characters of A-Z, a-z, 0-9, '_', '.', '-' and '/', with no empty, "." or ".." segment (so no leading slash and no URL).
- `resolve`: The asset path of uri (a file another names, relative to it: a model's buffers and images, a sprite sheet's image) beside the file at path: its %-escapes decoded and its "." and ".." segments followed. Null for one that isn't a relative path inside the assets (a URL, an absolute path, one climbing above them).

## AssetProgress

*typedef* in [`src/helix/asset/AssetProgress.hx`](../../src/helix/asset/AssetProgress.hx), `import helix.asset.AssetProgress;`

Load progress: phase ("locating", "downloading", "storing" or "ready"), bytes received, and total bytes, or null when unknown.

- `totalBytes:Null<Int>`
- `receivedBytes:Int`
- `phase:String`

## Assets

*class* in [`src/helix/asset/Assets.hx`](../../src/helix/asset/Assets.hx), `import helix.asset.Assets;`

Assets: the packaged files or downloads, cached. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from IAssets's public members with their doc comments.

```haxe
static function load(path:String, loaded:haxe.io.Bytes -> Void, ?failed:String -> Void):IRequest
static function ensure(path:String, loaded:haxe.io.Bytes -> Void, ?failed:String -> Void, ?progress:AssetProgress -> Void, ?options:EnsureOptions):IRequest
static var host(get, never):Null<String>
static function setHost(host:Null<String>):Bool
static var cacheMode(get, set):AssetCacheMode
static function clearCache(complete:StorageWriteResult -> Void):IRequest
static function subscribe(path:String, target:IReloadable):Void
static function unsubscribe(path:String, target:IReloadable):Void
static var busy(get, never):Bool
```

- `load`: Loads path's bytes as ensure does, without progress or options.
- `ensure`: Loads path's bytes: downloaded from the host when one is set and kept in the cache, or else read from the packaged files in place. A cached copy is used only while it's current: when a manifest (setManifest) lists the file, while the copy has the manifest's hash (else the file is downloaded past HTTP caches and kept only if it has it); otherwise while the host's Cache-Control says it's fresh, and then after asking the host (its ETag and Last-Modified sent): 304 keeps it, 200 replaces it, 4xx deletes it, and no answer (offline, a 5xx) uses it. One of loaded or failed runs once on the host thread, and neither once the request is cancelled; failed (else the log, with the path) for an invalid path, a closed service, a missing asset, an HTTP status outside 200-299 with no copy to use, a download that doesn't match its manifest, or a storage or transport error. progress, if given, reports each phase until the request settles.
- `host`: What's put before each path to download it, ending in "/": a URL, or a directory relative to the page (the browser's "assets/"); null when files are read from the program's packaged files (natively, unless HELIX_ASSET_HOST names a host).
- `setHost`: Downloads from host from now on (a "/" is added if it has none), or reads the packaged files with null. The cache keeps each host's files apart. False for an empty host.
- `cacheMode`: How downloaded copies no manifest lists are treated (AssetCacheMode); Revalidate by default.
- `clearCache`: Forgets every downloaded file, so the next load downloads it again, and what was read of the manifests, so the root is asked about again. complete runs once, on the host thread.
- `subscribe`: Tells target each time path's file changes while the game runs in the dev loop: the file is loaded again and target.reloaded gets its new bytes. That's how a game reloads its own files, such as a level or a JSON of tuning values, the way HeliX reloads textures and sounds. Load the file as usual first; subscribing doesn't load it. Outside the dev loop nothing changes, so it's never called. A target is told once per change however often it subscribed. For example, a class implementing IReloadable calls `Assets.subscribe("tuning.json", this)` and reads the bytes in its `reloaded`.
- `unsubscribe`: Stops telling target about path's changes. Does nothing if it wasn't subscribed.
- `busy`: Whether a load is under way or its completion not yet run (Host.busy asks it, with the decoders).

## EnsureOptions

*typedef* in [`src/helix/asset/EnsureOptions.hx`](../../src/helix/asset/EnsureOptions.hx), `import helix.asset.EnsureOptions;`

How ensure finds a file. source: where its bytes come from instead of its own path, a path read against the host as a browser reads a URL against a directory, or a whole URL; they're kept under the path asked for, remembering where they came from: a later plain load of the path asks about the copy there, and it streams from there when it's stale, as the host has nothing at the path. forceFetch: go past the cache to the host (or the packaged files), replacing what the cache holds.

- `source:Null<String>`
- `forceFetch:Null<Bool>`

## ExportResult

*enum* in [`src/helix/asset/ExportResult.hx`](../../src/helix/asset/ExportResult.hx), `import helix.asset.ExportResult;`

Where an exported file went: a path natively, the downloaded file's name in a browser; or why it couldn't be.

- `Exported(where:String)`
- `Failed(message:String)`

## Failure

*class* in [`src/helix/asset/Failure.hx`](../../src/helix/asset/Failure.hx), `import helix.asset.Failure;`

Where a load's failure goes: to the caller's failed lambda, or, when it gave none, to the log with the path, so nothing fails silently. Every load taking (loaded, ?failed) reports through it.

```haxe
static function report(path:String, message:String, failed:Null<String -> Void>):Void
static function named(path:String, message:String):String
```

- `report`: Calls failed with message, or, when failed is null, logs a warning, "Load failed: " and the message named by its path (named).
- `named`: message led by "path: ", or message as it is when it names path already (an HTTP status's does), so the path is said once.

## Fetch

*class* in [`src/helix/asset/Fetch.hx`](../../src/helix/asset/Fetch.hx), `import helix.asset.Fetch;`

Downloads: bounded whole-response GETs (FetchService). The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from FetchService's public members with their doc comments.

```haxe
static function fetch(request:FetchRequest, complete:FetchResult -> Void, ?progress:FetchProgress -> Void, ?part:FetchPart -> Void):IRequest
```

- `fetch`: Queues a GET of request.url. complete runs exactly once on the host thread; Failed for a maxBytes or timeoutSeconds not above 0, a closed service, a body over maxBytes, a timeout, or a transport failure. progress, if given, runs on the host thread at most once a frame. part, if given, runs on the host thread with each part of the body as it arrives, in order, before complete (whose response still holds the whole body); never after the fetch has settled.

## FetchPart

*typedef* in [`src/helix/asset/FetchPart.hx`](../../src/helix/asset/FetchPart.hx), `import helix.asset.FetchPart;`

A part of a response's body as it arrives: the response's HTTP status and headers (lower-case names), the total from Content-Length or null when unknown (or the body is compressed), and the part's bytes.

- `totalBytes:Null<Int>`
- `status:Int`
- `headers:Map<String, String>`
- `bytes:haxe.io.Bytes`

## FetchProgress

*typedef* in [`src/helix/asset/FetchProgress.hx`](../../src/helix/asset/FetchProgress.hx), `import helix.asset.FetchProgress;`

Body bytes received so far, and the total from Content-Length, or null when unknown (or the body is compressed).

- `totalBytes:Null<Int>`
- `receivedBytes:Int`

## FetchRequest

*typedef* in [`src/helix/asset/FetchRequest.hx`](../../src/helix/asset/FetchRequest.hx), `import helix.asset.FetchRequest;`

A GET of url: maxBytes limits the body (default 8 MiB), timeoutSeconds bounds the whole transfer (default 15), noCache bypasses HTTP caches (default false), headers are sent with it (none by default).

- `url:String`
- `timeoutSeconds:Null<Float>`
- `noCache:Null<Bool>`
- `maxBytes:Null<Int>`
- `headers:Null<Map<String, String>>`

## FetchResponse

*typedef* in [`src/helix/asset/FetchResponse.hx`](../../src/helix/asset/FetchResponse.hx), `import helix.asset.FetchResponse;`

A complete response: HTTP status, headers with lower-case names, and the whole body.

- `status:Int`
- `headers:Map<String, String>`
- `bytes:haxe.io.Bytes`

## FetchResult

*enum* in [`src/helix/asset/FetchResult.hx`](../../src/helix/asset/FetchResult.hx), `import helix.asset.FetchResult;`

How a fetch ended: a response of any HTTP status, a transport failure message, or cancellation.

- `Response(value:FetchResponse)`
- `Failed(message:String)`
- `Cancelled`

## IReloadable

*class* in [`src/helix/asset/IReloadable.hx`](../../src/helix/asset/IReloadable.hx), `import helix.asset.IReloadable;`

Told when a file it subscribed to (Assets.subscribe) changed and was loaded again. It's an object rather than a function so that after a hot reload of the code, its new code runs: a function kept from before would run the old.

```haxe
function reloaded(path:String, bytes:haxe.io.Bytes):Void
```

- `reloaded`: path's file changed, and bytes are its new contents. A throw is said as a failed reload, and the next change is tried again.

## IRequest

*class* in [`src/helix/asset/IRequest.hx`](../../src/helix/asset/IRequest.hx), `import helix.asset.IRequest;`

Host-thread cancellation. Completion is asynchronous and exactly once.

```haxe
function cancel():Void
```

- `cancel`: Cancels the operation if it has not settled: a load's lambdas aren't called (an operation with a result enum reports Cancelled); does nothing once settled.

## Saves

*class* in [`src/helix/asset/Saves.hx`](../../src/helix/asset/Saves.hx), `import helix.asset.Saves;`

The game's saves, apart from the asset cache (SaveService), installed by their first use, so a program that saves nothing opens no store for them. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from SaveService's public members with their doc comments.

```haxe
static var busy(get, never):Bool
static function read(name:String, loaded:String -> Void, ?missing:() -> Void, ?failed:String -> Void):IRequest
static function write(name:String, text:String, ?written:() -> Void, ?failed:String -> Void):IRequest
static function remove(name:String, ?removed:() -> Void, ?failed:String -> Void):IRequest
```

- `busy`: Whether a read, write or removal hasn't completed yet.
- `read`: Reads the save named name: loaded gets its text, missing runs when there is none (else loaded isn't called), failed (else the log) for a name that isn't an asset path or a store that fails. None runs once the request is cancelled.
- `write`: Writes text as the save named name, in place of what it was: written runs once it's kept, failed (else the log) for a name that isn't an asset path, text over 8 MiB or a store that fails.
- `remove`: Removes the save named name (none is no failure): removed runs once it's gone, failed (else the log) for a name that isn't an asset path or a store that fails.

## Storage

*class* in [`src/helix/asset/Storage.hx`](../../src/helix/asset/Storage.hx), `import helix.asset.Storage;`

The writable cache: files by key (StorageService). The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from StorageService's public members with their doc comments.

```haxe
static function read(key:String, complete:StorageResult -> Void):IRequest
static function write(key:String, bytes:haxe.io.Bytes, complete:StorageWriteResult -> Void):IRequest
static function remove(key:String, complete:StorageWriteResult -> Void):IRequest
static function source(key:String, complete:StorageSourceResult -> Void):IRequest
static function clear(complete:StorageWriteResult -> Void):IRequest
```

- `read`: Reads the whole file under key. Failed for an invalid key, a file over 8 MiB, a closed store, or an I/O error.
- `write`: Stores a copy of bytes under key, replacing what is there. Failed for an invalid key, more than 8 MiB, a read-only store, a closed store, or an I/O error.
- `remove`: Deletes the file under key; Written also when there was none. Failed for an invalid key, a read-only store, a closed store, or an I/O error.
- `source`: Leases the file under key for streaming without reading it; the caller releases a Local lease, and one that arrives after cancellation is released for it. Failed for an invalid key, a closed store, or an I/O error.
- `clear`: Removes every stored file; Failed for a read-only store.

## StorageResult

*enum* in [`src/helix/asset/StorageResult.hx`](../../src/helix/asset/StorageResult.hx), `import helix.asset.StorageResult;`

How a read ended: the stored bytes, Missing, a failure message, or cancellation.

- `Stored(bytes:haxe.io.Bytes)`
- `Missing`
- `Failed(message:String)`
- `Cancelled`

## StorageSourceResult

*enum* in [`src/helix/asset/StorageSourceResult.hx`](../../src/helix/asset/StorageSourceResult.hx), `import helix.asset.StorageSourceResult;`

How leasing a stored file ended: the lease, Missing, a failure message, or cancellation.

- `Local(value:Lease)`
- `Missing`
- `Failed(message:String)`
- `Cancelled`

## StorageWriteResult

*enum* in [`src/helix/asset/StorageWriteResult.hx`](../../src/helix/asset/StorageWriteResult.hx), `import helix.asset.StorageWriteResult;`

How a write or remove ended: Written, a failure message, or cancellation.

- `Written`
- `Failed(message:String)`
- `Cancelled`
