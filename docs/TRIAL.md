# Trial: the same game, six ways

A draft for review (2026-10-25). Nothing has run.

## The question

Is HeliX better than the alternatives at what GOALS.md says it's for? Or would an agent do as well, or better, without it?

Each arm gets the same game spec, the same model and the same budget. It's built by a fresh agent with no history and no access to
katawami's source. Then the arms are compared on what GOALS.md cares about.

## The arms

| Arm | Stack | What the agent gets |
| --- | --- | --- |
| Clean room | TypeScript or JavaScript, a canvas or WebGL, no game libraries (a bundler is allowed) | the spec |
| Three.js | Three.js, plus anything from npm | the spec |
| Pixi | Pixi, plus anything from npm | the spec |
| OpenFL | OpenFL with Lime, in Haxe | the spec |
| Godot | Godot 4, GDScript, exported for the web | the spec and the Godot binary with its export templates |
| HeliX | `-lib helix`, from a `haxelib git` install | the spec, plus HeliX's public docs (the README, the guide, docs/api) |

An optional seventh arm is HeliX with no docs, told only "use HeliX". It isn't expected to finish. The names it guesses are data for the
naming question: what an agent expects HeliX's API to be.

## The game

A slice of katawami, written without any engine's names. Every arm gets this text, word for word:

> A top-down game for the browser. The player rolls a ball through a maze, with momentum: it speeds up and slows down, and it bounces
> off walls. Junk lies on the floor. Rolling into a piece smaller than the ball picks it up: the piece stays stuck to the ball, and the
> ball grows. A piece bigger than the ball blocks it like a wall. The exit is a gate in the maze's wall. It opens once 70% of the junk
> is picked up, and the ball fits through only if it's narrower than the gate. The round has a countdown. Getting out wins; running out
> of time loses.
>
> - Three levels, each a different maze, played in order.
> - Controls: the arrow keys or WASD, and a touch stick on a phone.
> - Screens: a title screen, a level-complete screen, a game-over screen, and a pause menu (resume, restart, quit to title).
> - A HUD: the time left, how much junk has been picked up, and whether the exit is open.
> - Sound: a pickup sound, a bounce sound, a win, a loss, and music. The music must start after the first click or keypress, as browsers
>   require.
> - It must fit any window size and keep its aspect, without stretching.
> - Art can be simple shapes in flat colors.

## The rules

- **Fresh session for each arm:** the same model, an empty directory, and no access to other arms, katawami or HeliX's source. The HeliX
  arm sees only what a `haxelib` install contains.
- **The same budget for each arm:** a fixed number of turns, or tokens, decided before the trial starts. The agent may use as much of it
  as it needs.
- **The same human input for each arm:**
  1. The spec, as the first message.
  2. One playtest round once the agent says it's done. A person plays it and sends up to five bug reports, written the same way for
     every arm.
  3. A change request after the fixes: "Add a fourth level with a moving obstacle that pushes the ball." This measures how well the code
     takes a change.
- **Scoring:** the arms are scored blind where possible. The playtester doesn't know which arm made which build.

## What's measured

| Measure | How |
| --- | --- |
| Spec met | A checklist of the spec's items, each playable or not, after each round |
| Cost | Turns, tokens and wall time to "done", and again for the fixes and the change |
| Bugs | Found by the playtest, and how many were fixed in one round |
| Delivered size | The release build's gzipped total, with assets and without |
| Load | Time to the first frame on a throttled connection (Chrome's "Fast 4G") |
| Native | Whether the same code builds and runs natively (HeliX, OpenFL and Godot can; the others can't) |
| Code | Lines written, and how much of it is engine-like plumbing versus the game |
| The change | Turns to add the fourth level, and whether anything else broke |

## What would change the plan

Agree on this before anything runs:

- **HeliX should win** on delivered size and on native builds, because those are its design goals. If it doesn't, something in the core
  is wrong.
- **HeliX should match the best arm** on cost and bugs. If it loses clearly to Three.js or Pixi, the API and docs are the problem. The
  fix is the narrow path: a core reference sized for an agent, and names an agent expects.
- **If clean room comes close to HeliX** on everything except native, HeliX's value is native builds and small web delivery only. The
  scope should shrink to that.

## Setup and cost

- Godot needs its binary and web export templates installed, about 1 GB. OpenFL and Lime install through haxelib. Three.js and Pixi
  come from npm.
- Each arm runs on the private display for anything native, never the user's desktop.
- **Cost:** six arms of a full game each, roughly one to three hours of agent time per arm, plus three human rounds per arm. This is
  a large spend.
- A cheaper first pass: three arms (clean room, Three.js, HeliX), and the spec cut to one level.
