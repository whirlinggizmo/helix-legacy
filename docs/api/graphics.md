# helix.graphics

[Back to the index](README.md)

## AlphaMode

*abstract* in [`src/helix/graphics/AlphaMode.hx`](../../src/helix/graphics/AlphaMode.hx), `import helix.graphics.AlphaMode;`

How a sprite or a particle uses its texels' alpha, the same in 2D and 3D (Sprite3D.alphaMode, Emitter.alphaMode). In 3D it also says when it's drawn among the models: with the opaque ones, among the see-through ones back to front, or after everything.

- `AlphaMode.Opaque`: Ignored: drawn solid (in 3D, with the opaque models).
- `AlphaMode.Mask`: Texels below a cutoff are cut out, the rest solid: leaves, fences (in 3D, drawn with the opaque models).
- `AlphaMode.Blend`: Blended by it (in 3D, among the see-through models back to front).
- `AlphaMode.Add`: Added, times it: light, fire, glows (in 3D, after everything else).

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## BlendMode

*abstract* in [`src/helix/graphics/BlendMode.hx`](../../src/helix/graphics/BlendMode.hx), `import helix.graphics.BlendMode;`

How a pipeline's colors meet what the framebuffer has: replacing it, blended over it by their alpha (straight alpha), or added to it (times their alpha: light, fire, glows).

- `BlendMode.Opaque`: Replaces what's there.
- `BlendMode.Alpha`: Blended over what's there by its alpha.
- `BlendMode.Additive`: Added to what's there, times its alpha.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## ClipFlip

*abstract* in [`src/helix/graphics/ClipFlip.hx`](../../src/helix/graphics/ClipFlip.hx), `import helix.graphics.ClipFlip;`

What uniform block 0 holds, so an adapter whose render targets are stored upside down (GL's bottom-left origin) can draw a target the right way up: nothing it touches, a clip scale it writes (x 1, y -1 in such a pass, else 1), or a view-projection matrix (column-major, its first 64 bytes) whose y row it negates in such a pass.

- `ClipFlip.None`: Block 0 isn't touched (or there is none).
- `ClipFlip.ClipScale`: Block 0 is a vec4 clip scale the adapter writes.
- `ClipFlip.ViewProjection`: Block 0 starts with a view-projection matrix whose y row the adapter negates.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Color

*class* in [`src/helix/graphics/Color.hx`](../../src/helix/graphics/Color.hx), `import helix.graphics.Color;`

Colors as HeliX holds them: 0xAARRGGBB integers, alpha in the top byte, as Haxe's libraries write them and as an editor's color picker reads a literal. Each channel is 0 to 255. Text names a color the CSS way, #RRGGBB or #RRGGBBAA (a scene file, a color picker's field), converted by fromRgba and toRgba.

```haxe
static function fromChannels(red:Int, green:Int, blue:Int, ?alpha:Int = 255):Int
static function getRed(color:Int):Int
static function getGreen(color:Int):Int
static function getBlue(color:Int):Int
static function getAlpha(color:Int):Int
static function withAlpha(color:Int, alpha:Int):Int
static function fromRgba(rgba:Int):Int
static function toRgba(color:Int):Int
```

- `fromChannels`: The color of these channels, each 0 to 255 (only its low 8 bits are taken), alpha opaque unless given.
- `getRed`: color's red, 0 to 255.
- `getGreen`: color's green, 0 to 255.
- `getBlue`: color's blue, 0 to 255.
- `getAlpha`: color's alpha, 0 (clear) to 255 (opaque).
- `withAlpha`: color with its alpha replaced by alpha, 0 to 255 (only its low 8 bits are taken).
- `fromRgba`: The color an 0xRRGGBBAA integer names (the CSS order, as text writes it).
- `toRgba`: color as an 0xRRGGBBAA integer (the CSS order, as text writes it).

## DepthTest

*abstract* in [`src/helix/graphics/DepthTest.hx`](../../src/helix/graphics/DepthTest.hx), `import helix.graphics.DepthTest;`

Which fragments a pipeline's depth test passes, against the depth already there.

- `DepthTest.Off`: No test: every fragment is drawn.
- `DepthTest.LessEqual`: Nearer or as near: what's in front (the usual test).
- `DepthTest.Greater`: Farther: only where something nearer was drawn before (what's hidden behind it).

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Graphics

*class* in [`src/helix/graphics/Graphics.hx`](../../src/helix/graphics/Graphics.hx), `import helix.graphics.Graphics;`

The GPU: textures, buffers, shaders, pipelines, passes and draws. Shutting it down is the runner's, and so is the frame: the runner opens and closes it around the stage's drawing (docs/DISPLAY_MODEL.md), so beginFrame and endFrame aren't here; a pass into a texture (beginTargetPass) is drawn in init or update, before the frame opens. The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from IGraphics's public members with their doc comments.

```haxe
static function canSample(format:TextureFormat):Bool
static var msaaSamples(get, never):Int
static var maxMsaaSamples(get, never):Int
static function canRender(format:TextureFormat):Bool
```

- `canSample`: Whether this GPU samples textures of format: RGBA8 always; the compressed ones on GPUs that have them; half floats where it filters them.
- `msaaSamples`: Multisampling samples a pixel the screen is drawn with (WindowOptions.requestMsaaSamples): 1 for none, else what the platform gave, which may be fewer than asked. Render targets with depth are drawn with the same, resolved into the texture sampled.
- `maxMsaaSamples`: The most multisampling samples a pixel a window could ask for here, at most 8 (what requestMsaaSamples takes): for a settings menu to offer, applied at the next start. Natively the GPU's most; a browser only switches antialiasing on or off, choosing its own count, so there it's the count the canvas has when on (4 where the GPU has 4, else 1).
- `canRender`: Whether this GPU draws into render targets of format, blends over them and filters them when sampled: RGBA8 always; RGBA16F where float targets exist (natively nearly always; in a browser through EXT_color_buffer_float, turned on by asking); never a compressed one.

## PostProcess

*class* in [`src/helix/graphics/PostProcess.hx`](../../src/helix/graphics/PostProcess.hx), `import helix.graphics.PostProcess;`

Screen effects over a finished frame: the scene is drawn into a texture the screen's size (beginScene to endScene, a target pass), the enabled effects but the last draw in turn from one texture into another (target passes without depth, still before the screen's), and present draws the last over the screen's pass, or the frame as it is when no effect is on. Effects run in the order added, so turning one off and on (ScreenEffect.enabled) keeps its place. Its textures follow the screen's size; an effect's intermediates (ScreenEffect.intermediates) are made at their fractions of it.

An HDR chain: when an enabled effect wants HDR (ScreenEffect.hdr) and the GPU draws half floats (IGraphics.canRender), the scene is drawn in RGBA16F, the 3D views drawing into it (View3D: the stage tells them, View) writing their light after the exposure with no tone mapping, as sRGB values running past 1 (the sRGB curve carried on past 1, so sprites, particles and text, whose colors are sRGB values already, blend into it as into the screen, and are tone mapped with it). The tone mapping then runs as an effect (helix.shader.Tonemap, Neutral unless the chain has its own), after the last effect wanting HDR, unless the chain has one of its own; the effects before it read and write half floats, the ones after it the tone-mapped frame in RGBA8. Without half floats every texture is RGBA8 as the screen is, the 3D views tone map as they draw, and a Tonemap in the chain is skipped. An HDR scene is cleared to what its tone mapping shows as the clear color (Tonemap.computeHdrColor), so a background of clear color alone looks the same with the chain HDR or not.

```haxe
function new(?gpu:IGraphics)
var hdr(default, null):Bool
var sceneTexture(get, never):Null<Texture2D>
function add(effect:ScreenEffect):Bool
function remove(effect:ScreenEffect):Bool
function beginScene(width:Int, height:Int, clearColor:Int):Void
function endScene(time:Float):Void
function present():Void
function destroy():Void
```

- `new`: Effects drawn on gpu (the program's, Graphics, when not given), over a scene (the stage's, Stage.postProcess, or a view's, View.postProcess).
- `hdr`: Whether this frame's scene (the last beginScene's) is drawn in half floats: an enabled effect wants HDR and the GPU draws them.
- `sceneTexture`: The texture the scene is drawn into (the last beginScene's), or null before one.
- `add`: Adds effect at the end of the chain. False, changing nothing, when it is in the chain already.
- `remove`: Takes effect out of the chain, freeing its intermediates (the effect stays its owner's). False when it isn't in the chain.
- `beginScene`: Starts the frame's scene: a target pass into a width x height texture (the screen's size; half floats in an HDR chain), cleared to clearColor (0xAARRGGBB; in an HDR chain to the light its tone mapping shows as clearColor). Draw it as the screen; endScene ends it. Which effects draw this frame is taken here. Throws inside another pass.
- `endScene`: Ends the scene's pass and draws the effects but the last (each that was enabled at beginScene, in order, with the tone mapping in an HDR chain), each its intermediates and then from the one before's result into a texture of the chain, at time seconds; the last's intermediates too, its last pass waiting for present.
- `present`: Draws the processed frame over the open screen pass's viewport: the last effect over the others' result, or the frame as it is.
- `destroy`: Frees its textures and buffer; the effects stay their owner's.

## ScreenEffect

*class* in [`src/helix/graphics/ScreenEffect.hx`](../../src/helix/graphics/ScreenEffect.hx), `import helix.graphics.ScreenEffect;`

A screen effect: a Shader of kind screen drawn over a whole frame (one triangle over the viewport), with its own parameters and textures set by name (parameters), kept across the shader's reloads. PostProcess chains them (PostProcess.add); drawPass draws its shader once into the open pass. An effect of several passes (a subclass: a blur, a bloom's downsample chain) asks for intermediates, draws into them before its last pass (drawIntermediates, each step a ScreenEffect of its own drawn with drawInto) and reads more than one of them through its own textures (parameters.setTexture).

```haxe
function new(shader:Shader, ?alpha:Bool = false, ?gpu:IGraphics)
var shader(default, null):Shader
var parameters(default, null):ShaderParameters
var enabled:Bool
var hdr:Bool
var intermediates(default, null):Array<Float>
function drawIntermediates(frame:ScreenFrame):Void
function draw(frame:ScreenFrame):Void
function drawInto(target:Texture2D, source:Texture2D, time:Float):Void
function drawPass(source:Texture2D, width:Int, height:Int, time:Float):Void
```

- `new`: An effect drawing with shader (kind screen), blended over what's there when alpha, else replacing it, on gpu (the program's, Graphics, when not given). Throws for a shader of another kind.
- `shader`: Its shader.
- `parameters`: Its shader's own parameters and textures, set by name.
- `enabled`: Whether PostProcess draws it.
- `hdr`: Whether it reads an HDR frame: in a chain with one, PostProcess draws the scene in half floats where the GPU can (IGraphics.canRender), its colors running past 1, and tone maps it after the last such effect (helix.shader.Tonemap). False (the default) for an effect that reads the frame as the screen shows it, tone mapped, 0 to 1.
- `intermediates`: The textures it draws through before its last pass, each its size as a fraction of the frame's each way (.5: half; at least a pixel): PostProcess makes them in the frame's format, without depth, and hands them over in ScreenFrame.intermediates. Empty (the default) for an effect of one pass.
- `drawIntermediates`: Draws its passes before the last into frame.intermediates, each a target pass (drawInto), before the screen's pass: nothing for an effect of one pass (the default).
- `draw`: Draws its last pass over the open pass's viewport, frame.width x frame.height pixels: by default its shader once, reading frame.source.
- `drawInto`: Draws its shader once into target in a target pass of its own (cleared to transparent black), reading source, time seconds since it began: one step of an effect of several passes. Before the screen's pass, outside any other.
- `drawPass`: Draws its shader once over the open pass's viewport, reading source (the frame it changes), width x height pixels, seconds since it began. A texture of its own that isn't set is drawn as source.

## ScreenFrame

*class* in [`src/helix/graphics/ScreenFrame.hx`](../../src/helix/graphics/ScreenFrame.hx), `import helix.graphics.ScreenFrame;`

What a screen effect draws from in a PostProcess chain, this frame: the frame it changes, its size, the time, and the intermediates it asked for (ScreenEffect.intermediates), made by PostProcess at their sizes in the frame's format.

```haxe
function new(source:Texture2D, width:Int, height:Int, time:Float, intermediates:Array<Texture2D>)
final source:Texture2D
final width:Int
final height:Int
final time:Float
final intermediates:Array<Texture2D>
```

- `new`: A frame for an effect: source, width x height framebuffer pixels, time seconds, its intermediates.
- `source`: The frame the effect changes: the scene, or the effect before's result.
- `width`: The size of the frame the effect draws, in framebuffer pixels.
- `height`: The size of the frame the effect draws, in framebuffer pixels.
- `time`: Seconds since the effect began (the time PostProcess.endScene was given).
- `intermediates`: The effect's intermediates, in the order of its ScreenEffect.intermediates: textures without depth, each that fraction of width and height (at least a pixel), half floats where source is.

## ScreenshotResult

*enum* in [`src/helix/graphics/ScreenshotResult.hx`](../../src/helix/graphics/ScreenshotResult.hx), `import helix.graphics.ScreenshotResult;`

How a screenshot ended: where it was saved and its PNG file, or why it wasn't.

- `Saved(where:String, png:haxe.io.Bytes)`
- `Failed(message:String)`

## Screenshots

*class* in [`src/helix/graphics/Screenshots.hx`](../../src/helix/graphics/Screenshots.hx), `import helix.graphics.Screenshots;`

Screenshots of the frame, saved for the user (a download in a browser, a file natively; ScreenshotService). The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from ScreenshotService's public members with their doc comments.

```haxe
static function take(?name:String, ?done:ScreenshotResult -> Void):Void
static function sample(points:Array<Array<Float>>, done:Array<Array<Int>> -> Void, ?failed:String -> Void):Void
```

- `take`: Takes a screenshot of the next frame the app ends, saved as name (a plain file name ending .png; by default prefix, the date and time, and a count, as "asteroids-2026-10-14-153012-1.png"). done, when given, runs once on the host thread after that frame. Failed after shutdown. Throws for a name that isn't a plain .png file name.
- `sample`: Reads the next frame the app ends at points, each [x, y] in the design's units (Screen's; the pixel under it): done runs once on the host thread with each point's color as [r, g, b, a], 0 to 255 (0, 0, 0, 0 off the frame), or failed (else the log) when the frame can't be read or after shutdown. For checks that compare a few pixels across targets (the autopilot's sample), not every frame.

## Shader

*class* in [`src/helix/graphics/Shader.hx`](../../src/helix/graphics/Shader.hx), `import helix.graphics.Shader;`

An app's shader loaded from a .hxshader (src/helix/tool/shader/ShaderPacker.hx; Shaders loads them, the shader library packs its own into the program): its program built on the GPU, its kind ("screen", "surface" or "sprite"), its uniform blocks' sizes, its own parameters by name and its own textures by name. A surface shader comes with its variants, each a Shader of its own over the same parameters: skinned (drawing skinned models) and caster (drawing its shadow, when it has a vertex hook or a discard); a sprite shader with sprite3D (drawing a Renderer3D's sprites). A hot reload replaces the programs in place and bumps reloadCount; their pipelines (Pipelines) are made again over the new programs as they're next asked for.

```haxe
static inline var FORMAT:Int
static function fromText(text:String, ?gpu:IGraphics):Shader
var handle(default, null):Int
var kind(default, null):String
var skinned(default, null):Null<Shader>
var caster(default, null):Null<Shader>
var sprite3D(default, null):Null<Shader>
var reloadCount(get, never):Int
var blockSizes(get, never):Array<Int>
function getParameter(name:String):Null<ShaderParameter>
function getTextureSlot(name:String):Int
var textureSlots(get, never):Array<Int>
function destroy():Void
```

- `FORMAT`: The .hxshader format it reads (src/helix/tool/shader/ShaderPacker.hx's FORMAT).
- `fromText`: Builds a shader, and its variants, from a .hxshader's text on gpu (the program's, Graphics, when not given). Throws, saying why, for a file it can't read or a program that doesn't build. The caller destroys it.
- `handle`: The IGraphics shader handle.
- `kind`: Its kind: "screen" (a screen effect), "surface" (a Renderer3D material's) or "sprite" (a 2D sprite's: a SpriteEffect).
- `skinned`: The same surface shader drawing skinned models: its vertex stage moves each vertex by its joints (the stage's joint texture, at slot 5) before its vertex hook, its fragment stage, parameters and textures this one's. Null for a screen or sprite shader. Its caster draws skinned casters.
- `caster`: The program drawing its shadow casters into a shadow map: the depth pass with its vertex hook, its fragment stage run for what it discards. Null for a surface shader with neither a vertex hook nor a discard, whose shadow the framework's caster draws, and for a screen or sprite shader.
- `sprite3D`: The same sprite shader drawing a Renderer3D's sprites (Sprite3D.effect): its fragment stage over the framework's 3D sprite vertex stage (Sprite3DProgram's records, block 0 the sprites' uniforms), its output applying each sprite's alpha mode; its parameters and textures this one's. Null for a screen or surface shader.
- `reloadCount`: How many times it has been replaced by a reload: a pipeline made before the latest is stale.
- `blockSizes`: Its uniform blocks' sizes in bytes, by slot: 0 for a slot it lacks.
- `getParameter`: One of its own parameters by name, or null.
- `getTextureSlot`: One of its own textures' slot by name, or -1.
- `textureSlots`: The texture slots it samples, the framework's and its own, in order (there may be gaps: a slot it doesn't use).
- `destroy`: Frees the programs, its variants' too, and the pipelines made over them.

## ShaderParameter

*typedef* in [`src/helix/graphics/ShaderParameter.hx`](../../src/helix/graphics/ShaderParameter.hx), `import helix.graphics.ShaderParameter;`

One of a shader's own parameters: its uniform block's slot, its byte offset there, its type (float, vec2, vec3, vec4, mat4) and how many (1 unless an array).

- `type:String`
- `slot:Int`
- `offset:Int`
- `elementCount:Int`

## ShaderParameters

*class* in [`src/helix/graphics/ShaderParameters.hx`](../../src/helix/graphics/ShaderParameters.hx), `import helix.graphics.ShaderParameters;`

An app's shader's own parameters and textures, set by name and kept across the shader's reloads (a name the reloaded shader lacks is kept and ignored), written into its uniform blocks at their std140 offsets when something draws with it. ScreenEffect and Material3D have one.

```haxe
function new(shader:Shader)
function setValues(name:String, values:Array<Float>):Bool
function setFloat(name:String, value:Float):Bool
function setColor(name:String, color:Int):Bool
function getValues(name:String):Null<Array<Float>>
function setTexture(name:String, texture:Texture2D):Bool
function getTexture(name:String):Null<Texture2D>
function write(blocks:Array<Null<haxe.io.Bytes>>):Void
var textureSlots(get, never):Map<Int, Texture2D>
```

- `new`: The parameters of shader.
- `setValues`: Sets parameter name (a float, or a vector's or matrix's first components, an array's elements' in turn) to values; the rest keep theirs. False when the shader has no such parameter or the values don't fit it.
- `setFloat`: Sets a float parameter. False, changing nothing, when the shader has no such parameter.
- `setColor`: Sets a vector parameter to a color 0xAARRGGBB, each channel 0..1 as it is (not decoded from sRGB). False, changing nothing, when the shader has no such parameter or it has fewer than 4 components.
- `getValues`: The values a parameter was set to, or null for one never set (its value is then 0).
- `setTexture`: Binds texture to the shader's own texture name (sampled as the texture's sampling says). False when the shader has no such texture of its own.
- `getTexture`: The texture bound to name, or null.
- `write`: Writes the values set into blocks (the shader's uniform blocks' bytes by slot, null for one it lacks).
- `textureSlots`: The textures set, by the shader's slot.

## Shaders

*class* in [`src/helix/graphics/Shaders.hx`](../../src/helix/graphics/Shaders.hx), `import helix.graphics.Shaders;`

Apps' shaders (.hxshader files, packed from GLSL by src/helix/tool/shader/ShaderPacker.hx; how one is written: docs/SHADERS.md) loaded through the assets and built on the GPU, and built again in place when a file changes during development. The caller releases what it loads.

```haxe
function new(?assets:IAssets, ?gpu:IGraphics)
function load(path:String, loaded:Shader -> Void, ?failed:String -> Void):IRequest
function release(shader:Shader):Void
function reloaded(path:String, bytes:haxe.io.Bytes):Void
```

- `new`: Loads through assets and builds on gpu: the program's (Assets, Graphics) for those not given, read as they're used, so a cache made before the program runs (a field's initial value) works.
- `load`: Loads path (a .hxshader) into a shader. One of loaded or failed runs once on the host thread, and neither once the request is cancelled: loaded once its program is built; failed (else the log, with the path) for a load failure, a file it can't read or a program that doesn't build (with the compiler's log).
- `release`: Frees a shader this service loaded (after the pipelines made with it), and stops reloading it.
- `reloaded`: The file behind loaded shaders changed: they're built again in place. One that no longer builds stays as it was, its log logged as an error.

## SpriteEffect

*class* in [`src/helix/graphics/SpriteEffect.hx`](../../src/helix/graphics/SpriteEffect.hx), `import helix.graphics.SpriteEffect;`

A sprite effect: a Shader of kind sprite (its fragment stage including helix_sprite) that sprites draw through (Node2D.effect: a sprite's, a shape's, a text's or a drawing's own drawing; Batch2D.effect; and a Renderer3D's Sprite3D.effect through its shader's sprite3D variant) in place of the framework's sprite programs, with its own parameters and textures set by name (parameters), kept across the shader's reloads. The library's are in helix.shader (SpriteOutline, SpriteFlash, SpriteDissolve, PaletteSwap); an app's own is a .hxshader (Shaders.load) made into one with new. An effect is shared, not a sprite's own: every sprite drawn with it in a frame draws with its parameters as they are when the batch ends, and the sprites drawn with one effect one after another, of one texture, are one draw. A sprite wanting values of its own (its own flash) has an effect of its own, a draw of its own.

```haxe
function new(shader:Shader)
var shader(default, null):Shader
var parameters(default, null):ShaderParameters
function prepare(time:Float):Void
```

- `new`: An effect drawing with shader (kind sprite). Throws for a shader of another kind.
- `shader`: Its shader.
- `parameters`: Its shader's own parameters and textures, set by name. A texture of its own that isn't set is drawn as the sprite's.
- `prepare`: Brings its parameters to time, seconds of the batch's clock (Batch2D.time), just before a batch draws with it (once for each draw): nothing by default; an effect changing over time (SpriteFlash's fade) overrides it.
