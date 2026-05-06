extends Node2D
class_name GameScene

const ROAD_COLOR: Color = Color(0.42, 0.42, 0.42, 1.0)
const GRASS_COLOR: Color = Color(0.18, 0.50, 0.14, 1.0)
const RESET_COOLDOWN_SECONDS: float = 0.35
const TRACK_SAMPLE_STEP: float = 12.0
const DEFAULT_LEVEL: LevelData = preload("res://levels/level_01.tres")

@export var level_data: LevelData = DEFAULT_LEVEL
@export var police_scene: PackedScene = preload("res://scenes/Police.tscn")

var _police_list: Array[PoliceCar] = []
var _last_reset_press_msec: int = -1000
var _road_visual: Line2D

@onready var _path: Path2D = $Road
@onready var _player: PlayerCar = $Player
@onready var _police_container: Node2D = $PoliceContainer
@onready var _ui_layer: CanvasLayer = $UI
@onready var _reset_button: Button = $UI/ResetButton
@onready var _caught_label: Label = $UI/CaughtLabel
@onready var _paused_label: Label = $UI/PausedLabel


func _ready() -> void:
	_connect_signals()
	_setup_background()
	_style_ui()
	_setup_level_data()
	_setup_player()
	_spawn_police()
	GameManager.reset_complete()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		GameManager.set_game_paused(true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		GameManager.set_game_paused(false)


func _connect_signals() -> void:
	GameManager.reset_requested.connect(_on_reset_requested)
	GameManager.player_caught.connect(_on_player_caught)
	GameManager.game_pause_changed.connect(_on_game_pause_changed)
	_reset_button.button_down.connect(_on_reset_button_down)
	_reset_button.button_up.connect(_on_reset_button_up)
	_reset_button.pressed.connect(_on_reset_button_pressed)
	_ui_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_reset_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _setup_level_data() -> void:
	var data: LevelData = level_data if level_data != null else DEFAULT_LEVEL
	if data.road_points.size() < 4:
		push_warning("LevelData requires at least 4 road points; using defaults")
		data = DEFAULT_LEVEL
	_build_road(data)


func _build_road(data: LevelData) -> void:
	var curve: Curve2D = _path.curve
	curve.clear_points()
	var points: PackedVector2Array = data.road_points
	var point_count: int = points.size()
	for index: int in range(point_count):
		var prev: Vector2 = points[(index - 1 + point_count) % point_count]
		var next: Vector2 = points[(index + 1) % point_count]
		var tangent: Vector2 = (next - prev) * data.tangent_scale
		curve.add_point(points[index], -tangent, tangent)
	_redraw_road(data.road_width)


func _redraw_road(width: float) -> void:
	if is_instance_valid(_road_visual):
		_road_visual.queue_free()
	_road_visual = Line2D.new()
	_road_visual.width = width
	_road_visual.default_color = ROAD_COLOR
	_road_visual.joint_mode = Line2D.LINE_JOINT_ROUND
	_road_visual.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_road_visual.end_cap_mode = Line2D.LINE_CAP_ROUND
	var baked_length: float = _path.curve.get_baked_length()
	var offset: float = 0.0
	while offset <= baked_length:
		_road_visual.add_point(_path.curve.sample_baked(offset))
		offset += TRACK_SAMPLE_STEP
	_road_visual.add_point(_path.curve.sample_baked(0.0))
	add_child(_road_visual)
	move_child(_road_visual, 1)


func _setup_background() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = GRASS_COLOR
	bg.size = Vector2(2000, 1200)
	add_child(bg)
	move_child(bg, 0)


func _setup_player() -> void:
	_player.add_to_group("player")
	_player.setup(_path)
	_player.global_position = _path.to_global(_path.curve.sample_baked(0.0))
	_player.reset()


func _spawn_police() -> void:
	for existing_police: PoliceCar in _police_list:
		if is_instance_valid(existing_police):
			existing_police.queue_free()
	_police_list.clear()
	var baked_length: float = _path.curve.get_baked_length()
	var data: LevelData = level_data if level_data != null else DEFAULT_LEVEL
	for spawn_fraction: float in data.police_spawn_fractions:
		var offset: float = baked_length * clampf(spawn_fraction, 0.0, 0.99)
		var police: PoliceCar = police_scene.instantiate() as PoliceCar
		if police == null:
			continue
		_police_container.add_child(police)
		police.global_position = _path.to_global(_path.curve.sample_baked(offset))
		_police_list.append(police)


func _style_ui() -> void:
	var normal_style: StyleBoxFlat = StyleBoxFlat.new()
	normal_style.bg_color = Color(0.85, 0.15, 0.15, 1.0)
	normal_style.corner_radius_top_left = 12
	normal_style.corner_radius_top_right = 12
	normal_style.corner_radius_bottom_left = 12
	normal_style.corner_radius_bottom_right = 12
	var hover_style: StyleBoxFlat = normal_style.duplicate()
	hover_style.bg_color = Color(1.0, 0.25, 0.25, 1.0)
	_reset_button.add_theme_stylebox_override("normal", normal_style)
	_reset_button.add_theme_stylebox_override("hover", hover_style)
	_reset_button.add_theme_stylebox_override("pressed", hover_style)
	_reset_button.add_theme_font_size_override("font_size", 42)
	_reset_button.add_theme_color_override("font_color", Color.WHITE)
	_caught_label.add_theme_font_size_override("font_size", 72)
	_caught_label.add_theme_color_override("font_color", Color(1.0, 0.15, 0.15, 1.0))
	_paused_label.add_theme_font_size_override("font_size", 54)
	_paused_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))


func _on_reset_requested(reason: StringName) -> void:
	if reason == &"caught":
		_show_caught_then_reset()
	else:
		reset_level()


func _on_player_caught(_source: Node) -> void:
	GameManager.set_input_locked(true)


func _show_caught_then_reset() -> void:
	_caught_label.visible = true
	await get_tree().create_timer(1.0).timeout
	reset_level()


func reset_level() -> void:
	_player.global_position = _path.to_global(_path.curve.sample_baked(0.0))
	_player.reset()
	for police: PoliceCar in _police_list:
		if is_instance_valid(police):
			police.reset()
	_caught_label.visible = false
	GameManager.set_input_locked(get_tree().paused)
	GameManager.reset_complete()


func _on_game_pause_changed(is_paused: bool) -> void:
	get_tree().paused = is_paused
	_paused_label.visible = is_paused
	if is_paused:
		GameManager.set_input_locked(true)
	else:
		GameManager.set_input_locked(false)


func _on_reset_button_down() -> void:
	GameManager.set_input_locked(true)


func _on_reset_button_up() -> void:
	if not get_tree().paused:
		GameManager.set_input_locked(false)


func _on_reset_button_pressed() -> void:
	var now_msec: int = Time.get_ticks_msec()
	if (now_msec - _last_reset_press_msec) < int(RESET_COOLDOWN_SECONDS * 1000.0):
		return
	_last_reset_press_msec = now_msec
	GameManager.request_reset(&"manual")
