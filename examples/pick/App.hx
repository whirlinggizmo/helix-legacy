import helix.debug.FpsOverlay;
import helix.debug.PickOverlay2D;
import helix.debug.PickOverlay3D;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.render3d.Animator3D;
import helix.render3d.Camera3D;
import helix.render3d.DirectionalLight3D;
import helix.render3d.Drawing3D;
import helix.render3d.Environment3D;
import helix.render3d.HitArea3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.ModelFile3D;
import helix.render3d.Models3D;
import helix.render3d.Node3D;
import helix.render3d.PickHit3D;
import helix.render3d.Sprite3D;
import helix.render3d.Text3D;
import helix.render3d.View3D;
import helix.scene.Pointer;
import helix.time.Time;
import helix.host.ScreenShape;
import helix.render3d.Orbit3D;

/** Every kind a View3D picks, under the pointer (the earlier frameworks' pick): a cube, a sphere, a sprite and a text made pickable (their
	quads as drawn), a car from a glTF file (its triangles), and a walking character (her triangles as posed now, not as bound). A
	helix.scene.Pointer with nothing added reads the stage, through the view to its tree; its hit3D is the hit. The hit's point is marked
	and its normal drawn (a Drawing3D in the tree), and its node, distance and point shown. The left button puts a bullet hole where it
	points (Decals3D.placeOn: on the face hit, under the node hit, or on the character the joint moving her there), so the cube's turn
	with it as it turns and hers ride her as she walks. O stops the circling camera; Escape quits where
	quitting means anything. */
class App extends helix.App {
	var level = new Node3D();
	var view:View3D;
	var marks = new Drawing3D();
	var text = new Drawing2D();
	var pointer:Pointer;
	var camera = new Camera3D();
	var fps = new FpsOverlay();
	var overlay3D = new PickOverlay3D();
	var overlay2D = new PickOverlay2D();
	var picked:Null<PickHit3D>;
	// Bullet holes, on whatever they're put on; and the cube, turning, carrying its own.
	var holes:helix.render3d.Decals3D;
	var cube:Model3D;
	var animator:Null<Animator3D>;
	// The camera, circling.
	var orbit = new Orbit3D(9, 5, .2, 1, .3);

	override public function init():Void {
		Window.title = "HeliX pick";
		Window.requestSize(1000, 600);
		Stage.color = 0xff1c1e26;
		level.environment = new Environment3D();
		level.environment.setAmbient(0xffffffff, .3);
		// Framed for 16:9: everything pickable in view on a phone held upright too.
		camera.minAspect = 16 / 9;
		var sun = new DirectionalLight3D();
		sun.intensity = 2.5;
		sun.lookAt(-.4, -1, -.5);
		level.addChild(sun);
		var ground = new Material3D();
		ground.baseColor = 0xff3a3f4a;
		var floor = new Model3D(Mesh3D.plane(14, 14), ground);
		floor.name = "the ground";
		level.addChild(floor);
		var red = new Material3D(), blue = new Material3D();
		red.baseColor = 0xffd2503c;
		blue.baseColor = 0xff3c78d2;
		cube = new Model3D(Mesh3D.cube(1.2, 1.2, 1.2), red);
		cube.name = "a cube";
		cube.setPosition(-3, .6, 1);
		cube.setRotation(0, .6, 0);
		level.addChild(cube);
		holes = new helix.render3d.Decals3D(helix.particle.Emitter.getDot(), 32);
		holes.size = .18;
		holes.tint = 0xf0100c0a;
		level.addChild(holes);
		var sphere = new Model3D(Mesh3D.sphere(.8), blue);
		sphere.name = "a sphere";
		sphere.setPosition(-1, .8, -1.5);
		level.addChild(sphere);
		var label = new Text3D("PICK ME", .5, 0xfff5d25a);
		label.name = "a text";
		// Text lets picks through unless asked.
		label.pickable = true;
		label.setPosition(1, 2.4, -2);
		level.addChild(label);
		Textures.load("sprites/logo/wg-logo-white-alpha.png", Linear, texture -> placeLogo(texture));
		Models3D.load("models/car-kit/sedan-sports.glb", file -> placeCar(file));
		// The character: a skeleton and its clips, her outfit bound to it by joint name, walking in place.
		var files = new Map<String, ModelFile3D>(),
			names = ["Animations", "Casual_Body", "Casual_Head", "Casual_Legs", "Casual_Feet"];
		for (name in names)
			Models3D.load('models/modular-women/$name.glb', file -> gather(files, name, file, names.length));
		// A hotspot: picked by its sphere, never drawn.
		var hotspot = new Node3D();
		hotspot.name = "a hotspot";
		hotspot.hitArea = HitArea3D.sphere(0, 0, 0, .5);
		hotspot.setPosition(1, .5, 2.5);
		// Its label, above it: text lets picks through to what it names.
		var tag = new Text3D("Node3D + hitArea (nothing drawn)", .2, 0xffb4f0c0);
		tag.setPosition(0, .75, 0);
		hotspot.addChild(tag);
		level.addChild(hotspot);
		level.addChild(marks);
		overlay3D.pickShapes = overlay3D.drawBounds = overlay2D.pickShapes = overlay2D.drawBounds = false;
		level.addChild(overlay3D);
		view = new View3D(level, camera);
		Stage.addChild(view);
		// The text lets the pointer through to the world under it.
		text.pickable = false;
		Stage.addChild(text);
		Stage.addChild(fps);
		Stage.addChild(overlay2D);
		pointer = new Pointer();
	}

	// The logo's texture in: a sprite of it, pickable.
	function placeLogo(texture:Texture2D):Void {
		var logo = new Sprite3D(texture, 0xff7ab4ff);
		logo.name = "a sprite";
		logo.setSpriteSize(1.4, 1.4);
		logo.setPosition(-3, 2.6, -1);
		level.addChild(logo);
	}

	// The car's file in: a copy of it, turned a little.
	function placeCar(file:ModelFile3D):Void {
		var car = file.instantiate("a car");
		car.setPosition(3, 0, 1);
		car.setRotation(0, -.8, 0);
		level.addChild(car);
	}

	// One of the character's files in, kept by name: she's dressed once all count of them are.
	function gather(files:Map<String, ModelFile3D>, name:String, file:ModelFile3D, count:Int):Void {
		files[name] = file;
		if (Lambda.count(files) == count)
			dress(files);
	}

	function dress(files:Map<String, ModelFile3D>):Void {
		var animations = files["Animations"],
			character = animations.instantiate("a character");
		character.setPosition(.8, 0, .8);
		level.addChild(character);
		for (part in ["Casual_Body", "Casual_Head", "Casual_Legs", "Casual_Feet"])
			for (model in skinned(files[part].instantiate()))
				if (model.bindSkeleton(character)) {
					model.parent = null;
					model.name = "a character's " + part.split("_")[1].toLowerCase();
					character.addChild(model);
				}
		animator = new Animator3D(character);
		animator.play(animations.getClip("Walk"));
	}

	static function skinned(node:Node3D):Array<Model3D> {
		var model = Std.downcast(node, Model3D);
		var out = model != null && model.mesh.skinned ? [model] : [];
		for (i in 0...node.childCount)
			out = out.concat(skinned(node.getChild(i)));
		return out;
	}

	// The node's name, or its parent's (a file's parts are named for the node holding them).
	static function nameOf(node:Node3D):String {
		var at = node;
		while (at != null && at.name == "")
			at = at.parent;
		return at == null ? "a node" : at.name;
	}

	override public function update(dt:Float):Void {
		if (Host.canQuit() && Input.isFramePressed(Key.Escape))
			Host.quit();
		if (Input.isFramePressed(Key.O))
			orbit.running = !orbit.running;
		// What picks test (P) and each node's box (B), in the 3D and over the 2D: on, then off.
		if (Input.isFramePressed(Key.P))
			overlay3D.pickShapes = overlay2D.pickShapes = !overlay3D.pickShapes;
		if (Input.isFramePressed(Key.B))
			overlay3D.drawBounds = overlay2D.drawBounds = !overlay3D.drawBounds;
		orbit.update(dt);
		cube.setRotation(0, .6 + Time.clock.time * .4, 0);
		if (animator != null)
			animator.update(dt);
		fps.update(dt, Time.frameCpu);
		orbit.apply(camera);
		// The text in the design for the window's shape, wrapped to what's visible of it.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth;
		// What's under the pointer, through the stage to the view's tree, where the view was last drawn.
		pointer.update();
		picked = pointer.hit3D;
		if (picked != null && Input.pointerFramePressed)
			holes.placeOn(picked);

		marks.clear();
		if (picked != null) {
			var x = picked.getPoint(0),
				y = picked.getPoint(1),
				z = picked.getPoint(2);
			marks.sphere(x, y, z, .06, 0xffffe040);
			marks.line(x, y, z, x + picked.getNormal(0) * .6, y + picked.getNormal(1) * .6, z + picked.getNormal(2) * .6, 0xff40ff80);
		}
		fps.setPosition(vx + 12, vy + 10);
		text.clear();
		var title = "HeliX pick: move the pointer over anything";
		var y = vy + 36;
		y += text.drawTextWrapped(title, vx + 12, y, 20, vw - 24, 0xfff5f5f5) + 3;
		var line = picked == null ? "nothing under the pointer" : '${nameOf(picked.node)}   ${Math.round(picked.distance * 100) / 100} away   at '
			+ [for (a in 0...3) Math.round(picked.getPoint(a) * 100) / 100].join(", ") + '   facing ' +
				[for (a in 0...3) Math.round(picked.getNormal(a) * 100) / 100].join(", ");
		y += text.drawTextWrapped(line, vx + 12, y, 16, vw - 24, 0xffc8c8c8) + 4;
		text.drawTextWrapped("O: the camera   P: pick shapes   B: bounds   [LMB] add decal"
			+ (Host.canQuit() ? "   ESC: quit" : ""), vx
			+ 12, y, 16, vw
			- 24,
			0xffc8c8c8);
	}

	override public function cleanup():Void
		view.destroy();
}
