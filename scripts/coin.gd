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
	monitoring = false
	GameManager.collect_coin(self)
	collected.emit(self)
	_play_pickup_pop()


# Juice: a quick scale-up + fade on pickup instead of vanishing instantly, then
# free. Gameplay-wise the coin is already gone (monitoring off, guard set); this
# is purely the visual flourish.
func _play_pickup_pop() -> void:
	if not is_instance_valid(_visual):
		queue_free()
		return
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "scale", Vector2(1.7, 1.7), 0.15)
	tween.tween_property(_visual, "modulate:a", 0.0, 0.15)
	tween.chain().tween_callback(queue_free)
