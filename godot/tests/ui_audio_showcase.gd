extends Node


func _ready() -> void:
	UiAudio.play_move()
	await get_tree().create_timer(0.16).timeout
	UiAudio.play_confirm()

