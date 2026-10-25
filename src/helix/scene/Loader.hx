package helix.scene;

import haxe.io.Bytes;
import helix.asset.Assets;
import helix.asset.Failure;
import helix.asset.IRequest;
import helix.audio.Audio;
import helix.audio.AudioClip;
import helix.audio.AudioStream;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.render3d.EnvironmentMap3D;
import helix.render3d.Models3D;
import helix.render3d.Environments3D;
import helix.render3d.ModelCache3D;
import helix.render3d.ModelFile3D;

/** A group of loads with one progress: a scene's files gathered so a loading screen shows how far they are (progress, from how many
	have ended) and the scene starts once they're done (done), with what failed by name (failures). Each load goes through the service
	it always did, its own lambdas kept (a failure with no failed lambda logged with its path, as the service would); the loader only counts. wrap
	counts any other load the game makes. Nothing here cancels: a scene that exits early cancels its own requests, and a cancelled load is never
	counted as ended. */
class Loader {
	var total = 0;
	var finished = 0;
	var failureList:Array<String> = [];

	/** No loads yet: done, at progress 1. */
	public function new() {}

	/** How many loads were added. */
	public var count(get, never):Int;

	function get_count():Int
		return total;

	/** How many have ended, failed ones included. */
	public var doneCount(get, never):Int;

	function get_doneCount():Int
		return finished;

	/** How far along, 0 to 1 (1 with nothing to load). */
	public var progress(get, never):Float;

	function get_progress():Float
		return total == 0 ? 1 : finished / total;

	/** Whether every load has ended. */
	public var done(get, never):Bool;

	function get_done():Bool
		return finished >= total;

	/** What failed, each as its name and the reason. */
	public var failures(get, never):Array<String>;

	function get_failures():Array<String>
		return failureList.copy();

	/** Counts a load the game makes itself: wrap its completion, naming it; failed gives the reason for a result that failed, or null. */
	public function wrap<T>(name:String, complete:T->Void, failed:T->Null<String>):T->Void {
		total++;
		return result -> {
			finished++;
			var reason = failed(result);
			if (reason != null)
				failureList.push('$name: $reason');
			complete(result);
		};
	}

	// A load's lambdas counted: each ends it once, a failure named; failed, or else the log, told as the service would.
	function counted<T>(path:String, loaded:T->Void, failed:Null<String->Void>):{loaded:T->Void, failed:String->Void} {
		total++;
		return {
			loaded: value -> {
				finished++;
				loaded(value);
			},
			failed: message -> {
				finished++;
				failureList.push('$path: $message');
				Failure.report(path, message, failed);
			}
		};
	}

	/** An asset's bytes through Assets. */
	public function asset(path:String, loaded:Bytes->Void, ?failed:String->Void):IRequest {
		var both = counted(path, loaded, failed);
		return Assets.ensure(path, both.loaded, both.failed);
	}

	/** A texture through Textures, filtered by filter (Linear smooth, with mipmaps; Nearest sharp, for pixel art). */
	public function texture(path:String, filter:helix.texture.Filter, loaded:Texture2D->Void, ?failed:String->Void):IRequest {
		var both = counted(path, loaded, failed);
		return Textures.load(path, filter, both.loaded, both.failed);
	}

	/** A sound clip through Audio. */
	public function clip(path:String, loaded:AudioClip->Void, ?failed:String->Void):IRequest {
		var both = counted(path, loaded, failed);
		return Audio.loadClip(path, both.loaded, both.failed);
	}

	/** A sound stream through Audio. */
	public function stream(path:String, loaded:AudioStream->Void, ?failed:String->Void):IRequest {
		var both = counted(path, loaded, failed);
		return Audio.loadStream(path, both.loaded, both.failed);
	}

	/** An environment through Environments3D (loaded once it's prepared). */
	public function environment(path:String, loaded:EnvironmentMap3D->Void, ?failed:String->Void):IRequest {
		var both = counted(path, loaded, failed);
		return Environments3D.load(path, both.loaded, both.failed);
	}

	/** A model file through Models3D (or models, a cache of a test's). */
	public function model(path:String, loaded:ModelFile3D->Void, ?failed:String->Void, ?models:ModelCache3D):IRequest {
		var both = counted(path, loaded, failed);
		return models != null ? models.load(path, both.loaded, both.failed) : Models3D.load(path, both.loaded, both.failed);
	}
}
