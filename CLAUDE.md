# CLAUDE.md

Guidance for AI assistants working in this repository.

## Project overview

**Android Racer** ("Police Escape") is a small, child-friendly 2D racing game
built with **Godot 4** (project targets feature set `4.2`, Mobile renderer). The
player drives a car that auto-steers around a looping track by holding down a
touch/click; police cars detect and chase the player, and getting caught resets
the level. It is intended to be side-loaded onto an Android tablet with no ads.

The entire game is written in **GDScript**. There is no build system, package
manager, or compiled code — Godot loads the project directly.

## Running & editing the project

There is no CLI build/test tooling checked in; work through the Godot editor.

- **Open the editor:** `godot --editor` (or `godot -e`) from the project root.
- **Run the game:** `godot` from the project root, or press Play in the editor.
  The main scene is `res://scenes/Game.tscn` (`run/main_scene` in
  `project.godot`).
- **Requires Godot 4.x** (project written against 4.2). Godot itself is not
  vendored — a local install is needed to run or export.
- Display is configured for **landscape**, viewport `2000x1200`, stretch
  `canvas_items`/`expand`. 2D gravity is `0` (top-down driving, no physics fall).

## Repository layout

```
project.godot          # Godot project config; autoloads GameManager, sets main scene
icon.svg               # App icon
README.md              # Human-facing notes: architecture + testing strategy
scenes/
  Game.tscn            # Root scene: Road (Path2D), Player, PoliceContainer, UI
  Player.tscn          # CharacterBody2D player car (collision_layer 1)
  Police.tscn          # Area2D police car with a DetectionZone child Area2D
scripts/
  game_manager.gd      # Autoload singleton: signals + global game state machine
  game.gd              # GameScene: wiring, level build, spawning, UI, reset flow
  player.gd            # PlayerCar: input + steering + player state machine
  police.gd            # PoliceCar: detection/chase AI state machine
  level_data.gd        # LevelData Resource: road points, spawn fractions, etc.
levels/
  level_01.tres        # Default LevelData resource instance
docs/screenshots/      # SVG mockups of the UI
```

## Architecture

The codebase was deliberately refactored to be **signal-driven** with **formal
state machines** and **data-driven levels**. Preserve these patterns when making
changes.

### GameManager (autoload singleton)

`scripts/game_manager.gd` is registered as an autoload (`GameManager`) in
`project.godot`, so it is globally accessible from every script. It owns the
top-level `GameState` (`RUNNING`, `PAUSED`, `RESETTING`) and is the **central
signal bus**. Gameplay objects never call each other directly — they emit to and
listen on `GameManager`.

Signals:
- `reset_requested(reason: StringName)` — request a level reset (`&"caught"` or
  `&"manual"`).
- `player_caught(source: Node)` — police caught the player.
- `game_pause_changed(is_paused: bool)` — app pause/resume.
- `player_state_changed(state: int)` / `police_state_changed(police, state)` —
  state-machine telemetry.
- `input_lock_changed(is_locked: bool)` — global input lock toggled.

Key methods: `request_player_caught()` (guarded by `_reset_locked` so only one
catch fires per reset cycle), `request_reset()`, `reset_complete()`,
`set_game_paused()`, `set_input_locked()` / `is_input_locked()`.

### GameScene (`game.gd`)

The `Game` root node orchestrates everything in `_ready()`: connects signals,
draws the grass background + road, styles the UI, builds the level from
`LevelData`, positions the player, and spawns police. It:
- Builds the road as a `Curve2D` on the `Road` `Path2D` (looping, with tangents
  scaled by `LevelData.tangent_scale`) and renders it via a generated `Line2D`.
- Spawns police at fractional offsets along the baked curve length.
- Handles the reset flow (shows the `CAUGHT!` label, waits, then repositions
  player + police).
- Bridges OS pause via `_notification()` (`NOTIFICATION_APPLICATION_PAUSED/
  RESUMED`) into `GameManager.set_game_paused()`.
- The UI layer + reset button use `PROCESS_MODE_WHEN_PAUSED` so they remain
  responsive while the tree is paused.

### PlayerCar (`player.gd`) — CharacterBody2D

State machine `CarState`: `IDLE → ACCELERATING → BRAKING → CRASHING`. Behavior:
- Holding a touch (`InputEventScreenTouch`) or left mouse accelerates toward
  `max_speed`; releasing brakes toward 0.
- **Auto-steers** along the road: periodically (every `steering_update_interval`)
  it samples the curve `look_ahead_distance` ahead using
  `Curve2D.get_closest_offset()` + `sample_baked()`, wrapping with `fmod` at the
  track end, and steers toward that point.
- Reacts to `player_caught` (→ `CRASHING`) and `input_lock_changed` (freezes
  input) via `GameManager` signals.

### PoliceCar (`police.gd`) — Area2D

State machine `PoliceState`: `IDLE → ALERT → CHASING → RESETTING`. Behavior:
- A child `DetectionZone` (large `CircleShape2D`) triggers `ALERT` when the
  player enters; after `alert_duration` it transitions to `CHASING`.
- While chasing, it `lerp_angle`-turns toward the player and drives forward.
  If the player gets farther than `disengage_distance`, it `reset()`s.
- Its own body overlapping the player emits `GameManager.request_player_caught`.
- `_apply_state_visual()` tints the car body per state (red/orange/bright red/
  dark red).

### LevelData (`level_data.gd`) — Resource

Data-driven level definition: `road_points` (loop vertices), `tangent_scale`,
`road_width`, and `police_spawn_fractions` (0–1 positions along the track).
`levels/level_01.tres` is the default, referenced by `GameScene.DEFAULT_LEVEL`.
**To add a level, create a new `.tres` LevelData resource** and assign it to the
`GameScene.level_data` export — no code changes needed.

## Collision layers

- **Layer 1** = player. `Player` is on `collision_layer 1`, `collision_mask 0`.
- **Layer 2** = police. `Police` Area2D is on `collision_layer 2`,
  `collision_mask 1` (so it overlaps the player). The `DetectionZone` is on
  `collision_layer 0`, `collision_mask 1`.
- The player is tagged into the `"player"` group (in `game.gd`) and police check
  `is_in_group("player")` rather than relying on layers alone.

## Conventions

- **GDScript style:** static typing everywhere (`var x: float`, typed function
  signatures and returns, typed arrays like `Array[PoliceCar]`). Match this.
- **Signals over direct coupling:** route cross-object communication through
  `GameManager`, not direct node references, wherever practical.
- **State machines:** gameplay entities transition via a single `_set_state()`
  method that guards against no-op transitions and reports to `GameManager`.
  Add new behaviors as states/transitions, not ad-hoc booleans.
- **Tunable values are `@export` vars** (speeds, distances, timers) so they can
  be adjusted in the editor. Prefer adding exports over hardcoding constants.
- **StringName literals** (`&"caught"`) are used for signal reasons.
- Use `push_warning()` for recoverable misconfiguration (see `_setup_level_data`,
  `PlayerCar.setup`) and fall back to sane defaults rather than crashing.

## Testing

No tests are checked in yet. The README documents the intended strategy using
[GUT](https://github.com/bitwes/Gut): add focused unit tests around the pure
state transitions of `PlayerCar`, `PoliceCar`, and `GameManager` (see README
"Testing strategy" for the specific cases). If you add logic, prefer keeping
transitions pure/testable and add GUT tests accordingly.

## Git workflow

- Default branch is `master`; changes land via pull requests.
- `.gitignore` excludes the Godot cache (`.godot/`), export credentials, and
  common build/log artifacts — never commit these.
