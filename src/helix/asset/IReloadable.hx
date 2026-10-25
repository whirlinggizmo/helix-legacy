package helix.asset;

import haxe.io.Bytes;

/** Told when a file it subscribed to (Assets.subscribe) changed and was loaded again. It's an object rather than a function so that after a
	hot reload of the code, its new code runs: a function kept from before would run the old. */
interface IReloadable {
	/** path's file changed, and bytes are its new contents. A throw is said as a failed reload, and the next change is tried again. */
	function reloaded(path:String, bytes:Bytes):Void;
}
