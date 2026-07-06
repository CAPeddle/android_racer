extends "res://addons/gut/test.gd"

# Minimal deterministic test for PlayerCar (scripts/player.gd).
#
# We instantiate the full Player scene (so its Sprite2D child exists and
# _ready() succeeds) and exercise only the pure state-machine path that
# needs no physics frames or a baked Curve2D: drive the car into CRASHING
# via the caught handler, then reset() it back to IDLE and assert the
# resulting state_changed transition.

var _car: PlayerCar = null


func after_each() -> void:
	if is_instance_valid(_car):
		_car.queue_free()
	_car = null


func test_reset_returns_car_to_idle() -> void:
	_car = load("res://scenes/Player.tscn").instantiate()
	add_child_autofree(_car)  # runs _ready()
	watch_signals(_car)

	_car._on_player_caught(_car)  # IDLE -> CRASHING
	_car.reset()                  # CRASHING -> IDLE

	assert_signal_emit_count(_car, "state_changed", 2,
		"Expected CRASHING then IDLE transitions")
	# reset() should leave the car in the IDLE state (last emission).
	assert_signal_emitted_with_parameters(_car, "state_changed",
		[PlayerCar.CarState.IDLE])
