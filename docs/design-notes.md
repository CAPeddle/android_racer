# Design & playability roadmap

Notes on how to improve the design and playability of Android Racer, and which
tools/skills help. Written to be **picked up by future AI-assisted sessions** —
if you're an assistant starting fresh, read this alongside `CLAUDE.md`.

The game is a child-friendly Godot 4 top-down racer ("Police Escape"). As of the
last update it has: coins/score/win, a 3-level campaign with a difficulty ramp,
and procedural audio + juice (see `CLAUDE.md` for the architecture). This doc is
about what to build **next**, not what exists.

## Session continuation: Android build & deploy toolchain (2026-07-11)

A session confirmed the project **builds successfully** into a signed debug
APK and set up the local toolchain needed to do so. **WiFi deployment was
later confirmed working end-to-end in the same machine's follow-up session —
see "Session continuation: on-device freeze bug" below.** Pick this up here
if the next task is Android-export-related and that section doesn't cover it.

**What's installed on this machine** (`C:\projects\personal\android_racer`,
Windows), none of it checked into the repo:
- Godot editor **4.2.2 stable, non-.NET** at `C:\tools\godot\godot4.exe`
  (matches the version CI uses in `.github/workflows/tests.yml`). Not on PATH —
  invoke by full path.
- Matching export templates (incl. `android_debug.apk`/`android_release.apk`)
  installed to `%APPDATA%\Godot\export_templates\4.2.2.stable\`.
- Android SDK already existed at `%LOCALAPPDATA%\Android\Sdk` (build-tools
  34.0.0 + 36.1.0, platforms, NDK 26.1.10909125, platform-tools/`adb`), and JDK
  21 (OpenLogic) with `JAVA_HOME` set. Godot's global editor settings
  (`%APPDATA%\Godot\editor_settings-4.tres`) were patched with
  `export/android/android_sdk_path` and `export/android/debug_keystore` →
  `%USERPROFILE%\.android\debug.keystore` (pre-existing debug keystore, standard
  `androiddebugkey`/`android` alias+password).

**Real project fix (not just machine setup):** `project.godot` was missing
`rendering/textures/vram_compression/import_etc2_astc=true` under `[rendering]`.
Godot 4.2 silently fails Android export validation without it (surfaces as an
unhelpfully blank `Cannot export project with preset "Android" due to
configuration errors:` with no detail — root-caused by reading
`editor/import/resource_importer_texture_settings.cpp` and
`platform/android/export/export_plugin.cpp` upstream, since headless CLI export
in 4.2.2 doesn't print the underlying warning). **This fix is real and belongs
in the repo regardless of who runs the export next.**

A local `export_presets.cfg` (Android preset, legacy non-Gradle build,
arm64-v8a, unique name `com.example.androidracer`) was hand-built by
cross-referencing Godot 4.2's actual `get_export_options()` defaults. **It is
now committed to the repo** (no secrets inside — the keystore fields are
empty strings; signing config lives only in the machine-local Godot editor
settings, see the bootstrap doc). No need to rebuild it from scratch on a new
machine — just re-point `keystore/debug` et al. via the editor if the
committed preset's empty keystore fields don't resolve automatically.

**Verified:** `godot4.exe --headless --export-debug "Android"
build/android_racer.apk` exits 0 and produces a signed, verified
`build/android_racer.apk` (~21 MB) + `.apk.idsig`. Buildability is confirmed.

**Minor non-issue encountered:** the very first headless run after a fresh
`.godot/` cache threw `Identifier "Sfx" not declared`, breaking the
`AudioManager` autoload — this is a known Godot first-import quirk (global
`class_name` cache isn't built yet). A second headless pass
(`--headless --editor --quit-after 30`) resolved it with zero errors; not a
real bug, no code change needed.

## Session continuation: on-device freeze bug (2026-07-11 – 2026-07-13)

**WiFi deploy is now confirmed working end-to-end.** Paired via `adb pair
<ip>:<pairing_port> <code>` (Android 11+ shows a separate pairing screen from
the main connect IP:port — don't confuse the two), then `adb connect
<ip>:<connect_port>`, `adb devices -l` showed the tablet (Samsung Galaxy Tab
S6 Lite, SM-P610) as `device` (authorized), `adb install -r
build/android_racer.apk` succeeded, and the app launched and was confirmed
running via `adb shell pidof com.example.androidracer`.

**Bug found on-device:** after real play, the game appeared completely frozen
— the reset button worked (visibly reset the player car) but nothing else
moved or responded. Root-caused via a new GUT test
(`test/unit/test_game_scene.gd`): `game.gd`'s `_notification()` pauses the
whole `SceneTree` on `NOTIFICATION_APPLICATION_PAUSED` and only unpauses on a
matching `NOTIFICATION_APPLICATION_RESUMED`. Only the UI layer + reset button
are exempted from pause (`PROCESS_MODE_WHEN_PAUSED`, set in
`_connect_signals()`) — `Player` and `Police` use the default
`PROCESS_MODE_INHERIT`, so a stuck-paused tree freezes them outright with no
way to recover if `RESUMED` never arrives. Device logcat showed a multi-minute
gap in touch events right before the freeze, consistent with a screen
timeout, and touches kept reaching the app afterward without gameplay ever
unfreezing — consistent with `RESUMED` being missed (a known flaky spot on
some Android/OEM skins, Samsung's One UI included).

**Fix shipped:** `game.gd`'s `_notification()` now also unpauses on
`NOTIFICATION_APPLICATION_FOCUS_IN` if the tree is currently paused — FOCUS_IN
reliably fires whenever the window regains focus, so it recovers a
stuck-paused game even when `RESUMED` is missed. Covered by two new GUT tests
(`test_focus_in_unpauses_when_resumed_notification_is_missed`,
`test_focus_in_is_a_noop_when_not_paused`). Full suite green.

**Real, separate contributing factor found on this specific tablet:**
`settings get system screen_off_timeout` returned `30000` (30 seconds). That
alone will lock the screen during any natural pause in play longer than 30s
(the "CAUGHT!" pause, a level-clear celebration, a kid just thinking) —
**recommend raising it** (Settings → Display → Screen timeout → 2–5 minutes)
independent of the code fix. This may be the dominant cause of "frozen"
reports in practice, more than the missed-`RESUMED` edge case itself.

**Not yet cleanly re-verified on-device.** A redeploy after the fix was
interrupted by two device/tooling issues, not the fix itself:
1. The tablet's WiFi ADB connection dropped (`device offline`, then
   "connection refused" on reconnect) after repeated screen-off cycles during
   testing — likely the tablet's WiFi radio itself sleeping. Needs
   Wireless-debugging re-paired (new pairing + connect ports each time it's
   toggled) before remote verification can continue.
2. `adb exec-out screencap` intermittently returned empty/black frames when
   racing the ~30s timeout — screenshots are not a reliable verification
   method on this device without also disabling/extending the timeout first.

**Next step, first thing on a build-capable machine with this tablet:** raise
the tablet's screen timeout, re-pair Wireless debugging, then play, let the
screen lock (naturally or via power button), unlock, and confirm the car and
police resume moving immediately without needing the reset button.

**Unrelated but real local-toolchain gotcha, worth knowing before it wastes
another hour:** running GUT headless via `-s addons/gut/gut_cmdln.gd`
**hangs indefinitely with no error** if the project's `.godot/` import cache
was built *before* `addons/gut/` was cloned in — GUT's GUI resources
(`GutRunner.tscn` → fonts/theme) fail to resolve and something downstream
stalls instead of erroring cleanly. Fix: run `godot4.exe --headless --import`
once **after** installing GUT, before running tests. (A stray file literally
named `nul` in the project root — a leftover `> nul` redirect typo, since
this shell's `>` doesn't discard to a null device the way PowerShell's does —
was investigated as a possible cause first and ruled out; it was still
correctly-identified debris and was removed.)

## Skills / tooling available for design work

Findings from searching the claude.ai skills + plugin marketplaces:

- **There is NO dedicated game-design, Godot, pixel-art, or "game-juice" skill.**
  The game-design thinking comes from the assistant directly, not a skill.
- **Loaded per session (general skills), useful here:**
  - `artifact-design` — build a self-contained interactive HTML prototype to
    validate a look/feel *before* implementing in Godot. Highest-value use: a
    "track sketcher" where you drag points and it outputs a `road_points` array
    to paste into a new `levels/level_0N.tres`; also title-screen mockups and a
    color-palette explorer.
  - `dataviz` — chart the **difficulty curve** (police speed vs. the player's
    `max_speed` of 450, police count, coin count per level) so balancing is
    quantitative, not guesswork.
  - `run` / `verify` — drive the app to feel a change; `code-review` / `simplify`
    — keep design changes clean.
- **Discoverable / enable-on-demand:**
  - `canvas-design` (Anthropic skill) — generates original visual art as PNG/PDF.
    This is the route to **real art assets**. PR #3 already added a
    `custom_texture: Texture2D` export on `PlayerCar` and `PoliceCar` precisely so
    sprites can be dropped in; `Coin` would need an equivalent hook. Use it for
    car sprites, coin art, a title/logo, and background tiles to replace today's
    flat procedural placeholders. Not enabled by default — suggest enabling it
    when doing art.

## Direction

1. **Art direction via `canvas-design` + the existing `custom_texture` hooks** —
   turn flat placeholders into real sprites. Lowest-code, high visual impact.
2. **Interactive prototypes via `artifact-design`** — approve look/feel and level
   shapes before writing Godot code.
3. **Quantitative balancing via `dataviz`** — keep the campaign winnable-but-tense
   for a young child.
4. **Juice + tuning directly in GDScript** — most playability gains need no skill.

## Playability backlog (rough priority)

Highest leverage first. Each ships with GUT tests where there's testable logic
(see the testing policy in `CLAUDE.md`).

1. **Difficulty & pacing** (core for a young kid): tune police speed/detection/
   alert timing and coin spacing into a gentle ramp; consider an easy "practice"
   first level and/or a "can't-lose" toddler mode (an `@export` on the police or
   a GameManager flag that disables catching). Validate with a `dataviz` chart.
   **Done (first pass):** `LevelData.practice_mode` + `GameManager`'s catching
   flag give a no-lose level; Level 1 uses it. The campaign ramp is charted in
   `docs/difficulty-curve.svg` (police 3→4→6, speed 240→320→380 — all below the
   player's 450 top speed, though pure-pursuit police cut corners, so final
   escapability is a play-test call — coins 6→9→12).
2. **More juice** (beyond the coin pop / screen flash / engine hum already in):
   screen shake on catch, a coin sparkle/particle trail, squash-stretch on the
   player car, a brief zoom or slow-mo on level clear, a follow-camera, and
   "near-miss" feedback when a police just misses.
3. **Readability / UX**: a "GO!" countdown at level start, an arrow/indicator to
   the nearest uncollected coin, a pause menu, bigger/juicier score & level text,
   and colorblind-safe police state tints.
4. **Identity & content**: a title screen, a win celebration (confetti), a
   car-select screen using the `custom_texture` hook, and more themed tracks
   (each is one new `.tres` added to `GameScene.LEVELS` — no logic changes).
5. **Real art assets** (via `canvas-design`) once the above hooks exist.

## Constraints to keep in mind

- **This repo's CI/dev containers are headless with no Godot binary by
  default**, and most fresh sessions won't have one either. Assistants can
  design and implement, and the GUT suite runs in CI, but **anything about
  *feel* (juice timing, audio volume, difficulty) needs a human editor
  play-test** — that is the real validation, as it has been for every gameplay
  PR so far. (One exception: this specific Windows dev machine now has a local
  Godot 4.2.2 + Android toolchain installed outside the repo — see "Session
  continuation" above. That's machine-local setup, not something CI or a fresh
  container gets for free.)
- **GUT tests are required** for game-logic changes (`CLAUDE.md` → Testing).
- Prefer the established patterns: signal-driven `GameManager`, data-driven
  `LevelData`, formal state machines, `@export` tunables.

## Suggested first step

A skill-free, high-impact bundle: **difficulty tuning + a `dataviz` difficulty-
curve chart + two juice additions (screen shake on catch, coin sparkle)**. Then,
if `canvas-design` is enabled, follow up with real sprites through the
`custom_texture` hooks.
