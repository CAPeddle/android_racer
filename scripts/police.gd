extends Area2D
class_name PoliceCar

signal state_changed(state: int)

enum PoliceState {
	IDLE,
	ALERT,
	CHASING,
	RESETTING,
}

@export var chase_speed: float = 300.0
@export var alert_duration: float = 0.25

var _state: PoliceState = PoliceState.IDLE
var _tracked_player: Node2D = null
var _start_position: Vector2
var _alert_timer: float = 0.0

@onready var _detection_zone: Area2D = $DetectionZone
@onready var _car_body: Polygon2D = $CarBody


func _ready() -> void:
	_start_position = global_position
	_detection_zone.body_entered.connect(_on_detection_entered)
	_detection_zone.body_exited.connect(_on_detection_exited)
	body_entered.connect(_on_body_entered)
	_apply_state_visual()


func _physics_process(delta: float) -> void:
	if _state == PoliceState.ALERT:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			if is_instance_valid(_tracked_player):
				_set_state(PoliceState.CHASING)
			else:
				_set_state(PoliceState.IDLE)
	elif _state == PoliceState.CHASING:
		if not is_instance_valid(_tracked_player):
			_set_state(PoliceState.IDLE)
			return
		var dir: Vector2 = (_tracked_player.global_position - global_position).normalized()
		global_position += dir * chase_speed * delta
		rotation = dir.angle()


func reset() -> void:
	_set_state(PoliceState.RESETTING)
	_tracked_player = null
	global_position = _start_position
	rotation = 0.0
	_set_state(PoliceState.IDLE)


func _on_detection_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_tracked_player = body
	_alert_timer = alert_duration
	_set_state(PoliceState.ALERT)


func _on_detection_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	if body == _tracked_player:
		_tracked_player = null
	if _state != PoliceState.RESETTING:
		_set_state(PoliceState.IDLE)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.request_player_caught(self)


func _set_state(next_state: PoliceState) -> void:
	if _state == next_state:
		return
	_state = next_state
	_apply_state_visual()
	GameManager.report_police_state(self, int(_state))
	state_changed.emit(int(_state))


func _apply_state_visual() -> void:
	match _state:
		PoliceState.IDLE:
			_car_body.color = Color(0.75, 0.1, 0.1, 1.0)
		PoliceState.ALERT:
			_car_body.color = Color(1.0, 0.45, 0.05, 1.0)
		PoliceState.CHASING:
			_car_body.color = Color(1.0, 0.05, 0.05, 1.0)
		PoliceState.RESETTING:
			_car_body.color = Color(0.45, 0.05, 0.05, 1.0)
