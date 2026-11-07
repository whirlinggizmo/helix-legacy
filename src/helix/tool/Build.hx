package helix.tool;

#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import helix.tool.shader.ShaderPacker;
import helix.tool.shared.CommandError;
import helix.tool.shared.Files;
import sys.FileSystem;
import sys.io.File;
#end

/** The steps a game's build hxml lists after what it builds, as macros (`--macro helix.tool.Build.<step>(...)`), run by the compiler from
	the game's directory: `packShaders` before the build compiles, the others once it has written its output, in the order listed. A step's
	directory, when it takes one, is relative to the game's and defaults to the build's output directory: the `-js` file's, or the `-cpp`
	one natively. A step that fails ends the build with its message.

	- `packShaders(?directory)`: the game's `shaders/*.glsl` packed into `assets/shaders/<name>.hxshader` (or directory), each only when
	  its source is newer, with SDL_GPU's dialects when the build names the `sdl3-gpu` backend; nothing without a `shaders/` directory.
	  When the assets carry manifests (`tools/gen_manifest.py`'s), they're rewritten from their root down to the shaders' directory.
	- `cleanOutput(?directory)`: everything in the browser build's output directory removed but the JavaScript just written, so what's
	  there is what the steps after it put there. Refuses a native build's: a `-cpp` directory is hxcpp's working directory.
	- `generateWebPage(?directory)`: the page a browser build runs in, beside its JavaScript: `index.html` generated from the library's
	  template (titled with the game directory's name, loading the build's file, told of `config.json` when the game has one), and
	  `favicon.svg` (the game's, or the library's) copied, each when it isn't there (one there is the game's, and kept); the game's
	  `config.json` copied each build. Every browser build on `-lib helix-legacy` runs it (helix.macro.Haxelib), so the dev loop has a page.
	- `copyAssets(?directory)`: the game's `assets/` copied into directory as `assets/`, beside the page or the program, where both read
	  it.
	- `copyProgram(directory)`: the native program (the main class's, `-debug` in a debug build) and the libraries beside it copied
	  from the build's output into directory, a distribution of its own away from hxcpp's working directory.
	- `zipOutput(path, ?directory)`: directory written as a zip at path, its files at the zip's root (`index.html` at the root, as
	  itch.io takes a web game). */
class Build {
	#if macro
	/** The game's shaders packed into directory (assets/shaders) before the build, each only when changed. */
	public static function packShaders(?directory:String):Void {
		if (Context.defined("display") || !FileSystem.exists("shaders"))
			return;
		var sdlGpu = Context.definedValue("helix-backend") == "sdl3-gpu" || Context.defined("helix_sdl3_gpu");
		step(() -> new ShaderPacker(library()).packShaders(".", [], directory == null ? "assets/shaders" : directory, sdlGpu, false, true));
	}

	/** Once the browser build is written, everything in its output directory removed but its JavaScript. */
	public static function cleanOutput(?directory:String):Void {
		after(() -> {
			if (Context.defined("cpp") && directory == null)
				throw new CommandError("cleanOutput: a native build's output directory is hxcpp's working directory; copyProgram into one of its own");
			var target = output(directory),
				script = Files.resolve(Sys.getCwd(), Compiler.getOutput());
			var game = Files.resolve(Sys.getCwd(), ".");
			if (Files.contains(target, game))
				throw new CommandError('cleanOutput: ${Files.relative(target, game)} holds the game itself; build into a directory of its own (out/dist)');
			for (name in FileSystem.readDirectory(target)) {
				var path = Path.join([target, name]);
				if (Files.isDirectory(path))
					Files.removeDirectory(path);
				else if (Path.normalize(path) != script)
					FileSystem.deleteFile(path);
			}
		});
	}

	/** Once the browser build is written, its page beside it: index.html and favicon.svg each when it isn't there, config.json each build. */
	public static function generateWebPage(?directory:String):Void {
		var root = library();
		after(() -> {
			var target = output(directory),
				game = Files.resolve(Sys.getCwd(), ".");
			var config = Path.join([game, "config.json"]);
			var hasConfig = Files.isFile(config);
			if (hasConfig)
				File.copy(config, Path.join([target, "config.json"]));
			var icon = Path.join([target, "favicon.svg"]);
			if (!Files.isFile(icon)) {
				var own = Path.join([game, "favicon.svg"]);
				File.copy(Files.isFile(own) ? own : Path.join([root, "templates", "starter", "favicon.svg"]), icon);
			}
			var page = Path.join([target, "index.html"]);
			if (Files.isFile(page))
				return;
			var text = File.getContent(Path.join([root, "templates", "index.html"]));
			text = StringTools.replace(text, "{{title}}", Path.withoutDirectory(game));
			text = StringTools.replace(text, "{{meta}}", hasConfig ? '<meta name="helix-config" content="config.json">' : "");
			File.saveContent(page, StringTools.replace(text, '<script src="app.js">', '<script src="${Path.withoutDirectory(Compiler.getOutput())}">'));
		});
	}

	/** Once the build is written, the game's assets/ copied into directory. */
	public static function copyAssets(?directory:String):Void {
		after(() -> {
			var game = Files.resolve(Sys.getCwd(), "."),
				assets = Path.join([game, "assets"]);
			if (!Files.isDirectory(assets))
				return;
			var target = Path.join([output(directory), "assets"]);
			Files.removeDirectory(target);
			var count = Files.copyDirectory(assets, target);
			Sys.println('copyAssets: ${Files.relative(target, game)} ($count files)');
		});
	}

	/** Once the native build is written, its program and the libraries beside it copied into directory. */
	public static function copyProgram(directory:String):Void {
		after(() -> {
			if (!Context.defined("cpp"))
				throw new CommandError("copyProgram: a native build's step: this build writes no program");
			var built = Files.resolve(Sys.getCwd(), Compiler.getOutput()),
				target = Files.resolve(Sys.getCwd(), directory);
			var main = Compiler.getConfiguration().mainClass;
			var name = (main == null ? "Main" : main.name) + (Context.defined("debug") ? "-debug" : "") + (Sys.systemName() == "Windows" ? ".exe" : "");
			if (!Files.isFile(Path.join([built, name])))
				throw new CommandError('copyProgram: ${Path.join([built, name])} is not there');
			Files.makeDirectory(target);
			for (file in FileSystem.readDirectory(built))
				if (file == name || ~/\.(dll|so|dylib)(\.[0-9.]+)?$/.match(file))
					File.copy(Path.join([built, file]), Path.join([target, file]));
			if (Sys.systemName() != "Windows")
				Sys.command("chmod", ["755", Path.join([target, name])]);
			Sys.println('copyProgram: ${Files.relative(Path.join([target, name]), Files.resolve(Sys.getCwd(), "."))}');
		});
	}

	/** Once the build is written, directory written as a zip at path, its files at the zip's root. */
	public static function zipOutput(path:String, ?directory:String):Void {
		after(() -> {
			var game = Files.resolve(Sys.getCwd(), "."),
				source = output(directory),
				archive = Files.resolve(game, path);
			Files.zipDirectory(source, archive, archive);
			Sys.println('zipOutput: ${Files.relative(archive, game)} (${Std.int(FileSystem.stat(archive).size / 1024)} KB), from ${Files.relative(source, game)}');
		});
	}

	// directory resolved against the game's, or the build's output directory: the -js file's, or the -cpp one.
	static function output(directory:Null<String>):String {
		if (directory != null)
			return Files.resolve(Sys.getCwd(), directory);
		var out = Files.resolve(Sys.getCwd(), Compiler.getOutput());
		return Context.defined("js") ? Path.directory(out) : out;
	}

	// The library's directory (dependencies.json, templates/, the shader kinds), this file's three levels up from src/helix/tool.
	static function library():String
		return Path.normalize(Path.join([Path.directory(Context.resolvePath("helix/tool/Build.hx")), "..", "..", ".."]));

	// A step run once the build has written its output, not for a build that wrote nothing (--no-output, an editor's completion).
	static function after(run:() -> Void):Void {
		Context.onAfterGenerate(() -> {
			if (!Context.defined("display") && FileSystem.exists(Compiler.getOutput()))
				step(run);
		});
	}

	// A step run, its refusal said plainly and the build ended.
	static function step(run:() -> Void):Void {
		try {
			run();
		} catch (error:CommandError) {
			Sys.stderr().writeString(error.message + "\n");
			Sys.exit(1);
		}
	}
	#end
}
