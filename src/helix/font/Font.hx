package helix.font;

import helix.graphics.IGraphics;
import haxe.io.Bytes;
import helix.texture.Texture2D;
import helix.font.Glyph;

/** A font for text (Batch2D.drawText, a Text2D node): its characters as glyphs in one texture. builtIn() is JetBrains Mono's printable ASCII as a distance field, sharp at any
	size; fromTrueType() any TrueType font's printable ASCII and Latin-1, baked the same way (Fonts loads them from files), with its kerning;
	pixel() a 5x7 bitmap font. Sizes are in font pixels: the size the font was made at, which text is scaled from to the size asked for. */
class Font {
	var glyphs:Array<Null<Glyph>>;
	// A TrueType font's kerning, in font pixels, asked of its file as pairs come (a function, so a program that loads no TrueType font
	// carries none of the reader), and the pairs known.
	var kerningOf:Null<(Int, Int) -> Float>;
	var kerning = new Map<Int, Float>();

	function new(texture:Texture2D, glyphs:Array<Null<Glyph>>, size:Float, ascent:Float, descent:Float, distanceField:Bool) {
		this.texture = texture;
		this.glyphs = glyphs;
		this.size = size;
		this.ascent = ascent;
		this.descent = descent;
		this.distanceField = distanceField;
	}

	/** The texture holding every glyph, with a white texel for untextured shapes. */
	public var texture(default, null):Texture2D;

	/** The height the font was made at, ascent to descent, in font pixels: a text's size scales this. */
	public var size(default, null):Float;

	/** How far the tallest glyphs reach above the baseline, in font pixels. */
	public var ascent(default, null):Float;

	/** How far glyphs reach below the baseline, in font pixels; 0 or negative. */
	public var descent(default, null):Float;

	/** Whether the texture's alpha is a distance from each glyph's outline (Batch2D draws it so) rather than coverage. */
	public var distanceField(default, null):Bool;

	/** A character's glyph, or null when it has none (space has an advance but nothing to draw: its glyph has no size). */
	public function getGlyph(code:Int):Null<Glyph>
		return code >= 32 && code - 32 < glyphs.length ? glyphs[code - 32] : null;

	/** How far the pen moves besides the advance between characters left and right, in font pixels: usually negative, closing a pair such as
		"AV". 0 for a font without kerning. */
	public function getKerning(left:Int, right:Int):Float {
		if (kerningOf == null)
			return 0;
		var key = left << 16 | right & 0xFFFF, known = kerning.get(key);
		if (known == null) {
			known = kerningOf(left, right);
			kerning.set(key, known);
		}
		return known;
	}

	/** How far text moves the pen at size (world units, ascent to descent): its width, by its glyphs' advances and the kerning between them.
		Characters without a glyph count as nothing. */
	public function measure(text:String, size:Float):Float {
		var unit = size / this.size, width = 0.;
		for (i in 0...text.length) {
			var code = text.charCodeAt(i), glyph = getGlyph(code);
			if (glyph != null)
				width += glyph.advance * unit;
			if (i + 1 < text.length)
				width += getKerning(code, text.charCodeAt(i + 1)) * unit;
		}
		return width;
	}

	/** text broken into lines no wider than width in world units at size: at spaces, and a word wider than a line within it, between its
		letters; a line break ("\n") always breaks. Lines keep no trailing spaces. */
	public function wrap(text:String, size:Float, width:Float):Array<String> {
		var lines = [];
		for (paragraph in text.split("\n")) {
			var line = "";
			for (word in paragraph.split(" ")) {
				var tried = line == "" ? word : line + " " + word;
				if (measure(tried, size) <= width) {
					line = tried;
					continue;
				}
				if (line != "")
					lines.push(line);
				// A word wider than a line: as many of its letters as fit, line after line.
				line = word;
				while (line.length > 1 && measure(line, size) > width) {
					var fit = 1;
					while (fit < line.length && measure(line.substr(0, fit + 1), size) <= width)
						fit++;
					lines.push(line.substr(0, fit));
					line = line.substr(fit);
				}
			}
			lines.push(line);
		}
		return lines;
	}

	/** The height text takes wrapped to width at size (wrap), its lines lineHeight times size apart: what Batch2D.drawTextWrapped returns,
		known before drawing, for what's laid out under it (a button below a title that may wrap). */
	public function measureWrapped(text:String, size:Float, width:Float, lineHeight = 1.25):Float
		return wrap(text, size, width).length * size * lineHeight;

	/** The characters fromTrueType bakes: printable ASCII and Latin-1. */
	static function bakedCodes():Array<Int>
		return [for (c in 32...256) if (c < 127 || c >= 160) c];

	/** A font from a TrueType file's bytes: its printable ASCII and Latin-1 characters baked at pixelHeight (ascent to descent) into a distance
		field with padding pixels around each glyph (FontBaker), sharp from small text to about four times pixelHeight. Throws, saying why, for a
		file it can't read. On gpu, the program's (Graphics) when not given. The caller destroys it. */
	public static function fromTrueType(data:Bytes, pixelHeight = 32., padding = 6, ?gpu:IGraphics):Font {
		gpu = gpu != null ? gpu : helix.graphics.Graphics.instance;
		var font = new Font(null, [], 0, 0, 0, true);
		font.bakeTrueType(gpu, data, pixelHeight, padding);
		return font;
	}

	/** The file changed: baked again in place, at the size it was baked at. */
	@:allow(helix.font.FontCache)
	function replaceTrueType(gpu:IGraphics, data:Bytes):Void {
		var old = texture;
		bakeTrueType(gpu, data, size, 6);
		old.destroy(gpu);
	}

	function bakeTrueType(gpu:IGraphics, data:Bytes, pixelHeight:Float, padding:Int):Void {
		var file = new TrueType(data);
		var baked = FontBaker.bake(file, bakedCodes(), pixelHeight, padding, 512);
		var width = baked.width,
			height = baked.height,
			rgba = Bytes.alloc(width * height * 4);
		for (i in 0...width * height) {
			rgba.set(i * 4, 255);
			rgba.set(i * 4 + 1, 255);
			rgba.set(i * 4 + 2, 255);
			rgba.set(i * 4 + 3, baked.field.get(i));
		}
		texture = Texture2D.fromRgba(width, height, rgba, Linear, width - 1, height - 1, true, gpu);
		glyphs = [];
		for (g in baked.glyphs) {
			while (glyphs.length < g.code - 32)
				glyphs.push(null);
			glyphs.push({
				u0: g.x / width,
				v0: g.y / height,
				u1: (g.x + g.width) / width,
				v1: (g.y + g.height) / height,
				x: g.xOffset,
				y: g.yOffset,
				width: g.width,
				height: g.height,
				advance: g.advance
			});
		}
		size = baked.ascent - baked.descent;
		ascent = baked.ascent;
		descent = baked.descent;
		var scale = baked.scale;
		kerningOf = (left, right) -> file.getKerning(file.getGlyphIndex(left), file.getGlyphIndex(right)) * scale;
		kerning = new Map();
	}

	/** The built-in font: JetBrains Mono's printable ASCII as a distance field, baked by tools/bake_fonts.py (SIL OFL 1.1, see THIRD_PARTY_NOTICES.md). On gpu,
		the program's (Graphics) when not given. */
	public static function builtIn(?gpu:IGraphics):Font {
		gpu = gpu != null ? gpu : helix.graphics.Graphics.instance;
		var field = haxe.zip.InflateImpl.run(new haxe.io.BytesInput(haxe.crypto.Base64.decode(GeneratedFont.atlas)));
		var width = GeneratedFont.width, height = GeneratedFont.height;
		var rgba = Bytes.alloc(width * height * 4);
		for (i in 0...width * height) {
			rgba.set(i * 4, 255);
			rgba.set(i * 4 + 1, 255);
			rgba.set(i * 4 + 2, 255);
			rgba.set(i * 4 + 3, field.get(i));
		}
		var texture = Texture2D.fromRgba(width, height, rgba, Linear, GeneratedFont.whiteX, GeneratedFont.whiteY, true, gpu);
		var glyphs:Array<Null<Glyph>> = [];
		for (n in 0...95) {
			var g = GeneratedFont.glyphs, i = n * 6;
			glyphs.push({
				u0: g[i] / width,
				v0: g[i + 1] / height,
				u1: (g[i] + g[i + 2]) / width,
				v1: (g[i + 1] + g[i + 3]) / height,
				x: g[i + 4],
				y: g[i + 5],
				width: g[i + 2],
				height: g[i + 3],
				advance: GeneratedFont.advances[n]
			});
		}
		return new Font(texture, glyphs, GeneratedFont.ascent - GeneratedFont.descent, GeneratedFont.ascent, GeneratedFont.descent, true);
	}

	/** The 5x7 pixel font's glyphs: cells of 8 in a 128x64 texture, each 5 wide and 7 tall, sitting on the baseline, advancing 6. */
	static function pixelGlyphs():Array<Null<Glyph>>
		return [
			for (n in 0...95) {
				var x = n % 16 * 8, y = Std.int(n / 16) * 8;
				{
					u0: (x + .01) / 128,
					v0: (y + .01) / 64,
					u1: (x + 5 + .01) / 128,
					v1: (y + 7 + .01) / 64,
					x: 0.,
					y: -7.,
					width: n == 0 ? 0. : 5.,
					height: n == 0 ? 0. : 7.,
					advance: 6.
				};
			}
		];

	/** The glyphs, as rows of five pixels. A function, not a static: a browser hot reload keeps statics' old values, and an edit here should show. */
	static function rows():Map<String, String>
		return [
			"A" => "01110/10001/10001/11111/10001/10001/10001",
			"B" => "11110/10001/10001/11110/10001/10001/11110",
			"C" => "01111/10000/10000/10000/10000/10000/01111",
			"D" => "11110/10001/10001/10001/10001/10001/11110",
			"E" => "11111/10000/10000/11110/10000/10000/11111",
			"F" => "11111/10000/10000/11110/10000/10000/10000",
			"G" => "01111/10000/10000/10111/10001/10001/01111",
			"H" => "10001/10001/10001/11111/10001/10001/10001",
			"I" => "11111/00100/00100/00100/00100/00100/11111",
			"J" => "00111/00010/00010/00010/10010/10010/01100",
			"K" => "10001/10010/10100/11000/10100/10010/10001",
			"L" => "10000/10000/10000/10000/10000/10000/11111",
			"M" => "10001/11011/10101/10101/10001/10001/10001",
			"N" => "10001/11001/10101/10011/10001/10001/10001",
			"O" => "01110/10001/10001/10001/10001/10001/01110",
			"P" => "11110/10001/10001/11110/10000/10000/10000",
			"Q" => "01110/10001/10001/10001/10101/10010/01101",
			"R" => "11110/10001/10001/11110/10100/10010/10001",
			"S" => "01111/10000/10000/01110/00001/00001/11110",
			"T" => "11111/00100/00100/00100/00100/00100/00100",
			"U" => "10001/10001/10001/10001/10001/10001/01110",
			"V" => "10001/10001/10001/10001/10001/01010/00100",
			"W" => "10001/10001/10001/10101/10101/10101/01010",
			"X" => "10001/10001/01010/00100/01010/10001/10001",
			"Y" => "10001/10001/01010/00100/00100/00100/00100",
			"Z" => "11111/00001/00010/00100/01000/10000/11111",
			"0" => "01110/10001/10011/10101/11001/10001/01110",
			"1" => "00100/01100/00100/00100/00100/00100/01110",
			"2" => "01110/10001/00001/00010/00100/01000/11111",
			"3" => "11110/00001/00001/01110/00001/00001/11110",
			"4" => "00010/00110/01010/10010/11111/00010/00010",
			"5" => "11111/10000/10000/11110/00001/00001/11110",
			"6" => "01110/10000/10000/11110/10001/10001/01110",
			"7" => "11111/00001/00010/00100/01000/01000/01000",
			"8" => "01110/10001/10001/01110/10001/10001/01110",
			"9" => "01110/10001/10001/01111/00001/00001/01110",
			":" => "00000/00100/00100/00000/00100/00100/00000",
			"-" => "00000/00000/00000/11111/00000/00000/00000",
			"." => "00000/00000/00000/00000/00000/01100/01100",
			"!" => "00100/00100/00100/00100/00100/00000/00100",
			"?" => "01110/10001/00001/00010/00100/00000/00100",
			"/" => "00001/00010/00010/00100/01000/01000/10000",
			"+" => "00000/00100/00100/11111/00100/00100/00000",
			"'" => "00100/00100/01000/00000/00000/00000/00000",
			"(" => "00010/00100/01000/01000/01000/00100/00010",
			")" => "01000/00100/00010/00010/00010/00100/01000",
			"\"" => "01010/01010/00000/00000/00000/00000/00000",
			"#" => "01010/11111/01010/01010/11111/01010/00000",
			"$" => "00100/01111/10100/01110/00101/11110/00100",
			"%" => "11001/11010/00010/00100/01000/01011/10011",
			"&" => "01100/10010/10100/01000/10101/10010/01101",
			"*" => "00000/10101/01110/11111/01110/10101/00000",
			"," => "00000/00000/00000/00000/01100/00100/01000",
			";" => "00000/01100/01100/00000/01100/00100/01000",
			"<" => "00010/00100/01000/10000/01000/00100/00010",
			"=" => "00000/00000/11111/00000/11111/00000/00000",
			">" => "01000/00100/00010/00001/00010/00100/01000",
			"@" => "01110/10001/10111/10101/10111/10000/01111",
			"[" => "01110/01000/01000/01000/01000/01000/01110",
			"\\" => "10000/01000/01000/00100/00010/00010/00001",
			"]" => "01110/00010/00010/00010/00010/00010/01110",
			"^" => "00100/01010/10001/00000/00000/00000/00000",
			"_" => "00000/00000/00000/00000/00000/00000/11111",
			"`" => "01000/00100/00010/00000/00000/00000/00000",
			"{" => "00110/00100/00100/01000/00100/00100/00110",
			"|" => "00100/00100/00100/00100/00100/00100/00100",
			"}" => "01100/00100/00100/00010/00100/00100/01100",
			"~" => "00000/00000/01000/10101/00010/00000/00000",
			"a" => "00000/00000/01110/00001/01111/10001/01111",
			"b" => "10000/10000/10110/11001/10001/10001/11110",
			"c" => "00000/00000/01110/10000/10000/10001/01110",
			"d" => "00001/00001/01101/10011/10001/10001/01111",
			"e" => "00000/00000/01110/10001/11111/10000/01110",
			"f" => "00110/01001/01000/11100/01000/01000/01000",
			"g" => "00000/01111/10001/10001/01111/00001/01110",
			"h" => "10000/10000/10110/11001/10001/10001/10001",
			"i" => "00100/00000/01100/00100/00100/00100/01110",
			"j" => "00010/00000/00110/00010/00010/10010/01100",
			"k" => "10000/10000/10010/10100/11000/10100/10010",
			"l" => "01100/00100/00100/00100/00100/00100/01110",
			"m" => "00000/00000/11010/10101/10101/10101/10101",
			"n" => "00000/00000/10110/11001/10001/10001/10001",
			"o" => "00000/00000/01110/10001/10001/10001/01110",
			"p" => "00000/11110/10001/10001/11110/10000/10000",
			"q" => "00000/01111/10001/10001/01111/00001/00001",
			"r" => "00000/00000/10110/11001/10000/10000/10000",
			"s" => "00000/00000/01111/10000/01110/00001/11110",
			"t" => "01000/01000/11100/01000/01000/01001/00110",
			"u" => "00000/00000/10001/10001/10001/10011/01101",
			"v" => "00000/00000/10001/10001/10001/01010/00100",
			"w" => "00000/00000/10001/10001/10101/10101/01010",
			"x" => "00000/00000/10001/01010/00100/01010/10001",
			"y" => "00000/10001/10001/10001/01111/00001/01110",
			"z" => "00000/00000/11111/00010/00100/01000/11111"
		];

	/** The 5x7 pixel font: crisp at whole multiples of 7, blocky between. Its texture also carries a white texel for shapes. On gpu, the
		program's (Graphics) when not given. */
	public static function pixel(?gpu:IGraphics):Font {
		gpu = gpu != null ? gpu : helix.graphics.Graphics.instance;
		var font = new Font(bake(gpu), pixelGlyphs(), 7, 7, 0, false);
		live.push({font: font, gpu: gpu});
		return font;
	}

	/** Pixel fonts in use, so a hot reload that changes the glyphs can bake their textures again. */
	// Kept across a hot reload, so the reload's rebake finds every font.
	@:hot static var live:Array<{font:Font, gpu:IGraphics}> = [];

	@:afterHotReload static function rebake():Void
		for (entry in live) {
			var old = entry.font.texture;
			entry.font.texture = bake(entry.gpu);
			old.destroy(entry.gpu);
		}

	/** Frees the font's texture on gpu, the adapter that made it: the program's (Graphics) when not given. */
	public function destroy(?gpu:IGraphics):Void {
		gpu = gpu != null ? gpu : helix.graphics.Graphics.instance;
		texture.destroy(gpu);
		live = live.filter(e -> e.font != this);
	}

	static function bake(gpu:IGraphics):Texture2D {
		var bytes = Bytes.alloc(128 * 64 * 4);
		var glyphs = rows();
		for (c in glyphs.keys()) {
			var n = c.charCodeAt(0) - 32,
				ox = (n % 16) * 8,
				oy = Std.int(n / 16) * 8,
				lines = glyphs[c].split('/');
			for (y in 0...7)
				for (x in 0...5)
					if (lines[y].charAt(x) == "1") {
						var p = ((oy + y) * 128 + ox + x) * 4;
						for (k in 0...4)
							bytes.set(p + k, 255);
					}
		}
		for (k in 0...4)
			bytes.set((63 * 128 + 127) * 4 + k, 255);
		return Texture2D.fromRgba(128, 64, bytes, Nearest, 127, 63, gpu);
	}
}
