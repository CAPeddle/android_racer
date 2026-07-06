extends Area2D
class_name Coin

signal collected(coin: Node)

var _is_collected: bool = false

@onready var _visual: Node2D = $Visual


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _is_collected:
		return
	if body.is_in_group("player"):
		_collect()


func _collect() -> void:
	_is_collected = true
	if is_instance_valid(_visual):
		_visual.visible = false
	monitoring = false
	GameManager.collect_coin(self)
	collected.emit(self)
	queue_free()
