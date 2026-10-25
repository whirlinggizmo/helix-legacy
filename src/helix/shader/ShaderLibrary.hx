package helix.shader;

import haxe.io.Bytes;
import helix.graphics.IGraphics;
import helix.texture.Sampling;
import helix.texture.Wrap;
import helix.graphics.Shader;
import helix.texture.Texture2D;

/** The shader library's programs on each GPU. A library shader's source (src/helix/shader/*.glsl) is packed at build time into generated
	Haxe holding its .hxshader (src/helix/tool/shader/ShaderPacker.hx: <Name>Packed.text()), so a class in helix.shader gets its shader at once, with no load
	and no asset, and a shader nothing uses is left out of the build. Each is built the first time it's asked for on a GPU and kept, shared
	by everything drawing with it, until the runner releases the GPU's. In development a hot reload brings the shaders packed again from
	changed sources, and each built is built again in place, as Shaders does an app's. */
@:noCompletion
@:allow(helix)
class ShaderLibrary {
	// Kept across a hot reload, so the reload's rebuild finds every GPU's shaders.
	@:hot static var all = new haxe.ds.ObjectMap<IGraphics, Map<String, {shader:Shader, text:String}>>();

	/** The library shader name (its source's file stem: "unlit") on gpu, built from text (its packed .hxshader, <Name>Packed.text()) the first
		time it's asked for there. Throws, saying why, for a program that doesn't build. */
	static function get(gpu:IGraphics, name:String, text:String):Shader {
		var shaders = all.get(gpu);
		if (shaders == null)
			all.set(gpu, shaders = new Map());
		var entry = shaders[name];
		if (entry == null)
			shaders[name] = entry = {shader: Shader.fromText(text, gpu), text: text};
		return entry.shader;
	}

	// Kept across a hot reload with the shaders: each GPU's noise texture.
	@:hot static var noises = new haxe.ds.ObjectMap<IGraphics, Texture2D>();

	/** The size of the library's noise texture, texels a side. */
	static inline var NOISE_SIZE = 128;

	/** The library's noise texture on gpu (Dissolve's unless a game gives its own), made the first time it's asked for there: NOISE_SIZE
		texels a side, tiling, smooth value noise of three octaves in its red, green and blue alike, its values spread evenly over 0..1 (so a
		threshold at t keeps the share 1 - t of it); the same texels on every target. Sampled linear, repeating. The library frees it with its
		shaders. */
	static function getNoise(gpu:IGraphics):Texture2D {
		var texture = noises.get(gpu);
		if (texture == null) {
			texture = Texture2D.fromRgba(NOISE_SIZE, NOISE_SIZE, noisePixels(), Linear, gpu);
			texture.sampling = new Sampling(Linear, Repeat, Repeat);
			noises.set(gpu, texture);
		}
		return texture;
	}

	// Kept across a hot reload with the shaders: each GPU's identity LUT.
	@:hot static var luts = new haxe.ds.ObjectMap<IGraphics, Texture2D>();

	/** The identity color LUT on gpu (ColorLut's until a game gives its own grade), made the first time it's asked for there from
		ColorLut.identity(): every color itself. Sampled linear, clamped. The library frees it with its shaders. */
	static function getIdentityLut(gpu:IGraphics):Texture2D {
		var texture = luts.get(gpu);
		if (texture == null) {
			texture = Texture2D.fromRgba(ColorLut.SIZE * ColorLut.SIZE, ColorLut.SIZE, ColorLut.identity(), Linear, gpu);
			luts.set(gpu, texture);
		}
		return texture;
	}

	/** The noise texture's texels (getNoise), RGBA8, rows top first. */
	static function noisePixels():Bytes {
		var n = NOISE_SIZE, values = [for (_ in 0...n * n) 0.];
		var period = 8, weight = 1.;
		for (_ in 0...3) {
			var cell = n / period;
			for (y in 0...n)
				for (x in 0...n) {
					var fx = x / cell, fy = y / cell;
					var ix = Std.int(fx), iy = Std.int(fy);
					var tx = fx - ix, ty = fy - iy;
					tx = tx * tx * (3 - 2 * tx);
					ty = ty * ty * (3 - 2 * ty);
					var a = lattice(ix % period, iy % period, period),
						b = lattice((ix + 1) % period, iy % period, period),
						c = lattice(ix % period, (iy + 1) % period, period),
						d = lattice((ix + 1) % period, (iy + 1) % period, period);
					values[y * n + x] += weight * (a + (b - a) * tx + (c - a) * ty + (a - b - c + d) * tx * ty);
				}
			period *= 2;
			weight /= 2;
		}
		// Spread evenly: each texel its rank among them all, so a threshold cuts away the share it says.
		var order = [for (i in 0...n * n) i];
		order.sort((i, j) -> values[i] < values[j] ? -1 : values[i] > values[j] ? 1 : i - j);
		var pixels = Bytes.alloc(n * n * 4);
		for (rank in 0...order.length) {
			var at = order[rank] * 4,
				v = Std.int(rank * 255 / (order.length - 1) + .5);
			pixels.set(at, v);
			pixels.set(at + 1, v);
			pixels.set(at + 2, v);
			pixels.set(at + 3, 255);
		}
		return pixels;
	}

	// A lattice point's value, 0..1, from an integer hash of its place and the octave's period: the same on every target.
	static function lattice(x:Int, y:Int, period:Int):Float {
		// Int32's arithmetic wraps alike on every target.
		var h:haxe.Int32 = x;
		h = h * 374761393 + (y : haxe.Int32) * 668265263 + (period : haxe.Int32) * 1103515245;
		h = (h ^ (h >>> 13)) * 1274126177;
		h = h ^ (h >>> 16);
		return (h & 0xffff) / 0xffff;
	}

	/** Frees gpu's library shaders, the pipelines made over them, its noise texture and its identity LUT, before the adapter shuts down. */
	static function release(gpu:IGraphics):Void {
		for (textures in [noises, luts]) {
			var texture = textures.get(gpu);
			if (texture != null) {
				texture.destroy(gpu);
				textures.remove(gpu);
			}
		}
		var shaders = all.get(gpu);
		if (shaders == null)
			return;
		for (entry in shaders)
			entry.shader.destroy();
		all.remove(gpu);
	}

	#if hotreload
	// Development only (hotreload-hx): a reload brings the library packed again; a shader whose text changed is built again in place (its
	// pipelines made again as they're next asked for), and one that no longer builds stays as it was, its log traced.
	@:afterHotReload static function reloadShaders():Void {
		var texts = PackedShaders.texts();
		for (shaders in all)
			for (name => entry in shaders) {
				var packed = texts[name];
				if (packed == null)
					continue;
				var text = packed();
				if (text == entry.text)
					continue;
				try {
					entry.shader.replace(text);
					entry.text = text;
				} catch (e:Dynamic)
					trace('helix.shader $name: $e');
			}
	}
	#end
}
