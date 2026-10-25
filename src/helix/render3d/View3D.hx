package helix.render3d;

import helix.graphics.IGraphics;
import helix.render2d.Batch2D;
import helix.render2d.Camera2D;
import helix.texture.Texture2D;
import helix.render2d.View;
import helix.render2d.ViewFrame;
import helix.scene.Node;
import helix.render2d.Stage;
import helix.math.Point2D;

/** A 3D tree shown through a camera (docs/DISPLAY_MODEL.md): a display object, placed on the stage or in a 2D tree, showing content's
	children through camera in its rectangle (View). It holds the photography: the camera, the exposure and the tone mapping; the light is the place's (Node3D.environment), unless
	the view's own environment overrides it. Drawn under
	every 2D thing in the frame, as Flash's Stage3D content was under its display list: the 2D batch sends its draws once, at the frame's
	end. With a postProcess chain (View.postProcess) it's drawn into a texture instead and placed in the 2D's order like any 2D thing, so 2D
	drawn before it is under it. The view sizes the camera's viewport to its rectangle as it draws. Several views can show one tree (split screen); each draws it
	for itself. */
class View3D extends View {
	var gpu:Null<IGraphics>;
	var world:Null<Renderer3D>;
	// Its rectangle in framebuffer pixels, as the walk gave it.
	var areaX = 0;
	var areaY = 0;
	var areaWidth = 1;
	var areaHeight = 1;
	var framebufferWidth = 1;
	var framebufferHeight = 1;
	var time = 0.;

	/** A view of content's children through camera (a new one unless given), width x height of its own units (0 for the whole area of what
		shows it), drawn on gpu (the program's, Graphics.instance, unless given). */
	public function new(content:Node3D, ?camera:Camera3D, width = 0., height = 0., ?gpu:IGraphics) {
		super(width, height);
		this.content = content;
		this.camera = camera == null ? new Camera3D() : camera;
		this.gpu = gpu;
	}

	/** The tree whose children it shows. */
	public var content(default, null):Node3D;

	/** What it's seen through: its eye, projection and lens the app's, its viewport the view's rectangle. */
	public var camera:Camera3D;

	/** The light it shows its tree in, overriding the tree's (Node3D.environment), or null for the tree's own: a minimap's flat light, an
		editor's preview. */
	public var environment:Null<Environment3D>;

	/** How lit color comes into the screen's 0..1 after the exposure (Khronos PBR Neutral to start). */
	public var tonemap:Tonemap = Tonemap.Neutral;

	/** The exposure in stops (EV): each one doubles the light before the tone mapping; 0 to start. An exposure that isn't finite is 0. */
	public var exposure(default, set):Float = 0.;

	function set_exposure(value:Float):Float {
		exposure = Math.isFinite(value) ? value : 0;
		return exposure;
	}

	/** How many models the last frame drew, the ones outside the camera's view culled. */
	public var drawnNodeCount(get, never):Int;

	function get_drawnNodeCount():Int
		return world == null ? 0 : world.drawnNodeCount;

	/** How many draws the last frame took for its tree. */
	public var drawCallCount(get, never):Int;

	function get_drawCallCount():Int
		return world == null ? 0 : world.drawCallCount;

	/** How many models cast into the shadow maps the last frame. */
	public var shadowCasterCount(get, never):Int;

	function get_shadowCasterCount():Int
		return world == null ? 0 : world.shadowCasterCount;

	/** How many draws the last frame's shadow maps took. */
	public var shadowDrawCallCount(get, never):Int;

	function get_shadowDrawCallCount():Int
		return world == null ? 0 : world.shadowDrawCallCount;

	override function getContent():Node
		return content;

	// Deferred: drawn under the 2D before the batch ends (drawDeferred), in the rectangle the walk gave.
	override function show(batch:Batch2D, outer:Camera2D, x:Int, y:Int, w:Int, h:Int, time:Float):Void {
		areaX = x;
		areaY = y;
		areaWidth = w;
		areaHeight = h;
		framebufferWidth = outer.framebufferWidth;
		framebufferHeight = outer.framebufferHeight;
		this.time = time;
		ViewFrame.drawsUnder.push(() -> drawDeferred());
		ViewFrame.shadows.push(() -> prepare());
	}

	/** The ray from its camera's eye through the stage point x, y (the stage's units, as a game holds the pointer: Screen.toUnitsX of its
		pixels), into out (a new one when not given), returned, as the view was last drawn: with Ray3D.hitHeight and pointAt, where on the
		ground a click landed. Null for a point outside where it's shown, or before its first draw. Given out, it allocates nothing. */
	public function computeRay(x:Float, y:Float, ?out:Ray3D):Null<Ray3D> {
		var px = Stage.camera.worldToScreenX(x),
			py = Stage.camera.worldToScreenY(y);
		// With a chain its camera's viewport is its texture: the point carried into it.
		if (postProcess != null) {
			px -= shownX;
			py -= shownY;
		}
		return camera.computeRay(px, py, out);
	}

	/** What ray meets first in its tree, as a pick sees it: the nearest model, sprite or text, into hit (a new one when not given), or null
		for nothing. The ray is in its tree's world units (Ray3D.set: the ground under a ball, `ray.set(ball.x, ball.y, ball.z, 0, -1, 0)`;
		a line of sight). The hit says the node, the distance along the ray, the point, and the surface's normal facing back along the ray.
		Models are met by their triangles as posed now, from either side; a hidden or unpickable node and what's under it are passed over,
		as Stage.pick passes them; sprites and text face as its camera shows them. Given hit, it allocates nothing. */
	public function pickAlong(ray:Ray3D, ?hit:PickHit3D):Null<PickHit3D> {
		if (world == null) {
			world = new Renderer3D(gpu, content);
			world.viewed = true;
		}
		return world.pickAlong(ray, camera, hit);
	}

	/** Where the world point x, y, z of its tree is seen, in the stage's units (where a label over a head, an arrow to something off screen
		or a 2D burst from a 3D chest goes on the stage), into out (a new one when not given), returned, as the view was last drawn; a point
		off its sides lands off them. Null for a point behind its camera. Given out, it allocates nothing. */
	public function project(x:Float, y:Float, z:Float, ?out:Point2D):Null<Point2D> {
		var seen = camera.project(x, y, z, out);
		if (seen == null)
			return null;
		var px = seen.x, py = seen.y;
		if (postProcess != null) {
			px += shownX;
			py += shownY;
		}
		return seen.set(Stage.camera.screenToWorldX(px), Stage.camera.screenToWorldY(py));
	}

	override function pickShown(x:Float, y:Float):Null<helix.render2d.Node2D> {
		ViewFrame.picks3D.push((x, y, hit) -> pick3D(x, y, hit));
		return null;
	}

	override function pick3D(x:Float, y:Float, hit:Any):Null<Node> {
		if (world == null)
			return null;
		// With a chain its camera's viewport is its texture: the point carried into it.
		if (postProcess != null) {
			x -= shownX;
			y -= shownY;
		}
		var found = world.pick(camera, x, y, (hit : PickHit3D));
		return found == null ? null : found.node;
	}

	override function drawInto(gpu:IGraphics, w:Int, h:Int, hdr:Bool, time:Float):Void {
		if (world == null) {
			world = new Renderer3D(this.gpu != null ? this.gpu : gpu, content);
			world.viewed = true;
		}
		world.viewEnvironment = environment;
		camera.setViewport(w, h);
		world.tonemap = tonemap;
		world.exposure = exposure;
		world.hdr = hdr;
		world.time = time;
		world.draw(camera);
	}

	override function prepare():Void
		if (world != null)
			world.drawShadows(camera);

	override function drawDeferred():Void {
		if (world == null) {
			world = new Renderer3D(gpu, content);
			world.viewed = true;
		}
		world.viewEnvironment = environment;
		camera.setViewport(framebufferWidth, framebufferHeight);
		camera.setViewportArea(areaX, areaY, areaWidth, areaHeight);
		world.tonemap = tonemap;
		world.exposure = exposure;
		world.hdr = ViewFrame.hdr;
		world.time = time;
		world.draw(camera);
	}

	/** Draws its tree through its camera into target (a Texture2D.renderTarget with depth), cleared to clearColor (0xAARRGGBB): a picture
		taken when asked (a tile's portrait, an inventory icon), not each frame. Its shadows are drawn first. Outside a frame only: in init or
		update, before the runner opens the frame. */
	public function drawToTexture(target:Texture2D, clearColor = 0x00000000):Void {
		var gpu = this.gpu != null ? this.gpu : helix.graphics.Graphics.instance;
		if (world == null) {
			world = new Renderer3D(gpu, content);
			world.viewed = true;
		}
		world.viewEnvironment = environment;
		camera.setViewport(target.width, target.height);
		world.tonemap = tonemap;
		world.exposure = exposure;
		world.hdr = false;
		world.drawShadows(camera);
		gpu.beginTargetPass(target.handle, helix.graphics.Color.getRed(clearColor) / 255, helix.graphics.Color.getGreen(clearColor) / 255,
			helix.graphics.Color.getBlue(clearColor) / 255, helix.graphics.Color.getAlpha(clearColor) / 255);
		world.draw(camera);
		gpu.endTargetPass();
	}

	override public function destroy():Void {
		super.destroy();
		if (world != null)
			world.destroy();
		world = null;
	}
}
