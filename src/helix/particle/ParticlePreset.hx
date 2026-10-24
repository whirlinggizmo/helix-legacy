package helix.particle;

/** The particle presets' recipes, which Particles2D's and Particles3D's factories (explosion, smokePuff, sparks, dust, fire, smoke, rain,
	snow, confetti) make their emitters from: each in units of size (about how big the effect is, in its space's units: pixels on a 2D stage,
	world units in 3D), down being the sign of its space's downward y (+1 on a 2D stage, where y grows downward; -1 in 3D, +y up), drawn with
	the built-in dot (Emitter.getDot). A one-shot (explosion, smoke puff, sparks, dust, confetti) bursts once, where its node first is; the
	others run steadily. Each is an ordinary Emitter: change what doesn't fit. */
@:build(helix.macro.EnumNames.build())
enum abstract ParticlePreset(Int) {
	/** A burst of light outward, fading from white-yellow to red: a hit, a pop, a small explosion. One-shot. */
	var Explosion;

	/** A soft gray puff, spreading and rising a little as it fades: a landing, a vanish, a smoke grenade. One-shot. */
	var SmokePuff;

	/** Hot sparks thrown up and out, streaked along their motion and falling: a hit on metal, a grinder. One-shot. */
	var Sparks;

	/** A low, wide kick of dust that settles: footsteps, a landing, a skid. One-shot. */
	var Dust;

	/** A steady flame, rising and fading from yellow to red: a torch, a campfire. */
	var Fire;

	/** A steady column of gray smoke, rising and spreading: a chimney, a wreck. */
	var Smoke;

	/** Steady rain over a width of size, streaked along its fall, falling size units below the node. */
	var Rain;

	/** Steady snow over a width of size, drifting down size units below the node. */
	var Snow;

	/** Paper of five colors thrown up, spinning and falling: a win, a level cleared. One-shot. */
	var Confetti;

	/** An emitter of this preset, size big, for a space whose y goes down by the sign of down, flat for a 2D stage. */
	public function make(size:Float, down:Float, flat:Bool):Emitter {
		var self:ParticlePreset = cast this;
		var e = new Emitter(Emitter.getDot(), self == Rain ? 2048 : 512, flat);
		var up = -down;
		switch self {
			case Explosion:
				e.setLife(.35, .7);
				e.setSpawnSphere(size * .1);
				e.setVelocity(0, up * size * 3, 0, Math.PI, .6);
				e.drag = 4;
				e.setSize(size * .5, size * .1, .5);
				e.setColor(0xffffeeb0, 0x00ff3010);
				e.setAlphaMode(Add);
				e.burst(70);
			case SmokePuff:
				e.setLife(.8, 1.4);
				e.setSpawnSphere(size * .2);
				e.setVelocity(0, up * size * .8, 0, Math.PI * .6, .6);
				e.drag = 2.5;
				e.setGravity(0, up * size * .3, 0);
				e.clearSizeKeys();
				e.addSizeKey(0, size * .3);
				e.addSizeKey(1, size * .9);
				e.setColor(0xa0909090, 0x00707070);
				e.setSpin(-1, 1);
				e.setAlphaMode(Blend);
				e.burst(24);
			case Sparks:
				e.setLife(.3, .7);
				e.setVelocity(0, up * size * 4, 0, 1, .6);
				e.setGravity(0, down * size * 7, 0);
				e.drag = 1;
				e.stretch = .04;
				e.setSize(size * .07, size * .02, .5);
				e.setColor(0xffffdc78, 0x00ff3c0a);
				e.setAlphaMode(Add);
				e.burst(30);
			case Dust:
				e.setLife(.5, .9);
				e.setSpawnBox(size * .3, 0, size * .3);
				e.setVelocity(0, up * size * .9, 0, 1.3, .6);
				e.setGravity(0, down * size * .8, 0);
				e.drag = 3;
				e.clearSizeKeys();
				e.addSizeKey(0, size * .15);
				e.addSizeKey(1, size * .45);
				e.setColor(0x90c8b496, 0x00a08c78);
				e.setAlphaMode(Blend);
				e.burst(16);
			case Fire:
				e.rate = 70;
				e.setLife(.6, 1);
				e.setSpawnSphere(size * .2);
				e.setVelocity(0, up * size * 1.4, 0, .25, .3);
				e.drag = .8;
				e.setSpin(-1.5, 1.5);
				e.clearSizeKeys();
				e.addSizeKey(0, size * .45);
				e.addSizeKey(.3, size * .7);
				e.addSizeKey(1, size * .2);
				e.clearColorKeys();
				e.addColorKey(0, 0x00ffebbe);
				e.addColorKey(.1, 0x90ffebbe);
				e.addColorKey(.35, 0x80ff9628);
				e.addColorKey(.7, 0x50c8320f);
				e.addColorKey(1, 0x00500f05);
				e.setAlphaMode(Add);
				e.prewarm(1);
			case Smoke:
				e.rate = 14;
				e.setLife(2.5, 3.5);
				e.setSpawnSphere(size * .15);
				e.setVelocity(0, up * size * .6, 0, .3, .3);
				e.setSpin(-.6, .6);
				e.clearSizeKeys();
				e.addSizeKey(0, size * .2);
				e.addSizeKey(.2, size * .6);
				e.addSizeKey(1, size * 1.4);
				e.clearColorKeys();
				e.addColorKey(0, 0x00303030);
				e.addColorKey(.15, 0xa0404040);
				e.addColorKey(.6, 0x60707070);
				e.addColorKey(1, 0x00909090);
				e.setAlphaMode(Blend);
				e.prewarm(3);
			case Rain:
				e.rate = 500;
				e.setLife(1 / 3, 1 / 3);
				e.setSpawnBox(size / 2, 0, flat ? 0 : size / 2);
				e.setVelocity(0, down * size * 3, 0, .05, .1);
				e.stretch = .025;
				e.setSize(size * .012, size * .012);
				e.setColor(0xa0b4cdff, 0x60b4cdff);
				e.setAlphaMode(Blend);
				e.prewarm(1);
			case Snow:
				e.rate = 120;
				e.setLife(4, 6);
				e.setSpawnBox(size / 2, 0, flat ? 0 : size / 2);
				e.setVelocity(0, down * size * .2, 0, .5, .4);
				e.setSize(size * .008, size * .008, .5);
				e.setColor(0xf0ffffff, 0x00ffffff);
				e.setAlphaMode(Blend);
				e.prewarm(6);
			case Confetti:
				// Squares: the dot's solid middle.
				e.setRegion(12, 12, 8, 8);
				e.setLife(1.2, 2.2);
				e.setVelocity(0, up * size * 4, 0, 1.2, .7);
				e.setGravity(0, down * size * 7, 0);
				e.drag = .9;
				e.setSize(size * .1, size * .06, .5);
				e.setSpin(-8, 8);
				e.setColor(0xffffffff, 0x00ffffff);
				for (c in [0xffe62937, 0xffffcb00, 0xff00e430, 0xff66bfff, 0xff873cbe])
					e.addPaletteColor(c);
				e.setAlphaMode(Blend);
				e.burst(80);
		}
		return e;
	}
}
