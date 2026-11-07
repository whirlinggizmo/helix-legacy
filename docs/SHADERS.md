# Writing a shader

A game's own shader is a GLSL fragment stage in `shaders/<name>.glsl`. It includes one framework block, which decides its kind and gives it
everything else: the vertex stage, what it reads (the sprite's texture, the frame, the material and the lights) and the function that writes
its color. The build packs it into `assets/shaders/<name>.hxshader`, the game loads that as an asset, and the dev loop packs it again on
save, so the running page redraws with it.

The examples each have one: `examples/sprite2d/shaders/wave.glsl` and `examples/sprite3d/shaders/heat.glsl` (sprite),
`examples/postprocess/shaders/sepia.glsl` (screen), `examples/shaders/shaders/checker.glsl` and `examples/environment/shaders/pearl.glsl`
(surface). The library's own, in `src/helix/shader/*.glsl`, are written the same way and are worked references for each kind.

## The three kinds

| Kind | Block | Draws | The game attaches it with |
| --- | --- | --- | --- |
| sprite | `helix_sprite` | one 2D node's own drawing (a sprite's quad, a shape, a text's glyphs, a drawing's every call), or a 3D view's `Sprite3D` | `node.effect = new SpriteEffect(shader)` (`effect` is on every `Node2D`, and on `Sprite3D`) |
| screen | `helix_screen` | over a whole finished frame, one pixel at a time | `post.add(new ScreenEffect(shader))`, the `PostProcess` being `Stage.postProcess` or a view's `postProcess` |
| surface | `helix_surface` | a 3D model's surface, lit by the stage's lights, with their shadows | `material.setShader(shader)` on a `Material3D` |

- **Sprite**, to change how one thing on the stage looks: a flash, an outline, a wave, a palette, a dissolve. It replaces the framework's
  sprite program for that node's own drawing only, not its children's; an emitter (`Particles2D`) and a view draw through their own
  programs and take no effect. One `SpriteEffect` is shared by every node given it: they draw with its parameters as they are when the
  batch ends, so a node wanting values of its own (its own flash) has an effect of its own.
- **Screen**, to change the whole picture: a color grade, a vignette, a distortion, a fade. It reads the finished frame of the stage, or of
  the view whose `postProcess` holds it, and writes every pixel of it again.
- **Surface**, to change how a 3D material looks: patterns, toon steps, holes, a pulse, waving vertices. It gets the material's values, the
  stage's lights, shadows and environment, and the stage's own shading as a function to call. A material has one surface shader.

## The file, the build and the game

A game keeps its shaders in a `shaders/` directory beside `src/` and `assets/` (the starter has none: make it). The starter's
`hxml/common.hxml` packs them before every build:

```hxml
--macro helix.tool.Build.packShaders()
```

`packShaders` packs each `shaders/<name>.glsl` into `assets/shaders/<name>.hxshader` when its source is newer than its packed file, with
SDL_GPU's dialects too when the build names the `sdl3-gpu` backend. Without a `shaders/` directory it does nothing. `hxml/dev.hxml` runs
`helix.tool.Watchers.watchShaders()` beside the dev server: it packs them once, then again as each is saved and as new ones appear, and the
running page reloads the changed `.hxshader` as an asset. The first pack fetches sokol-shdc, the shader compiler, into the user's cache;
`haxelib run helix-legacy setup` fetches it ahead (BUILDING.md). The library's examples are packed by `tools/example.py` instead, into the build's
shared assets under the same `shaders/<name>.hxshader` path, so they load the same way.

The game loads a packed shader through the assets and wraps it in what its kind is used through:

```haxe
var shaders = new Shaders(); // helix.graphics.Shaders; keep it: it reloads what it loaded, and releases it
shaders.load("shaders/wave.hxshader", shader -> useWave(shader), message -> trace(message));

function useWave(shader:Shader):Void {
	wave = new SpriteEffect(shader); // a sprite shader
	wave.parameters.setFloat("speed", .8);
	logo.effect = wave;
}
```

| Kind | Wrapped by | Its parameters |
| --- | --- | --- |
| sprite | `new SpriteEffect(shader)` (throws for another kind) | `effect.parameters` |
| screen | `new ScreenEffect(shader)`, or `new ScreenEffect(shader, true)` to blend its output over the frame by its alpha rather than replace it (throws for another kind) | `effect.parameters` |
| surface | `material.setShader(shader)` (false, changing nothing, for another kind; `null` goes back to the stage's own shading) | `material.shaderParameters` (empty again whenever the shader changes) |

A screen effect runs once it is in a chain: `var post = new PostProcess(); post.add(sepia); Stage.postProcess = post;` (or a `View3D`'s or
`View2D`'s `postProcess`, for that view alone). `effect.enabled = false` leaves it in the chain undrawn.

A completion calls a method by name (`shader -> useWave(shader)`), never passes the method itself, so it survives a hot reload
(CONVENTIONS.md). The load's failure lambda gets the reason: a file that isn't there, or a program the GPU didn't build.

The classes and where they are: `Shaders`, `Shader`, `SpriteEffect`, `ScreenEffect`, `PostProcess` and `ShaderParameters` in
`helix.graphics`; `Material3D` in `helix.render3d`; `Texture2D` in `helix.texture`.

## The format

```glsl
/* What it does: a comment like any. */
@fs fs
@include_block helix_sprite
layout(binding=2) uniform wave_params {
    float amplitude; // texels sideways at most
    float waves;
    float speed;
};

void main() {
    float phase = 6.2831853 * (helix_quad_uv().y * waves - helix_time() * speed);
    vec4 c = helix_region_texel_at(helix_uv() + vec2(sin(phase) * amplitude * helix_texel_size().x, 0.0)) * helix_tint();
    helix_output(c.rgb, c.a);
}
@end
```

- **One fragment stage, named `fs`:** `@fs fs` up to `@end`. Any other name is refused (`the fragment stage must be "@fs fs"`). It is
  sokol-shdc's GLSL: version 450 style with separate textures and samplers (`texture(sampler2D(tex, smp), uv)`), compiled to GLSL 410 for
  native and GLSL ES 300 for the browser. There is no vertex stage to write; the kind's is the framework's.
- **Exactly one framework block,** `@include_block helix_sprite`, `helix_screen` or `helix_surface`, inside the stage. None, or two, is
  refused (`include exactly one framework block`).
- **Its color is written by calling `helix_output(vec3 color, float alpha)`,** the block's, not by writing an output variable: the sprite's
  3D variant applies the sprite's alpha mode there, and a surface's applies the hit flash, rim light, exposure, tone mapping and sRGB
  encoding there.
- **Names beginning `helix_` are the framework's.** A block, texture or function of the game's own takes another name.
- **Functions and constants of its own** go in the stage beside `main`, as in any GLSL.

### Its own parameters: uniform blocks

The values a game sets are members of uniform blocks declared in the stage (`layout(binding=N) uniform <name> { ... };`), each member set by
its name.

- **Bindings 2 to 7.** Blocks 0 and 1 are the framework's: a block of the game's at 0 or 1 is refused (`uniform blocks 0 and 1 are the
  framework's; give p binding 2 or more`); sokol-shdc refuses 8 and up. Two blocks never share a binding, a surface's vertex hook's
  included (`uniform blocks w and q cannot use the same binding 2`).
- **Members are `float`, `vec2`, `vec3`, `vec4` and `mat4`,** and arrays of `vec4` or `mat4` (`vec4 weights[4];`). Anything else is refused:
  `int`, `ivec*`, `bool`, `mat3`, a struct (`unsupported member` or `must flatten to one vec4 array`), and an array of `float`, `vec2` or
  `vec3` (sokol-shdc: `arrays must be of type vec4[], ivec4[] or mat4[]`; pack four floats into a `vec4` array instead).
- **One member a declaration:** `float a; float b;`, not `float a, b;` (refused), and no precision qualifiers.
- **Laid out by std140,** which the packer works out and the parameters follow, so the game never counts bytes: a `vec3` takes 16 bytes'
  alignment and 12 of room (a `float` after it fills its fourth component), each array element and each matrix column 16 bytes apart.
- **Names are unique across the shader's blocks:** parameters are found by member name alone.
- **A block nothing reads is left out by the compiler,** and its members with it: setting one then returns false. A block that is read
  keeps all its members.
- **A member never set is 0.** Set every parameter the shader needs once it loads (a `speed` left at 0 stands still).

### Its own textures

A texture of the game's own is a `texture2D` and a `sampler` at the same binding, the texture named as the game sets it:

```glsl
layout(binding=1) uniform texture2D palette;
layout(binding=1) uniform sampler palette_sampler;
// ... texture(sampler2D(palette, palette_sampler), uv)
```

| Kind | The framework's texture bindings | The game's | One the game hasn't set |
| --- | --- | --- | --- |
| sprite | 0: the sprite's texture | 1 to 11 | the sprite's texture |
| screen | 0: the frame | 1 to 11 | the frame |
| surface | 0 base color, 1 normal map, 2 shadow maps, 3 environment, 4 BRDF table, 5 joints (skinned variant) | 6 to 11 | white |

A texture at a framework binding is refused (`texture mine needs binding 6 or more`), as is one whose sampler is at another binding or
missing (`must share a binding`, `every texture needs a sampler`); sokol-shdc refuses 12 and up. The texture is sampled as its `Texture2D`'s
`sampling` says (nearest or linear, repeat or clamp), whatever the GLSL's sampler is named. `parameters.setTexture("palette", texture)`
binds it; false for a name the shader hasn't, or one beginning `helix_`.

### A surface's vertex hook

A surface shader (only a surface: a sprite or screen shader with one is refused, `only a surface shader has a vertex hook`) may move its
vertices in a `@block vertex` before `@fs fs`, defining `helix_vertex`:

```glsl
@block vertex
layout(binding=3) uniform wave_motion { // the fragment stage's block is at 2: bindings are shared by both stages
    float lift;
};
void helix_vertex(inout vec3 position, inout vec3 normal) {
    position += normal * sin(helix_time() * 3.0) * lift;
}
@end
```

- `position` and `normal` are in the model's own space, as posed (after skinning, for a skinned model), before the model is placed in the
  world. Change either; the normal is used as the hook leaves it (keep it unit length).
- The hook may call `helix_time()` and read uniform blocks of its own, set by name like the fragment stage's, at bindings neither the
  framework nor the fragment stage uses.
- The fragment stage's `helix_model_position()` and `helix_model_normal()` are the vertex before skinning and the hook, so a pattern laid by
  them stays on the surface as it moves.
- A shader with a hook, or with a `discard` anywhere outside a comment, is packed with shadow casters running the hook (and the fragment
  stage, for what it discards), so its shadow moves and opens with it. A surface cut open by `discard` usually wants
  `material.doubleSided = true`.

Every surface shader is also packed with a skinned variant, so it draws skinned models as it does the others; nothing in the source changes.
Every sprite shader is packed with a variant for 3D sprites (`Sprite3D.effect`), applying the sprite's `alphaMode` in its `helix_output`.

## The sprite kind: `helix_sprite`

For `Node2D.effect` and `Sprite3D.effect` (`helix.graphics.SpriteEffect`). Colors are sRGB values, 0 to 1, as the framebuffer holds them.

| GLSL | Returns |
| --- | --- |
| `vec4 helix_sprite_color()` | The color here as the framework would draw it: the texel times the tint; for text, the glyph's coverage (its distance field smoothed) in the tint. sRGB values, alpha 0..1. |
| `vec2 helix_uv()` | The texture coordinate here (in the texture, not the sprite). |
| `vec4 helix_region()` | The sprite's region of its texture: `xy` its top-left's texture coordinate, `zw` its bottom-right's. |
| `vec2 helix_quad_uv()` | Where this is across the sprite's region: 0, 0 its top-left to 1, 1 its bottom-right (0 across a region of no size). |
| `vec4 helix_tint()` | The node's tint, sRGB, alpha 0..1. |
| `vec4 helix_texel_at(vec2 uv)` | The texture at `uv`, untinted. |
| `vec4 helix_region_texel_at(vec2 uv)` | The texture at `uv` when inside the sprite's region (read at least half a texel in from its edge, so an atlas's neighbor never bleeds in); transparent black outside it. |
| `vec2 helix_texture_size()` | The texture's size in texels. |
| `vec2 helix_texel_size()` | One texel's size in texture coordinates. |
| `float helix_time()` | Seconds: the stage's time (below). |
| `void helix_output(vec3 color, float alpha)` | Writes the color: sRGB values and alpha, blended over what is drawn by the node's blend. In a 3D view, applies the sprite's alpha mode too. |
| `helix_sprite_texture`, `helix_sprite_sampler` | The sprite's texture and sampler (binding 0), for `texelFetch` and the like. |

A text's texture is a distance field, not its glyphs' colors: an effect reading the texture away from where the node is (a wave, an
outline) gets the field, so for text use `helix_sprite_color()`, which reads where the node is. A shape is drawn from one white texel of the built-in font's texture, so its color is its tint, and the region and
`helix_quad_uv()` say nothing about where in the shape this is.

```glsl
@fs fs
@include_block helix_sprite
layout(binding=2) uniform tint_flash_params {
    vec4 flash; // rgb sRGB (setColor), a how much
};
void main() {
    vec4 c = helix_sprite_color();
    helix_output(mix(c.rgb, flash.rgb, flash.a), c.a);
}
@end
```

## The screen kind: `helix_screen`

For a `ScreenEffect` in a `PostProcess`. The frame holds sRGB values, 0 to 1, as the screen shows them, unless the effect sets `hdr`
(below).

| GLSL | Returns |
| --- | --- |
| `vec4 helix_screen_color()` | The frame's color here. |
| `vec4 helix_screen_color_at(vec2 uv)` | The frame's color at `uv` (0, 0 its top-left, 1, 1 its bottom-right). |
| `helix_screen_uv` (a `vec2` input) | Where this is in the frame: 0, 0 its top-left, 1, 1 its bottom-right. |
| `vec2 helix_screen_size()` | The frame's size in pixels (the stage's or the view's; an intermediate's when drawn into one). |
| `float helix_time()` | Seconds: the stage's time (below). |
| `void helix_output(vec3 color, float alpha)` | Writes the color: replacing the frame's, or blended over it by alpha for an effect made with `alpha` true. |
| `helix_screen_texture`, `helix_screen_sampler` | The frame's texture and sampler (binding 0). |

An effect with `hdr = true` reads an HDR frame where the GPU draws half floats: the 3D light after the exposure, not yet tone mapped, as sRGB
values running past 1 (the sRGB curve carried on). The chain tone maps after the last such effect. An effect wanting linear light decodes
the frame first and encodes what it writes, as `src/helix/shader/bloom.glsl` does; the screen block has no decoding function. An effect
with `hdr` false (the default) reads the frame tone mapped, 0 to 1.

```glsl
@fs fs
@include_block helix_screen
layout(binding=2) uniform fade_params {
    float amount; // 0 none .. 1 all black
};
void main() {
    vec4 frame = helix_screen_color();
    vec2 d = helix_screen_uv - 0.5;
    float edge = smoothstep(0.3, 0.75, length(d * vec2(helix_screen_size().x / helix_screen_size().y, 1.0)));
    helix_output(frame.rgb * (1.0 - clamp(amount + edge * 0.5, 0.0, 1.0)), frame.a);
}
@end
```

## The surface kind: `helix_surface`

For `Material3D.setShader`. It works in **linear light**: `helix_base()`, the lights and `helix_shade()` are linear, and `helix_output`
takes linear color, adds the material's rim light, mixes its hit flash, applies the stage's exposure and tone mapping and encodes sRGB for the
screen (in an HDR chain, it writes the light after the exposure for the chain to tone map). A color the game sets with `setColor` is sRGB:
decode it with `helix_srgb_to_linear` before lighting or writing it.

The surface:

| GLSL | Returns |
| --- | --- |
| `vec4 helix_base()` | The base color: the material's `baseColor` times its texture (decoded from sRGB) times the model's tint. Linear, alpha 0..1. |
| `vec3 helix_normal()` | The unit normal in the world: the normal map's when the material has one, turned toward the viewer. |
| `vec2 helix_uv()` | The texture coordinate here. |
| `vec3 helix_world_position()` | Where this is in the world. |
| `vec3 helix_model_position()` | Where this is on the model at rest, in its own space (before skinning and the vertex hook): a pattern laid by it stays on the surface as the model moves and animates. |
| `vec3 helix_model_normal()` | The unit normal there, in the model's own space at rest. |
| `vec3 helix_camera_position()` | The camera's position in the world. |
| `vec3 helix_view_direction()` | The unit direction from here toward the camera. |
| `float helix_metallic()` | The material's `metallic`, 0..1. |
| `float helix_roughness()` | The material's `roughness`, held to 0.03..1. |
| `vec3 helix_emissive()` | The material's emissive light, linear, times its strength. |
| `float helix_time()` | Seconds: the stage's time (below). Also in the vertex hook. |
| `vec3 helix_srgb_to_linear(vec3 c)` | `c`, sRGB values, decoded to linear. |

The light:

| GLSL | Returns |
| --- | --- |
| `vec3 helix_shade(vec3 n, vec4 base)` | The stage's own shading of `base` (linear) facing `n`: glTF metallic-roughness under its lights, shadows, environment and ambient light, plus the material's emission. Linear. For a shader that only changes the inputs. |
| `vec3 helix_ambient()` | The stage's ambient light, linear, times its intensity. |
| `int helix_light_count()` | How many lights light the model, up to 8. |
| `vec3 helix_light(int i, vec3 world, vec3 n, out vec3 to_light)` | Light `i`'s radiance reaching `world` facing `n` (its color times intensity, its falloff, cone and shadow applied), and `to_light`, the unit direction toward it. `i` from 0 to `helix_light_count() - 1`. |
| `vec3 helix_light_lit(int i, vec3 world, vec3 n, out vec3 to_light, out float lit)` | As `helix_light`, and `lit`, how much of it the shadow lets through (1 in the open, 0 in shadow). |
| `float helix_shadow_at(int i, vec3 world, vec3 n, vec3 to_light)` | Light `i`'s shadow alone: 1 in the open, 0 in shadow; 1 for a light without shadows or a model that doesn't receive them. |
| `bool helix_has_environment()` | Whether the stage has an environment to light by. |
| `vec3 helix_environment_irradiance(vec3 n)` | The environment's diffuse light on a surface facing unit `n`, over pi, times its intensity; 0 without one. |
| `vec3 helix_environment_reflection(vec3 r, float roughness)` | The environment reflected in world direction `r` by a surface of `roughness`, times its intensity; 0 without one. |
| `vec2 helix_environment_brdf(float n_dot_v, float roughness)` | The split-sum BRDF table: specular reflectance is `f0 * x + y`. |
| `vec3 helix_rim_light()` | The material's rim light here (`helix.shader.Rim`); `helix_output` adds it already. |
| `vec3 helix_tonemap(vec3 color)` | The stage's exposure and tone mapping of linear color, into 0..1; `helix_output` applies it already. |
| `HELIX_PI` | pi, a `const float`. |
| `void helix_output(vec3 color, float alpha)` | Writes linear color and alpha as described above. |

A shader that only changes the inputs passes them to `helix_shade` (as `checker.glsl` and `pearl.glsl` do); one that lights its own way
walks the lights (as `src/helix/shader/water.glsl` and `toon.glsl` do). Either way it ends in `helix_output`.

```glsl
@fs fs
@include_block helix_surface
layout(binding=2) uniform stripes_params {
    vec4 stripe_color; // rgb sRGB (setColor)
    float width;       // a stripe's width, model units
};
void main() {
    float on = step(0.5, fract(helix_model_position().y / max(width, 1e-3)));
    vec4 base = helix_base();
    base.rgb = mix(base.rgb, helix_srgb_to_linear(stripe_color.rgb), on);
    helix_output(helix_shade(helix_normal(), base), base.a);
}
@end
```

## Parameters from the game

`SpriteEffect.parameters`, `ScreenEffect.parameters` and `Material3D.shaderParameters` are a `ShaderParameters`, set by member name. Each
setter returns false, changing nothing, for a name the shader hasn't or values that don't fit it. What is set is kept across the shader's
reloads (a name the reloaded shader lacks is kept and ignored).

| Call | Sets |
| --- | --- |
| `setFloat(name, value)` | A `float`. |
| `setValues(name, [x, y, ...])` | A vector's, matrix's or array's components from the first (a `mat4` column by column, an array element by element); the rest keep theirs. |
| `setColor(name, 0xAARRGGBB)` | A `vec4` to the color's red, green, blue and alpha, each its byte over 255. False for a member of fewer than 4 components. |
| `setTexture(name, texture)` | One of the shader's own textures to a `Texture2D`. |
| `getValues(name)`, `getTexture(name)` | What was set, or null. |

**Colors.** `setColor` passes the channels through as they are; it doesn't decode sRGB. A `0xAARRGGBB` color is sRGB, as every color in
HeliX is. So:

| Kind | Works in | A `setColor` color |
| --- | --- | --- |
| sprite | sRGB values, as the tint and the texture are | use as it is |
| screen | sRGB values, as the frame is (past 1 in an HDR frame) | use as it is |
| surface | linear light | decode it: `helix_srgb_to_linear(c.rgb)` |

A surface shader may take linear values from the game instead, set with `setValues` (`checker.glsl`'s colors are), and its comment says
which.

**Every frame is fine.** Setting a parameter is writing a few numbers the next draw reads (a sprite effect's as its batch ends, a surface's
as its model draws), so a game sets them in `update` as often as it likes: a strength that fades, a color that pulses, a time of its own. The library's surface classes decode in Haxe (`helix.shader.LibrarySurface`) or in GLSL (`unlit.glsl`).

**How bright a surface looks.** A surface is lit as glTF lights it: its diffuse is its color divided by π, times the light. A
`DirectionalLight3D` starts at intensity π, so a surface facing it shows its color as written; the stage's ambient light
(`Environment3D.setAmbient`) adds on top, and the tone mapping (Neutral by default, on the `View3D`) then softens values near 1, so a fully
saturated color lit straight on stops a little short of 255. A sun at 1 shows it at roughly 60 to 70% on screen. To judge a surface
shader's colors, light it with the default sun and a little ambient:

```haxe
var level = new Node3D(), camera = new Camera3D();      // helix.render3d
level.environment = new Environment3D();
level.environment.setAmbient(0xffffffff, .1);
var sun = new DirectionalLight3D();                      // intensity π: colors as written
sun.setRotation(-.8, .5, 0);
level.addChild(sun);
var material = new Material3D();
material.setShader(stripes);                              // the loaded surface Shader
var model = new Model3D(Mesh3D.cylinder(.6, 2), material);
level.addChild(model);
camera.setView(0, 1.5, 5, 0, 1, 0);
Stage.addChild(new View3D(level, camera));               // drawn under the 2D
```

## Time and size

`helix_time()` is the stage's time in seconds, in every kind: the game's clock (`Time.clock.time`: scaled with it, and still while it is
paused), or `Stage.heldTime` while that is set (an autopilot's samples, the same on every target). A `Renderer3D` drawn by hand gives surface
shaders its own `time`. A `SpriteEffect` subclass may override `prepare(time)` to bring its parameters to the batch's time before each draw
(as `SpriteFlash` fades).

A screen shader has the frame's size in pixels (`helix_screen_size()`); a sprite shader has its texture's (`helix_texture_size()`). A surface
shader has neither; `gl_FragCoord` gives the pixel in every kind.

## Hot reload and errors

- **In the dev loop** (`haxe hxml/dev.hxml`): a saved shader is packed again and the page builds the new program in place; every effect and
  material using the `Shader` draws with it from the next frame, its parameters kept. A shader the packer refuses or sokol-shdc can't
  compile is reported in the dev loop's terminal (`shader: wave.glsl failed, kept as it was: ...`) and its last packed file is kept, so the
  page keeps drawing the last one that worked. A packed file the browser's GPU can't build is reported in the page's console, and the
  shader stays as it was.
- **In a build:** `Build.packShaders` stops the build with the packer's message.
- **At load:** `Shaders.load` calls its failure lambda (or logs, with the path) for a file it can't read, one packed for another format
  (pack it again), or a program the GPU didn't build, with the compiler's log.

The packer's messages name the source file, and sokol-shdc's errors name the source's own line (`shaders/wave.glsl:12:4: error: ...`), though
what it compiles puts the framework's block first; an error in the framework's part, which a source rarely causes, says so instead.

## The library's shaders as references

`src/helix/shader/` holds the library's shaders, each with a typed class (`helix.shader`, docs/api/shader.md) over the same parameters:

- sprite: `sprite_flash.glsl`, `sprite_outline.glsl` (reading inside the region only), `sprite_dissolve.glsl`, `palette_swap.glsl` (a texture
  of its own, read texel by texel).
- screen: `vignette.glsl`, `pixelate.glsl`, `chromatic_aberration.glsl`, `crt.glsl`, `color_lut.glsl` (a texture of its own), `fxaa.glsl`,
  `blur.glsl` and `bloom.glsl` (several passes: `ScreenEffect` subclasses with intermediates), `tonemap.glsl` (HDR in, sRGB out).
- surface: `unlit.glsl` (an sRGB color decoded in GLSL), `toon.glsl` (its own lighting), `dissolve.glsl` (a `discard`, laid by the model's
  position), `water.glsl` (a vertex hook, its own lighting and the environment).
