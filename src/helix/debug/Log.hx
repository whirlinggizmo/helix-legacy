package helix.debug;

/** Writes messages for whoever is developing the game, each with how much it matters and, optionally, a tag saying what it's about:

	`Log.info("level 3 loaded")`, `Log.warn('no save yet', "saves")`, `Log.debug('ball at $x, $y', "physics")`.

	A line says where it was written from, as trace does (`Game.hx:42: [physics] ball at 10, 4`). In the browser it goes to the console
	(console.debug, info, warn and error, so the console's own filter works); natively, debug and info lines to the standard output and
	warnings and errors to the standard error. trace goes through it too, as Info.

	What's written is what's at or above `Log.level`, or a tag's own level when it has one (`Log.setTagLevel("physics", Warning)` quiets
	that tag's debug and info). Log.debug is gone from a release build altogether, so leave it in freely. The engine logs as well, under
	its own tags ("asset", "audio", "input", "shader", "tiled", "view", "window", "autopilot", "screenshot", "saves"). */
class Log {
	/** The least a message must matter to be written, unless its tag has a level of its own: Debug in a debug build and the dev loop, Info
		in a release, to start. Off writes nothing. */
	@:hot public static var level:LogLevel = #if (debug || hotreload) Debug #else Info #end;

	@:hot static var tagLevels:Map<String, LogLevel> = [];
	@:hot static var listeners:Array<(LogLevel, String) -> Void> = [];
	// Where lines go (the platform's, set as the program starts), and trace as it was before it came through here; the plain trace writes
	// lines until a platform's output is set (a unit test, the interpreter).
	@:hot static var output:Null<ILogOutput>;
	@:hot static var plainTrace:Null<(Dynamic, ?haxe.PosInfos) -> Void>;

	/** Writes message (anything; written as a string) as Debug: detail for finding a fault. Only in a debug build or the dev loop: a release
		build leaves the call out. */
	public static inline function debug(message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void {
		#if (debug || hotreload)
		write(Debug, message, tag, pos);
		#end
	}

	/** Writes message as Info: what happened, worth knowing. */
	public static function info(message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void
		write(Info, message, tag, pos);

	/** Writes message as Warning: something went wrong and the game carried on. */
	public static function warn(message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void
		write(Warning, message, tag, pos);

	/** Writes message as Error: something failed. */
	public static function error(message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void
		write(Error, message, tag, pos);

	/** Writes message as level says, when it's let through (isWritten). */
	public static function write(level:LogLevel, message:Dynamic, ?tag:String, ?pos:haxe.PosInfos):Void {
		if (!isWritten(level, tag))
			return;
		var line = format(message, tag, pos);
		for (listener in listeners.copy())
			listener(level, line);
		if (output != null)
			output.write(level, line);
		else
			(plainTrace != null ? plainTrace : haxe.Log.trace)(line, null);
	}

	/** Whether a message of level under tag (none when null) would be written: at or above the tag's level if it has one, else Log.level.
		To skip building a costly message that wouldn't be. */
	public static function isWritten(level:LogLevel, ?tag:String):Bool {
		var least = tag != null && tagLevels.exists(tag) ? tagLevels[tag] : Log.level;
		return level != Off && least != Off && (level : Int) >= (least : Int);
	}

	/** Gives tag a level of its own, in place of Log.level for its messages (Off to silence it), or takes it away with null. */
	public static function setTagLevel(tag:String, level:Null<LogLevel>):Void {
		if (level == null)
			tagLevels.remove(tag);
		else
			tagLevels[tag] = level;
	}

	/** Calls listener with each line written (its level, and the line as written), for an in-game console, an overlay or a test. */
	public static function listen(listener:(LogLevel, String) -> Void):Void
		if (listeners.indexOf(listener) < 0)
			listeners.push(listener);

	/** Stops calling listener. */
	public static function unlisten(listener:(LogLevel, String) -> Void):Void
		listeners.remove(listener);

	/** Sends lines to output from now on, and trace through Log as Info: the platform's, as the program starts. */
	@:allow(helix)
	static function start(to:ILogOutput):Void {
		output = to;
		if (plainTrace == null) {
			plainTrace = haxe.Log.trace;
			haxe.Log.trace = (value, ?infos) -> {
				var text = Std.string(value);
				if (infos != null && infos.customParams != null)
					for (more in infos.customParams)
						text += ", " + Std.string(more);
				write(Info, text, null, infos);
			};
		}
	}

	// "File.hx:42: [tag] message", as trace writes its place.
	static function format(message:Dynamic, tag:Null<String>, pos:Null<haxe.PosInfos>):String {
		var text = tag != null ? '[$tag] ' + Std.string(message) : Std.string(message);
		return pos != null ? '${pos.fileName}:${pos.lineNumber}: $text' : text;
	}
}
