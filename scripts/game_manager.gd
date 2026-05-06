extends Node

## Autoload singleton that manages global game state.
## Register the active Game scene via register_game(), then call
## player_caught() from the Police script to trigger a level reset.

var _game: Node = null


func register_game(game: Node) -> void:
	_game = game


func player_caught() -> void:
	if _game and is_instance_valid(_game):
		_game.on_player_caught()
