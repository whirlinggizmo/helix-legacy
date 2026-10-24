import haxe.io.Bytes;
import helix.asset.IAssets;
import helix.asset.AssetCacheMode;
import helix.asset.AssetProgress;
import helix.asset.EnsureOptions;
import helix.render3d.Gltf;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.ModelCache3D;
import helix.render3d.Models3D;
import helix.render3d.ModelFile3D;
import helix.render3d.ImageSource3D;
import helix.render3d.Node3D;

/** Characters dressed by slot (the dressing room example's Outfit, examples/dressing-room/src) from part files shared through a ModelCache3D, over the framework's queries
	(Node3D.collectModels, Model3D.bindSkeleton and Node3D.findAttachment), with Quaternius's modular women (the dressing-room and animation examples'): parts
	bound to the skeleton by joint name, held parts at a socket, choices before the skeleton and overtaken while loading, failures, and one load
	shared by many characters. */
@:access(helix)
class OutfitTests {
	static var checks = 0;
	// The loads the test's assets hold until released, by path, and how many each was asked for.
	static var held:Map<String, {loaded:Bytes->Void, failed:String->Void}> = [];
	static var asked:Map<String, Int> = [];

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function bytes(name:String):Bytes
		return sys.io.File.getBytes('examples/assets/models/modular-women/$name.glb');

	static function file(name:String):ModelFile3D
		return @:privateAccess new ModelFile3D(Gltf.read(bytes(name)));

	// Models over assets that answer only when the test releases a path (the part files carry no images, so no textures are needed).
	static function models():ModelCache3D
		return new ModelCache3D(new Held(), null);

	// Lets path's held load end with bytes.
	static function release(path:String, bytes:Bytes):Void {
		var load = held[path];
		held.remove(path);
		load.loaded(bytes);
	}

	// Lets path's held load fail with message.
	static function refuse(path:String, message:String):Void {
		var load = held[path];
		held.remove(path);
		load.failed(message);
	}

	// Whether node is character or under it.
	static function under(node:Null<Node3D>, character:Node3D):Bool {
		while (node != null) {
			if (node == character)
				return true;
			node = node.parent;
		}
		return false;
	}

	static function main():Void {
		var shared = models();
		for (name in ["Casual_Head", "Witch_Head", "Adventurer_Body", "Sword"])
			shared.put(name, file(name));
		var animations = file("Animations");
		var character = animations.instantiate("character");
		// The program's models are the test's: an outfit reads Models3D, as a game's does.
		@:privateAccess Models3D.bind(shared);
		var outfit = new Outfit();

		// Chosen before the skeleton: waits, then is worn on it.
		outfit.choose("head", "Casual_Head");
		check(outfit.pending && outfit.getWorn("head") == null, "A choice before the skeleton waits");
		outfit.skeleton = character;
		var head = outfit.getNodes("head");
		check(outfit.getWorn("head") == "Casual_Head" && head.length > 0 && !outfit.pending, "and is worn once it's given");
		var headModel:Model3D = cast head[0];
		check(head[0].parent == character && under(headModel.getJoint(0), character), "Its models are bound to the character's joints");

		// Swapped: the old part comes off.
		outfit.choose("head", "Witch_Head");
		check(outfit.getWorn("head") == "Witch_Head" && head[0].parent == null, "A new choice takes the old part off");
		outfit.choose("body", "Adventurer_Body");
		check(outfit.getWorn("body") == "Adventurer_Body" && outfit.getWorn("head") == "Witch_Head", "Slots are worn apart");

		// Held at a socket.
		outfit.choose("hand", "Sword", "Middle1.R");
		var sword = outfit.getNodes("hand");
		check(sword.length == 1 && sword[0].parent == character.find("Middle1.R", Node3D), "A held part hangs from its joint");
		var offset = sword[0].matrix.join(",");
		outfit.choose("hand", "Sword");
		var hung = outfit.getNodes("hand");
		check(hung.length == 1 && hung[0].parent == character.find("Middle1.R", Node3D) && hung[0].matrix.join(",") == offset,
			"Without a socket, a rigid part hangs from the joint its file hangs it from, at the file's offset");
		check(hung[0].find("Root", Node3D) == null && hung[0].find("Middle1.R", Node3D) == null,
			"and the file's own copy of the skeleton doesn't come with it");
		outfit.choose("hand", "Sword", "Nope");
		check(outfit.getWorn("hand") == null && outfit.getError("hand") != null && sword[0].parent == null,
			"A socket the skeleton lacks empties the slot, saying why");
		outfit.choose("hand", null);
		check(outfit.getChoice("hand") == null && outfit.getError("hand") == null, "A slot can be emptied");

		// A choice overtaken while its file loads is dropped.
		outfit.choose("legs", "Slow_Legs");
		check(outfit.pending && held.exists("Slow_Legs"), "A part not yet loaded is asked for");
		shared.put("Casual_Legs", file("Casual_Legs"));
		outfit.choose("legs", "Casual_Legs");
		check(outfit.getWorn("legs") == "Casual_Legs", "A later choice already loaded is worn at once");
		release("Slow_Legs", bytes("Adventurer_Legs"));
		check(outfit.getWorn("legs") == "Casual_Legs" && !outfit.pending, "and the overtaken one, landing after, is dropped");
		check(shared.isLoaded("Slow_Legs"), "though the models keep its file");

		// A file that fails.
		outfit.choose("feet", "Missing_Feet");
		refuse("Missing_Feet", "not found");
		check(outfit.getWorn("feet") == null && outfit.getError("feet") != null && !outfit.pending, "A part whose file fails empties its slot");

		// Many characters, one load.
		var others = [for (i in 0...3) new Outfit()];
		var skeletons = [for (i in 0...3) animations.instantiate('other$i')];
		for (i in 0...3) {
			others[i].skeleton = skeletons[i];
			others[i].choose("feet", "Shared_Feet");
		}
		check(asked["Shared_Feet"] == 1, "Characters asking for one part share its load");
		release("Shared_Feet", bytes("Casual_Feet"));
		var feet = [for (o in others) (cast o.getNodes("feet")[0] : Model3D)];
		check(feet[0] != feet[1] && feet[1] != feet[2] && feet[0].mesh == feet[1].mesh, "and each wears its own nodes over the same meshes");
		check(under(feet[2].getJoint(0), skeletons[2]) && !under(feet[2].getJoint(0), skeletons[0]), "each bound to its own skeleton");

		// Another skeleton: choices move to it; one lacking the joints refuses them.
		var moved = animations.instantiate("moved");
		outfit.skeleton = moved;
		check(outfit.getNodes("head")[0].parent == moved
			&& outfit.getWorn("body") == "Adventurer_Body"
			&& !under(outfit.getNodes("body")[0], character),
			"Choices move to a new skeleton, off the old one");
		outfit.skeleton = new Node3D();
		check(outfit.getWorn("head") == null && outfit.getError("head") != null, "A skeleton without the joints refuses a part");
		outfit.skeleton = null;
		check(outfit.getNodes("body").length == 0 && outfit.getChoice("head") == "Witch_Head" && outfit.pending,
			"Without a skeleton nothing is worn, and the choices are kept");

		// Every part of the pack is worn on the animations' skeleton, each slot's part from each outfit.
		var every = models();
		@:privateAccess Models3D.bind(every);
		var model = new Outfit(), refused = [];
		model.skeleton = animations.instantiate("model");
		for (look in [
			"Adventurer",
			"Casual",
			"Formal",
			"Medieval",
			"Punk",
			"SciFi",
			"Soldier",
			"Suit",
			"Witch",
			"Worker"
		])
			for (slot in ["Head", "Body", "Legs", "Feet"]) {
				var name = '${look}_$slot';
				every.put(name, file(name));
				model.choose(slot, name);
				if (model.getWorn(slot) != name)
					refused.push('$name: ${model.getError(slot)}');
			}
		check(refused.length == 0, 'Every part of the ten outfits is worn: $refused');

		// A file whose models sit under no joint: the piece is the whole file, hung at a socket.
		var loose = new Node3D(),
			gem = new Model3D(Mesh3D.plane(.1, .1), new Material3D());
		gem.name = "gem";
		var holder = new Node3D();
		holder.name = "holder";
		holder.addChild(gem);
		loose.addChild(holder);
		var at = loose.findAttachment(gem, character);
		check(at != null && at.piece == holder && at.joint == null, "A model under no joint of the skeleton's is a piece at the file's top, with no joint");
		check(loose.findAttachment(new Model3D(), character) == null, "A model not under the file has no attachment");

		// Shutting the models down cancels what's still loading, telling no one.
		var told = false;
		shared.load("Never", _ -> told = true, _ -> told = true);
		shared.shutdown();
		check(!told && !shared.isLoading("Never") && !held.exists("Never") && !shared.isLoaded("Casual_Head"),
			"Shutting down cancels loads, calling nothing, and forgets files");
		@:privateAccess Models3D.bind(null);
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}
}

/** Assets whose loads wait until the test releases them, counting how often each path is asked for. */
@:access(helix)
private class Held implements IAssets {
	public function new() {}

	public function load(path:String, loaded:Bytes->Void, ?failed:String->Void):helix.asset.IRequest
		return ensure(path, loaded, failed);

	public function ensure(path:String, loaded:Bytes->Void, ?failed:String->Void, ?progress:helix.asset.AssetProgress->Void,
			?options:helix.asset.EnsureOptions):helix.asset.IRequest {
		@:privateAccess OutfitTests.asked[path] = (OutfitTests.asked.exists(path) ? OutfitTests.asked[path] : 0) + 1;
		@:privateAccess OutfitTests.held[path] = {loaded: loaded, failed: message -> helix.asset.Failure.report(path, message, failed)};
		return new helix.asset.Request(() -> @:privateAccess OutfitTests.held.remove(path));
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
