package helix.adapter.graphics.webgl2;

import haxe.io.Bytes;
import helix.graphics.BlendMode;
import helix.graphics.Color;
import helix.graphics.IGraphics;
import helix.graphics.IGraphics.ReadPixelsResult;
import helix.graphics.PipelineDesc;
import helix.graphics.DepthTest;
import helix.graphics.ClipFlip;
import helix.texture.Sampling;
import helix.graphics.ShaderSource;
import helix.texture.TextureFormat;
import js.html.CanvasElement;
import js.html.webgl.WebGL2RenderingContext;

/** A render target: the framebuffer of its texture and its depth buffer (null without), its size, whether it holds half floats; multisampled,
	the framebuffer drawn into and its color. */
private typedef Target = {
	framebuffer:Dynamic,
	depth:Dynamic,
	half:Bool,
	drawn:Dynamic,
	color:Dynamic,
	width:Int,
	height:Int
}

/** IGraphics on a canvas's WebGL2 context: raw browser API calls only. It builds whatever program it is given (a ShaderSource's GLSL ES) and
	makes whatever pipeline it is described (a PipelineDesc); it knows no program, layout or pipeline of HeliX's own. */
@:noCompletion
class WebGL2GraphicsAdapter implements IGraphics {
	var gl:WebGL2RenderingContext;

	var next = 1;
	var buffers:Map<Int, Dynamic> = [];
	var textures:Map<Int, Dynamic> = [];
	// One sampler object for each Sampling value used, made when first used.
	var samplers:Array<Dynamic> = [];
	// Whether each TextureFormat is sampled, and drawn into, once asked.
	var formats:Array<Null<Bool>> = [];
	var renderable:Array<Null<Bool>> = [];
	// Programs, by handle: the linked program, its uniform blocks' locations and sizes by slot, its textures' sampler locations by slot.
	var shaders:Map<Int, {program:Dynamic, blocks:Array<Null<{location:Dynamic, size:Int}>>, textures:Array<Dynamic>}> = [];
	// Pipelines, by handle: their description.
	var pipelines:Map<Int, PipelineDesc> = [];
	// Cube textures' handles.
	var cubes:Map<Int, Bool> = [];
	// Data textures, by handle: their size.
	var dataTextures:Map<Int, {width:Int, height:Int}> = [];
	var active = false;
	// In a target pass: drawn flipped, as GL's framebuffers' origin is the bottom left, so a target is stored top row first like any texture.
	var flipped = false;
	var inTarget = false;
	// The screen's size this frame, and whether endFrame has ended it (so it can be read back).
	var frameWidth = 0;
	var frameHeight = 0;
	var frameEnded = false;
	var passHeight = 0;
	// Render targets, by texture handle: their framebuffer, depth buffer and size; multisampled, the framebuffer drawn into (its color and
	// depth the screen's samples), resolved into the texture's at the pass's end.
	var targets:Map<Int, Target> = [];
	// The target a target pass draws into, or null.
	var drawing:Null<Target>;
	// Multisampling samples a pixel of the canvas, as the browser gave them.
	// Shadow maps, by texture handle: a framebuffer a layer, and their size.
	var shadowMaps:Map<Int, {framebuffers:Array<Dynamic>, size:Int}> = [];
	// The sampler shadow maps are read through: comparing, linear, clamped.
	var comparison:Dynamic = null;
	// A block 0 turned over for a flipped pass, reused.
	var flippedBlock = new js.lib.Float32Array(64);
	// Attribute slots enabled by the last draw: each draw enables its own and turns the rest off.
	var enabled:Array<Bool> = [];

	/** Takes canvas's WebGL2 context, without alpha or stencil, with a depth buffer, antialiased (multisampled) when msaaSamples is over 1: the
		browser chooses how many (msaaSamples), nearly always 4. preserve keeps the drawing buffer between frames. Throws GraphicsUnavailable
		without WebGL2. */
	public function new(canvas:CanvasElement, preserve:Bool, msaaSamples:Int) {
		gl = cast canvas.getContext("webgl2", {
			alpha: false,
			antialias: msaaSamples > 1,
			depth: true,
			stencil: false,
			preserveDrawingBuffer: preserve
		});
		if (gl == null)
			throw new helix.graphics.GraphicsUnavailable("WebGL2 is required");
		this.msaaSamples = Std.int(Math.max(1, gl.getParameter(WebGL2RenderingContext.SAMPLES)));
	}

	@:isVar public var msaaSamples(get, null):Int = 1;

	function get_msaaSamples():Int
		return msaaSamples;

	// The canvas's own count when antialiased; otherwise the 4 browsers give, where the GPU has 4.
	public var maxMsaaSamples(get, never):Int;

	function get_maxMsaaSamples():Int
		return msaaSamples > 1 ? msaaSamples : gl.getParameter(WebGL2RenderingContext.MAX_SAMPLES) >= 4 ? 4 : 1;

	public function createTexture(width:Int, height:Int, levels:Array<Bytes>, format:TextureFormat = Rgba8):Int {
		if (width <= 0 || height <= 0 || levels.length == 0 || !canSample(format))
			throw "Invalid texture";
		var tex = gl.createTexture();
		gl.bindTexture(WebGL2RenderingContext.TEXTURE_2D, tex);
		gl.pixelStorei(WebGL2RenderingContext.UNPACK_ALIGNMENT, 1);
		var lw = width, lh = height;
		for (i in 0...levels.length) {
			if (levels[i].length != format.levelBytes(lw, lh)) {
				gl.deleteTexture(tex);
				throw "Invalid texture";
			}
			upload(WebGL2RenderingContext.TEXTURE_2D, i, format, lw, lh, levels[i], 0);
			lw = lw > 1 ? Std.int(lw / 2) : 1;
			lh = lh > 1 ? Std.int(lh / 2) : 1;
		}
		gl.texParameteri(WebGL2RenderingContext.TEXTURE_2D, WebGL2RenderingContext.TEXTURE_MAX_LEVEL, levels.length - 1);
		var id = next++;
		textures[id] = tex;
		return id;
	}

	public function createDataTexture(width:Int, height:Int):Int {
		var largest:Int = gl.getParameter(WebGL2RenderingContext.MAX_TEXTURE_SIZE);
		if (width <= 0 || height <= 0 || width > largest || height > largest)
			throw "Invalid data texture";
		var tex = gl.createTexture();
		gl.bindTexture(WebGL2RenderingContext.TEXTURE_2D, tex);
		// One immutable level: complete under any sampler, as texelFetch reads it.
		gl.texStorage2D(WebGL2RenderingContext.TEXTURE_2D, 1, WebGL2RenderingContext.RGBA32F, width, height);
		var id = next++;
		textures[id] = tex;
		dataTextures[id] = {width: width, height: height};
		return id;
	}

	public function updateDataTexture(handle:Int, data:Bytes):Void {
		var d = dataTextures[handle];
		if (d == null || data.length < d.width * d.height * 16)
			throw "Invalid data texture update";
		gl.bindTexture(WebGL2RenderingContext.TEXTURE_2D, textures[handle]);
		gl.pixelStorei(WebGL2RenderingContext.UNPACK_ALIGNMENT, 4);
		gl.texSubImage2D(WebGL2RenderingContext.TEXTURE_2D, 0, 0, 0, d.width, d.height, WebGL2RenderingContext.RGBA, WebGL2RenderingContext.FLOAT,
			new js.lib.Float32Array(data.getData(), 0, d.width * d.height * 4));
	}

	public function createCubeTexture(size:Int, levels:Array<Bytes>, format:TextureFormat):Int {
		if (size <= 0 || levels.length == 0 || !canSample(format))
			throw "Invalid cube texture";
		var tex = gl.createTexture();
		gl.bindTexture(WebGL2RenderingContext.TEXTURE_CUBE_MAP, tex);
		gl.pixelStorei(WebGL2RenderingContext.UNPACK_ALIGNMENT, 1);
		var s = size;
		for (i in 0...levels.length) {
			var face = format.levelBytes(s, s);
			if (levels[i].length != face * 6) {
				gl.deleteTexture(tex);
				throw "Invalid cube texture";
			}
			for (f in 0...6)
				upload(WebGL2RenderingContext.TEXTURE_CUBE_MAP_POSITIVE_X + f, i, format, s, s, levels[i], f * face);
			s = s > 1 ? Std.int(s / 2) : 1;
		}
		gl.texParameteri(WebGL2RenderingContext.TEXTURE_CUBE_MAP, WebGL2RenderingContext.TEXTURE_MAX_LEVEL, levels.length - 1);
		var id = next++;
		textures[id] = tex;
		cubes[id] = true;
		return id;
	}

	// Uploads level `level` of the bound texture at target (a 2D texture or a cube's face), width x height of format, from bytes at offset.
	function upload(target:Int, level:Int, format:TextureFormat, width:Int, height:Int, bytes:Bytes, offset:Int):Void {
		var length = format.levelBytes(width, height);
		switch format {
			case Rgba8:
				gl.texImage2D(target, level, WebGL2RenderingContext.RGBA, width, height, 0, WebGL2RenderingContext.RGBA, WebGL2RenderingContext.UNSIGNED_BYTE,
					new js.lib.Uint8Array(bytes.getData(), offset, length));
			case Rgba16f:
				gl.texImage2D(target, level, WebGL2RenderingContext.RGBA16F, width, height, 0, WebGL2RenderingContext.RGBA, WebGL2RenderingContext.HALF_FLOAT,
					new js.lib.Uint16Array(bytes.getData(), offset, Std.int(length / 2)));
			case _:
				gl.compressedTexImage2D(target, level, glFormat(format), width, height, 0, new js.lib.Uint8Array(bytes.getData(), offset, length));
		}
	}

	// The GL internal format of a compressed one, from its extension.
	static function glFormat(format:TextureFormat):Int
		return switch format {
			case Bc7: 0x8E8C; // COMPRESSED_RGBA_BPTC_UNORM_EXT
			case Astc4x4: 0x93B0; // COMPRESSED_RGBA_ASTC_4x4_KHR
			case Etc2Rgba8: 0x9278; // COMPRESSED_RGBA8_ETC2_EAC
			case Rgba8: WebGL2RenderingContext.RGBA8;
			case Rgba16f: WebGL2RenderingContext.RGBA16F;
		}

	public function canSample(format:TextureFormat):Bool {
		var known = formats[format];
		if (known == null) {
			// Asking for an extension also turns it on.
			known = switch format {
				// WebGL2 filters half floats without an extension.
				case Rgba8 | Rgba16f: true;
				case Bc7: gl.getExtension("EXT_texture_compression_bptc") != null;
				case Astc4x4: gl.getExtension("WEBGL_compressed_texture_astc") != null;
				case Etc2Rgba8: gl.getExtension("WEBGL_compressed_texture_etc") != null;
			}
			formats[format] = known;
		}
		return known;
	}

	// The sampler object for sampling: linear (through the mipmaps, when there are any) or nearest, and each axis's wrap.
	function sampler(sampling:Sampling):Dynamic {
		var index:Int = sampling;
		if (samplers[index] == null) {
			var wraps = [
				WebGL2RenderingContext.CLAMP_TO_EDGE,
				WebGL2RenderingContext.REPEAT,
				WebGL2RenderingContext.MIRRORED_REPEAT
			];
			var linear = sampling.filter == helix.texture.Filter.Linear,
				made = gl.createSampler();
			gl.samplerParameteri(made, WebGL2RenderingContext.TEXTURE_MIN_FILTER,
				linear ? WebGL2RenderingContext.LINEAR_MIPMAP_LINEAR : WebGL2RenderingContext.NEAREST_MIPMAP_NEAREST);
			gl.samplerParameteri(made, WebGL2RenderingContext.TEXTURE_MAG_FILTER, linear ? WebGL2RenderingContext.LINEAR : WebGL2RenderingContext.NEAREST);
			gl.samplerParameteri(made, WebGL2RenderingContext.TEXTURE_WRAP_S, wraps[(sampling.wrapU : Int) % 3]);
			gl.samplerParameteri(made, WebGL2RenderingContext.TEXTURE_WRAP_T, wraps[(sampling.wrapV : Int) % 3]);
			samplers[index] = made;
		}
		return samplers[index];
	}

	public function createBuffer(capacityBytes:Int):Int {
		if (capacityBytes <= 0 || capacityBytes % 4 != 0)
			throw "Invalid buffer capacity";
		var buffer = gl.createBuffer();
		gl.bindBuffer(WebGL2RenderingContext.ARRAY_BUFFER, buffer);
		gl.bufferData(WebGL2RenderingContext.ARRAY_BUFFER, capacityBytes, WebGL2RenderingContext.DYNAMIC_DRAW);
		var id = next++;
		buffers[id] = {
			buffer: buffer,
			capacity: capacityBytes,
			used: 0,
			index: false,
			isStatic: false
		};
		return id;
	}

	public function createStaticBuffer(data:Bytes, bytes:Int, index:Bool):Int {
		if (bytes <= 0 || bytes % 4 != 0 || bytes > data.length)
			throw "Invalid static buffer";
		var target = index ? WebGL2RenderingContext.ELEMENT_ARRAY_BUFFER : WebGL2RenderingContext.ARRAY_BUFFER;
		var buffer = gl.createBuffer();
		gl.bindBuffer(target, buffer);
		gl.bufferData(target, new js.lib.Uint8Array(data.getData(), 0, bytes), WebGL2RenderingContext.STATIC_DRAW);
		var id = next++;
		buffers[id] = {
			buffer: buffer,
			capacity: bytes,
			used: bytes,
			index: index,
			isStatic: true
		};
		return id;
	}

	public function updateBuffer(handle:Int, data:Bytes, usedBytes:Int):Void {
		var b = buffers[handle];
		if (!active
			|| b == null
			|| b.isStatic
			|| usedBytes < 0
			|| usedBytes % 4 != 0
			|| usedBytes > b.capacity
			|| usedBytes > data.length)
			throw "Invalid upload";
		gl.bindBuffer(WebGL2RenderingContext.ARRAY_BUFFER, b.buffer);
		gl.bufferSubData(WebGL2RenderingContext.ARRAY_BUFFER, 0, new js.lib.Uint8Array(data.getData(), 0, usedBytes));
		b.used = usedBytes;
	}

	function compile(type:Int, source:String):Dynamic {
		var s = gl.createShader(type);
		gl.shaderSource(s, source);
		gl.compileShader(s);
		if (!gl.getShaderParameter(s, WebGL2RenderingContext.COMPILE_STATUS)) {
			var log = gl.getShaderInfoLog(s);
			gl.deleteShader(s);
			throw log;
		}
		return s;
	}

	public function createShader(source:ShaderSource):Int {
		var v = compile(WebGL2RenderingContext.VERTEX_SHADER, source.glsl300es.vertex);
		var f = try compile(WebGL2RenderingContext.FRAGMENT_SHADER, source.glsl300es.fragment) catch (e:Dynamic) {
			gl.deleteShader(v);
			throw e;
		};
		var p = gl.createProgram();
		gl.attachShader(p, v);
		gl.attachShader(p, f);
		for (i in 0...source.attributes.length)
			gl.bindAttribLocation(p, i, source.attributes[i]);
		gl.linkProgram(p);
		gl.deleteShader(v);
		gl.deleteShader(f);
		if (!gl.getProgramParameter(p, WebGL2RenderingContext.LINK_STATUS)) {
			var log = gl.getProgramInfoLog(p);
			gl.deleteProgram(p);
			throw log;
		}
		var blocks:Array<Null<{location:Dynamic, size:Int}>> = [],
			samplerLocations:Array<Dynamic> = [];
		for (b in source.uniformBlocks)
			blocks[b.slot] = {location: gl.getUniformLocation(p, b.glslName), size: b.size};
		gl.useProgram(p);
		for (t in source.textures) {
			samplerLocations[t.slot] = gl.getUniformLocation(p, t.glslName);
			// Texture slot i samples unit i.
			gl.uniform1i(samplerLocations[t.slot], t.slot);
		}
		var id = next++;
		shaders[id] = {program: p, blocks: blocks, textures: samplerLocations};
		return id;
	}

	public function destroyShader(handle:Int):Void {
		var s = shaders[handle];
		if (s == null)
			throw "Invalid shader";
		for (id => desc in pipelines)
			if (desc.shader == handle)
				pipelines.remove(id);
		gl.deleteProgram(s.program);
		shaders.remove(handle);
	}

	public function createPipeline(desc:PipelineDesc):Int {
		if (!shaders.exists(desc.shader))
			throw "Invalid pipeline shader";
		for (b in desc.buffers)
			for (a in b.attributes)
				if (a.slot < 0
					|| a.componentCount < 1
					|| a.componentCount > 4
					|| a.offset < 0
					|| a.offset + a.componentCount * 4 > b.stride)
					throw "Invalid pipeline layout";
		var id = next++;
		pipelines[id] = desc;
		return id;
	}

	public function destroyPipeline(handle:Int):Void {
		if (!pipelines.exists(handle))
			throw "Invalid pipeline";
		pipelines.remove(handle);
	}

	public function canRender(format:TextureFormat):Bool {
		var known = renderable[format];
		if (known == null) {
			// Asking for the extension also turns it on: half floats then draw, blend and (WebGL2's own) filter.
			known = switch format {
				case Rgba8: true;
				case Rgba16f: gl.getExtension("EXT_color_buffer_float") != null;
				case _: false;
			}
			renderable[format] = known;
		}
		return known;
	}

	public function createRenderTarget(width:Int, height:Int, format:TextureFormat = Rgba8, depth:Bool = true):Int {
		if (width <= 0 || height <= 0 || !canRender(format))
			throw "Invalid render target";
		var half = format == Rgba16f,
			internal = half ? WebGL2RenderingContext.RGBA16F : WebGL2RenderingContext.RGBA8;
		var tex = gl.createTexture();
		gl.bindTexture(WebGL2RenderingContext.TEXTURE_2D, tex);
		gl.texImage2D(WebGL2RenderingContext.TEXTURE_2D, 0, internal, width, height, 0, WebGL2RenderingContext.RGBA,
			half ? WebGL2RenderingContext.HALF_FLOAT : WebGL2RenderingContext.UNSIGNED_BYTE, null);
		gl.texParameteri(WebGL2RenderingContext.TEXTURE_2D, WebGL2RenderingContext.TEXTURE_MAX_LEVEL, 0);
		// With depth, the screen's samples (at most what this GPU gives the format), so a target is drawn as smooth as the screen; without, one.
		var count = 1;
		if (depth) {
			var most:js.lib.Int32Array = gl.getInternalformatParameter(WebGL2RenderingContext.RENDERBUFFER, internal, WebGL2RenderingContext.SAMPLES);
			count = Std.int(Math.min(msaaSamples, most != null && most.length > 0 ? most[0] : 1));
		}
		var depthBuffer:Dynamic = null;
		if (depth) {
			depthBuffer = gl.createRenderbuffer();
			gl.bindRenderbuffer(WebGL2RenderingContext.RENDERBUFFER, depthBuffer);
			if (count > 1)
				gl.renderbufferStorageMultisample(WebGL2RenderingContext.RENDERBUFFER, count, WebGL2RenderingContext.DEPTH_COMPONENT24, width, height);
			else
				gl.renderbufferStorage(WebGL2RenderingContext.RENDERBUFFER, WebGL2RenderingContext.DEPTH_COMPONENT24, width, height);
		}
		var framebuffer = gl.createFramebuffer();
		gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, framebuffer);
		gl.framebufferTexture2D(WebGL2RenderingContext.FRAMEBUFFER, WebGL2RenderingContext.COLOR_ATTACHMENT0, WebGL2RenderingContext.TEXTURE_2D, tex, 0);
		if (depth && count <= 1)
			gl.framebufferRenderbuffer(WebGL2RenderingContext.FRAMEBUFFER, WebGL2RenderingContext.DEPTH_ATTACHMENT, WebGL2RenderingContext.RENDERBUFFER,
				depthBuffer);
		var complete = gl.checkFramebufferStatus(WebGL2RenderingContext.FRAMEBUFFER) == WebGL2RenderingContext.FRAMEBUFFER_COMPLETE;
		var drawn:Dynamic = null, color:Dynamic = null;
		if (count > 1) {
			color = gl.createRenderbuffer();
			gl.bindRenderbuffer(WebGL2RenderingContext.RENDERBUFFER, color);
			gl.renderbufferStorageMultisample(WebGL2RenderingContext.RENDERBUFFER, count, internal, width, height);
			drawn = gl.createFramebuffer();
			gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, drawn);
			gl.framebufferRenderbuffer(WebGL2RenderingContext.FRAMEBUFFER, WebGL2RenderingContext.COLOR_ATTACHMENT0, WebGL2RenderingContext.RENDERBUFFER,
				color);
			gl.framebufferRenderbuffer(WebGL2RenderingContext.FRAMEBUFFER, WebGL2RenderingContext.DEPTH_ATTACHMENT, WebGL2RenderingContext.RENDERBUFFER,
				depthBuffer);
			complete = complete
				&& gl.checkFramebufferStatus(WebGL2RenderingContext.FRAMEBUFFER) == WebGL2RenderingContext.FRAMEBUFFER_COMPLETE;
		}
		gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, null);
		if (!complete) {
			gl.deleteFramebuffer(framebuffer);
			if (depthBuffer != null)
				gl.deleteRenderbuffer(depthBuffer);
			if (drawn != null) {
				gl.deleteFramebuffer(drawn);
				gl.deleteRenderbuffer(color);
			}
			gl.deleteTexture(tex);
			throw "Render target incomplete";
		}
		var id = next++;
		textures[id] = tex;
		targets[id] = {
			framebuffer: framebuffer,
			depth: depthBuffer,
			half: half,
			drawn: drawn,
			color: color,
			width: width,
			height: height
		};
		return id;
	}

	public function createShadowMap(size:Int, layers:Int):Int {
		var largest:Int = gl.getParameter(WebGL2RenderingContext.MAX_TEXTURE_SIZE),
			most:Int = gl.getParameter(WebGL2RenderingContext.MAX_ARRAY_TEXTURE_LAYERS);
		if (size <= 0 || layers <= 0 || size > largest || layers > most)
			throw "Invalid shadow map";
		var tex = gl.createTexture();
		gl.bindTexture(WebGL2RenderingContext.TEXTURE_2D_ARRAY, tex);
		gl.texStorage3D(WebGL2RenderingContext.TEXTURE_2D_ARRAY, 1, WebGL2RenderingContext.DEPTH_COMPONENT24, size, size, layers);
		var framebuffers = [];
		for (layer in 0...layers) {
			var framebuffer = gl.createFramebuffer();
			gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, framebuffer);
			gl.framebufferTextureLayer(WebGL2RenderingContext.FRAMEBUFFER, WebGL2RenderingContext.DEPTH_ATTACHMENT, tex, 0, layer);
			// Depth only: nothing to draw colors into.
			gl.drawBuffers([WebGL2RenderingContext.NONE]);
			gl.readBuffer(WebGL2RenderingContext.NONE);
			framebuffers.push(framebuffer);
		}
		// Checked once here, never at a pass (a check at every pass stalls the browser).
		var complete = gl.checkFramebufferStatus(WebGL2RenderingContext.FRAMEBUFFER) == WebGL2RenderingContext.FRAMEBUFFER_COMPLETE;
		gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, null);
		if (!complete) {
			for (framebuffer in framebuffers)
				gl.deleteFramebuffer(framebuffer);
			gl.deleteTexture(tex);
			throw "Shadow map incomplete";
		}
		var id = next++;
		textures[id] = tex;
		shadowMaps[id] = {framebuffers: framebuffers, size: size};
		return id;
	}

	// The sampler for shadow maps: each read compares with the map's depth (less or equal), filtered linearly over its texels.
	function comparisonSampler():Dynamic {
		if (comparison == null) {
			comparison = gl.createSampler();
			gl.samplerParameteri(comparison, WebGL2RenderingContext.TEXTURE_MIN_FILTER, WebGL2RenderingContext.LINEAR);
			gl.samplerParameteri(comparison, WebGL2RenderingContext.TEXTURE_MAG_FILTER, WebGL2RenderingContext.LINEAR);
			gl.samplerParameteri(comparison, WebGL2RenderingContext.TEXTURE_WRAP_S, WebGL2RenderingContext.CLAMP_TO_EDGE);
			gl.samplerParameteri(comparison, WebGL2RenderingContext.TEXTURE_WRAP_T, WebGL2RenderingContext.CLAMP_TO_EDGE);
			gl.samplerParameteri(comparison, WebGL2RenderingContext.TEXTURE_COMPARE_MODE, WebGL2RenderingContext.COMPARE_REF_TO_TEXTURE);
			gl.samplerParameteri(comparison, WebGL2RenderingContext.TEXTURE_COMPARE_FUNC, WebGL2RenderingContext.LEQUAL);
		}
		return comparison;
	}

	public function beginShadowPass(map:Int, layer:Int):Void {
		var m = shadowMaps[map];
		if (active || m == null || layer < 0 || layer >= m.framebuffers.length)
			throw "Invalid shadow pass";
		gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, m.framebuffers[layer]);
		// Not flipped: a shadow map's rows run bottom first, as its lookups expect.
		inTarget = true;
		flipped = false;
		open(m.size, m.size, 0, 0, 0, 0);
	}

	public function beginTargetPass(target:Int, red:Float, green:Float, blue:Float, alpha:Float):Void {
		var t = targets[target];
		if (active || t == null)
			throw "Invalid target pass";
		gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, t.drawn != null ? t.drawn : t.framebuffer);
		drawing = t;
		inTarget = flipped = true;
		open(t.width, t.height, red, green, blue, alpha);
	}

	public function endTargetPass():Void {
		if (!inTarget)
			throw "No target pass";
		// Multisampled: its samples resolved into the texture (a blit, which the scissor would cut).
		var t = drawing;
		if (t != null && t.drawn != null) {
			gl.disable(WebGL2RenderingContext.SCISSOR_TEST);
			gl.bindFramebuffer(WebGL2RenderingContext.READ_FRAMEBUFFER, t.drawn);
			gl.bindFramebuffer(WebGL2RenderingContext.DRAW_FRAMEBUFFER, t.framebuffer);
			gl.blitFramebuffer(0, 0, t.width, t.height, 0, 0, t.width, t.height, WebGL2RenderingContext.COLOR_BUFFER_BIT, WebGL2RenderingContext.NEAREST);
		}
		drawing = null;
		gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, null);
		active = inTarget = flipped = false;
	}

	public function beginFrame(width:Int, height:Int, clearColor:Int):Void {
		if (active || width <= 0 || height <= 0)
			throw "Invalid pass";
		inTarget = flipped = frameEnded = false;
		frameWidth = width;
		frameHeight = height;
		open(width, height, Color.getRed(clearColor) / 255, Color.getGreen(clearColor) / 255, Color.getBlue(clearColor) / 255,
			Color.getAlpha(clearColor) / 255);
	}

	// Opens a pass on the bound framebuffer, width x height, cleared.
	function open(width:Int, height:Int, red:Float, green:Float, blue:Float, alpha:Float):Void {
		active = true;
		passHeight = height;
		gl.disable(WebGL2RenderingContext.SCISSOR_TEST);
		gl.disable(WebGL2RenderingContext.CULL_FACE);
		gl.depthMask(true);
		// A depth-only draw before may have masked the colors off: a clear writes them all.
		gl.colorMask(true, true, true, true);
		gl.clearColor(red, green, blue, alpha);
		gl.clearDepth(1);
		gl.clear(WebGL2RenderingContext.COLOR_BUFFER_BIT | WebGL2RenderingContext.DEPTH_BUFFER_BIT);
		gl.viewport(0, 0, width, height);
	}

	public function applyScissor(x:Int, y:Int, w:Int, h:Int):Void {
		if (!active || w < 0 || h < 0)
			throw "Invalid scissor";
		gl.enable(WebGL2RenderingContext.SCISSOR_TEST);
		// From the bottom left, as asked; a flipped pass's rows are upside down.
		gl.scissor(x, flipped ? passHeight - y - h : y, w, h);
	}

	public function resetScissor():Void {
		if (!active)
			throw "No pass";
		gl.disable(WebGL2RenderingContext.SCISSOR_TEST);
	}

	public function applyViewport(x:Int, y:Int, w:Int, h:Int):Void {
		if (!active || w <= 0 || h <= 0)
			throw "Invalid viewport";
		// From the bottom left, as asked; a flipped pass's rows are upside down.
		gl.viewport(x, flipped ? passHeight - y - h : y, w, h);
	}

	function blend(mode:BlendMode):Void
		if (mode == Opaque)
			gl.disable(WebGL2RenderingContext.BLEND);
		else {
			gl.enable(WebGL2RenderingContext.BLEND);
			// Added: the source times its alpha, plus what's there.
			var additive = mode == Additive;
			gl.blendFuncSeparate(WebGL2RenderingContext.SRC_ALPHA, additive ? WebGL2RenderingContext.ONE : WebGL2RenderingContext.ONE_MINUS_SRC_ALPHA,
				WebGL2RenderingContext.ONE, additive ? WebGL2RenderingContext.ONE : WebGL2RenderingContext.ONE_MINUS_SRC_ALPHA);
		}

	public function draw(pipeline:Int, buffers:Array<Int>, indices:Int, first:Int, count:Int, firstInstance:Int, instanceCount:Int, textures:Array<Int>,
			samplings:Array<Sampling>, uniforms:Array<Null<Bytes>>):Void {
		var p = pipelines[pipeline];
		if (!active || p == null)
			throw "Invalid draw";
		var shader = shaders[p.shader],
			group = p.primitive == Lines ? 2 : 3,
			ix = p.indexed ? this.buffers[indices] : null;
		if (first < 0
			|| count <= 0
			|| count % group != 0
			|| firstInstance < 0
			|| instanceCount <= 0
			|| p.indexed
			&& (ix == null || !ix.index || (first + count) * 4 > ix.used))
			throw "Invalid draw";
		// Each buffer's records must cover the draw: an instanced one's the instances, a vertex one's the vertices (indexed: GL checks them).
		for (i in 0...p.buffers.length) {
			var layout = p.buffers[i];
			if (layout.attributes.length == 0)
				continue;
			var b = i < buffers.length ? this.buffers[buffers[i]] : null;
			if (b == null
				|| b.index
				|| layout.instanced
				&& (firstInstance + instanceCount) * layout.stride > b.used
					|| !layout.instanced
					&& !p.indexed
					&& (first + count) * layout.stride > b.used)
				throw "Invalid draw";
		}
		gl.useProgram(shader.program);
		bindTextures(shader, textures, samplings);
		bindBlocks(shader, uniforms, p.flip);
		var used = [];
		for (i in 0...p.buffers.length) {
			var layout = p.buffers[i];
			if (layout.attributes.length == 0)
				continue;
			gl.bindBuffer(WebGL2RenderingContext.ARRAY_BUFFER, this.buffers[buffers[i]].buffer);
			// No base instance in WebGL2: an instanced buffer's attributes start at the draw's first record instead.
			var base = layout.instanced ? firstInstance * layout.stride : 0;
			for (a in layout.attributes) {
				gl.enableVertexAttribArray(a.slot);
				gl.vertexAttribPointer(a.slot, a.componentCount, WebGL2RenderingContext.FLOAT, false, layout.stride, base + a.offset);
				gl.vertexAttribDivisor(a.slot, layout.instanced ? 1 : 0);
				used[a.slot] = true;
			}
		}
		for (slot in 0...enabled.length)
			if (enabled[slot] && used[slot] != true) {
				gl.disableVertexAttribArray(slot);
				gl.vertexAttribDivisor(slot, 0);
			}
		enabled = used;
		if (p.depthTest != DepthTest.Off) {
			gl.enable(WebGL2RenderingContext.DEPTH_TEST);
			gl.depthFunc(p.depthTest == DepthTest.Greater ? WebGL2RenderingContext.GREATER : WebGL2RenderingContext.LEQUAL);
		} else
			gl.disable(WebGL2RenderingContext.DEPTH_TEST);
		gl.depthMask(p.depthWrite);
		if (p.cull != CullFace.None) {
			gl.enable(WebGL2RenderingContext.CULL_FACE);
			gl.cullFace(p.cull == CullFace.Front ? WebGL2RenderingContext.FRONT : WebGL2RenderingContext.BACK);
		} else
			gl.disable(WebGL2RenderingContext.CULL_FACE);
		// The front faces as described; flipped, they wind the other way (gl_FrontFacing too).
		gl.frontFace(flipped != p.clockwise ? WebGL2RenderingContext.CW : WebGL2RenderingContext.CCW);
		gl.colorMask(!p.depthOnly, !p.depthOnly, !p.depthOnly, !p.depthOnly);
		blend(p.blend);
		var mode = p.primitive == Lines ? WebGL2RenderingContext.LINES : WebGL2RenderingContext.TRIANGLES;
		if (p.indexed) {
			gl.bindBuffer(WebGL2RenderingContext.ELEMENT_ARRAY_BUFFER, ix.buffer);
			gl.drawElementsInstanced(mode, count, WebGL2RenderingContext.UNSIGNED_INT, first * 4, instanceCount);
		} else
			gl.drawArraysInstanced(mode, first, count, instanceCount);
	}

	// Binds textures by the program's slots, each sampled by its kind: a shadow map through the comparison sampler, a data texture nearest,
	// any other as its sampling says.
	function bindTextures(shader:{program:Dynamic, blocks:Array<Null<{location:Dynamic, size:Int}>>, textures:Array<Dynamic>}, textures:Array<Int>,
			samplings:Array<Sampling>):Void
		for (slot in 0...shader.textures.length) {
			if (shader.textures[slot] == null)
				continue;
			var handle = slot < textures.length ? textures[slot] : 0,
				t = this.textures[handle];
			if (t == null)
				throw "Invalid draw texture";
			gl.activeTexture(WebGL2RenderingContext.TEXTURE0 + slot);
			if (shadowMaps.exists(handle)) {
				gl.bindTexture(WebGL2RenderingContext.TEXTURE_2D_ARRAY, t);
				gl.bindSampler(slot, comparisonSampler());
			} else if (cubes.exists(handle)) {
				gl.bindTexture(WebGL2RenderingContext.TEXTURE_CUBE_MAP, t);
				gl.bindSampler(slot, sampler(slot < samplings.length ? samplings[slot] : Sampling.LINEAR));
			} else {
				gl.bindTexture(WebGL2RenderingContext.TEXTURE_2D, t);
				gl.bindSampler(slot, sampler(dataTextures.exists(handle)
					|| slot >= samplings.length ? Sampling.NEAREST : samplings[slot]));
			}
		}

	// Sets the program's uniform blocks from uniforms by slot, each its declared size; block 0 turned over in a flipped pass as flip says.
	function bindBlocks(shader:{program:Dynamic, blocks:Array<Null<{location:Dynamic, size:Int}>>, textures:Array<Dynamic>}, uniforms:Array<Null<Bytes>>,
			flip:ClipFlip):Void
		for (slot in 0...shader.blocks.length) {
			var block = shader.blocks[slot];
			if (block == null)
				continue;
			var data = slot < uniforms.length ? uniforms[slot] : null;
			if (data == null || data.length < block.size)
				throw "Invalid draw uniforms";
			var floats = new js.lib.Float32Array(data.getData(), 0, Std.int(block.size / 4));
			if (slot == 0 && flip == ClipScale) {
				floats = flippedBlock.subarray(0, Std.int(block.size / 4));
				floats.fill(0);
				floats[0] = 1;
				floats[1] = flipped ? -1 : 1;
			} else if (slot == 0 && flip == ViewProjection && flipped) {
				var copy = flippedBlock.length >= floats.length ? flippedBlock.subarray(0, floats.length) : new js.lib.Float32Array(floats.length);
				copy.set(floats);
				for (i in [1, 5, 9, 13])
					copy[i] = -copy[i];
				floats = copy;
			}
			if (block.location != null)
				gl.uniform4fv(block.location, floats);
		}

	public function endFrame():Void {
		if (!active || inTarget)
			throw "No screen pass";
		active = false;
		frameEnded = true;
	}

	public function readPixels(target:Int, done:ReadPixelsResult->Void):Void {
		if (active)
			throw "Inside a pass";
		var t = targets[target];
		// Half floats read back only as floats in WebGL2: not this call's RGBA8.
		if (target != 0 && (t == null || t.half))
			throw "Invalid render target";
		if (target == 0 && !frameEnded) {
			done(Failed("No frame has ended"));
			return;
		}
		var width = target == 0 ? frameWidth : t.width,
			height = target == 0 ? frameHeight : t.height;
		gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, target == 0 ? null : t.framebuffer);
		var pixels = new js.lib.Uint8Array(width * height * 4);
		gl.readPixels(0, 0, width, height, WebGL2RenderingContext.RGBA, WebGL2RenderingContext.UNSIGNED_BYTE, pixels);
		gl.bindFramebuffer(WebGL2RenderingContext.FRAMEBUFFER, null);
		var read = Bytes.ofData(pixels.buffer);
		if (target != 0) {
			done(Read(width, height, read));
			return;
		}
		// The screen's rows come bottom first (GL's origin); a target's are already top first, drawn flipped.
		var rgba = Bytes.alloc(read.length), row = width * 4;
		for (y in 0...height)
			rgba.blit(y * row, read, (height - 1 - y) * row, row);
		done(Read(width, height, rgba));
	}

	public function destroyBuffer(handle:Int):Void {
		var b = buffers[handle];
		if (b == null)
			throw "Invalid buffer";
		gl.deleteBuffer(b.buffer);
		buffers.remove(handle);
	}

	public function destroyTexture(handle:Int):Void {
		var t = textures[handle];
		if (t == null)
			throw "Invalid texture";
		gl.deleteTexture(t);
		textures.remove(handle);
		cubes.remove(handle);
		dataTextures.remove(handle);
		var map = shadowMaps[handle];
		if (map != null) {
			for (framebuffer in map.framebuffers)
				gl.deleteFramebuffer(framebuffer);
			shadowMaps.remove(handle);
		}
		var target = targets[handle];
		if (target != null) {
			gl.deleteFramebuffer(target.framebuffer);
			if (target.depth != null)
				gl.deleteRenderbuffer(target.depth);
			if (target.drawn != null) {
				gl.deleteFramebuffer(target.drawn);
				gl.deleteRenderbuffer(target.color);
			}
			targets.remove(handle);
		}
	}

	public function shutdown():Void {
		for (s in shaders)
			gl.deleteProgram(s.program);
		shaders.clear();
		pipelines.clear();
		for (made in samplers)
			if (made != null)
				gl.deleteSampler(made);
		samplers = [];
		if (comparison != null)
			gl.deleteSampler(comparison);
		comparison = null;
	}
}
