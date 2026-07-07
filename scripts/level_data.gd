extends Resource
class_name LevelData

## Human-facing name shown in the UI (e.g. "Level 2"). Falls back to
## "LEVEL <n>" when left blank.
@export var level_name: String = ""
@export var road_points: PackedVector2Array = PackedVector2Array([
	Vector2(200, 600),
	Vector2(350, 220),
	Vector2(700, 90),
	Vector2(1000, 130),
	Vector2(1300, 90),
	Vector2(1650, 220),
	Vector2(1800, 600),
	Vector2(1650, 980),
	Vector2(1300, 1110),
	Vector2(1000, 1070),
	Vector2(700, 1110),
	Vector2(350, 980),
])
@export var tangent_scale: float = 0.28
@export var road_width: float = 90.0
@export var police_spawn_fractions: PackedFloat32Array = PackedFloat32Array([0.125, 0.375, 0.625, 0.875])
@export var coin_fractions: PackedFloat32Array = PackedFloat32Array([0.06, 0.19, 0.31, 0.44, 0.56, 0.69, 0.81, 0.94])
## Per-level police chase speed. 0.0 means "use the Police scene's own
## default" — set a higher value on later levels to ramp difficulty.
@export var police_speed: float = 0.0
