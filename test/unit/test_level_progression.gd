extends "res://addons/gut/test.gd"

# Unit tests for GameManager's level-progression cursor (advance_level,
# restart_campaign, set_level_count). As with test_game_manager.gd we build a
# fresh, isolated instance from the script resource per test. The var is
# intentionally untyped: the script is an autoload (no class_name), so
# `GameManager` is not usable as a static type here.

const GAME_MANAGER_SCRIPT := preload("res://scripts/game_manager.gd")

var _gm = null


func before_each() -> void:
	_gm = GAME_MANAGER_SCRIPT.new()
	add_child_autofree(_gm)
	watch_signals(_gm)


func test_advance_level_emits_level_changed_with_next_index() -> void:
	_gm.set_level_count(3)
	_gm.advance_level()
	assert_eq(_gm.get_level_index(), 1, "Index should advance to 1")
	assert_signal_emit_count(_gm, "level_changed", 1)
	assert_signal_emitted_with_parameters(_gm, "level_changed", [1])
	assert_signal_not_emitted(_gm, "campaign_complete")


func test_advancing_past_last_level_completes_campaign() -> void:
	_gm.set_level_count(2)
	_gm.advance_level()  # 0 -> 1 (last level)
	_gm.advance_level()  # past last -> campaign_complete
	assert_eq(_gm.get_level_index(), 1, "Index must not advance past the last level")
	assert_signal_emit_count(_gm, "level_changed", 1)
	assert_signal_emit_count(_gm, "campaign_complete", 1)


func test_single_level_campaign_completes_immediately() -> void:
	_gm.set_level_count(1)
	_gm.advance_level()
	assert_signal_emit_count(_gm, "campaign_complete", 1)
	assert_signal_not_emitted(_gm, "level_changed")
	assert_eq(_gm.get_level_index(), 0)


func test_restart_campaign_resets_to_first_level() -> void:
	_gm.set_level_count(3)
	_gm.advance_level()  # -> 1
	_gm.advance_level()  # -> 2
	assert_eq(_gm.get_level_index(), 2)
	_gm.restart_campaign()
	assert_eq(_gm.get_level_index(), 0, "restart_campaign should return to level 0")
	assert_signal_emitted_with_parameters(_gm, "level_changed", [0])


func test_set_level_count_clamps_current_index_and_minimum() -> void:
	_gm.set_level_count(3)
	_gm.advance_level()  # -> 1
	_gm.advance_level()  # -> 2
	_gm.set_level_count(2)  # only 2 levels now; index must clamp to 1
	assert_eq(_gm.get_level_index(), 1, "Index should clamp into the new range")
	assert_eq(_gm.get_level_count(), 2)
	_gm.set_level_count(0)  # count is floored at 1
	assert_eq(_gm.get_level_count(), 1)
	assert_eq(_gm.get_level_index(), 0, "Index should clamp to 0 for a 1-level campaign")
