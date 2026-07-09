# Design & playability roadmap

Notes on how to improve the design and playability of Android Racer, and which
tools/skills help. Written to be **picked up by future AI-assisted sessions** —
if you're an assistant starting fresh, read this alongside `CLAUDE.md`.

The game is a child-friendly Godot 4 top-down racer ("Police Escape"). As of the
last update it has: coins/score/win, a 3-level campaign with a difficulty ramp,
and procedural audio + juice (see `CLAUDE.md` for the architecture). This doc is
about what to build **next**, not what exists.

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
   player's 450 top speed — coins 6→9→12).
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

- **This repo's CI/dev containers are headless with no Godot binary.** Assistants
  can design and implement, and the GUT suite runs in CI, but **anything about
  *feel* (juice timing, audio volume, difficulty) needs a human editor play-test**
  — that is the real validation, as it has been for every gameplay PR so far.
- **GUT tests are required** for game-logic changes (`CLAUDE.md` → Testing).
- Prefer the established patterns: signal-driven `GameManager`, data-driven
  `LevelData`, formal state machines, `@export` tunables.

## Suggested first step

A skill-free, high-impact bundle: **difficulty tuning + a `dataviz` difficulty-
curve chart + two juice additions (screen shake on catch, coin sparkle)**. Then,
if `canvas-design` is enabled, follow up with real sprites through the
`custom_texture` hooks.
