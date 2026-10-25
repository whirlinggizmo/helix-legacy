package helix.render3d;

import helix.graphics.Color;
import helix.graphics.Shader;
import helix.graphics.ShaderParameters;
import helix.texture.Texture2D;

/** How a model's surface looks: glTF's metallic-roughness model. A base color (0xAARRGGBB, its color sRGB-encoded as the convention's colors
	are; its alpha below 255 makes the surface see-through), an optional base color texture (sRGB) multiplying it, how metallic (0..1) and how
	rough (0..1) it is, an optional normal map (tangent space, green up) and its strength, light it gives off (emissive), and
	whether lights shade it at all. Shared by any number of models: models alike in mesh and material draw
	together. */
class Material3D {
	// Kept across a hot reload: ids made after one mustn't repeat those of materials still drawn.
	@:hot static var nextId = 1;

	// Which one it is, for sorting alike draws together.
	@:allow(helix.render3d.Renderer3D) var id = nextId++;

	var blendAlways = false;
	var parameters:Null<ShaderParameters>;

	/** White, not metallic, roughness 0.5, lit, untextured, giving off no light. */
	public function new() {}

	/** The base color, 0xAARRGGBB. */
	public var baseColor:Int = 0xffffffff;

	/** The base color texture, or null for none (white). */
	public var texture:Null<Texture2D>;

	/** How metallic, 0..1. Clamped to 0..1 (NaN is 0). */
	public var metallic(default, set):Float = 0.;

	function set_metallic(value:Float):Float {
		value = value > 0 ? (value < 1 ? value : 1) : 0;
		metallic = value;
		return value;
	}

	/** How rough, 0..1. Clamped to 0..1 (NaN is 0). */
	public var roughness(default, set):Float = .5;

	function set_roughness(value:Float):Float {
		value = value > 0 ? (value < 1 ? value : 1) : 0;
		roughness = value;
		return value;
	}

	/** Whether lights shade it; unlit, it shows its color as it is. */
	public var lit:Bool = true;

	/** The normal map (tangent space, green up), or null for none. Its colors are directions, read as they are, not decoded from sRGB.
		Load it smooth, with mipmaps (Textures.load's Linear). */
	public var normalTexture:Null<Texture2D>;

	/** How strongly the normal map bends the surface: 1 as it is, 0 flat. 0 or more (under 0, or NaN, is 0). */
	public var normalScale(default, set):Float = 1.;

	function set_normalScale(value:Float):Float {
		value = value >= 0 ? value : 0;
		normalScale = value;
		return value;
	}

	/** The light it gives off, 0xAARRGGBB (sRGB, alpha ignored); black for none. */
	public var emissive(default, null):Int = 0xff000000;

	/** How bright its emissive light is: the color times this. */
	public var emissiveStrength(default, null):Float = 1.;

	/** Gives it light of its own, color (0xAARRGGBB, sRGB) times strength, lit or not. False for a strength under 0. */
	public function setEmissive(color:Int, strength = 1.):Bool {
		if (!(strength >= 0))
			return false;
		emissive = color;
		emissiveStrength = strength;
		return true;
	}

	/** Whether both sides of its triangles draw (the back with its normal turned toward the viewer), for open surfaces, leaves, cloth, or
		a surface a shader cuts holes in; otherwise back faces are culled. */
	public var doubleSided:Bool = false;

	/** The app's surface shader it draws with, or null for the stage's own shading. */
	public var shader(default, null):Null<Shader>;

	/** Draws it with an app's surface shader (a .hxshader of kind surface: its own fragment stage, and maybe a vertex hook), which gets the
		material's values and textures and the stage's lights; null goes back to the stage's own shading. False, changing nothing, for a shader
		of another kind. Its parameters (shaderParameters) start empty when the shader changes. */
	public function setShader(value:Null<Shader>):Bool {
		if (value != null && value.kind != "surface")
			return false;
		if (value != shader)
			parameters = value == null ? null : new ShaderParameters(value);
		shader = value;
		return true;
	}

	/** Its surface shader's own parameters and textures, set by name; null without a shader. */
	public var shaderParameters(get, never):Null<ShaderParameters>;

	function get_shaderParameters():Null<ShaderParameters>
		return parameters;

	// The hit flash (helix.shader.HitFlash) and rim light (helix.shader.Rim) any material shows, drawn by the stage's lit program and every
	// surface shader alike: off until one is attached. The flash: its color (0xAARRGGBB, sRGB, its alpha how strong), how much of it (0..1),
	// and when fading, over how many seconds of the stage's time (0: held), from when a stage first drew it (NaN until then).
	@:allow(helix.shader) @:allow(helix.render3d.Renderer3D) var flashColor = 0xffffffff;
	@:allow(helix.shader) @:allow(helix.render3d.Renderer3D) var flashAmount = 0.;
	@:allow(helix.shader) @:allow(helix.render3d.Renderer3D) var flashSeconds = 0.;
	@:allow(helix.shader) @:allow(helix.render3d.Renderer3D) var flashStart = Math.NaN;
	// The rim: its color (0xAARRGGBB, sRGB, its alpha how strong; black for none) and power (how tight to the silhouette, above 0).
	@:allow(helix.shader) @:allow(helix.render3d.Renderer3D) var rimColor = 0xff000000;
	@:allow(helix.shader) @:allow(helix.render3d.Renderer3D) var rimPower = 3.;

	// How much of the flash shows at the stage's time: held, or fading from all of it to none over its seconds since a stage first drew it.
	@:allow(helix.shader) @:allow(helix.render3d.Renderer3D) function flashAt(time:Float):Float {
		if (flashSeconds <= 0)
			return flashAmount;
		if (Math.isNaN(flashStart))
			flashStart = time;
		var left = 1 - (time - flashStart) / flashSeconds;
		return flashAmount * (left > 1 ? 1 : left > 0 ? left : 0);
	}

	/** Whether it is see-through: drawn blended, back to front after the opaque, when set so or when its base color's alpha is below 255.
		Set, it draws blended even at full alpha, as glTF's alphaMode BLEND says (its texture's alpha then shows through). */
	public var blended(get, set):Bool;

	function get_blended():Bool
		return blendAlways || Color.getAlpha(baseColor) < 255;

	function set_blended(value:Bool):Bool {
		blendAlways = value;
		return value;
	}
}
