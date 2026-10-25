package helix.render2d;

import helix.graphics.IGraphics;
import helix.host.Presentation;
import helix.font.Font;

/** The stage: the one thing the runner draws, after the app's update, every frame (docs/DISPLAY_MODEL.md). Its children are display objects
	(Node2D and its kinds, and views: View2D, View3D), drawn in order, later over earlier, through a camera showing the app's design units
	(Screen: logical pixels unless a presentation mode says otherwise), cleared to its color first; every 3D view is drawn under the 2D. Flash's stage: what a game adds to it shows, with nothing to draw by
	hand. Installed by its first use (Stage), so a program that never uses it carries none of it. */
@:build(helix.macro.Facade.record())
@:noCompletion
class StageService {
	var gpu:IGraphics;
	var presentation:Presentation;
	var tree = new Renderer2D();
	var batch:Null<Batch2D>;
	// The last frame's: its 3D views' shadows and its views with a chain, drawn before the next frame opens.
	var shadows:Array<Void->Void> = [];
	var renders:Array<(IGraphics, Float) -> Void> = [];
	var chain:Null<ViewFrame.ChainCalls>;

	// The program's stage, made at its first use and drawn by the runner each frame (an optional part, helix.host.Part).

	@:allow(helix.render2d.Stage)
	static function install():StageService {
		return helix.host.Host.installPart(runner -> {
			var service = new StageService(helix.graphics.Graphics.instance, helix.host.Screen.instance);
			runner.install({
				draw: () -> service.draw(service.heldTime != null ? service.heldTime : helix.time.Time.clock.time),
				shutdown: () -> {
					service.destroy();
					Stage.bind(null);
				}
			});
			service;
		});
	}

	/** A stage drawn on gpu, its camera showing presentation's design units. */
	public function new(gpu:IGraphics, presentation:Presentation) {
		this.gpu = gpu;
		this.presentation = presentation;
	}

	/** What the frame is cleared to before the stage draws, 0xAARRGGBB (Flash's stage.color). Black to start. */
	public var color:Int = 0xff000000;

	/** The time the stage and its views draw at when set (emitters, sprite and screen effects, water), held there: an autopilot's samples,
		the same on every target. Null, to start, for the game's clock (Time.clock). */
	public var heldTime:Null<Float> = null;

	/** Screen effects over everything the stage draws (helix.graphics.PostProcess: bloom, a vignette, a color grade), or null for none: the
		stage is drawn into its scene, then the chain runs and is presented on the screen. In an HDR chain (an effect wanting HDR) the 3D
		views draw their light untone-mapped into it and the chain's tone mapping (Neutral, unless the chain has its own) brings it to the
		screen. */
	public var postProcess(default, set):Null<helix.graphics.PostProcess>;

	function set_postProcess(value:Null<helix.graphics.PostProcess>):Null<helix.graphics.PostProcess> {
		chain = ViewFrame.callsOf(value);
		return postProcess = value;
	}

	/** Puts node on the stage over what's there (its last child), taking it from any parent it had; a child of the stage already moves to
		the top, as Flash's addChild does (Node2D.addChild). */
	public function addChild(node:Node2D):Void
		tree.add(node);

	/** Puts node on the stage at index in drawing order (0 is drawn first, under the rest), as Node2D.addChildAt does: a level made after
		the HUD put under it. An index past the end, or -1, puts it over everything, as addChild. */
	public function addChildAt(node:Node2D, index:Int):Void
		tree.root.addChildAt(node, index);

	/** Puts node on the stage over what's there without it moving on screen: its world transform is kept (Node2D.addChildInPlace), a
		node taken from a moving group left where it is. False, changing nothing, for a node whose place can't be kept (scaled to nothing). */
	public function addChildInPlace(node:Node2D):Bool
		return tree.root.addChildInPlace(node);

	/** Its child at index, in drawing order; null past the end. */
	public function getChild(index:Int):Null<Node2D>
		return tree.root.getChild(index);

	/** Whether node is on the stage: one of its children or anywhere below one. Null is on nothing. */
	public function contains(node:Null<helix.scene.Node>):Bool
		return node != null && node != tree.root && tree.root.contains(node);

	/** node's index among the stage's children, in drawing order (0 is drawn first), or -1 when it isn't one of them. */
	public function getChildIndex(node:Node2D):Int
		return tree.root.getChildIndex(node);

	/** Takes the stage's child at index (in drawing order) off it and returns it, or null past the end, changing nothing. */
	public function removeChildAt(index:Int):Null<Node2D>
		return tree.root.removeChildAt(index);

	/** The first node named name on the stage (depth first, in drawing order), as kind, or null when there's none or it isn't a kind:
		`var score = Stage.find("score", Text2D);` (Node.find). */
	public function find<T:Node2D>(name:String, kind:Class<T>):Null<T>
		return tree.root.find(name, kind);

	/** Takes node off the stage. False, changing nothing, for a node that isn't one of its children. */
	public function removeChild(node:Node2D):Bool
		return tree.remove(node);

	/** The camera the stage is drawn through: the presentation's design units (Screen), refitted at each draw. */
	public var camera(default, null):Camera2D = new Camera2D();

	/** The font a text without its own is drawn in: the stage batch's (the built-in one), there from the stage's first use, so text can be
		measured and laid out before the first frame. */
	public var font(get, never):Font;

	function get_font():Font {
		if (batch == null)
			batch = new Batch2D(gpu);
		return batch.font;
	}

	/** How many children the stage has. */
	public var childCount(get, never):Int;

	function get_childCount():Int
		return tree.root.childCount;

	/** How many vertices the last frame's 2D took (Batch2D.vertexCount). */
	public var vertexCount(get, never):Int;

	function get_vertexCount():Int
		return batch == null ? 0 : batch.vertexCount;

	/** How many draws the last frame's 2D took (Batch2D.drawCallCount). */
	public var drawCallCount(get, never):Int;

	function get_drawCallCount():Int
		return batch == null ? 0 : batch.drawCallCount;

	/** How many nodes the last frame drew on the stage itself (a view's own count says what it drew), the ones outside the view skipped. */
	public var drawnNodeCount(get, never):Int;

	function get_drawnNodeCount():Int
		return tree.drawnNodeCount;

	/** Returns the topmost node under a framebuffer pixel.

		2D nodes are tested before 3D nodes. Nodes under a `View2D` count as 2D. A node whose `visible` or `pickable` is false is skipped
		together with its subtree, and the test continues to the nodes behind it. Paused nodes and nodes with an alpha of 0 are picked. The
		test uses the positions from the last frame drawn.

		@param x  The x coordinate, in framebuffer pixels from the left.
		@param y  The y coordinate, in framebuffer pixels from the top.
		@param hit  Optional. When a 3D node is picked, receives the hit (a `helix.render3d.PickHit3D`).
		@return  The node, or null if there is none. */
	public function pick(x:Float, y:Float, ?hit:Any):Null<helix.scene.Node> {
		ViewFrame.picks3D.resize(0);
		var found = tree.pick(camera, x, y);
		if (found != null)
			return found;
		var i = ViewFrame.picks3D.length;
		while (i-- > 0) {
			var node = ViewFrame.picks3D[i](x, y, hit);
			if (node != null)
				return node;
		}
		return null;
	}

	/** Draws the frame: opens it, cleared to color, draws the stage's children through the presentation's camera, and closes it (through
		postProcess, when it has one: into its scene, then its effects presented on the screen). The runner
		calls it once a frame after the app's update, with the game's clock in seconds (Time.clock: emitters advance by it, still while it's
		paused); a program without one (a
		test) calls it itself. */
	public function draw(time:Float):Void {
		if (batch == null)
			batch = new Batch2D(gpu);
		presentation.apply(camera);
		tree.time = time;
		// The 3D views the last frame reached draw their shadows before this one opens, as any pass into a texture must.
		for (draw in shadows)
			draw();
		// The views with a chain the last frame reached, drawn into their textures, as any pass into a texture must be, before the frame.
		ViewFrame.renders.resize(0);
		for (render in renders)
			render(gpu, time);
		var width = presentation.framebufferWidth,
			height = presentation.framebufferHeight;
		if (chain != null) {
			chain.begin(width, height, color);
			ViewFrame.hdr = chain.hdr();
		} else
			gpu.beginFrame(width, height, color);
		batch.begin(camera);
		ViewFrame.drawsUnder.resize(0);
		ViewFrame.shadows.resize(0);
		tree.draw(batch, camera);
		renders = ViewFrame.renders.copy();
		shadows = ViewFrame.shadows.copy();
		// The 3D views the walk reached, drawn now: under every 2D thing, which the batch sends as it ends.
		for (draw in ViewFrame.drawsUnder)
			draw();
		batch.end();
		if (chain != null) {
			chain.end(time);
			ViewFrame.hdr = false;
			gpu.beginFrame(width, height, 0xff000000);
			chain.present();
		}
		gpu.endFrame();
	}

	/** Frees its batch. */
	public function destroy():Void {
		if (batch != null)
			batch.destroy();
		batch = null;
	}
}
