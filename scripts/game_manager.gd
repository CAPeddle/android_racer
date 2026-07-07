extends Node

# NOTE: This script is registered as the `GameManager` autoload in
# project.godot, which already exposes it globally as `GameManager`. It must
# NOT also declare `class_name GameManager` — in Godot 4 a class_name that
# matches an autoload name collides ("hides an autoload singleton") and fails
# to parse, cascading a parse error into every script that calls GameManager.

signal reset_requested(reason: StringName)
signal player_caught(source: Node)
signal game_pause_changed(is_paused: bool)
signal player_state_changed(state: int)
signal police_state_changed(police: Node, state: int)
signal input_lock_changed(is_locked: bool)
signal score_changed(score: int)
signal level_won()
signal level_changed(index: int)
signal campaign_complete()

enum GameState {
	RUNNING,
	PAUSED,
	RESETTING,
}

var _state: GameState = GameState.RUNNING
var _input_locked: bool = false
var _reset_locked: bool = false
var _score: int = 0
var _coins_total: int = 0
var _coins_collected: int = 0
var _level_index: int = 0
var _level_count: int = 1


func request_player_caught(source: Node) -> void:
	if _reset_locked or _state == GameState.RESETTING:
		return
	_reset_locked = true
	_state = GameState.RESETTING
	player_caught.emit(source)
	reset_requested.emit(&"caught")


func request_reset(reason: StringName = &"manual") -> void:
	if _state != GameState.RESETTING:
		_state = GameState.RESETTING
	reset_requested.emit(reason)


func reset_complete() -> void:
	_reset_locked = false
	if _state != GameState.PAUSED:
		_state = GameState.RUNNING


func set_game_paused(is_paused: bool) -> void:
	_state = GameState.PAUSED if is_paused else GameState.RUNNING
	game_pause_changed.emit(is_paused)


func set_input_locked(is_locked: bool) -> void:
	if _input_locked == is_locked:
		return
	_input_locked = is_locked
	input_lock_changed.emit(is_locked)


func is_input_locked() -> bool:
	return _input_locked


func report_player_state(state: int) -> void:
	player_state_changed.emit(state)


func report_police_state(police: Node, state: int) -> void:
	police_state_changed.emit(police, state)


func set_coin_total(count: int) -> void:
	_coins_total = maxi(count, 0)
	_coins_collected = 0


func collect_coin(_coin: Node) -> void:
	if _state != GameState.RUNNING:
		return
	_score += 1
	_coins_collected += 1
	score_changed.emit(_score)
	if _coins_total > 0 and _coins_collected >= _coins_total:
		_state = GameState.RESETTING
		level_won.emit()


func reset_score() -> void:
	_score = 0
	_coins_collected = 0
	score_changed.emit(_score)


func get_score() -> int:
	return _score


# --- Level progression ---------------------------------------------------
# GameManager owns the campaign cursor (which level is current and how many
# there are). GameScene reports the count at startup and reacts to the
# level_changed / campaign_complete signals; the pure counter logic lives
# here so it stays testable.

func set_level_count(count: int) -> void:
	_level_count = maxi(count, 1)
	_level_index = clampi(_level_index, 0, _level_count - 1)


func get_level_index() -> int:
	return _level_index


func get_level_count() -> int:
	return _level_count


func advance_level() -> void:
	# Called after a level is won. Advances to the next level, or reports the
	# campaign finished once the final level is cleared.
	if _level_index + 1 < _level_count:
		_level_index += 1
		level_changed.emit(_level_index)
	else:
		campaign_complete.emit()


func restart_campaign() -> void:
	_level_index = 0
	level_changed.emit(_level_index)
