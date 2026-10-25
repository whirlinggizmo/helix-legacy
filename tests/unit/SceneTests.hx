import helix.asset.Assets;
import helix.asset.IAssets;
import helix.asset.AssetCacheMode;
import helix.asset.AssetProgress;
import helix.asset.EnsureOptions;
import helix.host.Presentation;
import helix.input.Input;
import helix.input.InputState;
import helix.render2d.Node2D;
import helix.render2d.Stage;
import helix.render2d.StageService;
import helix.scene.Loader;
import helix.scene.LoadingScreen;
import helix.scene.SplashScreen;
import helix.scene.transition.Transition;
import helix.scene.transition.Fade;
import helix.time.Time;

/** The screens that run themselves on the stage (docs/DISPLAY_MODEL.md): a transition swapping what's shown at its middle and taking its cover
	off at its end; the loading screen shown until its loader is done, held for a press when asked; the splash leaving after its seconds and a
	press, or after its most wait; and the Loader's counting, progress and failures over held loads. Their frames are ticked here by hand
	(Flow.tick), the stage bound as the runner would; nothing is drawn but the stage's own walk. */
@:access(helix)
class SceneTests {
	static var checks = 0;
	public static var log:Array<String> = [];
	// The loads the test's assets hold, by path: what each does when it loads and when it fails.
	public static var held:Map<String, {loaded:haxe.io.Bytes->Void, failed:String->Void}> = [];

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function took():String {
		var s = log.join(",");
		log = [];
		return s;
	}

	static function main():Void {
		// What the screens and the Loader read, bound as the runner would.
		@:privateAccess Assets.bind(new Held());
		var input = new InputState();
		@:privateAccess Input.bind(input);
		@:privateAccess Time.bind(null, new helix.time.Clock());
		var presentation = new Presentation();
		@:privateAccess presentation.refit(800, 600, 1);
		@:privateAccess helix.host.Screen.bind(presentation);
		var stage = new StageService(new Render2DTests.CountingGraphics(), presentation);
		@:privateAccess Stage.bind(stage);
		function frame(dt:Float):Void {
			@:privateAccess helix.scene.Flow.tick(dt);
			input.endFrame();
		}

		// A transition swaps at its middle, its cover over what's shown, and leaves at its end.
		var title = new Node2D(), level = new Node2D();
		Stage.addChild(title);
		var ended = false, fade = new Fade(1);
		check(fade.swap(title, level, () -> ended = true)
			&& fade.running
			&& Stage.childCount == 2, "Running: its cover on the stage over the title");
		check(!fade.swap(level, title), "Refused while it runs");
		frame(.4);
		check(title.parent != null && level.parent == null, "Before the middle, the title still shown");
		frame(.2);
		check(title.parent == null && level.parent != null && Stage.childCount == 2, "Past the middle: swapped, the cover still over the level");
		frame(.5);
		check(ended && !fade.running && Stage.childCount == 1 && level.parent != null, "Done: its cover off, done called");
		check(new Transition(1).run(() -> {}) && throws(() -> new Transition(0)), "A transition of no time is refused");
		frame(2);
		// A delay, a hold and an ease: nothing drawn until the delay is out, swapped at the middle and held covered, each half along its curve.
		var seenProgress:Array<Float> = [];
		var timed = new Probe(1, seenProgress), swappedAt = false, over = false;
		timed.delay = .5;
		timed.hold = .25;
		timed.coverEase = t -> helix.tween.Ease.quadIn(t);
		timed.uncoverEase = t -> helix.tween.Ease.quadOut(t);
		timed.delay = -1;
		check(timed.delay == 0, "A delay below 0 is none");
		timed.delay = .5;
		timed.run(() -> swappedAt = true, () -> over = true);
		frame(.4);
		check(seenProgress.length == 0 && timed.running, "Waiting out its delay: nothing drawn");
		frame(.35);
		check(Math.abs(seenProgress[seenProgress.length - 1] - .5 * .25) < 1e-9 && !swappedAt,
			"Covering along its ease: halfway through the time, quadIn a quarter of the way");
		frame(.3);
		check(swappedAt && seenProgress[seenProgress.length - 1] == .5, "Swapped at the middle, then held covered");
		frame(.2);
		check(seenProgress[seenProgress.length - 1] == .5 && !over, "Still held");
		frame(.3);
		check(Math.abs(seenProgress[seenProgress.length - 1] - (.5 + .5 * helix.tween.Ease.quadOut((1.05 - .75) / .5))) < 1e-9 && !over,
			"Uncovering after the hold, along its own ease (quadOut)");
		frame(.3);
		check(over && !timed.running, "Done after delay, both halves and the hold");
		// In halves: cover covers and stays covered until uncover (game over, a load under the cover); uncover alone starts covered (a fade
		// in from black); uncover while still covering waits for covered.
		var halves = new Probe(1, seenProgress),
			coveredNow = false,
			uncoveredNow = false;
		check(halves.cover(() -> coveredNow = true) && !halves.cover(), "Covering; a second cover refused");
		frame(.6);
		check(coveredNow && halves.covered && seenProgress[seenProgress.length - 1] == .5, "Covered after coverSeconds, done called");
		frame(5);
		check(halves.covered && halves.running && seenProgress[seenProgress.length - 1] == .5, "Stays covered with no hold");
		check(halves.uncover(() -> uncoveredNow = true) && !halves.covered, "Uncovering on asking");
		frame(.6);
		check(uncoveredNow && !halves.running && Stage.childCount == 1, "Uncovered, its cover off the stage");
		var fadeIn = new Probe(1, seenProgress), inDone = false;
		check(fadeIn.uncover(() -> inDone = true) && fadeIn.running, "Uncover alone: running, from covered");
		frame(.01);
		check(seenProgress[seenProgress.length - 1] > .5 && seenProgress[seenProgress.length - 1] < .6,
			"starting from covered: " + seenProgress[seenProgress.length - 1]);
		frame(.6);
		check(inDone && !fadeIn.running, "a fade in, done");
		var early = new Probe(1, seenProgress),
			earlyCovered = false,
			earlyDone = false;
		early.cover(() -> earlyCovered = true);
		frame(.2);
		check(early.uncover(() -> earlyDone = true) && !earlyCovered, "Uncover asked while covering");
		frame(.4);
		check(earlyCovered && !earlyDone, "covers first");
		frame(.6);
		check(earlyDone && !early.running, "then uncovers");
		// The time split unevenly: a quick close, a slow open.
		var split = new Probe(1, seenProgress),
			splitSwapped = false,
			splitDone = false;
		split.coverSeconds = .2;
		split.uncoverSeconds = .8;
		check(split.seconds == 1, "Its seconds the two halves together");
		split.coverSeconds = -1;
		check(split.coverSeconds == 0, "A half below 0 is none");
		split.coverSeconds = .2;
		split.run(() -> splitSwapped = true, () -> splitDone = true);
		frame(.1);
		check(Math.abs(seenProgress[seenProgress.length - 1] - .25) < 1e-9
			&& !splitSwapped, "Halfway through a .2 second close: a quarter");
		frame(.15);
		check(splitSwapped && !splitDone, "Swapped after .2 seconds");
		frame(.4);
		check(Math.abs(seenProgress[seenProgress.length - 1] - (.5 + .5 * (.25 + .4 - .2) / .8)) < 1e-9 && !splitDone, "Opening over .8");
		frame(.4);
		check(splitDone, "Done after the two");
		// A hold between an uneven close and open: covered from the swap through the hold, then opening.
		var holding = new Probe(1, seenProgress),
			holdSwapped = false,
			holdDone = false;
		holding.coverSeconds = .2;
		holding.uncoverSeconds = .8;
		holding.hold = .5;
		holding.run(() -> holdSwapped = true, () -> holdDone = true);
		frame(.3);
		check(holdSwapped && holding.progress == .5, "Swapped and covered after the close");
		frame(.35);
		check(holding.progress == .5 && !holdDone, "Still covered through the hold");
		frame(.2);
		check(holding.progress > .5 && !holdDone, "Opening once the hold is out");
		frame(.8);
		check(holdDone, "Done after the close, the hold and the open");

		// The loading screen: shown until its loader is done, then off, then called.
		var loader = new Loader();
		loader.loadAsset("a.txt", _ -> {});
		loader.loadAsset("b.txt", _ -> {});
		var loading = new LoadingScreen(loader), started = false;
		check(loading.show(() -> started = true) && loading.shown && !loading.show(() -> {}), "Shown, once");
		frame(1 / 60);
		check(!started && Stage.childCount == 2, "Waiting, on the stage over the level");
		held["a.txt"].loaded(haxe.io.Bytes.alloc(1));
		check(loader.progress == .5 && !loader.done, "Half the loads in");
		held["b.txt"].failed("gone");
		check(loader.done && loader.failures.join(",") == "b.txt: gone", "All ended, a failure named");
		frame(1 / 60);
		check(started && !loading.shown && Stage.childCount == 1, "Done: off the stage, then called");

		// Held for a press once loaded.
		var holding = new LoadingScreen(new Loader()), went = false;
		holding.holdForPress = true;
		holding.show(() -> went = true);
		frame(1 / 60);
		frame(1 / 60);
		check(!went && holding.shown, "Loaded, held for a press");
		input.keyEvent(Space, true);
		frame(1 / 60);
		check(went && !holding.shown, "A press lets it go");
		input.keyEvent(Space, false);

		// The splash: at least its seconds, and a press (already come above); or its most wait without one.
		var splash = new SplashScreen(null, 1, new Fade(.5)), next = false;
		check(splash.show(() -> next = true) && !splash.show(() -> {}), "Shown, once");
		frame(.5);
		check(!next && splash.elapsed == .5, "Before its seconds");
		frame(.6);
		frame(.3);
		check(next, "After its seconds, the press come: its transition's middle calls next");
		frame(1);
		check(Stage.childCount == 1, "Gone from the stage, its cover too");
		@:privateAccess Input.bind(new InputState());
		var patient = new SplashScreen(null, .1), onward = false;
		patient.maxWait = 2;
		patient.show(() -> onward = true);
		frame(1);
		check(!onward, "No press: it waits");
		frame(1.1);
		frame(1);
		check(onward, "Past its most wait it goes on without one");
		@:privateAccess Input.bind(input);
		// Coming in by its entrance (uncovered as shown), its logo's place known, and an iris as its exit aimed there.
		var iris = new helix.scene.transition.Iris(.4),
			entering = new Fade(.4);
		var aimed = new SplashScreen(null, .1, iris), went = false;
		aimed.entrance = entering;
		aimed.show(() -> went = true);
		check(entering.running && !Math.isNaN(aimed.logoX) && !Math.isNaN(aimed.logoY), "Its entrance running as it's shown; its logo's place known");
		frame(.5);
		check(!entering.running && iris.running && iris.pointX == aimed.logoX && iris.pointY == aimed.logoY,
			"Its entrance done; its iris exit closing on the logo");
		frame(1);
		check(went && Stage.childCount == 1, "Gone, next called");
		// An iris following a node closes wherever the node is each frame, not where it was when set; setPoint fixes it again.
		var aim = new helix.scene.transition.Iris(1),
			marker = new helix.render2d.Node2D();
		marker.setPosition(100, 50);
		Stage.addChild(marker);
		aim.follow(marker);
		stage.draw(0);
		check(@:privateAccess aim.centerX(0, 800) == 100 && @:privateAccess aim.centerY(0, 600) == 50, "Following: the node's place");
		marker.setPosition(300, 200);
		stage.draw(0);
		check(@:privateAccess aim.centerX(0, 800) == 300 && @:privateAccess aim.centerY(0, 600) == 200, "The node moved (a resize): the point with it");
		aim.setPoint(10, 20);
		check(aim.followed == null && @:privateAccess aim.centerX(0, 800) == 10, "setPoint: fixed again");
		aim.setPoint(Math.NaN, Math.NaN);
		check(@:privateAccess aim.centerX(0, 800) == 400, "Neither: the middle");
		Stage.removeChild(marker);

		// Things collected: they burst, fly to the target one after another, each told on arrival, then all done and off the stage.
		var score = new Node2D();
		score.setPosition(700, 40);
		Stage.addChild(score);
		var before = Stage.childCount, got = [], finished = false;
		var coins = new helix.scene.Collect2D(helix.texture.Texture2D.fromRgba(1, 1, haxe.io.Bytes.alloc(4), Nearest, -1, -1, false,
			new Render2DTests.CountingGraphics()), 5);
		check(coins.run(100, 500, score, i -> got.push(i), () -> finished = true)
			&& coins.running
			&& !coins.run(0, 0, score), "Running, once");
		check(Stage.childCount == before + 1, "Its sprites on the stage");
		frame(coins.scatterSeconds);
		check(got.length == 0, "Scattered, none in yet");
		frame(coins.flySeconds + .001);
		check(got.length == 1 && got[0] == 0, "The first in, the others still flying");
		for (_ in 0...10)
			frame(coins.stagger);
		check(got.join(",") == "0,1,2,3,4" && finished && !coins.running && Stage.childCount == before, "All in, in turn: done, off the stage");
		Stage.removeChild(score);

		// In 3D: they burst from a point in the level's units (the level placed off the origin), go under the level while they fly, and arc
		// in to the target (a group: its position) one after another.
		var level3 = new helix.render3d.Node3D(),
			chest = new helix.render3d.Node3D();
		level3.setPosition(10, 0, 0);
		chest.setPosition(0, 2, 0);
		level3.addChild(chest);
		var got3 = [], finished3 = false;
		var gems = new helix.scene.Collect3D(helix.texture.Texture2D.fromRgba(1, 1, haxe.io.Bytes.alloc(4), Nearest, -1, -1, false,
			new Render2DTests.CountingGraphics()), 3);
		check(gems.run(0, 0, 5, chest, i -> got3.push(i), () -> finished3 = true) && !gems.run(0, 0, 0, chest), "3D: running, once");
		check(level3.childCount == 2, "3D: its sprites under the level");
		var first = level3.getChild(1).getChild(0);
		frame(gems.scatterSeconds);
		check(first.y > 0
			&& Math.abs(first.x) + Math.abs(first.z - 5) <= gems.scatter
			&& got3.length == 0, "3D: scattered up and out, none in yet");
		frame(gems.flySeconds - .001);
		check(Math.abs(first.x) < .1 && Math.abs(first.y - 2) < .1 && Math.abs(first.z) < .1, "3D: the first nearly at the target, in the level's units");
		frame(.002);
		check(got3.join(",") == "0", "3D: the first in");
		for (_ in 0...4)
			frame(gems.stagger);
		check(got3.join(",") == "0,1,2" && finished3 && !gems.running && level3.childCount == 1, "3D: all in, in turn: done, out of the level");

		// The wipes, drawn into a cover over a 100 x 50 area at a progress, judged by what they cover.
		var cover = new helix.render2d.Drawing2D(),
			seen = new helix.math.Bounds2D();
		function covered(t:Transition, progress:Float):Null<helix.math.Bounds2D> {
			cover.clear();
			t.draw(cover, 0, 0, 100, 50, progress);
			return cover.computeBounds(cover, seen);
		}
		inline function spans(b:Null<helix.math.Bounds2D>, minX:Float, maxX:Float, minY:Float, maxY:Float):Bool
			return b != null && Math.abs(b.minX - minX) < 1e-6 && Math.abs(b.maxX - maxX) < 1e-6 && Math.abs(b.minY - minY) < 1e-6
				&& Math.abs(b.maxY - maxY) < 1e-6;
		var left = new helix.scene.transition.Slide(1, Left);
		check(spans(covered(left, .25), 50, 100, 0, 50), "A slide left comes in from the right");
		check(spans(covered(left, .75), 0, 50, 0, 50), "And goes on out to the left");
		check(spans(covered(new helix.scene.transition.Slide(1, Left, true), .75), 50, 100, 0, 50), "Or back out the way it came");
		check(spans(covered(new helix.scene.transition.Slide(1, Down), .25), 0, 100, 0, 25), "A slide down comes in from the top");
		var corner = covered(new helix.scene.transition.Slide(1, DownRight), .1);
		check(corner != null && corner.minX == 0 && corner.minY == 0 && corner.maxX < 50 && corner.maxY < 50, "A diagonal one comes in from its corner");
		check(spans(covered(new helix.scene.transition.Iris(1), .5), 0, 0 + 100, 0, 50)
			&& spans(covered(new helix.scene.transition.Diamond(1), .5), 0, 100, 0, 50),
			"An iris and a diamond cover all at the middle");
		var iris = new helix.scene.transition.Iris(1);
		iris.setPoint(90, 10);
		var open = covered(iris, .4);
		check(open != null && open.maxX > 100 && open.minY < 0, "On a point near a corner, its cover reaches past it to close there");
		var noise = new helix.scene.transition.Noise(1, 10);
		check(covered(noise, 0) == null && spans(covered(noise, .4999), 0, 100, 0, 50) && covered(noise, 1) == null,
			"Noise: nothing at the start, all just before the middle, nothing at the end");
		var part = covered(noise, .2);
		check(part != null, "Noise part way: some squares");

		// The loader by itself.
		var loader = new Loader();
		check(loader.done && loader.progress == 1 && loader.count == 0, "An empty loader is done");
		var got:Null<String> = null;
		var complete = loader.countLoad("thing", (v:Int) -> got = 'got $v', v -> v < 0 ? "negative" : null);
		check(!loader.done && loader.count == 1, "wrap counts a load");
		complete(-1);
		check(loader.done && got == "got -1" && loader.failures[0] == "thing: negative", "its completion runs and a failure is named");
		@:privateAccess Stage.bind(null);
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}

	static function throws(f:Void->Void):Bool {
		try
			f()
		catch (e:Dynamic)
			return true;
		return false;
	}
}

/** Assets whose loads the test releases by path. */
@:access(helix)
private class Held implements IAssets {
	public function new() {}

	public function load(path:String, loaded:haxe.io.Bytes->Void, ?failed:String->Void):helix.asset.IRequest
		return ensure(path, loaded, failed);

	public function ensure(path:String, loaded:haxe.io.Bytes->Void, ?failed:String->Void, ?progress:helix.asset.AssetProgress->Void,
			?options:helix.asset.EnsureOptions):helix.asset.IRequest {
		@:privateAccess SceneTests.held[path] = {loaded: loaded, failed: message -> helix.asset.Failure.report(path, message, failed)};
		return new helix.asset.Request(() -> {});
	}

	public var host(get, never):Null<String>;

	function get_host():Null<String>
		return null;

	public function setHost(host:Null<String>):Bool
		return false;

	public function pingHost(host:String, probePath:String, timeoutSeconds:Float, complete:Bool->Void):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public function clearCache(complete:helix.asset.StorageWriteResult->Void):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public var manifest(get, never):Null<String>;

	function get_manifest():Null<String>
		return null;

	public function setManifest(path:Null<String>):Bool
		return true;

	public var cacheMode(get, set):helix.asset.AssetCacheMode;

	function get_cacheMode():helix.asset.AssetCacheMode
		return Revalidate;

	function set_cacheMode(mode:helix.asset.AssetCacheMode):helix.asset.AssetCacheMode {
		return mode;
	}

	public function streamSource(path:String, located:helix.asset.IAssets.AudioLocation->Void, ?failed:String->Void, download:Bool = false):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public function subscribe(path:String, target:helix.asset.IReloadable):Void {}

	public function unsubscribe(path:String, target:helix.asset.IReloadable):Void {}

	public var busy(get, never):Bool;

	function get_busy():Bool
		return false;
}

/** A transition recording each progress it's drawn at. */
class Probe extends Transition {
	var seen:Array<Float>;

	public function new(seconds:Float, seen:Array<Float>) {
		super(seconds);
		this.seen = seen;
	}

	override public function draw(cover:helix.render2d.Drawing2D, x:Float, y:Float, width:Float, height:Float, progress:Float):Void
		seen.push(progress);
}
