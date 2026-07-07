# android_racer
A simple ad free side loadable Racer for my boy

## Architecture notes (production hardening)

- Gameplay flow is signal-driven through `GameManager` (`reset_requested`, `player_caught`, `input_lock_changed`, pause/state signals).
- `PlayerCar` uses a formal state machine: `IDLE`, `ACCELERATING`, `BRAKING`, `CRASHING`.
- `PoliceCar` uses a formal state machine: `IDLE`, `ALERT`, `CHASING`, `RESETTING`.
- Level setup is data-driven via `LevelData` resources (`levels/level_01..03.tres`) for road points, police/coin spawn fractions, and per-level police speed.
- Level progression is a campaign: clearing all coins in a level advances to the next (`GameManager.advance_level` → `level_changed`); clearing the last shows a win screen and loops back to level 1 (`campaign_complete` → `restart_campaign`). Getting caught reloads the current level, keeping progress.
- Audio is an `AudioManager` autoload that listens to `GameManager` signals and plays coin/caught/clear/win SFX plus a chase siren. All sounds are generated procedurally by `Sfx` (`scripts/sfx.gd`) — no audio assets are shipped. Juice: coin-pickup pop, a red screen flash on caught, and a speed-scaled engine hum.

## Testing (Godot + GUT)

Unit tests live in `test/unit/` and use [GUT](https://github.com/bitwes/Gut).
**They are required:** every change to game logic must ship with GUT tests, and
the suite must be green in CI before merge (see `CLAUDE.md` for the full policy).

- **CI:** `.github/workflows/tests.yml` runs the suite on every pull request and
  on pushes to `master`. It installs Godot 4.2.2 headless, clones GUT (pinned to
  a v9.x tag) into `addons/gut`, imports the project, and fails the job on any
  test failure. GUT is not vendored in the repo.
- **Run locally:** install GUT via the Godot editor AssetLib (or
  `git clone https://github.com/bitwes/Gut.git addons/gut`), then run:

  ```
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
  ```

Current coverage focuses on the pure, deterministic parts of the code:

- **`GameManager`** — score/coin counting, `level_won` firing exactly once,
  `collect_coin` gated on the `RUNNING` state, single-fire `request_player_caught`,
  `reset_complete` state restoration, input-lock change signalling, and pause.
- **`GameManager` level progression** — `advance_level` emitting `level_changed`
  or `campaign_complete`, `restart_campaign`, and `set_level_count` index clamping.
- **`Sfx`** — procedural `AudioStreamWAV` generation (format, mix rate, byte
  length, looping) for `tone` / `sweep` / `jingle`.
- **`AudioManager`** — the pure decision helpers: ding-only-on-score-increase and
  siren-active-while-any-police-chases.

Audio *playback*, the coin pop / screen flash / engine hum (presentation), and
physics-dependent movement are intentionally not unit-tested — they need a real
audio device or physics frames. The logic that decides *when* they happen is.
- **`Coin`** — the one-shot pickup guard (a coin reports to `GameManager` only once).
- **`PlayerCar` / `PoliceCar`** — the `reset()` state-machine paths back to `IDLE`.

Steering/physics-dependent behavior (look-ahead curve sampling, speed clamping,
timed `ALERT -> CHASING`) is intentionally left out of the current suite because
it needs real physics frames or a baked `Curve2D`; add such tests only when they
can be made deterministic.
