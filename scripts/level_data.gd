extends Resource
class_name LevelData

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
