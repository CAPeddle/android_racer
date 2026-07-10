# Session bootstrap — continuing on a build-capable machine

You (or an AI assistant) are picking this project up on a laptop that **can build
and deploy to a real Android device** for the first time. Every gameplay change
so far has shipped **without a single on-device play-test** — the dev containers
were headless with no Godot binary, so "feel" was never validated. That is the
headline: **the code is CI-green and logic-tested, but unvalidated on hardware.**

Read this alongside:
- **`CLAUDE.md`** — architecture, conventions, the testing policy (start here).
- **`docs/design-notes.md`** — the design & playability roadmap and the
  **skills/tools** discussion (`artifact-design`, `dataviz`, `canvas-design` via
  the `custom_texture` hooks). The "planned direction" below points back into it.
- **`docs/difficulty-curve.svg`** — the current campaign difficulty ramp, charted.

## Where we are

Shipped and merged to `master`:
- Coins / score / collect-all-coins win condition; a 3-level campaign with a
  difficulty ramp; procedural audio + juice.
- **Most recent (PR #9):** difficulty tuning (`LevelData.practice_mode` + a
  `GameManager` catching flag — Level 1 is a no-lose "practice" level), plus two
  juice additions: **screen shake on catch** and a **coin-pickup sparkle**.

None of the above has been felt on a device. That's job #1.

## Job #1 — on-device validation (do this before new features)

Build to the tablet, play each level, and judge **feel**. These are all
`@export` values (editable live in the Godot editor Inspector — no code change
needed to tune). Current defaults and what to check:

| Area | Where | Current default | What to look for |
|------|-------|-----------------|------------------|
| Screen shake on catch | `Game` node → `game.gd` | `shake_strength = 16.0`, `shake_decay = 45.0` | Punchy but not nauseating for a young child. Too weak = no impact; too strong = disorienting. |
| Coin sparkle timing | `Coin.tscn` → `coin.gd` | `sparkle_seconds = 0.5` | Burst reads as celebratory and finishes before the coin frees; not too long/laggy. |
| Engine hum | `Player` → `player.gd` | `engine_enabled = true`, `engine_volume_db = -16.0` | Present but not annoying at speed; pitch scales with speed. Mute-toggle candidate if it grates. |
| **Difficulty / escapability** | `levels/level_0*.tres` + `player.gd` `max_speed = 450.0` | police speed 240 / 320 / 380 | **The key unknown.** Police use *pure pursuit* and cut corners, so "police speed < 450" does **not** guarantee the player can escape. Confirm each level is winnable-but-tense for a young kid; retune `police_speed`, `alert_duration`, detection radius, and coin spacing as needed. |
| No-lose Level 1 | `levels/level_01.tres` `practice_mode = true` | on | Confirm police still chase (siren + tint) for excitement but genuinely cannot catch — a gentle on-ramp, not boring. |
| Steering / driving | `player.gd` (`look_ahead_distance`, `steering_update_interval`) | — | Auto-steer holds the racing line; holding to accelerate / releasing to brake feels right on a touchscreen. |

**When you retune:** any change to a tunable is fine to commit directly. Any
change to **game logic** must ship with GUT tests (see `CLAUDE.md` → Testing) and
stay CI-green. Record what you changed and why in the PR.

## Build / run / deploy

**Requires a local Godot 4.x install** (project targets feature set `4.2`; CI
pins **Godot 4.2.2**). Godot is not vendored.

- **Run in the editor:** `godot --editor` (or `-e`) from the project root, then
  press Play. Main scene is `res://scenes/Game.tscn`.
- **Run the game directly:** `godot` from the project root.
- **Run the tests locally** (GUT is git-ignored, install it first):
  ```
  git clone --depth 1 --branch v9.3.0 https://github.com/bitwes/Gut.git /tmp/gut
  cp -r /tmp/gut/addons/gut addons/gut          # copy ONLY the addon, not the repo root
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -gexit
  ```
  (Or install GUT via the editor **AssetLib**.) CI runs this same suite on every
  PR and on pushes to `master`.

### First-time Android export setup (not yet in the repo)

There is **no `export_presets.cfg` and no `android/` build template committed
yet** — Android export is unconfigured. First time on the laptop:

1. **Editor → Manage Export Templates → Download** the 4.2.2 templates.
2. Install the **Android build template**: *Project → Install Android Build
   Template* (creates `android/build/`).
3. Install the **Android SDK / OpenJDK** and point the editor at them:
   *Editor → Editor Settings → Export → Android* (SDK path, debug keystore). For
   sideload testing a **debug keystore** is enough — no Play Store signing.
4. *Project → Export → Add… → Android*, then **Export Project** to an `.apk`
   (or use one-click deploy with the device in USB-debug mode).
5. Sideload: `adb install -r path/to/game.apk` (or one-click deploy).

**Do commit** `export_presets.cfg` once created (it's the reproducible export
config). **Do not commit** keystores/credentials or the generated `android/`
template internals beyond what Godot expects — see `.gitignore`. Display is
already configured for **landscape**, viewport `2000x1200`.

## Planned direction (after validation)

From `docs/design-notes.md` (read it for the full backlog + which skill helps):

1. **Art direction via `canvas-design` + the existing `custom_texture` hooks** —
   the highest visual-impact, lowest-code step. `PlayerCar` and `PoliceCar`
   already expose `custom_texture: Texture2D` (PR #3) so sprites drop straight in;
   `Coin` still needs an equivalent hook. `canvas-design` is enable-on-demand —
   turn it on when doing real art (car sprites, coin art, a title/logo,
   background tiles).
2. **Interactive prototypes via `artifact-design`** — validate a look/feel or a
   new track shape as a self-contained HTML prototype *before* writing Godot
   code (e.g. a "track sketcher" that outputs a `road_points` array to paste into
   a new `levels/level_0N.tres`).
3. **More juice + UX** (mostly skill-free GDScript): a "GO!" countdown at level
   start, a nearest-uncollected-coin indicator, a pause menu, squash-stretch on
   the car, a slow-mo/zoom on level clear, "near-miss" feedback.
4. **Quantitative balancing via `dataviz`** — keep the difficulty chart
   (`difficulty-curve.svg`) in sync whenever the ramp changes.
5. **More themed tracks** — each is one new `.tres` added to `GameScene.LEVELS`,
   no logic changes.

Adding a level or tuning difficulty needs no new skill — it's data
(`levels/*.tres`) plus GUT tests for any logic. Reach for a skill only when the
task matches (art → `canvas-design`; prototype → `artifact-design`; chart →
`dataviz`).

## Constraints to carry forward

- **GUT tests are required** for any game-logic change; the suite must stay green
  in CI before merge (`CLAUDE.md` → Testing).
- Preserve the established patterns: signal-driven `GameManager`, data-driven
  `LevelData`, formal state machines, `@export` tunables, static typing.
- The autoload scripts (`game_manager.gd`, `audio_manager.gd`) must **not**
  declare a `class_name` matching their autoload name — it cascades a parse
  error into every dependent script.
