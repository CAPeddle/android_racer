# Session bootstrap — start here on a new machine

Read this first if you're picking up **Android Racer** on a machine that
hasn't touched this repo before (including a laptop migration). Then read:
- **`CLAUDE.md`** — architecture, conventions, the testing policy.
- **`docs/design-notes.md`** — the design & playability roadmap, plus a
  dated log of build-toolchain/on-device sessions (read the two most recent
  "Session continuation" entries there for the full story behind what's
  below).
- **`docs/difficulty-curve.svg`** — the current campaign difficulty ramp,
  charted.

## Where things stand (as of 2026-07-13)

- Core game (coins/score/win, 3-level campaign, difficulty ramp, procedural
  audio + juice) is done and CI-green. See `CLAUDE.md` for the architecture.
- **Godot 4.2.2 build + Android export is fully working and confirmed** on
  the previous machine: `export_presets.cfg` is committed, the ETC2/ASTC
  texture-compression fix is in `project.godot`, and a signed debug APK
  builds cleanly via `godot --headless --export-debug "Android"
  build/android_racer.apk`.
- **WiFi deploy to a physical tablet is confirmed working end-to-end**
  (pair → connect → install → launch → verified running via `adb shell
  pidof`).
- **A real on-device freeze bug was found, root-caused, and fixed** (see
  "Job #1" below) but **not yet cleanly re-verified on hardware** — the
  verification attempt was interrupted by the test tablet's WiFi
  ADB connection dropping (unrelated device/network flakiness, not the fix).
  This is the single most important open item.

## Job #1 — verify the pause/freeze fix on-device

This is the first thing to do once you have a Godot install and the test
tablet reachable again:

1. On the tablet: **Settings → Display → Screen timeout → raise it** (it was
   found set to 30 seconds — short enough to lock the screen during normal
   play pauses like the "CAUGHT!" message or a level-clear celebration, which
   independently looks like a freeze regardless of the code fix).
2. Re-pair Wireless debugging if the connection has dropped: Settings →
   Developer options → Wireless debugging shows a **pairing** IP:port+code
   (first-time only) and a separate **connect** IP:port (used every time) —
   don't confuse the two. `adb pair <ip>:<pairing_port> <code>`, then
   `adb connect <ip>:<connect_port>`.
3. Build + install the current APK (see "Build / export / deploy" below).
4. Play, then deliberately let the screen lock (wait it out, or press the
   power button), unlock, and confirm the player car and police **resume
   moving immediately** without needing the reset button. That confirms the
   `NOTIFICATION_APPLICATION_FOCUS_IN` fallback in `game.gd`'s
   `_notification()` actually recovers a stuck-paused game on this device.
5. If it's still frozen after unlocking: re-open
   `test/unit/test_game_scene.gd` and `docs/design-notes.md`'s "on-device
   freeze bug" section — the mechanism is well understood and tested; a
   remaining failure likely means this device's OEM Android skin has some
   other lifecycle quirk (e.g. never firing `FOCUS_IN` either) and the fix
   needs a second fallback signal.

## Restoring secrets / local settings after a laptop migration

If you're on a **new laptop** for this project, the git history has
everything except machine-local secrets and Claude Code's local (gitignored)
state. Those live in the shared OneDrive vault at
`Documents\Vault\claude-laptop-transfer\android_racer\` — see that folder's
place in the root `BOOTSTRAP.md` for the full restore checklist. In short:
- `settings.local.json` → `.claude/settings.local.json`
- `remember/` → `.remember/`
- `godot-editor/debug.keystore` → `%USERPROFILE%\.android\debug.keystore`
  (keeps the APK signing identity consistent — see that folder's `README.md`
  for why this matters and the keystore alias/password)
- `godot-editor/editor_settings-4.tres` → reference for the Android
  export paths in `%APPDATA%\Godot\editor_settings-4.tres` (don't blindly
  overwrite; the absolute paths will need adjusting if the new machine's
  username/drive/SDK location differs)

## Build / run / test

**Requires a local Godot 4.x install** (project targets feature set `4.2`;
CI pins **Godot 4.2.2**, non-.NET build). Godot is not vendored — install it
yourself and invoke by full path if it's not on `PATH`.

- **Editor:** `godot --editor` (or `-e`) from the project root. Main scene is
  `res://scenes/Game.tscn`.
- **Run directly:** `godot` from the project root.
- **Tests** (GUT is git-ignored — install it first):
  ```
  git clone --depth 1 --branch v9.3.0 https://github.com/bitwes/Gut.git /tmp/gut
  mkdir -p addons && cp -r /tmp/gut/addons/gut addons/gut   # copy ONLY the addon
  godot --headless --import                                  # REQUIRED after adding GUT — see gotcha below
  godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test/unit -ginclude_subdirs -gexit
  ```
  CI runs the same suite on every PR and on pushes to `master`
  (`.github/workflows/tests.yml`, pinned to GUT v9.3.0).

  **Gotcha:** if you `--headless -s addons/gut/gut_cmdln.gd ...` right after
  cloning GUT in, without first running `--headless --import`, it **hangs
  indefinitely with no error output** — GUT's GUI resources (fonts/theme)
  aren't imported yet and something downstream stalls instead of failing
  cleanly. Always import once after installing/updating GUT.

## Android export & deploy

Already configured and committed (`export_presets.cfg`, the ETC2/ASTC fix in
`project.godot`) — this is **not** a from-scratch setup anymore, just
machine-local tooling to install:

1. **Godot editor 4.2.2 stable (non-.NET)** + matching **export templates**
   (Editor → Manage Export Templates → Download, or download separately and
   place under `%APPDATA%\Godot\export_templates\4.2.2.stable\`).
2. **Android SDK** (build-tools, platform-tools/`adb`, an NDK version Godot
   4.2.2 supports — the previous machine used build-tools 34.0.0 + 36.1.0,
   NDK 26.1.10909125) and a **JDK 17+** (previous machine: JDK 21, OpenLogic).
3. Point the editor at them and at a debug keystore: **Editor → Editor
   Settings → Export → Android** (`android_sdk_path`, `java_sdk_path`,
   `debug_keystore` + user/pass). Restore `debug.keystore` from the OneDrive
   vault first (see above) so the signing identity matches what was
   previously installed on the test tablet.
4. Build: `godot --headless --export-debug "Android" build/android_racer.apk`
   (or Project → Export in the editor). Output is gitignored — expect to
   rebuild it, don't look for it in git history.
5. Deploy over WiFi: pair/connect via `adb` (see "Job #1" above for the
   pairing vs. connect port distinction), then `adb install -r
   build/android_racer.apk`.

Display is configured for **landscape**, viewport `2000x1200`.

## On-device validation checklist (tunables)

These are `@export` values, editable live in the Godot editor Inspector — no
code change needed to retune. Current defaults and what to feel-check:

| Area | Where | Current default | What to look for |
|------|-------|-----------------|------------------|
| Screen shake on catch | `Game` node → `game.gd` | `shake_strength = 16.0`, `shake_decay = 45.0` | Punchy but not nauseating for a young child. |
| Coin sparkle timing | `Coin.tscn` → `coin.gd` | `sparkle_seconds = 0.5` | Reads as celebratory, finishes before the coin frees. |
| Engine hum | `Player` → `player.gd` | `engine_enabled = true`, `engine_volume_db = -16.0` | Present but not annoying at speed. |
| **Difficulty / escapability** | `levels/level_0*.tres` + `player.gd` `max_speed = 450.0` | police speed 240 / 320 / 380 | Police use *pure pursuit* and cut corners, so "police speed < 450" doesn't guarantee escape — confirm each level is winnable-but-tense for a young kid. |
| No-lose Level 1 | `levels/level_01.tres` `practice_mode = true` | on | Police still chase (siren + tint) but can't catch — a gentle on-ramp, not boring. |
| Steering / driving | `player.gd` (`look_ahead_distance`, `steering_update_interval`) | — | Auto-steer holds the line; hold-to-accelerate / release-to-brake feels right on touch. |

Any change to a tunable is fine to commit directly. Any change to **game
logic** must ship with GUT tests (`CLAUDE.md` → Testing) and stay CI-green.

## Planned direction (after Job #1)

From `docs/design-notes.md` (read it for the full backlog + which skill
helps with each):

1. **Art direction via `canvas-design` + the existing `custom_texture`
   hooks** — highest visual-impact, lowest-code. `PlayerCar`/`PoliceCar`
   already expose it; `Coin` still needs an equivalent hook.
2. **Interactive prototypes via `artifact-design`** — validate look/feel or a
   new track shape before writing Godot code.
3. **More juice + UX** — a "GO!" countdown, nearest-coin indicator, pause
   menu, squash-stretch, slow-mo on level clear, near-miss feedback.
4. **Quantitative balancing via `dataviz`** — keep `difficulty-curve.svg` in
   sync whenever the ramp changes.
5. **More themed tracks** — each is one new `.tres` in `GameScene.LEVELS`.

## Constraints to carry forward

- **GUT tests are required** for any game-logic change; the suite must stay
  green in CI before merge (`CLAUDE.md` → Testing).
- Preserve established patterns: signal-driven `GameManager`, data-driven
  `LevelData`, formal state machines, `@export` tunables, static typing.
- The autoload scripts (`game_manager.gd`, `audio_manager.gd`) must **not**
  declare a `class_name` matching their autoload name — it cascades a parse
  error into every dependent script.
- Headless CI/dev containers have no Godot binary and no physical device —
  "feel" and on-device behavior (like Job #1 above) can only be validated on
  a machine with both, as this doc assumes.
