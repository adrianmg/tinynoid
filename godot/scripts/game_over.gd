class_name GameOverScreen
extends ResultScreenBase

signal new_game_requested

const RED := Color("#f15b68")


func _ready() -> void:
	configure_result("GAME OVER", RED, "RETRY", "game_over")
	super._ready()


func _request_primary_action() -> void:
	new_game_requested.emit()
