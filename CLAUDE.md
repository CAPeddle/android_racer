# CLAUDE.md

Guidance for AI assistants working in this repository.

## Project overview

**Android Racer** ("Police Escape") is a small, child-friendly 2D racing game
built with **Godot 4** (project targets feature set `4.2`, Mobile renderer). The
player drives a car that auto-steers around a looping track by holding down a
touch/click; police cars detect and chase the player, and getting caught resets
the level. The player collects coins scattered along the track for score;
grabbing every coin triggers a win/celebration and restarts the run. It is
intended to be side-loaded onto an Android tablet with no ads.

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
  Game.tscn            # Root scene: Road, Player, PoliceContainer, CoinContainer, UI
  Player.tscn          # CharacterBody2D player car (collision_layer 1)
  Police.tscn          # Area2D police car with a DetectionZone child Area2D
  Coin.tscn            # Area2D collectible coin with a Visual (Polygon2D) child
scripts/
  game_manager.gd      # Autoload singleton: signals + global game state machine
  game.gd              # GameScene: wiring, level build, spawning, UI, reset/win flow
  player.gd            # PlayerCar: input + steering + player state machine
  police.gd            # PoliceCar: detection/chase AI state machine
  coin.gd              # Coin: player-overlap pickup that reports to GameManager
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

> **Gotcha:** the autoload script must NOT declare `class_name GameManager`. In
> Godot 4 a `class_name` matching an autoload name collides ("hides an autoload
> singleton") and fails to parse, cascading a parse error into every script that
> references `GameManager`. The autoload already provides the global name.

Signals:
- `reset_requested(reason: StringName)` — request a level reset (`&"caught"` or
  `&"manual"`).
- `player_caught(source: Node)` — police caught the player.
- `game_pause_changed(is_paused: bool)` — app pause/resume.
- `player_state_changed(state: int)` / `police_state_changed(police, state)` —
  state-machine telemetry.
- `input_lock_changed(is_locked: bool)` — global input lock toggled.
- `score_changed(score: int)` — current score updated.
- `level_won()` — every coin in the level has been collected.

Key methods: `request_player_caught()` (guarded by `_reset_locked` and the
`RESETTING` state so only one catch/win fires per reset cycle), `request_reset()`,
`reset_complete()`, `set_game_paused()`, `set_input_locked()` /
`is_input_locked()`, and the score/coin API `set_coin_total()`, `collect_coin()`
(only counts while `RUNNING`; emits `level_won` when all coins are gathered),
`reset_score()`, `get_score()`.

### GameScene (`game.gd`)

The `Game` root node orchestrates everything in `_ready()`: connects signals,
draws the grass background + road, styles the UI, builds the level from
`LevelData`, positions the player, and spawns police + coins. It:
- Builds the road as a `Curve2D` on the `Road` `Path2D` (looping, with tangents
  scaled by `LevelData.tangent_scale`) and renders it via a generated `Line2D`.
- Spawns police and coins at fractional offsets along the baked curve length
  (`_spawn_police()` / `_spawn_coins()`), and reports the coin count to
  `GameManager.set_coin_total()`.
- Handles the reset flow (shows the `CAUGHT!` label, waits, then repositions
  player + police, respawns coins, and resets the score) and the win flow
  (`level_won` → show `YOU WIN!`, wait, then reset).
- Updates the `ScoreLabel` on `score_changed`.
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

### Coin (`coin.gd`) — Area2D

A collectible pickup. When the player body overlaps it, it hides its visual,
stops monitoring, calls `GameManager.collect_coin(self)`, emits `collected`, and
`queue_free()`s. Coins are one-shot (`_is_collected` guard); the scene respawns
a fresh set on every reset rather than reusing instances. The score/win decision
lives entirely in `GameManager` — the coin only reports the pickup.

### LevelData (`level_data.gd`) — Resource

Data-driven level definition: `road_points` (loop vertices), `tangent_scale`,
`road_width`, `police_spawn_fractions`, and `coin_fractions` (both are 0–1
positions along the track). `levels/level_01.tres` is the default, referenced by
`GameScene.DEFAULT_LEVEL`. **To add a level, create a new `.tres` LevelData
resource** and assign it to the `GameScene.level_data` export — no code changes
needed. Collect-all-coins is the win condition, so a level's coin count defines
its objective.

## Collision layers

- **Layer 1** = player. `Player` is on `collision_layer 1`, `collision_mask 0`.
- **Layer 2** = police. `Police` Area2D is on `collision_layer 2`,
  `collision_mask 1` (so it overlaps the player). The `DetectionZone` is on
  `collision_layer 0`, `collision_mask 1`.
- **Coins** are Area2Ds on `collision_layer 0`, `collision_mask 1` — they detect
  the player body but are not themselves detectable by anything else.
- The player is tagged into the `"player"` group (in `game.gd`); police and
  coins check `is_in_group("player")` rather than relying on layers alone.

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
- **Every change to game logic ships with GUT tests** (see Testing) — keep
  transitions pure/testable.

## Testing

**GUT tests are REQUIRED.** Every change to game logic must ship with
[GUT](https://github.com/bitwes/Gut) unit tests under `test/unit/`, and the
suite must be green in CI before a PR is merged. Treat missing or failing tests
as a blocking defect, not a follow-up.

- **What to test:** the pure, deterministic parts of the code — the
  state-machine transitions and signal contracts of `GameManager`, `PlayerCar`,
  `PoliceCar`, and `Coin`. Keep transitions pure/testable (drive them through a
  single `_set_state()`); avoid tests that depend on real physics frames or a
  baked `Curve2D` you cannot reliably set up. Instantiate a fresh subject per
  test and use `watch_signals()` for signal assertions. The existing files in
  `test/unit/` are the pattern to follow.
- **CI runs them automatically.** `.github/workflows/tests.yml` installs Godot
  4.2.2 headless, clones GUT (pinned to a v9.x tag) into `addons/gut`, imports
  the project, and runs the suite on every pull request and on pushes to
  `master`. The job fails if any test fails.
- **Run locally** (GUT is not vendored — see `.gitignore`): install GUT via the
  Godot editor **AssetLib**, or `git clone https://github.com/bitwes/Gut.git
  addons/gut`, then run:

  ```
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
  ```

## Git workflow

- Default branch is `master`; changes land via pull requests.
- `.gitignore` excludes the Godot cache (`.godot/`), export credentials, and
  common build/log artifacts — never commit these.
