extends "res://addons/gut/test.gd"

# Regression coverage for a device-observed freeze: after the OS backgrounds
# the app (e.g. a screen timeout on Android) and later resumes it, gameplay
# can end up completely unresponsive except for the reset button -- exactly
# what was seen on a Samsung Galaxy Tab S6 Lite after a screen-off gap during
# a WiFi-deploy play-test. Root cause: GameScene pauses the whole SceneTree on
# NOTIFICATION_APPLICATION_PAUSED (see _on_game_pause_changed in game.gd), but
# only the UI layer + reset button are exempted via PROCESS_MODE_WHEN_PAUSED
# (_connect_signals). Player and Police have no such exemption, so a paused
# tree freezes them outright, with no recovery if the matching
# NOTIFICATION_APPLICATION_RESUMED is ever missed by the OS.

var _game: GameScene = null


func before_each() -> void:
	GameManager.set_game_paused(false)
	GameManager.set_input_locked(false)


func after_each() -> void:
	if is_instance_valid(_game):
		get_tree().paused = false
		_game.queue_free()
	_game = null
	GameManager.set_game_paused(false)
	GameManager.set_input_locked(false)


func test_os_pause_notification_pauses_tree_and_locks_input() -> void:
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(_game)

	_game._notification(NOTIFICATION_APPLICATION_PAUSED)

	assert_true(get_tree().paused, "SceneTree should be paused after an OS pause notification")
	assert_true(GameManager.is_input_locked(), "Input should lock while paused")

	get_tree().paused = false  # keep the suite's tree usable for later tests


func test_os_resume_notification_unpauses_tree_and_unlocks_input() -> void:
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(_game)

	_game._notification(NOTIFICATION_APPLICATION_PAUSED)
	_game._notification(NOTIFICATION_APPLICATION_RESUMED)

	assert_false(get_tree().paused, "SceneTree should unpause once RESUMED arrives")
	assert_false(GameManager.is_input_locked(), "Input should unlock once RESUMED arrives")


func test_focus_in_unpauses_when_resumed_notification_is_missed() -> void:
	# The real device bug: PAUSED fires (screen timeout) but the matching
	# RESUMED never arrives. FOCUS_IN, which fires whenever the window
	# regains focus, is the fallback that recovers the game instead of
	# leaving it stuck paused forever.
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(_game)

	_game._notification(NOTIFICATION_APPLICATION_PAUSED)
	_game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	assert_false(get_tree().paused, "FOCUS_IN should recover a stuck-paused tree")
	assert_false(GameManager.is_input_locked(), "FOCUS_IN recovery should unlock input")


func test_focus_in_is_a_noop_when_not_paused() -> void:
	# Guard against FOCUS_IN (which fires often -- e.g. after a system
	# dialog closes) spuriously touching pause/input state outside the
	# stuck-paused recovery case.
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(_game)
	watch_signals(GameManager)

	_game._notification(NOTIFICATION_APPLICATION_FOCUS_IN)

	assert_false(get_tree().paused)
	assert_signal_not_emitted(GameManager, "game_pause_changed")


func test_player_and_police_have_no_exemption_from_a_paused_tree() -> void:
	# This is the mechanism behind the freeze: unlike the UI layer/reset
	# button, Player and Police use the default PROCESS_MODE_INHERIT, so a
	# stuck-paused SceneTree stops their _process/_physics_process/_input
	# outright -- confirmed against the live scenes, not just the scripts.
	var player: Node = load("res://scenes/Player.tscn").instantiate()
	var police: Node = load("res://scenes/Police.tscn").instantiate()
	add_child_autofree(player)
	add_child_autofree(police)

	assert_eq(player.process_mode, Node.PROCESS_MODE_INHERIT,
		"PlayerCar has no exemption, so it freezes if the tree gets stuck paused")
	assert_eq(police.process_mode, Node.PROCESS_MODE_INHERIT,
		"PoliceCar has no exemption, so it freezes if the tree gets stuck paused")


func test_reset_button_and_ui_layer_are_exempt_from_pause() -> void:
	_game = load("res://scenes/Game.tscn").instantiate()
	add_child_autofree(_game)

	var reset_button: Button = _game.get_node("UI/ResetButton")
	var ui_layer: CanvasLayer = _game.get_node("UI")

	assert_eq(reset_button.process_mode, Node.PROCESS_MODE_WHEN_PAUSED,
		"Reset button is the one thing that stays responsive when the tree is stuck paused")
	assert_eq(ui_layer.process_mode, Node.PROCESS_MODE_WHEN_PAUSED,
		"UI layer is the one thing that stays responsive when the tree is stuck paused")
