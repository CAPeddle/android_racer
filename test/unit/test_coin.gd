extends "res://addons/gut/test.gd"

# Unit test for the Coin one-shot pickup guard (scripts/coin.gd).
#
# Coin reports pickups to the live `GameManager` autoload, so this test
# watches the autoload's `score_changed` signal. We force the autoload into
# the RUNNING state and give it a coin budget so a reported pickup scores,
# then confirm that overlapping the coin twice only reports the pickup once
# (the `_is_collected` guard).

var _coin: Coin = null


func before_each() -> void:
	# Ensure the autoload is RUNNING with room to score before each test.
	GameManager.set_game_paused(false)
	GameManager.set_coin_total(10)
	GameManager.reset_score()


func after_each() -> void:
	if is_instance_valid(_coin):
		_coin.queue_free()
	_coin = null


func test_coin_reports_pickup_only_once() -> void:
	_coin = load("res://scenes/Coin.tscn").instantiate()
	add_child_autofree(_coin)  # runs _ready()
	watch_signals(GameManager)
	watch_signals(_coin)

	var player := Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)

	_coin._on_body_entered(player)
	_coin._on_body_entered(player)  # second overlap is ignored by the guard

	assert_signal_emit_count(GameManager, "score_changed", 1,
		"Coin should report the pickup to GameManager exactly once")
	assert_signal_emit_count(_coin, "collected", 1,
		"Coin should emit 'collected' exactly once")
	assert_eq(GameManager.get_score(), 1, "Exactly one coin should have scored")
