package helix.render2d;

/** The stage: what the program shows, drawn by the runner after every update (StageService; docs/DISPLAY_MODEL.md). Installed by its first
	use, so a program that never uses it carries none of it. The program's one, a static class: each member forwards to instance, written by
	helix.macro.Facade from StageService's public members with their doc comments. */
@:build(helix.macro.Facade.build(helix.render2d.StageService, ["draw", "destroy"], helix.render2d.StageService.install))
class Stage {
	/** The stage forwarded to: installed by its first use (an optional part, helix.host.Part) until the program's end, null before and after. Kept across a hot reload (@:hot): set once by the runner, nothing would set it again. */
	@:hot @:allow(helix) static var instance(default, null):StageService;

	/** The first node named name on the stage (depth first, in drawing order), as kind, or null when there's none or it isn't a kind:
		`var score = Stage.find("score", Text2D);` (Node.find). */
	public static function find<T:Node2D>(name:String, kind:Class<T>):Null<T>
		return service().find(name, kind);
}
