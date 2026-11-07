import haxe.io.Path;
import sys.FileSystem;

/** `haxelib run helix-legacy <command>`: the library's front door (haxelib.json's `main`), running a command (src/helix/tool/setup/Commands.hx) on the game
	in the directory it was given from: haxelib starts this in the library's directory and appends the caller's directory as the last argument (saying
	so with HAXELIB_RUN=1); run as `haxe --run Run` it works in the current directory. Haxe's interpreter runs it, so the commands need nothing
	but Haxe. Deliberately outside the framework's class path (src/), so no game compiles it. The commands: `--help`. */
class Run {
	static function main():Void {
		var args = Sys.args();
		var game = Sys.getCwd();
		if (Sys.getEnv("HAXELIB_RUN") == "1" && args.length > 0)
			game = args.pop();
		Sys.setCwd(game);
		Sys.exit(helix.tool.setup.Commands.run(args, libraryRoot()));
	}

	// The library's directory, this file's, fixed as the build resolved it: not the working directory, which haxelib sets and a user may not.
	static macro function libraryRoot():haxe.macro.Expr {
		var file = haxe.macro.Context.resolvePath("Run.hx");
		var root = FileSystem.absolutePath(Path.directory(file));
		return macro $v{root};
	}
}
