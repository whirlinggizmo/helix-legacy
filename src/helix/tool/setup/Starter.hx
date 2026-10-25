package helix.tool.setup;

import helix.tool.shared.CommandError;
import helix.tool.shared.Files;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/** `init`: the starter game (templates/starter: src/Main.hx and src/Game.hx, its builds in hxml/, assets/, .gitignore, VS Code's settings for
	the Haxe extension (.vscode/settings.json, its completion from the browser build), HTTPS for a phone (docker-compose.yml, tls/) and a
	README with the commands) written into a directory, each file's {name} the game's (its directory's name, "." the current one's) and
	{title} its title; or one of the library's examples as a game, the starter around it. The directory may be new, empty, or a repository
	just made (a .git/, a README, a LICENSE): a .gitignore there gets the starter's lines it lacks, a README the starter's below its own,
	and any other file the starter has is kept as it is. */
class Starter {
	/** The starter written into directory (made when missing) from the library at root, or with example (the name of a directory in the
		library's examples/) the example as a game: its App in src/ (an example's App.hx or every file of its src/, in place of Game.hx, Main.hx
		starting App), the examples' shared assets and its own in assets/ (its scripts for the autopilot as assets/autopilot/<example>/, as
		the examples load them), its shaders/ and its config.json. Refuses a file, a directory that already has a game's parts (src/, hxml/,
		assets/, shaders/ or config.json), and an example the library hasn't, listing those it has. Returns the files written (and added to),
		and those kept as they were, relative to directory. */
	public static function write(root:String, directory:String, ?example:String):{written:Array<String>, kept:Array<String>} {
		if (Files.isFile(directory))
			throw new CommandError('init: $directory is a file; a starter goes in a directory');
		var taken = [
			for (part in ["src", "hxml", "assets", "shaders", "config.json"])
				if (FileSystem.exists(Path.join([directory, part]))) part
		];
		if (taken.length > 0)
			throw new CommandError('init: $directory already has ${taken.join(", ")}; a starter goes in a new directory, or one with only a repository\'s files (.git/, a README, a LICENSE)');
		var source = example != null ? exampleSource(root, example) : null;
		var name = Path.withoutDirectory(Files.resolve(Sys.getCwd(), directory));
		var template = Path.join([root, "templates", "starter"]);
		var written = [], kept = [];
		for (relative in Files.listFiles(template)) {
			if (source != null && relative == "src/Game.hx")
				continue;
			var text = StringTools.replace(StringTools.replace(File.getContent(Path.join([template, relative])), "{name}", name), "{title}", title(name));
			if (source != null && relative == "src/Main.hx")
				text = ~/\bGame\b/g.replace(text, "App");
			if (source != null && relative == "README.md")
				text = StringTools.replace(text, "`src/Game.hx` is the game", '`src/App.hx` is the game (HeliX\'s example $example)');
			var target = Path.join([directory, relative]);
			if (Files.isFile(target)) {
				var mine = File.getContent(target);
				if (relative == ".gitignore") {
					// The starter's lines the game's lacks, added.
					var lines = mine.split("\n").map(StringTools.trim);
					var missing = [for (line in text.split("\n")) if (line != "" && lines.indexOf(line) < 0) line];
					text = missing.length == 0 ? mine : (StringTools.endsWith(mine, "\n") || mine == "" ? mine : mine + "\n") + missing.join("\n") + "\n";
				} else if (relative == "README.md")
					text = StringTools.rtrim(mine) + "\n\n" + text;
				else {
					kept.push(relative);
					continue;
				}
			}
			Files.writeText(target, text);
			written.push(relative);
		}
		// The game's files go in assets/, empty to begin with (the README says so): nothing in it ships that isn't the game's.
		Files.makeDirectory(Path.join([directory, "assets"]));
		if (source != null) {
			var own = Path.join([root, "examples", example]);
			if (source == own) {
				for (file in FileSystem.readDirectory(own))
					if (StringTools.endsWith(file, ".hx"))
						written.push(copy(own, file, directory, 'src/$file'));
			} else
				for (file in Files.listFiles(source))
					written.push(copy(source, file, directory, 'src/$file'));
			for (file in Files.listFiles(Path.join([root, "examples", "assets"])))
				written.push(copy(Path.join([root, "examples", "assets"]), file, directory, 'assets/$file'));
			for (part in [
				["assets", "assets"],
				["autopilot", 'assets/autopilot/$example'],
				["shaders", "shaders"]
			]) {
				var from = Path.join([own, part[0]]);
				if (Files.isDirectory(from))
					for (file in Files.listFiles(from))
						if (!StringTools.endsWith(file, ".py") && file.indexOf("__pycache__") < 0)
							written.push(copy(from, file, directory, '${part[1]}/$file'));
			}
			if (Files.isFile(Path.join([own, "config.json"])))
				written.push(copy(own, "config.json", directory, "config.json"));
		}
		// An example's own asset over a shared one of the same path is one file.
		var unique = [];
		for (file in written)
			if (unique.indexOf(file) < 0)
				unique.push(file);
		return {written: unique, kept: kept};
	}

	/** The library's examples at root: the directories of its examples/ holding an App.hx, or a src/App.hx; none when it has no examples. */
	public static function examples(root:String):Array<String> {
		var directory = Path.join([root, "examples"]);
		if (!Files.isDirectory(directory))
			return [];
		var names = [
			for (name in FileSystem.readDirectory(directory))
				if (Files.isFile(Path.join([directory, name, "App.hx"]))
					|| Files.isFile(Path.join([directory, name, "src", "App.hx"]))) name
		];
		names.sort(Reflect.compare);
		return names;
	}

	// The directory holding example's App.hx: its src/ for a larger example, else its own; refused, the examples listed, when there's none.
	static function exampleSource(root:String, example:String):String {
		if (examples(root).indexOf(example) < 0) {
			var names = examples(root);
			throw new CommandError(names.length == 0 ? 'init: no example $example; this copy of helix has no examples/' : 'init: no example $example; the examples: ${names.join(", ")}');
		}
		var own = Path.join([root, "examples", example]),
			larger = Path.join([own, "src"]);
		return Files.isFile(Path.join([larger, "App.hx"])) ? larger : own;
	}

	// The file at from/relative copied to directory/to, its directory made; returns to.
	static function copy(from:String, relative:String, directory:String, to:String):String {
		var target = Path.join([directory, to]);
		Files.makeDirectory(Path.directory(target));
		File.copy(Path.join([from, relative]), target);
		return to;
	}

	/** The title a directory's name gives: its words (apart by -, _ or spaces) capitalized, "my-jam-game" My Jam Game; Game when it has none. */
	public static function title(name:String):String {
		var words = [
			for (word in ~/[-_\s]+/g.split(name))
				if (word != "") word.charAt(0).toUpperCase() + word.substr(1)
		];
		return words.length > 0 ? words.join(" ") : "Game";
	}
}
