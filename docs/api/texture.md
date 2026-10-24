# helix.texture

[Back to the index](README.md)

## Sampling

*abstract* in [`src/helix/texture/Sampling.hx`](../../src/helix/texture/Sampling.hx), `import helix.texture.Sampling;`

How a draw samples a texture: its filter (linear, smooth and through its mipmaps when it has them; or nearest, sharp, for pixel art) and how it wraps along u and v. A small value, passed with each texture a draw uses; adapters keep one sampler for each that is used.

```haxe
static final NEAREST(default, null):Sampling
static final LINEAR(default, null):Sampling
var linear(get, never):Bool
var wrapU(get, never):Wrap
var wrapV(get, never):Wrap
function withLinear(value:Bool):Sampling
function withWrap(wrapU:Wrap, wrapV:Wrap):Sampling
static inline var COUNT:Int
```

- `NEAREST`: Nearest, clamped: pixel art.
- `LINEAR`: Linear, clamped: smooth.
- `linear`: Whether it filters linearly.
- `wrapU`: How it wraps along u.
- `wrapV`: How it wraps along v.
- `withLinear`: The same with linear filtering or not.
- `withWrap`: The same wrapping as wrapU and wrapV.
- `COUNT`: Every value there is, 0 to COUNT - 1, for an adapter's table of samplers.

## Texture2D

*class* in [`src/helix/texture/Texture2D.hx`](../../src/helix/texture/Texture2D.hx), `import helix.texture.Texture2D;`

A GPU texture with its size, its format and how it is sampled (Sampling: linear or nearest, and its wrap), which a draw reads when it takes the texture, so one texture can be drawn smooth and then sharp. whiteU/whiteV name an opaque white texel, -1 when it has none, for untextured shapes.

```haxe
static function fromRgba(width:Int, height:Int, rgba:haxe.io.Bytes, ?linear:Bool = false, ?whiteX:Int = -1, ?whiteY:Int = -1, ?mipmaps:Bool = false, ?gpu:IGraphics):Texture2D
static function fromLevels(width:Int, height:Int, levels:Array<haxe.io.Bytes>, format:TextureFormat, sampling:Sampling, ?gpu:IGraphics):Texture2D
static function renderTarget(width:Int, height:Int, ?linear:Bool = true, ?format:TextureFormat = Rgba8, ?depth:Bool = true, ?gpu:IGraphics):Texture2D
var handle(default, null):Int
var width(default, null):Int
var height(default, null):Int
var format(default, null):TextureFormat
var levelCount(get, never):Int
var byteCount(get, never):Int
var sampling:Sampling
var whiteU(default, null):Float
var whiteV(default, null):Float
function destroy(?gpu:IGraphics):Void
```

- `fromRgba`: Uploads width x height RGBA8 pixels, rows top first, sampled linear (smooth) or nearest (sharp, for pixel art); whiteX, whiteY name an opaque white texel for untextured shapes, -1 for none. mipmaps adds a chain (Mipmaps.build), so it can be drawn smaller than itself without shimmering. On gpu, the program's (Graphics) when not given. The caller destroys it.
- `fromLevels`: Uploads levels (the image and its mipmaps, each format.levelBytes of its size) of format, width x height, sampled as sampling says. Throws when the GPU can't sample format (IGraphics.canSample). On gpu, the program's (Graphics) when not given. The caller destroys it.
- `renderTarget`: A render target width x height of format: a texture drawn into by target passes (IGraphics.beginTargetPass with its handle), sampled linear (smooth) or nearest (sharp: a low-resolution view shown larger); with depth a depth buffer and the screen's multisampling, without neither (IGraphics.createRenderTarget). Throws for a format the GPU can't draw into (IGraphics.canRender). On gpu, the program's (Graphics) when not given. The caller destroys it.
- `handle`: The IGraphics handle, for draws.
- `width`: Width in texels.
- `height`: Height in texels.
- `format`: Its texels' format: RGBA8, or a compressed one.
- `levelCount`: How many levels it has: 1, or the image and its mipmaps.
- `byteCount`: The GPU memory its levels take, in bytes.
- `sampling`: How draws sample it, from the next draw that takes it on.
- `whiteU`: U of the center of an opaque white texel, or -1 when it has none.
- `whiteV`: V of the center of an opaque white texel, or -1 when it has none.
- `destroy`: Frees the GPU texture on gpu, the adapter that made it: the program's (Graphics) when not given.

## TextureFormat

*abstract* in [`src/helix/texture/TextureFormat.hx`](../../src/helix/texture/TextureFormat.hx), `import helix.texture.TextureFormat;`

What a texture's texels are: plain RGBA8, a GPU's compressed format (4x4 blocks of 16 bytes each), which only some GPUs sample (IGraphics.canSample), or half floats, linear light beyond 1 (an environment's cubes). The 8-bit and compressed ones' colors are sRGB values, as the shaders treat them.

- `TextureFormat.Rgba8`: 4 bytes a texel, rows top first.
- `TextureFormat.Bc7`: BC7 (BPTC): desktops.
- `TextureFormat.Astc4x4`: ASTC 4x4: phones.
- `TextureFormat.Etc2Rgba8`: ETC2 RGBA8 (with EAC alpha): older phones.
- `TextureFormat.Rgba16f`: RGBA half floats (IEEE binary16, little-endian), 8 bytes a texel, rows top first; filtered linearly where canSample says so.

```haxe
function levelBytes(width:Int, height:Int):Int
function toString():String
```

- `levelBytes`: The bytes of a level width x height (of one face, for a cube).
- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.

## Textures

*class* in [`src/helix/texture/Textures.hx`](../../src/helix/texture/Textures.hx), `import helix.texture.Textures;`

Textures from image files, shared by path and reloading in place when a file changes during development (TextureCache). The program's one, a static class: each member forwards to instance, written by helix.macro.Facade from TextureCache's public members with their doc comments.

```haxe
static function getCandidates(path:String):Array<String>
static function getPath(texture:Texture2D):Null<String>
static function load(path:String, linear:Bool, loaded:Texture2D -> Void, ?failed:String -> Void):IRequest
static function decode(encoded:haxe.io.Bytes, linear:Bool, decoded:Texture2D -> Void, ?failed:String -> Void):IRequest
static function release(texture:Texture2D):Void
```

- `getCandidates`: The files path loads from, in order, the first that loads winning: a "name.ktx" this GPU's compressed variants then name.png; any other path itself.
- `getPath`: The file texture was loaded from (for a "name.ktx", the one chosen), or null for one this service didn't load.
- `load`: Loads path into a texture: linear samples it smoothly, with mipmaps so it can be drawn smaller without shimmering; otherwise nearest, for pixel art (Texture2D.sampling changes it later). A "name.ktx" loads this GPU's variant or else name.png (getCandidates). Loads of the same path and filter share one texture (a load under way is joined, not started again), so its sampling is theirs together; each load releases it once (release), and the last frees it. One of loaded or failed runs once on the host thread, and neither once the request is cancelled; failed (else the log, with the path) for a closed service, or when no candidate loads and decodes.
- `decode`: Decodes encoded image bytes (a file's contents already in memory, such as a model's embedded image) into a texture, as load does but with nothing to reload: the caller owns the texture and destroys it. One of decoded or failed runs once on the host thread, and neither once the request is cancelled; failed (else the log) for a closed service or bytes that don't decode.
- `release`: Lets go of a texture this service loaded, once for each load that gave it: the last release frees it and stops reloading it.

## Wrap

*abstract* in [`src/helix/texture/Wrap.hx`](../../src/helix/texture/Wrap.hx), `import helix.texture.Wrap;`

How a texture's edges repeat past 0..1.

- `Wrap.Clamp`: The edge texel carries on.
- `Wrap.Repeat`: The texture tiles.
- `Wrap.Mirror`: The texture tiles, every other copy mirrored.

```haxe
function toString():String
```

- `toString`: The value's name, as written (Stopped, Playing): what Std.string, interpolation and trace show.
