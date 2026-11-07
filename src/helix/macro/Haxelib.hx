package helix.macro;

#if macro
import haxe.io.Path;
import haxe.macro.Compiler;
import haxe.macro.Context;
import sys.io.Process;
#end

/** What a build on `-lib helix-legacy` needs beyond the library's class path, run by the library's extraParams.hxml
	(`--macro helix.macro.Haxelib.configure()`), so a game's hxml carries nothing of the library's layout:

	- the generated code's class paths, `generated/shaders` and `generated/fonts` at the library's root (the framework's programs, the
	  packed shader library and the built-in font, committed and shipped: docs/DECISIONS.md 138), and `generated/shaders-sdlgpu` for an
	  SDL_GPU build (SDL_GPU's dialects, which only its builds carry);
	- `helix_sdl3_gpu`, the define the programs carry SDL_GPU's dialects under, when the build names the `sdl3-gpu` backend
	  (`-D helix-backend=sdl3-gpu`), so a game's hxml writes the backend and nothing else of it;
	- in the browser, the page beside the `-js` output (`helix.tool.Build.generateWebPage`: `index.html` from the library's template,
	  `favicon.svg`, the game's `config.json`), so the dev loop's server has a page to serve;
	- natively, hxcpp's architecture define for this machine, `HXCPP_ARM64` on arm64 and `HXCPP_M64` elsewhere, when the build sets none
	  (hxcpp picks 32-bit on Windows from a 64-bit process, which has no `PROCESSOR_ARCHITEW6432`).

	The repository's own builds list the class paths and the defines themselves (`tools/example.py`), which is also what the dev loop watches. */
@:noCompletion
class Haxelib {
	#if macro
	/** Adds the generated code's class paths, the SDL_GPU dialects' define for an sdl3-gpu build and, natively, this machine's
		architecture define. */
	public static function configure():Void {
		var root = Path.normalize(Path.join([Path.directory(Context.resolvePath("helix/macro/Haxelib.hx")), "..", "..", ".."]));
		Compiler.addClassPath(Path.join([root, "generated", "shaders"]));
		Compiler.addClassPath(Path.join([root, "generated", "fonts"]));
		// An init macro's define reaches the conditional compilation of every file parsed after it, which is all of them.
		if (Context.definedValue("helix-backend") == "sdl3-gpu" && !Context.defined("helix_sdl3_gpu"))
			Compiler.define("helix_sdl3_gpu");
		if (Context.defined("helix_sdl3_gpu"))
			Compiler.addClassPath(Path.join([root, "generated", "shaders-sdlgpu"]));
		if (Context.defined("js"))
			helix.tool.Build.generateWebPage();
		if (Context.defined("cpp")
			&& !Context.defined("HXCPP_M64")
			&& !Context.defined("HXCPP_M32")
			&& !Context.defined("HXCPP_ARM64"))
			Compiler.define(isArm64() ? "HXCPP_ARM64" : "HXCPP_M64");
	}

	/** True on an arm64 machine (Apple silicon, Linux aarch64, Windows on ARM): hxcpp's own test, read from the process here. */
	static function isArm64():Bool {
		if (Sys.systemName() == "Windows") {
			var arch = Sys.getEnv("PROCESSOR_ARCHITEW6432");
			if (arch == null)
				arch = Sys.getEnv("PROCESSOR_ARCHITECTURE");
			return arch != null && arch.toUpperCase() == "ARM64";
		}
		var process = new Process("uname", ["-m"]);
		var output = process.stdout.readAll().toString();
		process.close();
		return output.indexOf("aarch64") >= 0 || output.indexOf("arm64") >= 0;
	}
	#end
}
