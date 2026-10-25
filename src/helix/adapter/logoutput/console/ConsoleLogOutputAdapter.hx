package helix.adapter.logoutput.console;

import helix.debug.ILogOutput;
import helix.debug.LogLevel;

/** The browser's console: each level by its own call (console.debug, info, warn, error), so the console's level filter works on them. */
@:noCompletion
class ConsoleLogOutputAdapter implements ILogOutput {
	/** The page's console. */
	public function new() {}

	public function write(level:LogLevel, line:String):Void {
		switch level {
			case Debug:
				js.Browser.console.debug(line);
			case Info:
				js.Browser.console.info(line);
			case Warning:
				js.Browser.console.warn(line);
			case _:
				js.Browser.console.error(line);
		}
	}
}
