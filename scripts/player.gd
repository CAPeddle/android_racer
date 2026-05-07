extends CharacterBody2D
class_name PlayerCar

signal state_changed(state: int)

enum CarState {
	IDLE,
	ACCELERATING,
	BRAKING,
	CRASHING,
}

@export var max_speed: float = 450.0
@export var acceleration: float = 350.0
@export var brake_force: float = 600.0
@export var look_ahead_distance: float = 180.0
@export var steering_update_interval: float = 0.05
@export var custom_texture: Texture2D

var _path: Path2D = null
var _curve: Curve2D = null
var _curve_length: float = 0.0
var _speed: float = 0.0
var _state: CarState = CarState.IDLE
var _is_pressing: bool = false
var _steer_target_global: Vector2 = Vector2.ZERO
var _steer_timer: float = 0.0
var _input_locked: bool = false

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	if not GameManager.input_lock_changed.is_connected(_on_input_lock_changed):
		GameManager.input_lock_changed.connect(_on_input_lock_changed)
	if not GameManager.player_caught.is_connected(_on_player_caught):
		GameManager.player_caught.connect(_on_player_caught)
	_apply_sprite_texture()


func setup(road_path: Path2D) -> void:
	_path = road_path
	if not is_instance_valid(_path):
		push_warning("PlayerCar.setup called with invalid Path2D")
		return
	_curve = _path.curve
	if _curve == null:
		push_warning("PlayerCar.setup found null curve")
		return
	_curve_length = _curve.get_baked_length()
	_steer_target_global = global_position


func reset() -> void:
	_speed = 0.0
	_is_pressing = false
	_set_state(CarState.IDLE)
	velocity = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if _state == CarState.CRASHING or _input_locked:
		_is_pressing = false
		return
	if event is InputEventScreenTouch:
		_is_pressing = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_is_pressing = event.pressed


func _physics_process(delta: float) -> void:
	if _curve == null or _curve_length <= 0.0:
		return
	if _state == CarState.CRASHING:
		_speed = maxf(_speed - brake_force * delta * 1.5, 0.0)
	else:
		if _is_pressing and not _input_locked:
			_speed = minf(_speed + acceleration * delta, max_speed)
		else:
			_speed = maxf(_speed - brake_force * delta, 0.0)

	_update_state_from_input()
	if _speed < 1.0:
		velocity = Vector2.ZERO
		return

	_steer_timer += delta
	if _steer_timer >= steering_update_interval:
		_steer_timer = 0.0
		_update_steer_target()

	var steer_dir: Vector2 = (_steer_target_global - global_position).normalized()
	velocity = steer_dir * _speed
	move_and_slide()
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()


func _update_steer_target() -> void:
	var local_pos: Vector2 = _path.to_local(global_position)
	var closest_offset: float = _curve.get_closest_offset(local_pos)
	var look_offset: float = fmod(closest_offset + look_ahead_distance, _curve_length)
	var target_local: Vector2 = _curve.sample_baked(look_offset)
	_steer_target_global = _path.to_global(target_local)


func _update_state_from_input() -> void:
	if _state == CarState.CRASHING:
		return
	if _speed < 1.0:
		_set_state(CarState.IDLE)
	elif _is_pressing and not _input_locked:
		_set_state(CarState.ACCELERATING)
	else:
		_set_state(CarState.BRAKING)


func _set_state(next_state: CarState) -> void:
	if _state == next_state:
		return
	_state = next_state
	GameManager.report_player_state(int(_state))
	state_changed.emit(int(_state))


func _on_player_caught(_source: Node) -> void:
	_set_state(CarState.CRASHING)
	_is_pressing = false


func _on_input_lock_changed(is_locked: bool) -> void:
	_input_locked = is_locked
	if is_locked:
		_is_pressing = false


func _apply_sprite_texture() -> void:
	if custom_texture != null:
		sprite.texture = custom_texture
		sprite.modulate = Color.WHITE
		return
	sprite.texture = _create_placeholder_texture(Color(0.1, 0.28, 0.9, 1.0))
	sprite.modulate = Color.WHITE


func _create_placeholder_texture(color: Color) -> Texture2D:
	var image: Image = Image.create(64, 128, false, Image.FORMAT_RGBA8)
	image.fill(color)
	var generated_texture: ImageTexture = ImageTexture.create_from_image(image)
	if generated_texture != null:
		return generated_texture
	var fallback_texture := PlaceholderTexture2D.new()
	fallback_texture.size = Vector2(64, 128)
	return fallback_texture
