import Render2DTests.CountingGraphics;
import helix.graphics.Color;
import helix.font.Font;
import helix.render2d.Shape2D;
import helix.render2d.ShapeShading2D;
import helix.render2d.ShapeForm2D;
import helix.render2d.Text2D;
import helix.ui.Layout2D;
import helix.ui.Alignment2D;
import helix.ui.LayoutDirection2D;
import helix.ui.Sizing2D;
import helix.ui.WidgetState;

/** The UI's layout: rows, columns and stacks, sizes fixed, fitted, growing and shared, padding, gaps, margins, alignment and anchors, and the nodes
	placed by their pivots; the widgets used by keys, the pointer and typing, and their parts drawn by their states; the color picker's HSV, hex
	and input; a panel's title; the popup layer and the dropdown opening on it. */
@:access(helix)
class UiTests {
	static var checks = 0;

	static function check(value:Bool, message:String):Void {
		if (!value)
			throw message;
		checks++;
	}

	static function near(a:Float, b:Float):Bool
		return Math.abs(a - b) < 1e-6;

	public static function main():Void {
		var font = Font.builtIn(new CountingGraphics());
		layout(font);
		margins(font);
		widgets(font);
		typing(font);
		tiles(font);
		hsv();
		colors(font);
		theming(font);
		contrast();
		scrolling(font);
		states(font);
		titled(font);
		dropdowns(font);
		separators(font);
		points(font);
		flags(font);
		following(font);
		Sys.println(haxe.Json.stringify({passed: true, checks: checks}));
	}

	// A UI given no input reads the program's (Input) as it is at each update: one bound after it was made (an autopilot's) is the one it
	// reads, typed text asked of it, not of the one before.
	static function following(font:Font):Void {
		var was = helix.input.Input.instance;
		var first = new helix.input.InputState(),
			second = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		helix.input.Input.instance = first;
		var pointer = new helix.scene.Pointer();
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer),
			play = ui.button("Play"),
			name = ui.textField("", "name", 8);
		var layout = holding(sized(Fixed(300), Fit, Column), [play.layout, name.layout]);
		helix.input.Input.instance = second;
		function frame(?key:helix.input.Key):Void {
			second.endFrame();
			if (key != null) {
				second.keyEvent(key, true);
				second.keyEvent(key, false);
			}
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			pointer.update();
			ui.update();
		}
		check(ui.input == second, "Its input is the program's now, not when it was made");
		ui.focused = play;
		frame(Enter);
		check(play.clicked, "Enter on the input bound after it was made");
		ui.focused = name;
		frame();
		check(second.textEntry && !first.textEntry, "Typed text asked of the program's input now");
		helix.input.Input.instance = was;
	}

	// A panel's enabled and interactive reach the widgets in it: disabled, none is focused or clicked; not interactive, none takes the pointer
	// or focus and the pointer passes through to the world under it, a focused one losing focus; a disabled button still stops the pointer.
	static function flags(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var world = helix.render2d.Shape2D.rectangle(800, 600, 0xff203040);
		world.setPivot(0, 0);
		stage.root.addChild(world);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var panel = ui.panel("panel"),
			play = ui.button("Play"),
			quit = ui.button("Quit"),
			lone = ui.button("Lone");
		panel.add(play);
		panel.add(quit);
		panel.layout.setSizing(Fixed(300), Fit);
		var loneRow = Layout2D.row();
		loneRow.add(lone.layout);
		var layout = holding(sized(Grow(1), Grow(1), Column), [panel.layout, loneRow]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame(?keys:Array<helix.input.Key>, ?x:Float, ?y:Float, ?down:Bool):Void {
			input.endFrame();
			if (keys != null)
				for (k in keys) {
					input.keyEvent(k, true);
					input.keyEvent(k, false);
				}
			if (x != null)
				input.pointerEvent(x, y, down == true);
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		function click(w:helix.ui.Widget):Void {
			var x = w.layout.x + 10, y = w.layout.y + 10;
			frame(x, y, true);
			frame(x, y, false);
		}
		frame();
		click(play);
		check(play.clicked, "A button in a panel is clicked");
		// Disabled: the panel's widgets with it, their own flags kept.
		panel.enabled = false;
		check(!play.enabled && !quit.enabled && !panel.enabled, "A disabled panel's widgets read disabled");
		click(play);
		check(!play.clicked && !pointer.isClicked(world), "Not clicked, and the click doesn't reach the world");
		frame([Tab]);
		check(ui.focused == lone, "Tab passes over a disabled panel's widgets");
		panel.enabled = true;
		check(play.enabled, "Enabled again, each as it was");
		click(play);
		check(play.clicked, "and used again");
		// Not interactive: looks as it does, takes nothing, the pointer reaches the world.
		ui.focused = play;
		panel.interactive = false;
		frame();
		check(!play.interactive && play.enabled && play.visible && ui.focused == null, "Not interactive: still enabled and shown, focus lost");
		click(play);
		check(!play.clicked && pointer.isClicked(world), "Not clicked; the click passes through to the world under it");
		frame([Tab]);
		check(ui.focused == lone, "Tab passes over it");
		check(!ui.press("Play"), "Nor pressed by name");
		panel.interactive = true;
		click(quit);
		check(quit.clicked && !pointer.isClicked(world), "Interactive again: clicked, the world not");
		// A disabled button on its own still stops the pointer.
		lone.enabled = false;
		click(lone);
		check(!lone.clicked && !pointer.isClicked(world), "A disabled button isn't clicked and stops the pointer");
		lone.interactive = false;
		click(lone);
		check(pointer.isClicked(world), "Not interactive too, the pointer passes through it");
	}

	// Points on widgets and their parts (Ui.computePoint), in framebuffer pixels through the camera (two to a unit here): a widget's laid-out
	// rectangle, a slider's track, a color picker's square, bars and swatch, a scroll area's and a list's scrollbar and a list's rows, a
	// dropdown's list and rows only while it's open; none for a hidden widget, an unknown one or an unknown part. An autopilot finding its points
	// through it drags a slider along its track and clicks a dropdown's row.
	static function points(font:Font):Void {
		var stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(1600, 1200);
		camera.pixels(2);
		var ui:Null<helix.ui.Ui> = null;
		var pilot = new helix.debug.Autopilot('{"version":1,"seed":1,"commands":['
			+ '{"op":"drag","from":{"target":"volume","part":"track","at":[0,0.5]},"to":{"target":"volume","part":"track","at":[0.75,0.5]},"ticks":3},'
			+ '{"op":"click","target":"pick","seconds":5},'
			+ '{"op":"click","target":"pick","part":"row:2","at":[0.5,0.5],"seconds":5}]}',
			null, name -> ui.press(name), null, (target, part, x, y, out) -> ui.computePoint(target, part, x, y, out));
		var input = pilot.input;
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var panel = ui.panel(),
			volume = ui.slider("Volume", 0, 100, 0, 0, "volume"),
			tint = ui.colorPicker(0xffff0000, true, "tint"),
			area = ui.scrollArea(60, "area"),
			list = ui.list([for (i in 0...20) 'Item $i'], 4, "items"),
			pick = ui.dropdown(["Low", "Medium", "High"], 0, "pick"),
			hidden = ui.button("Hidden", "hidden");
		for (i in 0...10)
			area.add(ui.label('Line $i'));
		for (w in [volume, tint, area, list, pick, hidden])
			panel.add(w);
		hidden.visible = false;
		panel.layout.setSizing(Fixed(300), Fit);
		var layout = holding(sized(Grow(1), Grow(1)), [panel.layout]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		// As an app's frame: laid out, the pointer and the UI updated (through the places last drawn), then drawn.
		function frame():Void {
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			pointer.update();
			ui.update();
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
		}
		frame();
		frame();
		var out = [0., 0.];
		function at(name:String, part:String, x:Float, y:Float, ex:Float, ey:Float):Bool
			return ui.computePoint(name, part, x, y, out) && near(out[0], ex * 2) && near(out[1], ey * 2);
		var b = volume.layout,
			track:Layout2D = @:privateAccess volume.trackLayout;
		check(at("volume", "", 0, 0, b.x, b.y)
			&& at("volume", "", 1, 1, b.x + b.width, b.y + b.height), "A widget's rectangle, in pixels");
		check(at("volume", "", -.5, 2, b.x - b.width / 2, b.y + b.height * 2), "Past its edges, outside it");
		check(at("volume", "track", .25, .5, track.x + track.width / 4, track.y + track.height / 2), "A slider's track");
		var square:Layout2D = @:privateAccess tint.squareLayout,
			hue:Layout2D = @:privateAccess tint.hueLayout,
			alpha:Layout2D = @:privateAccess tint.alphaLayout,
			thick:Float = @:privateAccess tint.thickness,
			lane:Float = @:privateAccess tint.lane;
		check(at("tint", "square", 1, 0, square.x + square.width, square.y), "A color picker's square");
		check(at("tint", "hue", 0, .5, hue.x + thick / 2, hue.y + lane / 2)
			&& at("tint", "hue", 1, .5, hue.x + hue.width - thick / 2, hue.y + lane / 2),
			"Its hue bar between the centers of its round ends, in the middle of its lane");
		check(at("tint", "alpha", .5, .5, alpha.x + alpha.width / 2, alpha.y + lane / 2) && ui.computePoint("tint", "swatch", .5, .5, out),
			"Its alpha bar and its swatch");
		check(area.scrollbarShown && ui.computePoint("area", "track", .5, .5, out) && ui.computePoint("area", "thumb", .5, .5, out),
			"A scroll area's scrollbar's track and thumb");
		var thumbTop = out[1];
		area.scroll = area.maxScroll;
		frame();
		check(ui.computePoint("area", "thumb", .5, .5, out) && out[1] > thumbTop, "The thumb found where it's moved to");
		var pad = ui.theme.listPadding, row = ui.theme.listRowHeight;
		check(at("items", "row:1", 0, 0, list.layout.x + pad, list.layout.y + pad + row) && ui.computePoint("items", "thumb", .5, .5, out),
			"A list's rows and scrollbar");
		check(!ui.computePoint("items", "row:20", 0, 0, out) && !ui.computePoint("items", "row:x", 0, 0, out), "No row past its items");
		check(!ui.computePoint("pick", "list", 0, 0, out)
			&& !ui.computePoint("pick", "row:0", 0, 0, out), "A dropdown's list only while open");
		check(!ui.computePoint("hidden", "", 0, 0, out)
			&& !ui.computePoint("nobody", "", 0, 0, out)
			&& !ui.computePoint("volume", "knob", 0, 0, out),
			"None for a hidden widget, an unknown one or an unknown part");
		// The autopilot: its drag along the track three-quarters of the way, then the dropdown opened and its third row clicked.
		for (_ in 0...40) {
			pilot.advance(name -> null);
			frame();
			if (pilot.done)
				break;
		}
		check(pilot.done && Math.abs(volume.value - 75) < 1e-3, "An autopilot drags a slider by its track: " + volume.value);
		check(pick.selectedIndex == 2 && !pick.open, "and clicks a dropdown's row: " + pick.selectedIndex);
	}

	// Separators: one across a panel's column (spanning it, as thick as the theme's focusWidth, half a gap of room above and below), one down a
	// row (spanning its height); the theme's faceColor; a theme changed shows at the next frame; never focused or picked.
	static function separators(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var panel = ui.panel(),
			above = ui.button("Above"),
			across = ui.separator(),
			below = ui.button("Below"),
			left = ui.button("Left"),
			down = ui.separator(true, "down"),
			right = ui.button("Right");
		for (w in [above, across, below])
			panel.add(w);
		var row = Layout2D.row();
		row.setSizing(Fit, Fixed(60));
		for (w in [left, down, right]) {
			panel.adopt(w);
			row.add(w.layout);
		}
		panel.content.add(row);
		panel.layout.setSizing(Fixed(400), Fit);
		var layout = holding(sized(Grow(1), Grow(1)), [panel.layout]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame():Void {
			input.endFrame();
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		frame();
		frame();
		var theme = ui.theme,
			line:Shape2D = @:privateAccess across.line,
			upright:Shape2D = @:privateAccess down.line;
		var inner = 400 - theme.padding * 2;
		check(!across.vertical && down.vertical && across.name == "separator" && down.name == "down", "Made across, or down when vertical");
		check(near(across.layout.width, inner)
			&& near(line.width, inner)
			&& near(line.height, theme.focusWidth)
			&& near(across.layout.height, theme.focusWidth + theme.gap),
			"Across the column, as thick as focusWidth, half a gap either side");
		check(near(line.y, across.layout.y + theme.gap / 2) && near(below.layout.y, across.layout.y + across.layout.height + theme.gap),
			"The line in the middle of its room, the next widget a gap under it");
		check(near(upright.height, 60)
			&& near(upright.width, theme.focusWidth)
			&& near(down.layout.width, theme.focusWidth + theme.gap)
			&& near(upright.x, left.layout.x + left.layout.width + theme.gap / 2),
			"Down the row, spanning its height, half a gap either side");
		check(line.color == theme.faceColor && upright.color == theme.faceColor && !line.pickable, "In the faces' color, never picked");
		check(!across.focusable && !down.focusable, "Never focused");
		theme.faceColor = 0xff405060;
		theme.focusWidth = 3;
		theme.gap = 10;
		frame();
		check(line.color == 0xff405060, "The theme changed: its color at the next frame");
		frame();
		check(near(line.height, 3) && near(across.layout.height, 13) && near(upright.width, 3), "Arranged again: its new thickness and room");
		// A game's sizing wins: a separator made narrower keeps its width in the panel's stretching column, at its start.
		across.layout.widthSizing = Fixed(100);
		frame();
		frame();
		check(near(across.layout.width, 100) && near(across.layout.x, panel.content.x + theme.padding), "A width the game sets is kept");
	}

	// Tiles in a grid (rows of a column), with a button under them: arrows and the D-pad move focus across and down the grid on screen, Tab in
	// the order made; a tile is clicked or activated, marked selected, and its picture arrives later.
	static function tiles(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var grid = Layout2D.column(), cells = [];
		grid.gap = 8;
		for (r in 0...2) {
			var row = Layout2D.row();
			row.gap = 8;
			for (c in 0...3) {
				var tile = ui.tile(null, 'Part ${r * 3 + c}', 64);
				cells.push(tile);
				row.add(tile.layout);
			}
			grid.add(row);
		}
		var done = ui.button("Done");
		grid.add(done.layout);
		var layout = holding(sized(Grow(1), Grow(1)), [grid]);
		grid.setAnchor(Center, Center);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame(?keys:Array<helix.input.Key>, ?x:Float, ?y:Float, ?down:Bool):Void {
			input.endFrame();
			if (keys != null)
				for (k in keys) {
					input.keyEvent(k, true);
					input.keyEvent(k, false);
				}
			if (x != null)
				input.pointerEvent(x, y, down == true);
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		frame();
		frame([Down]);
		check(ui.focused == cells[0], "Down: the first tile");
		frame([Right]);
		frame([Down]);
		check(ui.focused == cells[4], "Right then Down: across the row, then down the column, on screen");
		frame([Left]);
		frame([Up]);
		check(ui.focused == cells[0], "Left then Up: back");
		frame([Down]);
		frame([Down]);
		check(ui.focused == done, "Down from the grid's bottom row: the button under it");
		frame([Up]);
		check(ui.focused == cells[3] || ui.focused == cells[4], "Up from the button: back into the grid's bottom row");
		frame([Tab]);
		check(ui.focused == cells[4] || ui.focused == cells[5], "Tab: the next in the order made");
		var middle = cells[1].layout;
		frame(middle.x + middle.width / 2, middle.y + middle.height / 2, true);
		frame(middle.x + middle.width / 2, middle.y + middle.height / 2, false);
		check(cells[1].clicked && ui.focused == cells[1], "A tile is clicked, focus with it");
		for (t in cells)
			t.selected = t == cells[1];
		frame();
		check(cells[1].selected && !cells[0].selected && !cells[1].clicked, "The game marks the chosen tile selected; a click lasts a frame");
		frame([Enter]);
		check(cells[1].clicked, "Enter activates the focused tile");
		check(cells[2].texture == null, "A tile without its picture yet");
		var picture = helix.texture.Texture2D.fromRgba(2, 2, haxe.io.Bytes.alloc(16), new CountingGraphics());
		cells[2].texture = picture;
		check(cells[2].texture == picture && cells[2].caption == "Part 2", "shows it once it comes");
	}

	// The theme changed after the widgets were made: each kind takes its colors, corners and sizes from it at the next update, and its layouts'
	// once arranged again; a layout a game sized itself, and a label's own size and color, are kept; another theme assigned is followed alike.
	static function theming(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(1000, 1600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var panel = ui.panel(),
			title = ui.label("Title"),
			plain = ui.label("Plain"),
			play = ui.button("Play"),
			sound = ui.toggle("Sound", true),
			volume = ui.slider("Volume", 0, 10, 5, 1),
			bar = ui.progress(.5),
			fixedBar = ui.progress(.5),
			name = ui.textField("abc"),
			tile = ui.tile(null, "Part", 64),
			levels = ui.list(["One", "Two", "Three"], 3),
			picker = ui.colorPicker(0xffff0000, true, "tint"),
			same = ui.button("Same"),
			wide = ui.button("Wide"),
			kept = ui.panel();
		title.textSize = 30;
		var startPadding = ui.theme.padding;
		// Values a game set equal to the theme's: still the game's, kept when the theme changes (no guessing from the value); a game's width
		// leaves the height the theme's.
		same.layout.setSizing(Fit, Fixed(40));
		same.layout.setPadding(startPadding * 2, 0, startPadding * 2, 0);
		wide.layout.widthSizing = Fixed(120);
		kept.content.gap = 8;
		kept.content.setPadding(startPadding, startPadding, startPadding, startPadding);
		title.color = 0xff123456;
		volume.valueShown = true;
		fixedBar.layout.setSizing(Grow(1), Fixed(10));
		for (w in [title, plain, play, sound, volume, bar, fixedBar, name, tile, levels, same, wide])
			panel.add(w);
		// The picker in a row, so it keeps its own width (the column would stretch it across).
		var pickerRow = Layout2D.row();
		panel.adopt(picker);
		pickerRow.add(picker.layout);
		panel.content.add(pickerRow);
		panel.layout.setSizing(Fixed(600), Fit);
		var layout = holding(sized(Grow(1), Grow(1)), [panel.layout]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame(?keys:Array<helix.input.Key>):Void {
			input.endFrame();
			if (keys != null)
				for (k in keys) {
					input.keyEvent(k, true);
					input.keyEvent(k, false);
				}
			Layout2D.arrange(layout, 0, 0, 1000, 1600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		frame();
		frame([Down]);
		var theme = ui.theme;
		var playFace:Shape2D = @:privateAccess play.face,
			playLabel:Text2D = @:privateAccess play.label,
			panelFace:Shape2D = @:privateAccess panel.rectangle,
			listFace:Shape2D = @:privateAccess levels.face,
			listRow:Shape2D = @:privateAccess levels.rows[0].face,
			listText:Text2D = @:privateAccess levels.rows[0].text,
			track:Shape2D = @:privateAccess volume.track,
			knob:Shape2D = @:privateAccess volume.knob.disc,
			checkMark:Shape2D = @:privateAccess sound.mark,
			barTrack:Shape2D = @:privateAccess bar.track,
			fieldText:Text2D = @:privateAccess name.textNode,
			caret:Shape2D = @:privateAccess name.caret,
			tileEdge:Shape2D = @:privateAccess tile.edge,
			hueKnob:Shape2D = @:privateAccess picker.hueKnob.disc,
			swatch:Shape2D = @:privateAccess picker.swatchColor,
			ring:Shape2D = @:privateAccess ui.ring;
		check(playFace.cornerRadius == 8
			&& listFace.cornerRadius == 0
			&& play.layout.height == 40
			&& levels.layout.height == 3 * 40 + 8,
			"The theme's look to start");
		var wasPadding = panel.content.paddingLeft,
			wasToggle = sound.layout.height,
			wasSized = fixedBar.layout.height,
			wasPicker = picker.layout.width;
		theme.faceColor = 0xff102030;
		theme.panelColor = 0xff405060;
		theme.accentColor = 0xff00ff00;
		theme.focusColor = 0xffff00ff;
		theme.focusWidth = 3;
		theme.cornerRadius = 3;
		theme.listCornerRadius = 12;
		theme.listRowCornerRadius = 5;
		theme.listRowHeight = 30;
		theme.listPadding = 6;
		theme.trackThickness = 10;
		theme.handleSize = 20;
		theme.textSize = 24;
		theme.padding = 14;
		theme.gap = 12;
		theme.widgetHeight = 50;
		theme.colorPickerWidth = 260;
		frame();
		check(playFace.color == 0xff102030 && playFace.cornerRadius == 3 && playLabel.textSize == 24,
			"A button: its face's color and corners, its text's size");
		check(panelFace.color == 0xff405060 && panelFace.cornerRadius == 3, "A panel: its color and corners");
		check(listFace.color == 0xff102030 && listFace.cornerRadius == 12 && listRow.cornerRadius == 5 && listText.textSize == 24,
			"A list: its color, its corners, its rows' corners and text");
		check(track.color == 0xff102030
			&& track.cornerRadius == 5
			&& @:privateAccess volume.fill.color == 0xff00ff00
			&& knob.radius == 10,
			"A slider: its track's color and round ends, its fill, its handle's size");
		check(checkMark.color == 0xff00ff00 && checkMark.width == 20 && checkMark.cornerRadius == 3 / 4, "A toggle: its mark's color, size and corners");
		check(barTrack.color == 0xff102030 && barTrack.cornerRadius == 3, "A progress bar: its color and corners");
		check(fieldText.textSize == 24 && caret.height == 28 && caret.color == 0xffff00ff, "A text field: its text's size, the caret's");
		check(tileEdge.color == 0xff00ff00 && tileEdge.cornerRadius == 5 && @:privateAccess tile.label.textSize == 24 * .8, "A tile: its edge, its caption");
		check(hueKnob.radius == 10
			&& swatch.radius == (10 + 1.5) * 2 + theme.gap / 4 && @:privateAccess picker.caption.textSize == 24 * .6,
			"A color picker: its handles, its swatch and caption");
		check(ring.visible && ring.color == 0xffff00ff && ring.outline == 3, "The focus ring: its color and width");
		check(@:privateAccess title.node.textSize == 30
			&& @:privateAccess title.node.color == 0xff123456
			&& @:privateAccess plain.node.textSize == 24
			&& @:privateAccess plain.node.color == theme.textColor,
			"A label: its own size and color kept, the theme's otherwise");
		frame();
		check(play.layout.height == 50 && name.layout.height == 50 && volume.layout.height == 50 && sound.layout.height == 50 && wasToggle == 40,
			"Arranged again: the widgets' heights");
		check(levels.layout.height == 3 * 30 + 6 * 2 && listRow.height == 30, "A list's rows' height and its padding");
		check(panel.content.paddingLeft == 14 && wasPadding == startPadding && play.layout.paddingLeft == 28 && name.layout.paddingLeft == 14,
			"Padding: a panel's, a button's, a field's");
		check(panel.content.gap == 12 && @:privateAccess sound.row.gap == 12, "Gaps never set follow the theme");
		check(same.layout.height == 40
			&& same.layout.paddingLeft == startPadding * 2
			&& kept.content.gap == 8
			&& kept.content.paddingLeft == startPadding,
			"Sizing, padding and a gap the game set, equal to the theme's then, are kept");
		check(wide.layout.widthSizing.match(Fixed(120))
			&& wide.layout.height == 50, "A width the game set is kept, the height still the theme's");
		check(@:privateAccess volume.trackLayout.height == 10 && @:privateAccess volume.fill.height == 10, "A slider's track and fill as thick");
		check(bar.layout.height == 24 * .75 && fixedBar.layout.height == 10 && wasSized == 10, "A progress bar's height; one a game sized keeps its own");
		check(wasPicker == 200 && picker.layout.width == 260 && @:privateAccess picker.hueLayout.height == (10 + 1.5) * 2,
			"A color picker: its width, its bars' rows");
		check(picker.textField.layout.height == 24 + 7
			&& picker.formatButton.layout.height == 24 + 7
			&& picker.textField.layout.paddingLeft == 7,
			"Its field's and button's height, from the text's, the field's padding its own");
		check(Type.enumEq(picker.textField.layout.widthSizing, Fixed(@:privateAccess picker.fieldWidth))
			&& Type.enumEq(picker.textField.layout.heightSizing, Fixed(24 + 7)),
			"Its field's sizing the picker's, not the theme's (a field grows, as tall as a widget)");
		frame();
		check(@:privateAccess picker.squareLayout.height == 260, "Its square as tall as its new width");
		// Another theme assigned: followed alike; null is the defaults.
		var other = new helix.ui.Theme();
		other.cornerRadius = 0;
		other.listRowHeight = 20;
		ui.theme = other;
		frame();
		frame();
		check(playFace.cornerRadius == 0 && play.layout.height == 40 && levels.layout.height == 3 * 20 + 8, "Another theme: followed");
		ui.theme = null;
		frame();
		check(ui.theme != null && playFace.cornerRadius == 8, "Null: a new theme, the defaults");
	}

	// A layout laid out direction's way (a stack when not given), sized width x height.
	static function sized(width:Sizing2D, height:Sizing2D, ?direction:LayoutDirection2D):Layout2D {
		var made = new Layout2D(direction != null ? direction : Stack);
		made.setSizing(width, height);
		return made;
	}

	static function fixed(w:Float, h:Float):Layout2D
		return sized(Fixed(w), Fixed(h));

	// Adds children to parent in order; returns parent.
	static function holding(parent:Layout2D, children:Array<Layout2D>):Layout2D {
		for (c in children)
			parent.add(c);
		return parent;
	}

	// The default theme's faces stand apart from its panel whatever is behind the panel: a panel see-through enough that a bright scene behind
	// it (the dressing room's lit plinth, the camera close) brings it to a face's color hides every face on it, its text left floating.
	static function contrast():Void {
		var theme = new helix.ui.Theme();
		for (backdrop in [0xff000000, 0xffffffff]) {
			var panel = over(theme.panelColor, backdrop);
			for (face in [theme.faceColor, theme.hoveredColor, theme.pressedColor])
				check(difference(face, panel) >= 36, 'A face (${StringTools.hex(face, 8)}) apart from the panel over ${StringTools.hex(backdrop, 8)}');
		}
	}

	// color (0xAARRGGBB) blended by its alpha over an opaque backdrop.
	static function over(color:Int, backdrop:Int):Int {
		var a = Color.getAlpha(color) / 255, out = 0xff000000;
		for (shift in [16, 8, 0])
			out |= Math.round(((color >>> shift) & 255) * a + ((backdrop >>> shift) & 255) * (1 - a)) << shift;
		return out;
	}

	// The summed difference of two colors' red, green and blue, 0 to 765.
	static function difference(a:Int, b:Int):Int {
		var sum = 0;
		for (shift in [16, 8, 0])
			sum += Std.int(Math.abs(((a >>> shift) & 255) - ((b >>> shift) & 255)));
		return sum;
	}

	static function layout(font:Font):Void {
		// A row: fixed children, a gap between, padding around; it fits them.
		var a = fixed(50, 20), b = fixed(50, 30), c = fixed(50, 20);
		var row = holding(Layout2D.row(), [a, b, c]);
		row.setPadding(5, 5, 5, 5);
		row.gap = 10;
		Layout2D.arrange(row, 0, 0, 1000, 1000, font);
		check(row.width == 180 && row.height == 40 && a.x == 5 && b.x == 65 && c.x == 125 && a.y == 5, "A row fits its children, gaps and padding");
		// Growing children share what's left by weight; a share of the parent; the main axis centered when none grows.
		var fix = fixed(100, 10),
			one = sized(Grow(1), Fixed(10)),
			two = sized(Grow(2), Fixed(10));
		var grow = holding(sized(Fixed(400), Fixed(10), Row), [fix, one, two]);
		Layout2D.arrange(grow, 0, 0, 1000, 1000, font);
		check(near(one.width, 100) && near(two.width, 200) && near(two.x, 200), "Growing children share the room left by weight");
		var half = sized(Percent(.5), Fixed(10)),
			centred = holding(sized(Fixed(400), Fixed(10), Row), [half]);
		centred.setAlign(Center, Start);
		Layout2D.arrange(centred, 0, 0, 1000, 1000, font);
		check(half.width == 200 && half.x == 100, "A share of the parent, centred when nothing grows");
		// A column stretching its children across: those growing across and those whose width nobody set; the others keep theirs, at the
		// column's start or their own anchor across.
		var wide = Layout2D.stack(),
			grown = sized(Grow(1), Fixed(10)),
			narrow = fixed(40, 10),
			fit = holding(sized(Fit, Fixed(10)), [fixed(60, 10)]),
			share = sized(Percent(.5), Fixed(10)),
			ended = fixed(40, 10);
		wide.heightSizing = Fixed(10);
		ended.setAnchor(End, Start);
		var column = holding(sized(Fixed(300), Fit, Column), [wide, grown, narrow, fit, share, ended]);
		column.setPadding(10, 0, 10, 0);
		column.setAlign(Start, Stretch);
		Layout2D.arrange(column, 0, 0, 1000, 1000, font);
		check(wide.width == 280 && wide.x == 10 && grown.width == 280 && grown.x == 10, "Stretch fills across a column: unsized and growing");
		check(narrow.width == 40 && narrow.x == 10 && fit.width == 60 && fit.x == 10, "A fixed and a fitted width kept in a stretching column");
		check(share.width == 140 && share.x == 10 && ended.width == 40 && ended.x == 250, "A share kept; one anchored at the end across");
		// A row stretching its children down, alike.
		var tall = Layout2D.stack(),
			high = sized(Fixed(10), Grow(1)),
			short = fixed(10, 30),
			fitHigh = holding(sized(Fixed(10), Fit), [fixed(10, 50)]),
			middled = fixed(10, 30);
		tall.widthSizing = Fixed(10);
		middled.setAnchor(Start, Center);
		var across = holding(sized(Fit, Fixed(200), Row), [tall, high, short, fitHigh, middled]);
		across.setAlign(Start, Stretch);
		Layout2D.arrange(across, 0, 0, 1000, 1000, font);
		check(tall.height == 200
			&& high.height == 200
			&& short.height == 30
			&& short.y == 0
			&& fitHigh.height == 50
			&& middled.y == 85,
			"Stretch down a row: unsized and growing filled, fixed and fitted kept, one anchored in the middle");
		// A stack: anchored to a corner and the middle, moved by offsets.
		var corner = fixed(40, 20), middle = fixed(40, 20);
		corner.setAnchor(End, End, -10, -10);
		middle.setAnchor(Center, Center);
		var screen = holding(sized(Grow(1), Grow(1)), [corner, middle]);
		Layout2D.arrange(screen, 0, 0, 800, 600, font);
		check(corner.x == 750 && corner.y == 570 && middle.x == 380 && middle.y == 290, "Anchored to a corner and the middle");
		check(corner.anchorX == End && corner.anchorOffsetY == -10 && screen.gap == 0 && column.crossAlign == Stretch, "A layout answers what it was set to");
		// Nodes placed by their pivots, sprites and rectangles sized; a text fitted to its measure.
		var panel = Shape2D.rectangle(1, 1),
			dot = Shape2D.circle(5),
			label = new Text2D("PLAY", 20, -1, Center);
		var panelLayout = Layout2D.of(panel),
			dotLayout = Layout2D.of(dot),
			labelLayout = Layout2D.of(label);
		panelLayout.heightSizing = Fixed(30);
		var nodes = holding(sized(Fixed(200), Fit, Column), [panelLayout, dotLayout, labelLayout]);
		nodes.setAlign(Start, Stretch);
		nodes.gap = 4;
		Layout2D.arrange(nodes, 10, 10, 1000, 1000, font);
		check(panel.x == 10 && panel.y == 10 && panel.width == 200 && panel.height == 30, "A rectangle at its corner, sized");
		check(dot.x == 110 && dot.y == 49 && dotLayout.height == 10, "A circle at its center (stretched across: the column's middle)");
		check(labelLayout.height == 20 && label.x == 110 && label.y == 58, "A centred text at its middle, as tall as its size");
		var fitted = holding(Layout2D.row(), [Layout2D.of(new Text2D("PLAY", 20))]);
		Layout2D.arrange(fitted, 0, 0, 1000, 1000, font);
		check(near(fitted.width, font.measure("PLAY", 20)), "A text fits its measure");
	}

	// Margins: room outside a layout, adding to the gaps in a row or column (never collapsing), counted in what its parent fits, taken before
	// growing children share the room, kept clear of when stretching or aligning across, insetting it in a stack; the game's kept over the
	// theme's; negative ones refused.
	static function margins(font:Font):Void {
		// A row: margins either side add to the gap; across, they keep it from the padding edge; the row fits them.
		var a = fixed(50, 20), b = fixed(50, 30);
		a.setMargin(5, 3, 7, 0);
		b.setMargin(4, 0, 0, 6);
		var row = holding(Layout2D.row(), [a, b]);
		row.setPadding(2, 2, 2, 2);
		row.gap = 10;
		Layout2D.arrange(row, 0, 0, 1000, 1000, font);
		check(a.x == 7 && b.x == 7 + 50 + 7 + 10 + 4 && a.y == 5 && b.y == 2, "A row: margins add to the gap and keep off the padding edge");
		check(row.width == 2 + 5 + 50 + 7 + 10 + 4 + 50 + 2 && row.height == 2 + 30 + 6 + 2, "A row fits its children's margins");
		// A column: a bottom margin and the next one's top both add to the gap, never collapsing into the larger.
		var top = fixed(40, 20), next = fixed(40, 20);
		top.setMargin(0, 10, 0, 5);
		next.setMargin(0, 8, 0, 0);
		var column = holding(Layout2D.column(), [top, next]);
		column.gap = 4;
		Layout2D.arrange(column, 0, 0, 1000, 1000, font);
		check(top.y == 10
			&& next.y == 10 + 20 + 5 + 4 + 8
			&& column.height == 10 + 20 + 5 + 4 + 8 + 20, "A column: margins added, not collapsed, and fitted");
		// A stack fits its children with their margins.
		var held = fixed(40, 20);
		held.setMargin(1, 2, 3, 4);
		var fitStack = holding(Layout2D.stack(), [held]);
		Layout2D.arrange(fitStack, 0, 0, 1000, 1000, font);
		check(fitStack.width == 44 && fitStack.height == 26 && held.x == 1 && held.y == 2, "A stack fits a child's margins, which inset it");
		// Growing children share the room left after every child's margins; a share is of the room its own margins leave.
		var fix = fixed(100, 10),
			one = sized(Grow(1), Fixed(10)),
			two = sized(Grow(2), Fixed(10));
		fix.setMargin(10, 0, 10, 0);
		one.setMargin(0, 0, 20, 0);
		var grow = holding(sized(Fixed(400), Fixed(10), Row), [fix, one, two]);
		Layout2D.arrange(grow, 0, 0, 1000, 1000, font);
		var left = 400 - 100 - 10 - 10 - 20;
		check(fix.x == 10 && near(one.x, 120) && near(one.width, left / 3) && near(two.width, left * 2 / 3) && near(two.x, 120 + left / 3 + 20),
			"Growing children share the room left after the margins");
		var half = sized(Percent(.5), Fixed(10)),
			centred = holding(sized(Fixed(400), Fixed(10), Row), [half]);
		half.setMargin(20, 0, 20, 0);
		centred.setAlign(Center, Start);
		Layout2D.arrange(centred, 0, 0, 1000, 1000, font);
		check(half.width == 180 && half.x == 90 + 20, "A share of the room its margins leave, its margin box centred");
		// Across a column: stretched less the margins; Center and End place the margin box.
		var stretched = Layout2D.stack(),
			middled = fixed(40, 10),
			ended = fixed(40, 10);
		stretched.heightSizing = Fixed(10);
		stretched.setMargin(6, 0, 4, 0);
		middled.setMargin(10, 0, 0, 0);
		middled.setAnchor(Center, Start);
		ended.setMargin(0, 0, 12, 0);
		ended.setAnchor(End, Start);
		var across = holding(sized(Fixed(300), Fit, Column), [stretched, middled, ended]);
		across.setPadding(10, 0, 10, 0);
		across.setAlign(Start, Stretch);
		Layout2D.arrange(across, 0, 0, 1000, 1000, font);
		check(stretched.width == 300 - 20 - 10 && stretched.x == 10 + 6, "Stretch fills across less the margins");
		check(middled.x == 10 + 10 + (280 - 10 - 40) / 2 && ended.x == 10 + 280 - 12 - 40, "Center and End across place the margin box");
		// Along a column: Center and End place the margin boxes.
		var low = fixed(10, 20), mid = fixed(10, 20);
		low.setMargin(0, 0, 0, 5);
		mid.setMargin(0, 5, 0, 5);
		var ending = holding(sized(Fixed(10), Fixed(100), Column), [low]),
			centring = holding(sized(Fixed(10), Fixed(100), Column), [mid]);
		ending.setAlign(End, Start);
		centring.setAlign(Center, Start);
		Layout2D.arrange(ending, 0, 0, 1000, 1000, font);
		Layout2D.arrange(centring, 0, 0, 1000, 1000, font);
		check(low.y == 100 - 5 - 20 && mid.y == (100 - 30) / 2 + 5, "End and Center along a column place the margin boxes");
		// A stack: stretched inside the margins; anchored to a corner, its offset inside them.
		var filled = Layout2D.stack(), corner = fixed(40, 20);
		filled.setAnchor(Stretch, Stretch);
		filled.setMargin(10, 20, 30, 40);
		corner.setAnchor(End, End, -5, -5);
		corner.setMargin(0, 0, 10, 10);
		var screen = holding(sized(Grow(1), Grow(1)), [filled, corner]);
		Layout2D.arrange(screen, 0, 0, 800, 600, font);
		check(filled.x == 10 && filled.y == 20 && filled.width == 760 && filled.height == 540, "A stack's child stretched inside its margins");
		check(corner.x == 800 - 10 - 40 - 5 && corner.y == 600 - 10 - 20 - 5, "Anchored at a corner, its offset inside its margins");
		// The root's margins inside arrange's rectangle.
		var root = sized(Grow(1), Grow(1));
		root.setMargin(5, 6, 0, 4);
		Layout2D.arrange(root, 0, 0, 1000, 1000, font);
		check(root.x == 5 && root.y == 6 && root.width == 995 && root.height == 990, "The root inside its margins");
		// The theme's margin applies until the game sets one, then never again; a negative or non-finite one is refused, nothing changed.
		var owned = fixed(10, 10);
		@:privateAccess owned.themeMargin(1, 2, 3, 4);
		check(owned.marginLeft == 1 && owned.marginBottom == 4, "The theme's margin while the game set none");
		check(owned.setMargin(0, 0, 0, 0) && owned.marginLeft == 0, "The game's margin, though none");
		@:privateAccess owned.themeMargin(5, 5, 5, 5);
		check(owned.marginLeft == 0 && owned.marginTop == 0, "The game's margin kept over the theme's");
		check(!owned.setMargin(-1, 0, 0, 0)
			&& !owned.setMargin(0, Math.NaN, 0, 0)
			&& !owned.setMargin(0, 0, Math.POSITIVE_INFINITY, 0)
			&& owned.marginLeft == 0
			&& owned.marginTop == 0,
			"A negative or non-finite margin refused");
	}

	// The widgets used by keys, the pointer and a pad's absence: focus order, the ring, activation, the held-key guard, back, a toggle, a
	// slider by keys and by a drag, a list by keys, the wheel and clicks, a disabled button.
	static function widgets(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var panel = ui.panel(),
			play = ui.button("Play"),
			sound = ui.toggle("Sound", true),
			volume = ui.slider("Volume", 0, 10, 5, 1),
			levels = ui.list([for (i in 0...20) 'Level ${i + 1}'], 4),
			off = ui.button("Locked");
		off.enabled = false;
		for (w in [play, sound, volume, levels, off])
			panel.content.add(w.layout);
		panel.layout.setSizing(Fixed(400), Fit);
		panel.layout.setAnchor(Center, Center);
		var layout = holding(sized(Grow(1), Grow(1)), [panel.layout]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		// keys pressed and let go within the frame, or kept down with hold (as an autopilot holds a key for a tick or more).
		function frame(?keys:Array<helix.input.Key>, ?x:Float, ?y:Float, ?down:Bool, wheel = 0., hold = false):Void {
			input.endFrame();
			if (keys != null)
				for (k in keys) {
					input.keyEvent(k, true);
					if (!hold)
						input.keyEvent(k, false);
				}
			if (x != null)
				input.pointerEvent(x, y, down == true);
			if (wheel != 0)
				input.wheelEvent(0, wheel);
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		frame();
		check(ui.focused == null && !ui.capturingKeys, "Nothing focused to start");
		frame([Down]);
		check(ui.focused == play && ui.capturingKeys && ui.focusedName == "Play", "Down: the first button, its name published");
		frame([Down]);
		frame([Enter]);
		check(ui.focused == sound && sound.changed && !sound.on, "Enter switches the toggle");
		frame([Down]);
		frame([Right]);
		check(ui.focused == volume && volume.value == 6 && volume.changed, "Right steps the slider, focus kept");
		frame([Left, Left]);
		check(volume.value == 5, "Left steps back (two presses in a frame are one: frame edges)");
		frame([Down]);
		frame([Down]);
		frame([Down]);
		check(ui.focused == levels && levels.selectedIndex == 1, "Up and Down choose in a focused list");
		frame([Tab]);
		check(ui.focused == play, "Tab leaves the list; the disabled button is skipped, focus wraps");
		frame([Enter]);
		check(play.clicked, "Enter activates the focused button");
		// The pointer: hovering hides the ring and hands back the keys; a click on a button.
		var bx = play.layout.x + 20, by = play.layout.y + 10;
		frame(bx, by, false);
		check(!ui.capturingKeys, "The pointer moving hands back the keys");
		frame(bx, by, true);
		frame(bx, by, false);
		check(play.clicked, "A click on the button");
		var ox = off.layout.x + 10, oy = off.layout.y + 10;
		frame(ox, oy, true);
		frame(ox, oy, false);
		check(!off.clicked, "A disabled button isn't clicked");
		// A drag along the slider's track to its end.
		var sx = volume.layout.x + 5,
			sy = volume.layout.y + volume.layout.height / 2;
		frame(sx, sy, true);
		frame(volume.layout.x + volume.layout.width + 50, sy, true);
		check(volume.value == 10, "Dragged to the end of the track: the most");
		frame(sx, sy, false);
		// The list: the wheel scrolls it; a click chooses the row under the pointer, again activates it.
		var lx = levels.layout.x + 30, ly = levels.layout.y + 10;
		frame(lx, ly, false, -2);
		frame(lx, ly, true);
		frame(lx, ly, false);
		check(levels.selectedIndex == 2 && levels.changed, "Scrolled two rows by the wheel, the top row now the third");
		frame(lx, ly, true);
		frame(lx, ly, false);
		check(levels.activated, "Clicked again: activated");
		// A new screen: Enter held across it does nothing until let go; Escape is back.
		input.keyEvent(Enter, true);
		ui.reset();
		ui.focused = play;
		frame();
		input.keyEvent(Enter, false);
		input.keyEvent(Enter, true);
		frame();
		check(!play.clicked, "A key held into a new screen does nothing");
		input.keyEvent(Enter, false);
		frame();
		frame([Enter]);
		check(play.clicked, "Pressed afresh, it does");
		frame([Escape]);
		check(ui.backPressed, "Escape is back");
		// A new screen with nothing held: a key pressed on its first frame works, and so does a drag begun on it (an autopilot's next tick).
		ui.reset();
		ui.focused = play;
		frame([Enter], null, null, null, 0, true);
		check(play.clicked, "A key pressed on a new screen's first frame, and held, works");
		input.keyEvent(Enter, false);
		ui.reset();
		volume.value = 5;
		frame(sx, sy, true);
		frame(volume.layout.x + volume.layout.width + 50, sy, true);
		check(volume.value == 10, "A drag begun on a new screen's first frame moves the slider");
		frame(sx, sy, false);
		// Something held into a new screen is kept from it until let go, nothing else: the pointer held, a key still works.
		volume.value = 5;
		input.pointerEvent(sx, sy, true);
		ui.reset();
		ui.focused = play;
		frame([Enter], volume.layout.x + volume.layout.width + 50, sy, true);
		check(play.clicked && volume.value == 5 && !volume.changed,
			"The held pointer moves nothing; Enter, pressed after, works: "
			+ play.clicked
			+ " "
			+ volume.value
			+ " "
			+ ui.focused);
		frame(sx, sy, false);
		// Used by name, as a test or an autopilot does: at the next update, when shown and usable.
		check(ui.press("Play") && !play.clicked, "Pressed by name; it takes at the next update");
		frame();
		check(play.clicked && ui.focused == play, "Clicked by name, focus with it");
		check(!ui.press("Locked") && !ui.press("Nothing"), "A disabled widget, or none of that name, isn't pressed");
	}

	// A text field: focused by a click, then typed in (spaces typed, not activating, and claimed from the game), Backspace, Enter, its limit;
	// the keys the UI's meanwhile.
	static function typing(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input),
			name = ui.textField("", "your name", 8);
		var layout = holding(sized(Fixed(300), Fit, Column), [name.layout]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame(?typed:String, ?key:helix.input.Key, ?x:Float, ?y:Float, ?down:Bool):Void {
			input.endFrame();
			if (typed != null)
				input.textEvent(typed);
			if (key != null) {
				input.keyEvent(key, true);
				input.keyEvent(key, false);
			}
			if (x != null)
				input.pointerEvent(x, y, down == true);
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		frame();
		frame(20, 10, true);
		frame(20, 10, false);
		check(ui.focused == name && ui.capturingKeys, "A click focuses the field; the UI has the keys though the pointer gave focus");
		check(input.textEntry, "Typed text is asked for while the field has focus");
		frame("ab c");
		check(name.text == "ab c" && name.changed, "Typed, a space among it");
		frame(" ", Space);
		check(name.text == "ab c " && !name.submitted, "Space types, not activates");
		check(input.isClaimed(Space) && !input.isFramePressed(Space) && !input.isPressed(Space),
			"The field claims the key: the game reading after sees no Space (no jump)");
		frame(Backspace);
		frame("defghijk");
		check(name.text == "ab cdefg", "Backspace takes one off; typing stops at the limit: " + name.text);
		frame(Enter);
		check(name.submitted, "Enter submits");
		ui.reset();
		check(!input.textEntry, "A new screen lets typed text go");
	}

	// HSV to RGBA and back at the edges: the primaries and secondaries at their sixths, black, white and greys, every 8-bit color of a sweep
	// back as it went in, and hex read in its forms and refused in others.
	static function hsv():Void {
		var C = helix.ui.ColorPicker;
		check(C.fromHsv(0, 1, 1) == 0xffff0000 && C.fromHsv(1, 1, 1) == 0xffff0000, "Hue 0 and 1: red");
		check(C.fromHsv(1 / 6, 1, 1) == 0xffffff00
			&& C.fromHsv(2 / 6, 1, 1) == 0xff00ff00
			&& C.fromHsv(3 / 6, 1, 1) == 0xff00ffff
			&& C.fromHsv(4 / 6, 1, 1) == 0xff0000ff
			&& C.fromHsv(5 / 6, 1, 1) == 0xffff00ff,
			"The sixths: yellow, green, cyan, blue, magenta");
		check(C.fromHsv(.3, 0, 1) == 0xffffffff && C.fromHsv(.3, .7, 0) == 0xff000000 && C.fromHsv(.3, 0, .5, 0x80) == 0x80808080,
			"White, black and a grey whatever the hue; alpha as given");
		check(C.fromHsv(-1, 2, 2, 300) == 0xffff0000 && C.fromHsv(0, 1, 1, -5) == 0x00ff0000, "Out of range clamped");
		// Round trips: every 8-bit color of a sweep comes back from its HSV as it went in.
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		var ui = new helix.ui.Ui(null, stage.root, camera, new helix.scene.Pointer(input), input), picker = ui.colorPicker(0xff000000),
			opaque = ui.colorPicker(0xff123456, false), wrong = 0;
		var r = 0;
		while (r < 256) {
			var g = 0;
			while (g < 256) {
				var b = 0;
				while (b < 256) {
					var c = Color.fromChannels(r, g, b, r + g * 3 + b);
					picker.color = c;
					if (picker.color != c || C.fromHsv(picker.hue, picker.saturation, picker.brightness, Color.getAlpha(c)) != c)
						wrong++;
					b += b == 0 || b == 254 ? 1 : 17;
				}
				g += g == 0 || g == 254 ? 1 : 17;
			}
			r += r == 0 || r == 254 ? 1 : 17;
		}
		check(wrong == 0, 'Every color of the sweep back as it went in ($wrong not)');
		// The hue kept through grey and black, the saturation through black.
		picker.color = 0xff3366cc;
		var hue = picker.hue;
		picker.color = 0xff808080;
		check(near(picker.hue, hue) && picker.saturation == 0 && picker.color == 0xff808080, "A grey keeps the hue");
		picker.color = 0xff3366cc;
		var saturation = picker.saturation;
		picker.color = 0xff000000;
		check(near(picker.hue, hue) && near(picker.saturation, saturation) && picker.brightness == 0, "Black keeps the hue and saturation");
		picker.brightness = 0xcc / 255;
		check(picker.color == 0xff3366cc, "Brightened again: the same color");
		picker.hue = 1;
		picker.saturation = 1;
		picker.brightness = 1;
		picker.color = 0xffff0000;
		check(picker.hue == 1, "Red assigned at hue 1 stays at 1 (the top of the bar), not 0");
		check(opaque.color == 0xff123456, "An opaque picker");
		opaque.color = 0x00123456;
		check(opaque.color == 0xff123456, "Without alpha, alpha is 0xff whatever is assigned");
		// Hex.
		check(C.parseHex("ff8800cc") == 0xccff8800 && C.parseHex("#FF8800") == 0xffff8800 && C.parseHex(" #aBcDeF12 ") == 0x12abcdef,
			"Hex: RRGGBBAA, RRGGBB as opaque, #, either case, spaces around");
		check(C.parseHex("ff880") == null && C.parseHex("ff8800c") == null && C.parseHex("gg8800") == null && C.parseHex("") == null
			&& C.parseHex("##ff8800") == null && C.parseHex("ff8800ccdd") == null,
			"Hex: wrong lengths and digits refused");
		check(C.formatHex(0xccff8800, true) == "ff8800cc" && C.formatHex(0xff0a0b0c, false) == "0a0b0c", "Hex written lowercase");
		// Decimal channels.
		check(C.parseRgba("255 136 0 204") == 0xccff8800
			&& C.parseRgba("255,136,0") == 0xffff8800
			&& C.parseRgba(" 1 , 2,3 ,  4 ") == 0x04010203
			&& C.parseRgba("0 0 0 0") == 0
			&& C.parseRgba("007 08 9") == 0xff070809,
			"RGBA: four or three channels apart by spaces or a comma, spaces around");
		check(C.parseRgba("256 0 0") == null && C.parseRgba("1 2") == null && C.parseRgba("1 2 3 4 5") == null && C.parseRgba("1,,2,3") == null
			&& C.parseRgba(",1 2 3") == null && C.parseRgba("1 2 3,") == null && C.parseRgba("1 2 3a") == null && C.parseRgba("1 2 -3") == null
			&& C.parseRgba("0001 2 3") == null && C.parseRgba("") == null && C.parseRgba("1.5 2 3") == null,
			"RGBA: out of range, too few or many channels, doubled or loose commas, other characters refused");
		check(C.formatRgba(0xccff8800, true) == "255 136 0 204"
			&& C.formatRgba(0xff0a0b0c, false) == "10 11 12", "RGBA written apart by spaces");
	}

	// A color picker in a panel: the theme's width there, then grown as wide as the panel's column, its square edge to edge and as tall, the strip and the field's row under it;
	// dragged in its square, along its bars, past their ends and through black (the hue kept); its parts stepped through by Enter and nudged
	// by the arrows, then let go so the arrows move focus again; hex typed in its field, refused text marked and changing nothing, the field
	// showing the color once left; the format cycled by its button (clicked, pressed by name, activated) and decimal channels typed; disabled.
	static function colors(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 900);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var panel = ui.panel(),
			above = ui.button("Above"),
			picker = ui.colorPicker(0xffff0000, true, "tint"),
			below = ui.button("Below");
		for (w in [above, picker, below])
			panel.add(w);
		panel.layout.setSizing(Fixed(500), Fit);
		var layout = holding(sized(Grow(1), Grow(1)), [panel.layout]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame(?keys:Array<helix.input.Key>, ?x:Float, ?y:Float, ?down:Bool, ?typed:String):Void {
			input.endFrame();
			if (keys != null)
				for (k in keys) {
					input.keyEvent(k, true);
					input.keyEvent(k, false);
				}
			if (typed != null)
				input.textEvent(typed);
			if (x != null)
				input.pointerEvent(x, y, down == true);
			Layout2D.arrange(layout, 0, 0, 800, 900, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		function click(b:Layout2D):Void {
			frame(b.x + b.width / 2, b.y + b.height / 2, true);
			frame(b.x + b.width / 2, b.y + b.height / 2, false);
		}
		frame();
		frame();
		var field = picker.textField,
			button = picker.formatButton,
			theme = ui.theme;
		check(picker.layout.width == theme.colorPickerWidth && picker.layout.x == panel.content.x + theme.padding,
			"The theme's width kept in the panel's column, which stretches its children: at its start");
		picker.layout.widthSizing = Grow(1);
		frame();
		frame();
		check(field.name == "tint-text" && button.name == "tint-format" && field.text == "ff0000ff" && field.hint == "RRGGBBAA" && picker.format == Hex,
			"The field and the button named after the picker, the field showing its color as hex");
		// The layout: the square edge to edge across the room the panel's column gives it grown (500 less its padding), as tall; the swatch and the bars in a padded
		// strip under it, the hue's row and the alpha's beside the swatch's middle; the field and the button centered under them.
		var side = picker.layout.width,
			pad = theme.padding,
			square = @:privateAccess picker.squareLayout,
			swatch = @:privateAccess picker.swatchLayout,
			hueRow = @:privateAccess picker.hueLayout,
			alphaRow = @:privateAccess picker.alphaLayout;
		check(side == 500 - pad * 2 && square.x == picker.layout.x && square.y == picker.layout.y && square.width == side && square.height == side,
			"The square edge to edge across the picker's width, as tall: " + side);
		check(swatch.x == picker.layout.x + pad && swatch.y == square.y + side + pad && swatch.width == swatch.height,
			"The swatch at the strip's padded start");
		check(hueRow.x == swatch.x + swatch.width + pad
			&& near(hueRow.x + hueRow.width, picker.layout.x + side - pad)
			&& alphaRow.x == hueRow.x
			&& alphaRow.width == hueRow.width
			&& alphaRow.y > hueRow.y,
			"The bars from beside the swatch to the strip's padded end, the alpha's under the hue's");
		check(near((hueRow.y + alphaRow.y + alphaRow.height) / 2, swatch.y + swatch.height / 2), "The bars beside the swatch's middle");
		check(near((field.layout.x + button.layout.x + button.layout.width) / 2, picker.layout.x + side / 2)
			&& field.layout.y == button.layout.y
			&& field.layout.height == button.layout.height
			&& field.layout.y >= swatch.y + swatch.height + pad,
			"The field and the button centered under the strip, as tall as each other");
		check(picker.layout.y + picker.layout.height == field.layout.y + field.layout.height + 2 + theme.textSize * .6 + pad,
			"The picker ends under the field's caption and the padding");
		// The square: saturation across, brightness up it.
		var sx = square.x, sy = square.y;
		frame(sx + side * .5, sy + side * .25, true);
		check(ui.focused == picker && near(picker.saturation, .5) && near(picker.brightness, .75) && picker.changed,
			"Pressed in the square: saturation across, brightness up it, focus with it");
		check(picker.color == helix.ui.ColorPicker.fromHsv(0, .5, .75), "The color from them");
		frame(sx + side * 2, sy + side * 2, true);
		check(picker.saturation == 1 && picker.brightness == 0 && picker.color == 0xff000000, "Dragged past the corner: clamped, black");
		frame(sx + side * 2, sy + side * 2, false);
		// The hue bar, left to right, between its round ends' centers (half its thickness in from its row's ends); dragged through black keeps
		// it.
		var thickness = theme.trackThickness;
		function along(row:Layout2D, f:Float):Float
			return row.x + thickness / 2 + f * (row.width - thickness);
		var hy = hueRow.y + hueRow.height / 2;
		frame(along(hueRow, .5), hy, true);
		frame(along(hueRow, 2 / 3), hy, true);
		check(near(picker.hue, 2 / 3) && !picker.changed && picker.color == 0xff000000, "The hue moved through black: the color still black");
		frame(along(hueRow, 2 / 3), sy - 100, true);
		check(near(picker.hue, 2 / 3), "Dragged off the bar: still the hue, along it");
		frame(hueRow.x - 50, sy + side * 3, true);
		check(picker.hue == 0, "Past the bar's left end: hue 0");
		frame(hueRow.x - 50, sy + side * 3, false);
		frame(along(hueRow, 1), hueRow.y + 1, true);
		frame(along(hueRow, 1), hueRow.y + 1, false);
		check(picker.hue == 1, "At the right end's center, the top of its row: hue 1");
		frame(sx + side, sy, true);
		check(picker.color == 0xffff0000, "Back to the square's top right: the full hue, red");
		frame(sx + side, sy, false);
		// The alpha bar under it: clear at its left, opaque at its right.
		frame(along(alphaRow, .5), alphaRow.y + alphaRow.height / 2, true);
		frame(along(alphaRow, .5), alphaRow.y + alphaRow.height / 2, false);
		check(picker.color == 0x80ff0000, "Half way along the alpha bar: alpha 0x80");
		frame([Up]);
		check(Color.getAlpha(picker.color) == Math.round(.55 * 255), "Up: the part the pointer chose, alpha up a twentieth");
		frame(swatch.x + swatch.width / 2, swatch.y + swatch.height / 2, true);
		frame(swatch.x + swatch.width / 2, swatch.y + swatch.height / 2 - 40, true);
		frame(swatch.x + swatch.width / 2, swatch.y + swatch.height / 2 - 40, false);
		check(Color.getAlpha(picker.color) == Math.round(.55 * 255)
			&& ui.focused == picker, "Dragged from the swatch: nothing changes, focus kept");
		// Keys: Enter steps through the parts (from the alpha bar to none, then the square), the arrows nudge the one stepped to.
		frame([Enter]);
		frame([Enter]);
		frame([Left]);
		check(near(picker.saturation, .95) && ui.focused == picker, "Enter twice, then Left: saturation down a twentieth, focus kept");
		frame([Down]);
		check(near(picker.brightness, .95) && ui.focused == picker, "Down: brightness down a twentieth, focus kept");
		frame([Enter]);
		frame([Left]);
		check(near(picker.hue, 1 - 1 / 20), "Enter again, then Left: the hue down a twentieth");
		frame([Up]);
		check(picker.hue == 1, "Up: up again");
		frame([Enter]);
		frame([Down]);
		check(Color.getAlpha(picker.color) == 0x80, "Enter again, then Down: alpha down a twentieth");
		frame([Enter]);
		frame([Down]);
		check(ui.focused == field, "Enter once more lets the arrows go: Down moves focus on, to the field under the bars");
		frame([Up]);
		check(ui.focused == picker, "Up: back to the picker");
		// Typing: hex as typed, refused text marked and changing nothing, the color's own hex once the field is left.
		var was = picker.color;
		click(field.layout);
		check(ui.focused == field && ui.capturingKeys, "A click focuses the field");
		for (i in 0...9)
			frame([Backspace]);
		check(field.text == "" && field.invalid && picker.color == Color.withAlpha(was, 255),
			"Emptied: marked invalid; the color the last it named, its first six digits (opaque) on the way");
		was = picker.color;
		frame(null, null, null, null, "#33");
		frame();
		check(field.invalid && picker.color == was, "Part of a color: marked invalid, the color unchanged");
		frame(null, null, null, null, "66cc");
		frame();
		check(!field.invalid && picker.color == 0xff3366cc && field.text == "#3366cc", "RRGGBB with #: taken as opaque, the text left as typed");
		frame(null, null, null, null, "4");
		frame(null, null, null, null, "0");
		frame();
		check(picker.color == 0x403366cc, "RRGGBBAA: alpha too");
		frame([Backspace]);
		frame(null, null, null, null, "x");
		frame();
		check(field.invalid && picker.color == 0x403366cc, "A wrong digit: marked, the color kept");
		frame([Tab]);
		frame();
		check(ui.focused == button && field.text == "3366cc40" && !field.invalid, "Left for the button after it: the field shows the color again");
		// The format: the button cycles it, the field showing the color in it at once; decimal channels typed.
		click(button.layout);
		check(picker.format == Rgba && field.text == "51 102 204 64" && field.hint == "r g b a" && ui.focused == button,
			"Clicked: decimal channels, shown at once");
		check(@:privateAccess picker.caption.text == "RGBA", "Its caption names it");
		click(field.layout);
		for (i in 0...13)
			frame([Backspace]);
		frame(null, null, null, null, "10, 20, 30");
		frame();
		check(!field.invalid && picker.color == 0xff0a141e, "Three channels apart by commas: taken as opaque");
		frame(null, null, null, null, " 300");
		frame();
		check(field.invalid && picker.color == 0xff0a141e, "A channel past 255: marked, the color kept");
		frame([Tab]);
		frame();
		check(field.text == "10 20 30 255" && !field.invalid, "Left: the color in decimal again");
		frame([Enter]);
		check(picker.format == Hex && field.text == "0a141eff" && @:privateAccess picker.caption.text == "HEX", "Enter on the focused button: hex again");
		check(ui.press("tint-format"), "Pressed by name");
		frame();
		check(picker.format == Rgba, "Pressed: decimal");
		picker.format = Hex;
		frame();
		check(field.text == "0a141eff", "Assigned: hex");
		// Disabled: not dragged, its field and button disabled with it.
		picker.enabled = false;
		frame(sx + 1, sy + 1, true);
		frame(sx + 1, sy + 1, false);
		click(button.layout);
		check(picker.color == 0xff0a141e && !field.enabled && !button.enabled && picker.format == Hex,
			"Disabled: not dragged, the field and the button with it");
		ui.remove(picker);
		check(ui.find("tint-text") == null && ui.find("tint-format") == null, "Removed with its field and its button");
		// Without alpha: no alpha bar, a smaller swatch beside the hue bar, three channels; in a row, its own width.
		var opaque = ui.colorPicker(0xff112233, false, "plain"),
			row = Layout2D.row();
		panel.adopt(opaque);
		row.add(opaque.layout);
		panel.content.add(row);
		frame();
		frame();
		var plainSwatch = @:privateAccess opaque.swatchLayout,
			plainHue = @:privateAccess opaque.hueLayout;
		check(opaque.layout.width == theme.colorPickerWidth && @:privateAccess opaque.squareLayout.height == opaque.layout.width,
			"In a row: its own width, the square as tall");
		check(@:privateAccess opaque.alphaLayout == null && plainSwatch.height < swatch.height && near(plainHue.y + plainHue.height / 2,
			plainSwatch.y + plainSwatch.height / 2),
			"No alpha bar; a smaller swatch, the hue bar beside its middle");
		opaque.format = Rgba;
		frame();
		check(opaque.textField.text == "17 34 51" && opaque.textField.hint == "r g b" && @:privateAccess opaque.caption.text == "RGB",
			"Without alpha: three channels, RGB");
	}

	// A scroll area of buttons and a list: their scrollbars' thumbs sized and placed by the content, the wheel, drags on the content, the thumb
	// and the track, keys and focus scrolling them, held to their ends; clipped widgets not taking the pointer; the bar shown always, when
	// needed or never, the content narrowing for it; theme changes at the next frame.
	static function scrolling(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var top = ui.button("Top"),
			area = ui.scrollArea(200, "area"),
			buttons = [for (i in 0...10) ui.button('B$i')],
			after = ui.button("After"),
			fits = ui.scrollArea(200, "fits"),
			few = [for (i in 0...2) ui.button('F$i')],
			notes = ui.scrollArea(100, "notes"),
			lines = [for (i in 0...6) ui.label('Line $i')],
			list = ui.list([for (i in 0...20) 'Item $i'], 4, "items"),
			short = ui.list(["One", "Two"], 4, "short");
		for (b in buttons)
			area.add(b);
		for (b in few)
			fits.add(b);
		for (l in lines)
			notes.add(l);
		// The area 100 units down, 300 wide, After right under it; the others beside it.
		top.layout.setSizing(Grow(1), Fixed(100));
		var column = Layout2D.column();
		column.setSizing(Fixed(300), Grow(1));
		for (w in [top, area, after])
			column.add(w.layout);
		var others = Layout2D.column();
		others.setSizing(Fixed(300), Grow(1));
		others.gap = 10;
		for (w in [fits, notes, list, short])
			others.add(w.layout);
		var layout = Layout2D.row();
		layout.setSizing(Grow(1), Grow(1));
		layout.gap = 50;
		layout.add(column);
		layout.add(others);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame(?keys:Array<helix.input.Key>, ?x:Float, ?y:Float, ?down:Bool, wheel = 0.):Void {
			input.endFrame();
			if (keys != null)
				for (k in keys) {
					input.keyEvent(k, true);
					input.keyEvent(k, false);
				}
			if (x != null)
				input.pointerEvent(x, y, down == true);
			if (wheel != 0)
				input.wheelEvent(0, wheel);
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		var bar:helix.ui.Scrollbar = @:privateAccess area.bar;
		frame();
		frame();
		// Ten buttons 40 tall, 8 apart: 472 units of content in a 200-unit window.
		check(near(area.layout.y, 100) && near(area.layout.height, 200), "The area's window: its height as made");
		check(near(area.content.height, 472) && near(area.maxScroll, 272), "Its content's height, and how far it scrolls");
		check(area.scrollbarShown && near(bar.width, 8), "The bar shown, the content overflowing");
		check(near(bar.thumbLength, 200 * 200 / 472) && near(bar.thumbOffset, 0), "The thumb the share in view, at the top");
		check(near(buttons[0].layout.width, 300 - 8 - 8), "The buttons narrowed for the bar and a gap");
		// The wheel over a button in it scrolls it a widget's height a notch, held to its ends.
		frame(50, 120, false, -1);
		check(near(area.scroll, 40), "The wheel over a button scrolls the area");
		frame(50, 120, false, 5);
		check(near(area.scroll, 0), "Held at the top");
		frame(50, 120, false, -100);
		check(near(area.scroll, 272) && near(bar.thumbOffset, 200 - bar.thumbLength), "Held at the end, the thumb at the bottom");
		frame(50, 80, false, -1);
		frame(50, 80, false, 1);
		check(near(area.scroll, 272), "The wheel outside it does nothing");
		// What's clipped isn't picked: B0 scrolled 30 up out of the window's top; B4 reaching under its bottom, over After.
		area.scroll = 30;
		frame(50, 50, false);
		frame(50, 50, false);
		check(near(buttons[0].layout.y, 70), "Arranged at the scroll: B0 above the window's top");
		frame(50, 90, true);
		frame(50, 90, false);
		check(!buttons[0].clicked, "B0's clipped part isn't clicked");
		frame(50, 105, true);
		frame(50, 105, false);
		check(buttons[0].clicked, "B0's part in view is");
		check(near(buttons[4].layout.y + buttons[4].layout.height, 302)
			&& near(after.layout.y, 300), "B4 reaching past the window, over After");
		frame(50, 301, true);
		frame(50, 301, false);
		check(after.clicked && !buttons[4].clicked, "Under the window After takes the click, not B4");
		// A drag on the content's empty space (a gap between buttons) scrolls it with the pointer.
		area.scroll = 0;
		frame(50, 50, false);
		frame(50, 50, false);
		frame(50, 144, true);
		frame(50, 104, true);
		check(near(area.scroll, 40), "Dragged up 40: scrolled 40");
		frame(50, 84, true);
		frame(50, 84, false);
		check(near(area.scroll, 60), "And on with the pointer");
		check(!buttons[0].clicked && !buttons[1].clicked, "A drag clicks nothing");
		// The thumb dragged: its top follows the pointer, the scroll in proportion; past the end held there.
		frame(296, 300, false);
		var grabY = 100 + bar.thumbOffset + 5, offset = bar.thumbOffset;
		frame(296, grabY, true);
		check(bar.dragging && near(area.scroll, 60), "The thumb taken, nothing moved yet");
		frame(296, grabY + 20, true);
		check(near(area.scroll, (offset + 20) / (200 - bar.thumbLength) * 272), "Dragged 20 down: the scroll in proportion");
		frame(296, 590, true);
		check(near(area.scroll, 272), "Dragged past the end: held there");
		frame(296, 590, false);
		check(!bar.dragging, "Let go");
		// The track pressed above the thumb: a page (the window's height) up.
		frame(296, 105, true);
		frame(296, 105, false);
		check(near(area.scroll, 72), "The track above the thumb: a page up");
		frame(296, 299, true);
		frame(296, 299, false);
		check(near(area.scroll, 272), "Below it: a page down, held at the end");
		// Focus moved by the game or keys to a button out of view scrolls it into view, with room for the ring; Page Up and Down page.
		area.scroll = 0;
		frame(50, 50, false);
		ui.focused = buttons[6];
		frame();
		var margin = ui.theme.focusWidth * 3;
		check(near(area.scroll, 6 * 48 + 40 + margin - 200), "Focus on B6: scrolled to show it");
		frame([Tab]);
		check(ui.focused == buttons[7] && near(area.scroll, 7 * 48 + 40 + margin - 200), "Tab to B7: on to show it");
		frame([Up]);
		frame([Up]);
		frame([Up]);
		frame([Up]);
		frame([Up]);
		check(ui.focused == buttons[2] && near(area.scroll, 2 * 48 - margin), "Up to B2, above the window: scrolled back to it");
		frame([PageDown]);
		check(near(area.scroll, 272), "Page Down with focus in it: a page, held at the end");
		frame([PageUp]);
		check(near(area.scroll, 72), "Page Up: a page back");
		frame([PageUp]);
		check(near(area.scroll, 0), "And held at the top");
		// An area with nothing focusable in it takes focus itself; Up and Down step it.
		ui.focused = notes;
		frame();
		frame([Down]);
		check(ui.focused == notes && near(notes.scroll, ui.theme.widgetHeight), "Down steps an area holding no focusable widget");
		// Content that fits: no bar, the buttons full width, nothing to scroll.
		check(near(fits.maxScroll, 0) && !fits.scrollbarShown && near(few[0].layout.width, 300), "Content that fits: no bar, full width");
		frame(350 + 50, 20, false, -1);
		check(near(fits.scroll, 0), "Nothing to scroll");
		// Always: the bar drawn with content that fits, its thumb the track's length, the buttons narrowed; Never: no bar, full width, still
		// scrolled by the wheel.
		fits.scrollbarVisibility = Always;
		area.scrollbarVisibility = Never;
		frame();
		frame();
		var fitsBar:helix.ui.Scrollbar = @:privateAccess fits.bar;
		check(fits.scrollbarShown && near(fitsBar.thumbLength, 200) && near(fitsBar.thumbOffset, 0), "Always: shown, the thumb the whole track");
		check(near(few[0].layout.width, 284), "Always: the buttons narrowed for it");
		check(!area.scrollbarShown && near(buttons[0].layout.width, 300), "Never: no bar, the buttons full width");
		frame(50, 120, false, -1);
		check(near(area.scroll, 40), "Never: still scrolled by the wheel");
		frame(296, 150, true);
		frame(296, 150, false);
		check(near(area.scroll, 40), "Never: no track to press at the right edge");
		// The list's bar: inside its padding at the right, its rows narrowed, its thumb dragged and its track pressed; none when it fits.
		var listBar:helix.ui.Scrollbar = @:privateAccess list.bar,
			pad = ui.theme.listPadding;
		var lx = list.layout.x, ly = list.layout.y, lw = list.layout.width;
		check(list.scrollbarShown && !short.scrollbarShown, "The long list's bar shown, the short one's not");
		check(near(listBar.thumbLength, 160 * 160 / 800) && near(listBar.thumbOffset, 0), "The list's thumb: the share in view");
		var rows:Array<{face:Shape2D, text:Text2D}> = @:privateAccess list.rows;
		var shortRows:Array<{face:Shape2D, text:Text2D}> = @:privateAccess short.rows;
		check(near(rows[0].face.width, lw - pad * 2 - 8 - pad)
			&& near(shortRows[0].face.width, lw - pad * 2), "Rows narrowed for the bar only where it shows");
		var bx = lx + lw - pad - 4;
		frame(bx, ly + pad + 150, true);
		frame(bx, ly + pad + 150, false);
		var listScroll:Float = @:privateAccess list.scroll;
		check(near(listScroll, 160) && list.selectedIndex == -1, "The list's track below the thumb: a page down, no row chosen");
		var thumbY = ly + pad + listBar.thumbOffset + 2;
		frame(bx, thumbY, true);
		frame(bx, thumbY + 64, true);
		frame(bx, thumbY + 64, false);
		listScroll = @:privateAccess list.scroll;
		check(near(listScroll, 160 + 64 / (160 - listBar.thumbLength) * 640), "The list's thumb dragged: the scroll in proportion");
		short.scrollbarVisibility = Always;
		frame();
		check(short.scrollbarShown
			&& near(shortRows[0].face.width, lw - pad * 2 - 8 - pad), "A short list's bar Always: shown, its rows narrowed");
		// The theme: its width, its track's color and its visibility at the next frame; a widget's own visibility kept.
		ui.theme.scrollbarThickness = 12;
		ui.theme.scrollbarTrackColor = 0x44112233;
		ui.theme.scrollbarVisibility = Never;
		frame();
		var track:Shape2D = @:privateAccess fitsBar.track;
		check(near(fitsBar.width, 12) && track.color == 0x44112233 && near(track.width, 12), "The theme's thickness and color at the next frame");
		check(fits.scrollbarShown && short.scrollbarShown && !list.scrollbarShown, "The theme's Never; the widgets' own Always kept");
		ui.theme.scrollbarVisibility = null;
		check(ui.theme.scrollbarVisibility == WhenNeeded, "A null visibility is WhenNeeded");
		frame();
		frame();
		check(list.scrollbarShown
			&& near(rows[0].face.width, lw - pad * 2 - 12 - pad), "Back to WhenNeeded, the rows narrowed for the wider bar");
		check(near(few[0].layout.width, 300 - 12 - 8), "The area's content narrowed for the wider bar at the next arrange");
	}

	// The states' priority (WidgetState: disabled, down, over, focused, normal), then every interactive widget's parts after a frame in each:
	// the pointer away, over them, held on them, focus moved to them by keys, disabled.
	static function states(font:Font):Void {
		// The table: every combination of enabled, down, over and focused, its state the first that holds in that order.
		for (k in 0...16) {
			var enabled = k & 1 != 0,
				down = k & 2 != 0,
				over = k & 4 != 0,
				focused = k & 8 != 0;
			var state = WidgetState.of(enabled, down, over, focused),
				expected = !enabled ? Disabled : down ? Down : over ? Over : focused ? Focused : Normal;
			check(state == expected, 'The state for enabled $enabled, down $down, over $over, focused $focused');
			var picked = state.pick(1, 2, 3, 4, 5);
			check(picked == switch expected {
				case Normal: 1;
				case Over: 2;
				case Down: 3;
				case Focused: 4;
				case Disabled: 5;
			}, "Each state picks its own color");
		}
		check(WidgetState.dim(0xff2e3448) == 0x7f2e3448
			&& WidgetState.dim(0x00112233) == 0x00112233, "Dimmed: the color at half its alpha");
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 1200);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var play = ui.button("Play"),
			off = ui.button("Locked"),
			sound = ui.toggle("Sound", true),
			name = ui.textField("abc"),
			volume = ui.slider("Volume", 0, 10, 5, 1),
			levels = ui.list([for (i in 0...20) 'Level ${i + 1}'], 4),
			part = ui.tile(null, "Part", 64),
			picker = ui.colorPicker(0xffff0000, true, "tint");
		off.enabled = false;
		var column = Layout2D.column();
		column.setSizing(Fixed(400), Grow(1));
		column.gap = 10;
		for (w in [play, off, sound, name, volume, levels, part])
			column.add(w.layout);
		var pickerRow = Layout2D.row();
		pickerRow.add(picker.layout);
		column.add(pickerRow);
		var layout = holding(sized(Grow(1), Grow(1)), [column]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame(?keys:Array<helix.input.Key>, ?x:Float, ?y:Float, ?down:Bool):Void {
			input.endFrame();
			if (keys != null)
				for (k in keys) {
					input.keyEvent(k, true);
					input.keyEvent(k, false);
				}
			if (x != null)
				input.pointerEvent(x, y, down == true);
			Layout2D.arrange(layout, 0, 0, 800, 1200, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		var theme = ui.theme;
		var playFace:Shape2D = @:privateAccess play.face,
			playLabel:Text2D = @:privateAccess play.label,
			offFace:Shape2D = @:privateAccess off.face,
			offLabel:Text2D = @:privateAccess off.label,
			box:Shape2D = @:privateAccess sound.check,
			fieldFace:Shape2D = @:privateAccess name.face,
			knob:Shape2D = @:privateAccess volume.knob.disc,
			tileFace:Shape2D = @:privateAccess part.face,
			thumb:Shape2D = @:privateAccess levels.bar.thumb,
			hueKnob:Shape2D = @:privateAccess picker.hueKnob.disc,
			squareMark:Shape2D = @:privateAccess picker.squareMark;
		function rowFace(i:Int):Shape2D
			return @:privateAccess levels.rows[i].face;
		// Away: every part at rest; the disabled button dimmed whatever the pointer does.
		frame(790, 1190, false);
		frame(790, 1190, false);
		check(playFace.color == theme.faceColor && playLabel.color == theme.textColor, "A button at rest");
		check(offFace.color == WidgetState.dim(theme.faceColor) && offLabel.color == theme.disabledTextColor,
			"A disabled button: its face dimmed, its text greyed");
		check(box.color == theme.faceColor && fieldFace.color == theme.faceColor && tileFace.color == theme.faceColor,
			"A toggle's box, a field's face, a tile's face at rest");
		check(knob.color == theme.handleColor && thumb.color == theme.handleColor && hueKnob.color == theme.handleColor
			&& squareMark.color == theme.handleColor,
			"Handles at rest: a slider's, a list's thumb, a color picker's");
		check([for (i in 0...4) rowFace(i).color].join(",") == "0,0,0,0", "A list's rows clear at rest");
		// Over each widget: its face lit; held: pressed.
		function over(l:Layout2D):Void
			frame(l.x + 8, l.y + l.height / 2, false);
		function held(l:Layout2D):Void
			frame(l.x + 8, l.y + l.height / 2, true);
		over(play.layout);
		check(playFace.color == theme.hoveredColor, "A button under the pointer: hovered");
		held(play.layout);
		check(playFace.color == theme.pressedColor, "Held: pressed");
		over(play.layout);
		over(off.layout);
		check(offFace.color == WidgetState.dim(theme.faceColor) && offLabel.color == theme.disabledTextColor,
			"A disabled button under the pointer: still dimmed");
		held(off.layout);
		check(offFace.color == WidgetState.dim(theme.faceColor), "Held: still dimmed (disabled first)");
		over(off.layout);
		over(sound.layout);
		check(box.color == theme.hoveredColor, "A toggle under the pointer: its box hovered");
		held(sound.layout);
		check(box.color == theme.pressedColor, "Held: pressed");
		over(sound.layout);
		over(part.layout);
		check(tileFace.color == theme.hoveredColor, "A tile under the pointer: hovered");
		held(part.layout);
		check(tileFace.color == theme.pressedColor, "Held: pressed");
		over(part.layout);
		over(name.layout);
		check(fieldFace.color == theme.hoveredColor, "A field under the pointer: hovered");
		// A slider's knob: over anywhere on the slider (a press there moves it), held while dragged.
		var sy = volume.layout.y + volume.layout.height / 2,
			trackLayout:Layout2D = @:privateAccess volume.trackLayout,
			mid = trackLayout.x + trackLayout.width / 2;
		frame(mid, sy, false);
		check(knob.color == theme.accentColor, "A slider under the pointer: its knob over");
		frame(mid, sy, true);
		check(knob.color == theme.focusColor, "Held: its knob down");
		frame(mid, sy, false);
		frame(790, 1190, false);
		check(knob.color == theme.handleColor, "Let go and left: at rest");
		// Focus by keys, the pointer away: a button's face stays at rest (the ring shows focus); a field's is lit.
		ui.focused = play;
		frame();
		check(ui.focused == play && playFace.color == theme.faceColor, "A focused button: at rest, the ring showing focus");
		ui.focused = name;
		frame();
		check(fieldFace.color == theme.hoveredColor, "A focused field: lit as it's typed in");
		ui.focused = null;
		frame();
		check(fieldFace.color == theme.faceColor, "Left: at rest");
		// A list: the row under the pointer hovered, held pressed; the chosen row in the accent color, hovered or not.
		var lx = levels.layout.x + 30,
			pad = theme.listPadding,
			rowY = (i:Int) -> levels.layout.y + pad + i * theme.listRowHeight + theme.listRowHeight / 2;
		frame(lx, rowY(1), false);
		check(rowFace(1).color == theme.hoveredColor && rowFace(0).color == 0 && rowFace(2).color == 0,
			"A list's row under the pointer: hovered, the others clear");
		frame(lx, rowY(1), true);
		check(rowFace(1).color == theme.pressedColor, "Held on it: pressed");
		frame(lx, rowY(1), false);
		check(levels.selectedIndex == 1 && rowFace(1).color == theme.accentColor, "Clicked: chosen, in the accent color though under the pointer");
		frame(lx, rowY(2), false);
		check(rowFace(1).color == theme.accentColor
			&& rowFace(2).color == theme.hoveredColor, "Another row hovered beside the chosen one");
		frame(790, 1190, false);
		check(rowFace(2).color == 0 && rowFace(1).color == theme.accentColor, "Left: the chosen row only");
		// Its scrollbar's thumb: over under the pointer, down dragged; no row hovered while the pointer's on the bar.
		var bar:helix.ui.Scrollbar = @:privateAccess levels.bar,
			tx = levels.layout.x + levels.layout.width - pad - bar.width / 2,
			ty = levels.layout.y + pad + bar.thumbOffset + bar.thumbLength / 2;
		frame(tx, ty, false);
		check(thumb.color == theme.accentColor && rowFace(0).color == 0, "The thumb under the pointer: over, no row hovered");
		frame(tx, ty, true);
		frame(tx, ty + 5, true);
		check(thumb.color == theme.focusColor, "Dragged: down");
		frame(tx, ty + 5, false);
		frame(790, 1190, false);
		check(thumb.color == theme.handleColor, "Let go and left: at rest");
		// A color picker's handles: the one over the part under the pointer, the other at rest.
		var hue:Layout2D = @:privateAccess picker.hueLayout,
			square:Layout2D = @:privateAccess picker.squareLayout;
		frame(hue.x + hue.width / 2, hue.y + hue.height / 2, false);
		check(hueKnob.color == theme.accentColor && squareMark.color == theme.handleColor, "Over the hue bar: its handle over");
		frame(square.x + square.width / 2, square.y + square.height / 2, false);
		check(squareMark.color == theme.accentColor && hueKnob.color == theme.handleColor, "Over the square: its handle over");
		frame(square.x + square.width / 2, square.y + square.height / 2, true);
		check(squareMark.color == theme.focusColor, "Dragged: down");
		frame(square.x + square.width / 2, square.y + square.height / 2, false);
		frame(790, 1190, false);
		check(squareMark.color == theme.focusColor
			&& hueKnob.color == theme.handleColor, "Left with focus: the part the keys drive focused");
		// Disabled, every widget: faces dimmed, text greyed, handles dimmed, even under the pointer.
		for (w in [play, sound, name, volume, levels, part])
			w.enabled = false;
		picker.enabled = false;
		frame(lx, rowY(2), false);
		frame(lx, rowY(2), false);
		check(playFace.color == WidgetState.dim(theme.faceColor) && playLabel.color == theme.disabledTextColor, "A disabled button");
		check(box.color == WidgetState.dim(theme.faceColor)
			&& @:privateAccess sound.mark.color == WidgetState.dim(theme.accentColor)
			&& @:privateAccess sound.label.color == theme.disabledTextColor,
			"A disabled toggle: box and mark dimmed, text greyed");
		check(fieldFace.color == WidgetState.dim(theme.faceColor)
			&& @:privateAccess name.textNode.color == theme.disabledTextColor, "A disabled field");
		check(knob.color == WidgetState.dim(theme.handleColor)
			&& @:privateAccess volume.track.color == WidgetState.dim(theme.faceColor)
			&& @:privateAccess volume.label.color == theme.disabledTextColor,
			"A disabled slider: knob and track dimmed, text greyed");
		check(rowFace(2).color == 0
			&& rowFace(1).color == WidgetState.dim(theme.accentColor)
			&& @:privateAccess levels.rows[2].text.color == theme.disabledTextColor
			&& thumb.color == WidgetState.dim(theme.handleColor),
			"A disabled list: no row hovered, the chosen one dimmed, text greyed, its thumb dimmed");
		check(tileFace.color == WidgetState.dim(theme.faceColor)
			&& @:privateAccess part.label.color == theme.disabledTextColor, "A disabled tile");
		check(hueKnob.color == WidgetState.dim(theme.handleColor) && squareMark.color == WidgetState.dim(theme.handleColor),
			"A disabled color picker's handles dimmed");
	}

	// A panel's title: a band across its top as tall as a line of text and a padding, its widgets under it, its text the title; its look the
	// theme's at the next frame; none for null or "".
	static function titled(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var panel = ui.panel("menu"), play = ui.button("Play");
		panel.add(play);
		panel.layout.setSizing(Fixed(300), Fit);
		var layout = holding(sized(Grow(1), Grow(1)), [panel.layout]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame():Void {
			input.endFrame();
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		frame();
		var theme = ui.theme;
		var untitled = panel.layout.height,
			band:helix.render2d.Node2D = @:privateAccess panel.band,
			bandFace:Shape2D = @:privateAccess panel.bandFace,
			bandText:Text2D = @:privateAccess panel.bandText,
			bandLayout:Layout2D = @:privateAccess panel.bandLayout;
		check(panel.title == null && !band.visible && !bandText.visible && near(play.layout.y, theme.padding), "No title: no band");
		panel.title = "Shaders";
		frame();
		frame();
		var height = theme.textSize + theme.padding;
		check(band.visible && bandText.visible && bandText.text == "Shaders", "Titled: the band, its text the title");
		check(near(bandLayout.y, 0) && near(bandLayout.height, height) && near(bandLayout.width, 300), "The band across its top, a line and a padding tall");
		check(near(panel.content.y, height) && near(play.layout.y, height + theme.padding) && near(panel.layout.height, untitled + height),
			"Its widgets under the band, the panel taller by it");
		check(near(bandText.x, theme.padding) && bandText.y > 0 && bandText.y < height, "The title a padding in, in the band");
		check(bandFace.color == theme.faceColor
			&& bandText.color == theme.textColor
			&& near(bandFace.cornerRadius, theme.cornerRadius)
			&& near(bandFace.height, height + theme.cornerRadius)
			&& near(band.clipHeight, height),
			"The band in the faces' color, its top corners the panel's, its bottom cut square (its face a corner taller, clipped)");
		// The theme changed: at the next frame (its height once arranged again).
		theme.faceColor = 0xff102030;
		theme.textColor = 0xffa0b0c0;
		theme.cornerRadius = 4;
		theme.textSize = 24;
		theme.padding = 6;
		frame();
		check(bandFace.color == 0xff102030 && bandText.color == 0xffa0b0c0 && bandFace.cornerRadius == 4 && bandText.textSize == 24,
			"The theme changed: the band's look at the next frame");
		frame();
		check(near(bandLayout.height, 30) && near(panel.content.y, 30) && near(play.layout.y, 36), "Arranged again: its new height, its widgets under it");
		panel.title = "";
		frame();
		frame();
		check(!band.visible && !bandText.visible && near(panel.content.y, 0), "\"\": no band, its widgets at its top again");
	}

	// The popup layer and a dropdown on it: a dropdown in a scroll area whose window clips it, a button under it and one beside, and a long
	// dropdown at the bottom right. Its list is drawn and picked above everything and outside the area's clip, takes the pointer (a press off
	// it closes it and does nothing else) and the keys, and is placed below its face, or above it at the bottom, kept on screen across.
	static function dropdowns(font:Font):Void {
		var input = new helix.input.InputState(),
			stage = new helix.render2d.Renderer2D(),
			camera = new helix.render2d.Camera2D();
		camera.setViewport(800, 600);
		camera.pixels(1);
		var pointer = new helix.scene.Pointer(input);
		pointer.addRenderer2D(stage, camera);
		var ui = new helix.ui.Ui(null, stage.root, camera, pointer, input);
		var sizes = ["Small", "Medium", "Large", "Huge", "Tiny"];
		var area = ui.scrollArea(80, "area"),
			size = ui.dropdown(sizes, 0, "size"),
			under = ui.button("Under"),
			other = ui.button("Other"),
			long = ui.dropdown([for (i in 0...20) 'Item $i'], 15, "long");
		area.add(size);
		var column = Layout2D.column();
		column.setSizing(Fixed(300), Fit);
		for (w in [area, under])
			column.add(w.layout);
		column.setAnchor(Start, Start);
		other.layout.setAnchor(Start, Start, 500, 0);
		long.layout.setAnchor(End, End);
		var layout = holding(sized(Grow(1), Grow(1)), [column, other.layout, long.layout]);
		var batch = new helix.render2d.Batch2D(new CountingGraphics());
		function frame(?keys:Array<helix.input.Key>, ?x:Float, ?y:Float, ?down:Bool, wheel = 0.):Void {
			input.endFrame();
			if (keys != null)
				for (k in keys) {
					input.keyEvent(k, true);
					input.keyEvent(k, false);
				}
			if (x != null)
				input.pointerEvent(x, y, down == true);
			if (wheel != 0)
				input.wheelEvent(0, wheel);
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		function click(x:Float, y:Float):Void {
			frame(x, y, true);
			frame(x, y, false);
		}
		var theme = ui.theme,
			pad = theme.listPadding,
			rowHeight = theme.listRowHeight;
		frame(790, 300, false);
		frame(790, 300, false);
		var widest = 0.;
		for (item in long.items)
			widest = Math.max(widest, font.measure(item, theme.textSize));
		check(near(long.layout.width, theme.padding * 2 + theme.padding / 2 + widest + theme.widgetHeight * .4)
			&& near(long.layout.height, theme.widgetHeight),
			"Fit: as wide as its widest item, the gap and the chevron's room, a widget tall");
		var widestSize = 0.;
		for (item in sizes)
			widestSize = Math.max(widestSize, font.measure(item, theme.textSize));
		check(near(size.layout.width, theme.padding * 2 + theme.padding / 2 + widestSize + theme.widgetHeight * .4)
			&& size.layout.x == area.layout.x,
			"Its own width in the area's column, which stretches its children: at its start");
		size.layout.widthSizing = Grow(1);
		frame(790, 300, false);
		check(near(size.layout.width, 300), "Grown across the area's column");
		var shown:Text2D = @:privateAccess size.shownText,
			sizeFace:Shape2D = @:privateAccess size.face;
		check(!size.open && ui.popup == null && size.selected == "Small" && shown.text == "Small", "Closed, showing the chosen item");
		check(long.selectedIndex == 15 && long.selected == "Item 15", "Made with its choice");
		// Opened by a click: its list below its face, as wide, over everything (the last of the UI's nodes) and in no clip.
		var cx = size.layout.x + size.layout.width / 2,
			cy = size.layout.y + size.layout.height / 2;
		click(cx, cy);
		var list = size.popup;
		check(size.open && list.open && ui.popup == list && ui.focusedName == "size" && ui.capturingKeys, "A click opens it: focused, with the keys");
		check(near(list.x, size.layout.x)
			&& near(list.y, size.layout.y + size.layout.height)
			&& !list.placedAbove, "Its list below its face, at its left");
		check(near(list.layout.width, size.layout.width) && near(list.layout.height, sizes.length * rowHeight + pad * 2),
			"As wide as the face, its five rows a list's");
		var layer = @:privateAccess list.root.parent;
		check(layer != null && ui.root.getChild(ui.root.childCount - 1) == layer, "Above every widget and the ring");
		var at = @:privateAccess list.root, clipped = false;
		while (at != null) {
			clipped = clipped || at.clipping;
			at = at.parent;
		}
		check(!clipped, "Clipped by nothing: not by the scroll area holding its face");
		frame(790, 300, false);
		var popFace:Shape2D = @:privateAccess size.popFace;
		function rowY(d:helix.ui.Dropdown, i:Int):Float
			return d.popup.y + pad + (i + .5) * rowHeight - @:privateAccess d.scroll;
		var rx = list.x + list.layout.width / 2;
		check(rowY(size, 3) > area.layout.y + area.layout.height, "Its fourth row past the area's window");
		check(stage.pick(camera, rx, rowY(size, 3)) == popFace, "Picked there all the same, above the button under it");
		var underFace:Shape2D = @:privateAccess under.face;
		check(rowY(size, 1) > under.layout.y && rowY(size, 1) < under.layout.y + under.layout.height, "Its second row over the button");
		frame(rx, rowY(size, 1), false);
		check(size.highlightedIndex == 1 && underFace.color == theme.faceColor, "The pointer over it highlights its row; the button under it sees nothing");
		var rowFace = (i:Int) -> (@:privateAccess size.rows[i].face : Shape2D);
		check(rowFace(1).color == theme.hoveredColor && rowFace(0).color == theme.accentColor && rowFace(2).color == 0,
			"The highlighted row hovered, the chosen one in the accent color, the rest clear");
		check(sizeFace.color == theme.pressedColor, "Its face pressed while open");
		// A click on a row chooses it and closes the list; the button under it isn't clicked.
		frame(rx, rowY(size, 2), true);
		check(size.open && !size.changed, "Pressed: still open");
		frame(rx, rowY(size, 2), false);
		check(!size.open && ui.popup == null && size.changed && size.selectedIndex == 2 && size.selected == "Large" && shown.text == "Large" && !under.clicked,
			"A click on a row chooses it and closes the list");
		frame(rx, rowY(size, 2), false);
		check(!size.changed, "changed lasts the frame");
		// A press off the list closes it and does nothing else, not even after it's let go.
		click(cx, cy);
		check(size.open, "Open again");
		var ox = other.layout.x + 10, oy = other.layout.y + 10;
		frame(ox, oy, true);
		check(!size.open && ui.popup == null && ui.focusedName == "size", "A press off it closes it; focus stays");
		check(pointer.captured, "The press is the UI's: the world under it sees nothing");
		frame(ox, oy, false);
		check(!other.clicked && !size.changed && size.selectedIndex == 2, "Let go: the button under the press isn't clicked");
		click(ox, oy);
		check(other.clicked && ui.focusedName == "Other", "The next click reaches it");
		// Pressing the face of an open dropdown closes it too, without opening it again.
		click(cx, cy);
		check(size.open, "Open");
		click(cx, cy);
		check(!size.open, "A click on its own face closes it");
		// Keys: Enter opens it at the chosen item, Up and Down move the highlight, Escape closes it unchanged and isn't back.
		frame([helix.input.Key.Enter]);
		check(size.open && size.highlightedIndex == 2 && ui.capturingKeys, "Enter opens it, the chosen item highlighted");
		frame([helix.input.Key.Down]);
		frame([helix.input.Key.Down]);
		check(size.highlightedIndex == 4 && size.selectedIndex == 2 && ui.focusedName == "size", "Down moves the highlight, not focus");
		frame([helix.input.Key.Down]);
		check(size.highlightedIndex == 4, "Held at the last");
		frame([helix.input.Key.Tab]);
		check(size.open && ui.focusedName == "size", "Tab doesn't move focus while it's open");
		frame([helix.input.Key.Escape]);
		check(!size.open && size.selectedIndex == 2 && !size.changed && !ui.backPressed, "Escape closes it unchanged, and isn't back");
		frame([helix.input.Key.Space]);
		frame([helix.input.Key.Up]);
		frame([helix.input.Key.Enter]);
		check(!size.open && size.changed && size.selectedIndex == 1 && shown.text == "Medium", "Space opens it, Up and Enter choose");
		frame([helix.input.Key.Down]);
		check(ui.focusedName == "Under" && size.selectedIndex == 1, "Closed, Down moves focus as for any widget");
		// A pad: South opens and chooses, East closes.
		ui.focused = size;
		function padPress(button:helix.input.PadButton):Void {
			input.endFrame();
			input.padEvent(button, true);
			input.padEvent(button, false);
			Layout2D.arrange(layout, 0, 0, 800, 600, font);
			batch.begin(camera);
			stage.draw(batch, camera);
			batch.end();
			pointer.update();
			ui.update();
		}
		padPress(South);
		check(size.open, "South opens it");
		padPress(East);
		check(!size.open && !ui.backPressed, "East closes it");
		padPress(South);
		padPress(Down);
		padPress(South);
		check(!size.open && size.selectedIndex == 2, "South chooses the highlighted item");
		// At the bottom right: its list above its face, kept on screen across, eight rows of twenty scrolled to the chosen one.
		check(ui.press("long"), "Used by name");
		frame(790, 10, false);
		var longList = long.popup,
			bar:helix.ui.Scrollbar = @:privateAccess long.bar;
		check(long.open
			&& longList.placedAbove
			&& near(longList.y + longList.layout.height, long.layout.y), "Above its face, with no room below");
		check(near(longList.layout.height, 8 * rowHeight + pad * 2) && bar.visible, "Eight rows, the rest scrolled to by its scrollbar");
		check(near(longList.layout.width, long.layout.width + bar.width + pad)
			&& near(longList.x + longList.layout.width, 800)
			&& longList.x < long.layout.x,
			"A scrollbar's room wider than its face, moved in to stay on screen");
		var scroll:Float = @:privateAccess long.scroll;
		check(long.highlightedIndex == 15 && scroll >= 16 * rowHeight - 8 * rowHeight - 1e-6 && scroll <= 15 * rowHeight + 1e-6,
			"Opened with the chosen row in view");
		frame([helix.input.Key.Down]);
		frame([helix.input.Key.Down]);
		frame([helix.input.Key.Down]);
		frame([helix.input.Key.Down]);
		frame([helix.input.Key.Down]);
		scroll = @:privateAccess long.scroll;
		check(long.highlightedIndex == 19 && near(scroll, 12 * rowHeight), "The highlight moved to the last, scrolled into view");
		var lx = longList.x + 40, ly = longList.y + longList.layout.height / 2;
		frame(lx, ly, false, 1);
		check(near(@:privateAccess long.scroll, 11 * rowHeight), "The wheel over it scrolls it");
		click(lx, rowY(long, 13));
		check(!long.open && long.changed && long.selectedIndex == 13, "A click on a scrolled row chooses it");
		// Disabled: dimmed, never opened; disabled while open, closed.
		size.enabled = false;
		frame(790, 300, false);
		click(cx, cy);
		check(!size.open
			&& sizeFace.color == WidgetState.dim(theme.faceColor)
			&& shown.color == theme.disabledTextColor, "Disabled: dimmed, not opened");
		size.enabled = true;
		click(cx, cy);
		check(size.open, "Enabled: opens");
		size.enabled = false;
		frame(790, 300, false);
		check(!size.open && ui.popup == null, "Disabled while open: closed");
		size.enabled = true;
		// The theme changed: the face's color and the list's rows at the next frame.
		click(cx, cy);
		theme.faceColor = 0xff203040;
		theme.listRowHeight = 30;
		frame(790, 300, false);
		check(popFace.color == 0xff203040
			&& near(size.popup.layout.height, sizes.length * 30 + pad * 2), "The theme's change at the next frame");
		frame([helix.input.Key.Escape]);
		frame(790, 300, false);
		check(sizeFace.color == 0xff203040, "Its face too");
		// A width the game gave its layout is kept whatever the theme's text becomes; a hint while none is chosen.
		var fitted = long.layout.width;
		theme.textSize = 30;
		frame();
		frame();
		check(long.layout.width > fitted, "Fit: wider for the theme's larger text, once arranged");
		long.layout.widthSizing = Fixed(250);
		theme.textSize = 14;
		frame();
		frame();
		check(near(long.layout.width, 250), "The game's width kept whatever the theme's text becomes");
		size.selectedIndex = -1;
		size.hint = "Choose";
		frame();
		check(size.selected == null && shown.text == "Choose" && shown.color == theme.disabledTextColor && !size.changed,
			"None chosen: its hint, in the disabled text's color, not a change");
		// Taken out while open: closed.
		click(cx, cy);
		check(size.open, "Open once more");
		ui.remove(size);
		check(ui.popup == null && !size.open, "Taken out: its list closed");
	}
}
