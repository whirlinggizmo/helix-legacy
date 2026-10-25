package helix.render2d;

import helix.graphics.Color;
import helix.graphics.IGraphics;
import helix.graphics.BlendMode;
import helix.graphics.Pipelines;
import helix.texture.Sampling;
import helix.graphics.SpriteEffect;
import helix.graphics.AlphaMode;
import haxe.io.Bytes;
import helix.font.Font;
import helix.texture.Texture2D;

/** Immediate 2D drawing in world units through a Camera2D, inside a frame (IGraphics.beginFrame to endFrame). A batch is one upload and one draw per
	run of a texture, camera and effect, drawn over whatever the frame has so far, without depth. Colors are 0xAARRGGBB. A transform (setTransform)
	places what follows, so a shape or text can be drawn turned and scaled; a Renderer2D draws its nodes so. What is drawn with an effect (effect: a
	sprite shader) goes through it in place of the framework's sprite program, its vertices in an upload of their own. */
@:noCompletion
@:allow(helix)
class Batch2D {
	var vertices = 0;
	var draws = 0;

	/** Vertices of the frame drawn last, those drawn through effects among them. */
	var vertexCount(get, never):Int;

	function get_vertexCount():Int
		return vertices + effectVertices;

	/** Draws of the frame drawn last: one per run of a texture, camera and effect. */
	var drawCallCount(get, never):Int;

	function get_drawCallCount():Int
		return draws;

	/** The built-in pixel font, whose texture also has the white texel shapes use. */
	var font(default, null):Font;

	var gpu:IGraphics;
	// The vertices data holds, and the GPU buffer's (which the next upload makes as big when it's less).
	var capacity:Int;
	var bufferCapacity:Int;
	var data:Bytes;
	var buffer:Int;
	var pipelines:Pipelines;
	// Block 0 of the sprite program, its clip scale, which the adapter writes.
	var clip = Bytes.alloc(16);
	var texture:Texture2D;
	var runStart = 0;
	var runs:Array<Int> = [];
	var runCameras:Array<Camera2D> = [];
	var runSamplings:Array<Sampling> = [];
	// By run: its clip in framebuffer pixels from the top-left (x, y, w, h), w -1 for none.
	var runClips:Array<Int> = [];
	// The clips pushed, each within the one before (x, y, w, h each); the current one last.
	var clips:Array<Int> = [];
	// By run: the emitter it draws (its index in the batch's particles), or -1 for a run of quads.
	var runParticles:Array<Int> = [];
	// By run: the effect it draws through (its vertices in the effects' upload), or null; and its texture.
	var runEffects:Array<Null<SpriteEffect>> = [];
	var runTextures:Array<Texture2D> = [];
	// The vertices drawn through effects, with their sprites' regions (Effect2DProgram), uploaded beside the others; made when first used.
	var effectVertices = 0;
	var effectCapacity = 0;
	var effectData:Bytes = Bytes.alloc(0);
	var effectBuffer = 0;
	var effectBufferCapacity = 0;
	// The region the vertices that follow are of (texture coordinates: u0, v0, u1, v1), and whether a nine-slice holds it for its quads.
	var ru0 = 0.;
	var rv0 = 0.;
	var ru1 = 0.;
	var rv1 = 0.;
	var regionHeld = false;
	// What draws particles, made by the first emitter drawn (an optional part: a batch that draws none carries none of it).
	var particles:Null<BatchParticles>;
	// A rounded rectangle's outlines, outside and in, reused.
	var outer:Array<Float> = [];
	var inner:Array<Float> = [];
	var sampling:Sampling = Sampling.NEAREST;
	var ta = 1.;
	var tb = 0.;
	var tc = 0.;
	var td = 1.;
	var tx = 0.;
	var ty = 0.;
	var r = 1.;
	var g = 1.;
	var b = 1.;
	var a = 1.;

	/** A batch with room for vertices vertices a frame to start, growing (twice as many) when a frame needs more, with its own buffer,
		pipeline and pixel font on gpu; cleanup frees them. Without gpu, the program's (Graphics.instance). */
	function new(?gpu:IGraphics, vertices = 32768) {
		if (gpu == null)
			gpu = helix.graphics.Graphics.instance;
		this.gpu = gpu;
		capacity = bufferCapacity = vertices > 6 ? vertices : 6;
		data = Bytes.alloc(capacity * Sprite2DProgram.stride);
		buffer = gpu.createBuffer(capacity * Sprite2DProgram.stride);
		pipelines = Pipelines.of(gpu);
		font = Font.builtIn(gpu);
		texture = font.texture;
	}

	/** Starts collecting a batch seen through camera (an unsized one taking the framebuffer: Camera2D), with no transform; later calls
		only fill it until end. */
	function begin(camera:Camera2D):Void {
		camera.fitFramebuffer();
		@:bypassAccessor this.camera = camera;
		@:bypassAccessor effect = null;
		alpha = 1;
		vertices = 0;
		effectVertices = 0;
		draws = 0;
		runStart = 0;
		runs = [];
		runCameras = [];
		runSamplings = [];
		runParticles = [];
		runEffects = [];
		runTextures = [];
		runClips = [];
		clips = [];
		if (particles != null)
			particles.startFrame();
		texture = font.texture;
		sampling = texture.sampling;
		samplingOverride = null;
		resetTransform();
	}

	/** The camera what follows is seen through, in its viewport (an unsized one taking the framebuffer: Camera2D): a world and a HUD in one
		batch. */
	var camera(default, set):Camera2D;

	/** What every color drawn from now on has its alpha multiplied by, 0 to 1: a Node2D's alpha as a stage draws it (a whole group faded).
		1 at begin. Particles aren't faded by it. */
	var alpha:Float = 1.;

	function set_camera(value:Camera2D):Camera2D {
		if (value != camera) {
			closeRun();
			value.fitFramebuffer();
			camera = value;
		}
		return value;
	}

	/** The effect what follows is drawn through (a sprite shader: helix.shader' SpriteOutline and the others, or an app's), or null (the
		default, and again at begin) for the framework's sprite program. Sprites, text and shapes alike: each is drawn through it with its
		region (a quad's texture coordinates; a nine-slice's whole region; a shape's white texel). One effect drawn from one sprite to the next
		stays one draw, as one texture does; its parameters are read as end draws. */
	var effect(default, set):Null<SpriteEffect>;

	function set_effect(value:Null<SpriteEffect>):Null<SpriteEffect> {
		if (value != effect) {
			closeRun();
			effect = value;
			runStart = value == null ? vertices : effectVertices;
		}
		return value;
	}

	/** The clock its effects see, seconds (helix_time() in a sprite shader, a SpriteFlash's fade): read as end draws. A Renderer2D's draw sets it
		to the stage's time. */
	var time:Float = 0.;

	/** The transform's a: x's share of a point's x. */
	var transformA(get, never):Float;

	function get_transformA():Float
		return ta;

	/** The transform's b: x's share of a point's y. */
	var transformB(get, never):Float;

	function get_transformB():Float
		return tb;

	/** The transform's c: y's share of a point's x. */
	var transformC(get, never):Float;

	function get_transformC():Float
		return tc;

	/** The transform's d: y's share of a point's y. */
	var transformD(get, never):Float;

	function get_transformD():Float
		return td;

	/** The transform's x offset, world units. */
	var transformX(get, never):Float;

	function get_transformX():Float
		return tx;

	/** The transform's y offset, world units. */
	var transformY(get, never):Float;

	function get_transformY():Float
		return ty;

	/** Places what follows: a point x, y it is given is drawn at a * x + c * y + tx, b * x + d * y + ty in world units. */
	function setTransform(a:Float, b:Float, c:Float, d:Float, tx:Float, ty:Float):Void {
		ta = a;
		tb = b;
		tc = c;
		td = d;
		this.tx = tx;
		this.ty = ty;
	}

	/** What follows is drawn where it is given, in world units. */
	function resetTransform():Void
		setTransform(1, 0, 0, 1, 0, 0);

	/** Draws the batch in the open frame: one upload of every vertex (and one of those drawn through effects) and one draw per run of a
		texture, camera and effect, each in its camera's viewport. Once a frame. */
	function end():Void {
		closeRun();
		// The GPU buffer as big as what grew this frame.
		if (bufferCapacity < capacity) {
			gpu.destroyBuffer(buffer);
			buffer = gpu.createBuffer(capacity * Sprite2DProgram.stride);
			bufferCapacity = capacity;
		}
		gpu.updateBuffer(buffer, data, vertices * Sprite2DProgram.stride);
		if (effectVertices > 0) {
			if (effectBufferCapacity < effectCapacity) {
				if (effectBuffer != 0)
					gpu.destroyBuffer(effectBuffer);
				effectBuffer = gpu.createBuffer(effectCapacity * Effect2DProgram.stride);
				effectBufferCapacity = effectCapacity;
			}
			gpu.updateBuffer(effectBuffer, effectData, effectVertices * Effect2DProgram.stride);
		}
		if (particles != null)
			particles.upload();
		var i = 0, viewport:Camera2D = null, clipped = false, cx = 0, cy = 0, cw = 0, ch = 0;
		while (i < runs.length) {
			var run = Std.int(i / 3), c = runCameras[run];
			if (c != viewport) {
				viewport = c;
				gpu.applyViewport(c.viewportX, c.framebufferHeight - c.viewportY - c.viewportHeight, c.viewportWidth, c.viewportHeight);
			}
			// The run's clip, set when it changes (from the top-left here, the bottom-left for the GPU).
			var at = run * 4, w = runClips[at + 2];
			if (w < 0 && clipped) {
				gpu.resetScissor();
				clipped = false;
			} else if (w >= 0 && (!clipped || runClips[at] != cx || runClips[at + 1] != cy || w != cw || runClips[at + 3] != ch)) {
				cx = runClips[at];
				cy = runClips[at + 1];
				cw = w;
				ch = runClips[at + 3];
				gpu.applyScissor(cx, c.framebufferHeight - cy - ch, cw, ch);
				clipped = true;
			}
			var emitted = runParticles[run], through = runEffects[run];
			if (through != null)
				drawEffect(through, runTextures[run], runSamplings[run], runs[i + 1], runs[i + 2]);
			else if (emitted >= 0)
				particles.draw(emitted, runs[i], runSamplings[run]);
			else
				gpu.draw(pipelines.sprite2D(Alpha), [buffer], 0, runs[i + 1], runs[i + 2], 0, 1, [runs[i]], [runSamplings[run]], [clip]);
			draws++;
			i += 3;
		}
		if (clipped)
			gpu.resetScissor();
	}

	// Draws count vertices from first of the effects' upload through effect, of texture sampled by sampling, at the batch's time.
	function drawEffect(effect:SpriteEffect, texture:Texture2D, sampling:Sampling, first:Int, count:Int):Void {
		var textures = [], samplings = [];
		var blocks = effect.bind(effect.shader, texture, sampling, time, clip, textures, samplings);
		gpu.draw(pipelines.spriteEffect(effect.shader.handle, Alpha), [effectBuffer], 0, first, count, 0, 1, textures, samplings, blocks);
	}

	/** Clips what follows to the rectangle x, y, w, h of the world units it would be drawn in now (through the transform and the camera; a
		turned one's bounds), within any clip already pushed, until popClip. */
	function pushClip(x:Float, y:Float, w:Float, h:Float):Void {
		closeRun();
		var lx = Math.POSITIVE_INFINITY,
			ly = Math.POSITIVE_INFINITY,
			hx = Math.NEGATIVE_INFINITY,
			hy = Math.NEGATIVE_INFINITY;
		for (k in 0...4) {
			var px = k & 1 == 0 ? x : x + w, py = k & 2 == 0 ? y : y + h;
			var sx = camera.worldToScreenX(ta * px + tc * py + tx),
				sy = camera.worldToScreenY(tb * px + td * py + ty);
			lx = Math.min(lx, sx);
			ly = Math.min(ly, sy);
			hx = Math.max(hx, sx);
			hy = Math.max(hy, sy);
		}
		var left = Math.round(lx),
			top = Math.round(ly),
			right = Math.round(hx),
			bottom = Math.round(hy);
		var n = clips.length;
		if (n > 0) {
			left = Std.int(Math.max(left, clips[n - 4]));
			top = Std.int(Math.max(top, clips[n - 3]));
			right = Std.int(Math.min(right, clips[n - 4] + clips[n - 2]));
			bottom = Std.int(Math.min(bottom, clips[n - 3] + clips[n - 1]));
		}
		clips.push(left);
		clips.push(top);
		clips.push(Std.int(Math.max(0, right - left)));
		clips.push(Std.int(Math.max(0, bottom - top)));
	}

	/** Ends the clip pushClip began; what follows is clipped as before it. Nothing with no clip pushed. */
	function popClip():Void {
		if (clips.length == 0)
			return;
		closeRun();
		clips.resize(clips.length - 4);
	}

	function pushRunClip():Void {
		var n = clips.length;
		for (k in 0...4)
			runClips.push(n == 0 ? (k == 2 ? -1 : 0) : clips[n - 4 + k]);
	}

	/** Later quads sample this texture, as its sampling is now (Texture2D.sampling). */
	function useTexture(value:Texture2D):Void {
		var wanted = samplingOverride != null ? samplingOverride : value.sampling;
		if (value != texture || wanted != sampling) {
			closeRun();
			texture = value;
			sampling = wanted;
		}
	}

	/** How what follows is sampled in place of each texture's own sampling, or null for the texture's: one texture drawn smooth and sharp in
		one frame (a Sprite2D's sampling, Drawing2D.image's). */
	var samplingOverride:Null<Sampling>;

	function closeRun():Void {
		var end = effect == null ? vertices : effectVertices;
		if (end > runStart) {
			runs.push(texture.handle);
			runs.push(runStart);
			runs.push(end - runStart);
			runCameras.push(camera);
			runSamplings.push(sampling);
			runParticles.push(-1);
			runEffects.push(effect);
			runTextures.push(texture);
			pushRunClip();
		}
		runStart = end;
	}

	inline function color(value:Int):Void {
		r = Color.getRed(value) / 255;
		g = Color.getGreen(value) / 255;
		b = Color.getBlue(value) / 255;
		a = Color.getAlpha(value) / 255 * alpha;
	}

	inline function vertex(x:Float, y:Float, u:Float, v:Float):Void {
		if (effect != null) {
			effectVertex(x, y, u, v);
			return;
		}
		if (vertices >= capacity) {
			// Room for twice as many: the GPU buffer follows at the upload (end).
			capacity *= 2;
			var grown = Bytes.alloc(capacity * Sprite2DProgram.stride);
			grown.blit(0, data, 0, vertices * Sprite2DProgram.stride);
			data = grown;
		}
		var p = vertices++ * Sprite2DProgram.stride,
			position = p + Sprite2DProgram.positionOffset,
			uv = p + Sprite2DProgram.uvOffset,
			c = p + Sprite2DProgram.colorOffset;
		data.setFloat(position, camera.clipX(ta * x + tc * y + tx));
		data.setFloat(position + 4, camera.clipY(tb * x + td * y + ty));
		data.setFloat(uv, u);
		data.setFloat(uv + 4, v);
		data.setFloat(c, r);
		data.setFloat(c + 4, g);
		data.setFloat(c + 8, b);
		data.setFloat(c + 12, a);
	}

	// A vertex drawn through the effect: as vertex writes one, and the region it is of.
	function effectVertex(x:Float, y:Float, u:Float, v:Float):Void {
		if (effectVertices >= effectCapacity) {
			effectCapacity = effectCapacity == 0 ? 1536 : effectCapacity * 2;
			var grown = Bytes.alloc(effectCapacity * Effect2DProgram.stride);
			grown.blit(0, effectData, 0, effectVertices * Effect2DProgram.stride);
			effectData = grown;
		}
		var p = effectVertices++ * Effect2DProgram.stride,
			position = p + Effect2DProgram.positionOffset,
			uv = p + Effect2DProgram.uvOffset,
			c = p + Effect2DProgram.colorOffset,
			region = p + Effect2DProgram.regionOffset;
		effectData.setFloat(position, camera.clipX(ta * x + tc * y + tx));
		effectData.setFloat(position + 4, camera.clipY(tb * x + td * y + ty));
		effectData.setFloat(uv, u);
		effectData.setFloat(uv + 4, v);
		effectData.setFloat(c, r);
		effectData.setFloat(c + 4, g);
		effectData.setFloat(c + 8, b);
		effectData.setFloat(c + 12, a);
		effectData.setFloat(region, ru0);
		effectData.setFloat(region + 4, rv0);
		effectData.setFloat(region + 8, ru1);
		effectData.setFloat(region + 12, rv1);
	}

	// The region the vertices that follow are of, unless a nine-slice holds its own.
	inline function region(u0:Float, v0:Float, u1:Float, v1:Float):Void
		if (!regionHeld) {
			ru0 = u0;
			rv0 = v0;
			ru1 = u1;
			rv1 = v1;
		}

	/** Untextured shapes need a white texel; switch back to the font's texture when the current one has none. */
	inline function solid():Void
		if (texture.whiteU < 0)
			useTexture(font.texture);

	/** A textured rectangle in world units, top-left at x, y, sampling u0, v0 to u1, v1 of the current texture, tinted. With distanceField, the texture's alpha is
		a distance from an outline (Font.distanceField), drawn with a smooth edge at any scale. */
	function quad(x:Float, y:Float, w:Float, h:Float, u0:Float, v0:Float, u1:Float, v1:Float, tint:Int, distanceField = false):Void {
		color(tint);
		region(u0, v0, u1, v1);
		// The 2D shader reads an alpha over 1 as "the texture's alpha is a distance field", tinted by the alpha less 2.
		if (distanceField)
			a += 2;
		vertex(x, y, u0, v0);
		vertex(x + w, y, u1, v0);
		vertex(x + w, y + h, u1, v1);
		vertex(x, y, u0, v0);
		vertex(x + w, y + h, u1, v1);
		vertex(x, y + h, u0, v1);
	}

	/** texture drawn centered on x, y, width x height in world units, turned rotation radians (clockwise on screen), sampling u0, v0 to u1, v1 of it
		(the whole texture by default), tinted (0xAARRGGBB, white by default). */
	function sprite(texture:Texture2D, x:Float, y:Float, width:Float, height:Float, rotation = 0., tint = 0xffffffff, u0 = 0., v0 = 0., u1 = 1., v1 = 1.):Void {
		useTexture(texture);
		color(tint);
		region(u0, v0, u1, v1);
		var c = Math.cos(rotation),
			s = Math.sin(rotation),
			hw = width / 2,
			hh = height / 2;
		// The corners from the center, turned: top-left, top-right, bottom-right, bottom-left.
		var ax = x + -hw * c - -hh * s, ay = y + -hw * s + -hh * c;
		var bx = x + hw * c - -hh * s, by = y + hw * s + -hh * c;
		var cx = x + hw * c - hh * s, cy = y + hw * s + hh * c;
		var dx = x + -hw * c - hh * s, dy = y + -hw * s + hh * c;
		vertex(ax, ay, u0, v0);
		vertex(bx, by, u1, v0);
		vertex(cx, cy, u1, v1);
		vertex(ax, ay, u0, v0);
		vertex(cx, cy, u1, v1);
		vertex(dx, dy, u0, v1);
	}

	/** sheet's frame at index (SpriteSheet2D.getFrame) drawn with its pivot at x, y (its file's, else its center), at its size in texels times
		scaleX, scaleY (below 0 mirrors it: -1, 1 faces it the other way), turned rotation radians (clockwise on screen), tinted (0xAARRGGBB, white
		by default). A trimmed frame is drawn where it was in its whole picture, a rotated one upright. An index the sheet hasn't draws nothing. */
	function sheetFrame(sheet:SpriteSheet2D, index:Int, x:Float, y:Float, scaleX = 1., scaleY = 1., rotation = 0., tint = 0xffffffff):Void {
		var frame = sheet.getFrame(index);
		if (frame == null)
			return;
		// The transform as it was, then the frame's own (moved, turned and scaled) after it.
		var a0 = ta, b0 = tb, c0 = tc, d0 = td, x0 = tx, y0 = ty;
		var cos = Math.cos(rotation), sin = Math.sin(rotation);
		var la = cos * scaleX,
			lb = sin * scaleX,
			lc = -sin * scaleY,
			ld = cos * scaleY;
		setTransform(a0 * la + c0 * lb, b0 * la + d0 * lb, a0 * lc + c0 * ld, b0 * lc + d0 * ld, a0 * x + c0 * y + x0, b0 * x + d0 * y + y0);
		var px = frame.hasPivot ? frame.pivotX : .5,
			py = frame.hasPivot ? frame.pivotY : .5;
		frameQuad(sheet.texture, frame, -px * frame.sourceWidth, -py * frame.sourceHeight, frame.sourceWidth, frame.sourceHeight, tint);
		setTransform(a0, b0, c0, d0, x0, y0);
	}

	// frame of texture filling the box x, y, width x height (its whole picture's, untrimmed): its texels where trimming left them, upright.

	@:allow(helix.render2d.Renderer2D)
	function frameQuad(texture:Texture2D, frame:SpriteFrame2D, x:Float, y:Float, width:Float, height:Float, tint:Int):Void {
		useTexture(texture);
		var sx = width / frame.sourceWidth, sy = height / frame.sourceHeight;
		var qx = x + frame.offsetX * sx,
			qy = y + frame.offsetY * sy,
			qw = frame.width * sx,
			qh = frame.height * sy;
		var tw = texture.width, th = texture.height;
		if (!frame.rotated) {
			quad(qx, qy, qw, qh, frame.x / tw, frame.y / th, (frame.x + frame.width) / tw, (frame.y + frame.height) / th, tint);
			return;
		}
		// Packed a quarter turn clockwise: in the texture it is height x width, its top-left at the texture rectangle's top-right.
		var u0 = frame.x / tw,
			v0 = frame.y / th,
			u1 = (frame.x + frame.height) / tw,
			v1 = (frame.y + frame.width) / th;
		color(tint);
		region(u0, v0, u1, v1);
		vertex(qx, qy, u1, v0);
		vertex(qx + qw, qy, u1, v1);
		vertex(qx + qw, qy + qh, u0, v1);
		vertex(qx, qy, u1, v0);
		vertex(qx + qw, qy + qh, u0, v1);
		vertex(qx, qy + qh, u0, v0);
	}

	/** texture drawn top-left at x, y, width x height in world units, tinted (white by default): the region sourceX, sourceY, sourceWidth x
		sourceHeight of it in texels, or the whole texture when sourceWidth or sourceHeight is 0 or less. Sampled as the texture's sampling is
		now. */
	function image(texture:Texture2D, x:Float, y:Float, width:Float, height:Float, tint = 0xffffffff, sourceX = 0., sourceY = 0., sourceWidth = 0.,
			sourceHeight = 0.):Void {
		useTexture(texture);
		var tw = texture.width, th = texture.height;
		if (!(sourceWidth > 0 && sourceHeight > 0)) {
			sourceX = sourceY = 0;
			sourceWidth = tw;
			sourceHeight = th;
		}
		quad(x, y, width, height, sourceX / tw, sourceY / th, (sourceX + sourceWidth) / tw, (sourceY + sourceHeight) / th, tint);
	}

	/** Draws texture's region sourceX, sourceY, sourceWidth x sourceHeight (texels; the whole texture when not given) as a frame filling x, y,
		width x height in world units: its corners left, top, right and bottom texels in from its edges keep their size (a texel a unit; shrunk
		alike when the frame is smaller than they are), its edges stretch along them and its middle both ways. A panel or button of any size from
		one image. */
	function nineSlice(texture:Texture2D, x:Float, y:Float, width:Float, height:Float, left:Float, top:Float, right:Float, bottom:Float, tint = 0xffffffff,
			sourceX = 0., sourceY = 0., sourceWidth = 0., sourceHeight = 0.):Void {
		useTexture(texture);
		var tw = texture.width, th = texture.height;
		if (!(sourceWidth > 0 && sourceHeight > 0)) {
			sourceX = sourceY = 0;
			sourceWidth = tw;
			sourceHeight = th;
		}
		// Corners shrink together when the frame is narrower or shorter than they are.
		var fitX = left + right > width && left + right > 0 ? width / (left + right) : 1.,
			fitY = top + bottom > height && top + bottom > 0 ? height / (top + bottom) : 1.;
		var xs = [x, x + left * fitX, x + width - right * fitX, x + width],
			ys = [y, y + top * fitY, y + height - bottom * fitY, y + height];
		var us = [sourceX, sourceX + left, sourceX + sourceWidth - right, sourceX + sourceWidth],
			vs = [sourceY, sourceY + top, sourceY + sourceHeight - bottom, sourceY + sourceHeight];
		// Each slice of the one region, for an effect.
		region(sourceX / tw, sourceY / th, (sourceX + sourceWidth) / tw, (sourceY + sourceHeight) / th);
		regionHeld = true;
		for (row in 0...3)
			for (col in 0...3) {
				var w = xs[col + 1] - xs[col], h = ys[row + 1] - ys[row];
				if (w > 0 && h > 0)
					quad(xs[col], ys[row], w, h, us[col] / tw, vs[row] / th, us[col + 1] / tw, vs[row + 1] / th, tint);
			}
		regionHeld = false;
	}

	/** Draws emitter's particles here in the batch's order (over what came before, under what comes after), through its camera: their places
		are world units (the batch's transform doesn't move them; they were born where their emitter was), the quads square to the screen. An
		emitter with nothing to draw draws nothing. */
	function emitter(emitter:helix.particle.Emitter):Void {
		if (!emitter.drawable)
			return;
		closeRun();
		if (particles == null)
			particles = new Batch2DParticles(gpu, pipelines);
		var drawn = particles.add(emitter, camera);
		var texture = emitter.texture;
		runs.push(texture.handle);
		runs.push(drawn.first);
		runs.push(drawn.count);
		runCameras.push(camera);
		runSamplings.push(texture.sampling);
		runEffects.push(null);
		runTextures.push(texture);
		pushRunClip();
		runParticles.push(drawn.index);
	}

	/** Draws one line of text, its top at y and x its left edge, center or right edge by align, size world units tall (ascent to descent), tinted
		color (0xAARRGGBB), in font or the batch's built-in one. Characters without a glyph are skipped. */
	function drawText(text:String, x:Float, y:Float, size:Float, color:Int, align:Align2D = Left, ?font:Font):Void {
		if (font == null)
			font = this.font;
		var unit = size / font.size;
		if (align == Center)
			x -= font.measure(text, size) / 2;
		else if (align == Right)
			x -= font.measure(text, size);
		var baseline = y + font.ascent * unit, field = font.distanceField;
		useTexture(font.texture);
		for (i in 0...text.length) {
			var code = text.charCodeAt(i), glyph = font.getGlyph(code);
			if (glyph != null) {
				if (glyph.width > 0)
					quad(x + glyph.x * unit, baseline + glyph.y * unit, glyph.width * unit, glyph.height * unit, glyph.u0, glyph.v0, glyph.u1, glyph.v1,
						color, field);
				x += glyph.advance * unit;
			}
			if (i + 1 < text.length)
				x += font.getKerning(code, text.charCodeAt(i + 1)) * unit;
		}
	}

	/** Draws text wrapped to width (Font.wrap), its lines lineHeight times size apart, the first's top at y, each placed by align at x, as
		drawText draws a line. Returns the height its lines take, so what follows can go under them (a HUD's lines on a narrow screen). */
	function drawTextWrapped(text:String, x:Float, y:Float, size:Float, width:Float, color:Int, align:Align2D = Left, lineHeight = 1.25, ?font:Font):Float {
		var f = font == null ? this.font : font, row = 0;
		for (line in f.wrap(text, size, width))
			drawText(line, x, y + size * lineHeight * row++, size, color, align, font);
		return size * lineHeight * row;
	}

	/** A filled rectangle in world units, top-left at x, y. */
	function rect(x:Float, y:Float, w:Float, h:Float, tint:Int):Void {
		solid();
		var u = texture.whiteU, v = texture.whiteV;
		quad(x, y, w, h, u, v, u, v, tint);
	}

	/** A filled triangle through three world points. */
	function triangle(x0:Float, y0:Float, x1:Float, y1:Float, x2:Float, y2:Float, tint:Int):Void {
		solid();
		var u = texture.whiteU, v = texture.whiteV;
		color(tint);
		region(u, v, u, v);
		vertex(x0, y0, u, v);
		vertex(x1, y1, u, v);
		vertex(x2, y2, u, v);
	}

	/** A segment width world units wide from x0, y0 to x1, y1, its ends as cap says (flat at the ends unless told); nothing for a segment of
		length 0, but a dot for a round cap. */
	function line(x0:Float, y0:Float, x1:Float, y1:Float, width:Float, tint:Int, cap:LineCap2D = Butt):Void {
		segment[0] = x0;
		segment[1] = y0;
		segment[2] = x1;
		segment[3] = y1;
		stroke(segment, false, width, Miter, cap, tint);
	}

	/** A path through points (x and y in turn), open, width world units wide centered on it, its corners as join says and its ends as cap
		says. Nothing for fewer than 2 distinct points, but a dot for a round cap. */
	function polyline(points:Array<Float>, width:Float, tint:Int, join:LineJoin2D = Miter, cap:LineCap2D = Butt):Void
		stroke(points, false, width, join, cap, tint);

	/** Rectangle outline drawn inside its bounds. */
	function frame(x:Float, y:Float, w:Float, h:Float, width:Float, tint:Int):Void {
		rect(x, y, w, width, tint);
		rect(x, y + h - width, w, width, tint);
		rect(x, y + width, width, h - 2 * width, tint);
		rect(x + w - width, y + width, width, h - 2 * width, tint);
	}

	/** A filled rectangle with corners of radius world units (clamped to half the shorter side), with segments for their size on screen. */
	function roundedRect(x:Float, y:Float, w:Float, h:Float, radius:Float, tint:Int):Void {
		if (radius <= 0 || w <= 0 || h <= 0) {
			rect(x, y, w, h, tint);
			return;
		}
		var n = roundedOutline(x, y, w, h, radius, cornerSteps(radius), outer), cx = x + w / 2, cy = y + h / 2;
		for (i in 0...n) {
			var j = (i + 1) % n;
			triangle(cx, cy, outer[i * 2], outer[i * 2 + 1], outer[j * 2], outer[j * 2 + 1], tint);
		}
	}

	/** A filled rectangle in world units, top-left at x, y, its corners of radius (clamped to half the shorter side; 0 for square), shaded from
		one color to the other (0xAARRGGBB), each channel linearly: across it, from its left edge to its right, or down, from its top to its
		bottom. */
	function gradientRect(x:Float, y:Float, w:Float, h:Float, radius:Float, from:Int, to:Int, down:Bool):Void {
		if (w <= 0 || h <= 0)
			return;
		solid();
		var u = texture.whiteU, v = texture.whiteV;
		region(u, v, u, v);
		// The color is linear in the position, so it is exact across any triangles: two for square corners, a fan from the middle for rounded.
		if (radius <= 0) {
			shadedVertex(x, y, x, y, w, h, from, to, down, u, v);
			shadedVertex(x + w, y, x, y, w, h, from, to, down, u, v);
			shadedVertex(x + w, y + h, x, y, w, h, from, to, down, u, v);
			shadedVertex(x, y, x, y, w, h, from, to, down, u, v);
			shadedVertex(x + w, y + h, x, y, w, h, from, to, down, u, v);
			shadedVertex(x, y + h, x, y, w, h, from, to, down, u, v);
			return;
		}
		var n = roundedOutline(x, y, w, h, radius, cornerSteps(radius), outer), cx = x + w / 2, cy = y + h / 2;
		for (i in 0...n) {
			var j = (i + 1) % n;
			shadedVertex(cx, cy, x, y, w, h, from, to, down, u, v);
			shadedVertex(outer[i * 2], outer[i * 2 + 1], x, y, w, h, from, to, down, u, v);
			shadedVertex(outer[j * 2], outer[j * 2 + 1], x, y, w, h, from, to, down, u, v);
		}
	}

	// A vertex at px, py of a gradient over the rectangle x, y, w x h: its color from's to to's by how far across (or down) it is.
	function shadedVertex(px:Float, py:Float, x:Float, y:Float, w:Float, h:Float, from:Int, to:Int, down:Bool, u:Float, v:Float):Void {
		var t = down ? (py - y) / h : (px - x) / w;
		t = t < 0 ? 0 : t > 1 ? 1 : t;
		r = (Color.getRed(from) * (1 - t) + Color.getRed(to) * t) / 255;
		g = (Color.getGreen(from) * (1 - t) + Color.getGreen(to) * t) / 255;
		b = (Color.getBlue(from) * (1 - t) + Color.getBlue(to) * t) / 255;
		a = (Color.getAlpha(from) * (1 - t) + Color.getAlpha(to) * t) / 255 * alpha;
		vertex(px, py, u, v);
	}

	/** A rounded rectangle's outline drawn inside its bounds, width wide: its inside's corners a radius less width, sharing their centers. */
	function roundedFrame(x:Float, y:Float, w:Float, h:Float, radius:Float, width:Float, tint:Int):Void {
		if (radius <= 0) {
			frame(x, y, w, h, width, tint);
			return;
		}
		if (w <= 0 || h <= 0 || width <= 0)
			return;
		width = Math.min(width, Math.min(w, h) / 2);
		radius = Math.min(radius, Math.min(w, h) / 2);
		var steps = cornerSteps(radius);
		var n = roundedOutline(x, y, w, h, radius, steps, outer);
		roundedOutline(x + width, y + width, w - width * 2, h - width * 2, radius - width, steps, inner);
		for (i in 0...n) {
			var j = (i + 1) % n;
			triangle(outer[i * 2], outer[i * 2 + 1], outer[j * 2], outer[j * 2 + 1], inner[i * 2], inner[i * 2 + 1], tint);
			triangle(inner[i * 2], inner[i * 2 + 1], outer[j * 2], outer[j * 2 + 1], inner[j * 2], inner[j * 2 + 1], tint);
		}
	}

	// A quarter of a circle's segments for radius, 2 at least.
	function cornerSteps(radius:Float):Int
		return Std.int(Math.max(2, Math.ceil(segments(radius) / 4)));

	// The outline of the rectangle x, y, w x h with corners of radius (0 to half its shorter side), into out: clockwise from the top-left
	// corner's arc, steps + 1 points a corner, so two outlines of the same steps join into a band. Returns its count of points.
	static function roundedOutline(x:Float, y:Float, w:Float, h:Float, radius:Float, steps:Int, out:Array<Float>):Int {
		w = Math.max(0, w);
		h = Math.max(0, h);
		var r = Math.max(0, Math.min(radius, Math.min(w, h) / 2)), k = 0;
		for (corner in 0...4) {
			var cx = corner == 0 || corner == 3 ? x + r : x + w - r,
				cy = corner < 2 ? y + r : y + h - r,
				start = Math.PI + corner * Math.PI / 2;
			for (i in 0...steps + 1) {
				var a = start + i * Math.PI / 2 / steps;
				out[k++] = cx + Math.cos(a) * r;
				out[k++] = cy + Math.sin(a) * r;
			}
		}
		return k >> 1;
	}

	/** Enough segments for the circle's size on screen: about one per 2.5 pixels of circumference, 12 at least. */
	function segments(radius:Float):Int
		return Std.int(Math.max(12, Math.min(256, Math.PI * 2 * radius * Math.sqrt(Math.abs(ta * td - tb * tc)) * Math.max(camera.zoom, camera.zoomY) / 2.5)));

	/** A filled circle in world units, centered on x, y, with segments for its size on screen. */
	function circle(x:Float, y:Float, radius:Float, tint:Int):Void {
		var n = segments(radius);
		for (i in 0...n) {
			var p = i * Math.PI * 2 / n, q = (i + 1) * Math.PI * 2 / n;
			triangle(x, y, x + Math.cos(p) * radius, y + Math.sin(p) * radius, x + Math.cos(q) * radius, y + Math.sin(q) * radius, tint);
		}
	}

	/** Circle outline drawn inside its radius. */
	function circleLines(x:Float, y:Float, radius:Float, width:Float, tint:Int):Void {
		var n = segments(radius), inner = Math.max(0, radius - width);
		for (i in 0...n) {
			var p = i * Math.PI * 2 / n,
				q = (i + 1) * Math.PI * 2 / n,
				cp = Math.cos(p),
				sp = Math.sin(p),
				cq = Math.cos(q),
				sq = Math.sin(q);
			triangle(x + cp * inner, y + sp * inner, x + cp * radius, y + sp * radius, x + cq * radius, y + sq * radius, tint);
			triangle(x + cp * inner, y + sp * inner, x + cq * radius, y + sq * radius, x + cq * inner, y + sq * inner, tint);
		}
	}

	/** Triangle outline drawn along its edges. */
	function triangleLines(x0:Float, y0:Float, x1:Float, y1:Float, x2:Float, y2:Float, width:Float, tint:Int):Void {
		line(x0, y0, x1, y1, width, tint);
		line(x1, y1, x2, y2, width, tint);
		line(x2, y2, x0, y0, width, tint);
	}

	/** A filled polygon through points (x and y in turn, at least 3), convex or not, as triangles of their indices (Polygon2D.triangulate's, three
		a triangle; worked out here when null: keep them for a polygon drawn every frame). */
	function polygon(points:Array<Float>, tint:Int, ?triangles:Array<Int>):Void {
		if (triangles == null)
			triangles = Polygon2D.triangulate(points);
		var i = 0;
		while (i + 2 < triangles.length) {
			var a = triangles[i] * 2,
				b = triangles[i + 1] * 2,
				c = triangles[i + 2] * 2;
			triangle(points[a], points[a + 1], points[b], points[b + 1], points[c], points[c + 1], tint);
			i += 3;
		}
	}

	/** A polygon's outline, closed, width world units wide centered on its edges, its corners as join says (mitered unless told; a miter
		longer than twice the width is cut to that). Nothing for fewer than 2 points. */
	function polygonLines(points:Array<Float>, width:Float, tint:Int, join:LineJoin2D = Miter):Void
		stroke(points, true, width, join, Butt, tint);

	/** A filled ellipse centered on x, y, radiusX across and radiusY down before it's turned by rotation (radians, clockwise), with segments
		for its size on screen. */
	function ellipse(x:Float, y:Float, radiusX:Float, radiusY:Float, rotation:Float, tint:Int):Void {
		var n = segments(Math.max(radiusX, radiusY)),
			c = Math.cos(rotation),
			s = Math.sin(rotation);
		var lastX = x + radiusX * c, lastY = y + radiusX * s;
		for (i in 1...n + 1) {
			var a = i * Math.PI * 2 / n,
				ex = Math.cos(a) * radiusX,
				ey = Math.sin(a) * radiusY;
			var px = x + ex * c - ey * s, py = y + ex * s + ey * c;
			triangle(x, y, lastX, lastY, px, py, tint);
			lastX = px;
			lastY = py;
		}
	}

	// A segment's two ends, for line, kept to draw without making an array.
	var segment = [0., 0., 0., 0.];
	// A stroke's distinct points, and each segment's direction (a unit vector), kept between strokes.
	var strokeX:Array<Float> = [];
	var strokeY:Array<Float> = [];
	var strokeDX:Array<Float> = [];
	var strokeDY:Array<Float> = [];

	// The path through points, closed or open, width wide centered on it: its corners joined as join says, an open path's ends capped as cap
	// says. Mitered corners are drawn as one strip; round and bevelled ones as a flat-ended band per segment with the gap on a corner's
	// outer side filled, so a translucent color shows a little overlap on the inner side.
	function stroke(points:Array<Float>, closed:Bool, width:Float, join:LineJoin2D, cap:LineCap2D, tint:Int):Void {
		var h = width / 2, xs = strokeX, ys = strokeY;
		xs.resize(0);
		ys.resize(0);
		var k = 0;
		while (k + 1 < points.length) {
			var x = points[k], y = points[k + 1];
			if (xs.length == 0 || x != xs[xs.length - 1] || y != ys[ys.length - 1]) {
				xs.push(x);
				ys.push(y);
			}
			k += 2;
		}
		if (closed && xs.length > 1 && xs[0] == xs[xs.length - 1] && ys[0] == ys[ys.length - 1]) {
			xs.pop();
			ys.pop();
		}
		var n = xs.length;
		if (n < 2 || h <= 0) {
			if (n >= 1 && !closed && cap == Round && h > 0)
				circle(xs[0], ys[0], h, tint);
			return;
		}
		var segments = closed ? n : n - 1, dxs = strokeDX, dys = strokeDY;
		dxs.resize(0);
		dys.resize(0);
		for (i in 0...segments) {
			var j = (i + 1) % n,
				dx = xs[j] - xs[i],
				dy = ys[j] - ys[i],
				length = Math.sqrt(dx * dx + dy * dy);
			dxs.push(dx / length);
			dys.push(dy / length);
		}
		// A square cap: the open ends carried half the width on.
		if (!closed && cap == Square) {
			xs[0] -= dxs[0] * h;
			ys[0] -= dys[0] * h;
			xs[n - 1] += dxs[segments - 1] * h;
			ys[n - 1] += dys[segments - 1] * h;
		}
		if (join == Miter) {
			// Each point's offset, half the width out along its miter (along its one segment's normal at an open end).
			var ox = outer, oy = inner;
			for (i in 0...n) {
				var before = closed || i > 0, after = closed || i < n - 1;
				var a = before ? (i + segments - 1) % segments : i,
					b = after ? i : i - 1;
				var nx = -dys[a] - dys[b],
					ny = dxs[a] + dxs[b],
					length = Math.sqrt(nx * nx + ny * ny);
				if (length < 1e-9) {
					nx = -dys[a];
					ny = dxs[a];
					length = 1;
				}
				nx /= length;
				ny /= length;
				var scale = h / Math.max(nx * -dys[a] + ny * dxs[a], .25);
				ox[i] = nx * scale;
				oy[i] = ny * scale;
			}
			for (i in 0...segments) {
				var j = (i + 1) % n;
				triangle(xs[i] + ox[i], ys[i] + oy[i], xs[i] - ox[i], ys[i] - oy[i], xs[j] - ox[j], ys[j] - oy[j], tint);
				triangle(xs[i] + ox[i], ys[i] + oy[i], xs[j] - ox[j], ys[j] - oy[j], xs[j] + ox[j], ys[j] + oy[j], tint);
			}
		} else {
			for (i in 0...segments) {
				var j = (i + 1) % n, px = -dys[i] * h, py = dxs[i] * h;
				triangle(xs[i] + px, ys[i] + py, xs[i] - px, ys[i] - py, xs[j] - px, ys[j] - py, tint);
				triangle(xs[i] + px, ys[i] + py, xs[j] - px, ys[j] - py, xs[j] + px, ys[j] + py, tint);
			}
			// Each corner's gap on its outer side: an arc around it, or one triangle across it.
			for (i in (closed ? 0 : 1)...(closed ? n : n - 1)) {
				var a = (i + segments - 1) % segments, b = i;
				var turn = dxs[a] * dys[b] - dys[a] * dxs[b],
					side = turn > 0 ? -1 : 1;
				if (Math.abs(turn) < 1e-9 && dxs[a] * dxs[b] + dys[a] * dys[b] > 0)
					continue;
				var ax = -dys[a] * h * side,
					ay = dxs[a] * h * side,
					bx = -dys[b] * h * side,
					by = dxs[b] * h * side;
				if (join == Bevel)
					triangle(xs[i], ys[i], xs[i] + ax, ys[i] + ay, xs[i] + bx, ys[i] + by, tint);
				else
					arc(xs[i], ys[i], h, Math.atan2(ay, ax), Math.atan2(by, bx), tint);
			}
		}
		if (!closed && cap == Round) {
			// Half a circle past each end, from one side round the end to the other.
			var start = Math.atan2(dxs[0], -dys[0]),
				end = Math.atan2(-dxs[segments - 1], dys[segments - 1]);
			arcThrough(xs[0], ys[0], h, start, Math.PI, tint);
			arcThrough(xs[n - 1], ys[n - 1], h, end, Math.PI, tint);
		}
	}

	// A fan of radius around x, y from angle from to angle to, the short way round.
	function arc(x:Float, y:Float, radius:Float, from:Float, to:Float, tint:Int):Void {
		var sweep = to - from;
		while (sweep > Math.PI)
			sweep -= Math.PI * 2;
		while (sweep <= -Math.PI)
			sweep += Math.PI * 2;
		arcThrough(x, y, radius, from, sweep, tint);
	}

	// A fan of radius around x, y from angle from through sweep radians, with steps for its size on screen.
	function arcThrough(x:Float, y:Float, radius:Float, from:Float, sweep:Float, tint:Int):Void {
		var steps = Std.int(Math.max(1, Math.ceil(Math.abs(sweep) / (Math.PI * 2) * segments(radius))));
		var lastX = x + Math.cos(from) * radius,
			lastY = y + Math.sin(from) * radius;
		for (i in 1...steps + 1) {
			var a = from + sweep * i / steps,
				px = x + Math.cos(a) * radius,
				py = y + Math.sin(a) * radius;
			triangle(x, y, lastX, lastY, px, py, tint);
			lastX = px;
			lastY = py;
		}
	}

	/** Frees the buffers and font made by new; the batch is unusable after. */
	function destroy():Void {
		gpu.destroyBuffer(buffer);
		if (particles != null)
			particles.destroy();
		if (effectBuffer != 0)
			gpu.destroyBuffer(effectBuffer);
		font.destroy(gpu);
	}
}

/** What draws a batch's particles, reached only through this, so a batch whose first emitter never comes carries none of the particle
	drawing, nor the particle program (CONVENTIONS, "An optional part is installed by its first use"). */
private interface BatchParticles {
	/** A new frame: no particles yet. */
	function startFrame():Void;

	/** emitter's particles added to the frame's, seen through camera: the index they're drawn by, and their first record and count. */
	function add(emitter:helix.particle.Emitter, camera:Camera2D):{index:Int, first:Int, count:Int};

	/** The frame's records uploaded, once all are added. */
	function upload():Void;

	/** The particles added as index drawn, of texture sampled by sampling. */
	function draw(index:Int, texture:Int, sampling:Sampling):Void;

	/** Their buffers freed. */
	function destroy():Void;
}

/** A batch's particles: their quad, the frame's records in one upload, and each emitter's uniforms and blending. */
private class Batch2DParticles implements BatchParticles {
	var gpu:IGraphics;
	var pipelines:Pipelines;
	var corners:Int;
	var indices:Int;
	var buffer = 0;
	var capacity = 0;
	var records:Bytes = Bytes.alloc(0);
	var count = 0;
	// By index, this frame: each emitter's first record and count, its uniforms, and its blending (0 opaque, 1 blended, 2 added).
	var drawn:Array<{
		first:Int,
		count:Int,
		uniforms:Bytes,
		phase:Int
	}> = [];

	/** Particles drawn on gpu, with the program from pipelines: their quad made now. */
	public function new(gpu:IGraphics, pipelines:Pipelines) {
		this.gpu = gpu;
		this.pipelines = pipelines;
		var quad = Bytes.alloc(4 * Particle3DProgram.stride), at = 0;
		for (c in [-.5, -.5, .5, -.5, .5, .5, -.5, .5]) {
			quad.setFloat(at, c);
			at += 4;
		}
		corners = gpu.createStaticBuffer(quad, quad.length, false);
		var order = Bytes.alloc(24);
		for (k in 0...6)
			order.setInt32(k * 4, [0, 1, 2, 0, 2, 3][k]);
		indices = gpu.createStaticBuffer(order, 24, true);
	}

	public function startFrame():Void {
		count = 0;
		drawn = [];
	}

	public function add(emitter:helix.particle.Emitter, camera:Camera2D):{index:Int, first:Int, count:Int} {
		var needed = (count + emitter.particleCount) * Particle3DProgram.instanceStride;
		if (needed > records.length) {
			var grown = Bytes.alloc(Std.int(Math.max(needed, records.length * 2)));
			grown.blit(0, records, 0, count * Particle3DProgram.instanceStride);
			records = grown;
		}
		var first = count, written = emitter.writeRecords(records, first * Particle3DProgram.instanceStride);
		count += written;
		// The camera's mapping from the world to clip space as a matrix; z at the near plane, so nothing drawn before hides them.
		var projection = new helix.render3d.Mat4();
		var sx = camera.zoom * 2 / camera.viewportWidth,
			sy = camera.zoomY * 2 / camera.viewportHeight;
		projection.set(0, sx);
		projection.set(5, -sy);
		projection.set(10, 0);
		projection.set(12, -camera.x * sx);
		projection.set(13, camera.y * sy);
		projection.set(14, -1);
		var uniforms = Bytes.alloc(Particle3DProgram.vertexUniformBytes);
		// Across the screen, and up it (y grows down in 2D).
		emitter.writeUniforms(uniforms, projection, [1, 0, 0], [0, -1, 0]);
		var phase = switch emitter.alphaMode {
			case Blend: 1;
			case Add: 2;
			case _: 0;
		};
		drawn.push({
			first: first,
			count: written,
			uniforms: uniforms,
			phase: phase
		});
		return {index: drawn.length - 1, first: first, count: written};
	}

	public function upload():Void {
		if (count == 0)
			return;
		if (count > capacity) {
			if (buffer != 0)
				gpu.destroyBuffer(buffer);
			capacity = 1024;
			while (capacity < count)
				capacity *= 2;
			buffer = gpu.createBuffer(capacity * Particle3DProgram.instanceStride);
		}
		gpu.updateBuffer(buffer, records, count * Particle3DProgram.instanceStride);
	}

	public function draw(index:Int, texture:Int, sampling:Sampling):Void {
		var d = drawn[index];
		gpu.draw(pipelines.particle3D(cast d.phase), [corners, buffer], indices, 0, 6, d.first, d.count, [texture], [sampling], [d.uniforms]);
	}

	public function destroy():Void {
		gpu.destroyBuffer(corners);
		gpu.destroyBuffer(indices);
		if (buffer != 0)
			gpu.destroyBuffer(buffer);
	}
}
