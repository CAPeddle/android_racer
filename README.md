# android_racer
A simple ad free side loadable Racer for my boy

## Architecture notes (production hardening)

- Gameplay flow is signal-driven through `GameManager` (`reset_requested`, `player_caught`, `input_lock_changed`, pause/state signals).
- `PlayerCar` uses a formal state machine: `IDLE`, `ACCELERATING`, `BRAKING`, `CRASHING`.
- `PoliceCar` uses a formal state machine: `IDLE`, `ALERT`, `CHASING`, `RESETTING`.
- Level setup is data-driven via `LevelData` resources (`levels/level_01.tres`) for road points and police spawn fractions.

## Testing strategy (Godot + GUT)

To make movement and AI logic production-ready, add [GUT](https://github.com/bitwes/Gut) and create focused unit tests around pure transitions:

1. **Player state transitions**
   - Given touch down/up events, assert state path `IDLE -> ACCELERATING -> BRAKING -> IDLE`.
   - On `player_caught`, assert `CRASHING` and input lock behavior.
2. **Player steering**
   - For known curve points, assert look-ahead sampling wraps correctly at track end.
   - Assert speed clamps to `[0, max_speed]`.
3. **Police transitions**
   - Assert `IDLE -> ALERT -> CHASING` only after `alert_duration`.
   - Assert reset path enters `RESETTING` then `IDLE`.
4. **GameManager orchestration**
   - Assert caught events lock reset and emit exactly one `reset_requested`.
   - Assert pause/resume emits `game_pause_changed` and input lock toggles.
