extends Node
class_name GameManager

signal reset_requested(reason: StringName)
signal player_caught(source: Node)
signal game_pause_changed(is_paused: bool)
signal player_state_changed(state: int)
signal police_state_changed(police: Node, state: int)
signal input_lock_changed(is_locked: bool)

enum GameState {
	RUNNING,
	PAUSED,
	RESETTING,
}

var _state: GameState = GameState.RUNNING
var _input_locked: bool = false
var _reset_locked: bool = false


func request_player_caught(source: Node) -> void:
	if _reset_locked:
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
