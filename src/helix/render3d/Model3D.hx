package helix.render3d;

import helix.math.Bounds3D;

/** A model: its parts, each a mesh drawn with a material (a glTF node with several primitives is one model of several parts), tinted
	(0xAARRGGBB, white for none; its alpha below 255 makes it see-through), casting and receiving shadows. A model of a skinned mesh follows
	the joints it's bound to (bindSkeleton). Its mesh and material are its first part's. */
class Model3D extends Node3D {
	var parts:Array<Part3D> = [];
	var castsShadows = true;
	var receivesShadows = true;
	var joints:Null<Array<Node3D>>;
	@:allow(helix.render3d.ModelPass3D) var passes:Array<ModelPass3D> = [];

	/** A model of one part, mesh drawn with material (a new white one when null); with no mesh, a model of no parts until mesh. */
	public function new(?mesh:Mesh3D, ?material:Material3D) {
		super();
		if (mesh != null)
			parts.push(new Part3D(mesh, material));
	}

	/** How many parts it has. */
	public var partCount(get, never):Int;

	function get_partCount():Int
		return parts.length;

	/** Its part at index, in the file's order; null past the end. */
	public function getPart(index:Int):Null<Part3D>
		return index >= 0 && index < parts.length ? parts[index] : null;

	/** Adds a part, mesh drawn with material (a new white one when null), after the others. */
	public function addPart(mesh:Mesh3D, ?material:Material3D):Void
		parts.push(new Part3D(mesh, material));

	/** Its first part's mesh, or null with no parts. Assigned to a model with no parts, it makes that part (white). */
	public var mesh(get, set):Null<Mesh3D>;

	function get_mesh():Null<Mesh3D>
		return parts.length > 0 ? parts[0].mesh : null;

	function set_mesh(value:Null<Mesh3D>):Null<Mesh3D> {
		if (parts.length == 0)
			parts.push(new Part3D(value));
		else
			parts[0].mesh = value;
		return value;
	}

	/** Its first part's material, or null with no parts. Assigned to a model with no parts, it makes that part (with no mesh). */
	public var material(get, set):Null<Material3D>;

	function get_material():Null<Material3D>
		return parts.length > 0 ? parts[0].material : null;

	function set_material(value:Null<Material3D>):Null<Material3D> {
		if (parts.length == 0)
			parts.push(new Part3D(null, value));
		else
			parts[0].material = value;
		return value;
	}

	/** How many extra passes it's drawn in (ModelPass3D: helix.shader.Outline and Silhouette add themselves). */
	public var passCount(get, never):Int;

	function get_passCount():Int
		return passes.length;

	/** Its extra pass at index, in the order added; null past the end. */
	public function getPass(index:Int):Null<ModelPass3D>
		return index >= 0 && index < passes.length ? passes[index] : null;

	/** Its tint, 0xAARRGGBB. */
	public var tint:Int = 0xffffffff;

	/** Whether it casts shadows (from the lights that cast them; see-through models never do). True by default. */
	public var shadowCasting(get, set):Bool;

	function get_shadowCasting():Bool
		return castsShadows;

	function set_shadowCasting(value:Bool):Bool {
		castsShadows = value;
		return value;
	}

	/** Whether shadows fall on it. True by default. */
	public var shadowReceiving(get, set):Bool;

	function get_shadowReceiving():Bool
		return receivesShadows;

	function set_shadowReceiving(value:Bool):Bool {
		receivesShadows = value;
		return value;
	}

	/** Its skin (its mesh's joints by name), or null: a model of a skinned mesh without one draws in its bind pose. */
	public var skin(default, null):Null<Skin3D>;

	/** How many joints it follows: its skin's, once bound; 0 otherwise. */
	public var jointCount(get, never):Int;

	function get_jointCount():Int
		return joints == null ? 0 : joints.length;

	/** The node its joint index follows; null past them or unbound. */
	public function getJoint(index:Int):Null<Node3D>
		return joints == null || index < 0 || index >= joints.length ? null : joints[index];

	// Its parts' vertices placed in the world into out: a skinned one's posed by the joints it's bound to (moved on the CPU, as the GPU
	// blends them, a pass over its vertices; unbound, its bind pose placed by world), a rigid one's by world. Node3D.computeBounds.
	override function measureOwnWorld(world:Mat4, out:Bounds3D):Void {
		// Each joint's world matrix times its inverse bind: what takes a vertex from the mesh's bind space to the world, column-major.
		var palette = posedPalette, made = false;
		for (part in parts) {
			var mesh = part.mesh;
			if (mesh == null)
				continue;
			var vertices = mesh.vertices,
				skin = mesh.skinData,
				posed = joints != null && mesh.skinned;
			if (posed && !made) {
				made = true;
				palette.resize(0);
				for (j in 0...joints.length) {
					joints[j].computeWorld(jointWorld);
					for (col in 0...4)
						for (row in 0...4) {
							var v = 0.;
							for (k in 0...4)
								v += jointWorld.get(k * 4 + row) * this.skin.getInverseBind(j, col * 4 + k);
							palette.push(v);
						}
				}
			}
			for (i in 0...mesh.vertexCount) {
				var at = i * Lit3DProgram.stride + Lit3DProgram.positionOffset;
				var x = vertices.getFloat(at),
					y = vertices.getFloat(at + 4),
					z = vertices.getFloat(at + 8);
				var placedX = 0., placedY = 0., placedZ = 0.;
				for (row in 0...3) {
					var v = 0.;
					if (posed) {
						var s = i * Skinned3DProgram.skinStride;
						for (k in 0...4) {
							var weight = skin.getFloat(s + Skinned3DProgram.weightsOffset + k * 4);
							if (weight <= 0)
								continue;
							var m = Std.int(skin.getFloat(s + Skinned3DProgram.jointsOffset + k * 4) + .5) * 16;
							if (m >= palette.length)
								continue;
							v += weight * (palette[m + row] * x + palette[m + 4 + row] * y + palette[m + 8 + row] * z + palette[m + 12 + row]);
						}
					} else
						v = world.get(row) * x + world.get(4 + row) * y + world.get(8 + row) * z + world.get(12 + row);
					if (row == 0)
						placedX = v;
					else if (row == 1)
						placedY = v;
					else
						placedZ = v;
				}
				out.expand(placedX, placedY, placedZ);
			}
		}
	}

	// The scratch measureOwnWorld reuses: the palette of a skinned model's joints, and a joint's world matrix.
	static var posedPalette:Array<Float> = [];
	static var jointWorld = new Mat4();

	/** Binds it, a model of a skinned mesh, to a skeleton: each of skin's joints (its own skin when null) to the node of that name at or under
		skeleton, which must be on the same stage, so its vertices follow them. A piece of gear skinned in a file of its own follows a character
		this way, by joint name. False, changing nothing, for a mesh that isn't skinned, no skin, or a joint name the skeleton lacks. */
	public function bindSkeleton(skeleton:Node3D, ?skin:Skin3D):Bool {
		var chosen = skin != null ? skin : this.skin, mesh = this.mesh;
		if (mesh == null || !mesh.skinned || chosen == null)
			return false;
		var found = [];
		for (j in 0...chosen.jointCount) {
			var name = chosen.getJointName(j);
			var node = skeleton.name == name ? skeleton : skeleton.find(name, Node3D);
			if (node == null)
				return false;
			found.push(node);
		}
		this.skin = chosen;
		joints = found;
		return true;
	}
}
