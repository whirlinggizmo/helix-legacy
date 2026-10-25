package helix.adapter.logoutput.stdio;

import helix.debug.ILogOutput;
import helix.debug.LogLevel;

/** The process's output: debug and info lines on stdout, warnings and errors on stderr marked as such ("warning: ", "error: "). */
@:noCompletion
class StdioLogOutputAdapter implements ILogOutput {
	/** The process's own. */
	public function new() {}

	public function write(level:LogLevel, line:String):Void {
		switch level {
			case Debug | Info:
				Sys.println(line);
			case Warning:
				Sys.stderr().writeString('warning: $line\n');
			case _:
				Sys.stderr().writeString('error: $line\n');
		}
	}
}
