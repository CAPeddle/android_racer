extends "res://addons/gut/test.gd"

# Minimal deterministic test for PoliceCar (scripts/police.gd).
#
# We instantiate the full Police scene (so its DetectionZone and Sprite2D
# children exist and _ready() succeeds) and exercise only the reset() path,
# which needs no physics frames: from IDLE it transitions RESETTING then
# back to IDLE.

var _police: PoliceCar = null


func after_each() -> void:
	if is_instance_valid(_police):
		_police.queue_free()
	_police = null


func test_reset_cycles_through_resetting_back_to_idle() -> void:
	_police = load("res://scenes/Police.tscn").instantiate()
	add_child_autofree(_police)  # runs _ready(); starts in IDLE
	watch_signals(_police)

	_police.reset()  # IDLE -> RESETTING -> IDLE

	assert_signal_emit_count(_police, "state_changed", 2,
		"Expected RESETTING then IDLE transitions")
	# The final state after reset() must be IDLE (last emission).
	assert_signal_emitted_with_parameters(_police, "state_changed",
		[PoliceCar.PoliceState.IDLE])
