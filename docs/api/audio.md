# helix.audio

[Back to the index](README.md)

## Audio

*class* in [`src/helix/audio/Audio.hx`](../../src/helix/audio/Audio.hx), `import helix.audio.Audio;`

Sounds: clips and streams loaded through the assets, decoded and played (AudioResources), through buses. The audio output under it (IAudio) is the adapter's. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from AudioResources' public members with their doc comments, but for the buses and what plays through them, written here: the bus tree is plain engine data, there from the program's start, before the runner binds instance.

```haxe
static final master(default, null):Bus
static final music(default, null):Bus
static final effects(default, null):Bus
static function addBus(name:String, parent:Bus):Null<Bus>
static function play(sound:AudioResource, ?loop:Bool = false, ?volume:Float = 1.):AudioPlayback
static function crossfade(from:AudioPlayback, to:AudioPlayback, seconds:Float, ?toVolume:Float = 1.):Void
static function saveBuses(?key:String = "audio", ?done:() -> Void, ?failed:String -> Void):Void
static function loadBuses(?key:String = "audio", ?done:() -> Void, ?failed:String -> Void):Void
static function loadClip(path:String, loaded:AudioClip -> Void, ?failed:String -> Void):IRequest
static function loadStream(path:String, loaded:AudioStream -> Void, ?failed:String -> Void):IRequest
```

- `master`: The root bus, every other one under it. Kept across a hot reload (@:hot), as the buses a game holds are.
- `music`: The music's bus, under master. Kept across a hot reload (@:hot).
- `effects`: The sound effects' bus, under master: what play plays through. Kept across a hot reload (@:hot).
- `addBus`: A new bus named name under parent, at volume 1, held as a reference (`@:hot static final ambience = Audio.addBus("ambience", Audio.effects)`); its name is what saveBuses and loadBuses know it by. Null, adding none, for an empty name or one a bus has.
- `play`: Plays sound through effects from the beginning at volume (0 to 1), looping if asked: effects.play.
- `crossfade`: Fades from to silence and stops it, and to from its volume up to toVolume (1 by default; the track's own level), both over seconds and linear in power (FadeCurve.Power), so the two together hold their loudness through the middle: start to at 0 (`Audio.crossfade(theme, Audio.music.play(next, true, 0), 2)`).
- `saveBuses`: Saves every bus's volume and mute by name as JSON, the save named key (Saves, kept apart from the asset cache, so clearing it keeps them); done runs once it's written, failed (else the log, with the key) for a failed write.
- `loadBuses`: Loads the volumes and mutes saveBuses saved under key into the buses of their names, a name with no bus skipped; a volume is clamped, and assigning it ends a bus's fade. done runs once they're set, or nothing was saved; failed (else the log, with the key) for a failed read or a file that isn't the saved JSON.
- `loadClip`: Loads path and decodes it whole into a clip, which reloads in place when the file changes: a WAV (PCM or float), Ogg (Vorbis or Opus) or MP3, mono or stereo at any rate, played as mono at 44100 Hz; at most 8 MiB and about 47 seconds (loadStream for music). One of loaded or failed runs once on the host thread, and neither once the request is cancelled: loaded with a clip the caller owns and releases; failed (else the log, with the path) for a closed service, a load or decode failure, or a clip the backend refuses. A clip that arrives after cancellation is released.
- `loadStream`: Opens path (a WAV, Ogg or MP3, as loadClip takes) for progressive playback from a cached or packaged copy, or else from the host without loading it whole: its remote URL where the backend plays one (a browser), else its download, played as it arrives and kept in the cache when it ends (IAssets.streamSource's download). One of loaded or failed runs once on the host thread, and neither once the request is cancelled: loaded with a stream the caller owns and releases (its stored copy's lease ends with it); failed (else the log, with the path) for a closed service, a missing asset, a failed download, or a source the backend cannot open.

## AudioClip

*class* in [`src/helix/audio/AudioClip.hx`](../../src/helix/audio/AudioClip.hx), `import helix.audio.AudioClip;`

Fully decoded, reusable audio resource.

```haxe
var path(default, null):Null<String>
```

- `path`: The asset it was loaded from, which a reload replaces in place.

## AudioPlayback

*class* in [`src/helix/audio/AudioPlayback.hx`](../../src/helix/audio/AudioPlayback.hx), `import helix.audio.AudioPlayback;`

One playback, playing or paused, through a bus; holds its resource until stopped or played to its end. While audio hasn't started (a browser before the page's first key or pointer press) it waits, its pause, volume, pitch and pan kept, and starts once audio runs. What the adapter hears is heardVolume, its own volume times its bus's heard volume, sent once a frame when either changed.

```haxe
function new(resource:AudioResource, loop:Bool, volume:Float, bus:Bus)
var id(default, null):Int
var finished(default, null):Bool
var source(default, null):Int
var bus(default, null):Bus
var state(get, never):PlayState
function stop():Bool
function pause():Bool
function resume():Bool
var volume(default, set):Float
var heardVolume(get, never):Float
var pitch(default, set):Float
var pan(default, set):Float
function fade(to:Float, seconds:Float, ?done:() -> Void, ?stopWhenSilent:Bool = false):Void
function poll():Void
```

- `new`: A playback of resource (whose playback reference the caller retained) through bus at volume, looping if asked: it starts now if audio runs, waits if audio is available but hasn't started, and finishes at once otherwise. AudioResources.play makes it.
- `id`: The adapter's voice; 0 while it waits for audio to start, or when it couldn't start.
- `finished`: Whether it was stopped, played to its end, or never started; its resource reference is released then.
- `source`: The adapter's resource it plays, kept as it started: a reload may replace the resource's.
- `bus`: The bus it plays through.
- `state`: Playing or Paused while it lasts (waiting counts as playing); then Stopped (stop(), or it never started) or Complete (it played to its end).
- `stop`: Stops it and releases its resource reference. False once it has finished.
- `pause`: Pauses it where it is. False unless it's playing.
- `resume`: Plays on from where it was paused. False unless it's paused.
- `volume`: Its own volume, 0 to 1. Clamped to 0..1 (NaN is 0); once it has finished, kept but not heard. Assigning it ends a fade, whose done doesn't run.
- `heardVolume`: What it is heard at, 0 to 1: its volume times its bus's heardVolume.
- `pitch`: Its playback rate, 0.25 to 4 (1 as recorded; 2 an octave up and half as long), clamped (NaN is 1).
- `pan`: Where it is heard, -1 (left) to 1 (right), 0 the middle, equal power; clamped (NaN is 0).
- `fade`: Moves its volume to to (0 to 1, clamped) over seconds (0 or less, or NaN, sets it at once), linear in decibels, a silent end taken as -60 dB; at the end done runs (during this call for 0 seconds) and, with stopWhenSilent and an end of 0, it stops. A fade started over another, or a volume assigned, ends the earlier one, whose done doesn't run. Nothing once it has finished.
- `poll`: Starts it once audio runs, and finishes it, releasing its resource reference, once the adapter no longer plays it. AudioResources.poll calls it.

## AudioResource

*class* in [`src/helix/audio/AudioResource.hx`](../../src/helix/audio/AudioResource.hx), `import helix.audio.AudioResource;`

One owner plus active playback references. release() drops the owner's reference.

```haxe
var id(default, null):Int
var disposed(default, null):Bool
function retainPlayback():Void
function releasePlayback():Void
function release():Void
```

- `id`: The backend clip or stream id, which a reload may replace.
- `disposed`: Whether the owner and every playback have released it, so its backend resource is destroyed.
- `retainPlayback`: Adds a reference for a starting playback. Throws once the owner has released it.
- `releasePlayback`: Drops a playback's reference; the last reference destroys the backend resource.
- `release`: Drops the owner's reference, once; the backend resource is destroyed when no playback still holds it.

## AudioStream

*class* in [`src/helix/audio/AudioStream.hx`](../../src/helix/audio/AudioStream.hx), `import helix.audio.AudioStream;`

Progressively decoded resource. Stored and remote sources are independent policy.

## Bus

*class* in [`src/helix/audio/Bus.hx`](../../src/helix/audio/Bus.hx), `import helix.audio.Bus;`

A bus sounds are played through: a name, a parent, a volume, a mute and a fade, plain engine data. Audio.master is the root, Audio.music and Audio.effects are under it from the program's start, and Audio.addBus makes a game's own. A playback's heard volume is its own times its bus's heardVolume; the buses' fades advance and the heard volumes reach the voices once a frame (AudioResources.poll). A bus is held as a reference; its name is used only to save and load the volumes (Audio.saveBuses, Audio.loadBuses).

```haxe
final name:String
final parent:Null<Bus>
var volume(default, set):Float
var muted:Bool
var heardVolume(get, never):Float
function fade(to:Float, seconds:Float, ?done:() -> Void):Void
function play(sound:AudioResource, ?loop:Bool = false, ?volume:Float = 1.):AudioPlayback
function all():Array<Bus>
```

- `name`: Its name, unique among the buses: what saving and loading the volumes know it by.
- `parent`: The bus it plays into: null only for the master.
- `volume`: Its volume, 0 to 1, clamped (NaN is 0). Assigning it ends a fade, whose done doesn't run.
- `muted`: Whether it is muted: its heard volume, and everything played through it or a bus under it, is then 0, its volume kept for unmuting.
- `heardVolume`: What it plays at: its volume times its parents' up to the master, 0 when it or a parent is muted.
- `fade`: Moves its volume to to (0 to 1, clamped) over seconds (0 or less, or NaN, sets it at once), linear in decibels, a silent end taken as -60 dB; done runs at the end, during this call for 0 seconds. A fade started over another, or a volume assigned, ends the earlier one, whose done doesn't run.
- `play`: Plays sound through it from the beginning at volume (0 to 1), looping if asked: AudioResources.play on the program's (Audio.instance). Throws before the runner has bound one, and as AudioResources.play throws.
- `all`: This bus and every bus under it, parents before their children.

## Fade

*class* in [`src/helix/audio/Fade.hx`](../../src/helix/audio/Fade.hx), `import helix.audio.Fade;`

A volume (0 to 1) moving from one level to another over seconds along a curve (FadeCurve): linear in decibels so it sounds even, a silent end taken as FLOOR_DB, or linear in power for a crossfade; the last step lands on the end exactly. A bus's and a playback's fades each step one, once a frame.

```haxe
function new(from:Float, to:Float, seconds:Float, ?done:() -> Void, ?curve:FadeCurve = FadeCurve.Decibels)
static inline var FLOOR_DB:Float
static function at(from:Float, to:Float, fraction:Float, ?curve:FadeCurve = FadeCurve.Decibels):Float
final done:Null<() -> Void>
var finished(get, never):Bool
function step(delta:Float):Float
```

- `new`: From volume from to volume to (each 0 to 1) over seconds (0 or less ends at the first step) along curve, done run at the end by its owner.
- `FLOOR_DB`: The level a silent end (a volume of 0) is taken as, in decibels.
- `at`: The volume fraction (0 to 1) of the way from volume from to volume to along curve: linear in decibels, each end under FLOOR_DB's level taken as FLOOR_DB, or linear in power; to itself at 1.
- `done`: Runs once it reaches its end; null for none.
- `finished`: Whether it has reached its end.
- `step`: Moves it on by delta seconds (under 0 as 0) and returns the volume there: to exactly once finished.

## FadeCurve

*abstract* in [`src/helix/audio/FadeCurve.hx`](../../src/helix/audio/FadeCurve.hx), `import helix.audio.FadeCurve;`

How a Fade moves between its levels: Decibels, linear in decibels, even to the ear for a fade to or from silence (a bus's and a playback's fades); Power, linear in power (the volume's square), so two sounds crossfaded this way, one out and one in, keep their sum's loudness through the middle (Audio.crossfade).

Values: `Decibels`, `Power`.

## PlayState

*abstract* in [`src/helix/audio/PlayState.hx`](../../src/helix/audio/PlayState.hx), `import helix.audio.PlayState;`

Where a playback is: playing, paused, stopped (by stop(), or it never started), or complete (it played to its end). Each value is its own name, so a state traced or put in a probe reads "Playing", not a number.

Values: `Stopped`, `Playing`, `Paused`, `Complete`.

## StreamOpenResult

*enum* in [`src/helix/audio/StreamOpenResult.hx`](../../src/helix/audio/StreamOpenResult.hx), `import helix.audio.StreamOpenResult;`

How opening a stream ended: its id, or a failure message.

- `Opened(id:Int)`
- `Failed(message:String)`
