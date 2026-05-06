extends CharacterBody2D

## One-touch path-following player car.
##
## – Press/hold the screen  → accelerate.
## – Release               → brake and coast to a stop.
## – Steering uses a "look-ahead" point sampled from the road Path2D so the
##   car naturally feels the pull of corners at high speed.

const MAX_SPEED: float = 450.0
const ACCELERATION: float = 350.0
const BRAKE_FORCE: float = 600.0
const LOOK_AHEAD_DIST: float = 180.0

var _speed: float = 0.0
var _pressing: bool = false
var _path: Path2D = null


func setup(road_path: Path2D) -> void:
	_path = road_path


func reset() -> void:
	_speed = 0.0
	_pressing = false
	velocity = Vector2.ZERO


## Use _unhandled_input so UI buttons (Reset) consume their events first
## and do not accidentally accelerate the car.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_pressing = event.pressed
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressing = event.pressed


func _physics_process(delta: float) -> void:
	if not _path:
		return

	var curve: Curve2D = _path.curve

	# Accelerate or brake depending on touch state.
	if _pressing:
		_speed = minf(_speed + ACCELERATION * delta, MAX_SPEED)
	else:
		_speed = maxf(_speed - BRAKE_FORCE * delta, 0.0)

	if _speed < 1.0:
		velocity = Vector2.ZERO
		return

	# Convert to the Path2D's local space for curve sampling.
	var local_pos: Vector2 = _path.to_local(global_position)
	var closest_offset: float = curve.get_closest_offset(local_pos)

	# Sample a look-ahead point and wrap it for a looping track.
	var baked_length: float = curve.get_baked_length()
	var look_offset: float = fmod(closest_offset + LOOK_AHEAD_DIST, baked_length)

	var target_local: Vector2 = curve.sample_baked(look_offset)
	var target_global: Vector2 = _path.to_global(target_local)

	# Steer directly towards the look-ahead point.
	var steer_dir: Vector2 = (target_global - global_position).normalized()
	velocity = steer_dir * _speed

	move_and_slide()

	# Rotate car sprite to face the movement direction.
	if velocity.length_squared() > 1.0:
		rotation = velocity.angle()
