import haxe.io.Bytes;
import helix.asset.Assets;
import helix.debug.Autopilot;
import helix.debug.FpsOverlay;
import helix.debug.TestHarness;
import helix.graphics.Color;
import helix.graphics.PostProcess;
import helix.graphics.Screenshots;
import helix.graphics.SpriteEffect;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Input;
import helix.input.Key;
import helix.render2d.Camera2D;
import helix.render2d.Drawing2D;
import helix.render2d.Node2D;
import helix.render2d.Sprite2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.texture.Textures;
import helix.render2d.View2D;
import helix.render3d.AnimationClip3D;
import helix.render3d.Animator3D;
import helix.render3d.Camera3D;
import helix.render3d.DirectionalLight3D;
import helix.render3d.Environment3D;
import helix.render3d.Material3D;
import helix.render3d.Mesh3D;
import helix.render3d.Model3D;
import helix.render3d.ModelFile3D;
import helix.render3d.Models3D;
import helix.render3d.Node3D;
import helix.render3d.View3D;
import helix.shader.Bloom;
import helix.shader.Blur;
import helix.shader.ChromaticAberration;
import helix.shader.ColorLut;
import helix.shader.Crt;
import helix.shader.Dissolve;
import helix.shader.Fxaa;
import helix.shader.HitFlash;
import helix.shader.Outline;
import helix.shader.PaletteSwap;
import helix.shader.Pixelate;
import helix.shader.Rim;
import helix.shader.Silhouette;
import helix.shader.SpriteDissolve;
import helix.shader.SpriteFlash;
import helix.shader.SpriteOutline;
import helix.shader.Tonemap;
import helix.shader.Toon;
import helix.shader.Unlit;
import helix.shader.Vignette;
import helix.shader.Water;
import helix.time.Time;
import helix.ui.ColorPicker;
import helix.ui.Dropdown;
import helix.ui.ListView;
import helix.ui.Panel;
import helix.ui.Slider;
import helix.ui.Ui;
import helix.host.ScreenShape;
import helix.render3d.Orbit3D;

/** A tour of the shader library (helix.shader): every library shader, one at a time, over one still scene, its parameters on sliders and
	its colors on color pickers (helix.ui's ColorPicker).
	The scene is a View3D's tree (its ambient light an Environment3D on its root), shown with the sprites in a View2D: the Kenney sports car, a sphere and a skinned character (Quaternius's Ultimate Modular Women) behind a low wall, under a sun
	casting shadows, with two lamps glowing past white; a row of sprites (the logo twice, a creature of indexed pixels and a checkerboard in a clear ring, both drawn sharp) along the bottom.
	The menu (helix.ui) lists the shaders by kind; choosing one turns it on alone:
	- surface shaders, on the car's, the sphere's and her materials: Unlit, Toon, Rim, HitFlash (held; F flashes), Dissolve, Water
	- passes, on the same models: Outline, and Silhouette (her, seen through the wall)
	- screen effects, over the scene and the sprites (a PostProcess, the chain of the View2D showing them): Bloom, Tonemap (ACES over the chain's Neutral), Fxaa, Blur, Vignette, ColorLut (a
	  teal and orange grade), Crt, ChromaticAberration, Pixelate; and a chain of two, Bloom then Vignette
	- sprite effects: SpriteOutline, SpriteFlash (held; F flashes) and SpriteDissolve on the row but the creature, and PaletteSwap (the
	  creature's indices in another row of its palette: it's drawn through its palette's first row the rest of the time, as a game draws an
	  indexed sprite, since a sprite has one effect and without one its indices show as near-black reds)
	The sliders under the list set the chosen one's parameters as its fields do; at the top right a color picker sets each of its colors (with
	an alpha bar where the color's alpha means something), a dropdown above it choosing which when it has several (Water's three, Toon's
	shadow and rim), its text field taking a color typed (as hex, or decimal channels once its button cycles the format). The
	menu is on the stage over that view, outside the effects.

	Pointer, arrows, Enter and a pad use the menu; PageDown / PageUp: the next or previous shader; X: the chosen one off and on to compare;
	R: PaletteSwap's next row while it's chosen;
	F: a flash in the flash's color (HitFlash's and SpriteFlash's pickers); O: the camera circling; Escape quits where quitting means anything.
	Options: autopilot (a script under assets/: the stage's time (Stage.heldTime), her pose and the camera are then held from the first frame, the window the
	autopilot's page's size, so its samples of the frame compare across targets; the script's click names a shader, None or Chain, choosing
	it, or else a widget of the menu: a picker is named for its shader and color, Unlit-color, its text field Unlit-color-text) and autoclose
	(1: quit once the script is done). The probes: ready (everything loaded), chosen (the chosen shader's name, or None), color (the color
	the chosen shader's picker shows, as hex; "" without one) and hdr (PostProcess.hdr). */
class App extends helix.App {
	static inline var FLOOR_Y = 0.;
	static inline var WOMEN = "models/modular-women/";
	static var PARTS = ["Casual_Head", "Casual_Body", "Casual_Legs", "Casual_Feet"];
	static inline var LOGO = "sprites/logo/wg-logo-bw-alpha.png";
	static inline var WHITE_LOGO = "sprites/logo/wg-logo-white-alpha.png";
	// The creature's pixels, a character an index into its palette's columns: . none, o its outline, b its body, e its eyes.
	static var CREATURE = [
		"....oooooooo....", "..oobbbbbbbboo..", ".obbbbbbbbbbbbo.", ".obbbbbbbbbbbbo.", "obbbeeebbeeebbbo", "obbbeooebeooebbo", "obbbeooebeooebbo",
		"obbbeeebbeeebbbo", "obbbbbbbbbbbbbbo", "obbbbbbbbbbbbbbo", "obbboooooooobbbo", ".obbbbbbbbbbbbo.", ".obbbbbbbbbbbbo.", "..oobbbbbbbboo..",
		"..o.oo....oo.o..", ".oo..........oo."
	];
	// Its palette: a row a variant, a column an index (none, outline, body, eyes); 0xAARRGGBB.
	static var PALETTE = [
		[0x00000000, 0xff1a2a1a, 0xff58c858, 0xfff5f5f5],
		[0x00000000, 0xff2a1414, 0xffe05050, 0xffffe040],
		[0x00000000, 0xff141a30, 0xff5078f0, 0xfff5f5f5]
	];

	// The autopilot's window's size (the autopilot's browser page's), so its samples compare across targets.
	static inline var PILOT_WIDTH = 800;
	static inline var PILOT_HEIGHT = 600;

	// The time the autopilot holds the stage at (Stage.heldTime), so its samples compare across targets.
	static inline var HELD_TIME = 2.;

	// The scene's 3D tree and the view showing it; the 3D view and the sprite row under one node, shown by a view whose chain is the screen
	// effects (the menu, the title and the frame rate on the stage outside it); the title and keys, drawn again each update.
	var level = new Node3D();
	var view3D:View3D;
	var scene = new Node2D();
	var sceneCamera = new Camera2D();
	var sceneView:View2D;
	var post:PostProcess;
	var camera = new Camera3D();
	var orbit = new Orbit3D(6.4, 2.4, .25, 0);
	var hud = new Drawing2D();
	var fps = new FpsOverlay();
	var ui:Null<Ui>;
	var list:Null<ListView>;
	var layout:Null<helix.ui.Layout2D>;
	var status = "loading";

	// The library's shaders by kind, in the menu's order: each one's name, kind, how it's turned on and off, its sliders and their panel.
	var entries:Array<Entry> = [];
	var chosen = -1;
	var shown = true;

	// What the shaders go on: the materials and models of the car, the sphere and her, and her skinned models (the silhouette's).
	var materials:Array<Material3D> = [];
	var models:Array<Model3D> = [];
	var skinned:Array<Model3D> = [];
	var rowSprites:Array<Sprite2D> = [];

	// The surface shaders' last made (their fields write the materials' parameters), and the passes, effects and sprite effects, made once.
	var toons:Array<Toon> = [];
	var unlits:Array<Unlit> = [];
	var dissolves:Array<Dissolve> = [];
	var waters:Array<Water> = [];
	var outlines:Array<Outline> = [];
	var silhouettes:Array<Silhouette> = [];
	var bloom:Bloom;
	var tonemap:Tonemap;
	var fxaa:Fxaa;
	var blur:Blur;
	var vignette:Vignette;
	var colorLut:ColorLut;
	var crt:Crt;
	var aberration:ChromaticAberration;
	var pixelate:Pixelate;
	var spriteOutline:SpriteOutline;
	var spriteFlash:SpriteFlash;
	var spriteDissolve:SpriteDissolve;
	var paletteSwap:PaletteSwap;
	// The creature's own look, its palette's first row, whenever no sprite effect is on the row.
	var creatureColors:PaletteSwap;
	var grade:Texture2D;
	var creature:Texture2D;
	var palette:Texture2D;
	var checker:Texture2D;

	// The parameters the surface shaders and the rim are made with, so one made again (switching back to it) keeps what the sliders and
	// pickers set; colors 0xAARRGGBB.
	var unlitColor = 0xffff7f00;
	var toonBands = 3;
	var toonRimPower = 3.;
	var toonShadowColor = 0xff3a4150;
	var toonRimColor = 0x55ffffff;
	var rimPower = 2.;
	var rimColor = 0xccffffff;
	var flashAmount = .6;
	var flashColor = 0xffffffff;
	var dissolveAmount = .45;
	var dissolveEdge = .06;
	var dissolveScale = 1.;
	var dissolveIntensity = 4.;
	var dissolveEdgeColor = 0xffff7a1e;
	var waterAmplitude = .04;
	var waterWavelength = .6;
	var waterShininess = 64.;
	var waterDeepColor = 0xff0b2a4a;
	var waterShallowColor = 0xff2a8f96;
	var waterSkyColor = 0xffa0b8d8;
	var outlineColor = 0xff101018;
	var outlineWidth = .02;
	var silhouetteColor = 0x993fa9ff;

	// What's loaded: the car, her skeleton and parts, the logos.
	var carPlaced = false;
	var character:Null<Node3D>;
	var parts:Array<ModelFile3D> = [];
	var worn = 0;
	var animator:Null<Animator3D>;
	var logos = 0;
	var pilot:Null<Autopilot>;
	// Whether an autopilot was asked for: the time, her pose and the camera are held from the first frame, before its script is in.
	var piloted = false;
	var published = false;

	override public function init():Void {
		Window.title = "HeliX shader gallery";
		var script = Host.getOption("autopilot", "");
		if (script != "") {
			piloted = true;
			Window.requestSize(PILOT_WIDTH, PILOT_HEIGHT);
			Assets.load(script, bytes -> startPilot(bytes), message -> throw 'Autopilot load failed: ' + message);
		} else
			Window.requestSize(1100, 640);
		// Under the autopilot the stage is drawn at a held time from the start, so what moves with it (the water's waves) is drawn the same
		// on every target.
		if (piloted)
			Stage.heldTime = HELD_TIME;
		Stage.color = 0xff14161c;
		post = new PostProcess();
		level.environment = new Environment3D();
		level.environment.setAmbient(0xffffffff, .2);
		view3D = new View3D(level, camera);
		scene.addChild(view3D);
		sceneView = new View2D(scene, sceneCamera);
		sceneView.color = 0xff14161c;
		sceneView.postProcess = post;
		Stage.addChild(sceneView);
		orbit.running = false;
		orbit.targetX = .5;
		orbit.targetY = .7;
		camera.minAspect = 16 / 9;
		var sun = new DirectionalLight3D();
		sun.color = 0xfffff4e4;
		sun.intensity = 2;
		sun.shadowCasting = true;
		sun.shadowDistance = 12;
		sun.lookAt(-.4, -.8, -.45);
		level.addChild(sun);
		var floor = new Material3D();
		floor.baseColor = 0xff5c6066;
		floor.roughness = .9;
		level.addChild(new Model3D(Mesh3D.plane(12, 8), floor));
		// The sphere in the middle, finely divided for the water's waves.
		var ball = new Material3D();
		ball.baseColor = 0xff3b82f6;
		ball.roughness = .35;
		var sphere = new Model3D(Mesh3D.sphere(.55, 64, 128), ball);
		sphere.setPosition(.5, FLOOR_Y + .55, -.2);
		level.addChild(sphere);
		addMaterial(ball);
		models.push(sphere);
		// The wall before her: the default shading, her silhouette shows through it.
		var brick = new Material3D();
		brick.baseColor = 0xff9a7b5c;
		brick.roughness = .9;
		var wall = new Model3D(Mesh3D.cube(1.1, .6, .1), brick);
		wall.setPosition(2.15, FLOOR_Y + .3, 1.1);
		level.addChild(wall);
		// Two lamps glowing far past white, for the bloom.
		for (i in 0...2) {
			var glow = new Material3D();
			glow.baseColor = 0xff000000;
			glow.setEmissive(i == 0 ? 0xffffd9a0 : 0xff9fd8ff, 10);
			var bulb = new Model3D(Mesh3D.sphere(.14), glow);
			bulb.shadowCasting = false;
			bulb.setPosition(i == 0 ? -.9 : 1.4, 1.9, i == 0 ? -.9 : -1.2);
			level.addChild(bulb);
		}
		Models3D.load("models/car-kit/sedan-sports.glb", file -> placeCar(file));
		for (name in PARTS)
			Models3D.load(WOMEN + name + ".glb", file -> addPart(file), message -> status = '$name: $message');
		Models3D.load(WOMEN + "Animations.glb", file -> placeCharacter(file), message -> status = 'Animations: $message');

		// The sprite row: the logo twice and the creature, made here as indexed pixels (its red channel an index), with its palette.
		var pixels = Bytes.alloc(16 * 16 * 4);
		for (y in 0...16)
			for (x in 0...16) {
				var index = ".obe".indexOf(CREATURE[y].charAt(x));
				pixels.set((y * 16 + x) * 4, index);
				pixels.set((y * 16 + x) * 4 + 3, index == 0 ? 0 : 255);
			}
		creature = Texture2D.fromRgba(16, 16, pixels);
		var colors = Bytes.alloc(PALETTE.length * 4 * 4);
		for (row in 0...PALETTE.length)
			for (column in 0...4)
				for (channel in 0...4)
					colors.set((row * 4 + column) * 4 + channel, (Color.toRgba(PALETTE[row][column]) >>> (24 - channel * 8)) & 255);
		palette = Texture2D.fromRgba(4, PALETTE.length, colors);
		// A checkerboard of 8 x 8 texels, drawn sharp: hard edges of strong contrast, where Fxaa shows; in a clear ring a texel wide, where
		// the sprite outline shows (drawn 10 texels across, so its squares are as large as the other sprites' texels would make them).
		var squares = Bytes.alloc(10 * 10 * 4);
		for (i in 0...100) {
			var x = i % 10 - 1,
				y = Std.int(i / 10) - 1,
				inside = x >= 0 && x < 8 && y >= 0 && y < 8;
			var light = (x + y) % 2 == 0;
			for (c in 0...3)
				squares.set(i * 4 + c, light ? 0xf0 : 0x20);
			squares.set(i * 4 + 3, inside ? 255 : 0);
		}
		checker = Texture2D.fromRgba(10, 10, squares);
		for (i in 0...4) {
			var sprite = new Sprite2D(i == 2 ? creature : i == 3 ? checker : null);
			sprite.setPivot(.5, .5);
			sprite.setSize(i == 3 ? 140 : 112, i == 3 ? 140 : 112);
			rowSprites.push(sprite);
			scene.addChild(sprite);
		}
		Textures.load(LOGO, true, texture -> useLogo(0, texture));
		Textures.load(WHITE_LOGO, true, texture -> useLogo(1, texture));

		// The screen effects in the chain, each off until chosen; the sprite effects.
		bloom = new Bloom();
		tonemap = new Tonemap();
		tonemap.mode = Aces;
		fxaa = new Fxaa();
		blur = new Blur(6);
		vignette = new Vignette(.6);
		grade = Texture2D.fromRgba(ColorLut.SIZE * ColorLut.SIZE, ColorLut.SIZE, tealAndOrange(), true);
		colorLut = new ColorLut(grade);
		crt = new Crt();
		aberration = new ChromaticAberration(6);
		pixelate = new Pixelate(8);
		for (effect in [bloom, tonemap, fxaa, blur, colorLut, aberration, crt, pixelate, vignette]) {
			effect.enabled = false;
			post.add(effect);
		}
		spriteOutline = new SpriteOutline(0xffffb020, 4);
		spriteFlash = new SpriteFlash();
		spriteDissolve = new SpriteDissolve();
		spriteDissolve.amount = .45;
		paletteSwap = new PaletteSwap(palette, 1);
		creatureColors = new PaletteSwap(palette);
		rowSprites[2].effect = creatureColors;
		Stage.addChild(hud);
		Stage.addChild(fps);
		// The menu over all of it, outside the effects, read from the program's input (an autopilot's menu waits for its script, whose input is
		// the program's while it plays).
		if (!piloted)
			build();
	}

	// A grade, as an artist would make one from the identity strip: shadows toward teal, highlights toward orange, a little more contrast.
	static function tealAndOrange():Bytes {
		var pixels = ColorLut.identity();
		for (i in 0...Std.int(pixels.length / 4)) {
			var r = pixels.get(i * 4) / 255,
				g = pixels.get(i * 4 + 1) / 255,
				b = pixels.get(i * 4 + 2) / 255;
			var warm = .299 * r + .587 * g + .114 * b - .5;
			inline function channel(c:Float, shift:Float):Int {
				var v = .5 + (c - .5) * 1.15 + shift * warm;
				return Std.int(Math.max(0, Math.min(1, v)) * 255 + .5);
			}
			pixels.set(i * 4, channel(r, .25));
			pixels.set(i * 4 + 1, channel(g, -.08));
			pixels.set(i * 4 + 2, channel(b, -.3));
		}
		return pixels;
	}

	// The autopilot's script in: the menu reads its input (the program's while it plays), its clicks choose shaders by name or use the menu's widgets by theirs, and its points
	// on the widgets are found by the UI.
	function startPilot(bytes:Bytes):Void {
		pilot = new Autopilot(bytes.toString(), name -> Screenshots.take(name), name -> choose(name) || ui != null && ui.press(name),
			(points, done, failed) -> Screenshots.sample(points, done, failed),
			(target, part, x, y, out) -> ui != null && ui.computePoint(target, part, x, y, out));
		build();
	}

	function probe(name:String):Dynamic
		return switch name {
			case "ready": carPlaced && character != null && worn == PARTS.length && logos == 2 && ui != null;
			case "chosen": chosen < 0 ? "None" : entries[chosen].name;
			case "color":
				var colors = chosen < 0 ? [] : entries[chosen].colors;
				colors.length == 0 ? "" : ColorPicker.formatHex(colors[entries[chosen].color].value, colors[entries[chosen].color].alpha);
			case "hdr": post.hdr;
			default: throw 'Unknown probe ' + name;
		}

	// A material the surface shaders go on.
	function addMaterial(material:Material3D):Void
		materials.push(material);

	// A logo in: sprite i of the row draws it.
	function useLogo(i:Int, texture:Texture2D):Void {
		rowSprites[i].texture = texture;
		logos++;
	}

	// The car's file in: a copy of it on the left, its materials and models the shaders'.
	function placeCar(file:ModelFile3D):Void {
		var node = file.instantiate("car");
		node.setPosition(-1.2, FLOOR_Y, -.3);
		node.setRotation(0, .7, 0);
		level.addChild(node);
		for (material in file.materials)
			addMaterial(material);
		var skinnedModels = [], rigid = [];
		node.collectModels(skinnedModels, rigid);
		for (model in rigid)
			models.push(model);
		carPlaced = true;
		passesFor();
	}

	// Her skeleton in: on the right behind the wall, holding her idle clip's first pose (playing it unless piloted), wearing the parts in.
	function placeCharacter(file:ModelFile3D):Void {
		var node = file.instantiate("character");
		node.setPosition(2.15, FLOOR_Y, .55);
		node.setScale(.8, .8, .8);
		node.setRotation(0, -.3, 0);
		level.addChild(node);
		character = node;
		animator = new Animator3D(node);
		var idle:Null<AnimationClip3D> = file.getClip("Idle");
		if (idle != null)
			animator.play(idle);
		for (part in parts)
			wear(part);
	}

	// A part's file in: kept, and worn if she's here.
	function addPart(file:ModelFile3D):Void {
		parts.push(file);
		wear(file);
	}

	// A part's skinned models bound to her skeleton by joint name and moved under her; its materials and models the shaders'.
	function wear(file:ModelFile3D):Void {
		if (character == null)
			return;
		var copy = file.instantiate("part"), skinnedModels = [], rigid = [];
		copy.collectModels(skinnedModels, rigid);
		for (model in skinnedModels)
			if (model.bindSkeleton(character)) {
				model.parent = null;
				character.addChild(model);
				models.push(model);
				skinned.push(model);
			} else
				status = '${model.name} names a joint the skeleton hasn\'t';
		for (material in file.materials)
			addMaterial(material);
		worn++;
		if (worn == PARTS.length && status == "loading")
			status = "";
		passesFor();
	}

	// The outlines and silhouettes of every model in so far, made once each, on while theirs is the chosen shader.
	function passesFor():Void {
		for (i in outlines.length...models.length) {
			var outline = new Outline(models[i], outlineColor, outlineWidth);
			outline.enabled = false;
			outlines.push(outline);
		}
		for (i in silhouettes.length...skinned.length) {
			var silhouette = new Silhouette(skinned[i], silhouetteColor);
			silhouette.enabled = false;
			silhouettes.push(silhouette);
		}
		if (chosen >= 0 && shown)
			entries[chosen].on();
	}

	// The menu, on the stage over the effects' view: the shaders' list and, under it, the chosen one's sliders.
	function build():Void {
		var ui = new Ui();
		ui.theme.textSize = 15;
		this.ui = ui;
		// The title and the frame rate over the menu, as they were drawn after it.
		Stage.addChild(hud);
		Stage.addChild(fps);
		entries = [
			entry("Unlit", "surface", () -> surface(m -> unlits.push(newUnlit(m))), [], [
				color("color", unlitColor, false, c -> {
					unlitColor = c;
					for (u in unlits)
						u.color = c;
				})
			]),
			entry("Toon", "surface", () -> surface(m -> toons.push(newToon(m))), [
				slider("bands", 2, 6, toonBands, 1, v -> {
					toonBands = Std.int(v);
					for (t in toons)
						t.bands = toonBands;
				}),
				slider("rim power", 1, 8, toonRimPower, .5, v -> {
					toonRimPower = v;
					for (t in toons)
						t.rim.power = v;
				})
			], [
				color("shadow", toonShadowColor, false, c -> {
					toonShadowColor = c;
					for (t in toons)
						t.shadowColor = c;
				}),
				color("rim", toonRimColor, true, c -> {
					toonRimColor = c;
					for (t in toons)
						t.rim.color = c;
				})
			]),
			entry("Rim", "surface", () -> surface(m -> new Rim(m, rimColor, rimPower)), [
				slider("power", .5, 8, rimPower, .5, v -> {
					rimPower = v;
					surface(m -> new Rim(m, rimColor, rimPower));
				})
			], [
				color("color", rimColor, true, c -> {
					rimColor = c;
					surface(m -> new Rim(m, rimColor, rimPower));
				})
			]),
			entry("HitFlash", "surface", () -> surface(m -> holdFlash(m)), [
				slider("amount held", 0, 1, flashAmount, .1, v -> {
					flashAmount = v;
					surface(m -> holdFlash(m));
				})
			], [
				color("color", flashColor, true, c -> {
					flashColor = c;
					surface(m -> holdFlash(m));
				})
			]),
			entry("Dissolve", "surface", () -> surface(m -> dissolves.push(newDissolve(m))), [
				slider("amount", 0, 1, dissolveAmount, .05, v -> {
					dissolveAmount = v;
					for (d in dissolves)
						d.amount = v;
				}),
				slider("edge width", 0, .2, dissolveEdge, .02, v -> {
					dissolveEdge = v;
					for (d in dissolves)
						d.edgeWidth = v;
				}),
				slider("scale", .25, 4, dissolveScale, .25, v -> {
					dissolveScale = v;
					for (d in dissolves)
						d.scale = v;
				}),
				slider("edge intensity", 0, 8, dissolveIntensity, .25, v -> {
					dissolveIntensity = v;
					for (d in dissolves)
						d.edgeIntensity = v;
				})
			], [
				color("edge", dissolveEdgeColor, true, c -> {
					dissolveEdgeColor = c;
					for (d in dissolves)
						d.edgeColor = c;
				})
			]),
			entry("Water", "surface", () -> surface(m -> waters.push(newWater(m))), [
				slider("amplitude", 0, .1, waterAmplitude, .01, v -> {
					waterAmplitude = v;
					for (w in waters)
						w.amplitude = v;
				}),
				slider("wavelength", .2, 2, waterWavelength, .1, v -> {
					waterWavelength = v;
					for (w in waters)
						w.wavelength = v;
				}),
				slider("shininess", 8, 256, waterShininess, 8, v -> {
					waterShininess = v;
					for (w in waters)
						w.shininess = v;
				})
			], [
				color("deep", waterDeepColor, false, c -> {
					waterDeepColor = c;
					for (w in waters)
						w.deepColor = c;
				}),
				color("shallow", waterShallowColor, false, c -> {
					waterShallowColor = c;
					for (w in waters)
						w.shallowColor = c;
				}),
				color("sky", waterSkyColor, false, c -> {
					waterSkyColor = c;
					for (w in waters)
						w.skyColor = c;
				})
			]),
			entry("Outline", "pass", () -> {
				for (o in outlines)
					o.enabled = true;
			}, [
				slider("width", 0, .08, outlineWidth, .005, v -> {
					outlineWidth = v;
					for (o in outlines)
						o.width = v;
				})
			], [
				color("color", outlineColor, false, c -> {
					outlineColor = c;
					for (o in outlines)
						o.color = c;
				})
			]),
			entry("Silhouette", "pass", () -> {
				for (s in silhouettes)
					s.enabled = true;
			}, [], [
				color("color", silhouetteColor, true, c -> {
					silhouetteColor = c;
					for (s in silhouettes)
						s.color = c;
				})
			]),
			entry("Bloom", "screen", () -> bloom.enabled = true,
				[
					slider("intensity", 0, 3, bloom.intensity, .1, v -> bloom.intensity = v),
					slider("threshold", .5, 4, bloom.threshold, .1, v -> bloom.threshold = v)
				]),
			entry("Tonemap", "screen", () -> tonemap.enabled = true, [slider("mode", 0, 2, 2, 1, v -> tonemap.mode = cast Std.int(v))]),
			entry("Fxaa", "screen", () -> fxaa.enabled = true,
				[
					slider("subpixel", 0, 1, fxaa.subpixel, .05, v -> fxaa.subpixel = v),
					slider("edge threshold", .06, .33, fxaa.edgeThreshold, .01, v -> fxaa.edgeThreshold = v)
				]),
			entry("Blur", "screen", () -> blur.enabled = true, [slider("radius", 0, 24, blur.radius, 1, v -> blur.radius = v)]),
			entry("Vignette", "screen", () -> vignette.enabled = true, [
				slider("strength", 0, 1, vignette.strength, .05, v -> vignette.strength = v),
				slider("radius", .2, 1.2, vignette.radius, .05, v -> vignette.radius = v)
			],
				[color("color", vignette.color, false, c -> vignette.color = c)]),
			entry("ColorLut", "screen", () -> colorLut.enabled = true, [slider("amount", 0, 1, colorLut.amount, .05, v -> colorLut.amount = v)]),
			entry("Crt", "screen", () -> crt.enabled = true,
				[
					slider("curvature", 0, .3, crt.curvature, .01, v -> crt.curvature = v),
					slider("lines", 100, 600, crt.lines, 20, v -> crt.lines = v),
					slider("mask", 0, 1, crt.mask, .05, v -> crt.mask = v)
				]),
			entry("ChromaticAberration", "screen", () -> aberration.enabled = true,
				[slider("amount", 0, 16, aberration.amount, 1, v -> aberration.amount = v)]),
			entry("Pixelate", "screen", () -> pixelate.enabled = true,
				[
					slider("cell size", 1, 32, pixelate.cellSize, 1, v -> pixelate.cellSize = Std.int(v))
				]),
			entry("Chain", "screen", () -> bloom.enabled = vignette.enabled = true, []),
			entry("SpriteOutline", "sprite", () -> row(spriteOutline), [slider("width", 0, 16, spriteOutline.width, 1, v -> spriteOutline.width = v)],
				[color("color", spriteOutline.color, true, c -> spriteOutline.color = c)]),
			entry("SpriteFlash", "sprite", () -> {
				spriteFlash.amount = flashAmount;
				row(spriteFlash);
			},
				[slider("amount held", 0, 1, flashAmount, .1, v -> spriteFlash.amount = v)],
				[color("color", spriteFlash.color, true, c -> spriteFlash.color = c)]),
			entry("SpriteDissolve", "sprite", () -> row(spriteDissolve), [
				slider("amount", 0, 1, spriteDissolve.amount, .05, v -> spriteDissolve.amount = v),
				slider("edge width", 0, .2, spriteDissolve.edgeWidth, .02, v -> spriteDissolve.edgeWidth = v)
			],
				[color("edge", spriteDissolve.edgeColor, true, c -> spriteDissolve.edgeColor = c)]),
			entry("PaletteSwap", "sprite", () -> rowSprites[2].effect = paletteSwap, [
				slider("row", 0, PALETTE.length - 1, paletteSwap.row, 1, v -> paletteSwap.row = Std.int(v))
			])
		];
		var shaders = ui.list([
			for (e in entries)
				'${e.kind}: ${e.name == "Chain" ? "Bloom + Vignette" : e.name}'
		], 9, "shaders");
		list = shaders;
		var choice = ui.panel("menu");
		choice.title = "Shaders";
		choice.add(shaders);
		choice.layout.setAnchor(Start, Start, 16, 84);
		choice.layout.setSizing(Fixed(300), Fit);
		for (e in entries) {
			var panel = ui.panel(e.name);
			var heading = ui.label(e.kind + " " + e.name);
			panel.add(heading);
			for (s in e.sliders) {
				panel.add(s.widget = ui.slider(s.label, s.min, s.max, s.value, s.step, e.name + "-" + s.label));
				s.widget.valueShown = true;
			}
			if (e.name == "Chain")
				panel.add(ui.label("Bloom, then Vignette"));
			panel.layout.setAnchor(Start, End, 16, -16);
			panel.layout.setSizing(Fixed(300), Fit);
			panel.visible = false;
			e.panel = panel;
			// A panel a color: a dropdown of which of the shader's colors (when it has several) and its picker, one shown at a time.
			var names = [for (c in e.colors) c.label];
			for (c in e.colors) {
				var colorPanel = ui.panel(e.name + "-" + c.label + "-panel");
				colorPanel.add(ui.label(e.name + " " + c.label));
				if (names.length > 1) {
					colorPanel.add(c.which = ui.dropdown(names, names.indexOf(c.label), e.name + "-" + c.label + "-which"));
				}
				colorPanel.add(c.picker = ui.colorPicker(c.value, c.alpha, e.name + "-" + c.label));
				colorPanel.layout.setAnchor(End, Start, -16, 84);
				colorPanel.layout.setSizing(Fit, Fit);
				colorPanel.visible = false;
				c.panel = colorPanel;
			}
		}
		// The design: the list at the top left, the chosen shader's sliders at the bottom left, its colors at the top right.
		var root = helix.ui.Layout2D.stack();
		root.setSizing(Grow(1), Grow(1));
		root.add(choice.layout);
		for (e in entries) {
			root.add(e.panel.layout);
			for (c in e.colors)
				root.add(c.panel.layout);
		}
		layout = root;
	}

	function entry(name:String, kind:String, on:Void->Void, sliders:Array<Setting>, ?colors:Array<ColorSetting>):Entry
		return {
			name: name,
			kind: kind,
			on: on,
			sliders: sliders,
			panel: null,
			colors: colors != null ? colors : [],
			color: 0
		};

	function slider(label:String, min:Float, max:Float, value:Float, step:Float, set:Float->Void):Setting
		return {
			label: label,
			min: min,
			max: max,
			value: value,
			step: step,
			set: set,
			widget: null
		};

	function color(label:String, value:Int, alpha:Bool, set:Int->Void):ColorSetting
		return {
			label: label,
			value: value,
			alpha: alpha,
			set: set,
			panel: null,
			which: null,
			picker: null
		};

	// A surface shader (or term) put on every material: make called with each.
	function surface(make:Material3D->Void):Void
		for (m in materials)
			make(m);

	// A sprite effect on the row but the creature, which keeps its palette (a sprite has one effect: without it, its indices show as
	// near-black reds).
	function row(effect:SpriteEffect):Void
		for (s in rowSprites)
			if (s != rowSprites[2])
				s.effect = effect;

	function newUnlit(m:Material3D):Unlit {
		var u = new Unlit(m);
		u.color = unlitColor;
		return u;
	}

	function newToon(m:Material3D):Toon {
		var t = new Toon(m);
		t.bands = toonBands;
		t.rim.power = toonRimPower;
		t.shadowColor = toonShadowColor;
		t.rim.color = toonRimColor;
		return t;
	}

	function newDissolve(m:Material3D):Dissolve {
		var d = new Dissolve(m);
		d.amount = dissolveAmount;
		d.edgeWidth = dissolveEdge;
		d.scale = dissolveScale;
		d.edgeIntensity = dissolveIntensity;
		d.edgeColor = dissolveEdgeColor;
		return d;
	}

	function newWater(m:Material3D):Water {
		var w = new Water(m);
		w.amplitude = waterAmplitude;
		w.wavelength = waterWavelength;
		w.shininess = waterShininess;
		w.deepColor = waterDeepColor;
		w.shallowColor = waterShallowColor;
		w.skyColor = waterSkyColor;
		return w;
	}

	// The flash held on a material, in the flash's color.
	function holdFlash(m:Material3D):Void {
		var flash = new HitFlash(m);
		flash.color = flashColor;
		flash.amount = flashAmount;
	}

	// Everything off: the materials on the default shading with no rim (none of them came with one) and no flash, no pass, effect or
	// sprite effect but the creature's own colors.
	function allOff():Void {
		for (m in materials) {
			m.setShader(null);
			new Rim(m, 0x00000000);
			new HitFlash(m).amount = 0;
		}
		toons = [];
		unlits = [];
		dissolves = [];
		waters = [];
		for (pass in outlines)
			pass.enabled = false;
		for (pass in silhouettes)
			pass.enabled = false;
		for (effect in [bloom, tonemap, fxaa, blur, colorLut, aberration, crt, pixelate, vignette])
			effect.enabled = false;
		spriteFlash.amount = 0;
		for (s in rowSprites)
			s.effect = null;
		rowSprites[2].effect = creatureColors;
	}

	// Chooses the shader named name (an entry's name), None for none: it alone on, its sliders shown. False for no such name, or before the
	// menu is made.
	function choose(name:String):Bool {
		if (list == null)
			return false;
		var index = -1;
		for (i in 0...entries.length)
			if (entries[i].name == name)
				index = i;
		if (index < 0 && name != "None")
			return false;
		list.selectedIndex = index;
		show(index);
		return true;
	}

	// Entry index (-1: none) chosen and on alone, its sliders shown.
	function show(index:Int):Void {
		chosen = index;
		shown = true;
		allOff();
		for (i in 0...entries.length) {
			var e = entries[i];
			e.panel.visible = i == index;
			for (k in 0...e.colors.length)
				e.colors[k].panel.visible = i == index && k == e.color;
		}
		if (index >= 0)
			entries[index].on();
	}

	override public function update(dt:Float):Void {
		// Read the program's input (the autopilot's while it plays: a tick a frame, none while a sample waits for its frame, none once done).
		var reading = pilot == null || (!pilot.done && pilot.advance(name -> probe(name)) != null && !pilot.awaitingFrame);
		// The design for the window's shape, the menu laid out in what's visible of it.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth,
			vh = Screen.visibleHeight;
		// The effects' view sees the stage's design units, as the stage does.
		Screen.apply(sceneCamera);
		if (ui != null && reading) {
			helix.ui.Layout2D.arrange(layout, vx, vy, vw, vh, ui.font);
			ui.update();
			if (list.changed)
				show(list.selectedIndex);
			if (chosen >= 0) {
				var e = entries[chosen];
				for (s in e.sliders)
					if (s.widget.changed)
						s.set(s.widget.value);
				var c = e.colors.length > 0 ? e.colors[e.color] : null;
				if (c != null && c.picker.changed)
					c.set(c.value = c.picker.color);
				// Another of its colors chosen: that color's panel shown in this one's place, its dropdown choosing it.
				if (c != null && c.which != null && c.which.changed && c.which.selectedIndex >= 0) {
					c.panel.visible = false;
					e.color = c.which.selectedIndex;
					c.which.selectedIndex = e.colors.indexOf(c);
					var next = e.colors[e.color];
					next.which.selectedIndex = e.color;
					next.panel.visible = true;
				}
			}
			if (!ui.capturingKeys) {
				var count = entries.length;
				if (Input.isFramePressed(Key.PageDown))
					choose(entries[chosen < 0 ? 0 : (chosen + 1) % count].name);
				if (Input.isFramePressed(Key.PageUp))
					choose(entries[chosen <= 0 ? count - 1 : chosen - 1].name);
			}
			if (Input.isFramePressed(Key.R) && !ui.capturingKeys && chosen >= 0 && entries[chosen].name == "PaletteSwap") {
				paletteSwap.row = (paletteSwap.row + 1) % PALETTE.length;
				var rowSlider = entries[chosen].sliders[0].widget;
				if (rowSlider != null)
					rowSlider.value = paletteSwap.row;
			}
			if (Input.isFramePressed(Key.X) && chosen >= 0) {
				shown = !shown;
				allOff();
				if (shown)
					entries[chosen].on();
			}
			if (Input.isFramePressed(Key.F)) {
				for (m in materials)
					new HitFlash(m).trigger(flashColor, .3);
				spriteFlash.trigger(spriteFlash.color, .3);
			}
			if (Input.isFramePressed(Key.O))
				orbit.running = !orbit.running;
			if (Host.canQuit() && Input.isFramePressed(Key.Escape) && !ui.capturingKeys)
				Host.quit();
		}
		// Her pose and the camera: held under the autopilot, as the stage's time is.
		if (animator != null)
			animator.update(piloted ? 0 : dt);
		orbit.update(piloted ? 0 : dt);
		fps.update(dt, Time.frameCpu);
		orbit.apply(camera);

		// The sprite row along the bottom of what's visible, right of the menu.
		var left = vx + 340, across = vw - 340 - 24;
		for (i in 0...rowSprites.length)
			rowSprites[i].setPosition(left + across * (i + .5) / rowSprites.length, vy + vh - 96);

		// The title and the keys over the menu.
		hud.clear();
		var title = chosen < 0 ? "nothing chosen" : entries[chosen].kind + " shader " + entries[chosen].name + (shown ? "" : " (off)");
		hud.drawTextWrapped('HeliX shader gallery: $title', vx + 16, vy + 36, 18, vw - 32, 0xfff5f5f5);
		hud.drawTextWrapped('PageDown / PageUp: next / previous  X: off and on  F: flash  O: camera${chosen >= 0 && entries[chosen].name == "PaletteSwap" ? "  R: next row" : ""}${status == "" ? "" : "   " + status}',
			vx
			+ 16, vy
			+ 60, 14, vw
			- 32, 0xffc8c8c8);
		fps.setPosition(vx + 16, vy + 10);
		if (pilot != null && pilot.done && !published) {
			published = true;
			TestHarness.publish({game: {chosen: probe("chosen"), hdr: post.hdr}, autopilot: pilot.snapshot});
			if (Host.getOption("autoclose", "0") == "1")
				Host.quit();
		}
	}

	override public function cleanup():Void {
		sceneView.postProcess = null;
		post.destroy();
		for (t in [grade, creature, palette, checker])
			t.destroy();
		sceneView.destroy();
		view3D.destroy();
	}
}

/** A slider of a shader's parameter: its text, range and step, the value it starts at, what it sets, and its widget once made. */
typedef Setting = {
	label:String,
	min:Float,
	max:Float,
	value:Float,
	step:Float,
	set:Float->Void,
	widget:Null<Slider>
}

/** A color of a shader's: its text, its value (0xAARRGGBB), whether its alpha means anything (its picker then has an alpha bar), what it sets,
	and once made its panel, the dropdown there choosing among the shader's colors (when it has several) and its picker. */
typedef ColorSetting = {
	label:String,
	value:Int,
	alpha:Bool,
	set:Int->Void,
	panel:Null<Panel>,
	which:Null<Dropdown>,
	picker:Null<ColorPicker>
}

/** A shader in the menu: its name, its kind (surface, pass, screen, sprite), how it's turned on (everything else off first), its sliders and
	their panel, its colors and which of them is shown. */
typedef Entry = {
	name:String,
	kind:String,
	on:Void->Void,
	sliders:Array<Setting>,
	panel:Null<Panel>,
	colors:Array<ColorSetting>,
	color:Int
}
