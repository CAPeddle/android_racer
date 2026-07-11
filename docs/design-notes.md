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
APK and set up the local toolchain needed to do so. **WiFi deployment to a
device was NOT yet confirmed** — no device was connected during the session.
Pick this up here if the next task is "deploy to my tablet" or anything
Android-export-related.

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
cross-referencing Godot 4.2's actual `get_export_options()` defaults — it is
currently **untracked** (gitignore only excludes `export_credentials.cfg`, not
`export_presets.cfg`; ask before committing it, since export presets are
sometimes intentionally kept local/per-machine).

**Verified:** `godot4.exe --headless --export-debug "Android"
build/android_racer.apk` exits 0 and produces a signed, verified
`build/android_racer.apk` (~21 MB) + `.apk.idsig`. Buildability is confirmed.

**Not yet done — WiFi deploy:** `adb devices` returned empty (no device
connected). Next steps to finish the original ask:
1. On the tablet: Settings → Developer options → **Wireless debugging** → on,
   note the IP:port (and pairing code if Android 11+ shows a separate pairing
   screen).
2. From this machine: `adb pair <ip>:<pairing_port>` (enter the on-device
   code) if pairing for the first time, then `adb connect <ip>:<port>`.
3. `adb devices -l` should now list the tablet.
4. `adb install -r build/android_racer.apk`, then launch and play-test on
   device.
5. Both devices must be on the **same WiFi network/subnet**.

**Minor non-issue encountered:** the very first headless run after a fresh
`.godot/` cache threw `Identifier "Sfx" not declared`, breaking the
`AudioManager` autoload — this is a known Godot first-import quirk (global
`class_name` cache isn't built yet). A second headless pass
(`--headless --editor --quit-after 30`) resolved it with zero errors; not a
real bug, no code change needed.

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
