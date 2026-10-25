package helix.graphics;

import haxe.io.Bytes;
import helix.texture.Texture2D;
import helix.shader.Tonemap;
import helix.texture.TextureFormat;
import helix.texture.Sampling;

/** Screen effects over a finished frame: the scene is drawn into a texture the screen's size (beginScene to endScene, a target pass), the
	enabled effects but the last draw in turn from one texture into another (target passes without depth, still before the screen's), and
	present draws the last over the screen's pass, or the frame as it is when no effect is on. Effects run in the order added, so turning one
	off and on (ScreenEffect.enabled) keeps its place. Its textures follow the screen's size; an effect's intermediates
	(ScreenEffect.intermediates) are made at their fractions of it.

	An HDR chain: when an enabled effect wants HDR (ScreenEffect.hdr) and the GPU draws half floats (IGraphics.canRender), the scene is drawn
	in RGBA16F, the 3D views drawing into it (View3D: the stage tells them, View) writing their light after the exposure with no tone mapping, as sRGB values running past 1 (the sRGB curve
	carried on past 1, so sprites, particles and text, whose colors are sRGB values already, blend into it as into the screen, and are tone
	mapped with it). The tone mapping then runs as an effect (helix.shader.Tonemap, Neutral unless the chain has its own), after the last effect wanting HDR, unless the chain
	has one of its own; the effects before it read and write half floats, the ones after it the tone-mapped frame in RGBA8. Without half
	floats every texture is RGBA8 as the screen is, the 3D views tone map as they draw, and a Tonemap in the chain is skipped. An HDR scene is
	cleared to what its tone mapping shows as the clear color (Tonemap.computeHdrColor), so a background of clear color alone looks the same
	with the chain HDR or not. */
class PostProcess {
	var gpu:IGraphics;
	var effects:Array<ScreenEffect> = [];
	var width = 0;
	var height = 0;
	// The scene's texture (with depth, multisampled as the screen), and the chain's, two of each format in use, drawn back and forth.
	var scene:Null<Texture2D>;
	var chain:Map<Int, Array<Texture2D>> = [];
	// Each effect's intermediates, as last made.
	var made = new haxe.ds.ObjectMap<ScreenEffect, Array<Texture2D>>();
	// The tone mapping added to an HDR chain without one, made the first time.
	var tonemap:Null<Tonemap>;
	// This frame's effects in order (the tone mapping among them in an HDR chain) and the tone mapping's place in them (-1 for none).
	var steps:Array<ScreenEffect> = [];
	var tonemapAt = -1;
	var result:Null<Texture2D>;
	var last:Null<ScreenEffect>;
	var lastFrame:Null<ScreenFrame>;
	// An HDR scene's clear: the values, and the clear color and mode they were worked out for (mode -1: none yet).
	var hdrClear = [0., 0, 0, 0];
	var hdrClearOf = -1;
	var hdrClearMode = -1;
	// Drawing the frame as it is: two clip-space triangles, sampling it whole.
	var copyBuffer:Int;
	// The sprite program's block 0, its clip scale, which the adapter writes.
	var clip = Bytes.alloc(16);
	var quad = Bytes.alloc(6 * Sprite2DProgram.stride);

	/** Effects drawn on gpu (the program's, Graphics, when not given), over a scene (the stage's, Stage.postProcess, or a view's,
		View.postProcess). */
	public function new(?gpu:IGraphics) {
		this.gpu = gpu = gpu != null ? gpu : Graphics.instance;
		copyBuffer = gpu.createBuffer(6 * Sprite2DProgram.stride);
		var corners = [
			[-1, 1, 0, 0],
			[1, 1, 1, 0],
			[1, -1, 1, 1],
			[-1, 1, 0, 0],
			[1, -1, 1, 1],
			[-1, -1, 0, 1]
		];
		for (i in 0...6) {
			var at = i * Sprite2DProgram.stride, c = corners[i];
			quad.setFloat(at + Sprite2DProgram.positionOffset, c[0]);
			quad.setFloat(at + Sprite2DProgram.positionOffset + 4, c[1]);
			quad.setFloat(at + Sprite2DProgram.uvOffset, c[2]);
			quad.setFloat(at + Sprite2DProgram.uvOffset + 4, c[3]);
			for (k in 0...4)
				quad.setFloat(at + Sprite2DProgram.colorOffset + k * 4, 1);
		}
	}

	/** Whether this frame's scene (the last beginScene's) is drawn in half floats: an enabled effect wants HDR and the GPU draws them. */
	public var hdr(default, null):Bool = false;

	/** The texture the scene is drawn into (the last beginScene's), or null before one. */
	public var sceneTexture(get, never):Null<Texture2D>;

	function get_sceneTexture():Null<Texture2D>
		return scene;

	/** Adds effect at the end of the chain. False, changing nothing, when it is in the chain already. */
	public function add(effect:ScreenEffect):Bool {
		if (effects.indexOf(effect) >= 0)
			return false;
		effects.push(effect);
		return true;
	}

	/** Takes effect out of the chain, freeing its intermediates (the effect stays its owner's). False when it isn't in the chain. */
	public function remove(effect:ScreenEffect):Bool {
		if (!effects.remove(effect))
			return false;
		release(effect);
		return true;
	}

	/** Starts the frame's scene: a target pass into a width x height texture (the screen's size; half floats in an HDR chain), cleared to
		clearColor (0xAARRGGBB; in an HDR chain to the light its tone mapping shows as clearColor). Draw it as the screen; endScene ends it.
		Which effects draw this frame is taken here. Throws inside another pass. */
	public function beginScene(width:Int, height:Int, clearColor:Int):Void {
		plan();
		if (width != this.width || height != this.height) {
			clear();
			this.width = width;
			this.height = height;
		}
		var format:TextureFormat = hdr ? Rgba16f : Rgba8;
		if (scene != null && scene.format != format) {
			scene.destroy(gpu);
			scene = null;
		}
		if (scene == null)
			scene = Texture2D.renderTarget(width, height, Linear, format, gpu);
		if (hdr) {
			var tonemap:Tonemap = cast steps[tonemapAt];
			if (clearColor != hdrClearOf || (tonemap.mode : Int) != hdrClearMode) {
				tonemap.computeHdrColor(clearColor, hdrClear);
				hdrClearOf = clearColor;
				hdrClearMode = tonemap.mode;
			}
			gpu.beginTargetPass(scene.handle, hdrClear[0], hdrClear[1], hdrClear[2], hdrClear[3]);
		} else
			gpu.beginTargetPass(scene.handle, Color.getRed(clearColor) / 255, Color.getGreen(clearColor) / 255, Color.getBlue(clearColor) / 255,
				Color.getAlpha(clearColor) / 255);
	}

	/** Ends the scene's pass and draws the effects but the last (each that was enabled at beginScene, in order, with the tone mapping in an HDR
		chain), each its intermediates and then from the one before's result into a texture of the chain, at time seconds; the last's
		intermediates too, its last pass waiting for present. */
	public function endScene(time:Float):Void {
		gpu.endTargetPass();
		result = scene;
		last = null;
		lastFrame = null;
		for (i in 0...steps.length) {
			var effect = steps[i];
			var frame = new ScreenFrame(result, width, height, time, intermediatesOf(effect, i <= tonemapAt ? Rgba16f : Rgba8));
			effect.drawIntermediates(frame);
			if (i == steps.length - 1) {
				last = effect;
				lastFrame = frame;
				break;
			}
			var into = chainTarget(i < tonemapAt ? Rgba16f : Rgba8, result);
			gpu.beginTargetPass(into.handle, 0, 0, 0, 1);
			effect.draw(frame);
			gpu.endTargetPass();
			result = into;
		}
	}

	/** Draws the processed frame over the open screen pass's viewport: the last effect over the others' result, or the frame as it is. */
	public function present():Void {
		if (result == null)
			return;
		if (last != null) {
			last.draw(lastFrame);
			return;
		}
		gpu.updateBuffer(copyBuffer, quad, quad.length);
		gpu.draw(Pipelines.of(gpu).sprite2D(Opaque), [copyBuffer], 0, 0, 6, 0, 1, [result.handle], [Sampling.NEAREST], [clip]);
	}

	/** Frees its textures and buffer; the effects stay their owner's. */
	public function destroy():Void {
		clear();
		if (scene != null)
			scene.destroy(gpu);
		scene = null;
		gpu.destroyBuffer(copyBuffer);
	}

	// This frame's steps: the enabled effects; in an HDR chain the tone mapping after the last wanting HDR (unless the chain has its own),
	// without one no tone mapping (the 3D views' does it).
	function plan():Void {
		var on = [for (e in effects) if (e.enabled) e];
		var wanting = -1;
		for (i in 0...on.length)
			if (on[i].hdr)
				wanting = i;
		hdr = wanting >= 0 && gpu.canRender(Rgba16f);
		tonemapAt = -1;
		if (!hdr) {
			steps = [for (e in on) if (!Std.isOfType(e, Tonemap)) e];
			return;
		}
		steps = on;
		for (i in 0...steps.length)
			if (Std.isOfType(steps[i], Tonemap)) {
				tonemapAt = i;
				break;
			}
		if (tonemapAt < 0) {
			if (tonemap == null)
				tonemap = new Tonemap();
			tonemap.mode = helix.render3d.Tonemap.Neutral;
			tonemapAt = wanting + 1;
			steps.insert(tonemapAt, tonemap);
		}
	}

	// The chain's texture of format to draw into that isn't from (the one it reads), made the first time.
	function chainTarget(format:TextureFormat, from:Texture2D):Texture2D {
		var pair = chain[format];
		if (pair == null)
			chain[format] = pair = [];
		var i = pair.length > 0 && pair[0] == from ? 1 : 0;
		if (pair[i] == null)
			pair[i] = Texture2D.renderTarget(width, height, Linear, format, false, gpu);
		return pair[i];
	}

	// effect's intermediates in format at its fractions of the frame's size: made again when they or the size changed.
	function intermediatesOf(effect:ScreenEffect, format:TextureFormat):Array<Texture2D> {
		var scales = effect.intermediates, have = made.get(effect);
		var sizes = [for (s in scales) [size(width, s), size(height, s)]];
		var current = have != null && have.length == scales.length;
		if (current)
			for (i in 0...have.length)
				if (have[i].width != sizes[i][0] || have[i].height != sizes[i][1] || have[i].format != format)
					current = false;
		if (current)
			return have;
		release(effect);
		var textures = [for (s in sizes) Texture2D.renderTarget(s[0], s[1], Linear, format, false, gpu)];
		made.set(effect, textures);
		return textures;
	}

	// A fraction of a length in pixels: rounded down, at least 1.
	static function size(length:Int, fraction:Float):Int {
		var n = Math.floor(length * fraction);
		return n < 1 ? 1 : n;
	}

	// Frees effect's intermediates.
	function release(effect:ScreenEffect):Void {
		var have = made.get(effect);
		if (have == null)
			return;
		for (t in have)
			t.destroy(gpu);
		made.remove(effect);
	}

	// Frees every texture sized to the screen: the scene's, the chain's, the effects' intermediates.
	function clear():Void {
		if (scene != null)
			scene.destroy(gpu);
		scene = null;
		for (pair in chain)
			for (t in pair)
				if (t != null)
					t.destroy(gpu);
		chain.clear();
		for (effect in [for (e in made.keys()) e])
			release(effect);
		result = null;
		last = null;
		lastFrame = null;
	}
}
