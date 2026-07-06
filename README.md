# android_racer
A simple ad free side loadable Racer for my boy

## Architecture notes (production hardening)

- Gameplay flow is signal-driven through `GameManager` (`reset_requested`, `player_caught`, `input_lock_changed`, pause/state signals).
- `PlayerCar` uses a formal state machine: `IDLE`, `ACCELERATING`, `BRAKING`, `CRASHING`.
- `PoliceCar` uses a formal state machine: `IDLE`, `ALERT`, `CHASING`, `RESETTING`.
- Level setup is data-driven via `LevelData` resources (`levels/level_01.tres`) for road points and police spawn fractions.

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
- **`Coin`** — the one-shot pickup guard (a coin reports to `GameManager` only once).
- **`PlayerCar` / `PoliceCar`** — the `reset()` state-machine paths back to `IDLE`.

Steering/physics-dependent behavior (look-ahead curve sampling, speed clamping,
timed `ALERT -> CHASING`) is intentionally left out of the current suite because
it needs real physics frames or a baked `Curve2D`; add such tests only when they
can be made deterministic.
