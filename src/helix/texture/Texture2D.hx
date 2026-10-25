package helix.texture;

import helix.graphics.IGraphics;
import helix.texture.Sampling;
import helix.texture.TextureFormat;
import haxe.io.Bytes;

/** A GPU texture with its size, its format and how it is sampled (Sampling: linear or nearest, and its wrap), which a draw reads when it
	takes the texture, so one texture can be drawn smooth and then sharp. whiteU/whiteV name an opaque white texel, -1 when it has none,
	for untextured shapes. */
class Texture2D {
	var levels:Int;

	/** The IGraphics handle, for draws. */
	public var handle(default, null):Int;

	/** Width in texels. */
	public var width(default, null):Int;

	/** Height in texels. */
	public var height(default, null):Int;

	/** Its texels' format: RGBA8, or a compressed one. */
	public var format(default, null):TextureFormat;

	/** How many levels it has: 1, or the image and its mipmaps. */
	public var levelCount(get, never):Int;

	function get_levelCount():Int
		return levels;

	/** The GPU memory its levels take, in bytes. */
	public var byteCount(get, never):Int;

	function get_byteCount():Int {
		var total = 0, w = width, h = height;
		for (_ in 0...levels) {
			total += format.levelBytes(w, h);
			w = w > 1 ? w >> 1 : 1;
			h = h > 1 ? h >> 1 : 1;
		}
		return total;
	}

	/** How draws sample it, from the next draw that takes it on. */
	public var sampling:Sampling;

	/** U of the center of an opaque white texel, or -1 when it has none. */
	public var whiteU(default, null):Float = -1.;

	/** V of the center of an opaque white texel, or -1 when it has none. */
	public var whiteV(default, null):Float = -1.;

	function new(handle:Int, width:Int, height:Int, format:TextureFormat, levels:Int, sampling:Sampling) {
		this.handle = handle;
		this.width = width;
		this.height = height;
		this.format = format;
		this.levels = levels;
		this.sampling = sampling;
	}

	/** Uploads width x height RGBA8 pixels, rows top first, filtered by filter (Linear smooth, Nearest sharp for pixel art); whiteX, whiteY name an
		opaque white texel for untextured shapes, -1 for none. mipmaps adds a chain (Mipmaps.build), so it can be drawn smaller than itself without
		shimmering. On gpu, the program's (Graphics) when not given. The caller destroys it. */
	public static function fromRgba(width:Int, height:Int, rgba:Bytes, filter:Filter = Nearest, whiteX = -1, whiteY = -1, mipmaps = false,
			?gpu:IGraphics):Texture2D {
		gpu = gpu != null ? gpu : helix.graphics.Graphics.instance;
		var levels = mipmaps ? helix.texture.Mipmaps.build(width, height, rgba) : [rgba];
		var texture = new Texture2D(gpu.createTexture(width, height, levels), width, height, Rgba8, levels.length, new Sampling(filter));
		if (whiteX >= 0) {
			texture.whiteU = (whiteX + .5) / width;
			texture.whiteV = (whiteY + .5) / height;
		}
		return texture;
	}

	/** Uploads levels (the image and its mipmaps, each format.levelBytes of its size) of format, width x height, sampled as sampling says. Throws
		when the GPU can't sample format (IGraphics.canSample). On gpu, the program's (Graphics) when not given. The caller destroys it. */
	public static function fromLevels(width:Int, height:Int, levels:Array<Bytes>, format:TextureFormat, sampling:Sampling, ?gpu:IGraphics):Texture2D {
		gpu = gpu != null ? gpu : helix.graphics.Graphics.instance;
		return new Texture2D(gpu.createTexture(width, height, levels, format), width, height, format, levels.length, sampling);
	}

	/** A render target width x height of format: a texture drawn into by target passes (IGraphics.beginTargetPass with its handle), sampled
		Linear (smooth) or Nearest (sharp: a low-resolution view shown larger); with depth a depth buffer and the screen's multisampling, without
		neither (IGraphics.createRenderTarget). Throws for a format the GPU can't draw into (IGraphics.canRender). On gpu, the program's (Graphics)
		when not given. The caller destroys it. */
	public static function renderTarget(width:Int, height:Int, filter:Filter = Linear, format:TextureFormat = Rgba8, depth = true, ?gpu:IGraphics):Texture2D {
		gpu = gpu != null ? gpu : helix.graphics.Graphics.instance;
		return new Texture2D(gpu.createRenderTarget(width, height, format, depth), width, height, format, 1, new Sampling(filter));
	}

	/** A new image in place of this one (a hot reload): the same object and sampling, a new GPU texture of levels. */
	@:allow(helix.texture.TextureCache)
	function replace(gpu:IGraphics, width:Int, height:Int, levels:Array<Bytes>, format:TextureFormat):Void {
		var old = handle;
		handle = gpu.createTexture(width, height, levels, format);
		this.width = width;
		this.height = height;
		this.format = format;
		this.levels = levels.length;
		gpu.destroyTexture(old);
	}

	/** Frees the GPU texture on gpu, the adapter that made it: the program's (Graphics) when not given. */
	public function destroy(?gpu:IGraphics):Void
		(gpu != null ? gpu : helix.graphics.Graphics.instance).destroyTexture(handle);
}
