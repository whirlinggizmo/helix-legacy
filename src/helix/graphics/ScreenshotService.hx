package helix.graphics;

import helix.debug.Log;
import haxe.io.Bytes;
import helix.asset.IExport;
import helix.asset.ExportResult;
import helix.graphics.IGraphics;
import helix.host.Presentation;
import helix.graphics.ScreenshotResult;

/** Screenshots, the same on every platform: the next frame the app ends is read back (IGraphics.readPixels), encoded as PNG (Png) and handed
	to the user (IExport: a download in a browser, a file natively); or read at a few points, for a check comparing pixels (sample). The
	Runner calls frameEnded after each of the app's frames. Encoding runs on the host thread, so the frame it's taken in is slower. The
	runner's is what the Screenshots static forwards to. */
@:build(helix.macro.Facade.record())
@:noCompletion
class ScreenshotService {
	var graphics:IGraphics;
	var export:IExport;
	var prefix:String;
	var count = 0;
	var live = true;
	var pending:Array<{name:String, done:Null<ScreenshotResult->Void>}> = [];
	var presentation:Presentation;
	var samples:Array<{points:Array<Array<Float>>, done:Array<Array<Int>>->Void, failed:Null<String->Void>}> = [];

	/** Reads frames from graphics and saves them through export, named prefix (the product's name, say) and the time; samples them at points
		in presentation's units. */
	public function new(graphics:IGraphics, export:IExport, prefix:String, presentation:Presentation) {
		this.graphics = graphics;
		this.export = export;
		this.prefix = prefix;
		this.presentation = presentation;
	}

	/** Takes a screenshot of the next frame the app ends, saved as name (a plain file name ending .png; by default prefix, the date and time,
		and a count, as "asteroids-2026-10-14-153012-1.png"). done, when given, runs once on the host thread after that frame. Failed after
		shutdown. Throws for a name that isn't a plain .png file name. */
	public function take(?name:String, ?done:ScreenshotResult->Void):Void {
		if (name != null
			&& (!StringTools.endsWith(name, ".png") || name.indexOf("/") >= 0 || name.indexOf("\\") >= 0 || name.charAt(0) == "."))
			throw "Invalid screenshot name";
		if (!live) {
			if (done != null)
				done(Failed("Closed screenshots"));
			return;
		}
		count++;
		pending.push({name: name != null ? name : prefix + "-" + DateTools.format(Date.now(), "%Y-%m-%d-%H%M%S") + "-" + count + ".png", done: done});
	}

	/** Reads the next frame the app ends at points, each [x, y] in the design's units (Screen's; the pixel under it): done runs once on the
		host thread with each point's color as [r, g, b, a], 0 to 255 (0, 0, 0, 0 off the frame), or failed (else the log) when the frame can't
		be read or after shutdown. For checks that compare a few pixels across targets (the autopilot's sample), not every frame. */
	public function sample(points:Array<Array<Float>>, done:Array<Array<Int>>->Void, ?failed:String->Void):Void {
		if (!live) {
			fail(failed, "Closed screenshots");
			return;
		}
		samples.push({points: points, done: done, failed: failed});
	}

	static function fail(failed:Null<String->Void>, message:String):Void
		if (failed != null)
			failed(message);
		else
			Log.warn('Screenshots.sample: $message', "screenshot");

	// The colors at points (design units) in a frame of width x height pixels, rows top first.
	function colorsAt(points:Array<Array<Float>>, width:Int, height:Int, rgba:Bytes):Array<Array<Int>>
		return [
			for (p in points) {
				var x = Math.floor(presentation.toPixelsX(p[0])),
					y = Math.floor(presentation.toPixelsY(p[1]));
				if (x < 0 || y < 0 || x >= width || y >= height) [0, 0, 0, 0] else {
					var at = (y * width + x) * 4;
					[rgba.get(at), rgba.get(at + 1), rgba.get(at + 2), rgba.get(at + 3)];
				}
			}
		];

	/** After the app's frame: takes the screenshots and samples asked for, from the frame it just ended. Nothing when none were asked for. */
	public function frameEnded():Void {
		if (pending.length == 0 && samples.length == 0)
			return;
		var taking = pending, sampling = samples;
		pending = [];
		samples = [];
		graphics.readPixels(0, result -> switch result {
			case Read(width, height, rgba):
				for (s in sampling)
					s.done(colorsAt(s.points, width, height, rgba));
				if (taking.length == 0)
					return;
				var png = Png.encode(width, height, rgba);
				for (shot in taking)
					export.export(shot.name, "image/png", png, exported -> if (shot.done != null) shot.done(switch exported {
						case Exported(where): Saved(where, png);
						case Failed(message): Failed(message);
					}));
			case Failed(message):
				for (s in sampling)
					fail(s.failed, message);
				for (shot in taking)
					if (shot.done != null)
						shot.done(Failed(message));
		});
	}

	/** Fails what was asked for and refuses more. */
	public function shutdown():Void {
		live = false;
		var taking = pending, sampling = samples;
		pending = [];
		samples = [];
		for (s in sampling)
			fail(s.failed, "Closed screenshots");
		for (shot in taking)
			if (shot.done != null)
				shot.done(Failed("Closed screenshots"));
	}
}
