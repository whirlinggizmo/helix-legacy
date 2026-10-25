package helix.asset;

import helix.debug.Log;

/** Where a load's failure goes: to the caller's failed lambda, or, when it gave none, to the log with the path, so nothing fails silently. Every
	load taking (loaded, ?failed) reports through it. */
class Failure {
	/** Calls failed with message, or, when failed is null, logs a warning, "Load failed: " and the message named by its path (named). */
	public static function report(path:String, message:String, failed:Null<String->Void>):Void {
		if (failed != null)
			failed(message);
		else
			Log.warn('Load failed: ${named(path, message)}', "asset");
	}

	/** message led by "path: ", or message as it is when it names path already (an HTTP status's does), so the path is said once. */
	public static function named(path:String, message:String):String
		return message.indexOf(path) >= 0 ? message : '$path: $message';
}
