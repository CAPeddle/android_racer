extends "res://addons/gut/test.gd"

# Unit tests for the GameManager singleton (scripts/game_manager.gd).
#
# Each test runs against a FRESH instance built from the script resource
# rather than the live `GameManager` autoload, so every test is fully
# isolated from the others and from the running game's state. We construct
# via the preloaded script const to sidestep any ambiguity between the
# autoload singleton name and the `class_name GameManager` global class.

const GAME_MANAGER_SCRIPT := preload("res://scripts/game_manager.gd")

var _gm: GameManager = null


func before_each() -> void:
	_gm = GAME_MANAGER_SCRIPT.new()
	add_child_autofree(_gm)
	watch_signals(_gm)


func test_collect_coin_increments_score_and_emits_score_changed() -> void:
	_gm.set_coin_total(3)
	_gm.collect_coin(null)
	assert_eq(_gm.get_score(), 1, "Score should increment to 1 after one coin")
	assert_signal_emit_count(_gm, "score_changed", 1)
	assert_signal_emitted_with_parameters(_gm, "score_changed", [1])


func test_collecting_all_coins_emits_level_won_once_and_ignores_extra() -> void:
	_gm.set_coin_total(2)
	_gm.collect_coin(null)
	_gm.collect_coin(null)  # last coin -> level_won, state -> RESETTING
	assert_signal_emit_count(_gm, "level_won", 1)
	assert_eq(_gm.get_score(), 2, "Score should be 2 after collecting both coins")
	# A further collect is ignored because the state is now RESETTING.
	_gm.collect_coin(null)
	assert_eq(_gm.get_score(), 2, "Score must not change after the level is won")
	assert_signal_emit_count(_gm, "level_won", 1)
	assert_signal_emit_count(_gm, "score_changed", 2)


func test_collect_coin_is_noop_unless_running() -> void:
	_gm.set_coin_total(3)
	_gm.request_player_caught(null)  # state -> RESETTING
	_gm.collect_coin(null)
	assert_eq(_gm.get_score(), 0, "Coins collected while RESETTING must not score")
	assert_signal_not_emitted(_gm, "score_changed")


func test_request_player_caught_emits_once_even_when_called_twice() -> void:
	_gm.request_player_caught(null)
	_gm.request_player_caught(null)  # guarded by _reset_locked / RESETTING
	assert_signal_emit_count(_gm, "player_caught", 1)
	assert_signal_emit_count(_gm, "reset_requested", 1)


func test_reset_complete_returns_state_to_running() -> void:
	_gm.set_coin_total(3)
	_gm.request_player_caught(null)  # -> RESETTING
	_gm.collect_coin(null)
	assert_eq(_gm.get_score(), 0, "Collecting while RESETTING is ignored")
	_gm.reset_complete()  # -> RUNNING
	_gm.collect_coin(null)
	assert_eq(_gm.get_score(), 1, "Collecting works again after reset_complete")


func test_set_input_locked_emits_only_on_change() -> void:
	_gm.set_input_locked(true)
	_gm.set_input_locked(true)  # same value -> no emission
	assert_signal_emit_count(_gm, "input_lock_changed", 1)
	assert_true(_gm.is_input_locked(), "is_input_locked should reflect the locked state")
	_gm.set_input_locked(false)
	assert_signal_emit_count(_gm, "input_lock_changed", 2)
	assert_false(_gm.is_input_locked())


func test_reset_score_zeroes_score_and_emits_zero() -> void:
	_gm.set_coin_total(5)
	_gm.collect_coin(null)
	_gm.collect_coin(null)
	assert_eq(_gm.get_score(), 2)
	_gm.reset_score()
	assert_eq(_gm.get_score(), 0, "reset_score should zero the score")
	assert_signal_emitted_with_parameters(_gm, "score_changed", [0])


func test_set_game_paused_pauses_and_blocks_collect_after_reset_complete() -> void:
	_gm.set_coin_total(3)
	_gm.set_game_paused(true)
	assert_signal_emit_count(_gm, "game_pause_changed", 1)
	assert_signal_emitted_with_parameters(_gm, "game_pause_changed", [true])
	# reset_complete must keep the PAUSED state, so collecting stays ignored.
	_gm.reset_complete()
	_gm.collect_coin(null)
	assert_eq(_gm.get_score(), 0, "Coins must not score while paused")
	assert_signal_not_emitted(_gm, "score_changed")
