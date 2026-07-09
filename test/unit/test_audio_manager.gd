extends "res://addons/gut/test.gd"

# Unit tests for AudioManager's pure decision helpers (scripts/audio_manager.gd).
# We build a bare instance WITHOUT adding it to the tree, so _ready() does not
# run — no players, no signal connections, no audio side effects — leaving just
# the pure state helpers (should_ding, set_pursuit, is_siren_active) to test.

const AUDIO_SCRIPT := preload("res://scripts/audio_manager.gd")

var _am = null


func before_each() -> void:
	_am = AUDIO_SCRIPT.new()


func after_each() -> void:
	if _am != null:
		_am.free()
	_am = null


func test_should_ding_only_when_score_increases() -> void:
	assert_true(_am.should_ding(1), "First coin should ding")
	assert_false(_am.should_ding(1), "No ding when the score is unchanged")
	assert_true(_am.should_ding(2), "A higher score should ding")
	assert_false(_am.should_ding(0), "A score reset must not ding")


func test_siren_active_while_any_police_chases() -> void:
	var a: Node = Node.new()
	var b: Node = Node.new()
	assert_false(_am.is_siren_active(), "Silent with no pursuers")
	_am.set_pursuit(a, true)
	assert_true(_am.is_siren_active())
	_am.set_pursuit(b, true)
	assert_true(_am.is_siren_active())
	_am.set_pursuit(a, false)
	assert_true(_am.is_siren_active(), "Still chasing via b")
	_am.set_pursuit(b, false)
	assert_false(_am.is_siren_active(), "Silent once all pursuers disengage")
	a.free()
	b.free()


func test_set_pursuit_is_idempotent_per_police() -> void:
	var a: Node = Node.new()
	_am.set_pursuit(a, true)
	_am.set_pursuit(a, true)  # same car reported twice
	_am.set_pursuit(a, false)
	assert_false(_am.is_siren_active(), "One disengage clears one car")
	a.free()
