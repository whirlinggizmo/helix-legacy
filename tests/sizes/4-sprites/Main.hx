// The web size ladder (tools/measure_sizes.py): each rung adds one thing to the one before; this one + a texture loaded and drawn.
import helix.AppOptions;
import helix.host.Window;
import helix.render2d.Shape2D;
import helix.render2d.Sprite2D;
import helix.render2d.Stage;
import helix.render2d.Text2D;
import helix.texture.Textures;

/** The entry point: Game on the backend the build names. */
class Main {
	public static function main():Void {
		var options = new AppOptions();
		options.product = "size-4-sprites";
		new Game(options);
	}
}

/** This rung's game: + a texture loaded and drawn. */
class Game extends helix.App {
	override public function init():Void {
		Window.title = "4-sprites";
		Stage.color = 0xff202840;
		var box = Shape2D.rectangle(320, 160, 0xff66bfff);
		box.setPosition(40, 40);
		Stage.addChild(box);
		var hello = new Text2D("Hello", 48, 0xff102030);
		hello.setPosition(60, 90);
		Stage.addChild(hello);
		Textures.load("sprites/logo.png", Linear, texture -> {
			var logo = new Sprite2D(texture);
			logo.setPosition(400, 300);
			logo.setSize(64, 64);
			Stage.addChild(logo);
		});
	}
}
