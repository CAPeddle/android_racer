extends Node2D
class_name GameScene

const ROAD_COLOR: Color = Color(0.42, 0.42, 0.42, 1.0)
const GRASS_COLOR: Color = Color(0.18, 0.50, 0.14, 1.0)
const RESET_COOLDOWN_SECONDS: float = 0.35
const TRACK_SAMPLE_STEP: float = 12.0
const DEFAULT_LEVEL: LevelData = preload("res://levels/level_01.tres")
# The built-in campaign, played in order. Clearing a level advances to the
# next; clearing the last loops back to the first (see GameManager).
const LEVELS: Array = [
	preload("res://levels/level_01.tres"),
	preload("res://levels/level_02.tres"),
	preload("res://levels/level_03.tres"),
]

## Optional override for the campaign. Leave empty to use the built-in LEVELS.
@export var levels: Array[LevelData] = []
@export var police_scene: PackedScene = preload("res://scenes/Police.tscn")
@export var coin_scene: PackedScene = preload("res://scenes/Coin.tscn")

var _police_list: Array[PoliceCar] = []
var _coin_list: Array[Coin] = []
var _last_reset_press_msec: int = -1000
var _road_visual: Line2D

@onready var _path: Path2D = $Road
@onready var _player: PlayerCar = $Player
@onready var _police_container: Node2D = $PoliceContainer
@onready var _coin_container: Node2D = $CoinContainer
@onready var _ui_layer: CanvasLayer = $UI
@onready var _reset_button: Button = $UI/ResetButton
@onready var _caught_label: Label = $UI/CaughtLabel
@onready var _paused_label: Label = $UI/PausedLabel
@onready var _win_label: Label = $UI/WinLabel
@onready var _score_label: Label = $UI/ScoreLabel
@onready var _level_label: Label = $UI/LevelLabel
@onready var _flash: ColorRect = $UI/FlashRect


func _ready() -> void:
	_connect_signals()
	_setup_background()
	_style_ui()
	GameManager.set_level_count(_campaign().size())
	_load_level(GameManager.get_level_index())
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
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.level_won.connect(_on_level_won)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.campaign_complete.connect(_on_campaign_complete)
	_reset_button.button_down.connect(_on_reset_button_down)
	_reset_button.button_up.connect(_on_reset_button_up)
	_reset_button.pressed.connect(_on_reset_button_pressed)
	_ui_layer.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	_reset_button.process_mode = Node.PROCESS_MODE_WHEN_PAUSED


func _campaign() -> Array:
	return levels if not levels.is_empty() else LEVELS


func _level_at(index: int) -> LevelData:
	var list: Array = _campaign()
	if list.is_empty():
		return DEFAULT_LEVEL
	var i: int = clampi(index, 0, list.size() - 1)
	var data: LevelData = list[i]
	if data == null or data.road_points.size() < 4:
		push_warning("LevelData at index %d is invalid; using defaults" % i)
		return DEFAULT_LEVEL
	return data


func _level_display_name(index: int) -> String:
	var data: LevelData = _level_at(index)
	if not data.level_name.is_empty():
		return data.level_name
	return "LEVEL %d" % (index + 1)


# Builds a level end to end: road, player placement, police, coins, score and
# UI labels. Used on startup, on every level change, and on caught/manual
# resets, so there is a single path for putting the world into a fresh state.
func _load_level(index: int) -> void:
	var data: LevelData = _level_at(index)
	_build_road(data)
	_setup_player()
	_spawn_police(data)
	_spawn_coins(data)
	GameManager.reset_score()
	_level_label.text = _level_display_name(index)
	_caught_label.visible = false
	_win_label.visible = false


func _build_road(data: LevelData) -> void:
	var curve: Curve2D = _path.curve
	if curve == null:
		# A Path2D placed in the scene without points has a null curve; create
		# one so the road can be built (and rebuilt on every level change).
		curve = Curve2D.new()
		_path.curve = curve
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


func _spawn_police(data: LevelData) -> void:
	for existing_police: PoliceCar in _police_list:
		if is_instance_valid(existing_police):
			existing_police.queue_free()
	_police_list.clear()
	var baked_length: float = _path.curve.get_baked_length()
	for spawn_fraction: float in data.police_spawn_fractions:
		var offset: float = baked_length * clampf(spawn_fraction, 0.0, 0.99)
		var police: PoliceCar = police_scene.instantiate() as PoliceCar
		if police == null:
			continue
		_police_container.add_child(police)
		police.global_position = _path.to_global(_path.curve.sample_baked(offset))
		if data.police_speed > 0.0:
			police.chase_speed = data.police_speed
		_police_list.append(police)


func _spawn_coins(data: LevelData) -> void:
	for existing_coin: Coin in _coin_list:
		if is_instance_valid(existing_coin):
			existing_coin.queue_free()
	_coin_list.clear()
	var baked_length: float = _path.curve.get_baked_length()
	for coin_fraction: float in data.coin_fractions:
		var offset: float = baked_length * clampf(coin_fraction, 0.0, 0.99)
		var coin: Coin = coin_scene.instantiate() as Coin
		if coin == null:
			continue
		_coin_container.add_child(coin)
		coin.global_position = _path.to_global(_path.curve.sample_baked(offset))
		_coin_list.append(coin)
	GameManager.set_coin_total(_coin_list.size())


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
	_score_label.add_theme_font_size_override("font_size", 44)
	_score_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4, 1.0))
	_win_label.add_theme_font_size_override("font_size", 80)
	_win_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
	_level_label.add_theme_font_size_override("font_size", 44)
	_level_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))


func _on_reset_requested(reason: StringName) -> void:
	if reason == &"caught":
		_show_caught_then_reset()
	else:
		reset_level()


func _on_player_caught(_source: Node) -> void:
	GameManager.set_input_locked(true)
	_flash_screen()


# Juice: a red full-screen flash that fades out when the player is caught.
func _flash_screen() -> void:
	_flash.color = Color(1.0, 0.15, 0.15, 0.55)
	var tween: Tween = create_tween()
	tween.tween_property(_flash, "color:a", 0.0, 0.45)


func _show_caught_then_reset() -> void:
	_caught_label.visible = true
	await get_tree().create_timer(1.0).timeout
	reset_level()


func reset_level() -> void:
	# Getting caught (or a manual reset) restarts the CURRENT level, keeping
	# the player's campaign progress.
	_load_level(GameManager.get_level_index())
	GameManager.set_input_locked(get_tree().paused)
	GameManager.reset_complete()


func _on_score_changed(score: int) -> void:
	_score_label.text = "SCORE: %d" % score


func _on_level_won() -> void:
	# All coins collected: celebrate the clear, then ask GameManager to
	# advance (which fires level_changed or campaign_complete).
	GameManager.set_input_locked(true)
	_win_label.text = "%s CLEAR!" % _level_display_name(GameManager.get_level_index())
	_win_label.visible = true
	await get_tree().create_timer(1.5).timeout
	_win_label.visible = false
	GameManager.advance_level()


func _on_level_changed(index: int) -> void:
	_load_level(index)
	GameManager.set_input_locked(get_tree().paused)
	GameManager.reset_complete()


func _on_campaign_complete() -> void:
	# Final level cleared: big celebration, then loop back to the first level.
	GameManager.set_input_locked(true)
	_win_label.text = "YOU BEAT THE GAME!"
	_win_label.visible = true
	await get_tree().create_timer(2.5).timeout
	_win_label.visible = false
	GameManager.restart_campaign()


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
