import Render2DTests.CountingGraphics;
import helix.graphics.Color;
import helix.graphics.Graphics;
import helix.graphics.PostProcess;
import helix.graphics.ScreenEffect;
import helix.graphics.ScreenFrame;
import helix.graphics.Shader;
import helix.texture.TextureFormat;
import haxe.io.Bytes;
import helix.texture.Texture2D;
import helix.render3d.Renderer3D;
import helix.shader.Bloom;
import helix.shader.Blur;
import helix.shader.ChromaticAberration;
import helix.shader.ColorLut;
import helix.shader.Crt;
import helix.shader.Fxaa;
import helix.shader.Pixelate;
import helix.shader.ShaderLibrary;
import helix.shader.Tonemap;
import helix.shader.Vignette;

/** An effect of several passes: intermediates at the fractions given, each drawn into from the one before (the first from the frame). */
@:access(helix)
class Steps extends ScreenEffect {
	public function new(gpu:CountingGraphics, shader:Shader, fractions:Array<Float>) {
		super(shader, false, gpu);
		intermediates = fractions;
	}

	override public function drawIntermediates(frame:ScreenFrame):Void {
		var from = frame.source;
		for (t in frame.intermediates) {
			drawInto(t, from, frame.time);
			from = t;
		}
	}
}

/** PostProcess's plan: which textures a chain gets, at which sizes and in which formats, and which of them each pass draws into, on graphics
	that only counts: an 8-bit chain, intermediates at fractions of the screen, an HDR chain with its tone mapping added (and without half
	floats, none), the order kept through add and remove, and sizes following the screen; Bloom's chain of levels, down and back up; the
	library's screen effects' fields written where their shaders' reflection puts them, held to their ranges; the identity LUT's texels. */
@:access(helix)
class PostProcessTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static var gpu:CountingGraphics;
	static var shader:Shader;

	// The target a pass drew into, by its place in this frame's passes.
	static function pass(i:Int):{
		width:Int,
		height:Int,
		format:TextureFormat,
		depth:Bool
	}
		return gpu.renderTargets[gpu.targetPasses[i]];

	// A frame of post at width x height, the passes counted from its start.
	static function frame(post:PostProcess, width:Int, height:Int):Void {
		gpu.targetPasses = [];
		post.beginScene(width, height, 0xff000000);
		post.endScene(1);
		gpu.beginFrame(width, height, 0xff000000);
		post.present();
	}

	// An sRGB value (running past 1 too) to linear light, and back, as the tone mapping's shader works them.
	static function decode(v:Float):Float
		return v < .04045 ? v / 12.92 : Math.pow((v + .055) / 1.055, 2.4);

	static function encode(v:Float):Float
		return v < .0031308 ? v * 12.92 : 1.055 * Math.pow(v, 1 / 2.4) - .055;

	// An HDR scene's clear: for each mode, the light Tonemap.computeHdrColor answers is shown (tone mapped as the shader does, written as
	// 8 bits) as the color asked for, so a background of clear color alone looks the same with an HDR chain and without; PostProcess clears an
	// 8-bit scene to the color and an HDR one to that light, worked out again when the mode changes.
	static function hdrClear():Void {
		var tonemap = new Tonemap();
		var colors = [
			0xff14161c,
			0xff000000,
			0xff808080,
			0xff87ceeb,
			0xffc04020,
			0x802a2f3c,
			0xffffffff
		];
		for (mode in [
			helix.render3d.Tonemap.None,
			helix.render3d.Tonemap.Neutral,
			helix.render3d.Tonemap.Aces
		]) {
			tonemap.mode = mode;
			for (color in colors) {
				var out = [];
				tonemap.computeHdrColor(color, out);
				var shown = Tonemap.map(mode, [for (c in 0...3) decode(out[c])]);
				for (c in 0...3) {
					var asked = (Color.toRgba(color) >>> (24 - 8 * c)) & 255;
					check(Math.abs(encode(shown[c]) * 255 - asked) <= .5, 'Mode $mode shows ${StringTools.hex(color, 8)}\'s channel $c as given');
				}
				check(out[3] == Color.getAlpha(color) / 255, "The alpha is the color's");
			}
		}
		tonemap.mode = Neutral;
		var dark = [];
		tonemap.computeHdrColor(0xff14161c, dark);
		check(dark[0] > 0x14 / 255 && dark[2] > 0x1c / 255, "Neutral's toe darkens, so its clear is lighter than the color");
		var white = [];
		tonemap.computeHdrColor(0xffffffff, white);
		check(white[0] == white[1] && white[0] > 2, "White under Neutral is the most light it answers");

		var post = new PostProcess(gpu);
		var bright = new ScreenEffect(shader, gpu);
		bright.hdr = true;
		post.add(bright);
		gpu.targetPasses = [];
		gpu.targetClears = [];
		post.beginScene(800, 600, 0xff14161c);
		post.endScene(1);
		check(gpu.targetClears[0][0] == dark[0] && gpu.targetClears[0][2] == dark[2], "An HDR scene is cleared to the light Neutral shows as its color");
		// A chain with a tone mapping of its own in another mode: its clear worked out for that mode.
		var ownMode = new Tonemap();
		ownMode.mode = Aces;
		post.add(ownMode);
		gpu.targetClears = [];
		post.beginScene(800, 600, 0xff14161c);
		post.endScene(1);
		var aces = [];
		tonemap.mode = Aces;
		tonemap.computeHdrColor(0xff14161c, aces);
		check(gpu.targetClears[0][0] == aces[0] && aces[0] != dark[0], "Its clear is worked out again for the mode");
		bright.enabled = false;
		post.remove(ownMode);
		gpu.targetClears = [];
		post.beginScene(800, 600, 0xff14161c);
		post.endScene(1);
		check(gpu.targetClears[0][0] == 0x14 / 255 && gpu.targetClears[0][1] == 0x16 / 255 && gpu.targetClears[0][3] == 1,
			"An 8-bit scene is cleared to its color as given");
		post.destroy();
	}

	static function main():Void {
		gpu = new CountingGraphics();
		@:privateAccess Graphics.bind(gpu);
		var stages = {vertex: "", fragment: ""};
		var text = haxe.Json.stringify({
			helixShader: 2,
			kind: "screen",
			attributes: [],
			glsl410: stages,
			glsl300es: stages,
			uniformBlocks: [
				{
					slot: 0,
					stage: "vertex",
					size: 16,
					glslName: "v",
					vec4s: 1,
					name: "helix_screen_vs_params"
				},
				{
					slot: 1,
					stage: "fragment",
					size: 16,
					glslName: "f",
					vec4s: 1,
					name: "helix_screen_params"
				}
			],
			textures: [
				{
					slot: 0,
					stage: "fragment",
					name: "helix_screen_texture",
					glslName: "a"
				}
			]
		});
		shader = Shader.fromText(text, gpu);

		// No effect: the scene alone, RGBA8 with depth at the screen's size, copied to the screen.
		var post = new PostProcess(gpu);
		frame(post, 800, 600);
		check(gpu.targetPasses.length == 1
			&& pass(0).width == 800
			&& pass(0).height == 600
			&& pass(0).format == Rgba8
			&& pass(0).depth,
			"Without effects the scene is one RGBA8 texture with depth, the screen's size");
		check(gpu.draws.length == 1 && gpu.draws[0].vertices == 6, "The scene is copied to the screen as it is");

		// Two effects, 8 bits: the first draws into a texture of the chain without depth, the last over the screen.
		var a = new ScreenEffect(shader, gpu),
			b = new ScreenEffect(shader, gpu);
		check(post.add(a) && post.add(b) && !post.add(a), "Effects are added once");
		frame(post, 800, 600);
		check(!post.hdr && gpu.targetPasses.length == 2 && pass(0).format == Rgba8 && pass(0).depth, "An 8-bit chain's scene is RGBA8 with depth");
		check(pass(1).width == 800 && pass(1).height == 600 && pass(1).format == Rgba8 && !pass(1).depth,
			"The chain's textures are the screen's size, RGBA8, without depth");
		var c = new ScreenEffect(shader, gpu);
		post.add(c);
		frame(post, 800, 600);
		check(gpu.targetPasses.length == 3 && gpu.targetPasses[1] != gpu.targetPasses[2] && !pass(2).depth,
			"Three effects draw back and forth between two textures");
		b.enabled = false;
		frame(post, 800, 600);
		check(gpu.targetPasses.length == 2, "An effect turned off is skipped");
		b.enabled = true;
		check(post.remove(c) && !post.remove(c), "An effect is removed once");

		// Intermediates: fractions of the screen each way, rounded down, at least a pixel, in the frame's format, without depth; the last
		// effect's drawn before the screen's pass too.
		var steps = new Steps(gpu, shader, [.5, .25, .001]);
		post.add(steps);
		frame(post, 801, 601);
		check(gpu.targetPasses.length == 6, "The scene, two effects' passes and the last effect's three intermediates are drawn before the screen");
		check(pass(3).width == 400 && pass(3).height == 300 && pass(4).width == 200 && pass(4).height == 150 && pass(5).width == 1 && pass(5).height == 1,
			"Intermediates are their fractions of the screen, rounded down, at least a pixel");
		check(pass(3).format == Rgba8 && !pass(3).depth, "An 8-bit chain's intermediates are RGBA8 without depth");
		var made = Lambda.count(gpu.renderTargets);
		frame(post, 801, 601);
		check(Lambda.count(gpu.renderTargets) == made, "The same size makes nothing again");
		var destroyed = gpu.destroyedTextures;
		frame(post, 640, 480);
		check(gpu.destroyedTextures - destroyed == 6
			&& pass(0).width == 640
			&& pass(3).width == 320, "A new size makes every texture again");
		destroyed = gpu.destroyedTextures;
		post.remove(steps);
		check(gpu.destroyedTextures - destroyed == 3, "A removed effect's intermediates are freed");

		// HDR: an effect wanting it opens the scene in half floats; the tone mapping follows the last effect wanting HDR (Neutral, unless the
		// chain has its own), the ones before it drawing half floats, the ones after it RGBA8.
		var hdrPost = new PostProcess(gpu);
		var bright = new Steps(gpu, shader, [.5]);
		bright.hdr = true;
		var after = new ScreenEffect(shader, gpu);
		hdrPost.add(bright);
		hdrPost.add(after);
		gpu.targetPasses = [];
		hdrPost.beginScene(800, 600, 0xff000000);
		check(hdrPost.hdr, "An effect wanting HDR draws the scene HDR");
		hdrPost.endScene(1);
		check(pass(0).format == Rgba16f && pass(0).depth, "An HDR scene is half floats with depth");
		check(gpu.targetPasses.length == 4 && pass(1).format == Rgba16f && pass(1).width == 400 && !pass(1).depth,
			"The scene, the HDR effect's intermediate in half floats, its pass, the tone mapping's");
		check(pass(2).format == Rgba16f && !pass(2).depth && pass(3).format == Rgba8 && !pass(3).depth,
			"Before the tone mapping the chain is half floats, from it on RGBA8");
		var tonemap:Tonemap = @:privateAccess hdrPost.tonemap;
		check(tonemap != null && tonemap.mode == Neutral && @:privateAccess hdrPost.steps[1] == tonemap, "The tone mapping added is Neutral");

		// Without half floats: 8 bits throughout, no tone mapping added, and a Tonemap of the chain's own skipped.
		gpu.floatTargets = false;
		var own = new Tonemap();
		hdrPost.add(own);
		frame(hdrPost, 800, 600);
		check(!hdrPost.hdr && pass(0).format == Rgba8 && gpu.targetPasses.length == 3 && pass(1).format == Rgba8,
			"Without half floats the chain is RGBA8 and no tone mapping runs");

		// A Tonemap of the chain's own is where it was added, and none is added.
		gpu.floatTargets = true;
		hdrPost.remove(after);
		hdrPost.add(after);
		frame(hdrPost, 800, 600);
		var planned:Array<ScreenEffect> = @:privateAccess hdrPost.steps;
		check(planned.length == 3 && planned[1] == own && planned[2] == after, "A Tonemap of the chain's own is used where it was added");
		check(pass(3).format == Rgba8, "After its own tone mapping the chain is RGBA8");
		post.destroy();
		hdrPost.destroy();
		gpu.floatTargets = true;
		hdrClear();
		bloom();
		fields();
		identity();
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}

	// The bytes effect's parameters write, by slot (null for a slot its shader lacks).
	static function blocks(effect:ScreenEffect):Array<Null<Bytes>> {
		var out = [for (size in effect.shader.blockSizes) size > 0 ? Bytes.alloc(size) : null];
		effect.parameters.write(out);
		return out;
	}

	// The value effect's parameter name is written as, its component i, checked at offset in block 2 (the effect's own).
	static function written(effect:ScreenEffect, name:String, offset:Int, i = 0):Float {
		var p = effect.shader.getParameter(name);
		check(p != null && p.slot == 2 && p.offset == offset, '${Type.getClassName(Type.getClass(effect))}\'s $name at $offset in its block');
		return blocks(effect)[2].getFloat(offset + i * 4);
	}

	static function near(a:Float, b:Float):Bool
		return Math.abs(a - b) < 1e-5;

	// Bloom in an HDR chain: its levels going down, halving from half the screen, then back up, in half floats without depth; its composite
	// into the chain and the tone mapping after it; each step reading what it should. Without half floats the same in RGBA8, thresholding the
	// tone-mapped frame.
	static function bloom():Void {
		var bloom = new Bloom();
		check(bloom.hdr, "Bloom wants HDR");
		var post = new PostProcess(gpu);
		post.add(bloom);
		frame(post, 800, 600);
		check(post.hdr && gpu.targetPasses.length == 1 + Bloom.LEVELS + Bloom.LEVELS - 1 + 1,
			"The scene, the levels down, the levels back up, the bloom added to the frame; the tone mapping over the screen");
		var sizes = [[400, 300], [200, 150], [100, 75], [50, 37], [25, 18], [12, 9]];
		for (i in 0...Bloom.LEVELS)
			check(pass(1 + i).width == sizes[i][0] && pass(1 + i).height == sizes[i][1] && pass(1 + i).format == Rgba16f && !pass(1 + i).depth,
				'Level $i going down is ${sizes[i]}, half floats without depth');
		for (k in 0...Bloom.LEVELS - 1) {
			var level = Bloom.LEVELS - 2 - k;
			check(pass(1 + Bloom.LEVELS + k).width == sizes[level][0]
				&& pass(1 + Bloom.LEVELS + k).height == sizes[level][1]
				&& pass(1 + Bloom.LEVELS + k).format == Rgba16f
				&& gpu.targetPasses[1 + Bloom.LEVELS + k] != gpu.targetPasses[1 + level],
				'Coming up, level $level is ${sizes[level]}, a texture of its own');
		}
		var last = 1 + 2 * Bloom.LEVELS - 1;
		check(pass(last).width == 800 && pass(last).format == Rgba16f, "The bloom is added into the chain's half floats, the tone mapping after");
		var tonemap:Tonemap = @:privateAccess post.tonemap;
		check(@:privateAccess post.steps[1] == tonemap, "The tone mapping follows the bloom");

		// Its steps by hand: what each reads.
		var source = Texture2D.renderTarget(64, 64, Linear, Rgba16f, false, gpu);
		var levels = [
			for (f in bloom.intermediates)
				Texture2D.renderTarget(Std.int(Math.max(1, Math.floor(64 * f))), Std.int(Math.max(1, Math.floor(64 * f))), Linear, Rgba16f, false, gpu)
		];
		check(levels.length == 2 * Bloom.LEVELS - 1
			&& bloom.intermediates[Bloom.LEVELS] == .5, "Its intermediates: the levels down, then up");
		var screenFrame = new ScreenFrame(source, 64, 64, 1, levels);
		bloom.threshold = 2;
		bloom.knee = .25;
		bloom.drawIntermediates(screenFrame);
		var drawn:{textures:Array<Int>, uniforms:Array<Null<Bytes>>} = gpu.screen;
		var slot = bloom.shader.getTextureSlot("bloom_texture");
		check(slot == 1 && drawn.textures[0] == levels[Bloom.LEVELS + 1].handle && drawn.textures[slot] == levels[0].handle,
			"The last step up reads the level below coming up, and adds the first level going down");
		check(near(drawn.uniforms[2].getFloat(8), 2)
			&& near(drawn.uniforms[2].getFloat(12), 2)
			&& near(drawn.uniforms[2].getFloat(16), .5),
			"A step up's mode, an HDR frame's threshold, and the knee's width in light");
		check(near(drawn.uniforms[2].getFloat(0), 1 / levels[Bloom.LEVELS + 1].width), "It steps by a texel of what it reads");
		bloom.draw(screenFrame);
		drawn = gpu.screen;
		check(drawn.textures[0] == source.handle
			&& drawn.textures[slot] == levels[Bloom.LEVELS].handle
			&& near(drawn.uniforms[2].getFloat(8), 3),
			"Its last pass adds the first level coming up to the frame");
		check(near(drawn.uniforms[2].getFloat(20), 1 / Bloom.LEVELS), "Its intensity over the levels summed");
		var flat = Texture2D.renderTarget(64, 64, Linear, Rgba8, false, gpu);
		bloom.toneMappedThreshold = .7;
		bloom.drawIntermediates(new ScreenFrame(flat, 64, 64, 1, levels));
		check(near(gpu.screen.uniforms[2].getFloat(12), .7), "A tone-mapped frame is thresholded at toneMappedThreshold");

		// Without half floats: the same chain in RGBA8, no tone mapping.
		gpu.floatTargets = false;
		frame(post, 800, 600);
		check(!post.hdr && gpu.targetPasses.length == 1 + 2 * Bloom.LEVELS - 1 && pass(1).format == Rgba8 && pass(1).width == 400,
			"Without half floats the levels are RGBA8 and the bloom is the last pass, over the screen");
		gpu.floatTargets = true;
		post.destroy();
	}

	// Each library screen effect's fields: written where the reflection puts them, held to their ranges.
	static function fields():Void {
		var bloom = new Bloom();
		check(bloom.threshold == 1 && bloom.knee == .5 && bloom.intensity == 1, "Bloom's defaults");
		bloom.intensity = 40;
		bloom.threshold = -1;
		bloom.knee = Math.NaN;
		check(bloom.intensity == 16
			&& bloom.threshold == 0
			&& bloom.knee == 0
			&& near(written(bloom, "intensity", 20), 16 / Bloom.LEVELS),
			"Bloom's fields held to their ranges");

		var fxaa = new Fxaa();
		check(near(written(fxaa, "subpixel", 0), .75)
			&& near(written(fxaa, "edge_threshold", 4), .166)
			&& near(written(fxaa, "edge_threshold_min", 8), .0833),
			"Fxaa's defaults, FXAA 3.11's");
		fxaa.edgeThreshold = 1;
		fxaa.subpixel = -1;
		check(fxaa.edgeThreshold == .333 && near(written(fxaa, "edge_threshold", 4), .333) && written(fxaa, "subpixel", 0) == 0,
			"Fxaa's fields held to their ranges");

		var blur = new Blur(12, .25);
		check(blur.intermediates.length == 1 && blur.intermediates[0] == .25, "Blur's one texture at its resolution");
		blur.resolution = 0;
		blur.radius = 1000;
		check(blur.intermediates[0] == 1 / 16 && blur.radius == 128, "Blur's fields held to their ranges");
		var source = Texture2D.renderTarget(800, 600, Linear, Rgba8, false, gpu),
			half = Texture2D.renderTarget(400, 300, Linear, Rgba8, false, gpu);
		blur.radius = 16;
		var screenFrame = new ScreenFrame(source, 800, 600, 0, [half]);
		blur.drawIntermediates(screenFrame);
		check(gpu.screen.textures[0] == source.handle
			&& near(gpu.screen.uniforms[2].getFloat(0), 2 / 800)
			&& gpu.screen.uniforms[2].getFloat(4) == 0,
			"Blur's first pass across the frame, taps radius / 8 pixels apart");
		blur.draw(screenFrame);
		check(gpu.screen.textures[0] == half.handle
			&& gpu.screen.uniforms[2].getFloat(0) == 0
			&& near(gpu.screen.uniforms[2].getFloat(4), 2 / 600),
			"Its second down, from its texture");

		var vignette = new Vignette(.7);
		check(near(written(vignette, "strength", 16), .7)
			&& near(written(vignette, "radius", 20), .4)
			&& near(written(vignette, "softness", 24), .6)
			&& written(vignette, "color", 0, 3) == 1,
			"Vignette's fields");
		vignette.color = 0x00ff8000;
		vignette.softness = 0;
		check(near(written(vignette, "color", 0), 1)
			&& near(written(vignette, "color", 0, 1), 0x80 / 255)
			&& near(written(vignette, "softness", 24), .001),
			"Vignette's color as it is, its softness held above 0");

		var crt = new Crt();
		check(written(crt, "lines", 0) == 240
			&& near(written(crt, "darkness", 4), .35)
			&& near(written(crt, "curvature", 8), .3)
			&& near(written(crt, "mask", 12), .3)
			&& written(crt, "mask_size", 16) == 1
			&& near(written(crt, "flicker", 20), .5),
			"Crt's fields");
		crt.lines = 0;
		crt.curvature = 3;
		check(crt.lines == 1 && crt.curvature == 1, "Crt's fields held to their ranges");

		var aberration = new ChromaticAberration();
		aberration.amount = 100;
		check(aberration.amount == 64 && written(aberration, "amount", 0) == 64, "ChromaticAberration's amount held to 64");

		var pixelate = new Pixelate(10);
		check(written(pixelate, "cell_size", 0) == 10, "Pixelate's cell size");
		pixelate.cellSize = 0;
		check(pixelate.cellSize == 1 && written(pixelate, "cell_size", 0) == 1, "A cell at least a pixel");

		var grade = new ColorLut();
		var slot = grade.shader.getTextureSlot("lut_texture");
		check(slot == 1 && grade.parameters.getTexture("lut_texture") == ShaderLibrary.getIdentityLut(gpu) && grade.lut == null,
			"ColorLut grades through the library's identity until given a LUT, at slot 1");
		var own = Texture2D.fromRgba(1024, 32, ColorLut.identity(), Linear, gpu);
		grade.lut = own;
		grade.amount = 2;
		check(grade.parameters.getTexture("lut_texture") == own && grade.amount == 1 && written(grade, "amount", 0) == 1,
			"A LUT of the game's; its amount held to 1");
		check(ShaderLibrary.getIdentityLut(gpu) == ShaderLibrary.getIdentityLut(gpu), "The identity LUT is made once a GPU");
	}

	// The identity strip: 1024 x 32, blue choosing the square, red across it, green down, each channel i * 255 / 31.
	static function identity():Void {
		var strip = ColorLut.identity();
		check(strip.length == 1024 * 32 * 4, "The strip is 1024 x 32 RGBA8");
		inline function texel(x:Int, y:Int):Array<Int> {
			var at = (y * 1024 + x) * 4;
			return [strip.get(at), strip.get(at + 1), strip.get(at + 2), strip.get(at + 3)];
		}
		check(texel(0, 0).join(",") == "0,0,0,255"
			&& texel(1023, 31).join(",") == "255,255,255,255", "Black at its first texel, white at its last");
		check(texel(31, 0).join(",") == "255,0,0,255"
			&& texel(0, 31).join(",") == "0,255,0,255"
			&& texel(992, 0).join(",") == "0,0,255,255",
			"Red across a square, green down, blue by the square");
		check(texel(32 * 10 + 5, 20).join(",") == '${Std.int(5 * 255 / 31 + .5)},${Std.int(20 * 255 / 31 + .5)},${Std.int(10 * 255 / 31 + .5)},255',
			"Each channel its index times 255 / 31, rounded");
	}
}
