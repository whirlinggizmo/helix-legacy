import helix.render3d.Models3D;
import helix.render3d.Node3D;

/** What a character wears, by slot ("head", "body", "hand" ... the game names them): a part file for each, from the program's models (Models3D),
	shared by every character. The dressing room's own, game code over the framework's pieces, as a Babylon playground's Actor is over its engine: Models3D (a file loaded once), Node3D.collectModels and Model3D.bindSkeleton (a part's skinned models follow the character's joints by name),
	and Node3D.findAttachment (its rigid models, a sword, a gun, a hat, hang from the character's joint named as the one their file hangs them from,
	keeping their offset, or from a joint the choice names, a socket). The policy is this class's: choices may come before the skeleton, and in
	any order while files load; each slot wears its latest choice once both its file and the skeleton are in, a choice overtaken while its file
	loads is dropped, and a part that can't be worn leaves its slot empty, saying why. */
class Outfit {
	var chosen:Map<String, Choice> = [];
	var worn:Map<String, Worn> = [];
	var errors:Map<String, String> = [];

	/** An outfit drawing its parts from the program's models (Models3D), for a skeleton given later (skeleton). */
	public function new() {}

	/** The skeleton parts are worn on (a character's root, its joints at or under it), or null before it's given; assigning one wears
		every slot's choice on it, taking them off the one before (null takes everything off). */
	public var skeleton(default, set):Null<Node3D>;

	function set_skeleton(value:Null<Node3D>):Null<Node3D> {
		for (slot in [for (s in worn.keys()) s])
			takeOff(slot);
		skeleton = value;
		// Each choice tried afresh on it: what one skeleton refused another may take (a file that failed fails again, remembered).
		errors.clear();
		for (slot in [for (s in chosen.keys()) s])
			apply(slot);
		return value;
	}

	/** Chooses path's part for slot (null leaves the slot empty): worn on the skeleton by joint name, its rigid models at their joints, or, with
		joint, at that one (a socket). It's worn once its file has loaded (at once when it has, and the skeleton is given); a later choice for the
		slot overtakes it. A part that can't be worn (its file fails, its skeleton lacks a joint it names) leaves the slot empty, with getError
		saying why. */
	public function choose(slot:String, path:Null<String>, ?joint:String):Void {
		errors.remove(slot);
		if (path == null) {
			chosen.remove(slot);
			takeOff(slot);
			return;
		}
		chosen[slot] = new Choice(path, joint);
		apply(slot);
	}

	/** The path chosen for slot, or null for none. */
	public function getChoice(slot:String):Null<String> {
		var choice = chosen[slot];
		return choice == null ? null : choice.path;
	}

	/** The path slot wears now (its choice once it's on), or null for none. */
	public function getWorn(slot:String):Null<String> {
		var w = worn[slot];
		return w == null ? null : w.path;
	}

	/** The nodes slot's part added to the character, empty for none. */
	public function getNodes(slot:String):Array<Node3D> {
		var w = worn[slot];
		return w == null ? [] : w.nodes.copy();
	}

	/** The slots chosen, in no order. */
	public var slots(get, never):Array<String>;

	function get_slots():Array<String>
		return [for (s in chosen.keys()) s];

	/** Why slot's choice couldn't be worn, or null. */
	public function getError(slot:String):Null<String>
		return errors[slot];

	/** Whether a choice is waiting for its file (or for the skeleton). */
	public var pending(get, never):Bool;

	function get_pending():Bool {
		for (slot => choice in chosen)
			if (getWorn(slot) != choice.path && !errors.exists(slot))
				return true;
		return false;
	}

	// Wears slot's choice when its file and the skeleton are in; asks the models for the file otherwise.
	function apply(slot:String):Void {
		var choice = chosen[slot];
		if (choice == null || skeleton == null)
			return;
		var w = worn[slot];
		if (w != null && w.path == choice.path && w.joint == choice.joint)
			return;
		var file = Models3D.find(choice.path);
		if (file == null) {
			Models3D.load(choice.path, _ -> if (chosen[slot] == choice) apply(slot), message -> if (chosen[slot] == choice) fail(slot, message));
			return;
		}
		takeOff(slot);
		var copy = file.instantiate(slot), skinned = [], rigid = [];
		copy.collectModels(skinned, rigid);
		if (skinned.length == 0 && rigid.length == 0) {
			fail(slot, '${choice.path}: no model to wear');
			return;
		}
		for (model in skinned)
			if (!model.bindSkeleton(skeleton)) {
				fail(slot, '${choice.path}: ${model.name} names a joint the skeleton hasn\'t');
				return;
			}
		var socket = choice.joint == null ? null : joint(choice.joint);
		if (choice.joint != null && socket == null) {
			fail(slot, '${choice.path}: the skeleton has no joint ${choice.joint}');
			return;
		}
		// The rigid models in pieces, each hung from the socket chosen, or else from the joint its file hangs it from.
		var pieces:Array<Node3D> = [], joints:Array<Node3D> = [];
		for (model in rigid) {
			var at = copy.findAttachment(model, skeleton);
			if (at == null || pieces.indexOf(at.piece) >= 0)
				continue;
			var target = socket != null ? socket : at.joint;
			if (target == null) {
				fail(slot, '${choice.path}: the skeleton has no joint to hang ${at.piece.name} from');
				return;
			}
			pieces.push(at.piece);
			joints.push(target);
		}
		var nodes:Array<Node3D> = [];
		for (model in skinned) {
			model.parent = null;
			skeleton.addChild(model);
			nodes.push(model);
		}
		for (i in 0...pieces.length) {
			pieces[i].parent = null;
			joints[i].addChild(pieces[i]);
			nodes.push(pieces[i]);
		}
		worn[slot] = new Worn(choice.path, choice.joint, nodes);
	}

	// The skeleton's joint (or root) named name, or null.
	function joint(name:String):Null<Node3D>
		return name == "" ? null : skeleton.name == name ? skeleton : skeleton.find(name, Node3D);

	function fail(slot:String, message:String):Void {
		takeOff(slot);
		errors[slot] = message;
	}

	function takeOff(slot:String):Void {
		var w = worn[slot];
		if (w == null)
			return;
		for (node in w.nodes)
			node.parent = null;
		worn.remove(slot);
	}
}

/** A slot's choice: its part's path, and the socket its rigid models hang from (null: the joints their file hangs them from). */
private class Choice {
	/** The part file's path. */
	public final path:String;

	/** The socket chosen, or null. */
	public final joint:Null<String>;

	/** A choice of path, held at joint. */
	public function new(path:String, joint:Null<String>) {
		this.path = path;
		this.joint = joint;
	}
}

/** What a slot wears: its path and socket, and the nodes it added to the character. */
private class Worn {
	/** The part file's path. */
	public final path:String;

	/** The socket chosen, or null. */
	public final joint:Null<String>;

	/** The nodes added to the character: skinned models under the skeleton, rigid pieces under their joints. */
	public final nodes:Array<Node3D>;

	/** What path, held at joint, added: nodes. */
	public function new(path:String, joint:Null<String>, nodes:Array<Node3D>) {
		this.path = path;
		this.joint = joint;
		this.nodes = nodes;
	}
}
