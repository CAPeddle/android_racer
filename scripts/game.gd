extends Node2D

## Main game scene script.
##
## Responsibilities:
##   • Build the winding road (Path2D curve + Line2D visual).
##   • Spawn the Player at the path start.
##   • Spawn Police cars at evenly-spaced offsets along the path.
##   • Wire the Reset button.
##   • Implement reset_level() called by GameManager.

const ROAD_WIDTH: float = 90.0
const ROAD_COLOR: Color = Color(0.42, 0.42, 0.42, 1.0)
const GRASS_COLOR: Color = Color(0.18, 0.50, 0.14, 1.0)
const POLICE_COUNT: int = 4

var _police_scene: PackedScene = preload("res://scenes/Police.tscn")
var _police_list: Array[Area2D] = []
var _is_caught: bool = false

@onready var _path: Path2D = $Road
@onready var _player = $Player
@onready var _police_container: Node2D = $PoliceContainer
@onready var _reset_btn: Button = $UI/ResetButton
@onready var _caught_label: Label = $UI/CaughtLabel


func _ready() -> void:
	GameManager.register_game(self)
	_reset_btn.pressed.connect(reset_level)
	_style_reset_button()
	_setup_background()
	_setup_road()
	_setup_player()
	_spawn_police()


# ─── Road ────────────────────────────────────────────────────────────────────

func _setup_road() -> void:
	var curve: Curve2D = _path.curve

	# Control-points for a smooth, looping oval track that fills the 2000×1200
	# viewport.  Catmull-Rom tangents are computed automatically from neighbours.
	var pts: Array[Vector2] = [
		Vector2(200,  600),
		Vector2(350,  220),
		Vector2(700,   90),
		Vector2(1000, 130),
		Vector2(1300,  90),
		Vector2(1650, 220),
		Vector2(1800, 600),
		Vector2(1650, 980),
		Vector2(1300, 1110),
		Vector2(1000, 1070),
		Vector2(700,  1110),
		Vector2(350,  980),
	]

	var n: int = pts.size()
	for i: int in range(n):
		var prev: Vector2 = pts[(i - 1 + n) % n]
		var next: Vector2 = pts[(i + 1) % n]
		var tangent: Vector2 = (next - prev) * 0.28
		curve.add_point(pts[i], -tangent, tangent)

	# Draw the road surface using a thick Line2D (drawn behind everything).
	var line: Line2D = Line2D.new()
	line.width = ROAD_WIDTH
	line.default_color = ROAD_COLOR
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND

	var baked_len: float = curve.get_baked_length()
	var step: float = 12.0
	var t: float = 0.0
	while t <= baked_len:
		line.add_point(curve.sample_baked(t))
		t += step
	# Close the visual loop.
	line.add_point(curve.sample_baked(0.0))

	add_child(line)
	# Road sits above the background but below cars.
	move_child(line, 1)


# ─── Background ──────────────────────────────────────────────────────────────

func _setup_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = GRASS_COLOR
	bg.size = Vector2(2000, 1200)
	add_child(bg)
	move_child(bg, 0)  # Draw first → behind everything.


# ─── Player ──────────────────────────────────────────────────────────────────

func _setup_player() -> void:
	_player.add_to_group("player")
	_player.setup(_path)
	var start_pos: Vector2 = _path.to_global(_path.curve.sample_baked(0.0))
	_player.global_position = start_pos


# ─── Police ──────────────────────────────────────────────────────────────────

func _spawn_police() -> void:
	var baked_len: float = _path.curve.get_baked_length()
	# Distribute police evenly around the track, offset so none is at the
	# player's start (offset 0).
	for i: int in range(POLICE_COUNT):
		var frac: float = (float(i) + 0.5) / float(POLICE_COUNT)
		var offset: float = baked_len * frac
		var pos: Vector2 = _path.to_global(_path.curve.sample_baked(offset))

		var police: Area2D = _police_scene.instantiate()
		_police_container.add_child(police)
		police.global_position = pos
		_police_list.append(police)


# ─── UI ──────────────────────────────────────────────────────────────────────

func _style_reset_button() -> void:
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.85, 0.15, 0.15, 1.0)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12

	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(1.0, 0.25, 0.25, 1.0)

	_reset_btn.add_theme_stylebox_override("normal", normal_style)
	_reset_btn.add_theme_stylebox_override("hover", hover_style)
	_reset_btn.add_theme_stylebox_override("pressed", hover_style)
	_reset_btn.add_theme_font_size_override("font_size", 42)
	_reset_btn.add_theme_color_override("font_color", Color(1, 1, 1, 1))

	# Style the caught label.
	_caught_label.add_theme_font_size_override("font_size", 72)
	_caught_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))


# ─── Reset ───────────────────────────────────────────────────────────────────

func on_player_caught() -> void:
	if _is_caught:
		return
	_is_caught = true
	_caught_label.visible = true
	# Brief pause so the child can see the "caught" message before the reset.
	await get_tree().create_timer(1.0).timeout
	reset_level()


func reset_level() -> void:
	_is_caught = false
	# Snap player back to path start.
	var start_pos: Vector2 = _path.to_global(_path.curve.sample_baked(0.0))
	_player.global_position = start_pos
	_player.reset()

	# Return all police to their spawn positions.
	for p: Area2D in _police_list:
		p.reset()

	_caught_label.visible = false
