package helix.ui;

import helix.render2d.Node2D;
import helix.render2d.Shape2D;
import helix.render2d.Sprite2D;
import helix.render2d.Text2D;
import helix.texture.Texture2D;

/** A picture with a caption under it, in a frame: an inventory's item, a character creator's choice, a level to pick. Clicked by the pointer,
	or activated with focus by Enter, Space or a pad's South; marked selected by the game (one of a group, as the game decides: clicked,
	then selected). Its picture can come later (a thumbnail still being made): until then, and with none, the frame shows the theme's face
	color. Ask clicked once a frame. */
class Tile extends Widget {
	var face:Shape2D;
	var picture:Sprite2D;
	var label:Text2D;
	var edge:Shape2D;
	var inner:Layout2D;

	@:allow(helix.ui.Ui)
	function new(ui:Ui, name:String, texture:Null<Texture2D>, caption:String, side:Float) {
		super(ui, name);
		this.side = side;
		var theme = ui.theme;
		face = Shape2D.rectangle(1, 1, theme.faceColor);
		face.setPivot(0, 0);
		edge = Shape2D.rectangle(1, 1, theme.accentColor);
		edge.setPivot(0, 0);
		edge.pickable = false;
		edge.visible = false;
		picture = new Sprite2D(texture);
		picture.setPivot(0, 0);
		picture.pickable = false;
		label = new Text2D(caption, theme.textSize * .8, theme.textColor, theme.font);
		label.setPivot(.5, 0);
		label.pickable = false;
		for (n in [edge, face, picture, label])
			root.addChild(n);
		// The edge a little outside the face, the picture square inside it, the caption under the picture.
		layout = Layout2D.stack(edge);
		inner = Layout2D.column(face);
		inner.setAlign(Start, Center);
		var image = Layout2D.of(picture);
		image.themeSizing(Fixed(side), Fixed(side));
		inner.add(image);
		inner.add(Layout2D.of(label));
		layout.themePadding(3, 3, 3, 3);
		layout.add(inner);
		picture.visible = texture != null;
		readTheme(theme);
	}

	/** Whether it was clicked or activated this frame. */
	public var clicked(default, null):Bool = false;

	/** Whether it's marked selected: drawn with an accent edge. */
	public var selected:Bool = false;

	/** Its picture, or null while it has none. */
	public var texture(get, set):Null<Texture2D>;

	function get_texture():Null<Texture2D>
		return picture.texture;

	function set_texture(texture:Null<Texture2D>):Null<Texture2D> {
		picture.texture = texture;
		picture.visible = texture != null;
		return texture;
	}

	/** Its caption, under the picture. */
	public var caption(get, set):String;

	function get_caption():String
		return label.text;

	function set_caption(value:String):String {
		label.text = value;
		return value;
	}

	/** The side of its picture's square, in units. */
	public var side(default, null):Float;

	override function get_focusable():Bool
		return true;

	override function target():Null<Node2D>
		return face;

	override function readTheme(theme:Theme):Void {
		var pad = theme.padding;
		face.cornerRadius = theme.cornerRadius;
		edge.cornerRadius = theme.cornerRadius + 2;
		label.textSize = theme.textSize * .8;
		label.font = theme.font;
		inner.themePadding(pad, pad, pad, pad);
		inner.themeGap(pad / 2);
	}

	override function update(hovered:Bool, held:Bool, clicked:Bool, focused:Bool, activated:Bool, stepX:Int, stepY:Int):Void {
		var theme = ui.theme,
			state = WidgetState.of(enabled, held, hovered, focused);
		this.clicked = enabled && (clicked || activated);
		face.color = state.face(theme);
		edge.visible = selected;
		edge.color = state == Disabled ? WidgetState.dim(theme.accentColor) : theme.accentColor;
		picture.tint = state == Disabled ? 0xff808080 : 0xffffffff;
		label.color = state.text(theme);
	}
}
