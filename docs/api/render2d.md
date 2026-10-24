# helix.render2d

[Back to the index](README.md)

## Align2D

*abstract* in [`src/helix/render2d/Align2D.hx`](../../src/helix/render2d/Align2D.hx), `import helix.render2d.Align2D;`

Which point of a line of text its x names: its left edge, center or right edge.

- `Align2D.Left`: x is the text's left edge.
- `Align2D.Center`: x is the text's center.
- `Align2D.Right`: x is the text's right edge.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## AnimationDirection2D

*abstract* in [`src/helix/render2d/AnimationDirection2D.hx`](../../src/helix/render2d/AnimationDirection2D.hx), `import helix.render2d.AnimationDirection2D;`

Which way a SpriteAnimation2D plays through its frames (Aseprite's tag directions).

- `AnimationDirection2D.Forward`: First to last.
- `AnimationDirection2D.Reverse`: Last to first.
- `AnimationDirection2D.PingPong`: First to last and back, the ends shown once a turn.
- `AnimationDirection2D.PingPongReverse`: Last to first and back, the ends shown once a turn.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Camera2D

*class* in [`src/helix/render2d/Camera2D.hx`](../../src/helix/render2d/Camera2D.hx), `import helix.render2d.Camera2D;`

A 2D view: the world point at the viewport's center and how many pixels a world unit covers (across and down alike, but under a Presentation that stretches). Y grows downward. The viewport is the whole framebuffer, or an area of it (setViewportArea). A camera never sized (setViewport) is the whole framebuffer as it is at each use: a Batch2D beginning with it, fit and pixels size it to Screen's framebuffer then (the window's, refitted by the runner before each frame), so it follows a resize; one the app sized keeps its size.

```haxe
function new()
var sized(default, null):Bool
var x(default, null):Float
var y(default, null):Float
function setPosition(x:Float, y:Float):Void
var zoom(default, set):Float
var zoomY(default, set):Float
var framebufferWidth(default, null):Int
var framebufferHeight(default, null):Int
var viewportX(default, null):Int
var viewportY(default, null):Int
var viewportWidth(default, null):Int
var viewportHeight(default, null):Int
function setViewport(width:Int, height:Int):Void
function setViewportArea(x:Int, y:Int, width:Int, height:Int):Bool
function fit(left:Float, top:Float, width:Float, height:Float):Bool
function pixels(scale:Float):Bool
function screenToWorldX(px:Float):Float
function screenToWorldY(py:Float):Float
function worldToScreenX(wx:Float):Float
function worldToScreenY(wy:Float):Float
function clipX(wx:Float):Float
function clipY(wy:Float):Float
```

- `new`: A camera at world 0, 0, zoom 1, unsized: the whole framebuffer once used under a runner, a 1 x 1 viewport until then.
- `sized`: Whether setViewport or setViewportArea sized it. Unsized, it takes the framebuffer's size at each use (the class doc).
- `x`: The world X at the viewport's center.
- `y`: The world Y at the viewport's center.
- `setPosition`: Puts the world point x, y at the viewport's center.
- `zoom`: Framebuffer pixels per world unit across; assigning it sets the zoom down too (zoomY). At least 1e-6 (0 or less, or NaN, is 1e-6).
- `zoomY`: Framebuffer pixels per world unit down: zoom's, unless assigned apart after it (a stretched view: Presentation's Stretch). At least 1e-6 (0 or less, or NaN, is 1e-6).
- `framebufferWidth`: The framebuffer width in pixels, from setViewport.
- `framebufferHeight`: The framebuffer height in pixels, from setViewport.
- `viewportX`: The viewport's left edge in framebuffer pixels from the framebuffer's left.
- `viewportY`: The viewport's top edge in framebuffer pixels from the framebuffer's top.
- `viewportWidth`: The viewport width in framebuffer pixels.
- `viewportHeight`: The viewport height in framebuffer pixels.
- `setViewport`: The framebuffer it draws to, width x height pixels, all of it the viewport; a size under 1 clamps to 1. From then on it's sized: it keeps this size rather than the framebuffer's.
- `setViewportArea`: Narrows the viewport to an area of the framebuffer last given to setViewport: x, y is its top-left in framebuffer pixels from the framebuffer's top-left. The next setViewport takes the whole framebuffer again. False, changing nothing, for a width or height under 1 or an area not inside the framebuffer.
- `fit`: Show a world rectangle whole and centered; the longer screen side shows extra world (an unsized camera takes the framebuffer first). False for a width or height of 0 or less.
- `pixels`: World units are logical pixels from the viewport's top-left: scale is the pixel ratio (framebuffer pixels per logical pixel); an unsized camera takes the framebuffer first. False for a scale of 0 or less.
- `screenToWorldX`: The world X under framebuffer pixel X px, from the framebuffer's left edge.
- `screenToWorldY`: The world Y under framebuffer pixel Y py, from the framebuffer's top edge.
- `worldToScreenX`: The framebuffer pixel X, from the framebuffer's left edge, of world X wx.
- `worldToScreenY`: The framebuffer pixel Y, from the framebuffer's top edge, of world Y wy.
- `clipX`: Clip-space X (-1 left to 1 right) of world X wx.
- `clipY`: Clip-space Y (1 top to -1 bottom) of world Y wy; the flip makes world Y grow downward.

## CameraFollow2D

*class* in [`src/helix/render2d/CameraFollow2D.hx`](../../src/helix/render2d/CameraFollow2D.hx), `import helix.render2d.CameraFollow2D;`

A 2D camera following a target: the target moves freely inside a dead zone around the view's center, the view catching up smoothly (at the same speed at any frame rate) when it leaves, kept inside the world's bounds; and shaken (shake), a trauma that decays, the view thrown about by the square of it. update follows, apply places a camera there. Follow where the target is drawn (between simulation ticks, where it's interpolated), not where it's simulated, or the view jitters against it. The shake is the view's only, never the game's: its random numbers are its own.

```haxe
function new(?x:Float = 0., ?y:Float = 0., ?seed:Int = 1)
var x(default, null):Float
var y(default, null):Float
var smoothing:Float
var shakeDistance:Float
var shakeRecovery:Float
var shakeFrequency:Float
var trauma(default, null):Float
var shakeX(default, null):Float
var shakeY(default, null):Float
function setDeadZone(width:Float, height:Float):Bool
function setBounds(left:Float, top:Float, right:Float, bottom:Float):Bool
function clearBounds():Void
function shake(amount:Float):Void
function snap(x:Float, y:Float):Void
function update(targetX:Float, targetY:Float, dt:Float, camera:Camera2D):Void
function apply(camera:Camera2D):Void
```

- `new`: A follow at x, y (the view's center, world units) with no dead zone and no bounds; seed seeds its shake.
- `x`: The point followed to, before the shake: the view's center in world units.
- `y`: The point followed to, before the shake: the view's center in world units.
- `smoothing`: How quickly the view catches up with the target when it leaves the dead zone: the rate of Interpolate.damp, per second (about a fifth of the way left after 1.6 / rate seconds). 0 or less catches up at once.
- `shakeDistance`: How far the view is thrown at full trauma, as a share of the height it shows (0.04: 24 pixels of a 600-pixel view), so a shake looks the same in a world of pixels or of tiles.
- `shakeRecovery`: How much trauma it loses a second: 1 settles a full shake in a second.
- `shakeFrequency`: How many times a second the shake changes direction.
- `trauma`: The shake's trauma, 0 (still) to 1, falling by shakeRecovery a second; the view is thrown by its square, so small shakes are gentle.
- `shakeX`: Where the shake throws the view now, across, in world units.
- `shakeY`: Where the shake throws the view now, down, in world units.
- `setDeadZone`: The target moves freely within width x height world units around the view's center (0, 0: none, the view always catching up). False, changing nothing, for a size below 0.
- `setBounds`: Keeps the view inside the world from left, top to right, bottom (world units): it stops at their edges, centered on a world smaller than it. False, changing nothing, for an empty world.
- `clearBounds`: Lets the view go anywhere.
- `shake`: Adds amount to the trauma (held to 1): 0.3 a bump, 1 an explosion.
- `snap`: Puts the view's center at x, y at once (a respawn, a new level), within its bounds at the next update.
- `update`: Follows the target at targetX, targetY (world units) for dt seconds, seeing as much as camera shows (its viewport at its zoom), and advances the shake.
- `apply`: Places camera at the followed point, thrown by the shake.

## Decals2D

*class* in [`src/helix/render2d/Decals2D.hx`](../../src/helix/render2d/Decals2D.hx), `import helix.render2d.Decals2D;`

Marks left on the ground of a game seen from above: skid marks, footsteps, scorch marks, a target ring. A fixed pool of a texture's sprites, drawn together (alike sprites beside each other in the draw order are one draw): each place puts one down, and once the pool is full the oldest is taken up and put down again, so a trail never grows past its capacity. Given a life (lifeSeconds), each mark fades out over fadeSeconds once it has lived it, on the game's clock (a paused game's marks stay as they are), and is taken up; without one it stays until the pool comes round to it. Either way the ones next to be taken up for reuse (fadeCount) fade by how soon, so a full pool's trail thins out where it ends instead of losing a mark at a time. In its own space: add it under what walks over the marks (before them, as a child drawn first). Decals are never picked: a click passes to what's under them.

```haxe
function new(texture:Texture2D, ?capacity:Int = 64)
var texture(default, null):Texture2D
var capacity(get, never):Int
var count(get, never):Int
var size:Float
var tint:Int
var fadeCount(get, set):Int
var lifeSeconds(get, set):Float
var fadeSeconds(get, set):Float
function place(x:Float, y:Float, ?angle:Float = 0., ?size:Float = 0., ?tint:Int):Sprite2D
function clear():Void
```

- `new`: A pool of capacity (at least 1) decals of texture.
- `texture`: Their texture.
- `capacity`: How many it holds before the oldest is put down again.
- `count`: How many are down now: up to capacity.
- `size`: Each decal's size, its own units, square (place may give its own): 0 to start, for its texture's size (or its region's).
- `tint`: Their tint, 0xAARRGGBB: white (the texture as it is) to start. place may give its own.
- `fadeCount`: How many of the decals next to be taken up for reuse fade, by how soon: the next at 1 in fadeCount + 1 of its alpha (none fade while the pool has that many places free). A quarter of the capacity to start; 0 for none. Clamped to 0..capacity. Takes effect at the next place.
- `lifeSeconds`: Seconds on the game's clock each decal stays as placed before it fades out (over fadeSeconds) and is taken up: 0 (the default, and for less) for as long as the pool lets it. Applies to every decal down, as old as each is.
- `fadeSeconds`: Seconds a decal takes to fade out once it has lived its life (lifeSeconds): .5 to start; 0 (and for less) to vanish at once.
- `place`: Puts a decal down at x, y (its own space), turned angle radians (clockwise, as the stage's y is down), size across (0, the default, for the pool's size), tinted (0xAARRGGBB; null for the pool's tint), over the others. Returns its sprite, to set its region (a variant from an atlas) or effect now: it's the pool's, put down again once taken up, its region and effect cleared then.
- `clear`: Takes every decal up.

## Drawing2D

*class* in [`src/helix/render2d/Drawing2D.hx`](../../src/helix/render2d/Drawing2D.hx), `import helix.render2d.Drawing2D;`

Drawing kept on a node (docs/DISPLAY_MODEL.md): Flash's graphics, as calls named as Batch2D's (rect, frame, roundedRect, circle, circleLines, line, polygon, polygonLines, image, drawText, drawTextWrapped), each taking its own color (0xAARRGGBB), so there is no fill to begin or end. The calls are kept in order, in the node's own units, and drawn each frame where the node is, turned, scaled and faded with it; clear takes them away. Calling clear and drawing again in update is immediate drawing, as Flash games did it. Not culled; picked by the box around what it holds.

```haxe
function new()
var callCount(get, never):Int
function clear():Void
function rect(x:Float, y:Float, w:Float, h:Float, color:Int):Void
function frame(x:Float, y:Float, w:Float, h:Float, width:Float, color:Int):Void
function roundedRect(x:Float, y:Float, w:Float, h:Float, radius:Float, color:Int):Void
function circle(x:Float, y:Float, radius:Float, color:Int):Void
function circleLines(x:Float, y:Float, radius:Float, width:Float, color:Int):Void
function line(x0:Float, y0:Float, x1:Float, y1:Float, width:Float, color:Int):Void
function polygon(points:Array<Float>, color:Int):Bool
function polygonLines(points:Array<Float>, width:Float, color:Int):Bool
function image(texture:Texture2D, x:Float, y:Float, w:Float, h:Float, ?tint:Int = 0xffffffff, ?sourceX:Float = 0., ?sourceY:Float = 0., ?sourceWidth:Float = 0., ?sourceHeight:Float = 0., ?sampling:Sampling):Void
function drawTextWrapped(text:String, x:Float, y:Float, size:Float, width:Float, color:Int, ?align:Align2D = Left, ?lineHeight:Float = 1.25, ?font:Font):Float
function drawText(text:String, x:Float, y:Float, size:Float, color:Int, ?align:Align2D = Left, ?font:Font):Void
```

- `new`: A drawing holding nothing yet.
- `callCount`: How many calls it holds.
- `clear`: Takes everything drawn away.
- `rect`: A filled rectangle, top-left at x, y, w x h.
- `frame`: A rectangle's outline drawn inside its bounds, width wide.
- `roundedRect`: A filled rectangle with corners of radius (clamped to half the shorter side).
- `circle`: A filled circle centered on x, y.
- `circleLines`: A circle's outline width wide, drawn inside the circle of radius around x, y (from radius - width out to radius).
- `line`: A segment width wide from x0, y0 to x1, y1, square ended.
- `polygon`: A filled polygon through points (x and y in turn, copied; at least 3 points, convex or not, not crossing itself). False, holding nothing more, for fewer than 3 points or one that can't be filled.
- `polygonLines`: A polygon's outline through points (copied), closed, width wide centered on its edges. False, holding nothing more, for fewer than 2 points.
- `image`: texture drawn top-left at x, y, w x h, tinted (white by default): its region sourceX, sourceY, sourceWidth x sourceHeight in texels, or all of it when sourceWidth or sourceHeight is 0 or less; sampled as sampling says, or as the texture's sampling is when drawn when null.
- `drawTextWrapped`: Text wrapped to width (Font.wrap), its lines lineHeight times size apart, the first's top at y, each placed by align at x, in font (null for the batch's, the stage's font). Returns the height its lines take, as Batch2D's does, for placing what follows (one line's when no font is known: none given and no stage running).
- `drawText`: One line of text, its top at y and x its left edge, center or right edge by align, size tall, in font (null for the batch's).

## HitArea2D

*class* in [`src/helix/render2d/HitArea2D.hx`](../../src/helix/render2d/HitArea2D.hx), `import helix.render2d.HitArea2D;`

The shape a node is picked by in place of what it draws (Node2D.hitArea), in the node's own units, moving, turning and scaling with it; never drawn. For something clicked but not seen (a hotspot over a painting: a bare Node2D with one), a target easier to tap than its image, or one tighter than it.

```haxe
static function rectangle(x:Float, y:Float, width:Float, height:Float):HitArea2D
static function circle(x:Float, y:Float, radius:Float):HitArea2D
function contains(x:Float, y:Float):Bool
```

- `rectangle`: A rectangle width x height, its top-left at x, y (below 0 is 0), as Shape2D.rectangle places one.
- `circle`: A circle of radius (below 0 is 0) centered on x, y, as Shape2D.circle places one.
- `contains`: Whether its node's own point x, y is inside it, edges included.

## Node2D

*class* in [`src/helix/render2d/Node2D.hx`](../../src/helix/render2d/Node2D.hx), `import helix.render2d.Node2D;`

What a Renderer2D holds: a transform in a tree, with children of its own kind. A bare one is a group: it draws nothing, only a transform for its children (an empty in Blender, a dummy in 3ds Max, a null in Cinema 4D), a handle that moves or hides a set of things together, or a pivot to turn them about. The framework's kinds are its classes (Sprite2D, Shape2D, Text2D, Particles2D), each holding only its own data; a game never subclasses one, and game state lives elsewhere, the node its view (docs/DECISIONS.md, 61 and 130). Its transform is a position, a rotation in radians (clockwise on screen, y growing down) and a scale, relative to its parent; its world transform is worked out when a stage draws it, only after it or a node above it changed. Any node can clip its children (setClip).

```haxe
function new()
var alpha(default, set):Float
var hitArea:Null<HitArea2D>
var effect:Null<SpriteEffect>
var parent(get, set):Null<Node2D>
function getChild(index:Int):Null<Node2D>
function addChild(child:Node2D):Bool
function addChildAt(child:Node2D, index:Int):Bool
function addChildInPlace(child:Node2D):Bool
function removeChildAt(index:Int):Null<Node2D>
function removeChild(child:Node2D):Bool
function computeBounds(?relativeTo:Node2D, ?out:Bounds2D):Null<Bounds2D>
var clipping(get, never):Bool
var clipWidth(default, null):Float
var clipHeight(default, null):Float
function setClip(width:Float, height:Float):Bool
function clearClip():Void
var x(get, set):Float
var y(get, set):Float
function setPosition(x:Float, y:Float):Void
var rotation(get, set):Float
var scaleX(get, set):Float
var scaleY(get, set):Float
function setScale(x:Float, y:Float):Void
function toWorldX(x:Float, y:Float):Float
function toWorldY(x:Float, y:Float):Float
function toLocalX(x:Float, y:Float):Float
function toLocalY(x:Float, y:Float):Float
```

- `new`: A group at the origin, unturned and unscaled, with no children.
- `alpha`: How opaque it and everything under it are drawn, 0 (not seen) to 1, multiplied down the tree: fading a group fades its children, as a Flash display object's alpha did. Clamped to 0..1; 1 to start. Particles aren't faded by it. Picking doesn't follow it: a node faded to 0 is still picked (pickable = false or visible = false for one that isn't).
- `hitArea`: The shape it's picked by in place of what it draws, in its own units, never drawn; null (the default) for what it draws. A group with one is picked by it; its children are picked as ever, over it.
- `effect`: The effect its own drawing goes through (a sprite shader: helix.shader's SpriteOutline, SpriteFlash, SpriteDissolve, PaletteSwap, or an app's SpriteEffect), or null (the default) for the framework's sprite program: a sprite's quad, a shape's, a text's glyphs (their distance field as the effect reads it), a drawing's every call. Its own, not its children's; an emitter and a view draw through their own programs. An effect is shared: the nodes given one draw with its values, and those drawn one after another with one effect and texture are one draw.
- `parent`: Its parent, or null at a tree's top. Assigning a node makes this its last child as that node's addChild does, keeping this one's local transform (addChildInPlace keeps the world one); assigning null takes it from its parent as the parent's removeChild does. A node under itself or one of its own descendants is refused, leaving the tree as it was.
- `getChild`: Its child at index, in drawing order; null past the end.
- `addChild`: Makes child its last child (drawn over the others), taking it from any parent it had, keeping child's local transform: it moves with this node as it sat under its old parent (a hat onto a head joint). addChildInPlace keeps its world transform instead. False, changing nothing, for itself or one of its own ancestors.
- `addChildAt`: Makes child its child at index in drawing order (0 is drawn first, under the others; those from index on move up one), taking it from any parent it had and keeping its local transform, as addChild does; an index past the end, or -1, makes it the last. A child of this node already moves to index. False, changing nothing, for itself or one of its own ancestors.
- `addChildInPlace`: Puts child under this node without it moving: its world transform is kept and its local one recomputed from this node's (a dropped sword picked up by a hand). addChild keeps the child's local transform instead (a hat onto a head joint). A shear the two transforms make together is lost. False, changing nothing, for itself or one of its own ancestors, or this scaled to nothing.
- `removeChildAt`: Takes its child at index (in drawing order) from its children and returns it, or null past the end, changing nothing.
- `removeChild`: Takes child from its children. False when it isn't one.
- `computeBounds`: The box around it and everything under it as they are now, into out (a new one when not given), or null for nothing drawn: in its tree's world (the stage's units on the stage; inside a View2D's content, the world its camera looks at), or in relativeTo's own units when given (Flash's getBounds), as relativeTo's children are placed, to fit a panel around a group. Each sprite, shape, text, drawing and sized view counts by its own box, placed by the transforms as they are now (a draw needn't have run). A disabled or hidden node and what's under it are left out, as an emitter is; a text without a font of its own is measured in the stage's (Stage.font), and left out where there's no stage. Null too for a relativeTo scaled to nothing. relativeTo may be anywhere in the same tree, this node included. `computeBounds(scratch)` is the world into scratch: Haxe skips relativeTo for a Bounds2D. Given out, it allocates nothing.
- `clipping`: Whether its children are clipped (setClip).
- `clipWidth`: The clip's width in its own units, or -1 without one.
- `clipHeight`: The clip's height in its own units, or -1 without one.
- `setClip`: Clips its children (drawn and picked) to the rectangle width x height from its own origin, in its own units: a scrolling list's window. A turned node clips to the turned rectangle's bounds. Its own output isn't clipped. False, changing nothing, for a size below 0.
- `clearClip`: Stops clipping its children.
- `x`: Its position's x, relative to its parent.
- `y`: Its position's y, relative to its parent (down the screen).
- `setPosition`: Places it at x, y, relative to its parent.
- `rotation`: Its rotation in radians, clockwise on screen, relative to its parent.
- `scaleX`: Its scale along its own x; a negative scale mirrors it.
- `scaleY`: Its scale along its own y; a negative scale mirrors it.
- `setScale`: Scales it along its own x and y; a negative scale mirrors it.
- `toWorldX`: The world x of its own point x, y, as the last draw placed it.
- `toWorldY`: The world y of its own point x, y, as the last draw placed it.
- `toLocalX`: The x in its own units of world point x, y, as the last draw placed it; NaN when it is scaled to nothing.
- `toLocalY`: The y in its own units of world point x, y, as the last draw placed it; NaN when it is scaled to nothing.

## Particles2D

*class* in [`src/helix/render2d/Particles2D.hx`](../../src/helix/render2d/Particles2D.hx), `import helix.render2d.Particles2D;`

An emitter of particles (helix.particle.Emitter, made flat for 2D), placed here: it spawns where this node is in the world, and the stage advances it by its clock (Renderer2D.time) each draw. Its particles draw at its place in the stage's order, through the GPU, and stay where they were born, so they trail as the node moves.

```haxe
function new(emitter:Emitter)
static function explosion(size:Float):Particles2D
static function smokePuff(size:Float):Particles2D
static function sparks(size:Float):Particles2D
static function dust(size:Float):Particles2D
static function fire(size:Float):Particles2D
static function smoke(size:Float):Particles2D
static function rain(size:Float):Particles2D
static function snow(size:Float):Particles2D
static function confetti(size:Float):Particles2D
var emitter(default, null):Emitter
var removeWhenSpent:Bool
```

- `new`: emitter, placed here.
- `explosion`: A preset (helix.particle.ParticlePreset.Explosion): a burst of light outward, fading from white-yellow to red: a hit, a pop, a small explosion. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `smokePuff`: A preset (helix.particle.ParticlePreset.SmokePuff): a soft gray puff, spreading and rising a little as it fades: a landing, a vanish. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `sparks`: A preset (helix.particle.ParticlePreset.Sparks): hot sparks thrown up and out, streaked and falling: a hit on metal. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `dust`: A preset (helix.particle.ParticlePreset.Dust): a low, wide kick of dust that settles: footsteps, a landing, a skid. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `fire`: A preset (helix.particle.ParticlePreset.Fire): a steady flame, rising and fading from yellow to red: a torch, a campfire; size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `smoke`: A preset (helix.particle.ParticlePreset.Smoke): a steady column of gray smoke, rising and spreading: a chimney, a wreck; size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `rain`: A preset (helix.particle.ParticlePreset.Rain): steady rain over a width of size, falling size below the node; size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `snow`: A preset (helix.particle.ParticlePreset.Snow): steady snow over a width of size, drifting down size below the node; size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `confetti`: A preset (helix.particle.ParticlePreset.Confetti): paper of five colors thrown up, spinning and falling: a win, a level cleared. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in pixels on the stage, or the units of the 2D tree it's in. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `emitter`: Its emitter.
- `removeWhenSpent`: Whether it takes itself off its parent once its emitter is spent (Emitter.spent: a one-shot's burst died out), the frame after: true for the one-shot presets (explosion, smokePuff, sparks, dust, confetti), so a game puts one down and forgets it; false otherwise.

## Polygon2D

*class* in [`src/helix/render2d/Polygon2D.hx`](../../src/helix/render2d/Polygon2D.hx), `import helix.render2d.Polygon2D;`

Simple polygons as points, x and y in turn: filled by triangulating them (convex or not), outlined by mitered strips.

```haxe
static function doubleArea(points:Array<Float>):Float
static function triangulate(points:Array<Float>):Array<Int>
```

- `doubleArea`: Twice the signed area of the polygon through points: above 0 when its points go clockwise on screen (y down).
- `triangulate`: The triangles filling the simple polygon through points (at least 3, not crossing itself), as indices of points, three a triangle, by ear clipping; either winding. A polygon that crosses itself is filled as far as clipping gets.

## Shape2D

*class* in [`src/helix/render2d/Shape2D.hx`](../../src/helix/render2d/Shape2D.hx), `import helix.render2d.Shape2D;`

A flat shape in a color (0xAARRGGBB), filled or outlined: a rectangle (its corners square or rounded), a circle, a line or a polygon, made by the static constructors, as they differ only in their geometry (form says which). Each form reads the values it uses: a rectangle its size, pivot and corner radius, a circle its radius, a line and a polygon their points; the others' are kept but not drawn.

```haxe
static function rectangle(width:Float, height:Float, ?color:Int = 0xffffffff):Shape2D
static function circle(radius:Float, ?color:Int = 0xffffffff):Shape2D
static function line(x0:Float, y0:Float, x1:Float, y1:Float, ?color:Int = 0xffffffff):Shape2D
static function polygon(points:Array<Float>, ?color:Int = 0xffffffff):Null<Shape2D>
var form(default, null):ShapeForm2D
var color:Int
var shading:ShapeShading2D
var endColor:Int
var width(get, never):Float
var height(get, never):Float
function setSize(width:Float, height:Float):Void
function setPivot(x:Float, y:Float):Void
var pivotX(default, null):Float
var pivotY(default, null):Float
var radius(get, set):Float
var cornerRadius(get, set):Float
var outline(get, set):Float
var points(get, never):Array<Float>
function setPoints(value:Array<Float>):Bool
```

- `rectangle`: A filled rectangle width x height (below 0 is 0), its top-left at its position (pivot 0, 0).
- `circle`: A filled circle of radius (below 0 is 0), centered on its position.
- `line`: A line from x0, y0 to x1, y1 in its own units, as wide as its outline (1 to start).
- `polygon`: A filled polygon through points in its own units (x and y in turn, copied; at least 3 points, convex or not, not crossing itself). Null for fewer than 3 points or an odd count.
- `form`: Which shape it is.
- `color`: Its color, 0xAARRGGBB: a shaded rectangle's at its start (its left edge, or its top).
- `shading`: How a filled rectangle is colored: Flat in color (the start), or shaded from color to endColor across or down it, each channel linearly (alpha too, so a ramp to the same color at alpha 0 fades it out). An outlined rectangle and the other forms are drawn flat.
- `endColor`: The color a shaded rectangle reaches at its end (its right edge, or its bottom), 0xAARRGGBB. (0xffffffff to start.)
- `width`: A rectangle's width, in its own units.
- `height`: A rectangle's height, in its own units.
- `setSize`: Sizes a rectangle, in its own units; below 0 is 0.
- `setPivot`: Sets the point of a rectangle at its position, which it turns and scales about, as a fraction of its size: 0, 0 its top-left (the start), 1, 1 its bottom-right.
- `pivotX`: A rectangle's pivot's x fraction.
- `pivotY`: A rectangle's pivot's y fraction.
- `radius`: A circle's radius, in its own units. At least 0 (below 0, or NaN, is 0).
- `cornerRadius`: A rectangle's corners' radius, in its own units, 0 for square (the start): drawn at most half its shorter side; outlined, the outline's middle follows the corners; picked by its rounded shape. At least 0 (below 0, or NaN, is 0).
- `outline`: Its outline's width, in its own units, centered on its edge: 0 draws a rectangle, circle or polygon filled (the start), and is a line's width (1 to start; 0 draws nothing). At least 0 (below 0, or NaN, is 0).
- `points`: A polygon's points or a line's ends, x and y in turn (a copy); empty for a rectangle or circle.
- `setPoints`: Gives a polygon new points (as polygon() takes them, copied) or a line new ends (4 floats). False, changing nothing, for a rectangle or circle or a wrong count.

## ShapeForm2D

*abstract* in [`src/helix/render2d/ShapeForm2D.hx`](../../src/helix/render2d/ShapeForm2D.hx), `import helix.render2d.ShapeForm2D;`

Which shape a Shape2D is.

- `ShapeForm2D.Rectangle`: A rectangle, filled or outlined, its corners square or rounded.
- `ShapeForm2D.Circle`: A circle, filled or outlined.
- `ShapeForm2D.Line`: A line segment.
- `ShapeForm2D.Polygon`: A polygon, filled or outlined.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## ShapeShading2D

*abstract* in [`src/helix/render2d/ShapeShading2D.hx`](../../src/helix/render2d/ShapeShading2D.hx), `import helix.render2d.ShapeShading2D;`

How a filled rectangle is colored.

- `ShapeShading2D.Flat`: In its color alone.
- `ShapeShading2D.Across`: From its color at its left edge to its endColor at its right.
- `ShapeShading2D.Down`: From its color at its top to its endColor at its bottom.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Sprite2D

*class* in [`src/helix/render2d/Sprite2D.hx`](../../src/helix/render2d/Sprite2D.hx), `import helix.render2d.Sprite2D;`

A sprite: a texture (or a region of it, or a SpriteSheet2D's frame) drawn as a rectangle, its region's size in texels unless sized, its pivot at its position (its center by default), tinted (0xAARRGGBB). Its scale scales it and its rotation turns it, about its pivot; a nine-slice frame keeps its corners' size as it's sized (setNineSlice). It may draw through an effect (effect).

```haxe
function new(texture:Null<Texture2D>, ?tint:Int = 0xffffffff)
var texture:Null<Texture2D>
var tint:Int
var sampling:Null<Sampling>
function setRegion(x:Float, y:Float, width:Float, height:Float):Void
function setFrame(sheet:SpriteSheet2D, index:Int):Bool
var frame(default, null):Null<SpriteFrame2D>
var regionX(get, never):Float
var regionY(get, never):Float
var regionWidth(get, never):Float
var regionHeight(get, never):Float
var width(get, never):Float
var height(get, never):Float
function setSize(width:Float, height:Float):Void
function setPivot(x:Float, y:Float):Void
var pivotX(default, null):Float
var pivotY(default, null):Float
function setNineSlice(left:Float, top:Float, right:Float, bottom:Float):Bool
var nineSliceLeft(get, never):Float
var nineSliceTop(get, never):Float
var nineSliceRight(get, never):Float
var nineSliceBottom(get, never):Float
var nineSlice(get, never):Bool
```

- `new`: A sprite of texture (null for none yet: it draws nothing), the whole texture at its size in texels, turning about its center, tinted (0xAARRGGBB, white for none).
- `texture`: Its texture, or null: it draws nothing.
- `tint`: What its texels are multiplied by, 0xAARRGGBB: white leaves them as they are.
- `sampling`: How its texture is sampled, in place of the texture's own (Texture2D.sampling), or null for the texture's: the same texture drawn sharp here and smooth elsewhere.
- `setRegion`: Its region of its texture, in texels from its top-left; a width or height of 0 or less (the default) shows the whole texture. It shows no sheet's frame after (setFrame).
- `setFrame`: Shows sheet's frame at index (a SpriteAnimator2D given the sprite shows its frames so): its texture becomes the sheet's, its size the frame's whole picture (unless sized), its pivot the frame's when its file gives one. A trimmed frame draws where it was in its picture, a rotated one upright; a frame draws whole, not as a nine-slice. False, changing nothing, for an index the sheet hasn't.
- `frame`: The sheet's frame it shows (setFrame), or null: it shows its region.
- `regionX`: Its region's left, in texels.
- `regionY`: Its region's top, in texels.
- `regionWidth`: Its region's width in texels: its frame's whole picture's when it shows one, else what was set, or else its texture's (0 without one).
- `regionHeight`: Its region's height in texels: its frame's whole picture's when it shows one, else what was set, or else its texture's (0 without one).
- `width`: The width it draws at, in its own units: as sized, else its region's in texels.
- `height`: The height it draws at, in its own units: as sized, else its region's in texels.
- `setSize`: Sizes it, in its own units; a width or height of 0 or less goes back to its region's size.
- `setPivot`: Sets the point at its position, which it turns and scales about, as a fraction of its size: 0, 0 its top-left, 1, 1 its bottom-right (0.5, 0.5, its center, by default).
- `pivotX`: Its pivot's x fraction.
- `pivotY`: Its pivot's y fraction.
- `setNineSlice`: Draws it as a nine-slice frame (Batch2D.nineSlice): its region's corners left, top, right and bottom texels in from its edges keep their size as it's sized, its edges and middle stretch. All 0 (the start) draws it stretched whole. False, changing nothing, for an inset below 0.
- `nineSliceLeft`: Its nine-slice's left inset, texels.
- `nineSliceTop`: Its nine-slice's top inset, texels.
- `nineSliceRight`: Its nine-slice's right inset, texels.
- `nineSliceBottom`: Its nine-slice's bottom inset, texels.
- `nineSlice`: Whether it draws as a nine-slice frame.

## SpriteAnimation2D

*class* in [`src/helix/render2d/SpriteAnimation2D.hx`](../../src/helix/render2d/SpriteAnimation2D.hx), `import helix.render2d.SpriteAnimation2D;`

A named run of a SpriteSheet2D's frames, played by a SpriteAnimator2D: an Aseprite tag, or frames whose names differ only by a number. Each frame shows for its own duration.

```haxe
function new(name:String, frames:Array<Int>, direction:AnimationDirection2D)
final name:String
final frames:Array<Int>
final direction:AnimationDirection2D
```

- `new`: An animation named name over the sheet's frames, played in direction.
- `name`: Its name: the tag's, or the frames' names without their numbers ("run_01.png" -> "run").
- `frames`: The sheet's frames it shows, by index, in order.
- `direction`: Which way it plays through them.

## SpriteAnimator2D

*class* in [`src/helix/render2d/SpriteAnimator2D.hx`](../../src/helix/render2d/SpriteAnimator2D.hx), `import helix.render2d.SpriteAnimator2D;`

Plays a SpriteSheet2D's animations: which frame shows, each for its own duration, in its animation's direction, looping or once. Call update once a frame; frame is the sheet's frame to draw (Batch2D.sheetFrame), and a sprite given to it shows that frame itself. entered says which of the animation's frames the last update reached, a footstep's sound on the frame its foot lands.

```haxe
function new(sheet:SpriteSheet2D, ?sprite:Sprite2D)
var sheet(default, null):SpriteSheet2D
var sprite:Null<Sprite2D>
var speed(default, set):Float
var animation(get, never):Null<SpriteAnimation2D>
var frame(get, never):Int
var frameIndex(get, never):Int
var finished(get, never):Bool
function play(name:String, ?loop:Bool = true):Bool
function stop():Void
function entered(index:Int):Bool
function update(seconds:Float):Void
```

- `new`: Plays sheet's animations, showing each frame on sprite as it changes when one is given.
- `sheet`: The sheet it plays.
- `sprite`: The sprite showing its frame, or null.
- `speed`: How fast time runs: 1 as the sheet's durations say, 2 twice as fast, 0 held. Below 0, or not finite, is taken as 0.
- `animation`: The animation playing (or finished and holding its last frame), or null.
- `frame`: The sheet's frame showing, by index (SpriteSheet2D.getFrame), or -1 with no animation.
- `frameIndex`: The frame showing by its place in the animation (0 its first), or -1 with no animation.
- `finished`: Whether an animation played once has reached its end (it holds its last frame); false while one loops, or with none.
- `play`: Plays the sheet's animation named name from its start, looping or once; playing the one already playing (not finished) goes on where it is, looping as now asked. False, changing nothing, for a name the sheet hasn't.
- `stop`: Stops: no animation, no frame (a sprite keeps the frame it shows).
- `entered`: Whether the last update (or the play that started it) reached the animation's frame at index (its place in the animation, 0 its first), though a long update may have passed it already.
- `update`: Advances time by seconds (times speed): the frames whose durations it passes go by, an animation played once stops on its last.

## SpriteFrame2D

*class* in [`src/helix/render2d/SpriteFrame2D.hx`](../../src/helix/render2d/SpriteFrame2D.hx), `import helix.render2d.SpriteFrame2D;`

One frame of a SpriteSheet2D: where it is in the sheet's texture and how it is drawn. A trimmed frame (its transparent edges cut off when packed) keeps its place in the whole picture: its texels are drawn offsetX, offsetY in from the top-left of a sourceWidth x sourceHeight box. A rotated frame was packed turned a quarter turn clockwise; it is drawn upright.

```haxe
function new(name:String, x:Int, y:Int, width:Int, height:Int, rotated:Bool, offsetX:Int, offsetY:Int, sourceWidth:Int, sourceHeight:Int, pivotX:Float, pivotY:Float, duration:Float)
final name:String
final x:Int
final y:Int
final width:Int
final height:Int
final rotated:Bool
final offsetX:Int
final offsetY:Int
final sourceWidth:Int
final sourceHeight:Int
final pivotX:Float
final pivotY:Float
final duration:Float
var hasPivot(get, never):Bool
```

- `new`: A frame named name, its texels at x, y in the texture, width x height drawn upright (packed turned when rotated), offsetX, offsetY in from the top-left of a sourceWidth x sourceHeight picture, its pivot pivotX, pivotY (NaN for none), shown for duration seconds.
- `name`: Its name in the sheet's file (a file name as packed: "run_01.png"), or its number in a grid.
- `x`: Its texels' left in the texture, in texels.
- `y`: Its texels' top in the texture, in texels.
- `width`: Its texels' width as drawn (upright): in the texture, a rotated frame's height.
- `height`: Its texels' height as drawn (upright): in the texture, a rotated frame's width.
- `rotated`: Whether it was packed turned a quarter turn clockwise (TexturePacker's rotation).
- `offsetX`: How far its texels are from the left of the whole picture: what trimming cut off its left (0 untrimmed).
- `offsetY`: How far its texels are from the top of the whole picture: what trimming cut off its top (0 untrimmed).
- `sourceWidth`: The whole picture's width before trimming, in texels: the size it draws at.
- `sourceHeight`: The whole picture's height before trimming, in texels.
- `pivotX`: Its pivot as a fraction of the whole picture (0 its left, 1 its right), when its file gives one (TexturePacker's pivot), else NaN.
- `pivotY`: Its pivot as a fraction of the whole picture (0 its top, 1 its bottom), when its file gives one, else NaN.
- `duration`: How long it shows when its animation plays, in seconds.
- `hasPivot`: Whether its file gives it a pivot.

## SpriteSheet2D

*class* in [`src/helix/render2d/SpriteSheet2D.hx`](../../src/helix/render2d/SpriteSheet2D.hx), `import helix.render2d.SpriteSheet2D;`

A texture holding many pictures (an atlas), with where each one is (its frames) and the runs of them that animate (its animations). Read from the JSON TexturePacker and Aseprite write (their "JSON Hash" and "JSON Array" layouts: trimmed and rotated frames, pivots, Aseprite's tags and frame durations), or cut from a grid of equal cells. Without tags, frames whose names differ only by a number make an animation ("run_01.png", "run_02.png": "run"). A Sprite2D shows a frame (Sprite2D.setFrame), a Batch2D draws one (Batch2D.sheetFrame), a SpriteAnimator2D plays them.

```haxe
static function parse(texture:Texture2D, text:String, ?secondsPerFrame:Float = .1):SpriteSheet2D
static function grid(texture:Texture2D, frameWidth:Int, frameHeight:Int, ?count:Int = 0, ?secondsPerFrame:Float = .1, ?margin:Int = 0, ?spacing:Int = 0):SpriteSheet2D
static function load(path:String, loaded:SpriteSheet2D -> Void, ?failed:String -> Void, ?linear:Bool = false, ?secondsPerFrame:Float = .1):IRequest
var texture(default, null):Texture2D
var reloadCount(default, null):Int
var frameCount(get, never):Int
function getFrame(index:Int):Null<SpriteFrame2D>
function findFrame(name:String):Int
var animationNames(get, never):Array<String>
function findAnimation(name:String):Null<SpriteAnimation2D>
function addAnimation(name:String, frames:Array<Int>, ?direction:AnimationDirection2D = Forward):Bool
function destroy():Void
function reloaded(path:String, bytes:haxe.io.Bytes):Void
```

- `parse`: A sheet over texture from a TexturePacker or Aseprite JSON file's text; a frame without its own duration shows for secondsPerFrame. Throws, saying why, for text it can't read.
- `grid`: A sheet over texture cut into cells of frameWidth x frameHeight texels, left to right then down, margin texels in from its edges and spacing texels apart: count of them (every whole cell for 0), named by number from "0", each shown for secondsPerFrame. It has no animations until given them (addAnimation).
- `load`: Loads a TexturePacker or Aseprite JSON file at path and the image it names (its meta.image, beside it), sampled smoothly when linear, else sharp for pixel art (TextureCache.load); a frame without its own duration shows for secondsPerFrame. The file reads again in place when it changes during development, as the image does. One of loaded or failed runs once (failed, else the log, for a file that doesn't load or read, or an image that doesn't), neither once the request is cancelled. destroy frees what it loaded.
- `texture`: Its texture.
- `reloadCount`: How many times its file has been read again (a hot reload): an animator playing it finds its animation again by name.
- `frameCount`: How many frames it has.
- `getFrame`: Its frame at index (0 up to frameCount), or null.
- `findFrame`: The index of its frame named name (as its file names it: "run_01.png"), or -1.
- `animationNames`: Its animations' names, in the order its file gives them.
- `findAnimation`: Its animation named name, or null.
- `addAnimation`: Adds an animation named name over its frames by index, played in direction, in place of one of that name. False, changing nothing, for no frames or an index it hasn't.
- `destroy`: Frees what load loaded (its texture through Textures) and stops reading its file again; a sheet made from a texture leaves the texture to its maker.
- `reloaded`: Its file changed: its frames and animations are read again (its image reloads on its own). A file that doesn't read leaves it as it was, and throws.

## Stage

*class* in [`src/helix/render2d/Stage.hx`](../../src/helix/render2d/Stage.hx), `import helix.render2d.Stage;`

The stage: what the program shows, drawn by the runner after every update (StageService; docs/DISPLAY_MODEL.md). Installed by its first use, so a program that never uses it carries none of it. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from StageService's public members with their doc comments.

```haxe
static function find(name:String, kind:Class<T>):Null<T>
static var color(get, set):Int
static var heldTime(get, set):Null<Float>
static var postProcess(get, set):Null<PostProcess>
static function addChild(node:Node2D):Void
static function addChildAt(node:Node2D, index:Int):Void
static function addChildInPlace(node:Node2D):Bool
static function getChild(index:Int):Null<Node2D>
static function contains(node:Null<Node>):Bool
static function getChildIndex(node:Node2D):Int
static function removeChildAt(index:Int):Null<Node2D>
static function removeChild(node:Node2D):Bool
static var camera(get, never):Camera2D
static var font(get, never):Font
static var childCount(get, never):Int
static var vertexCount(get, never):Int
static var drawCallCount(get, never):Int
static var drawnNodeCount(get, never):Int
static function pick(x:Float, y:Float, ?hit:Any):Null<Node>
```

- `find`: The first node named name on the stage (depth first, in drawing order), as kind, or null when there's none or it isn't a kind: `var score = Stage.find("score", Text2D);` (Node.find).
- `color`: What the frame is cleared to before the stage draws, 0xAARRGGBB (Flash's stage.color). Black to start.
- `heldTime`: The time the stage and its views draw at when set (emitters, sprite and screen effects, water), held there: an autopilot's samples, the same on every target. Null, to start, for the game's clock (Time.clock).
- `postProcess`: Screen effects over everything the stage draws (helix.graphics.PostProcess: bloom, a vignette, a color grade), or null for none: the stage is drawn into its scene, then the chain runs and is presented on the screen. In an HDR chain (an effect wanting HDR) the 3D views draw their light untone-mapped into it and the chain's tone mapping (Neutral, unless the chain has its own) brings it to the screen.
- `addChild`: Puts node on the stage over what's there (its last child), taking it from any parent it had; a child of the stage already moves to the top, as Flash's addChild does (Node2D.addChild).
- `addChildAt`: Puts node on the stage at index in drawing order (0 is drawn first, under the rest), as Node2D.addChildAt does: a level made after the HUD put under it. An index past the end, or -1, puts it over everything, as addChild.
- `addChildInPlace`: Puts node on the stage over what's there without it moving on screen: its world transform is kept (Node2D.addChildInPlace), a node taken from a moving group left where it is. False, changing nothing, for a node whose place can't be kept (scaled to nothing).
- `getChild`: Its child at index, in drawing order; null past the end.
- `contains`: Whether node is on the stage: one of its children or anywhere below one. Null is on nothing.
- `getChildIndex`: node's index among the stage's children, in drawing order (0 is drawn first), or -1 when it isn't one of them.
- `removeChildAt`: Takes the stage's child at index (in drawing order) off it and returns it, or null past the end, changing nothing.
- `removeChild`: Takes node off the stage. False, changing nothing, for a node that isn't one of its children.
- `camera`: The camera the stage is drawn through: the presentation's design units (Screen), refitted at each draw.
- `font`: The font a text without its own is drawn in: the stage batch's (the built-in one), there from the stage's first use, so text can be measured and laid out before the first frame.
- `childCount`: How many children the stage has.
- `vertexCount`: How many vertices the last frame's 2D took (Batch2D.vertexCount).
- `drawCallCount`: How many draws the last frame's 2D took (Batch2D.drawCallCount).
- `drawnNodeCount`: How many nodes the last frame drew on the stage itself (a view's own count says what it drew), the ones outside the view skipped.
- `pick`: The topmost node under framebuffer pixel x, y (from the top-left, as the pointer is): a 2D node, or one a View2D shows, before anything 3D (3D draws under the 2D); else a 3D view's node under it, hit (a helix.render3d.PickHit3D, when given) filled with where. A hidden (visible false) or unpickable (pickable false) node and what's under it aren't picked, the pick going on to what's behind; a paused one is picked, and one faded to alpha 0. Null for none. As last drawn: views pick where they were shown.

## Text2D

*class* in [`src/helix/render2d/Text2D.hx`](../../src/helix/render2d/Text2D.hx), `import helix.render2d.Text2D;`

A line of text in the 2D world: its value, size units tall (ascent to descent), in a color (0xAARRGGBB) and a font (null: the drawing batch's built-in one); its position is the top of the text and, by align, its left edge, center or right edge. Wrapped to a width, it is a block of lines (setWrapWidth). Not pickable until pickable is set: a label lets the pointer through to what it's on. Batch2D.drawText draws text without a node; Font.measure measures it.

```haxe
function new(value:String, ?size:Float = 16., ?color:Int = 0xffffffff, ?align:Align2D = Left, ?font:Font)
var text:String
var textSize(get, set):Float
var color:Int
var align:Align2D
var font:Null<Font>
var wrapWidth(default, null):Float
var lineHeight(default, null):Float
function setWrapWidth(width:Float, ?lineHeight:Float = 1.25):Bool
function measureWidth(font:Font):Float
function measureHeight(font:Font):Float
```

- `new`: value, size units tall (0 or less, or NaN, is 1e-6), in color, aligned on its position by align, in font (null: the batch's built-in one).
- `text`: Its text.
- `textSize`: Its size, units tall (ascent to descent). At least 1e-6 (0 or less, or NaN, is 1e-6).
- `color`: Its color, 0xAARRGGBB.
- `align`: Which point of it its position's x is: its left edge, center or right edge.
- `font`: Its font, or null for the drawing batch's built-in one.
- `wrapWidth`: Its wrap width in its own units: 0 for one line.
- `lineHeight`: Its wrapped lines apart, times its size.
- `setWrapWidth`: Wraps it to width in its own units (Font.wrap), its lines lineHeight times its size apart; 0 for one line. False, changing nothing, for a width below 0 or a line height of 0 or less.
- `measureWidth`: Its width in its own units as drawn in font (its own, if it has one): its wrap width, or its one line's.
- `measureHeight`: Its height in its own units as drawn in font (its own, if it has one): its size, or its wrapped lines'.

## View

*class* in [`src/helix/render2d/View.hx`](../../src/helix/render2d/View.hx), `import helix.render2d.View;`

What View2D and View3D share (docs/DISPLAY_MODEL.md): a display object showing a tree of nodes through a camera, in a rectangle width x height of its own units from its position, scaled with it and not turned (a view is drawn upright; its rotation is ignored), or, with a width or height of 0, the whole area of whatever shows it (the stage's, or the view it's in). Placed like any node: on the stage, or in a tree another view shows (a minimap in a panel). A view is never drawn inside the tree it shows: one that would be (it shows a tree it's in, or one already being drawn above it) is skipped, and logged once.

```haxe
var width:Float
var height:Float
var postProcess(default, set):Null<PostProcess>
var color:Int
var texture(get, never):Null<Texture2D>
function destroy():Void
```

- `width`: Its width in its own units; 0 or less for the whole area of what shows it.
- `height`: Its height in its own units; 0 or less for the whole area of what shows it.
- `postProcess`: Screen effects over what it shows (a pixelated game under a sharp HUD, a blurred world behind a menu), or null for none. With a chain, what it shows is drawn into a texture before the frame opens, the chain run over it, and the result drawn where the view is, in the 2D's order like any 2D thing (so a 3D view with a chain sits between 2D things), a frame behind its rectangle: it's drawn at the size the view was last shown at, and nothing shows the first frame.
- `color`: With a chain, what its scene is cleared to before what it shows is drawn into it, 0xAARRGGBB: clear to start, so what's under the view shows through; a color for a background its effects work on (a bloom halo, a vignette), as the stage's color is for the stage's chain.
- `texture`: With a chain, the texture its effects' result was last drawn into, what the view shows (a material can wear it: a live label); null before its first, or without a chain.
- `destroy`: Frees what it drew with (its texture for effects, its GPU buffers); the chain and the tree are the app's.

## View2D

*class* in [`src/helix/render2d/View2D.hx`](../../src/helix/render2d/View2D.hx), `import helix.render2d.View2D;`

A 2D tree shown through a camera (docs/DISPLAY_MODEL.md): a display object, placed on the stage or in another tree, showing content's children through camera in its rectangle (View), clipped to it. The camera's position and zoom are the app's (framebuffer pixels per world unit, as a Camera2D's always are: Window.pixelRatio for logical pixels); the view sizes its viewport to the rectangle as it draws, so after a first frame the camera's viewport is the view's (what CameraFollow2D reads for its bounds). Several views can show one tree (a minimap of the world); a world's emitters advance once a frame however many show them.

```haxe
function new(content:Node2D, ?camera:Camera2D, ?width:Float = 0., ?height:Float = 0.)
var content(default, null):Node2D
var camera:Camera2D
var drawnNodeCount(get, never):Int
function destroy():Void
```

- `new`: A view of content's children through camera (a new one at world 0, 0, zoom 1 unless given), width x height of its own units (0 for the whole area of what shows it).
- `content`: The tree whose children it shows.
- `camera`: What it's seen through: its position and zoom the app's, its viewport the view's rectangle.
- `drawnNodeCount`: How many nodes the last frame drew of its tree, the ones outside the camera's view skipped.
