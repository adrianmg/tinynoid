extends Node

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const GAMEPLAY_SCENE: PackedScene = preload("res://scenes/gameplay.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://scenes/game_over.tscn")
const STAGE_CLEAR_SCENE: PackedScene = preload("res://scenes/stage_clear.tscn")

var _current_screen: Node


func _ready() -> void:
	GameSession.new_game()
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_cancel")
		and is_instance_valid(_current_screen)
		and not _current_screen is MainMenu
	):
		get_viewport().set_input_as_handled()
		_show_main_menu()


func _show_main_menu() -> void:
	MusicController.play_menu()
	var main_menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	_replace_screen(main_menu)
	main_menu.start_requested.connect(_start_new_game)
	main_menu.quit_requested.connect(_quit_game)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_gameplay() -> void:
	MusicController.play_stage(GameSession.level)
	var gameplay := GAMEPLAY_SCENE.instantiate()
	_replace_screen(gameplay)
	gameplay.restart_requested.connect(_restart_current_stage)
	gameplay.game_over_requested.connect(_show_game_over)
	gameplay.stage_clear_requested.connect(_show_stage_clear)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _show_game_over() -> void:
	var game_over := GAME_OVER_SCENE.instantiate()
	_replace_screen(game_over)
	game_over.new_game_requested.connect(_restart_current_stage)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_stage_clear() -> void:
	var stage_clear := STAGE_CLEAR_SCENE.instantiate()
	_replace_screen(stage_clear)
	stage_clear.replay_requested.connect(_continue_campaign)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _start_new_game(start_level: int = 1) -> void:
	GameSession.new_game(start_level)
	_show_gameplay()


func _restart_current_stage() -> void:
	var current_level := GameSession.level
	GameSession.new_game(current_level)
	_show_gameplay()


func _continue_campaign() -> void:
	if GameSession.level >= LevelCatalog.STAGE_COUNT:
		_show_main_menu()
		return

	GameSession.advance_level()
	_show_gameplay()


func _quit_game() -> void:
	MusicController.stop_for_shutdown()
	await get_tree().process_frame
	MusicController.shutdown()
	await get_tree().process_frame
	get_tree().quit()


func _replace_screen(next_screen: Node) -> void:
	if is_instance_valid(_current_screen):
		remove_child(_current_screen)
		_current_screen.queue_free()

	_current_screen = next_screen
	add_child(_current_screen)
