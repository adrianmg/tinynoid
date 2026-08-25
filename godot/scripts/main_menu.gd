class_name MainMenu
extends Control

signal start_requested(stage_number: int)
signal daily_requested
signal community_level_requested(level: Dictionary)
signal community_lab_requested
signal high_scores_requested
signal quit_requested

const VOID := Color("#050611")
const PANEL := Color("#111329")
const RAIL_DARK := Color("#12345b")
const BLUE := Color("#287fc4")
const CYAN := Color("#74ddff")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const MAGENTA := Color("#c967e8")
const DESKTOP_OPTION_Y := [76, 90, 104, 118, 132, 146]
const WEB_OPTION_Y := [80, 96, 112, 128, 144]
const RECENT_SCORE_Y := 174
const SUBTITLE := "A TINY ARKANOID TRIBUTE BY @ADRIANMG"
const COMMUNITY_SUBTITLE := "SHARED COMMUNITY LEVEL"
const DESKTOP_INSTRUCTION_LINES: Array[String] = [
	"Arrow keys to move & select",
	"Enter / Space to select",
	"ESC to quit",
]
const MOBILE_INSTRUCTION_LINES: Array[String] = [
	"Tap and drag to move",
	"Tap to select / launch / fire",
	"Swipe lists to scroll",
]

var _selected_index := 0
var _selected_stage := 1
var _recent_score_state := Leaderboard.STATE_LOADING
var _recent_score: Dictionary = {}
var _featured_community_level: Dictionary = {}
var _notice := ""
var _web_mode := OS.has_feature("web")


func configure_featured_community_level(level: Dictionary) -> void:
	_featured_community_level = level.duplicate(true)
	_selected_index = 0


func show_notice(message: String) -> void:
	_notice = message.to_upper()
	queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_selected_stage = clampi(
		GameSession.level,
		1,
		LevelCatalog.STAGE_COUNT
	)
	AudioSettings.level_changed.connect(_on_audio_level_changed)
	DisplayController.mode_changed.connect(_on_display_mode_changed)
	Leaderboard.latest_score_updated.connect(_on_latest_score_updated)
	_recent_score = Leaderboard.cached_latest_score()
	if not _recent_score.is_empty():
		_recent_score_state = Leaderboard.STATE_STALE
	if (
		_featured_community_level.is_empty()
		and DisplayServer.get_name() != "headless"
	):
		Leaderboard.request_latest_score()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(36, 72, 184, 90), PANEL)
	var accent := MAGENTA if has_featured_community_level() else CYAN
	draw_rect(Rect2(36, 72, 184, 2), accent)
	draw_rect(Rect2(36, 158, 184, 2), BLUE)

	draw_rect(Rect2(52, 46, 16, 2), MAGENTA)
	draw_rect(Rect2(188, 46, 16, 2), MAGENTA)
	PixelFont.draw_centered(self, "TINYNOID", 42, CYAN, 2)
	PixelFont.draw_centered(
		self,
		COMMUNITY_SUBTITLE if has_featured_community_level() else SUBTITLE,
		61,
		MAGENTA if has_featured_community_level() else WHITE
	)

	for option_index in range(_option_count()):
		var option_rect := _get_option_rect(option_index)
		if option_index == _selected_index:
			draw_rect(option_rect, RAIL_DARK)
			draw_rect(Rect2(option_rect.position, Vector2(2, option_rect.size.y)), CYAN)
			draw_rect(
				Rect2(
					option_rect.end.x - 2,
					option_rect.position.y,
					2,
					option_rect.size.y
				),
				CYAN
			)

		PixelFont.draw_centered(
			self,
			_get_option_text(option_index),
			_get_option_y(option_index),
			YELLOW if option_index == _selected_index else WHITE
		)

	draw_rect(Rect2(16, RECENT_SCORE_Y - 2, 224, 9), VOID)
	PixelFont.draw_centered(
		self,
		get_recent_score_text(),
		RECENT_SCORE_Y,
		_get_recent_score_color()
	)
	var instruction_lines := instruction_lines_for(
		GamePointer.is_mobile_device()
	)
	PixelFont.draw_centered(self, instruction_lines[0], 190, CYAN)
	PixelFont.draw_centered(self, instruction_lines[1], 202, WHITE)
	PixelFont.draw_centered(self, instruction_lines[2], 216, MAGENTA)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()

	if event.is_action_pressed("ui_cancel"):
		quit_requested.emit()
	elif event.is_action_pressed("ui_up"):
		_select_relative(-1)
		UiAudio.play_move()
	elif event.is_action_pressed("ui_down"):
		_select_relative(1)
		UiAudio.play_move()
	elif event.is_action_pressed("ui_left"):
		_change_selected(-1)
		UiAudio.play_move()
	elif event.is_action_pressed("ui_right"):
		_change_selected(1)
		UiAudio.play_move()
	elif event.is_action_pressed("launch") or event.is_action_pressed("ui_accept"):
		UiAudio.play_confirm()
		_activate_selected()
	else:
		return

	if is_instance_valid(viewport):
		viewport.set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered_option := _get_option_at(event.position)
		if hovered_option >= 0 and hovered_option != _selected_index:
			_selected_index = hovered_option
			UiAudio.play_move()
			queue_redraw()
	elif GamePointer.is_primary_press(event):
		var clicked_option := _get_option_at(event.position)
		if clicked_option >= 0:
			_selected_index = clicked_option
			UiAudio.play_confirm()
			accept_event()
			_activate_selected()


func get_selected_index() -> int:
	return _selected_index


func get_selected_stage() -> int:
	return _selected_stage


func is_sound_enabled() -> bool:
	return AudioSettings.is_enabled()


func get_sound_level() -> int:
	return AudioSettings.level


func has_featured_community_level() -> bool:
	return not _featured_community_level.is_empty()


func get_featured_community_level() -> Dictionary:
	return _featured_community_level.duplicate(true)


static func instruction_lines_for(is_mobile: bool) -> Array[String]:
	return (
		MOBILE_INSTRUCTION_LINES
		if is_mobile
		else DESKTOP_INSTRUCTION_LINES
	)


static func option_ids_for(is_web: bool) -> Array[StringName]:
	var option_ids: Array[StringName] = [
		&"play",
		&"daily",
		&"community_lab",
		&"high_scores",
	]
	if not is_web:
		option_ids.append(&"window")
	option_ids.append(&"sound")
	return option_ids


func get_recent_score_text() -> String:
	if not _notice.is_empty():
		return _fit_text(_notice, 248)
	if has_featured_community_level():
		return _fit_text(
			"%s — BY %s" % [
				String(_featured_community_level.get("level_name", "LEVEL")),
				String(
					CommunityCatalogClient.format_creator_name(
						String(
							_featured_community_level.get(
								"creator_display_name",
								"CREATOR"
							)
						)
					)
				),
			],
			248
		)
	if not _recent_score.is_empty():
		return "%s HIT %d POINTS RECENTLY" % [
			String(_recent_score.get("player_name", "PLAYER")),
			int(_recent_score.get("score", 0)),
		]

	match _recent_score_state:
		Leaderboard.STATE_LOADING:
			return "LOADING RECENT SCORE"
		Leaderboard.STATE_EMPTY:
			return "NO RECENT SCORES YET"
		Leaderboard.STATE_ERROR:
			return "RECENT SCORE OFFLINE"

	return "NO RECENT SCORES YET"


func _select_relative(direction: int) -> void:
	_selected_index = posmod(_selected_index + direction, _option_count())
	queue_redraw()


func _change_selected(direction: int) -> void:
	match _get_option_id(_selected_index):
		&"play":
			if has_featured_community_level():
				_featured_community_level = {}
				_notice = ""
				_selected_stage = wrapi(
					1 + direction,
					1,
					LevelCatalog.STAGE_COUNT + 1
				)
				queue_redraw()
				return
			_selected_stage = wrapi(
				_selected_stage + direction,
				1,
				LevelCatalog.STAGE_COUNT + 1
			)
			queue_redraw()
		&"window":
			DisplayController.cycle_window_mode(direction)
		&"sound":
			AudioSettings.cycle_level(direction)


func _activate_selected() -> void:
	match _get_option_id(_selected_index):
		&"play":
			if has_featured_community_level():
				community_level_requested.emit(
					_featured_community_level.duplicate(true)
				)
			else:
				start_requested.emit(_selected_stage)
		&"daily":
			daily_requested.emit()
		&"community_lab":
			community_lab_requested.emit()
		&"high_scores":
			high_scores_requested.emit()
		&"window":
			DisplayController.cycle_window_mode()
		&"sound":
			AudioSettings.cycle_level(-1)


func _get_option_text(option_index: int) -> String:
	match _get_option_id(option_index):
		&"play":
			return (
				"PLAY SHARED LEVEL"
				if has_featured_community_level()
				else "PLAY STAGE %02d" % _selected_stage
			)
		&"daily":
			return "DAILY CARTRIDGE"
		&"community_lab":
			return "COMMUNITY LAB"
		&"high_scores":
			return "HIGH SCORES"
		&"window":
			return "WINDOW %s" % DisplayController.get_mode_label()
		&"sound":
			return "SOUND %s" % AudioSettings.get_level_label()

	return ""


func _get_option_rect(option_index: int) -> Rect2:
	return Rect2(52, _get_option_y(option_index) - 3, 152, 11)


func _get_option_at(position: Vector2) -> int:
	for option_index in range(_option_count()):
		var hit_rect := Rect2(
			36,
			_get_option_y(option_index) - 8,
			184,
			16
		)
		if hit_rect.has_point(position):
			return option_index

	return -1


func _option_count() -> int:
	return option_ids_for(_web_mode).size()


func _get_option_id(option_index: int) -> StringName:
	var option_ids := option_ids_for(_web_mode)
	return option_ids[option_index] if option_index < option_ids.size() else &""


func _get_option_y(option_index: int) -> int:
	return (
		WEB_OPTION_Y[option_index]
		if _web_mode
		else DESKTOP_OPTION_Y[option_index]
	)


func _on_display_mode_changed(_label: String) -> void:
	queue_redraw()


func _on_audio_level_changed(_level: int) -> void:
	queue_redraw()


func _on_latest_score_updated(
	state: StringName,
	entry: Dictionary,
	_fetched_at: String
) -> void:
	_recent_score_state = state
	_recent_score = entry.duplicate(true)
	queue_redraw()


func _get_recent_score_color() -> Color:
	if not _notice.is_empty():
		return MAGENTA
	if has_featured_community_level():
		return (
			CYAN
			if String(_featured_community_level.get("status", "")) == "listed"
			else MAGENTA
		)
	if (
		_recent_score_state == Leaderboard.STATE_STALE
		or _recent_score_state == Leaderboard.STATE_ERROR
	):
		return MAGENTA
	if _recent_score.is_empty():
		return CYAN
	return YELLOW


func _fit_text(text: String, maximum_width: int) -> String:
	if PixelFont.measure(text).x <= maximum_width:
		return text
	var shortened := text
	while shortened.length() > 3:
		shortened = shortened.left(shortened.length() - 1)
		if PixelFont.measure(shortened + "...").x <= maximum_width:
			return shortened + "..."
	return "..."
