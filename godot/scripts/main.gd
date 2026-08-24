extends Node

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const GAMEPLAY_SCENE: PackedScene = preload("res://scenes/gameplay.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://scenes/game_over.tscn")
const STAGE_CLEAR_SCENE: PackedScene = preload("res://scenes/stage_clear.tscn")
const NAME_ENTRY_SCENE: PackedScene = preload("res://scenes/name_entry.tscn")
const HIGH_SCORES_SCENE: PackedScene = preload("res://scenes/high_scores.tscn")

var _current_screen: Node
var _pending_submission: Dictionary = {}
var _pending_terminal := ""


func _ready() -> void:
	GameSession.new_game()
	_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_cancel")
		and is_instance_valid(_current_screen)
		and not _current_screen is MainMenu
		and not _current_screen is NameEntryScreen
		and not _current_screen is HighScoresScreen
	):
		get_viewport().set_input_as_handled()
		_show_main_menu()


func _show_main_menu() -> void:
	MusicController.play_menu()
	var main_menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	_replace_screen(main_menu)
	main_menu.start_requested.connect(_start_new_game)
	main_menu.high_scores_requested.connect(_show_high_scores)
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
	_finish_run("game_over")


func _present_game_over() -> void:
	var game_over := GAME_OVER_SCENE.instantiate()
	_replace_screen(game_over)
	game_over.new_game_requested.connect(_restart_current_stage)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_stage_clear() -> void:
	if GameSession.level >= LevelCatalog.STAGE_COUNT:
		_finish_run("campaign_clear")
		return
	_present_stage_clear()


func _present_stage_clear() -> void:
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


func _finish_run(outcome: String) -> void:
	var run_result := GameSession.capture_run_result(outcome)
	if run_result.is_empty():
		_present_terminal(outcome)
		return

	if not PlayerProfile.has_player_name():
		Leaderboard.record_score(run_result, "GUEST")
		_pending_submission = run_result
		_pending_terminal = outcome
		_show_name_entry()
		return

	Leaderboard.record_score(
		run_result,
		PlayerProfile.get_display_name()
	)
	_present_terminal(outcome)


func _show_name_entry() -> void:
	var name_entry: NameEntryScreen = NAME_ENTRY_SCENE.instantiate()
	name_entry.configure(
		PlayerProfile.player_name,
		int(_pending_submission.get("score", 0)),
		true
	)
	_replace_screen(name_entry)
	name_entry.name_confirmed.connect(_on_name_confirmed)
	name_entry.guest_selected.connect(_on_guest_selected)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_high_scores() -> void:
	var high_scores: HighScoresScreen = HIGH_SCORES_SCENE.instantiate()
	_replace_screen(high_scores)
	high_scores.back_requested.connect(_show_main_menu)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_name_confirmed(player_name: String) -> void:
	if _pending_submission.is_empty():
		_show_main_menu()
		return

	Leaderboard.record_score(_pending_submission, player_name)
	var terminal := _pending_terminal
	_clear_pending_terminal()
	_present_terminal(terminal)


func _on_guest_selected() -> void:
	if _pending_terminal.is_empty():
		_show_main_menu()
		return

	Leaderboard.record_score(_pending_submission, "GUEST")
	var terminal := _pending_terminal
	_clear_pending_terminal()
	_present_terminal(terminal)


func _present_terminal(outcome: String) -> void:
	if outcome == "campaign_clear":
		_present_stage_clear()
	else:
		_present_game_over()


func _clear_pending_terminal() -> void:
	_pending_submission = {}
	_pending_terminal = ""


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
