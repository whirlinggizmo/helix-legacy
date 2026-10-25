package helix.tool.setup;

import helix.tool.shared.CommandError;
import helix.tool.shared.Downloads;
import helix.tool.shared.Files;
import haxe.io.Path;

/** `autopilot`: plays one of the game's autopilot scripts in a headless Chromium and prints what the game published. It builds the release
	(hxml/build.dist.hxml, into out/dist/), serves out/dist/ on a free port of this machine (the script copied in as it is now), and opens
	the page with the script, sound off and ticks fast. The runner is the library's tools/autopilot.cjs, on Node. Playwright (the version dependencies.json pins) and its
	Chromium are fetched into the user's cache for HeliX's tools the first time, with npm; a Chromium of the user's own can be named
	instead. */
class AutopilotTool {
	/** Plays script (a path under assets/, given with or without "assets/") for the game in the current directory, the library at root:
		built first unless build is false, in browser (a Chromium's path) or Playwright's own when null. Returns the runner's exit code: 0
		when the script ran to its end, 1 when it failed (its message on the standard error). Refuses a script that isn't there, a release
		build that fails, and a machine without Node. */
	public static function run(root:String, script:String, build:Bool, ?browser:String):Int {
		var under = StringTools.startsWith(script, "assets/") ? script.substr("assets/".length) : script;
		if (!Files.isFile(Path.join(["assets", under])))
			throw new CommandError('autopilot: no script assets/$under (a script goes under assets/, assets/autopilot/run.json say)');
		if (browser != null && !Files.isFile(browser))
			throw new CommandError('autopilot: --browser names $browser, which isn\'t a file');
		if (build) {
			if (!Files.isFile("hxml/build.dist.hxml"))
				throw new CommandError("autopilot: no hxml/build.dist.hxml here to build the release with (run it from the game's directory, or pass --no-build)");
			Downloads.say("autopilot: building the release (hxml/build.dist.hxml)");
			if (Sys.command("haxe hxml/build.dist.hxml 1>&2") != 0)
				throw new CommandError("autopilot: the release build failed");
		}
		if (!Files.isFile("out/dist/index.html"))
			throw new CommandError("autopilot: no out/dist/index.html: build the release first (haxe hxml/build.dist.hxml)");
		// The script as it is now, so one edited since the build (or with --no-build) is the one played.
		Files.writeText(Path.join(["out/dist/assets", under]), sys.io.File.getContent(Path.join(["assets", under])));
		if (Sys.command(Sys.systemName() == "Windows" ? "node --version 1>NUL 2>NUL" : "node --version 1>/dev/null 2>&1") != 0)
			throw new CommandError("autopilot: it runs on Node.js, and there's no node here: install Node.js (nodejs.org), then run it again");
		var playwright = playwright(root, browser == null);
		Sys.putEnv("HELIX_PLAYWRIGHT", playwright.module);
		Sys.putEnv("PLAYWRIGHT_BROWSERS_PATH", playwright.browsers);
		var page = '/?autopilot=${StringTools.urlEncode(under)}&autoclose=1&audio=0&fast=1';
		return Sys.command("node", [
			Path.join([root, "tools", "autopilot.cjs"]),
			browser != null ? browser : "",
			page,
			"out/dist"
		]);
	}

	/** Playwright at the version dependencies.json pins, in the user's cache, installed with npm when it's missing, and its Chromium too when
		chromium: the directory of its module, and where its browsers are kept. */
	static function playwright(root:String, chromium:Bool):{module:String, browsers:String} {
		var pins:Dynamic = haxe.Json.parse(sys.io.File.getContent(Path.join([root, "dependencies.json"])));
		var version:String = pins.nodePackages.playwright;
		var directory = Path.join([Downloads.cache(), 'playwright-$version']),
			browsers = Path.join([Downloads.cache(), "playwright-browsers"]);
		var module = Path.join([directory, "node_modules", "playwright"]);
		if (!Files.isFile(Path.join([module, "package.json"]))) {
			Downloads.say('autopilot: installing Playwright $version into $directory (npm, once)');
			Files.makeDirectory(directory);
			if (Sys.command('npm install --prefix "$directory" --no-save --no-audit --no-fund playwright@$version 1>&2') != 0)
				throw new CommandError('autopilot: npm couldn\'t install Playwright $version (npm comes with Node.js; is the network there?)');
		}
		if (chromium) {
			Sys.putEnv("PLAYWRIGHT_BROWSERS_PATH", browsers);
			// Playwright skips a browser it already has, so this is quick after the first time.
			if (Sys.command('node "${Path.join([module, "cli.js"])}" install chromium-headless-shell 1>&2') != 0)
				throw new CommandError("autopilot: Playwright couldn't fetch its Chromium (is the network there? --browser names one of your own)");
		}
		return {module: module, browsers: browsers};
	}
}
