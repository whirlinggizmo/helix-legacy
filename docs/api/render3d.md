# helix.render3d

[Back to the index](README.md)

## AnimationClip3D

*class* in [`src/helix/render3d/AnimationClip3D.hx`](../../src/helix/render3d/AnimationClip3D.hx), `import helix.render3d.AnimationClip3D;`

A named animation: tracks moving nodes, by name, over its duration (its last key). Read from a glTF file (ModelFile3D.clips), whether or not the file has meshes: a file of animations alone plays on any skeleton with the joint names its tracks target (Animator3D). Read, never changed; shared by everything that plays it.

```haxe
function new(name:String, tracks:Array<Track3D>)
var name(default, null):String
var duration(default, null):Float
var trackCount(get, never):Int
function getTrack(index:Int):Null<Track3D>
```

- `new`: A clip named name of tracks.
- `name`: Its name: its file's (a Blender export's is the armature's and the action's, "Armature|Walk").
- `duration`: Its length in seconds: its last key's time.
- `trackCount`: How many tracks.
- `getTrack`: Track index; null past them.

## Animator3D

*class* in [`src/helix/render3d/Animator3D.hx`](../../src/helix/render3d/Animator3D.hx), `import helix.render3d.Animator3D;`

Plays AnimationClips on the nodes under a root (a character's skeleton): each track moves the node of its name at or under the root, so a clip from one file plays on a skeleton from another with the same names, and a clip naming a node the root hasn't is refused. play() crossfades from the clip before over the seconds given; a node the clips don't both move blends with its rest pose (where it was when the Animator3D first moved it). queue() plays a clip next, when the one playing ends (a one-shot back to its idle). update() advances the time and poses the nodes; a Renderer3D draws them as they're left. One clip plays at a time (layers, playing an upper body's clip over a lower body's, aren't here yet).

```haxe
function new(root:Node3D)
var clip(get, never):Null<AnimationClip3D>
var time(get, never):Float
function setTime(seconds:Float):Bool
var speed(default, set):Float
var finished(get, never):Bool
var fading(get, never):Bool
function play(clip:AnimationClip3D, ?loop:Bool = true, ?fade:Float = 0.):Bool
function queue(clip:AnimationClip3D, ?loop:Bool = true, ?fade:Float = 0.):Bool
var queued(get, never):Null<AnimationClip3D>
function stop():Void
function update(seconds:Float):Void
```

- `new`: Plays on the nodes at and under root.
- `clip`: The clip playing, or null.
- `time`: Where the clip playing is, in seconds from its start (within its duration).
- `setTime`: Moves the clip playing to seconds (wrapped into its duration when it loops, held between 0 and its end when not). False, changing nothing, with no clip playing or for a time that isn't finite.
- `speed`: How fast time runs: 1 as the clip was made, 0 held, below 0 backwards. A speed that isn't finite is taken as 0.
- `finished`: Whether a clip that doesn't loop has reached its end (false while one loops, or with none).
- `fading`: Whether a crossfade is under way.
- `play`: Plays clip from its start, looping or not, crossfading from the clip playing over fade seconds (0: at once); playing the clip already playing does nothing to it. Either way a queued clip is dropped. False, changing nothing, for a clip a track of which moves a node not at or under the root, or a fade below 0.
- `queue`: Plays clip next, as play would, once the clip playing ends: at the update a clip that doesn't loop reaches its end, crossfading from its last frame over fade seconds; at once when none is playing or the one playing has finished. A looping clip doesn't end, so a clip queued behind one waits (until the clip playing is played again not looping). One clip waits at a time, a later queue replacing it; play and stop drop it. False, changing nothing, for a clip play would refuse.
- `queued`: The clip waiting to play next (queue), or null.
- `stop`: Stops playing: the nodes stay as the last update left them, and a queued clip is dropped.
- `update`: Advances time by seconds (times the speed) and poses the nodes: call once a frame, before drawing.

## Attachment3D

*typedef* in [`src/helix/render3d/Attachment3D.hx`](../../src/helix/render3d/Attachment3D.hx), `import helix.render3d.Attachment3D;`

Where a rigid piece attaches to a skeleton (Node3D.findAttachment): the piece, and the joint it hangs from, null for none.

- `piece:Node3D`
- `joint:Null<Node3D>`

## Camera3D

*class* in [`src/helix/render3d/Camera3D.hx`](../../src/helix/render3d/Camera3D.hx), `import helix.render3d.Camera3D;`

A 3D view, perspective or orthographic (projection), as a node: it sees from its world position down its -z, its +y up (its scale ignored), so one parented to what it should follow (a car's driver's seat) rides along, and setView places it to look from an eye at a target. Right-handed with +y up, seen in a viewport that is the whole framebuffer or an area of it (setViewportArea), as Camera2D's. Drawn through by Renderer3D.draw and Batch3D.begin whether or not it is on a stage. Distances are world units; angles radians. Its values are properties that clamp (fovY, near, far, orthographicHeight, minAspect, lensShiftX and lensShiftY), each held to its range as its doc comment says.

```haxe
function new()
function setView(eyeX:Float, eyeY:Float, eyeZ:Float, targetX:Float, targetY:Float, targetZ:Float, ?upX:Float = 0., ?upY:Float = 1., ?upZ:Float = 0.):Bool
var eyeX(get, never):Float
var eyeY(get, never):Float
var eyeZ(get, never):Float
var forwardX(get, never):Float
var forwardY(get, never):Float
var forwardZ(get, never):Float
var upX(get, never):Float
var upY(get, never):Float
var upZ(get, never):Float
var projection(default, set):Projection3D
var fovY(default, set):Float
var minAspect(default, set):Float
var lensShiftX(default, set):Float
var lensShiftY(default, set):Float
var drawnFovY(get, never):Float
var drawnHeight(get, never):Float
var near(default, set):Float
var far(default, set):Float
var orthographicHeight(default, set):Float
var framebufferWidth(default, null):Int
var framebufferHeight(default, null):Int
var viewportX(default, null):Int
var viewportY(default, null):Int
var viewportWidth(default, null):Int
var viewportHeight(default, null):Int
function setViewport(width:Int, height:Int):Void
function setViewportArea(x:Int, y:Int, width:Int, height:Int):Bool
var viewProjection(get, never):Mat4
function computeRay(x:Float, y:Float, ?out:Ray3D):Null<Ray3D>
function project(x:Float, y:Float, z:Float, ?out:Point2D):Null<Point2D>
```

- `new`: A camera at 0, 0, 10 looking at the origin, +y up, perspective with a quarter turn (pi/4) of vertical view (an orthographic height of 10 kept for when projection says so), clipping at 0.1 and 1000, on a 1 x 1 viewport.
- `setView`: Places it at eye and turns it to look at target, up giving the roll: positions relative to its parent (the world's, at the top). False, changing nothing, when the eye is at the target or up is along the view.
- `eyeX`: The eye's x: its world position.
- `eyeY`: The eye's y.
- `eyeZ`: The eye's z.
- `forwardX`: Which way it looks, in the world, x: its -z, a unit vector.
- `forwardY`: Which way it looks, y.
- `forwardZ`: Which way it looks, z.
- `upX`: Its up in the world, x: its +y, a unit vector square to the view.
- `upY`: Its up, y.
- `upZ`: Its up, z.
- `projection`: Which projection draws, Perspective to start: a perspective view sees fovY, an orthographic one orthographicHeight, both kept whichever draws, with near and far either way. Perspective holds near above 0: switching to it with a near of 0 or less raises near to 1e-6, and far to 2e-6 when it was no more.
- `fovY`: The perspective view's vertical field of view in radians, pi/4 to start: held from 0.001 to pi - 0.001, a value outside landing on the nearer bound (NaN on the lower). Drawn when projection is Perspective; drawnFovY is what the viewport's shape makes of it.
- `minAspect`: The narrowest viewport shape (width / height) the view keeps its width at: on a narrower viewport its vertical view (fovY, or orthographicHeight) grows so it sees as far across as at this aspect. A scene framed for 16:9 (16 / 9) shows all its width on a phone held upright, with more above and below (Godot's keep-width; Presentation's Expand, in 3D). 0, the default, for none; 0 or more (under 0, or NaN, is 0).
- `lensShiftX`: How far right of the viewport's center the view's axis lands, in halves of the viewport's width: 0, the default, at the center; 1 at its right edge, -1 its left. A lens shift (a view camera's rise and fall): the picture slides across without turning the camera, so what it looks at sits off-center (beside a panel, say) seen square on, the view as wide as before. Any finite value; NaN or an infinity is 0.
- `lensShiftY`: How far above the viewport's center the view's axis lands, in halves of the viewport's height: 0, the default, at the center; 1 at its top edge. As lensShiftX, up and down. Any finite value; NaN or an infinity is 0.
- `drawnFovY`: The vertical field of view drawn, in radians: fovY, widened on a viewport narrower than the minimum aspect (minAspect).
- `drawnHeight`: The orthographic height drawn, in world units: orthographicHeight, taller on a viewport narrower than the minimum aspect.
- `near`: The near clip plane's distance from the eye, 0.1 to start: held below far, one at or past far (or NaN) landing 1e-6 under it; a perspective view (projection) holds it above 0 too, one of 0 or less landing on 1e-6. An orthographic view's near may be 0 or less. Set far first when the new pair lies past the old one.
- `far`: The far clip plane's distance from the eye, 1000 to start: held above near, one at or under near (or NaN) landing 1e-6 over it. Set near first when the new pair lies under the old one.
- `orthographicHeight`: The orthographic view's height in world units seen top to bottom (the width by the viewport's shape), 10 to start: held above 0, one of 0 or less (or NaN) landing on 1e-6. Drawn when projection is Orthographic; drawnHeight is what the viewport's shape makes of it.
- `framebufferWidth`: The framebuffer width in pixels, from setViewport.
- `framebufferHeight`: The framebuffer height in pixels, from setViewport.
- `viewportX`: The viewport's left edge in framebuffer pixels from the framebuffer's left.
- `viewportY`: The viewport's top edge in framebuffer pixels from the framebuffer's top.
- `viewportWidth`: The viewport width in framebuffer pixels.
- `viewportHeight`: The viewport height in framebuffer pixels.
- `setViewport`: The framebuffer it draws to, width x height pixels, all of it the viewport; a size under 1 clamps to 1.
- `setViewportArea`: Narrows the viewport to an area of the framebuffer last given to setViewport: x, y is its top-left in framebuffer pixels from the framebuffer's top-left. The next setViewport takes the whole framebuffer again. False, changing nothing, for a width or height under 1 or an area not inside the framebuffer.
- `viewProjection`: World to clip space, for the viewport's shape: the projection's matrix (its lens shift applied) * view, recomputed by each call, the view from where it is in the world now.
- `computeRay`: The ray through framebuffer pixel x, y (from the framebuffer's top-left, as the pointer is) into out (a new one when not given), returned: from the near plane, away from the camera, through the same matrices the stage draws with (perspective or orthographic, the viewport's shape). Null, leaving out as it was, for a point outside the viewport area (a pointer off the window, -1, -1, among them). Given out, it allocates nothing.
- `project`: Where the world point x, y, z is seen in the framebuffer, in pixels from its top-left (as the pointer is), into out (a new one when not given), returned: through the same matrices the stage draws with, within the camera's viewport area (a point off its sides lands off them). Null for a point behind the camera (or on its eye's plane), which no pixel shows. Given out, it allocates nothing.

## CubeMap3D

*class* in [`src/helix/render3d/CubeMap3D.hx`](../../src/helix/render3d/CubeMap3D.hx), `import helix.render3d.CubeMap3D;`

A cubemap of linear RGB floats with its mips: mips[m] holds the six faces of (size >> m) squared texels each, three floats a texel.

```haxe
function new(size:Int, mipCount:Int)
final size:Int
final mipCount:Int
final mips:Array<haxe.ds.Vector<Float>>
```

- `new`: An all-black cube of size with mipCount mips.
- `size`: Its face size at mip 0.
- `mipCount`: How many mips.
- `mips`: Each mip's texels, zero to start.

## Decals3D

*class* in [`src/helix/render3d/Decals3D.hx`](../../src/helix/render3d/Decals3D.hx), `import helix.render3d.Decals3D;`

Marks left on the ground: skid marks, footsteps, scorch marks, a target ring under a spell. A fixed pool of a texture's sprites lying flat (SpriteFacing3D.Ground), drawn in one draw: each place puts one down, and once the pool is full the oldest is taken up and put down again, so a trail never grows past its capacity. Given a life (lifeSeconds), each mark fades out over fadeSeconds once it has lived it, on the game's clock (a paused game's marks stay as they are), and is taken up; without one it stays until the pool comes round to it. Either way the ones next to be taken up for reuse (fadeCount) fade by how soon, so a full pool's trail thins out where it ends instead of losing a mark at a time. place puts one in its own space, the ground its x-z plane: place it on a level's floor. placeOn puts one on what a pick hit (a bullet hole in a wall, a scorch on a crate), on its face there and carried by its node as it moves. A decal lies flat, lifted a little (lift) off what it's put on, so it doesn't flicker into it; over an edge or a curve it shows sunk or standing off. Decals are never picked: a click passes to what's under them.

```haxe
function new(texture:Texture2D, ?capacity:Int = 64)
var texture(default, null):Texture2D
var capacity(get, never):Int
var count(get, never):Int
var size:Float
var tint:Int
var lift:Float
var fadeCount(get, set):Int
var lifeSeconds(get, set):Float
var fadeSeconds(get, set):Float
function place(x:Float, y:Float, z:Float, ?angle:Float = 0., ?size:Float = 0., ?tint:Int):Sprite3D
function placeOn(hit:PickHit3D, ?angle:Float = 0., ?size:Float = 0., ?tint:Int):Null<Sprite3D>
function clear():Void
```

- `new`: A pool of capacity (at least 1) decals of texture.
- `texture`: Their texture.
- `capacity`: How many it holds before the oldest is put down again.
- `count`: How many are down now: up to capacity.
- `size`: Each decal's size, world units, square (place may give its own): 1 to start.
- `tint`: Their tint, 0xAARRGGBB (sRGB): white (the texture as it is) to start. place may give its own.
- `lift`: How far over the ground each lies, world units: .01 to start. More if far views flicker; 0 for none.
- `fadeCount`: How many of the decals next to be taken up for reuse fade, by how soon: the next at 1 in fadeCount + 1 of its alpha (none fade while the pool has that many places free). A quarter of the capacity to start; 0 for none. Clamped to 0..capacity. Takes effect at the next place.
- `lifeSeconds`: Seconds on the game's clock each decal stays as placed before it fades out (over fadeSeconds) and is taken up: 0 (the default, and for less) for as long as the pool lets it. Applies to every decal down, as old as each is.
- `fadeSeconds`: Seconds a decal takes to fade out once it has lived its life (lifeSeconds): .5 to start; 0 (and for less) to vanish at once.
- `place`: Puts a decal down at x, y, z (its own space; y the ground's height there), turned angle radians about y (its texture's top toward -z at 0), size world units across (0, the default, for the pool's size), tinted (0xAARRGGBB; null for the pool's tint). Returns its sprite, to set its region (a variant from an atlas) or effect now: it's the pool's, put down again once taken up, its region and effect cleared then.
- `placeOn`: Puts a decal on what hit hit (a pick's: Pointer.hit3D, View3D's or Renderer3D's pick), lying on its face there (along the hit's normal, lifted lift off it), turned angle radians about the normal, size world units across as placed (0, the default, for the pool's size; whatever the node's scale), tinted (0xAARRGGBB; null for the pool's tint). It's put under the node hit, so it moves with it; on a skinned model, under the joint moving the surface there (hit.joint), so it rides the pose. Returns its sprite, as place does; null, putting nothing down, for a hit of nothing.
- `clear`: Takes every decal up.

## DirectionalLight3D

*class* in [`src/helix/render3d/DirectionalLight3D.hx`](../../src/helix/render3d/DirectionalLight3D.hx), `import helix.render3d.DirectionalLight3D;`

The sun: everything lit from one direction, its node's -z (aim it with lookAt or setRotation), wherever it is. It may cast shadows (shadowCasting), over what the camera sees out to its shadow distance.

```haxe
function new()
```

- `new`: A white directional light of intensity π shining down its -z: lit as glTF lights a surface (its diffuse its color over π), a surface facing it shows its own color, as written, before the ambient light and the tone mapping.

## Drawing3D

*class* in [`src/helix/render3d/Drawing3D.hx`](../../src/helix/render3d/Drawing3D.hx), `import helix.render3d.Drawing3D;`

3D drawing kept on a node (docs/DISPLAY_MODEL.md): Drawing2D's counterpart, as calls named as Batch3D's (line, triangle, cube, cubeWires, sphere, grid), each taking its own color (0xAARRGGBB), kept in order in the node's own units and drawn each frame where the node is, after the tree's opaque models and depth-tested against them, before what's seen through (smoke, glyphs), solid shapes shaded by Batch3D's fixed light; clear takes them away. Calling clear and drawing again in update is immediate drawing (a debug line, a path, a grid under a scene). Not lit by the tree's lights, not culled, not picked.

```haxe
function new()
var callCount(get, never):Int
function clear():Void
function line(x0:Float, y0:Float, z0:Float, x1:Float, y1:Float, z1:Float, color:Int):Void
function triangle(x0:Float, y0:Float, z0:Float, x1:Float, y1:Float, z1:Float, x2:Float, y2:Float, z2:Float, color:Int):Void
function cube(x:Float, y:Float, z:Float, width:Float, height:Float, depth:Float, color:Int):Void
function cubeWires(x:Float, y:Float, z:Float, width:Float, height:Float, depth:Float, color:Int):Void
function sphere(x:Float, y:Float, z:Float, radius:Float, color:Int, ?rings:Int = 16, ?slices:Int = 24):Void
function grid(slices:Int, spacing:Float, color:Int):Void
```

- `new`: A drawing holding nothing yet.
- `callCount`: How many calls it holds.
- `clear`: Takes everything drawn away.
- `line`: A segment between two points.
- `triangle`: A filled triangle through three points, unshaded.
- `cube`: A solid box centered on x, y, z, width x height x depth, its faces shaded.
- `cubeWires`: A box's edges, centered on x, y, z, width x height x depth.
- `sphere`: A solid sphere centered on x, y, z, shaded, of rings by slices.
- `grid`: A square grid on the ground plane (y 0), slices by slices cells of spacing, centered on the origin.

## Environment3D

*class* in [`src/helix/render3d/Environment3D.hx`](../../src/helix/render3d/Environment3D.hx), `import helix.render3d.Environment3D;`

A place's light (docs/DISPLAY_MODEL.md): the ambient light reaching everything evenly, the environment map lighting and reflecting the lit models, and the background drawn behind them. Data, set as a 3D node's environment (Node3D.environment, where a scene file's "environment" section puts it) or as a view's, which overrides what it shows (View3D.environment). How a camera photographs the place (exposure, tone mapping) is the view's, not this. Unlit to start: no ambient light, no map, no background.

```haxe
function new()
var ambientColor(default, null):Int
var ambientIntensity(default, null):Float
function setAmbient(color:Int, intensity:Float):Bool
var map(default, null):Null<EnvironmentMap3D>
var mapIntensity(default, null):Float
var rotation(default, null):Float
function setMap(map:Null<EnvironmentMap3D>, ?intensity:Float = 1., ?rotation:Float = 0.):Bool
var background(default, null):Null<EnvironmentMap3D>
var backgroundBlur(default, null):Float
function setBackground(map:Null<EnvironmentMap3D>, ?blur:Float = 0.):Bool
```

- `new`: An environment of no light: no ambient light, no map, no background.
- `ambientColor`: The ambient light's color, 0xAARRGGBB (sRGB). White to start.
- `ambientIntensity`: The ambient light's intensity, 0 or more. 0 to start.
- `setAmbient`: The light reaching everything evenly, from no direction: color 0xAARRGGBB (sRGB) times intensity. False, changing nothing, for an intensity under 0.
- `map`: The environment map lighting and reflecting the lit models (Environments3D.load), or null.
- `mapIntensity`: How strongly the map lights, and the background shows: 1 as its file has it.
- `rotation`: How far the map, and the background, turn about +y, in radians.
- `setMap`: Lights the lit models with map (null: none) as well as the lights and the ambient light: its intensity (1 as its file has it) and its turn about +y (radians), which the background shares. False, changing nothing, for an intensity under 0 or a rotation that isn't finite.
- `background`: The environment map drawn behind everything, or null.
- `backgroundBlur`: How blurred the background is: 0 sharp to 1 its blurriest.
- `setBackground`: Draws map (null: none) behind everything, at blur 0 (sharp, the image's own resolution) to 1 (blurred to a few texels), turned and as bright as setMap says. False, changing nothing, for a blur outside 0..1.

## EnvironmentBake3D

*class* in [`src/helix/render3d/EnvironmentBake3D.hx`](../../src/helix/render3d/EnvironmentBake3D.hx), `import helix.render3d.EnvironmentBake3D;`

Prepares an environment map on the CPU, a step at a time (run, under a time budget), so that it spreads over frames: from an equirectangular image (a .hdr's linear light, or an 8-bit image's sRGB) it works out the light it casts on rough surfaces (irradiance, as 9 spherical-harmonic coefficients), a cubemap of the image at its own resolution (the background, its mips box-filtered for blur) and one blurred for each roughness (GGX-prefiltered, CUBE_SIZE a face and MIP_COUNT mips, roughness 0 to 1 across them: what smooth to rough surfaces reflect), both as half floats ready for the GPU; and once, shared by every environment, the split-sum BRDF table (brdfTable). Split-sum image-based lighting, as the glTF sample viewer, Filament and Unreal light with it. Conventions: directions are world space, +y up. An equirectangular image's u runs around the horizon, 0.5 looking toward -z and growing toward +x; v = 0 is straight up. Cubemap faces are +X, -X, +Y, -Y, +Z, -Z in GL's orientation (s, t from 0 to 1, t = 0 the face's first row). The coefficients are convolved for Lambert's diffuse and divided by pi: evaluated at a normal, they give irradiance over pi.

```haxe
static inline var CUBE_SIZE:Int
static inline var MIP_COUNT:Int
static inline var BRDF_SIZE:Int
static function fromHdr(encoded:haxe.io.Bytes):EnvironmentBake3D
static function fromRgba(width:Int, height:Int, rgba:haxe.io.Bytes):EnvironmentBake3D
static var brdfTable(get, never):Null<haxe.io.Bytes>
static function equirectDirection(u:Float, v:Float, out:haxe.ds.Vector<Float>):Void
static function directionEquirect(x:Float, y:Float, z:Float, out:haxe.ds.Vector<Float>):Void
static function cubeDirection(face:Int, s:Float, t:Float, out:haxe.ds.Vector<Float>):Void
static function directionCube(x:Float, y:Float, z:Float, out:haxe.ds.Vector<Float>):Void
static function sampleEquirect(rgb:haxe.ds.Vector<Float>, width:Int, height:Int, x:Float, y:Float, z:Float, out:haxe.ds.Vector<Float>):Void
static function sampleCube(cube:CubeMap3D, x:Float, y:Float, z:Float, lod:Float, out:haxe.ds.Vector<Float>):Void
static function projectRows(rgb:haxe.ds.Vector<Float>, width:Int, height:Int, y0:Int, y1:Int, sums:haxe.ds.Vector<Float>):Void
static function shFromSums(sums:haxe.ds.Vector<Float>, out:haxe.ds.Vector<Float>):Void
static function evalSh(sh:haxe.ds.Vector<Float>, x:Float, y:Float, z:Float, out:haxe.ds.Vector<Float>):Void
static function cubeRows(rgb:haxe.ds.Vector<Float>, width:Int, height:Int, cube:CubeMap3D, face:Int, y0:Int, y1:Int):Void
static function boxMips(cube:CubeMap3D):Void
static function prefilterSamples(source:CubeMap3D, mip:Int, mipCount:Int, n:Int, out:haxe.ds.Vector<Float>):Int
static function prefilterRows(source:CubeMap3D, out:CubeMap3D, mip:Int, face:Int, y0:Int, y1:Int, samples:haxe.ds.Vector<Float>, count:Int):Void
static function halfOf(value:Float):Int
var done(get, never):Bool
function run(budgetMs:Float):Bool
var irradiance(get, never):haxe.ds.Vector<Float>
var lightingLevels(default, null):Array<haxe.io.Bytes>
var backgroundLevels(default, null):Array<haxe.io.Bytes>
var backgroundSize(default, null):Int
```

- `CUBE_SIZE`: The prefiltered cube's face size, at mip 0.
- `MIP_COUNT`: The prefiltered cube's mips: 128 down to 4, roughness 0, 0.2, ... 1.
- `BRDF_SIZE`: The BRDF table's size: n.v across, roughness down.
- `fromHdr`: A bake of encoded, a .hdr's bytes, decoded in its steps. Throws for one that isn't a .hdr.
- `fromRgba`: A bake of an 8-bit image (rows top first, RGBA, its colors sRGB), as linear light. Throws for a size of 0 or less, or rgba too short.
- `brdfTable`: The split-sum BRDF table once a bake has made it (null before): BRDF_SIZE square, RGBA8, red the scale A and green the bias B on F0 (F0 * A + B, 0..1), by n.v across and perceptual roughness down, each at its texel's centre: integrated over 256 GGX importance samples with Schlick-GGX geometry (k = alpha / 2) and Schlick's Fresnel (Karis' split sum).
- `equirectDirection`: The direction of equirectangular u, v (0..1 each), into out (x, y, z).
- `directionEquirect`: Where direction x, y, z (any length but 0) is in an equirectangular image, into out (u, v).
- `cubeDirection`: The direction through face's s, t (0..1 each), normalized, into out (x, y, z).
- `directionCube`: Where direction x, y, z is on a cube, into out (face, s, t).
- `sampleEquirect`: The equirectangular image (width x height, linear RGB) in direction x, y, z, filtered, into out (r, g, b).
- `sampleCube`: cube in direction x, y, z at mip lod (between mips, both blended), into out (r, g, b).
- `projectRows`: Rows y0 to y1 of an equirectangular image's projection onto the basis, added to sums (27: 9 coefficients, RGB each).
- `shFromSums`: The coefficients from a whole image's sums: each band's Lambert convolution (Ramamoorthi and Hanrahan), over pi; into out.
- `evalSh`: The irradiance over pi that coefficients sh (27) give at unit normal x, y, z, into out (r, g, b).
- `cubeRows`: Rows y0 to y1 of face of cube's mip 0 from an equirectangular image, each texel 2x2 samples.
- `boxMips`: cube's mips from 1 on, each its last box-filtered.
- `prefilterSamples`: Mip mip's prefilter samples, the same for every texel of the mip: n Hammersley points through GGX at roughness mip / (mipCount - 1), those below the horizon left out, into out (four floats each: the light direction about +z, its z its weight n.l, and the source mip it reads, blurrier where samples are sparse: filtered importance sampling); how many are kept.
- `prefilterRows`: Rows y0 to y1 of face of out's mip mip, from source through count samples (prefilterSamples'); mip 0 is source as it is, at out's size.
- `halfOf`: value as an IEEE half float's bits, rounded to nearest; past the largest finite half, the largest.
- `done`: Whether it's finished.
- `run`: Works steps until it's done or budgetMs milliseconds have passed (at least one step); true once done. Throws for a .hdr that turns out broken.
- `irradiance`: Its irradiance once done: 9 coefficients, RGB each (27 floats), over pi.
- `lightingLevels`: The prefiltered cube once done: MIP_COUNT levels from CUBE_SIZE, each its six faces one after another, RGBA half floats.
- `backgroundLevels`: The background cube once done: from backgroundSize down to 1, each its six faces one after another, RGBA half floats.
- `backgroundSize`: The background cube's face size, once its size is known (0 before): the image's width over 4, rounded down to a power of two, 64 to 1024.

## EnvironmentMap3D

*class* in [`src/helix/render3d/EnvironmentMap3D.hx`](../../src/helix/render3d/EnvironmentMap3D.hx), `import helix.render3d.EnvironmentMap3D;`

An environment map, ready to light a stage and stand behind it (Renderer3D.setEnvironment, setBackground): its irradiance (the light it casts on rough surfaces, 9 spherical-harmonic coefficients), its prefiltered cube (what smooth to rough surfaces reflect) and its background cube (the image at its own resolution, blurred mips below), both half floats on the GPU. From Environments3D.load, which prepares it (EnvironmentBake3D) and replaces its cubes in place when its file changes during development.

```haxe
var path(default, null):String
var lightingTexture(get, never):Int
var backgroundTexture(get, never):Int
var backgroundMipCount(get, never):Int
var irradiance(default, null):haxe.ds.Vector<Float>
function destroy(?gpu:IGraphics):Void
```

- `path`: The file it was loaded from.
- `lightingTexture`: The prefiltered cube's handle: EnvironmentBake3D.MIP_COUNT mips, roughness 0 to 1.
- `backgroundTexture`: The background cube's handle.
- `backgroundMipCount`: The background cube's mips: blur 1 is its last.
- `irradiance`: Its irradiance: 9 coefficients, RGB each (27 floats), over pi.
- `destroy`: Frees its cubes on gpu, the program's (Graphics) when not given. Environments3D.release does it for one it loaded.

## Environments3D

*class* in [`src/helix/render3d/Environments3D.hx`](../../src/helix/render3d/Environments3D.hx), `import helix.render3d.Environments3D;`

Environment maps from equirectangular images, prepared a little each frame (EnvironmentCache3D), installed by their first use, so a program with none carries none of it. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from EnvironmentCache3D's public members with their doc comments.

```haxe
static var budgetMs(get, set):Float
static var busy(get, never):Bool
static function load(path:String, loaded:EnvironmentMap3D -> Void, ?failed:String -> Void):IRequest
static function release(environment:EnvironmentMap3D):Void
```

- `budgetMs`: The milliseconds of preparation poll does a frame: 4 to start. A loading screen might raise it. At least 1e-6 (0 or less, or NaN, is 1e-6).
- `busy`: Whether anything is still loading or being prepared.
- `load`: Loads path into an environment. Loads of the same path share one (a load under way is joined); each load releases it once (release), and the last frees it. One of loaded or failed runs once on the host thread, and neither once the request is cancelled; failed (else the log, with the path) for a closed service, a file that won't load or isn't an image, or a GPU without filtered half floats.
- `release`: Lets go of an environment this service loaded, once for each load that gave it: the last release frees it and stops reloading it.

## HitArea3D

*class* in [`src/helix/render3d/HitArea3D.hx`](../../src/helix/render3d/HitArea3D.hx), `import helix.render3d.HitArea3D;`

The shape a node is picked by in place of what it draws (Node3D.hitArea), in the node's own units, moving, turning and scaling with it; never drawn. For something clicked but not seen (a bare Node3D with one), a thin model easier to hit (a door), or one tighter than its triangles.

```haxe
static function box(x:Float, y:Float, z:Float, width:Float, height:Float, depth:Float):HitArea3D
static function sphere(x:Float, y:Float, z:Float, radius:Float):HitArea3D
```

- `box`: A box width x height x depth (below 0 is 0) centered on x, y, z.
- `sphere`: A sphere of radius (below 0 is 0) centered on x, y, z.

## ImageSource3D

*enum* in [`src/helix/render3d/ImageSource3D.hx`](../../src/helix/render3d/ImageSource3D.hx), `import helix.render3d.ImageSource3D;`

Where a model's image file is.

- `InView(view:Int)`: In a buffer view.
- `Inline(bytes:haxe.io.Bytes)`: Inline: a data: URI's bytes.
- `File(uri:String)`: A file of its own: a uri relative to the model.

## Light3D

*class* in [`src/helix/render3d/Light3D.hx`](../../src/helix/render3d/Light3D.hx), `import helix.render3d.Light3D;`

A light, shining from its node's place and orientation once it is on a stage: a DirectionalLight3D, a PointLight3D or a SpotLight3D (a stage never holds a bare Light3D). Its color is 0xAARRGGBB (sRGB, its alpha ignored), its intensity a multiplier (a directional light's π shows a surface facing it at its color as written). Under a model, a lamp's bulb, it moves with it; it has children as any node. A directional light or a spot may cast shadows (shadowCasting; a stage draws them with Renderer3D.drawShadows): from the models that cast them onto those that receive them (Model3D.shadowCasting, shadowReceiving; both by default). A directional light's map covers what the camera sees out to its shadow distance; a spot's, its cone out to its range (or the shadow distance, the nearer).

```haxe
var color:Int
var intensity(default, set):Float
var shadowCasting(get, set):Bool
var shadowDistance(default, set):Float
var shadowMapSize(default, set):Int
var shadowStrength(default, set):Float
var shadowColor:Int
var shadowBiasConstant(default, null):Float
var shadowBiasSlope(default, null):Float
function setShadowBias(constant:Float, slope:Float):Bool
```

- `color`: Its color, 0xAARRGGBB.
- `intensity`: Its intensity, a multiplier: 0 or more (under 0, or NaN, is 0). A directional light's starts at π (a surface facing it shows its color as written), a point's and a spot's at 1.
- `shadowCasting`: Whether it casts shadows (always false for a point light: it would need a map each way).
- `shadowDistance`: How far from the camera a directional light's shadows reach, in world units (50 by default); a spot's reach no further. Shorter is sharper: the map covers less. At least 1e-6 (0 or less, or NaN, is 1e-6) and finite (infinity is the largest finite Float).
- `shadowMapSize`: Its shadow map's side in texels (2048 by default): a power of two from 256 to 4096, what it's given rounded down to one and into that range. A stage's casting lights share the largest asked for.
- `shadowStrength`: How much of its light a shadow takes away, clamped to 0..1 (1 by default; NaN is 0).
- `shadowColor`: What its shadows leave of the surface's own color, 0xAARRGGBB (sRGB, alpha ignored; black by default: nothing): a cold blue for a sunny day's shade.
- `shadowBiasConstant`: Its shadows' depth bias, constant part, in shadow-map texels (1 by default).
- `shadowBiasSlope`: Its shadows' depth bias, slope part: texels more where the light grazes a surface (4 by default).
- `setShadowBias`: Sets its shadows' depth bias in texels: constant everywhere, plus slope where the light grazes. More stops a surface shadowing itself in stripes ("acne"); too much lifts a shadow off its caster's foot. False, changing nothing, for a negative or infinite one.

## Mat4

*class* in [`src/helix/render3d/Mat4.hx`](../../src/helix/render3d/Mat4.hx), `import helix.render3d.Mat4;`

A 4x4 matrix of floats, column-major (element column * 4 + row), as shaders take it. Setters overwrite the whole matrix.

```haxe
function new()
function get(index:Int):Float
function set(index:Int, value:Float):Void
function makeIdentity():Void
function makePerspective(fovY:Float, aspect:Float, near:Float, far:Float):Bool
function makeOrthographic(height:Float, aspect:Float, near:Float, far:Float):Bool
function makeOrthographicBox(left:Float, right:Float, bottom:Float, top:Float, near:Float, far:Float):Bool
function makeLookAt(eyeX:Float, eyeY:Float, eyeZ:Float, targetX:Float, targetY:Float, targetZ:Float, upX:Float, upY:Float, upZ:Float):Bool
function makeTransform(px:Float, py:Float, pz:Float, qx:Float, qy:Float, qz:Float, qw:Float, sx:Float, sy:Float, sz:Float):Void
function copyFrom(other:Mat4):Void
function makeProduct(a:Mat4, b:Mat4):Void
function makeInverse(of:Mat4):Bool
function writeTo(bytes:haxe.io.Bytes, ?offset:Int = 0):Void
```

- `new`: The identity.
- `get`: Element column * 4 + row.
- `set`: Sets element column * 4 + row to value.
- `makeIdentity`: The identity.
- `makePerspective`: A perspective projection: fovY radians of vertical view, aspect width / height, near and far the clip planes' distances, GL clip depth (-1 near to 1 far). False, changing nothing, unless 0 < fovY < pi, aspect > 0 and 0 < near < far.
- `makeOrthographic`: An orthographic projection: height world units of vertical view (width by aspect, width / height) centered on the view's axis, near and far the clip planes' distances, GL clip depth (-1 near to 1 far). False, changing nothing, unless height > 0, aspect > 0 and near < far.
- `makeOrthographicBox`: An orthographic projection of the box left..right, bottom..top (in view space's x and y), near..far its depth: GL clip depth (-1 near to 1 far). False, changing nothing, unless left < right, bottom < top and near < far.
- `makeLookAt`: A view from eye looking at target, up giving the roll: right-handed, the eye looking down its -z. False, changing nothing, when the eye is at the target or up is parallel to the view.
- `makeTransform`: Scale, then rotation (the unit quaternion qx, qy, qz, qw), then translation: a placement's matrix.
- `copyFrom`: Copies other into this matrix.
- `makeProduct`: a * b: b applied first, then a. Either may be this matrix.
- `makeInverse`: The inverse of of (by its adjugate), which may be this matrix. False, setting all zeros, for a singular one.
- `writeTo`: Writes the 16 floats, column-major, little-endian float32, into bytes at offset: the 64 bytes a shader's matrix uniform takes.

## Material3D

*class* in [`src/helix/render3d/Material3D.hx`](../../src/helix/render3d/Material3D.hx), `import helix.render3d.Material3D;`

How a model's surface looks: glTF's metallic-roughness model. A base color (0xAARRGGBB, its color sRGB-encoded as the convention's colors are; its alpha below 255 makes the surface see-through), an optional base color texture (sRGB) multiplying it, how metallic (0..1) and how rough (0..1) it is, an optional normal map (tangent space, green up) and its strength, light it gives off (emissive), and whether lights shade it at all. Shared by any number of models: models alike in mesh and material draw together.

```haxe
function new()
var baseColor:Int
var texture:Null<Texture2D>
var metallic(default, set):Float
var roughness(default, set):Float
var lit:Bool
var normalTexture:Null<Texture2D>
var normalScale(default, set):Float
var emissive(default, null):Int
var emissiveStrength(default, null):Float
function setEmissive(color:Int, ?strength:Float = 1.):Bool
var doubleSided:Bool
var shader(default, null):Null<Shader>
function setShader(value:Null<Shader>):Bool
var shaderParameters(get, never):Null<ShaderParameters>
var blended(get, set):Bool
```

- `new`: White, not metallic, roughness 0.5, lit, untextured, giving off no light.
- `baseColor`: The base color, 0xAARRGGBB.
- `texture`: The base color texture, or null for none (white).
- `metallic`: How metallic, 0..1. Clamped to 0..1 (NaN is 0).
- `roughness`: How rough, 0..1. Clamped to 0..1 (NaN is 0).
- `lit`: Whether lights shade it; unlit, it shows its color as it is.
- `normalTexture`: The normal map (tangent space, green up), or null for none. Its colors are directions, read as they are, not decoded from sRGB. Load it smooth, with mipmaps (Textures.load's linear true).
- `normalScale`: How strongly the normal map bends the surface: 1 as it is, 0 flat. 0 or more (under 0, or NaN, is 0).
- `emissive`: The light it gives off, 0xAARRGGBB (sRGB, alpha ignored); black for none.
- `emissiveStrength`: How bright its emissive light is: the color times this.
- `setEmissive`: Gives it light of its own, color (0xAARRGGBB, sRGB) times strength, lit or not. False for a strength under 0.
- `doubleSided`: Whether both sides of its triangles draw (the back with its normal turned toward the viewer), for open surfaces, leaves, cloth, or a surface a shader cuts holes in; otherwise back faces are culled.
- `shader`: The app's surface shader it draws with, or null for the stage's own shading.
- `setShader`: Draws it with an app's surface shader (a .hxshader of kind surface: its own fragment stage, and maybe a vertex hook), which gets the material's values and textures and the stage's lights; null goes back to the stage's own shading. False, changing nothing, for a shader of another kind. Its parameters (shaderParameters) start empty when the shader changes.
- `shaderParameters`: Its surface shader's own parameters and textures, set by name; null without a shader.
- `blended`: Whether it is see-through: drawn blended, back to front after the opaque, when set so or when its base color's alpha is below 255. Set, it draws blended even at full alpha, as glTF's alphaMode BLEND says (its texture's alpha then shows through).

## Mesh3D

*class* in [`src/helix/render3d/Mesh3D.hx`](../../src/helix/render3d/Mesh3D.hx), `import helix.render3d.Mesh3D;`

Triangles for lit models: each vertex a position, a normal, texture coordinates and a tangent (Lit3DProgram's packing; the tangent's w its bitangent's sign, glTF's convention), indexed, with the box around them; a skinned one also each vertex's four joints and their weights (Skinned3DProgram's skin buffer), its box its bind pose's. Made once and never changed; a Renderer3D uploads it the first time it draws it. The shapes made here are centered on the origin, y up, counter-clockwise from outside (the front face), in world units, as the earlier frameworks' generated meshes.

```haxe
function new(vertices:haxe.io.Bytes, vertexCount:Int, indices:haxe.io.Bytes, indexCount:Int)
static function fromArrays(positions:Array<Float>, normals:Null<Array<Float>>, uvs:Null<Array<Float>>, tangents:Null<Array<Float>>, indices:Null<Array<Int>>, ?joints:Array<Float>, ?weights:Array<Float>):Mesh3D
static function plane(width:Float, length:Float, ?subdivisions:Int = 0):Mesh3D
static function cube(width:Float, height:Float, length:Float):Mesh3D
static function sphere(radius:Float, ?rings:Int = 16, ?segments:Int = 32):Mesh3D
static function cylinder(radius:Float, height:Float, ?segments:Int = 32):Mesh3D
static function cone(radius:Float, height:Float, ?segments:Int = 32):Mesh3D
static function capsule(radius:Float, height:Float, ?rings:Int = 16, ?segments:Int = 32):Mesh3D
static function torus(radius:Float, thickness:Float, ?rings:Int = 32, ?segments:Int = 16):Mesh3D
var vertexCount(default, null):Int
var indexCount(default, null):Int
var vertices(get, never):haxe.io.Bytes
var indices(get, never):haxe.io.Bytes
var minX(get, never):Float
var minY(get, never):Float
var minZ(get, never):Float
var maxX(get, never):Float
var maxY(get, never):Float
var maxZ(get, never):Float
var skinned(get, never):Bool
var skinData(default, null):Null<haxe.io.Bytes>
var shape(default, null):Null<MeshShape3D>
function getJointReach(skin:Skin3D):Null<haxe.ds.Vector<Float>>
var passVertices(get, never):haxe.io.Bytes
function destroy():Void
```

- `new`: A mesh of vertexCount vertices in vertices (Lit3DProgram.stride bytes each) and indexCount uint32 indices (whole triangles) in indices. Throws for a count of 0 or less, too few bytes, or an index past the vertices.
- `fromArrays`: A mesh from arrays: positions (x, y, z each), normals (one a position, unit length; null to work them out from the triangles), texture coordinates (u, v each; null for zeros), tangents (x, y, z, w each, w the bitangent's sign; null to work them out) and indices (whole triangles; null for each three positions a triangle, in order); skinned when joints (four joint indices a vertex) and weights (their four weights, normalized here) are given. Throws for arrays that don't agree.
- `plane`: Flat in x and z, facing +y, width along x and length along z, subdivisions (0..256) more cells each way; texture coordinates span it once.
- `cube`: A box width along x, height along y and length along z, each face its own vertices (sharp edges), textured 0..1 a face.
- `sphere`: A sphere of radius, rings (2..256) from pole to pole and segments (3..512) around; u around, v from the top pole to the bottom.
- `cylinder`: A capped cylinder along y, of radius and height, segments (3..512) around.
- `cone`: A cone along y, tip up, of base radius and height, its base capped, segments (3..512) around.
- `capsule`: A capsule along y: height from end to end (at least twice the radius; less is a sphere), rings (2..256) across both round ends, segments (3..512) around.
- `torus`: A ring around y: radius to the middle of the tube, thickness the tube's radius, rings (3..512) around the ring and segments (3..512) around the tube.
- `vertexCount`: Its vertices.
- `indexCount`: Its indices: three a triangle.
- `vertices`: The vertex data, Lit3DProgram.stride bytes a vertex.
- `indices`: The indices, uint32 each.
- `minX`: The box around it: its smallest x.
- `minY`: Its smallest y.
- `minZ`: Its smallest z.
- `maxX`: Its largest x.
- `maxY`: Its largest y.
- `maxZ`: Its largest z.
- `skinned`: Whether its vertices follow joints (a skin's): a Model3D showing it needs one (Model3D.skin).
- `skinData`: A skinned mesh's joints and weights, Skinned3DProgram.skinStride bytes a vertex: four joint indices (as floats), then their four weights, summing to 1. Null for one that isn't skinned.
- `shape`: What made it, for a mesh from plane, cube, sphere, cylinder, cone, capsule or torus: the generator's name and its arguments as it was called. Null for a mesh from arrays (fromArrays, a file's meshes), which nothing can write back as a shape.
- `getJointReach`: How far each of skin's joints reaches in this skinned mesh as bound: the farthest of the vertices it weights from its bind position (Skin3D.getBindPosition), -1 for a joint that weights none; worked out the first time it's asked for each skin, for culling a posed model. Null for a mesh that isn't skinned.
- `passVertices`: Its vertices as a model's passes (ModelPass3D: an outline, a silhouette) draw them, Flat3DProgram.stride bytes each: its position, then its normal averaged over every vertex at that position (the distinct normals of the vertices at exactly that place summed, then made unit length; the vertex's own normal where they cancel out). A hard edge splits a vertex into copies, one a face, each with its face's normal; pushed out along those, an outline's shell would crack into separate faces, so the copies move together instead. Worked out the first time it's read (a mesh no pass draws never has it), Flat3DProgram.stride bytes a vertex more. Vertices of separate meshes (a model's parts) aren't averaged together.
- `destroy`: Frees its buffers, if it was uploaded; drawing it again uploads it again.

## MeshShape3D

*class* in [`src/helix/render3d/MeshShape3D.hx`](../../src/helix/render3d/MeshShape3D.hx), `import helix.render3d.MeshShape3D;`

What made a generated mesh (Mesh3D.shape): the generator's name, plane, cube, sphere, cylinder, cone, capsule or torus, and its arguments as it was called, by the generator's own parameter names (a plane's width, length and subdivisions; a sphere's radius, rings and segments), the ones left at their defaults included, a count as a whole number. A scene file writes a Model3D's generated mesh from it; a mesh from arrays or from a file has none.

```haxe
function new(name:String, arguments:Map<String, Float>)
final name:String
final arguments:Map<String, Float>
```

- `new`: The record of a call of the generator name with arguments.
- `name`: The generator's name: plane, cube, sphere, cylinder, cone, capsule or torus.
- `arguments`: Its arguments by the generator's parameter names, every one said, as the generator was called (before any clamping).

## Model3D

*class* in [`src/helix/render3d/Model3D.hx`](../../src/helix/render3d/Model3D.hx), `import helix.render3d.Model3D;`

A model: its parts, each a mesh drawn with a material (a glTF node with several primitives is one model of several parts), tinted (0xAARRGGBB, white for none; its alpha below 255 makes it see-through), casting and receiving shadows. A model of a skinned mesh follows the joints it's bound to (bindSkeleton). Its mesh and material are its first part's.

```haxe
function new(?mesh:Mesh3D, ?material:Material3D)
var partCount(get, never):Int
function getPart(index:Int):Null<Part3D>
function addPart(mesh:Mesh3D, ?material:Material3D):Void
var mesh(get, set):Null<Mesh3D>
var material(get, set):Null<Material3D>
var passCount(get, never):Int
function getPass(index:Int):Null<ModelPass3D>
var tint:Int
var shadowCasting(get, set):Bool
var shadowReceiving(get, set):Bool
var skin(default, null):Null<Skin3D>
var jointCount(get, never):Int
function getJoint(index:Int):Null<Node3D>
function bindSkeleton(skeleton:Node3D, ?skin:Skin3D):Bool
```

- `new`: A model of one part, mesh drawn with material (a new white one when null); with no mesh, a model of no parts until mesh.
- `partCount`: How many parts it has.
- `getPart`: Its part at index, in the file's order; null past the end.
- `addPart`: Adds a part, mesh drawn with material (a new white one when null), after the others.
- `mesh`: Its first part's mesh, or null with no parts. Assigned to a model with no parts, it makes that part (white).
- `material`: Its first part's material, or null with no parts. Assigned to a model with no parts, it makes that part (with no mesh).
- `passCount`: How many extra passes it's drawn in (ModelPass3D: helix.shader.Outline and Silhouette add themselves).
- `getPass`: Its extra pass at index, in the order added; null past the end.
- `tint`: Its tint, 0xAARRGGBB.
- `shadowCasting`: Whether it casts shadows (from the lights that cast them; see-through models never do). True by default.
- `shadowReceiving`: Whether shadows fall on it. True by default.
- `skin`: Its skin (its mesh's joints by name), or null: a model of a skinned mesh without one draws in its bind pose.
- `jointCount`: How many joints it follows: its skin's, once bound; 0 otherwise.
- `getJoint`: The node its joint index follows; null past them or unbound.
- `bindSkeleton`: Binds it, a model of a skinned mesh, to a skeleton: each of skin's joints (its own skin when null) to the node of that name at or under skeleton, which must be on the same stage, so its vertices follow them. A piece of gear skinned in a file of its own follows a character this way, by joint name. False, changing nothing, for a mesh that isn't skinned, no skin, or a joint name the skeleton lacks.

## ModelFile3D

*class* in [`src/helix/render3d/ModelFile3D.hx`](../../src/helix/render3d/ModelFile3D.hx), `import helix.render3d.ModelFile3D;`

A model file read into what a Renderer3D draws: its meshes (a part a glTF primitive), its materials and its node tree, from a glTF 2.0 file (ModelCache3D loads them). instantiate() makes a fresh node tree each call, sharing the file's meshes and materials, so any number of copies draw together; each copy has lights and cameras of its own. Made by ModelCache3D; read, never changed after. Read: GLB and .gltf files, their buffers inside them, inline (data: URIs) or in files beside them, and their images in buffer views, inline or in files beside them; triangle primitives' positions, normals (worked out when missing), first texture coordinates and tangents (worked out when missing); metallic-roughness materials' base color and texture, metallic and roughness factors, normal map and its scale, emissive color (with KHR_materials_emissive_strength), alphaMode BLEND and doubleSided; nodes' names, translation, rotation and scale or matrix, and children; the default scene's roots; textures' samplers (filter and wrap); KHR_lights_punctual's directional, point and spot lights; cameras (a perspective one's yfov, znear and zfar, an orthographic one's ymag, znear and zfar; its aspectRatio or xmag is the viewport's business and isn't read); skins (each vertex's first four joints and weights, the joints by their nodes' names, their inverse bind matrices), each copy's skinned models bound to that copy's joints; animations as AnimationClips (clips), their tracks targeting nodes by name, so a file of animations alone plays on any skeleton with those names. Not read yet (warned once a file): morph targets (and animations of their weights), metallic-roughness, occlusion and emissive textures, alphaMode MASK, texture transforms (KHR_texture_transform beyond its texture coordinate set), a second texture coordinate set, and a second set of joints and weights (a vertex's fifth to eighth joints).

```haxe
var warnings(get, never):Array<String>
var skins(get, never):Array<Skin3D>
var clips(get, never):Array<AnimationClip3D>
function getClip(name:String):Null<AnimationClip3D>
var materials(get, never):Array<Material3D>
function instantiate(?name:String = ""):Node3D
```

- `warnings`: What the file used that isn't read yet, each once.
- `skins`: Its skins, in the file's order: the joints its skinned meshes follow.
- `clips`: Its animations, in the file's order.
- `getClip`: The animation named name: its whole name, or the part after a "|" (a Blender export names a clip "Armature|Walk", so "Walk" finds it); null for none.
- `materials`: Its materials, in the file's order: change one and every copy's parts with it change.
- `instantiate`: A new node tree of the file's default scene, under a group named name: each of the file's nodes as one node of its name, transform and children: a node with a mesh a Model3D (its primitives the model's parts, sharing the file's meshes and materials), a light node a DirectionalLight3D, PointLight3D or SpotLight3D as the file says (of its own, each copy), a camera node a Camera3D (of its own, each copy) seeing from the node down its -z with its +y up, as glTF's does, so nothing is turned, and any other a group (a bare Node3D: a joint, an empty). A node with both a mesh and a light is the model, the light its first child; one with both a mesh and a camera is the model, the camera a child named the node's name with "_camera" appended.

## ModelPass3D

*class* in [`src/helix/render3d/ModelPass3D.hx`](../../src/helix/render3d/ModelPass3D.hx), `import helix.render3d.ModelPass3D;`

An extra pass a model is drawn in after the stage's opaque models: the model again in one flat color, from the same records as its parts (static or skinned, instanced like it), either pushed out along its normals into a shell whose far side shows past its edges (an outline: helix.shader.Outline), or drawn only where something nearer hides it (a silhouette: helix.shader.Silhouette). Each kind's constructor adds it to its model. A stage draws its opaque models without silhouettes and its opaque sprites, then the silhouettes, then the opaque models with them (so a model's own parts never hide it), then every outline, then what's see-through.

```haxe
var model(default, null):Model3D
var color:Int
var enabled:Bool
function remove():Bool
```

- `model`: The model it draws.
- `color`: Its color, 0xAARRGGBB: a display color (sRGB, written as it is, as sprites' are), its alpha blending a silhouette over what hides it.
- `enabled`: Whether it draws: true to start.
- `remove`: Takes it off its model, which draws it no more. False when it was taken off before.

## Models3D

*class* in [`src/helix/render3d/Models3D.hx`](../../src/helix/render3d/Models3D.hx), `import helix.render3d.Models3D;`

Model files (glTF 2.0), loaded once and shared by path (ModelCache3D). The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from ModelCache3D's public members with their doc comments.

```haxe
static function load(path:String, loaded:ModelFile3D -> Void, ?failed:String -> Void):IRequest
static function find(path:String):Null<ModelFile3D>
static function isLoaded(path:String):Bool
static function isLoading(path:String):Bool
static var loadingCount(get, never):Int
static function put(path:String, file:ModelFile3D):Void
static function forget(path:String):Void
```

- `load`: Loads path (a .glb or .gltf) into a ModelFile3D: the file, then any buffers it keeps in files beside it, then its images (decoded from the file, or loaded from files beside it through the textures, which reload them when they change). One of loaded or failed runs once: during this call when the file is loaded already (or failed before; forget clears a failure), else on the host thread when its load ends: loaded once its images are in (one that fails leaves its material untextured, with a warning), failed (else the log, with the path) for a load failure, a buffer that won't load, or a file it can't read. Neither runs once the request is cancelled (the shared load goes on for the others) or the service shuts down.
- `find`: The file at path if it's loaded, else null.
- `isLoaded`: Whether path is loaded.
- `isLoading`: Whether path is loading.
- `loadingCount`: How many files are loading.
- `put`: Adds a file loaded some other way under path, as if loaded from there (a test's, a generated one).
- `forget`: Forgets path: its file (the copies instantiated from it stay) or its failure, so it's loaded again when next asked for.

## Node3D

*class* in [`src/helix/render3d/Node3D.hx`](../../src/helix/render3d/Node3D.hx), `import helix.render3d.Node3D;`

What a 3D stage holds: a transform in a tree, with children of its own kind (Godot's Node3D). A bare one is a group: it draws nothing, only a transform for its children (an empty in Blender, a dummy in 3ds Max, a null in Cinema 4D), a handle that moves or hides a set of things together, or a pivot to turn them about. The framework's kinds are its classes (Model3D, DirectionalLight3D, PointLight3D, SpotLight3D, Camera3D, Sprite3D, Text3D, Particles3D), each holding only its own data; a game never subclasses one, and game state lives elsewhere, the node its view (docs/DECISIONS.md, 61 and 130). Its transform is a position, a rotation (a unit quaternion, set from angles or by lookAt) and a scale, relative to its parent; its world matrix is worked out when a stage draws it, only after it or a node above it changed.

```haxe
function new()
var environment:Null<Environment3D>
var hitArea:Null<HitArea3D>
function addChild(child:Node3D):Bool
function addChildAt(child:Node3D, index:Int):Bool
function addChildInPlace(child:Node3D):Bool
function removeChildAt(index:Int):Null<Node3D>
function removeChild(child:Node3D):Bool
var parent(get, set):Null<Node3D>
function getChild(index:Int):Null<Node3D>
function collectModels(skinned:Array<Model3D>, rigid:Array<Model3D>):Void
function findAttachment(model:Model3D, skeleton:Node3D):Null<Attachment3D>
function computeWorld(?out:Mat4):Mat4
function computeBounds(?relativeTo:Node3D, ?out:Bounds3D):Null<Bounds3D>
var x(get, set):Float
var y(get, set):Float
var z(get, set):Float
var quaternionX(get, never):Float
var quaternionY(get, never):Float
var quaternionZ(get, never):Float
var quaternionW(get, never):Float
var scaleX(get, set):Float
var scaleY(get, set):Float
var scaleZ(get, set):Float
function setPosition(x:Float, y:Float, z:Float):Void
var rotationX(get, never):Float
var rotationY(get, never):Float
var rotationZ(get, never):Float
function setRotation(x:Float, y:Float, z:Float):Void
function setQuaternion(x:Float, y:Float, z:Float, w:Float):Void
var matrix(get, never):Array<Float>
function setMatrix(m:Array<Float>):Bool
function setScale(x:Float, y:Float, z:Float):Void
function lookAt(x:Float, y:Float, z:Float, ?upX:Float = 0., ?upY:Float = 1., ?upZ:Float = 0.):Bool
var worldMatrix(get, never):Mat4
```

- `new`: A group at the origin, unturned and unscaled, with no children.
- `environment`: The light of the place under it (Environment3D: ambient light, environment map, background), or null: a level's root carries its level's (a scene file's "environment" section). A View3D lights its tree by its own environment if it has one, else by the first one in its tree (the root's, depth first); others are logged once and not used yet (the nearest ancestor's, docs/ROADMAP.md).
- `hitArea`: The shape it's picked by in place of what it draws, in its own units, never drawn; null (the default) for what it draws. A group with one is picked by it; its children are picked as ever, the nearest hit winning.
- `addChild`: Makes child its last child, taking it from any parent it had, keeping child's local transform: it moves with this node as it sat under its old parent (a hat onto a head joint). addChildInPlace keeps its world transform instead. False, changing nothing, for itself or one of its own ancestors.
- `addChildAt`: Makes child its child at index in drawing order (0 is drawn first, under the others; those from index on move up one), taking it from any parent it had and keeping its local transform, as addChild does; an index past the end, or -1, makes it the last. A child of this node already moves to index. False, changing nothing, for itself or one of its own ancestors.
- `addChildInPlace`: Puts child under this node without it moving: its world transform is kept and its local one recomputed from this node's (a dropped sword picked up by a hand). addChild keeps the child's local transform instead (a hat onto a head joint). A shear the two transforms make together is lost. False, changing nothing, for itself or one of its own ancestors, or a zero scale on this or above it.
- `removeChildAt`: Takes its child at index (in drawing order) from its children and returns it, or null past the end, changing nothing.
- `removeChild`: Takes child from its children. False when it isn't one.
- `parent`: Its parent, or null at a tree's top. Assigning a node makes this its last child as that node's addChild does, keeping this one's local transform (addChildInPlace keeps the world one); assigning null takes it from its parent as the parent's removeChild does. A node under itself or one of its own descendants is refused, leaving the tree as it was.
- `getChild`: Its child at index, in drawing order; null past the end.
- `collectModels`: The models at or under it, sorted: the skinned ones (bound to a skeleton by bindSkeleton) into skinned, the rigid ones into rigid, a rigid model's own children going with it (a sword's gem). A part file's own copy of an armature (an exporter's) is passed over, as only models are taken: with findAttachment, how a game dresses a character from files of their own (the examples' Outfit).
- `findAttachment`: Where a rigid model under it (a part file's root, instantiated) attaches to skeleton: the piece to hang, the node just under model's nearest ancestor below this named as a joint skeleton has (an importer may split one mesh into several models, so the piece may be above model, and its siblings go with it), and that joint, which the piece keeps its offset from. A file whose models sit under no joint gives the node just under this as the piece and null as the joint, for a socket the game chooses. Null when model isn't under this.
- `computeWorld`: Its world matrix as it is now, into out (a new one when not given), returned: its own transform and every one above it, worked out afresh without touching what a stage keeps (a camera's view is found so, wherever it is). Given out, it allocates nothing.
- `computeBounds`: The box around it and everything under it as they are now, into out (a new one when not given), or null for nothing to bound: in the world, or in relativeTo's own units when given (as relativeTo's children are placed). Each model counts by its vertices (a skinned one's as posed), each sprite by the sphere its quad can turn in, placed by the transforms as they are now (a draw needn't have run). A disabled or hidden node and what's under it are left out, as text and emitters are. Null too for a relativeTo scaled to nothing. Exact where a stage's culling box is generous, for framing: a camera fitted to it. `computeBounds(scratch)` is the world into scratch: Haxe skips relativeTo for a Bounds3D. Given out, it allocates nothing once it has walked as deep a tree before.
- `x`: Its position's x, relative to its parent.
- `y`: Its position's y.
- `z`: Its position's z.
- `quaternionX`: Its rotation's quaternion x, relative to its parent.
- `quaternionY`: Its rotation's quaternion y.
- `quaternionZ`: Its rotation's quaternion z.
- `quaternionW`: Its rotation's quaternion w.
- `scaleX`: Its scale along its own x.
- `scaleY`: Its scale along its own y.
- `scaleZ`: Its scale along its own z.
- `setPosition`: Places it at x, y, z, relative to its parent.
- `rotationX`: Its rotation as angles in radians about x, then y, then z (setRotation's), x of them: worked out from its quaternion, so an equal turn, not always the angles set (y is kept within -pi/2..pi/2).
- `rotationY`: Its rotation's angle about y, radians, as rotationX.
- `rotationZ`: Its rotation's angle about z, radians, as rotationX.
- `setRotation`: Turns it by angles in radians about x, then y, then z, relative to its parent.
- `setQuaternion`: Turns it by the unit quaternion x, y, z, w, relative to its parent (normalized here; the identity for a zero one).
- `matrix`: Its matrix relative to its parent (16 floats, column-major): its place, turn and scale put together.
- `setMatrix`: Places, turns and scales it by a matrix (16 floats, column-major) relative to its parent, taken apart into translation, rotation and scale; a shear is lost. False, changing nothing, for one of the wrong length or with a zero scale.
- `setScale`: Scales it along its own x, y and z.
- `lookAt`: Turns it so its -z looks from its position at x, y, z, up (0, 1, 0 by default) giving the roll; positions relative to its parent. False, changing nothing, when the point is its position or up is along the view.
- `worldMatrix`: Its world matrix as the last update left it (Renderer3D.draw updates it).

## Orbit3D

*class* in [`src/helix/render3d/Orbit3D.hx`](../../src/helix/render3d/Orbit3D.hx), `import helix.render3d.Orbit3D;`

A circling camera: a point going round a target at a radius and a height, looking at the target. `update` advances it, `apply` places a camera there. At an angle of 0 the camera is on the target's +z side, and the angle grows toward +x. The examples' way of showing a model from all sides; a game moves its cameras its own way.

```haxe
function new(radius:Float, height:Float, ?speed:Float = .25, ?targetY:Float = 0., ?angle:Float = 0.)
var angle:Float
var speed:Float
var radius:Float
var height:Float
var targetX:Float
var targetY:Float
var targetZ:Float
var running:Bool
function update(dt:Float):Void
function apply(camera:Camera3D):Void
```

- `new`: A circle of radius at height, going round at speed radians a second from angle, looking at (0, targetY, 0); targetX and targetZ move the point looked at.
- `angle`: Where round the circle it is, in radians: 0 on the target's +z side, a quarter turn on its +x side.
- `speed`: How fast it goes round, in radians a second; under 0 the other way.
- `radius`: How far out from the target, across the ground, in world units.
- `height`: How high the camera is, in world units: its y, not its height over the target.
- `targetX`: The point the camera looks at, in world units.
- `targetY`: The point the camera looks at, in world units.
- `targetZ`: The point the camera looks at, in world units.
- `running`: Whether `update` goes round; false holds the camera where it is.
- `update`: Goes round for dt seconds, if running.
- `apply`: Places camera on the circle at the angle, looking at the target (its setView).

## Part3D

*class* in [`src/helix/render3d/Part3D.hx`](../../src/helix/render3d/Part3D.hx), `import helix.render3d.Part3D;`

One piece of a Model3D: a mesh drawn with a material (a glTF primitive). A model's parts move together, as its node; each draws with the models alike in mesh and material.

```haxe
function new(mesh:Null<Mesh3D>, ?material:Material3D)
var mesh:Null<Mesh3D>
var material:Material3D
```

- `new`: mesh (null for none yet: it draws nothing) drawn with material (a new white one when null).
- `mesh`: Its mesh, or null for none.
- `material`: Its material.

## Particles3D

*class* in [`src/helix/render3d/Particles3D.hx`](../../src/helix/render3d/Particles3D.hx), `import helix.render3d.Particles3D;`

An emitter of particles (helix.particle.Emitter), placed here: it spawns where this node is (a move spreads its spawns along the way, and particles may inherit its velocity), and the stage advances it by its clock (Renderer3D.setTime) each draw. Particles stay where they were born, so they trail as the node moves.

```haxe
function new(emitter:Emitter)
static function explosion(size:Float):Particles3D
static function smokePuff(size:Float):Particles3D
static function sparks(size:Float):Particles3D
static function dust(size:Float):Particles3D
static function fire(size:Float):Particles3D
static function smoke(size:Float):Particles3D
static function rain(size:Float):Particles3D
static function snow(size:Float):Particles3D
static function confetti(size:Float):Particles3D
var emitter(default, null):Emitter
var removeWhenSpent:Bool
```

- `new`: emitter, placed here.
- `explosion`: A preset (helix.particle.ParticlePreset.Explosion): a burst of light outward, fading from white-yellow to red: a hit, a pop, a small explosion. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `smokePuff`: A preset (helix.particle.ParticlePreset.SmokePuff): a soft gray puff, spreading and rising a little as it fades: a landing, a vanish. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `sparks`: A preset (helix.particle.ParticlePreset.Sparks): hot sparks thrown up and out, streaked and falling: a hit on metal. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `dust`: A preset (helix.particle.ParticlePreset.Dust): a low, wide kick of dust that settles: footsteps, a landing, a skid. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `fire`: A preset (helix.particle.ParticlePreset.Fire): a steady flame, rising and fading from yellow to red: a torch, a campfire; size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `smoke`: A preset (helix.particle.ParticlePreset.Smoke): a steady column of gray smoke, rising and spreading: a chimney, a wreck; size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `rain`: A preset (helix.particle.ParticlePreset.Rain): steady rain over a width of size, falling size below the node; size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `snow`: A preset (helix.particle.ParticlePreset.Snow): steady snow over a width of size, drifting down size below the node; size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `confetti`: A preset (helix.particle.ParticlePreset.Confetti): paper of five colors thrown up, spinning and falling: a win, a level cleared. One-shot, off its parent once spent (removeWhenSpent); size about how big it is, in world units. Drawn with the built-in dot (Emitter.getDot); its emitter is an ordinary one, to change what doesn't fit.
- `emitter`: Its emitter.
- `removeWhenSpent`: Whether it takes itself off its parent once its emitter is spent (Emitter.spent: a one-shot's burst died out), the frame after: true for the one-shot presets (explosion, smokePuff, sparks, dust, confetti), so a game puts one down and forgets it; false otherwise.

## PickHit3D

*class* in [`src/helix/render3d/PickHit3D.hx`](../../src/helix/render3d/PickHit3D.hx), `import helix.render3d.PickHit3D;`

What a pick hit (Renderer3D.pick): the node, how far along the ray, the point in the world and in the node's own space, the surface's normal there in the world, facing back along the ray, and on a skinned model the joint that moves it there.

```haxe
function new()
var node(default, null):Null<Node3D>
var joint(default, null):Null<Node3D>
var distance(default, null):Float
function getPoint(axis:Int):Float
function getLocalPoint(axis:Int):Float
function getNormal(axis:Int):Float
```

- `new`: No hit yet.
- `node`: The node hit (a model, a sprite or a text), or null for no hit.
- `joint`: On a skinned model, the joint that moves the surface hit most (its triangle's joints weighed at the point), which something stuck there follows as the model is posed (Decals3D.placeOn); null for anything else.
- `distance`: How far along the ray, in world units from its start (a camera's near plane).
- `getPoint`: Where in the world, axis 0 (x), 1 (y) or 2 (z).
- `getLocalPoint`: Where in the node's own space (a skinned model's as posed), axis 0, 1 or 2.
- `getNormal`: The surface's normal in the world, a unit vector facing back along the ray, axis 0, 1 or 2.

## PointLight3D

*class* in [`src/helix/render3d/PointLight3D.hx`](../../src/helix/render3d/PointLight3D.hx), `import helix.render3d.PointLight3D;`

A light from its node's position in every direction, fading with distance, out to its range. It casts no shadows: it would need a map each way.

```haxe
function new()
var range(default, set):Float
```

- `new`: A white point light of intensity 1 and unlimited range.
- `range`: Its range in world units: past it, nothing; 0 for unlimited (falling off with the square of the distance). 0 or more (under 0, or NaN, is 0).

## Projection3D

*abstract* in [`src/helix/render3d/Projection3D.hx`](../../src/helix/render3d/Projection3D.hx), `import helix.render3d.Projection3D;`

How a Camera3D flattens the world onto its viewport: which of its two projections draws (Camera3D.projection).

- `Projection3D.Perspective`: Lines converge toward the eye: fovY radians of vertical view, near above 0.
- `Projection3D.Orthographic`: No perspective: orthographicHeight world units seen top to bottom, the width by the viewport's shape; near may be 0 or less.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Ray3D

*class* in [`src/helix/render3d/Ray3D.hx`](../../src/helix/render3d/Ray3D.hx), `import helix.render3d.Ray3D;`

A ray in the world: where it starts and the way it goes (a unit vector). Camera3D.computeRay makes one through a pixel; Renderer3D.pick follows one.

```haxe
function new()
var originX(get, never):Float
var originY(get, never):Float
var originZ(get, never):Float
var directionX(get, never):Float
var directionY(get, never):Float
var directionZ(get, never):Float
function set(x:Float, y:Float, z:Float, dx:Float, dy:Float, dz:Float):Bool
function at(distance:Float, axis:Int):Float
function pointAt(distance:Float, ?out:Point3D):Point3D
function hitPlane(nx:Float, ny:Float, nz:Float, d:Float):Float
function hitHeight(y:Float):Float
```

- `new`: A ray from the origin down -z.
- `originX`: Where it starts, x.
- `originY`: Where it starts, y.
- `originZ`: Where it starts, z.
- `directionX`: The way it goes, x (a unit vector's).
- `directionY`: The way it goes, y.
- `directionZ`: The way it goes, z.
- `set`: Starts it at x, y, z going along dx, dy, dz (made a unit vector). False, changing nothing, for a direction of length 0 or one that isn't finite.
- `at`: The point distance along it, axis 0 (x), 1 (y) or 2 (z).
- `pointAt`: The point distance along it, into out (a new one when not given), returned. Given out, it allocates nothing.
- `hitPlane`: How far along it it meets the plane of points p where nx * p.x + ny * p.y + nz * p.z = d (the normal nx, ny, nz, any length), from its origin on: NaN when it runs along the plane or away from it (the plane behind it). With pointAt, where on the ground a click landed, where nothing was there to pick.
- `hitHeight`: How far along it it reaches the height y (the plane y = y, the ground at 0): hitPlane(0, 1, 0, y). NaN when it never does.

## Skin3D

*class* in [`src/helix/render3d/Skin3D.hx`](../../src/helix/render3d/Skin3D.hx), `import helix.render3d.Skin3D;`

A skin: the joints a skinned mesh's vertices follow, by name, and each joint's inverse bind matrix (the mesh's space into the joint's, as it was bound). Shared by every model of a file showing it; a Model3D binds its joints to nodes by these names (Model3D.bindSkeleton), so a mesh skinned in one file can follow a skeleton from another with the same joint names. Read, never changed.

```haxe
function new(names:Array<String>, ?inverseBind:Array<Float>)
var jointCount(get, never):Int
function getJointName(index:Int):String
function getBindPosition(index:Int, axis:Int):Float
function getInverseBind(index:Int, i:Int):Float
```

- `new`: A skin of joints named names, inverseBind their inverse bind matrices one after another (16 floats each, column-major; null for identities). Throws for matrices that don't match the names.
- `jointCount`: How many joints.
- `getJointName`: Joint index's name.
- `getBindPosition`: Joint index's place in its mesh's space as bound, axis 0 (x), 1 (y) or 2 (z).
- `getInverseBind`: Joint index's inverse bind matrix's element at (column-major) i.

## SpotLight3D

*class* in [`src/helix/render3d/SpotLight3D.hx`](../../src/helix/render3d/SpotLight3D.hx), `import helix.render3d.SpotLight3D;`

A point light's falloff out to its range, within a cone around its node's -z: full inside its inner cone, fading to nothing at its outer. It may cast shadows (shadowCasting), over its cone out to its range (or its shadow distance, the nearer).

```haxe
function new()
var range(default, set):Float
var innerCone(get, never):Float
var outerCone(get, never):Float
function setCone(inner:Float, outer:Float):Bool
```

- `new`: A white spot of intensity 1 and unlimited range, its cones 0.3 and 0.4 radians from its axis.
- `range`: Its range in world units: past it, nothing; 0 for unlimited (falling off with the square of the distance). 0 or more (under 0, or NaN, is 0).
- `innerCone`: Its inner cone, radians from its axis: full light inside it.
- `outerCone`: Its outer cone, radians from its axis: no light past it, fading from the inner one.
- `setCone`: Sets its cones, radians from its axis. False, changing nothing, unless 0 <= inner <= outer < pi/2.

## Sprite3D

*class* in [`src/helix/render3d/Sprite3D.hx`](../../src/helix/render3d/Sprite3D.hx), `import helix.render3d.Sprite3D;`

A sprite: a texture (or a region of it) on a quad, 1 x 1 world units by default, its pivot at its position, facing the camera, blended by its alpha, unlit, tinted (0xAARRGGBB, sRGB, as 2D sprites are). Its scale scales it; its rotation turns it only when its facing is its own (Ground, Free).

```haxe
function new(texture:Null<Texture2D>, ?tint:Int = 0xffffffff)
var texture:Null<Texture2D>
var tint:Int
var effect:Null<SpriteEffect>
function setRegion(x:Float, y:Float, width:Float, height:Float):Void
var regionX(default, null):Float
var regionY(default, null):Float
var regionWidth(default, null):Float
var regionHeight(default, null):Float
var spriteWidth(default, null):Float
var spriteHeight(default, null):Float
function setSpriteSize(width:Float, height:Float):Bool
function setPivot(x:Float, y:Float):Void
var pivotX(default, null):Float
var pivotY(default, null):Float
var facing:SpriteFacing3D
var alphaMode(default, null):AlphaMode
var alphaCutoff(get, never):Float
function setAlphaMode(mode:AlphaMode, ?cutoff:Float = .5):Bool
```

- `new`: A sprite of texture (null for none yet: it draws nothing), tinted (0xAARRGGBB, white for none).
- `texture`: Its texture, or null.
- `tint`: Its tint, 0xAARRGGBB (sRGB).
- `effect`: The effect it draws through (a sprite shader: helix.shader' SpriteOutline, SpriteFlash, SpriteDissolve, PaletteSwap, or an app's SpriteEffect; its shader's sprite3D variant, its alpha mode applied as ever), or null (the default) for the framework's sprite program. Shared, as a 2D sprite's: the sprites given one draw with its values at the stage's time, and alike ones beside each other in the draw order (a texture, an alpha mode, an effect) are one draw.
- `setRegion`: Its region of its texture, in texels from its top-left; a width or height of 0 or less (the default) shows the whole texture.
- `regionX`: Its region's left, in texels.
- `regionY`: Its region's top, in texels.
- `regionWidth`: Its region's width in texels (0 or less: the whole texture).
- `regionHeight`: Its region's height in texels (0 or less: the whole texture).
- `spriteWidth`: Its width in world units, before its scale (1 by default).
- `spriteHeight`: Its height in world units, before its scale (1 by default).
- `setSpriteSize`: Sizes it, in world units before its scale. False, changing nothing, for a size below 0.
- `setPivot`: Sets the point at its position, which it turns and scales about, as a fraction of its size: 0, 0 its top-left, 1, 1 its bottom-right (0.5, 0.5, its center, by default).
- `pivotX`: Its pivot's x fraction.
- `pivotY`: Its pivot's y fraction.
- `facing`: How it faces.
- `alphaMode`: How its texels' alpha is used.
- `alphaCutoff`: The alpha below which a Mask sprite's texels are cut out (0..1).
- `setAlphaMode`: Sets how it uses its texels' alpha, and a Mask's cutoff (0..1, 0.5 by default). False, changing nothing, for a cutoff outside 0..1.

## SpriteFacing3D

*abstract* in [`src/helix/render3d/SpriteFacing3D.hx`](../../src/helix/render3d/SpriteFacing3D.hx), `import helix.render3d.SpriteFacing3D;`

How a 3D sprite or text faces.

- `SpriteFacing3D.Camera`: The camera, square to its view: a coin, a glow, a particle.
- `SpriteFacing3D.Upright`: The camera, turning about y and staying upright: a tree, a character drawn flat.
- `SpriteFacing3D.Ground`: Flat, its texture's top toward its node's -z, facing its node's +y (the ground's up, unturned): a decal, a shadow blob.
- `SpriteFacing3D.Free`: As its node is turned: in the node's x-y plane, facing its +z. A sign.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Text3D

*class* in [`src/helix/render3d/Text3D.hx`](../../src/helix/render3d/Text3D.hx), `import helix.render3d.Text3D;`

A line of text in the world: its value, size world units tall (ascent to descent), in a font (null: the stage's built-in one), its block's pivot at its position (its center by default), facing the camera, in a color (0xAARRGGBB, sRGB). Unlit and blended, as sprites are, and sharp at any distance (a distance-field font). Pivoted and faced as a sprite. Not pickable until pickable is set: a label lets a pick through to what it's on.

```haxe
function new(value:String, ?size:Float = .5, ?color:Int = 0xffffffff, ?font:Font)
var text:String
var textSize(get, set):Float
var color:Int
var font:Null<Font>
function setPivot(x:Float, y:Float):Void
var pivotX(default, null):Float
var pivotY(default, null):Float
var facing:SpriteFacing3D
function measureWidth():Float
function measureHeight():Float
```

- `new`: value, size world units tall (a size of 0 or less is 0.5), in color, in font (null: the stage's built-in one).
- `text`: Its text.
- `textSize`: Its size, world units tall. At least 1e-6 (0 or less, or NaN, is 1e-6).
- `color`: Its color, 0xAARRGGBB (sRGB).
- `font`: Its font, or null for the stage's built-in one.
- `setPivot`: Sets the point of its block at its position, which it turns and scales about, as a fraction of its size: 0, 0 its top-left, 1, 1 its bottom-right (0.5, 0.5, its center, by default).
- `pivotX`: Its pivot's x fraction.
- `pivotY`: Its pivot's y fraction.
- `facing`: How it faces.
- `measureWidth`: Its width in its own units, in its font (the built-in one when it has none), as Text2D measures.
- `measureHeight`: Its height in its own units: its size (one line, ascent to descent), as Text2D measures.

## Tonemap

*abstract* in [`src/helix/render3d/Tonemap.hx`](../../src/helix/render3d/Tonemap.hx), `import helix.render3d.Tonemap;`

How a stage brings lit color, which can run past 1 (bright lights, an HDR environment), into the 0..1 a screen shows, after its exposure.

- `Tonemap.None`: Clamped: everything past 1 is 1, so highlights flatten to white and shift hue.
- `Tonemap.Neutral`: Khronos PBR Neutral: colors unchanged until highlights roll off; glTF viewers' default.
- `Tonemap.Aces`: ACES filmic (Narkowicz's fit): more contrast, highlights shifting toward white.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Track3D

*class* in [`src/helix/render3d/Track3D.hx`](../../src/helix/render3d/Track3D.hx), `import helix.render3d.Track3D;`

One node's motion along one path in a clip: the node by name, its keys' times (seconds, rising) and values.

```haxe
function new(target:String, path:TrackPath3D, interpolation:TrackInterpolation3D, times:Array<Float>, values:Array<Float>)
static function slerp(ax:Float, ay:Float, az:Float, aw:Float, bx:Float, by:Float, bz:Float, bw:Float, t:Float, out:haxe.ds.Vector<Float>):Void
final target:String
final path:TrackPath3D
final interpolation:TrackInterpolation3D
final times:haxe.ds.Vector<Float>
final values:haxe.ds.Vector<Float>
function sample(seconds:Float, out:haxe.ds.Vector<Float>):Void
```

- `new`: A track moving target's path through times and values. Throws for values that don't match the times, or times that fall.
- `slerp`: The rotation t of the way from quaternion a to b along the shorter arc, into out (normalized).
- `target`: The node it moves, by name: bound under whatever an Animator3D plays it on.
- `path`: What it moves.
- `interpolation`: How it runs between keys.
- `times`: Its keys' times, seconds, rising.
- `values`: Its keys' values, one after another (3 floats a key, or 4 for a rotation; for a cubic spline, the in-tangent, value and out-tangent of each key).
- `sample`: Its value at seconds (held before its first key and after its last), into out (3 floats, or 4 for a rotation, normalized).

## TrackInterpolation3D

*abstract* in [`src/helix/render3d/TrackInterpolation3D.hx`](../../src/helix/render3d/TrackInterpolation3D.hx), `import helix.render3d.TrackInterpolation3D;`

How a track's keys run between them, glTF's three.

- `TrackInterpolation3D.Linear`: A straight line (a rotation's spherical one).
- `TrackInterpolation3D.Step`: Held until the next key.
- `TrackInterpolation3D.CubicSpline`: A cubic Hermite spline through the keys, each key its in-tangent, value and out-tangent.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## TrackPath3D

*abstract* in [`src/helix/render3d/TrackPath3D.hx`](../../src/helix/render3d/TrackPath3D.hx), `import helix.render3d.TrackPath3D;`

What a track moves: its node's position, rotation (a quaternion) or scale.

- `TrackPath3D.Translation`: Its position: x, y, z.
- `TrackPath3D.Rotation`: Its rotation: a quaternion x, y, z, w.
- `TrackPath3D.Scale`: Its scale: x, y, z.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## View3D

*class* in [`src/helix/render3d/View3D.hx`](../../src/helix/render3d/View3D.hx), `import helix.render3d.View3D;`

A 3D tree shown through a camera (docs/DISPLAY_MODEL.md): a display object, placed on the stage or in a 2D tree, showing content's children through camera in its rectangle (View). It holds the photography: the camera, the exposure and the tone mapping; the light is the place's (Node3D.environment), unless the view's own environment overrides it. Drawn under every 2D thing in the frame, as Flash's Stage3D content was under its display list: the 2D batch sends its draws once, at the frame's end. With a postProcess chain (View.postProcess) it's drawn into a texture instead and placed in the 2D's order like any 2D thing, so 2D drawn before it is under it. The view sizes the camera's viewport to its rectangle as it draws. Several views can show one tree (split screen); each draws it for itself.

```haxe
function new(content:Node3D, ?camera:Camera3D, ?width:Float = 0., ?height:Float = 0., ?gpu:IGraphics)
var content(default, null):Node3D
var camera:Camera3D
var environment:Null<Environment3D>
var tonemap:Tonemap
var exposure(default, set):Float
var drawnNodeCount(get, never):Int
var drawCallCount(get, never):Int
var shadowCasterCount(get, never):Int
var shadowDrawCallCount(get, never):Int
function computeRay(x:Float, y:Float, ?out:Ray3D):Null<Ray3D>
function project(x:Float, y:Float, z:Float, ?out:Point2D):Null<Point2D>
function drawToTexture(target:Texture2D, ?clearColor:Int = 0x00000000):Void
function destroy():Void
```

- `new`: A view of content's children through camera (a new one unless given), width x height of its own units (0 for the whole area of what shows it), drawn on gpu (the program's, Graphics.instance, unless given).
- `content`: The tree whose children it shows.
- `camera`: What it's seen through: its eye, projection and lens the app's, its viewport the view's rectangle.
- `environment`: The light it shows its tree in, overriding the tree's (Node3D.environment), or null for the tree's own: a minimap's flat light, an editor's preview.
- `tonemap`: How lit color comes into the screen's 0..1 after the exposure (Khronos PBR Neutral to start).
- `exposure`: The exposure in stops (EV): each one doubles the light before the tone mapping; 0 to start. An exposure that isn't finite is 0.
- `drawnNodeCount`: How many models the last frame drew, the ones outside the camera's view culled.
- `drawCallCount`: How many draws the last frame took for its tree.
- `shadowCasterCount`: How many models cast into the shadow maps the last frame.
- `shadowDrawCallCount`: How many draws the last frame's shadow maps took.
- `computeRay`: The ray from its camera's eye through the stage point x, y (the stage's units, as a game holds the pointer: Screen.toUnitsX of its pixels), into out (a new one when not given), returned, as the view was last drawn: with Ray3D.hitHeight and pointAt, where on the ground a click landed. Null for a point outside where it's shown, or before its first draw. Given out, it allocates nothing.
- `project`: Where the world point x, y, z of its tree is seen, in the stage's units (where a label over a head, an arrow to something off screen or a 2D burst from a 3D chest goes on the stage), into out (a new one when not given), returned, as the view was last drawn; a point off its sides lands off them. Null for a point behind its camera. Given out, it allocates nothing.
- `drawToTexture`: Draws its tree through its camera into target (a Texture2D.renderTarget with depth), cleared to clearColor (0xAARRGGBB): a picture taken when asked (a tile's portrait, an inventory icon), not each frame. Its shadows are drawn first. Outside a frame only: in init or update, before the runner opens the frame.
