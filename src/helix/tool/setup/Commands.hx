package helix.tool.setup;

import helix.tool.shared.CommandError;

/** `haxelib run helix <command>`'s commands, read from the command line and run on the game in the current directory; Run.hx calls it. A
	refusal (CommandError) is said on the standard error and exits with 1; a command line it can't read, with 2. */
class Commands {
	/** What `--help` says. */
	public static final HELP = "usage: haxelib run helix <command> [options]

What a game on -lib helix does before it has an hxml, or outside one. Its builds are hxml files (the starter's hxml/), whose build steps are
macros in helix.tool: Build's steps (shaders packed, the page, assets, the zip), Watchers, WebServer (BUILDING.md).

  init DIRECTORY                 a starter game in DIRECTORY (new, empty, or a repository just made; . is this one): src/Main.hx and src/Game.hx (a window title, a rectangle
                              and a greeting), hxml/ (common.hxml and web.hxml; build.web, build.native and build.dist; dev, the dev loop; and
                              serve.dist), assets/, favicon.svg (the page's icon, to replace), .gitignore and a README
  init DIRECTORY --example NAME  the library's example NAME as a game in DIRECTORY, the starter around it: its App in src/, the examples'
                              assets and its own in assets/, its shaders/ and config.json; an unknown NAME lists the examples
  autopilot SCRIPT [--no-build] [--browser CHROMIUM]
                              plays the autopilot script SCRIPT (under assets/: assets/autopilot/run.json) in a headless Chromium: builds
                              the release (hxml/build.dist.hxml; not with --no-build), serves out/dist/, opens it with the script, and
                              prints what the game published; exits 1 when the script fails, saying why. Needs Node.js; Playwright and
                              its Chromium are fetched into the user's cache the first time (npm), or --browser names a Chromium
  setup [--sdl-gpu]           the tools packing shaders needs, made ready ahead of its first use (before going offline, or for a CI's
                              cache), and listed: sokol-shdc, and with --sdl-gpu glslang and SPIRV-Cross (built by hxcpp, with the system's
                              C++ compiler)

Packing shaders fetches sokol-shdc into the user's cache the first time, and for SDL_GPU glslang and SPIRV-Cross too; HELIX_SHDC,
HELIX_GLSLANG and HELIX_SPIRV_CROSS name programs of your own instead.";

	/** Runs the command args name for the game in the current directory, the library being at root; returns the exit code. */
	public static function run(args:Array<String>, root:String):Int {
		if (args.length == 0)
			return usage("a command is needed: init, autopilot or setup");
		var command = args[0], rest = args.slice(1);
		if (command == "--help" || command == "-h") {
			Sys.println(HELP);
			return 0;
		}
		try {
			switch command {
				case "init":
					var options = new Options(rest, [], ["--example"]);
					if (options.help)
						return help("init DIRECTORY [--example NAME]: a starter game, or the library's example NAME as a game, in a new or empty directory");
					if (options.positional.length != 1)
						return usage("init: name one directory");
					var directory = options.positional[0],
						example = options.values["--example"];
					var wrote = Starter.write(root, directory, example),
						written = wrote.written;
					if (wrote.kept.length > 0)
						Sys.println('init: $directory: kept as they were: ${wrote.kept.join(", ")}');
					if (example == null)
						Sys.println('init: $directory: ' + written.join(", "));
					else {
						var assets = written.filter(file -> StringTools.startsWith(file, "assets/"));
						Sys.println('init: $directory: the example $example, '
							+ written.filter(file -> !StringTools.startsWith(file, "assets/")).join(", ")
							+ ', and ${assets.length} files in assets/');
					}
				case "autopilot":
					var options = new Options(rest, ["--no-build"], ["--browser"]);
					if (options.help)
						return
							help("autopilot SCRIPT [--no-build] [--browser CHROMIUM]: the autopilot script SCRIPT (under assets/) played on the release build in a headless Chromium");
					if (options.positional.length != 1)
						return usage("autopilot: name one script (under assets/)");
					return AutopilotTool.run(root, options.positional[0], options.flags.indexOf("--no-build") < 0, options.values["--browser"]);
				case "setup":
					var options = new Options(rest, ["--sdl-gpu"], []);
					if (options.help)
						return help("setup [--sdl-gpu]: the tools packing shaders needs, made ready ahead and listed");
					if (options.positional.length > 0)
						return usage('setup: unexpected ${options.positional[0]}');
					ToolCache.run(root, options.flags.indexOf("--sdl-gpu") >= 0);
				default:
					return usage('unknown command $command: init, autopilot or setup');
			}
		} catch (error:OptionError) {
			return usage('$command: ${error.message}');
		} catch (error:CommandError) {
			Sys.stderr().writeString(error.message + "\n");
			return 1;
		}
		return 0;
	}

	static function help(line:String):Int {
		Sys.println("usage: haxelib run helix " + line);
		return 0;
	}

	static function usage(message:String):Int {
		Sys.stderr().writeString('usage: haxelib run helix <command> [options] (--help lists them)\nhelix: $message\n');
		return 2;
	}
}

/** A command line that can't be read: an unknown option. */
private class OptionError extends haxe.Exception {}

/** A command's options read from its arguments: its flags, --help. */
private class Options {
	/** The arguments that aren't options, in order. */
	public var positional:Array<String> = [];

	/** The flags given. */
	public var flags:Array<String> = [];

	/** The options given a value (the argument after them), by name. */
	public var values:Map<String, String> = [];

	/** Whether --help (or -h) was given. */
	public var help = false;

	/** args read, known naming the command's flags and valued its options taking a value. */
	public function new(args:Array<String>, known:Array<String>, valued:Array<String>) {
		var i = 0;
		while (i < args.length) {
			var arg = args[i++];
			if (arg == "--help" || arg == "-h")
				help = true;
			else if (known.indexOf(arg) >= 0)
				flags.push(arg);
			else if (valued.indexOf(arg) >= 0) {
				if (i >= args.length || StringTools.startsWith(args[i], "-"))
					throw new OptionError('$arg needs a value');
				values[arg] = args[i++];
			} else if (StringTools.startsWith(arg, "-") && arg.length > 1)
				throw new OptionError('unknown option $arg');
			else
				positional.push(arg);
		}
	}
}
