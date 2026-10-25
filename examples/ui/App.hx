import haxe.io.Bytes;
import helix.asset.Storage;
import helix.audio.Audio;
import helix.audio.AudioClip;
import helix.audio.AudioPlayback;
import helix.audio.AudioStream;
import helix.audio.Bus;
import helix.debug.FpsOverlay;
import helix.host.Host;
import helix.host.Screen;
import helix.host.Window;
import helix.input.Actions;
import helix.input.Anchor;
import helix.input.Input;
import helix.input.Key;
import helix.input.PadAxis;
import helix.input.PadButton;
import helix.render2d.Drawing2D;
import helix.render2d.Stage;
import helix.texture.Texture2D;
import helix.time.Time;
import helix.ui.Layout2D;
import helix.ui.Sizing2D;
import helix.ui.Alignment2D;
import helix.ui.Button;
import helix.ui.ColorPicker;
import helix.ui.Dropdown;
import helix.ui.Label;
import helix.ui.ListView;
import helix.ui.Panel;
import helix.ui.ProgressBar;
import helix.ui.ScrollArea;
import helix.ui.Slider;
import helix.ui.TextField;
import helix.ui.Toggle;
import helix.ui.Ui;
import helix.host.ScreenShape;

/** A game's menus (helix.ui), a Ui on the stage: a main menu, settings, controls and a scrolling list of levels, the main menu in a nine-slice panel, the others
	in the theme's rounded ones, every widget's corners rounded too, the headings keeping more room under them (a margin, Layout2D.setMargin), laid out in a 1280 x 720 design fitted to the window, used alike by the
	pointer, keys (arrows, Tab, Enter, Escape) and a pad (D-pad, South, East). Nothing is called back: each frame the example asks the widgets
	what happened. Settings set the master, music and effects buses (Audio.master, music, effects) with music playing under them, a short
	effect played as the effects slider is let go, and mute the music, a dropdown (Dropdown, beside the name field) chooses a quality, saved
	through Storage as it changes, and a color picker (ColorPicker, without alpha, beside its label in a row so it keeps its own width)
	chooses the background, saved as hex through Storage once the pointer lets go; Controls lists an Actions map's actions with their bindings in a scroll area
	(ScrollArea, more rows than it shows, its scrollbar at the right, a Rebind focused by keys scrolled into view), a Rebind
	button capturing the next key, pad button, axis or touch for one (Escape cancels) and Reset; both are saved through Storage and loaded at
	start. A progress bar fills; the status in the corner is anchored there. Escape on the main menu quits where quitting means anything.
	Options: autopilot (a script under assets/; the menus and the actions then read its input, and the settings are saved under keys of its
	own, removed first, so a run starts from the defaults and leaves a player's alone; the window is then the autopilot's page's size, so its
	samples of the frame compare across targets), audio (0 for silence) and autoclose (1: quit once the script is done). The probes: screen,
	focus (the focused widget's name), loaded, jump (its bindings' text, joined by ", "), capturing, jumpDown, masterVolume, musicVolume,
	effectsVolume, musicMuted, background (the chosen color as hex), backgroundText (the picker's text field, in its format),
	bindingsScrolled (how far the bindings are scrolled, as a share of how far they can be, in hundredths: 0 at the top, 1 at the end, whatever
	the layout's sizes), quality (the chosen quality's text) and qualityOpen (whether its list is open). */
class App extends helix.App {
	// The background to start, and the autopilot's window (its browser page's size), so its samples compare across targets.
	static inline var BACKGROUND = 0xff14161c;
	// The room the panels keep clear, in design units: the help line's at the top, the status's and the bar's at the bottom.
	static inline var PANELS_TOP = 72;
	static inline var PANELS_BOTTOM = 104;
	static inline var PILOT_WIDTH = 800;
	static inline var PILOT_HEIGHT = 600;

	var ui:Null<Ui>;
	var fps = new FpsOverlay();
	// The status and the hint, drawn again each update over the widgets.
	var text = new Drawing2D();
	var layout:Layout2D;
	var screen = "main";
	var status = "";
	var loading = 0.;
	// The screens' panels and widgets.
	var main:Panel;
	var settings:Panel;
	// Settings' body (all but its heading and Back), scrolled when the room is shorter than it.
	var settingsBody:ScrollArea;
	var controls:Panel;
	var levels:Panel;
	var play:Button;
	var openSettings:Button;
	var openControls:Button;
	var openLevels:Button;
	var quit:Button;
	var master:Slider;
	var music:Slider;
	var effects:Slider;
	var muteMusic:Toggle;
	var name:TextField;
	var quality:Dropdown;
	var background:ColorPicker;
	var back:Button;
	var bindingsArea:ScrollArea;
	var rows:Array<{action:String, bindings:Label, rebind:Button}> = [];
	var live:Label;
	var reset:Button;
	var backFromControls:Button;
	var list:ListView;
	var start:Button;
	var backFromLevels:Button;
	var bar:ProgressBar;
	var corner:Label;
	// The player's controls, and the Storage keys they and the buses are saved under.
	var actions:Actions;
	var actionsKey = "actions";
	var busesKey = "audio";
	var backgroundKey = "background";
	var qualityKey = "quality";
	var loads = 0;
	// The action a rebind waits for a press for, or "".
	var rebinding = "";
	// The buses' volumes changed by a slider and not yet saved (saved once the pointer is let go), and whether effects was one.
	var unsaved = false;
	var effectsMoved = false;
	// The background's color changed and not yet saved (saved once the pointer is let go).
	var backgroundUnsaved = false;
	var song:Null<AudioPlayback>;
	var click:Null<AudioClip>;

	override public function init():Void {
		Window.title = "HeliX ui";
		Stage.color = BACKGROUND;
		if (Host.getOption("audio", "1") != "0") {
			Audio.loadStream("audio/music/a_hero_is_born.mp3", stream -> playMusic(stream));
			Audio.loadClip("audio/sfx/click_004.ogg", clip -> click = clip);
		}
		// Under an autopilot (its script in before init: App.probe), the autopilot's window and a run of its own: its saves apart from a
		// player's, and gone before it starts, so every run begins from the defaults.
		if (autopilot == null)
			Window.requestSize(1000, 600);
		else {
			Window.requestSize(PILOT_WIDTH, PILOT_HEIGHT);
			actionsKey = "autopilot-actions";
			busesKey = "autopilot-audio";
			backgroundKey = "autopilot-background";
			qualityKey = "autopilot-quality";
		}
		build();
	}

	// An autopilot's clicks press the menus' widgets by name, and its points on them are found by the UI.
	override public function pressWidget(name:String):Bool
		return ui != null && ui.press(name);

	override public function locateWidget(target:String, part:String, x:Float, y:Float, out:Array<Float>):Bool
		return ui != null && ui.computePoint(target, part, x, y, out);

	// The music opened: played on the music bus, looping, the playback holding the stream.
	function playMusic(stream:AudioStream):Void {
		song = Audio.music.play(stream, true, .5);
		stream.release();
	}

	// The screens, read from Input (the window's, or the autopilot's while it plays), and the controls and the buses' volumes loaded.
	function build():Void {
		var ui = new Ui();
		this.ui = ui;
		Stage.addChild(text);
		Stage.addChild(fps);
		actions = new Actions();
		actions.bind("jump", Keyboard(Key.Space));
		actions.bind("jump", Pad(PadButton.South));
		actions.bind("move", KeyboardPair(Key.Left, Key.Right));
		actions.bind("move", Axis(PadAxis.LeftX, 0, .15));
		actions.bind("fire", Keyboard(Key.Z));
		actions.bind("fire", Pad(PadButton.West));
		actions.bind("fire", TouchRegion(Anchor.BottomRight, -120, -120, 96, 96));
		actions.bind("dash", Keyboard(Key.X));
		actions.bind("dash", Pad(PadButton.RightBumper));
		actions.bind("interact", Keyboard(Key.E));
		actions.bind("interact", Pad(PadButton.North));
		actions.bind("pause", Keyboard(Key.P));
		actions.bind("pause", Pad(PadButton.Start));
		actions.bind("map", Keyboard(Key.M));
		actions.bind("map", Pad(PadButton.Back));

		var frame = panelImage();
		main = ui.panel("main");
		main.setFrame(frame, 6, 6, 6, 6, 0xff262c3c);
		var title = ui.label("HeliX ui");
		title.textSize = 32;
		play = ui.button("Play", "play");
		openSettings = ui.button("Settings", "openSettings");
		openControls = ui.button("Controls", "openControls");
		openLevels = ui.button("Levels", "openLevels");
		quit = ui.button("Quit", "quit");
		quit.enabled = Host.canQuit();
		for (w in [title, play, openSettings, openControls, openLevels, quit])
			main.add(w);

		settings = ui.panel("settings");
		var heading = ui.label("Settings");
		heading.textSize = 26;
		// A heading keeps a gap's more room under it than the widgets keep between them: a margin of its own.
		heading.layout.setMargin(0, 0, 0, ui.theme.gap);
		master = ui.slider("Master", 0, 100, 100, 10, "masterVolume");
		music = ui.slider("Music", 0, 100, 100, 10, "musicVolume");
		effects = ui.slider("Effects", 0, 100, 100, 10, "effectsVolume");
		muteMusic = ui.toggle("Mute music", false, "muteMusic");
		name = ui.textField("", "your name", 16, "name");
		var qualityLabel = ui.label("Quality");
		quality = ui.dropdown(["Low", "Medium", "High", "Ultra"], 2, "quality");
		var backgroundLabel = ui.label("Background");
		background = ui.colorPicker(BACKGROUND, false, "background");
		back = ui.button("Back", "backFromSettings");
		// The heading, then the body in a scroll area (the volumes, a line under them, then the rest), then Back.
		settings.add(heading);
		settingsBody = ui.scrollArea(1, "settingsBody");
		settings.add(settingsBody);
		for (w in [master, music, effects, ui.separator(), muteMusic])
			settingsBody.add(w);
		// The name's field and the quality's dropdown in a row, the field taking the room the dropdown (as wide as its widest item) leaves.
		var nameRow = Layout2D.row();
		nameRow.gap = ui.theme.gap;
		nameRow.setAlign(Start, Center);
		name.layout.widthSizing = Grow(1);
		for (w in [name, qualityLabel, quality]) {
			settingsBody.adopt(w);
			nameRow.add(w.layout);
		}
		settingsBody.content.add(nameRow);
		// The picker beside its label, in a row, narrower than the theme's width.
		var backgroundRow = Layout2D.row();
		backgroundRow.gap = ui.theme.gap * 2;
		for (w in [backgroundLabel, background]) {
			settingsBody.adopt(w);
			backgroundRow.add(w.layout);
		}
		background.layout.setSizing(Fixed(240), Fit);
		settingsBody.content.add(backgroundRow);
		settings.add(back);

		controls = ui.panel("controls");
		var heading = ui.label("Controls");
		heading.textSize = 26;
		heading.layout.setMargin(0, 0, 0, ui.theme.gap);
		controls.add(heading);
		// The bindings' rows in a scroll area: three and a half rows in view, the rest scrolled to.
		bindingsArea = ui.scrollArea(164, "bindings");
		controls.add(bindingsArea);
		for (action in actions.names) {
			var label = ui.label(action),
				bindings = ui.label(""),
				rebind = ui.button("Rebind", 'rebind-$action');
			label.layout.setSizing(Fixed(80), Fit);
			bindings.layout.setSizing(Grow(1), Fit);
			var row = Layout2D.row();
			row.gap = ui.theme.gap;
			row.setAlign(Start, Center);
			for (w in [label, bindings, rebind]) {
				bindingsArea.adopt(w);
				row.add(w.layout);
			}
			bindingsArea.content.add(row);
			rows.push({action: action, bindings: bindings, rebind: rebind});
		}
		live = ui.label("");
		live.color = 0xff9aa2b8;
		controls.add(live);
		reset = ui.button("Reset", "reset");
		backFromControls = ui.button("Back", "backFromControls");
		var buttons = Layout2D.row();
		buttons.gap = ui.theme.gap;
		for (b in [reset, backFromControls]) {
			controls.adopt(b);
			buttons.add(b.layout);
		}
		controls.content.add(buttons);

		levels = ui.panel("levels");
		list = ui.list([
			for (i in 0...30)
				'Level ${i + 1}: ${["The Belt", "Ice Field", "Debris", "The Rift", "Dark Side"][i % 5]}'
		], 6, "levels");
		start = ui.button("Start", "start");
		backFromLevels = ui.button("Back", "backFromLevels");
		levels.add(list);
		levels.adopt(start);
		levels.adopt(backFromLevels);
		var buttons = Layout2D.row();
		buttons.gap = ui.theme.gap;
		buttons.add(start.layout);
		buttons.add(backFromLevels.layout);
		levels.content.add(buttons);
		bar = ui.progress(0);
		corner = ui.label("");
		corner.color = 0xff9aa2b8;
		// The design: the panels centered in the room between the help line at the top and the status at the bottom, the bar along the
		// bottom, the focus in the corner.
		layout = Layout2D.stack();
		layout.setSizing(Grow(1), Grow(1));
		var panels = Layout2D.stack();
		panels.setSizing(Grow(1), Grow(1));
		panels.setPadding(0, PANELS_TOP, 0, PANELS_BOTTOM);
		layout.add(panels);
		for (panel in [main, settings, controls, levels]) {
			panel.layout.setAnchor(Center, Center);
			panels.add(panel.layout);
		}
		main.layout.setSizing(Fixed(360), Fit);
		settings.layout.setSizing(Fixed(480), Fit);
		controls.layout.setSizing(Fixed(640), Fit);
		levels.layout.setSizing(Fixed(520), Fit);
		bar.layout.setSizing(Fixed(400), Fixed(10));
		bar.layout.setAnchor(Center, End, 0, -24);
		corner.layout.setAnchor(End, End, -16, -48);
		for (w in [bar, corner])
			layout.add(w.layout);
		show("main");

		if (autopilot != null)
			Storage.remove(actionsKey, _ -> Storage.remove(busesKey, _ -> Storage.remove(backgroundKey, _ -> Storage.remove(qualityKey, _ -> loadSettings()))));
		else
			loadSettings();
	}

	// The saved controls and buses, over the defaults; the sliders and the toggle set from the buses.
	function loadSettings():Void {
		actions.load(actionsKey, () -> loads++, message -> {
			trace('Controls not loaded: $message');
			loads++;
		});
		Audio.loadBuses(busesKey, () -> {
			for (pair in [
				{slider: master, bus: Audio.master},
				{slider: music, bus: Audio.music},
				{slider: effects, bus: Audio.effects}
			])
				pair.slider.value = Math.round(pair.bus.volume * 100);
			muteMusic.on = Audio.music.muted;
			loads++;
		}, message -> {
			trace('Volumes not loaded: $message');
			loads++;
		});
		Storage.read(backgroundKey, result -> {
			switch result {
				case Stored(bytes):
					var color = ColorPicker.parseHex(bytes.toString());
					if (color != null) background.color = color;
				case Failed(message):
					trace('Background not loaded: $message');
				case Missing | Cancelled:
			}
			loads++;
		});
		Storage.read(qualityKey, result -> {
			switch result {
				case Stored(bytes):
					var index = quality.items.indexOf(bytes.toString());
					if (index >= 0) quality.selectedIndex = index;
				case Failed(message):
					trace('Quality not loaded: $message');
				case Missing | Cancelled:
			}
			loads++;
		});
	}

	// A frame image for the panels' nine-slice: a light border, a darker inside, its corners cut.
	function panelImage():Texture2D {
		var size = 16, pixels = Bytes.alloc(size * size * 4);
		for (y in 0...size)
			for (x in 0...size) {
				var edge = x < 2 || y < 2 || x >= size - 2 || y >= size - 2,
					cut = (x < 2 || x >= size - 2) && (y < 2 || y >= size - 2);
				var at = (y * size + x) * 4, value = edge ? 255 : 150;
				pixels.set(at, value);
				pixels.set(at + 1, value);
				pixels.set(at + 2, value);
				pixels.set(at + 3, cut ? 0 : 255);
			}
		return Texture2D.fromRgba(size, size, pixels);
	}

	function show(which:String):Void {
		screen = which;
		main.visible = which == "main";
		settings.visible = which == "settings";
		controls.visible = which == "controls";
		levels.visible = which == "levels";
		ui.reset();
	}

	// The action's bindings as a remap screen shows them, joined by ", ".
	function describe(action:String):String
		return [for (b in actions.bindings(action)) Actions.describe(b)].join(", ");

	// A named value for the autopilot, and the final game it publishes.
	override public function probe(name:String):Dynamic
		return switch name {
			case "screen": screen;
			case "focus": ui.focusedName;
			case "loaded": loads == 4;
			case "jump": describe("jump");
			case "capturing": actions.capturing;
			case "jumpDown": actions.isDown("jump");
			case "masterVolume": Audio.master.volume;
			case "musicVolume": Audio.music.volume;
			case "effectsVolume": Audio.effects.volume;
			case "musicMuted": Audio.music.muted;
			case "background": ColorPicker.formatHex(background.color, false);
			case "backgroundText": background.textField.text;
			case "bindingsScrolled": bindingsArea.maxScroll > 0 ? Math.round(bindingsArea.scroll / bindingsArea.maxScroll * 100) / 100 : 0;
			case "quality": quality.selected;
			case "qualityOpen": quality.open;
			default: throw 'Unknown probe ' + name;
		}

	// A slider moved: its bus at its level at once, saved once the pointer lets go.
	function setVolume(slider:Slider, bus:Bus):Void {
		if (!slider.changed)
			return;
		bus.volume = slider.value / 100;
		unsaved = true;
		effectsMoved = effectsMoved || slider == effects;
	}

	override public function update(dt:Float):Void {
		// The design for the window's shape, grown to its edges: the layout arranged into all that's visible.
		ScreenShape.update();
		var vx = Screen.visibleX,
			vy = Screen.visibleY,
			vw = Screen.visibleWidth,
			vh = Screen.visibleHeight;
		for (row in rows)
			row.bindings.text = actions.capturing && rebinding == row.action ? "Press a key or button..." : describe(row.action);
		// Settings' body as tall as its widgets, or as the room leaves it (then it scrolls): the room less the rest of the panel, from the
		// last arrangement (a frame behind as the window changes).
		var room = vh - PANELS_TOP - PANELS_BOTTOM,
			rest = settings.layout.height - settingsBody.layout.height;
		settingsBody.layout.heightSizing = Fixed(Math.max(80, Math.min(settingsBody.content.height, room - rest)));
		Layout2D.arrange(layout, vx, vy, vw, vh, ui.font);
		// While a rebind waits for its press, the screen waits too: the press is the binding's, not the menu's.
		if (!actions.capturing) {
			ui.update();
			// Asked, never told: what happened this frame.
			switch screen {
				case "main":
					if (play.clicked)
						status = 'Playing as ${name.text == "" ? "nobody" : name.text}, master ${master.value}%, music ${muteMusic.on ? "muted" : '${music.value}%'}';
					if (openSettings.clicked)
						show("settings");
					if (openControls.clicked)
						show("controls");
					if (openLevels.clicked)
						show("levels");
					if (quit.clicked || ui.backPressed && Host.canQuit())
						Host.quit();
				case "settings":
					setVolume(master, Audio.master);
					setVolume(music, Audio.music);
					setVolume(effects, Audio.effects);
					if (muteMusic.changed) {
						Audio.music.muted = muteMusic.on;
						status = 'Music ${muteMusic.on ? "muted" : "on"}';
						Audio.saveBuses(busesKey);
					}
					if (name.submitted)
						status = 'Hello, ${name.text}';
					if (background.changed)
						backgroundUnsaved = true;
					if (quality.changed) {
						status = 'Quality ${quality.selected}';
						Storage.write(qualityKey, Bytes.ofString(quality.selected), result -> switch result {
							case Failed(message): trace('Quality not saved: $message');
							case Written | Cancelled:
						});
					}
					if (back.clicked || ui.backPressed && !name.submitted && ui.focused != name && ui.focused != background.textField)
						show("main");
				case "controls":
					for (row in rows)
						if (row.rebind.clicked)
							rebind(row);
					if (reset.clicked) {
						actions.reset();
						actions.save(actionsKey);
						status = "Controls reset";
					}
					if (backFromControls.clicked || ui.backPressed)
						show("main");
				case "levels":
					if (list.changed || list.activated || start.clicked) {
						var chosen = list.selectedIndex;
						status = chosen < 0 ? "Choose a level" : (list.activated || start.clicked ? "Starting " : "Chose ") + list.items[chosen];
					}
					if (backFromLevels.clicked || ui.backPressed)
						show("main");
			}
		}
		// A slider's change saved once it's let go (a drag ends; a key's step at once), the effect played at the effects bus's new level.
		if (unsaved && !ui.input.pointerDown) {
			unsaved = false;
			Audio.saveBuses(busesKey);
			if (effectsMoved && click != null)
				Audio.play(click);
			effectsMoved = false;
		}
		if (backgroundUnsaved && !ui.input.pointerDown) {
			backgroundUnsaved = false;
			Storage.write(backgroundKey, Bytes.ofString(ColorPicker.formatHex(background.color, false)), result -> switch result {
				case Failed(message): trace('Background not saved: $message');
				case Written | Cancelled:
			});
		}
		var move = Math.round(actions.axis("move") * 100) / 100;
		live.text = 'jump ${actions.isDown("jump") ? "down" : "up"}   move ${move}   fire ${actions.isDown("fire") ? "down" : "up"}';
		loading = (loading + dt * .2) % 1;
		bar.value = loading;
		corner.text = 'focus: ${ui.focusedName == "" ? "none" : ui.focusedName}${ui.capturingKeys ? " (keys)" : ""}';
		fps.update(dt, Time.frameCpu);
		Stage.color = background.color;
		text.clear();
		text.drawTextWrapped(status, vx + vw / 2, vy + vh - 80, 18, vw - 32, 0xffc8d0e8, Center);
		text.drawTextWrapped("pointer, arrows / Tab / Enter / Escape, or a pad", vx + vw / 2, vy + 40, 16, vw - 32, 0xff7a8298, Center);
		// The frame rate in the window's own pixels: its place and size in the design's units, a logical pixel being pixelRatio / scaleX of them.
		var pixel = Window.pixelRatio / Screen.scaleX;
		fps.size = 16 * pixel;
		fps.setPosition(vx + 12 * pixel, vy + 10 * pixel);
	}

	// Waits for the next press for the row's action: the row reads "Press a key or button..." until it's taken (then saved) or Escape
	// cancels.
	function rebind(row:{action:String, bindings:Label, rebind:Button}):Void {
		if (actions.capture(row.action, binding -> {
			actions.save(actionsKey);
			status = '${row.action}: ${describe(row.action)}';
		}, () -> status = "Rebind cancelled"))
			rebinding = row.action;
	}
}
