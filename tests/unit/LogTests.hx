import helix.debug.ILogOutput;
import helix.debug.Log;
import helix.debug.LogLevel;

// Where the lines went, for checking.
private class Lines implements ILogOutput {
	public var written:Array<String> = [];

	public function new() {}

	public function write(level:LogLevel, line:String):Void
		written.push('$level $line');
}

/** Log: levels and tags letting messages through, the line's place and tag, listeners, trace going through it, and Log.debug left out of
	a build that's neither debug nor the dev loop (as this one). */
class LogTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function main():Void {
		var lines = new Lines();
		@:privateAccess Log.start(lines);
		Log.level = Info;
		Log.info("hello");
		check(lines.written.length == 1
			&& StringTools.endsWith(lines.written[0], "LogTests.hx:30: hello")
			&& StringTools.startsWith(lines.written[0], "Info "),
			"A line says its level, where it was written and what");
		Log.warn("no save", "saves");
		check(StringTools.endsWith(lines.written[1], ": [saves] no save")
			&& StringTools.startsWith(lines.written[1], "Warning "), "A tag before the message");
		Log.debug("detail");
		check(lines.written.length == 2, "Log.debug is left out of a release build");
		Log.level = Warning;
		Log.info("quiet");
		Log.error("loud");
		check(lines.written.length == 3
			&& StringTools.endsWith(lines.written[2], "loud"), "Below Log.level, nothing; at or above it, written");
		Log.setTagLevel("audio", Error);
		Log.warn("a clip", "audio");
		Log.setTagLevel("ui", Info);
		Log.info("a button", "ui");
		check(lines.written.length == 4
			&& StringTools.endsWith(lines.written[3], "[ui] a button"), "A tag's own level, above or below Log.level");
		Log.setTagLevel("ui", Off);
		Log.error("silenced", "ui");
		Log.setTagLevel("ui", null);
		Log.error("back", "ui");
		check(lines.written.length == 5
			&& StringTools.endsWith(lines.written[4], "[ui] back"), "Off silences a tag; null gives it Log.level again");
		check(!Log.isWritten(Info) && Log.isWritten(Error) && !Log.isWritten(Warning, "audio") && !Log.isWritten(Off), "isWritten says so ahead");
		var heard = [];
		var listener = (level:LogLevel, line:String) -> heard.push(level);
		Log.listen(listener);
		Log.error("one");
		Log.unlisten(listener);
		Log.error("two");
		check(heard.length == 1 && heard[0] == Error, "A listener hears each line until it stops listening");
		Log.level = Info;
		trace("traced", 2);
		check(StringTools.startsWith(lines.written[lines.written.length - 1], "Info ")
			&& StringTools.endsWith(lines.written[lines.written.length - 1], ": traced, 2"),
			"trace goes through Log as Info, its extra values after");
		Log.level = Off;
		Log.error("nothing");
		check(StringTools.endsWith(lines.written[lines.written.length - 1], ": traced, 2"), "Log.level Off writes nothing");
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}
}
