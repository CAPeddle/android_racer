extends Area2D
class_name Coin

signal collected(coin: Node)

const SPARKLE_SECONDS: float = 0.5

var _is_collected: bool = false

@onready var _visual: Node2D = $Visual
@onready var _sparkle: CPUParticles2D = $Sparkle


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
	_play_pickup_effect()


# Juice: on pickup, pop the coin (scale-up + fade) and emit a sparkle burst,
# then free once the effect has played out. Gameplay-wise the coin is already
# gone (monitoring off, guard set); this is purely the flourish.
func _play_pickup_effect() -> void:
	if is_instance_valid(_visual):
		var tween: Tween = create_tween()
		tween.set_parallel(true)
		tween.tween_property(_visual, "scale", Vector2(1.7, 1.7), 0.15)
		tween.tween_property(_visual, "modulate:a", 0.0, 0.15)
	if is_instance_valid(_sparkle):
		_sparkle.emitting = true
	# Outlive the tween so the sparkle finishes before the coin frees.
	get_tree().create_timer(SPARKLE_SECONDS).timeout.connect(queue_free)
