package helix.debug;

/** Where a platform writes the log's lines (Log): the browser's console, or the process's output. */
@:noCompletion
interface ILogOutput {
	/** Writes line, already formatted, as level says. */
	function write(level:LogLevel, line:String):Void;
}
