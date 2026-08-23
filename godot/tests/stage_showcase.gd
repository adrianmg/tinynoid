extends Node2D

@export_range(1, LevelCatalog.STAGE_COUNT, 1) var stage_number := 17


func _enter_tree() -> void:
	GameSession.new_game(stage_number)


func _ready() -> void:
	MusicController.play_stage(stage_number)
