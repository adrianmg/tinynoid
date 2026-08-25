extends Node

const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const GAMEPLAY_SCENE: PackedScene = preload("res://scenes/gameplay.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://scenes/game_over.tscn")
const STAGE_CLEAR_SCENE: PackedScene = preload("res://scenes/stage_clear.tscn")
const NAME_ENTRY_SCENE: PackedScene = preload("res://scenes/name_entry.tscn")
const HIGH_SCORES_SCENE: PackedScene = preload("res://scenes/high_scores.tscn")
const COMMUNITY_LAB_SCENE: PackedScene = preload(
	"res://scenes/community_lab.tscn"
)

var _current_screen: Node
var _pending_submission: Dictionary = {}
var _pending_terminal := ""
var _deep_link_id := ""
var _community_retry_id := ""
var _featured_request_id := ""
var _featured_request_level: Dictionary = {}


func _ready() -> void:
	GameSession.new_game()
	CommunityCatalog.level_checked.connect(_on_level_checked)
	_show_main_menu()
	_try_community_deep_link()


func _unhandled_input(event: InputEvent) -> void:
	if (
		event.is_action_pressed("ui_cancel")
		and is_instance_valid(_current_screen)
		and not _current_screen is MainMenu
		and not _current_screen is NameEntryScreen
		and not _current_screen is HighScoresScreen
		and not _current_screen is CommunityLab
	):
		get_viewport().set_input_as_handled()
		_show_contextual_main_menu()


func _show_main_menu(
	featured_community_level: Dictionary = {},
	notice: String = ""
) -> void:
	MusicController.play_menu()
	var main_menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	if not featured_community_level.is_empty():
		main_menu.configure_featured_community_level(featured_community_level)
	if not notice.is_empty():
		main_menu.show_notice(notice)
	_replace_screen(main_menu)
	main_menu.start_requested.connect(_start_new_game)
	main_menu.community_level_requested.connect(_request_featured_community_game)
	main_menu.community_lab_requested.connect(_show_community_lab)
	main_menu.high_scores_requested.connect(_show_high_scores)
	main_menu.quit_requested.connect(_quit_game)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_contextual_main_menu() -> void:
	if GameSession.is_community_run():
		_show_main_menu(GameSession.community_level)
	else:
		_show_main_menu()


func _show_gameplay() -> void:
	MusicController.play_stage(GameSession.level)
	var gameplay := GAMEPLAY_SCENE.instantiate()
	_replace_screen(gameplay)
	gameplay.restart_requested.connect(_restart_current_stage)
	gameplay.game_over_requested.connect(_show_game_over)
	gameplay.stage_clear_requested.connect(_show_stage_clear)
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN


func _show_community_lab(notice: String = "") -> void:
	MusicController.play_menu()
	var community_lab: CommunityLab = COMMUNITY_LAB_SCENE.instantiate()
	_replace_screen(community_lab)
	community_lab.level_requested.connect(_start_community_game)
	community_lab.back_requested.connect(_show_main_menu)
	community_lab.editor_requested.connect(_open_level_editor)
	if not notice.is_empty():
		community_lab.show_notice(notice)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _open_level_editor() -> void:
	var error := OS.shell_open("https://tinynoid.vercel.app/editor/")
	if error != OK and _current_screen is CommunityLab:
		(_current_screen as CommunityLab).show_notice(
			"COULD NOT OPEN LEVEL EDITOR"
		)


func _start_community_game(level_data: Dictionary) -> void:
	GameSession.new_community_game(level_data)
	_show_gameplay()


func _request_featured_community_game(level_data: Dictionary) -> void:
	var level_id := String(level_data.get("id", ""))
	if not CommunityCatalogClient.is_valid_id(level_id):
		_show_main_menu(level_data, "SHARED LEVEL UNAVAILABLE")
		return
	_show_main_menu(level_data, "VERIFYING SHARED LEVEL")
	_featured_request_id = level_id
	_featured_request_level = level_data.duplicate(true)
	if (
		not CommunityCatalog.request_exact(level_id)
		and _featured_request_id == level_id
	):
		_featured_request_id = ""
		_featured_request_level = {}
		_show_main_menu(level_data, "SHARED LEVEL CHECK BUSY")


func _show_game_over() -> void:
	_finish_run("game_over")


func _present_game_over() -> void:
	var game_over := GAME_OVER_SCENE.instantiate()
	_replace_screen(game_over)
	game_over.new_game_requested.connect(_restart_current_stage)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _show_stage_clear() -> void:
	if GameSession.is_community_run():
		_present_stage_clear()
		return
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
	_register_eligible_run()
	_show_gameplay()


func _restart_current_stage() -> void:
	if GameSession.is_community_run():
		_retry_community_level()
		return
	var current_level := GameSession.level
	GameSession.new_game(current_level)
	_register_eligible_run()
	_show_gameplay()


func _retry_community_level() -> void:
	var level_id := String(GameSession.community_level.get("id", ""))
	if not CommunityCatalogClient.is_valid_id(level_id):
		_fail_community_retry("Community level is no longer available.")
		return
	_show_community_lab("VERIFYING RETRY ONLINE")
	_community_retry_id = level_id
	if (
		not CommunityCatalog.request_exact(level_id)
		and _community_retry_id == level_id
	):
		_fail_community_retry("Could not start the retry freshness check.")


func _fail_community_retry(message: String) -> void:
	_community_retry_id = ""
	GameSession.new_game()
	_show_community_lab(
		message
		if not message.is_empty()
		else "Community level is no longer available."
	)


func _continue_campaign() -> void:
	if GameSession.is_community_run():
		_show_contextual_main_menu()
		return
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
		_record_terminal_score(run_result, "GUEST")
		_pending_submission = run_result
		_pending_terminal = outcome
		_show_name_entry()
		return

	_record_terminal_score(
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

	var saved := _record_terminal_score(_pending_submission, player_name)
	var terminal := _pending_terminal
	if saved:
		_clear_pending_terminal()
	_present_terminal(terminal)


func _on_guest_selected() -> void:
	if _pending_terminal.is_empty():
		_show_main_menu()
		return

	var saved := _record_terminal_score(_pending_submission, "GUEST")
	var terminal := _pending_terminal
	if saved:
		_clear_pending_terminal()
	_present_terminal(terminal)


func _present_terminal(outcome: String) -> void:
	if outcome == "campaign_clear":
		_present_stage_clear()
	else:
		_present_game_over()


func _register_eligible_run() -> void:
	if GameSession.can_submit_score():
		Leaderboard.register_run(GameSession.run_id)


func _record_terminal_score(
	run_result: Dictionary,
	player_name: String
) -> bool:
	var saved := Leaderboard.record_score(run_result, player_name)
	if not saved:
		_pending_submission = run_result.duplicate(true)
		push_warning("Terminal score remains in memory because local save failed.")
	return saved


func _clear_pending_terminal() -> void:
	_pending_submission = {}
	_pending_terminal = ""


func _try_community_deep_link() -> void:
	if not OS.has_feature("web"):
		return
	var query: Variant = JavaScriptBridge.eval("window.location.search", true)
	if typeof(query) != TYPE_STRING:
		return
	_deep_link_id = CommunityCatalogClient.deep_link_id(String(query))
	if _deep_link_id.is_empty():
		return
	if _current_screen is MainMenu:
		(_current_screen as MainMenu).show_notice("VERIFYING SHARED LEVEL")
	if (
		not CommunityCatalog.request_exact(_deep_link_id)
		and not _deep_link_id.is_empty()
	):
		_deep_link_id = ""
		if _current_screen is MainMenu:
			(_current_screen as MainMenu).show_notice(
				"SHARED LEVEL CHECK BUSY"
			)


func _on_level_checked(
	level_id: String,
	playable: bool,
	level_data: Dictionary,
	message: String
) -> void:
	if level_id == _featured_request_id:
		var requested_level := _featured_request_level.duplicate(true)
		_featured_request_id = ""
		_featured_request_level = {}
		if playable and CommunityCatalog.is_confirmed_playable(level_id):
			_start_community_game(level_data)
		else:
			GameSession.new_game()
			_show_main_menu(
				requested_level,
				message
				if not message.is_empty()
				else "SHARED LEVEL UNAVAILABLE"
			)
		return
	if level_id == _community_retry_id:
		_community_retry_id = ""
		if playable and CommunityCatalog.is_confirmed_playable(level_id):
			_start_community_game(level_data)
		else:
			_fail_community_retry(message)
		return
	if level_id != _deep_link_id:
		return
	_deep_link_id = ""
	if not _current_screen is MainMenu:
		return
	if playable and CommunityCatalog.is_confirmed_playable(level_id):
		_show_main_menu(level_data)
	else:
		_show_main_menu(
			{},
			message
			if not message.is_empty()
			else "SHARED LEVEL UNAVAILABLE"
		)


func _quit_game() -> void:
	MusicController.stop_for_shutdown()
	await get_tree().process_frame
	MusicController.shutdown()
	await get_tree().process_frame
	get_tree().quit()


func _replace_screen(next_screen: Node) -> void:
	_cancel_pending_community_navigation()
	if is_instance_valid(_current_screen):
		remove_child(_current_screen)
		_current_screen.queue_free()

	_current_screen = next_screen
	add_child(_current_screen)


func _cancel_pending_community_navigation() -> void:
	_deep_link_id = ""
	_community_retry_id = ""
	_featured_request_id = ""
	_featured_request_level = {}
