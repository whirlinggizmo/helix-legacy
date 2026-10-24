import haxe.io.Bytes;
import helix.graphics.IGraphics;
import helix.graphics.PipelineDesc;
import helix.texture.Sampling;
import helix.texture.Wrap;
import helix.graphics.ShaderSource;
import helix.texture.TextureFormat;
import helix.render2d.Batch2D;
import helix.render2d.Camera2D;
import helix.render2d.HitArea2D;
import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.ShapeShading2D;
import helix.render2d.Sprite2D;
import helix.render2d.Text2D;
import helix.render2d.Polygon2D;
import helix.render2d.Renderer2D;
import helix.texture.Texture2D;
import helix.render3d.Model3D;
import helix.render3d.Sprite3D;

/** Graphics that only counts: handles, and the draws and viewports of a frame, sorted by what their pipeline draws: a 2D batch's
	(unindexed, with buffers), a screen effect's or background's (no buffers), or a mesh's (indexed). */
@:access(helix)
class CountingGraphics implements IGraphics {
	var next = 1;
	var pipelineDescs = new Map<Int, PipelineDesc>();

	/** Each 2D draw (unindexed, with buffers), in order: its range, first sampling, pipeline, buffers, textures and uniform blocks. */
	public var draws:Array<{
		vertices:Int,
		first:Int,
		sampling:Sampling,
		pipeline:Int,
		buffers:Array<Int>,
		textures:Array<Int>,
		uniforms:Array<Null<Bytes>>
	}> = [];

	public var viewports:Array<Array<Int>> = [];
	public var uploaded:Null<Bytes>;

	/** Each buffer's last upload, by handle. */
	public var uploads:Map<Int, Bytes> = [];

	public function new() {}

	public function createTexture(width:Int, height:Int, levels:Array<Bytes>, format:TextureFormat = Rgba8):Int
		return next++;

	public function createCubeTexture(size:Int, levels:Array<Bytes>, format:TextureFormat):Int
		return next++;

	public function createDataTexture(width:Int, height:Int):Int
		return next++;

	public function updateDataTexture(handle:Int, data:Bytes):Void {}

	public function canSample(format:TextureFormat):Bool
		return format == Rgba8 || format == Astc4x4 || format == Rgba16f;

	public var msaaSamples(get, never):Int;

	function get_msaaSamples():Int
		return 1;

	public var maxMsaaSamples(get, never):Int;

	function get_maxMsaaSamples():Int
		return 1;

	/** Each buffer's size as made, by handle. */
	public var bufferBytes = new Map<Int, Int>();

	public function createBuffer(capacityBytes:Int):Int {
		var id = next++;
		bufferBytes[id] = capacityBytes;
		return id;
	}

	public function createStaticBuffer(data:Bytes, bytes:Int, index:Bool):Int
		return next++;

	public function createPipeline(desc:PipelineDesc):Int {
		var id = next++;
		pipelineDescs[id] = desc;
		return id;
	}

	public var screen:Null<{textures:Array<Int>, uniforms:Array<Null<Bytes>>}>;

	public function createShader(source:ShaderSource):Int
		return next++;

	public function destroyShader(handle:Int):Void {}

	public function updateBuffer(handle:Int, data:Bytes, usedBytes:Int):Void {
		uploaded = data.sub(0, usedBytes);
		uploads[handle] = uploaded;
	}

	/** Whether it draws into half floats (canRender). */
	public var floatTargets = true;

	public function canRender(format:TextureFormat):Bool
		return format == Rgba8 || floatTargets && format == Rgba16f;

	/** Each render target made, by handle: its size, format and whether it has depth. */
	public var renderTargets:Map<Int, {
		width:Int,
		height:Int,
		format:TextureFormat,
		depth:Bool
	}> = [];

	/** The render targets target passes drew into, in order. */
	public var targetPasses:Array<Int> = [];

	public function createRenderTarget(width:Int, height:Int, format:TextureFormat = Rgba8, depth:Bool = true):Int {
		renderTargets[next] = {
			width: width,
			height: height,
			format: format,
			depth: depth
		};
		return next++;
	}

	/** The colors target passes cleared to, red, green, blue and alpha, in order. */
	public var targetClears:Array<Array<Float>> = [];

	public function beginTargetPass(target:Int, red:Float, green:Float, blue:Float, alpha:Float):Void {
		targetPasses.push(target);
		targetClears.push([red, green, blue, alpha]);
	}

	public function endTargetPass():Void {}

	/** The layers shadow passes drew into, in order. */
	public var shadowPasses:Array<Int> = [];

	public function createShadowMap(size:Int, layers:Int):Int
		return next++;

	public function beginShadowPass(map:Int, layer:Int):Void
		shadowPasses.push(layer);

	/** The last frame's clear color, and how many frames have ended. */
	public var clearColor = 0;

	public var framesEnded = 0;

	public function beginFrame(width:Int, height:Int, clearColor:Int):Void {
		draws = [];
		viewports = [];
		this.clearColor = clearColor;
	}

	/** Each scissor set (x, y, w, h), or null for a reset, in order. */
	public var scissors:Array<Null<Array<Int>>> = [];

	public function applyScissor(x:Int, y:Int, w:Int, h:Int):Void
		scissors.push([x, y, w, h]);

	public function resetScissor():Void
		scissors.push(null);

	public function applyViewport(x:Int, y:Int, w:Int, h:Int):Void
		viewports.push([x, y, w, h]);

	/** Each mesh draw's pipeline, in order. */
	public var meshPipelines:Array<Int> = [];

	/** Each mesh draw's instance count and first instance, its buffers, textures and uniform blocks, in order. */
	public var meshDraws:Array<{
		instances:Int,
		firstInstance:Int,
		buffers:Array<Int>,
		textures:Array<Int>,
		uniforms:Array<Null<Bytes>>
	}> = [];

	/** The description a pipeline was made from. */
	public function describe(pipeline:Int):PipelineDesc
		return pipelineDescs[pipeline];

	public function draw(pipeline:Int, buffers:Array<Int>, indices:Int, first:Int, count:Int, firstInstance:Int, instanceCount:Int, textures:Array<Int>,
			samplings:Array<Sampling>, uniforms:Array<Null<Bytes>>):Void {
		var desc = pipelineDescs[pipeline];
		if (desc.indexed) {
			meshPipelines.push(pipeline);
			meshDraws.push({
				instances: instanceCount,
				firstInstance: firstInstance,
				buffers: buffers.copy(),
				textures: textures.copy(),
				uniforms: [for (u in uniforms) u == null ? null : u.sub(0, u.length)]
			});
		} else if (desc.buffers.length == 0)
			screen = {textures: textures, uniforms: uniforms};
		else
			draws.push({
				vertices: count,
				first: first,
				sampling: samplings.length > 0 ? samplings[0] : Sampling.NEAREST,
				pipeline: pipeline,
				buffers: buffers.copy(),
				textures: textures.copy(),
				uniforms: [for (u in uniforms) u == null ? null : u.sub(0, u.length)]
			});
	}

	public function endFrame():Void
		framesEnded++;

	public function readPixels(target:Int, done:helix.graphics.IGraphics.ReadPixelsResult->Void):Void
		done(Failed("No GPU"));

	public var destroyedTextures = 0;

	public function destroyTexture(handle:Int):Void
		destroyedTextures++;

	public function destroyBuffer(handle:Int):Void {}

	public function destroyPipeline(handle:Int):Void {}

	public function shutdown():Void {}
}

/** Assets whose loads complete when flush says, counting them. Only load and the subscriptions do anything. */
@:access(helix)
class HeldAssets implements helix.asset.IAssets {
	public var loads = 0;
	public var held:Array<Void->Void> = [];

	public function new() {}

	public function load(path:String, loaded:Bytes->Void, ?failed:String->Void):helix.asset.IRequest {
		loads++;
		held.push(() -> loaded(Bytes.alloc(4)));
		return new helix.asset.Request(() -> {});
	}

	public function flush():Void {
		var now = held;
		held = [];
		for (f in now)
			f();
	}

	public function ensure(path:String, loaded:Bytes->Void, ?failed:String->Void, ?progress:helix.asset.AssetProgress->Void,
			?options:helix.asset.EnsureOptions):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public var host(get, never):Null<String>;

	function get_host():Null<String>
		return null;

	public function setHost(host:Null<String>):Bool
		return false;

	public function pingHost(host:String, probePath:String, timeoutSeconds:Float, complete:Bool->Void):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public function clearCache(complete:helix.asset.StorageWriteResult->Void):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public var manifest(get, never):Null<String>;

	function get_manifest():Null<String>
		return null;

	public function setManifest(path:Null<String>):Bool
		return true;

	public var cacheMode(get, set):helix.asset.AssetCacheMode;

	function get_cacheMode():helix.asset.AssetCacheMode
		return Revalidate;

	function set_cacheMode(mode:helix.asset.AssetCacheMode):helix.asset.AssetCacheMode {
		return mode;
	}

	public function streamSource(path:String, located:helix.asset.IAssets.AudioLocation->Void, ?failed:String->Void, download:Bool = false):helix.asset.IRequest
		return new helix.asset.Request(() -> {});

	public function subscribe(path:String, target:helix.asset.IReloadable):Void {}

	public function unsubscribe(path:String, target:helix.asset.IReloadable):Void {}

	public var busy(get, never):Bool;

	function get_busy():Bool
		return held.length > 0;
}

/** A decoder answering at once with one white texel, counting decodes. */
@:access(helix)
class WhiteImages implements helix.graphics.IImageDecoder {
	public var decodes = 0;

	public function new() {}

	public function decode(encoded:Bytes, done:helix.graphics.ImageDecoding.ImageDecodeResult->Void):Void {
		decodes++;
		var pixel = Bytes.alloc(4);
		pixel.fill(0, 4, 255);
		done(Decoded(1, 1, pixel));
	}

	public function poll():Void {}
}

/** Polygon2D, Node2D's transforms and kinds, and Renderer2D's walk, culling and cameras, through a Batch2D on graphics that only counts. */
@:access(helix.host.Screen)
@:access(helix)
class Render2DTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float):Bool
		return Math.abs(a - b) < 1e-9;

	// The area the triangles cover, summed.
	static function covered(points:Array<Float>, triangles:Array<Int>):Float {
		var sum = 0., i = 0;
		while (i < triangles.length) {
			sum += Math.abs(Polygon2D.doubleArea([
				for (k in 0...3)
					for (c in 0...2)
						points[triangles[i + k] * 2 + c]
			])) / 2;
			i += 3;
		}
		return sum;
	}

	// An unsized camera takes Screen's framebuffer as a batch begins with it (or as it fits or goes to pixels), and follows it; one the app
	// sized keeps its size; with no Screen bound (no runner), it stays as it is.
	static function unsizedCamera():Void {
		var screen = new helix.host.Presentation();
		@:privateAccess screen.refit(640, 480, 1);
		@:privateAccess helix.host.Screen.bind(screen);
		var gpu = new CountingGraphics(),
			batch = new Batch2D(gpu),
			fresh = new Camera2D(),
			own = new Camera2D();
		check(!fresh.sized && fresh.viewportWidth == 1 && fresh.viewportHeight == 1, "A fresh camera is unsized, on a 1 x 1 viewport");
		gpu.beginFrame(640, 480, 0);
		batch.begin(fresh);
		batch.end();
		check(!fresh.sized && fresh.viewportWidth == 640 && fresh.viewportHeight == 480 && fresh.framebufferWidth == 640 && fresh.framebufferHeight == 480,
			"An unsized camera takes the framebuffer as the batch begins, and stays unsized");
		@:privateAccess screen.refit(800, 600, 1);
		own.setViewport(320, 240);
		batch.begin(fresh);
		batch.camera = own;
		batch.end();
		check(fresh.viewportWidth == 800 && fresh.viewportHeight == 600, "It follows the framebuffer's next size");
		check(own.sized && own.viewportWidth == 320 && own.viewportHeight == 240, "A camera the app sized keeps its size, as the batch's camera too");
		var byPixels = new Camera2D(), fitted = new Camera2D();
		check(byPixels.pixels(2) && byPixels.viewportWidth == 800 && near(byPixels.x, 200) && near(byPixels.y, 150),
			"pixels on an unsized camera takes the framebuffer first");
		check(fitted.fit(0, 0, 400, 300) && fitted.viewportWidth == 800 && near(fitted.zoom, 2), "So does fit");
		@:privateAccess helix.host.Screen.bind(null);
		var alone = new Camera2D();
		batch.begin(alone);
		batch.end();
		check(!alone.sized && alone.viewportWidth == 1, "With no Screen bound, outside a runner, an unsized camera stays as it is");
		batch.destroy();
	}

	static function main():Void {
		// Polygons: a square either way round, and a concave arrow, covered exactly by n - 2 triangles.
		var square = [0., 0, 10, 0, 10, 10, 0, 10];
		var reversed = [0., 10, 10, 10, 10, 0, 0, 0];
		var arrow = [0., 0, 10, 5, 0, 10, 3, 5];
		for (points in [square, reversed, arrow]) {
			var triangles = Polygon2D.triangulate(points);
			check(triangles.length == (points.length / 2 - 2) * 3, "A simple polygon of n points is n - 2 triangles");
			check(near(covered(points, triangles), Math.abs(Polygon2D.doubleArea(points)) / 2), "The triangles cover the polygon exactly");
		}
		check(Polygon2D.doubleArea(square) > 0, "Clockwise on screen (y down) is a positive area");
		check(Shape2D.polygon([0, 0, 1, 1]) == null
			&& Shape2D.polygon([0, 0, 1, 1, 2]) == null, "A polygon needs 3 points, x and y in pairs");

		// Transforms: a child of a turned, scaled, placed parent; toLocal undoes toWorld.
		var stage = new Renderer2D(),
			parent = new Node2D(),
			child = Shape2D.circle(1);
		parent.setPosition(100, 50);
		parent.rotation = Math.PI / 2;
		parent.setScale(2, 2);
		child.setPosition(10, 0);
		parent.addChild(child);
		stage.add(parent);
		var gpu = new CountingGraphics(),
			batch = new Batch2D(gpu),
			camera = new Camera2D();
		camera.setViewport(400, 300);
		camera.pixels(1);
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		// Turned a quarter clockwise on screen (y down), +x points down: 10 along x, doubled, is 20 below the parent.
		check(near(child.toWorldX(0, 0), 100) && near(child.toWorldY(0, 0), 70), "A child is placed by its parent's turn, scale and position");
		check(near(child.toLocalX(child.toWorldX(3, -4), child.toWorldY(3, -4)), 3)
			&& near(child.toLocalY(child.toWorldX(3, -4), child.toWorldY(3, -4)), -4),
			"toLocal undoes toWorld");
		parent.setPosition(0, 0);
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		check(near(child.toWorldY(0, 0), 20), "Moving the parent moves the child at the next draw");
		check(!child.addChild(parent) && !parent.addChild(parent), "No node becomes its own ancestor");
		// Assigning x, y, rotation or a scale marks it moved, as setPosition does.
		parent.x = 30;
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		check(near(child.toWorldX(0, 0), 30) && near(child.toWorldY(0, 0), 20) && parent.x == 30, "Assigning x moves the node in the world");
		parent.scaleX = 1;
		parent.scaleY = 1;
		parent.rotation = 0;
		parent.y = 5;
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		check(near(child.toWorldX(0, 0), 40) && near(child.toWorldY(0, 0), 5), "Assigning y, rotation and the scales move it too");
		// attach keeps a node's world place under a moved, turned, scaled parent; parent = keeps its local one.
		var holder = new Node2D(), held = new Node2D();
		holder.setPosition(100, 50);
		holder.rotation = Math.PI / 2;
		holder.setScale(2, 3);
		held.setPosition(7, 9);
		check(holder.addChildInPlace(held) && held.parent == holder, "attach makes it a child");
		var w = @:privateAccess Node2D.worldOf(held);
		check(near(w[4], 7) && near(w[5], 9) && near(w[0], 1) && near(w[3], 1), "An attached node keeps its world place");
		check(!held.addChildInPlace(holder) && holder.parent == null, "attach refuses an ancestor as add does");
		// addChildAt: a place in the drawing order, past the end the last; a child already there moves; an ancestor refused.
		var row = new Node2D(),
			a = new Node2D(),
			b = new Node2D(),
			c = new Node2D();
		row.addChild(a);
		row.addChild(b);
		check(row.addChildAt(c, 1) && row.getChild(0) == a && row.getChild(1) == c && row.getChild(2) == b, "Put between");
		check(row.addChildAt(b, 0) && row.getChild(0) == b && row.getChild(1) == a && row.getChild(2) == c && row.childCount == 3,
			"Its own child moved to the front");
		check(row.addChildAt(b, 99) && row.getChild(2) == b && row.addChildAt(a, -1) && row.getChild(2) == a, "Past the end, or -1: the last");
		check(!a.addChildAt(row, 0) && row.parent == null, "An ancestor refused");
		check(row.contains(row) && row.contains(b) && !b.contains(row) && !row.contains(new Node2D()) && !row.contains(null),
			"contains: itself and below, not above, not elsewhere, not null");
		check(row.getChildIndex(b) == 1 && row.getChildIndex(a) == 2 && row.getChildIndex(row) == -1, "Each child's index; -1 for a non-child");
		check(row.removeChildAt(0) == c
			&& c.parent == null
			&& row.childCount == 2
			&& row.removeChildAt(5) == null
			&& row.childCount == 2,
			"removeChildAt takes and returns the child there; past the end, nothing");
		row.addChildAt(c, 0);
		// find: by name and kind, null of another kind.
		var text = new Text2D("Hi", 10, 0xffffffff);
		text.name = "greeting";
		c.addChild(text);
		check(row.find("greeting", Text2D) == text
			&& row.find("greeting", Node2D) == text
			&& row.find("greeting", Shape2D) == null
			&& row.find("missing", Node2D) == null,
			"find by kind: its own, any node, another kind (null), none");
		held.parent = null;
		held.setPosition(1, 0);
		held.parent = holder;
		w = @:privateAccess Node2D.worldOf(held);
		check(held.parent == holder && near(w[4], 100) && near(w[5], 52), "parent = keeps its local transform");
		held.parent = null;
		check(held.parent == null && holder.childCount == 0, "parent = null takes it from its parent");

		// A mirrored sprite covers the same box; a sprite with no texture draws nothing.
		var texture = Texture2D.fromRgba(4, 2, Bytes.alloc(32), gpu);
		var sprite = new Sprite2D(texture);
		check(sprite.width == 4 && sprite.height == 2, "A sprite with no size is its texture's size in texels");
		sprite.setRegion(1, 0, 2, 2);
		check(sprite.width == 2 && sprite.regionWidth == 2, "A region gives it the region's size");
		sprite.setSize(8, 6);
		check(sprite.width == 8 && sprite.height == 6 && sprite.regionWidth == 2, "A size is drawn at, the region kept");
		sprite.setSize(0, 0);
		check(sprite.width == 2, "A size of 0 goes back to the region's");

		// Culling: of three circles, the one far outside the view isn't drawn; hidden nodes and their children aren't either.
		var culled = new Renderer2D();
		for (x in [10., 390, 5000]) {
			var c = Shape2D.circle(5);
			c.setPosition(x, 150);
			culled.add(c);
		}
		var hidden = new Node2D();
		hidden.addChild(Shape2D.circle(5));
		hidden.visible = false;
		culled.add(hidden);
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		culled.draw(batch, camera);
		batch.end();
		check(culled.drawnNodeCount == 2 && hidden.getChild(0).visible, "Only nodes in view are drawn; a hidden group takes its children with it");
		hidden.getChild(0).visible = false;
		hidden.visible = true;
		batch.begin(camera);
		culled.draw(batch, camera);
		batch.end();
		check(culled.drawnNodeCount == 2 && hidden.getChild(0).pickable, "A hidden node isn't drawn; its pickable is kept");

		// The pick overlay: each shown node's box, and what each pickable one is hit by; hidden and unpickable subtrees as a pick has them.
		var looked = new Renderer2D(),
			solid = Shape2D.rectangle(10, 10),
			ghostly = new Node2D(),
			deaf = new Node2D(),
			spot = new Node2D(),
			overlay = new helix.debug.PickOverlay2D();
		ghostly.addChild(Shape2D.rectangle(10, 10));
		ghostly.visible = false;
		deaf.addChild(Shape2D.rectangle(10, 10));
		deaf.pickable = false;
		spot.hitArea = HitArea2D.circle(0, 0, 5);
		for (node in [solid, ghostly, deaf, spot, (overlay : Node2D)])
			looked.add(node);
		batch.begin(camera);
		looked.draw(batch, camera);
		batch.end();
		check(overlay.callCount == 4, "Box and hit shape for a shape, nothing hidden, a box alone unpickable, a hit area alone");
		function redraw():Int {
			@:privateAccess overlay.refreshedAt = Math.NaN;
			batch.begin(camera);
			looked.draw(batch, camera);
			batch.end();
			return overlay.callCount;
		}
		overlay.drawBounds = false;
		check(redraw() == 2, "Its boxes switched off: the hit shapes alone");
		overlay.drawBounds = true;
		overlay.pickShapes = false;
		check(redraw() == 2, "Its hit shapes switched off: the boxes alone");
		var outlines = [], ring = Shape2D.circle(10);
		ring.outline = 2;
		Renderer2D.pickOutlines(ring, null, outlines);
		check(outlines.length == 2 && near(outlines[0][0], 10) && near(outlines[1][0], 12), "A ring's pick shape: its two edges, as a pick tests it");
		Renderer2D.pickOutlines(Shape2D.line(0, 0, 10, 0), null, outlines);
		check(outlines.length == 1 && outlines[0].length == 68, "A line's: the stroke about it");
		Renderer2D.pickOutlines(new Node2D(), null, outlines);
		check(outlines.length == 0, "A group's: nothing");

		// Two cameras in one batch: a run each, each in its own viewport.
		var left = new Camera2D(), right = new Camera2D();
		left.setViewport(400, 300);
		left.setViewportArea(0, 0, 200, 300);
		left.pixels(1);
		right.setViewport(400, 300);
		right.setViewportArea(200, 0, 200, 300);
		right.pixels(1);
		gpu.beginFrame(400, 300, 0);
		batch.begin(left);
		batch.rect(0, 0, 10, 10, -1);
		stage.draw(batch, right);
		batch.end();
		check(gpu.draws.length == 2 && gpu.viewports.length == 2 && gpu.viewports[0][0] == 0 && gpu.viewports[1][0] == 200,
			"A camera change splits the batch, each part in its camera's viewport");
		check(gpu.draws[0].vertices == 6 && gpu.draws[1].first == 6, "The parts follow each other in the one upload");

		// The transform places vertices: a rect at the origin, moved 10 right, starts at clip x of world 10.
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		batch.setTransform(1, 0, 0, 1, 10, 0);
		batch.rect(0, 0, 1, 1, -1);
		batch.end();
		check(Math.abs(gpu.uploaded.getFloat(0) - camera.clipX(10)) < 1e-6, "setTransform places what follows");
		// A shaded rectangle: each vertex its color by how far across (or down) it is, alpha too; flat, outlined, it's one color.
		var shaded = Shape2D.rectangle(10, 20, 0x00ff0000);
		shaded.shading = Across;
		shaded.endColor = 0xff0000ff;
		var shadedStage = new Renderer2D();
		shadedStage.add(shaded);
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		shadedStage.draw(batch, camera);
		batch.end();
		function vertexColor(i:Int):Array<Float> {
			var c = i * Sprite2DProgram.stride + Sprite2DProgram.colorOffset,
				data = gpu.uploaded;
			return [for (k in 0...4) Math.round(data.getFloat(c + k * 4) * 255)];
		}
		check(vertexColor(0).join(",") == "255,0,0,0"
			&& vertexColor(1).join(",") == "0,0,255,255"
			&& vertexColor(5).join(",") == "255,0,0,0",
			"Across: its left edge the color, its right the end color");
		shaded.shading = Down;
		shaded.cornerRadius = 4;
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		shadedStage.draw(batch, camera);
		batch.end();
		var middle = vertexColor(0);
		check(middle.join(",") == "128,0,128,128", "Down and rounded: a fan from its middle, half way between: " + middle);
		shaded.outline = 2;
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		shadedStage.draw(batch, camera);
		batch.end();
		check(vertexColor(0).join(",") == "255,0,0,0", "Outlined: flat");
		// Sampling: its bits round-trip, and a change of a texture's sampling splits the batch's run, each part sampled as it was then.
		var sampling = new Sampling(true, Repeat, Mirror);
		check(sampling.linear && sampling.wrapU == Repeat && sampling.wrapV == Mirror && (sampling : Int) < Sampling.COUNT,
			"Sampling keeps its filter and wraps");
		check(!sampling.withLinear(false).linear && sampling.withWrap(Clamp, Clamp).wrapV == Clamp, "with* change one part");
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		texture.sampling = Sampling.LINEAR;
		batch.image(texture, 0, 0, 4, 4);
		texture.sampling = Sampling.NEAREST;
		batch.image(texture, 4, 0, 4, 4);
		batch.image(texture, 8, 0, 4, 4);
		batch.end();
		check(gpu.draws.length == 2 && gpu.draws[0].sampling.linear && !gpu.draws[1].sampling.linear && gpu.draws[1].vertices == 12,
			"A texture drawn smooth then sharp is two runs, sampled as each was drawn");

		// KTX 1: a 5 x 3 ASTC 4x4 file with its mipmaps (2 x 1, 1 x 1): one block a level.
		var file = new haxe.io.BytesBuffer();
		for (b in [0xAB, 0x4B, 0x54, 0x58, 0x20, 0x31, 0x31, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A])
			file.addByte(b);
		for (v in [0x04030201, 0, 1, 0, 0x93B0, 0x1908, 5, 3, 0, 0, 1, 3, 4])
			file.addInt32(v);
		file.addInt32(0); // key/value data: 4 bytes of nothing
		var levelSizes = [2 * 1 * 16, 16, 16];
		for (size in levelSizes) {
			file.addInt32(size);
			for (i in 0...size)
				file.addByte(i);
		}
		var ktx = helix.texture.Ktx.read(file.getBytes());
		check(ktx.format == Astc4x4 && ktx.width == 5 && ktx.height == 3 && ktx.levels.length == 3 && ktx.levels[0].length == 32,
			"A KTX file's format, size and levels are read");
		var bad = false;
		try
			helix.texture.Ktx.read(Bytes.alloc(64))
		catch (e:Dynamic)
			bad = true;
		check(bad, "A file that isn't KTX is refused");
		check((Astc4x4 : TextureFormat).levelBytes(5, 3) == 32 && (Rgba8 : TextureFormat).levelBytes(5, 3) == 60,
			"Level sizes: blocks of 4x4, or 4 bytes a texel");

		// "name.ktx" tries the variants this GPU samples (here ASTC only), then the PNG; a variant named outright is tried alone.
		var textures = new helix.texture.TextureCache(null, null, gpu);
		check(textures.getCandidates("a/b.ktx").join(",") == "a/b.astc.ktx,a/b.png", "name.ktx: this GPU's variants, then name.png");
		check(textures.getCandidates("a/b.bc7.ktx").join(",") == "a/b.bc7.ktx" && textures.getCandidates("a/b.png").join(",") == "a/b.png",
			"Other paths are themselves");
		// TrueType: the example fonts' characters, outlines and kerning; a baked atlas whose glyphs fit it, with its white texel.
		var komika = new helix.font.TrueType(sys.io.File.getBytes("examples/assets/fonts/Komika/KOMIKAH_.ttf"));
		var a = komika.getGlyphIndex("A".code),
			v = komika.getGlyphIndex("V".code);
		check(a > 0 && v > 0 && komika.getGlyphIndex(0x4E00) == 0, "Characters map to glyphs; one the font lacks to 0");
		check(komika.getOutline(a).length > 0
			&& komika.getOutline(komika.getGlyphIndex(" ".code)).length == 0, "A letter has an outline, a space none");
		var h = komika.getGlyphIndex("H".code);
		check(komika.getKerning(a, v) < 0 && komika.getKerning(h, h) == 0, "GPOS kerning closes AV and leaves HH");
		var baked = helix.font.FontBaker.bake(komika, [for (c in 32...127) c], 32, 6, 512);
		var fits = true;
		for (g in baked.glyphs)
			fits = fits && g.x + g.width <= baked.width && g.y + g.height < baked.height;
		check(fits
			&& baked.field.get(baked.width * baked.height - 1) == 255, "Glyphs fit the atlas above its free row; the white texel is set");
		check(Math.abs(baked.ascent - baked.descent - 32) < 1e-9, "The baked height is ascent to descent");
		var font = helix.font.Font.fromTrueType(sys.io.File.getBytes("examples/assets/fonts/Komika/KOMIKAH_.ttf"), gpu);
		check(font.getGlyph(0xE9) != null && font.getGlyph(0x7F) == null && font.getKerning("A".code, "V".code) < 0,
			"A loaded font has Latin-1 and kerning in font pixels");
		check(font.measure("AV", 32) < font.measure("A", 32) + font.measure("V", 32), "Kerning narrows a measured pair");
		var cff = false;
		try
			new helix.font.TrueType(Bytes.ofString("OTTO and twelve"))
		catch (e:Dynamic)
			cff = true;
		check(cff, "A file that isn't TrueType is refused");
		// A screen effect's parameters land at their std140 offsets: a float, a vec3 at 16, a vec4 array's second element at 48, a mat4's second
		// column at 96 + 16; the framework's block 1 holds the frame's size and the time; an unset texture is drawn as the frame.
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
				},
				{
					slot: 2,
					stage: "fragment",
					size: 160,
					glslName: "params",
					vec4s: 10,
					name: "params",
					members: [
						{
							name: "strength",
							type: "float",
							offset: 0,
							count: 1
						},
						{
							name: "shift",
							type: "vec3",
							offset: 16,
							count: 1
						},
						{
							name: "weights",
							type: "vec4",
							offset: 32,
							count: 3
						},
						{
							name: "grade",
							type: "mat4",
							offset: 96,
							count: 1
						}
					]
				}
			],
			textures: [
				{
					slot: 0,
					stage: "fragment",
					name: "helix_screen_texture",
					glslName: "a"
				},
				{
					slot: 1,
					stage: "fragment",
					name: "noise_texture",
					glslName: "b"
				}
			]
		});
		var shader = helix.graphics.Shader.fromText(text, gpu),
			effect = new helix.graphics.ScreenEffect(shader, false, gpu);
		check(effect.parameters.setFloat("strength", .5)
			&& effect.parameters.setValues("shift", [1, 2, 3])
			&& effect.parameters.setValues("weights", [0, 0, 0, 0, 7])
			&& effect.parameters.setValues("grade", [0, 0, 0, 0, 9]),
			"Parameters are set by name");
		check(!effect.parameters.setFloat("missing", 1)
			&& !effect.parameters.setValues("strength", [1, 2])
			&& !effect.parameters.setTexture("helix_screen_texture", texture),
			"Unknown parameters, too many values and the framework's texture are refused");
		effect.drawPass(texture, 640, 480, 2.5);
		var block = gpu.screen.uniforms[2], info = gpu.screen.uniforms[1];
		check(block.getFloat(0) == .5 && block.getFloat(16) == 1 && block.getFloat(24) == 3 && block.getFloat(48) == 7 && block.getFloat(112) == 9,
			"Values land at their std140 offsets");
		check(info.getFloat(0) == 640 && info.getFloat(4) == 480 && info.getFloat(8) == 2.5, "Block 1 holds the frame's size and the time");
		check(gpu.screen.textures.length == 2 && gpu.screen.textures[1] == texture.handle, "An unset texture is drawn as the frame");
		var other = helix.graphics.Shader.fromText(StringTools.replace(text, '"screen"', '"surface"'), gpu);
		var refused = false;
		try
			new helix.graphics.ScreenEffect(other, false, gpu)
		catch (e:Dynamic)
			refused = true;
		check(refused, "A shader of another kind isn't a screen effect");
		// A mirrored model (a negative scale) draws through another pipeline than an ordinary one: its front faces wind the other way.
		var stage3D = new helix.render3d.Renderer3D(gpu),
			cube = helix.render3d.Mesh3D.cube(1, 1, 1),
			material = new helix.render3d.Material3D();
		var plain = new Model3D(cube, material),
			mirrored = new Model3D(cube, material);
		plain.setPosition(-2, 0, 0);
		mirrored.setPosition(2, 0, 0);
		mirrored.setScale(-1, 1, 1);
		stage3D.add(plain);
		stage3D.add(mirrored);
		var view = new helix.render3d.Camera3D();
		view.setViewport(400, 300);
		gpu.meshPipelines = [];
		stage3D.draw(view);
		check(stage3D.drawCallCount == 2 && gpu.meshPipelines.length == 2 && gpu.meshPipelines[0] != gpu.meshPipelines[1],
			"A mirrored model is its own run, through another pipeline");
		// Sprites: opaque ones draw before the see-through phase, blended ones after them, added ones last, each phase through its own pipeline;
		// sprites of one texture in a phase are one draw.
		var spriteTexture = Texture2D.fromRgba(1, 1, Bytes.alloc(4), gpu);
		var modes:Array<helix.graphics.AlphaMode> = [Add, Blend, Opaque, Blend, Add];
		for (mode in modes) {
			var s3 = new Sprite3D(spriteTexture);
			s3.setAlphaMode(mode);
			stage3D.add(s3);
		}
		gpu.meshPipelines = [];
		stage3D.draw(view);
		var p = gpu.meshPipelines;
		// Two models (plain and mirrored), then the sprites' three phases.
		check(p.length == 5 && p[2] != p[3] && p[3] != p[4] && p[2] != p[4] && stage3D.drawnNodeCount == 7,
			"Sprites draw opaque, then blended, then added, each phase a draw through its own pipeline");
		stage3D.destroy();
		// Textures: loads of one file and filter share one texture (one fetch, one decode, even while under way); a load given up leaves the
		// others theirs; another filter is another texture; the last release frees it.
		var heldAssets = new HeldAssets(),
			images = new WhiteImages(),
			decoding = new helix.graphics.ImageDecoding(images),
			shared = new helix.texture.TextureCache(heldAssets, decoding, gpu);
		var got:Array<Texture2D> = [];
		shared.load("a.png", true, texture -> got.push(texture));
		var given = shared.load("a.png", true, texture -> got.push(texture));
		shared.load("a.png", true, texture -> got.push(texture));
		given.cancel();
		heldAssets.flush();
		decoding.poll();
		check(heldAssets.loads == 1 && images.decodes == 1 && got.length == 2 && got[0] == got[1], "Loads under way of one file share one fetch and texture");
		shared.load("a.png", true, texture -> got.push(texture));
		check(heldAssets.loads == 1 && got.length == 3 && got[2] == got[0], "A later load of it is given the same texture");
		shared.load("a.png", false, texture -> got.push(texture));
		heldAssets.flush();
		decoding.poll();
		check(heldAssets.loads == 2 && got.length == 4 && got[3] != got[0], "Another filter is another texture");
		var destroyed = gpu.destroyedTextures;
		shared.release(got[0]);
		shared.release(got[0]);
		check(gpu.destroyedTextures == destroyed, "A texture still held isn't freed");
		shared.release(got[0]);
		check(gpu.destroyedTextures == destroyed + 1, "The last release frees it");
		batch.destroy();
		pick2D();
		clipping();
		sliceAndWrap();
		rounded();
		unsizedCamera();
		// A batch with room for a few vertices grows to a frame's need: every rectangle uploaded, into a GPU buffer as big.
		var growing = new CountingGraphics(),
			small = new Batch2D(growing, 6),
			view = new Camera2D();
		view.setViewport(400, 300);
		growing.beginFrame(400, 300, 0);
		small.begin(view);
		for (i in 0...1000)
			small.rect(i % 40, Std.int(i / 40), 1, 1, 0xffffffff);
		small.end();
		var biggest = 0, fits = true;
		for (handle => upload in growing.uploads) {
			biggest = upload.length > biggest ? upload.length : biggest;
			fits = fits && growing.bufferBytes.exists(handle) && upload.length <= growing.bufferBytes[handle];
		}
		check(biggest == 6000 * Sprite2DProgram.stride
			&& fits, "A frame past a batch's room grows it: all 6000 vertices, in a buffer that holds them");

		// Decals: a pool of sprites, the oldest put down again once full (last in the draw order), those next to be taken up faded.
		var decals = new helix.render2d.Decals2D(Texture2D.fromRgba(1, 1, Bytes.alloc(4), new CountingGraphics()), 3);
		check(decals.fadeCount == 0, "A quarter of 3 fades: none");
		decals.fadeCount = 1;
		var first = decals.place(10, 20, .5, 8);
		decals.place(0, 0);
		check(decals.count == 2 && !first.pickable && near(first.x, 10) && near(first.y, 20) && near(first.rotation, .5) && near(first.width, 8),
			"Placed where given, turned and sized, never picked");
		check(first.tint == 0xffffffff, "Unfaded while a place is free");
		decals.place(0, 0);
		check(first.tint == 0x80ffffff, "Full: the next to go fades");
		var again = decals.place(1, 1);
		check(again == first && decals.count == 3 && decals.childCount == 3 && decals.getChild(2) == first && near(first.width, 1),
			"Past full, the oldest put down again on top, its texture's size by default");
		decals.clear();
		check(decals.count == 0 && decals.childCount == 0, "Cleared");

		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}

	// Rounded rectangles: drawn as fans and bands, picked by their rounded shape, filled or outlined.
	static function rounded():Void {
		var gpu = new CountingGraphics(),
			batch = new Batch2D(gpu),
			stage = new Renderer2D(),
			camera = new Camera2D();
		camera.setViewport(400, 300);
		camera.pixels(1);
		var clamped = Shape2D.rectangle(5, 5);
		clamped.cornerRadius = -1;
		clamped.outline = -2;
		check(clamped.cornerRadius == 0 && clamped.outline == 0 && Shape2D.circle(-3).radius == 0, "A radius or outline below 0 is 0");
		var card = Shape2D.rectangle(100, 60);
		card.cornerRadius = 20;
		card.setPosition(100, 100);
		stage.add(card);
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		var roundedVertices = gpu.draws[0].vertices;
		check(stage.pick(camera, 102, 102) == null && stage.pick(camera, 120, 102) == card && stage.pick(camera, 150, 130) == card,
			"A rounded rectangle is picked by its shape: not in a corner cut off");
		card.cornerRadius = 100;
		check(stage.pick(camera, 101, 130) == card
			&& stage.pick(camera, 105, 105) == null, "A radius past half the shorter side is half of it");
		card.cornerRadius = 20;
		card.outline = 4;
		check(stage.pick(camera, 100, 130) == card
			&& stage.pick(camera, 150, 130) == null
			&& stage.pick(camera, 106, 106) == card
			&& stage.pick(camera, 102, 102) == null,
			"Outlined, it's the stroke along its rounded edge");
		card.outline = 0;
		card.cornerRadius = 0;
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		check(gpu.draws[0].vertices == 6 && roundedVertices > 6 && roundedVertices % 3 == 0, "Square, two triangles; rounded, a fan of them");
		batch.destroy();
	}

	// Picking a Renderer2D: the topmost node under a point, by each kind's own area, through the camera, honouring the flags.
	static function pick2D():Void {
		var gpu = new CountingGraphics(),
			batch = new Batch2D(gpu),
			stage = new Renderer2D(),
			camera = new Camera2D();
		camera.setViewport(400, 300);
		// World units as screen pixels, from the top-left, as a HUD's.
		camera.pixels(1);
		var box = Shape2D.rectangle(100, 100), disc = Shape2D.circle(30);
		box.setPosition(100, 100);
		disc.setPosition(150, 150);
		stage.add(box);
		stage.add(disc);
		var label = new Text2D("HELLO", 20);
		check(!label.pickable && Shape2D.rectangle(1, 1).pickable, "Text isn't pickable until asked; shapes are");
		label.pickable = true;
		label.setPosition(250, 50);
		stage.add(label);
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		check(stage.pick(camera, 160, 160) == disc
			&& stage.pick(camera, 105, 105) == box, "The topmost under the point: the disc over the box");
		check(stage.pick(camera, 300, 250) == null && stage.pick(camera, -1, -1) == null, "Nothing, and off the viewport nothing");
		check(stage.pick(camera, 260, 60) == label && stage.pick(camera, 260, 75) == null, "Text by its block");
		disc.pickable = false;
		check(stage.pick(camera, 160, 160) == box, "Unpickable: the box under it");
		disc.pickable = true;
		disc.visible = false;
		check(stage.pick(camera, 160, 160) == box, "Hidden isn't hit: the box under it");
		disc.visible = true;
		// A ring: its stroke, not its middle.
		var ring = Shape2D.circle(40);
		ring.outline = 4;
		ring.setPosition(300, 200);
		stage.add(ring);
		check(stage.pick(camera, 342, 200) == ring && stage.pick(camera, 300, 200) == null, "An outlined circle is its stroke");
		var slash = Shape2D.line(0, 0, 50, 50);
		slash.setPosition(20, 220);
		stage.add(slash);
		check(stage.pick(camera, 45, 245) == slash && stage.pick(camera, 60, 230) == null, "A line by its stroke");
		var wedge = Shape2D.polygon([0., 0, 60, 0, 0, 60]);
		wedge.setPosition(330, 10);
		stage.add(wedge);
		check(stage.pick(camera, 340, 20) == wedge && stage.pick(camera, 385, 65) == null, "A filled polygon by its inside");
		// Turned a quarter (y down: clockwise on screen), a tall thin rectangle lies down, its length reaching left from its corner.
		var bar = Shape2D.rectangle(10, 80);
		bar.setPosition(200, 200);
		bar.rotation = Math.PI / 2;
		stage.add(bar);
		check(stage.pick(camera, 150, 205) == bar && stage.pick(camera, 205, 250) != bar, "A turned rectangle where it's turned to, not where it was");
		// Through a zoomed camera: screen points are the camera's.
		camera.zoom = 2;
		var at = [camera.worldToScreenX(150), camera.worldToScreenY(150)];
		check(stage.pick(camera, at[0], at[1]) == disc, "Through a zoomed camera");
		camera.pixels(1);
		box.visible = false;
		check(stage.pick(camera, 105, 105) == null, "A hidden node isn't hit");
		box.visible = true;
		box.pickable = false;
		check(stage.pick(camera, 105, 105) == null, "An unpickable one isn't");
		box.pickable = true;
		box.paused = true;
		check(stage.pick(camera, 105, 105) == box, "A paused one is");
		box.paused = false;
		box.alpha = 0;
		check(stage.pick(camera, 105, 105) == box, "A transparent one is");
		box.alpha = 1;
		// A hit area: a bare group picked by it, never drawn; a node by it in place of its drawing; a group's flags reach its children.
		var spot = new Node2D();
		spot.setPosition(300, 250);
		spot.hitArea = HitArea2D.rectangle(0, 0, 20, 10);
		stage.add(spot);
		check(stage.pick(camera, 310, 255) == spot && stage.pick(camera, 310, 265) == null, "A group by its rectangle");
		spot.hitArea = HitArea2D.circle(0, 0, 5);
		check(stage.pick(camera, 303, 253) == spot && stage.pick(camera, 305, 255) == null, "By a circle");
		box.hitArea = HitArea2D.rectangle(0, 0, 2, 2);
		check(stage.pick(camera, 105, 105) == null, "In place of what it draws");
		box.hitArea = null;
		var dot = Shape2D.circle(2);
		dot.setPosition(10, 0);
		spot.addChild(dot);
		check(stage.pick(camera, 310, 250) == dot, "A child over its group's area");
		spot.pickable = false;
		check(stage.pick(camera, 310, 250) == null
			&& stage.pick(camera, 303, 253) == null, "An unpickable group takes its children with it");
	}

	// Clips: a batch's nested clips as scissors (bottom-left, within the outer one), and a Renderer2D node clipping its children, drawn and picked.
	static function clipping():Void {
		var gpu = new CountingGraphics(),
			batch = new Batch2D(gpu),
			camera = new Camera2D();
		camera.setViewport(400, 300);
		camera.pixels(1);
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		batch.rect(0, 0, 10, 10, -1);
		batch.pushClip(50, 40, 100, 100);
		batch.rect(0, 0, 400, 300, -1);
		batch.pushClip(120, 0, 100, 100);
		batch.rect(0, 0, 400, 300, -1);
		batch.popClip();
		batch.popClip();
		batch.rect(0, 0, 10, 10, -1);
		batch.end();
		var s = gpu.scissors;
		check(s.length == 3 && s[0].join(",") == "50,160,100,100" && s[1].join(",") == "120,200,30,60" && s[2] == null,
			"Nested clips: the outer, then within it, as the GPU's bottom-left rectangles; reset after: " + s.map(x -> x == null ? "-" : x.join(","))
			.join(" "));
		// A list's window: a group clipping its rows; a row scrolled out of it is neither drawn there nor picked.
		var stage = new Renderer2D(), list = new Node2D();
		list.setPosition(20, 20);
		check(list.setClip(100, 50) && list.clipping && !list.setClip(-1, 5), "A clip, and a size below 0 refused");
		var inside = Shape2D.rectangle(100, 20),
			outside = Shape2D.rectangle(100, 20);
		outside.setPosition(0, 60);
		list.addChild(inside);
		list.addChild(outside);
		stage.add(list);
		gpu.scissors = [];
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		check(gpu.scissors.length >= 1 && gpu.scissors[0].join(",") == "20,230,100,50", "The group's window as the scissor");
		check(stage.pick(camera, 30, 30) == inside && stage.pick(camera, 30, 85) == null, "A row out of the window isn't picked");
		list.clearClip();
		check(stage.pick(camera, 30, 85) == outside, "Without the clip it is");
	}

	// Nine-slice frames and wrapped text.
	static function sliceAndWrap():Void {
		var gpu = new CountingGraphics(),
			batch = new Batch2D(gpu),
			camera = new Camera2D();
		camera.setViewport(400, 300);
		camera.pixels(1);
		var font = batch.font;
		check(font.measure(" ", 16) > 0, "A space has a width (wgrender-c's caa49dd)");
		var lines = font.wrap("the quick brown fox jumps over the lazy dog", 16, 100);
		check(lines.length > 1
			&& [for (l in lines) if (font.measure(l, 16) > 100) l].length == 0
			&& lines.join(" ") == "the quick brown fox jumps over the lazy dog",
			"Wrapped at spaces, no line wider than the width, nothing lost: "
			+ lines.join("|"));
		var long = font.wrap("abcdefghijklmnopqrstuvwxyz", 16, 60);
		check(long.length > 1
			&& long.join("") == "abcdefghijklmnopqrstuvwxyz"
			&& [for (l in long) if (font.measure(l, 16) > 60) l].length == 0,
			"A word wider than a line, broken between its letters");
		check(font.wrap("one\ntwo", 16, 1000).join("|") == "one|two", "A line break breaks");
		// Nine quads, the corners keeping their texels' size; a frame too small shrinks them alike.
		var texture = Texture2D.fromRgba(16, 16, haxe.io.Bytes.alloc(16 * 16 * 4), gpu);
		gpu.beginFrame(400, 300, 0);
		batch.begin(camera);
		batch.nineSlice(texture, 10, 10, 200, 100, 4, 4, 4, 4);
		batch.end();
		var ninth = batch.vertexCount;
		batch.begin(camera);
		batch.image(texture, 10, 10, 200, 100);
		batch.end();
		check(ninth == batch.vertexCount * 9, "Nine quads for a frame");
		var stage = new Renderer2D(), panel = new Sprite2D(texture);
		check(panel.setNineSlice(4, 4, 4, 4) && panel.nineSlice && !panel.setNineSlice(-1, 1, 1, 1) && panel.nineSliceLeft == 4,
			"Nine-slice insets of 0 or more");
		panel.setSize(200, 100);
		panel.setPivot(0, 0);
		stage.add(panel);
		var note = new Text2D("the quick brown fox jumps over the lazy dog", 16);
		check(note.setWrapWidth(100) && !note.setWrapWidth(-1) && note.wrapWidth == 100, "Wrapping to a width of 0 or more");
		note.setPosition(250, 20);
		note.pickable = true;
		stage.add(note);
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		check(stage.pick(camera, 260, 50) == note && note.heightIn(font) > 40, "A wrapped text picked by its whole block, lines below the first");
		// A pivot places a text as it does a sprite: centered on its position, or by a corner; picked and bounded where it's drawn.
		var title = new Text2D("Title", 20, 0xffffffff, font);
		title.pickable = true;
		title.setPosition(400, 300);
		var w = title.measureWidth(), box = new helix.math.Bounds2D();
		check(w > 0 && title.measureHeight() == 20, "Measured in its own font, none passed");
		title.setPivot(.5, .5);
		stage.add(title);
		@:privateAccess title.measureOwn(font, box);
		check(near(box.minX, -w / 2) && near(box.maxX, w / 2) && near(box.minY, -10) && near(box.maxY, 10), "Pivot .5, .5: its box centered on it");
		batch.begin(camera);
		stage.draw(batch, camera);
		batch.end();
		check(stage.pick(camera, 400 - w / 2 + 1, 291) == title
			&& stage.pick(camera, 400 + w / 2 + 2, 300) != title, "Picked where it's drawn");
		title.setPivot(1, 1);
		@:privateAccess title.measureOwn(font, box);
		check(near(box.minX, -w) && near(box.maxX, 0) && near(box.minY, -20) && near(box.maxY, 0), "Pivot 1, 1: its bottom right on it");
	}
}
