extends Area2D

## Police car – simple two-state machine: IDLE and CHASE.
##
## IDLE  – Stationary at its spawn position.
## CHASE – Moves towards the player at CHASE_SPEED.
##
## Transitions:
##   Player enters DetectionZone  → IDLE  ➜ CHASE
##   Player leaves DetectionZone  → CHASE ➜ IDLE  (police stops in place)
##   Player overlaps police body  → GameManager.player_caught()

enum State { IDLE, CHASE }

const CHASE_SPEED: float = 300.0

var _state: State = State.IDLE
var _player: Node2D = null
var _start_position: Vector2

@onready var _detection_zone: Area2D = $DetectionZone
@onready var _car_body: Polygon2D = $CarBody


func _ready() -> void:
	_start_position = global_position
	_detection_zone.body_entered.connect(_on_detection_entered)
	_detection_zone.body_exited.connect(_on_detection_exited)
	body_entered.connect(_on_body_caught)


func _on_detection_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player = body
		_state = State.CHASE
		_car_body.color = Color(1.0, 0.05, 0.05, 1.0)  # Bright red when chasing


func _on_detection_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_state = State.IDLE
		_player = null
		_car_body.color = Color(0.75, 0.1, 0.1, 1.0)  # Dim red when idle


func _on_body_caught(body: Node2D) -> void:
	if body.is_in_group("player"):
		GameManager.player_caught()


func _physics_process(delta: float) -> void:
	if _state == State.CHASE and _player:
		var dir: Vector2 = (_player.global_position - global_position).normalized()
		global_position += dir * CHASE_SPEED * delta
		rotation = dir.angle()


func reset() -> void:
	_state = State.IDLE
	_player = null
	global_position = _start_position
	rotation = 0.0
	_car_body.color = Color(0.75, 0.1, 0.1, 1.0)
