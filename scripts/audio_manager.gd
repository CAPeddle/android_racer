extends Node

# Registered as the `AudioManager` autoload in project.godot. Like GameManager,
# it must NOT declare `class_name AudioManager` — a class_name matching an
# autoload name collides ("hides an autoload singleton") and fails to parse.
#
# AudioManager is a pure listener on the GameManager signal bus: it never drives
# gameplay, it only reacts to it. Every sound effect is generated procedurally
# by Sfx (no audio files shipped). The decision helpers (should_ding,
# set_pursuit, is_siren_active) are kept free of node access so they can be
# unit-tested — see test/unit/test_audio_manager.gd.

# PoliceCar.PoliceState.CHASING. Hardcoded to avoid a load-order dependency on
# the PoliceCar class; kept in sync via this comment.
const CHASING_STATE: int = 2

var _last_score: int = 0
var _chasing: Dictionary = {}

var _streams: Dictionary = {}
var _sfx_player: AudioStreamPlayer = null
var _siren_player: AudioStreamPlayer = null


func _ready() -> void:
	_build_streams()
	_sfx_player = AudioStreamPlayer.new()
	add_child(_sfx_player)
	_siren_player = AudioStreamPlayer.new()
	_siren_player.stream = _streams.get("siren")
	_siren_player.volume_db = -8.0
	add_child(_siren_player)
	_connect_signals()


func _build_streams() -> void:
	_streams["coin"] = Sfx.jingle(PackedFloat32Array([880.0, 1320.0]), 0.06, 0.5)
	_streams["caught"] = Sfx.sweep(520.0, 130.0, 0.5, 0.55)
	_streams["clear"] = Sfx.jingle(PackedFloat32Array([660.0, 880.0, 1100.0]), 0.11, 0.5)
	_streams["win"] = Sfx.jingle(PackedFloat32Array([523.0, 659.0, 784.0, 1047.0]), 0.14, 0.55)
	var siren: AudioStreamWAV = Sfx.jingle(PackedFloat32Array([760.0, 940.0]), 0.32, 0.4)
	siren.loop_mode = AudioStreamWAV.LOOP_FORWARD
	siren.loop_begin = 0
	siren.loop_end = siren.data.size() / 2
	_streams["siren"] = siren


func _connect_signals() -> void:
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.player_caught.connect(_on_player_caught)
	GameManager.level_won.connect(_on_level_won)
	GameManager.campaign_complete.connect(_on_campaign_complete)
	GameManager.level_changed.connect(_on_level_changed)
	GameManager.reset_requested.connect(_on_reset_requested)
	GameManager.police_state_changed.connect(_on_police_state_changed)


# --- Pure decision helpers (unit-tested) ---------------------------------

# A coin was collected whenever the score ticks up. score_changed also fires
# with 0 on reset, which must NOT ding.
func should_ding(new_score: int) -> bool:
	var ding: bool = new_score > _last_score
	_last_score = new_score
	return ding


# Track which police are actively chasing; the siren plays while any is.
func set_pursuit(police: Object, chasing: bool) -> bool:
	var id: int = police.get_instance_id() if police != null else 0
	if chasing:
		_chasing[id] = true
	else:
		_chasing.erase(id)
	return is_siren_active()


func is_siren_active() -> bool:
	return not _chasing.is_empty()


# --- Signal handlers -----------------------------------------------------

func _on_score_changed(score: int) -> void:
	if should_ding(score):
		_play("coin")


func _on_player_caught(_source: Node) -> void:
	_play("caught")
	_chasing.clear()
	_update_siren()


func _on_level_won() -> void:
	_play("clear")


func _on_campaign_complete() -> void:
	_play("win")


func _on_level_changed(_index: int) -> void:
	_last_score = 0
	_chasing.clear()
	_update_siren()


func _on_reset_requested(_reason: StringName) -> void:
	_chasing.clear()
	_update_siren()


func _on_police_state_changed(police: Node, state: int) -> void:
	set_pursuit(police, state == CHASING_STATE)
	_update_siren()


func _play(key: String) -> void:
	if _sfx_player == null:
		return
	var stream: AudioStream = _streams.get(key)
	if stream == null:
		return
	_sfx_player.stream = stream
	_sfx_player.play()


func _update_siren() -> void:
	if _siren_player == null:
		return
	if is_siren_active():
		if not _siren_player.playing:
			_siren_player.play()
	elif _siren_player.playing:
		_siren_player.stop()
