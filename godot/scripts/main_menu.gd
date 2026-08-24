class_name MainMenu
extends Control

signal start_requested(stage_number: int)
signal quit_requested

const VOID := Color("#050611")
const PANEL := Color("#111329")
const RAIL_DARK := Color("#12345b")
const BLUE := Color("#287fc4")
const CYAN := Color("#74ddff")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const MAGENTA := Color("#c967e8")
const OPTION_Y := [94, 116, 138]
const SUBTITLE := "A tiny tribute from Adrian Mato to Arkanoid"
const INSTRUCTION_LINES := [
	"Arrow keys to move & select",
	"Enter / Space / tap to select",
	"ESC to quit",
]

var _selected_index := 0
var _selected_stage := 1


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_selected_stage = clampi(
		GameSession.level,
		1,
		LevelCatalog.STAGE_COUNT
	)
	AudioSettings.level_changed.connect(_on_audio_level_changed)
	DisplayController.mode_changed.connect(_on_display_mode_changed)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(36, 78, 184, 82), PANEL)
	draw_rect(Rect2(36, 78, 184, 2), CYAN)
	draw_rect(Rect2(36, 158, 184, 2), BLUE)

	draw_rect(Rect2(52, 46, 16, 2), MAGENTA)
	draw_rect(Rect2(188, 46, 16, 2), MAGENTA)
	PixelFont.draw_centered(self, "TINYNOID", 42, CYAN, 2)
	PixelFont.draw_centered(self, SUBTITLE, 61, WHITE)

	for option_index in range(OPTION_Y.size()):
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
			OPTION_Y[option_index],
			YELLOW if option_index == _selected_index else WHITE
		)

	PixelFont.draw_centered(self, INSTRUCTION_LINES[0], 190, CYAN)
	PixelFont.draw_centered(self, INSTRUCTION_LINES[1], 202, WHITE)
	PixelFont.draw_centered(self, INSTRUCTION_LINES[2], 216, MAGENTA)


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
			_activate_selected()
			accept_event()


func get_selected_index() -> int:
	return _selected_index


func get_selected_stage() -> int:
	return _selected_stage


func is_sound_enabled() -> bool:
	return AudioSettings.is_enabled()


func get_sound_level() -> int:
	return AudioSettings.level


func _select_relative(direction: int) -> void:
	_selected_index = posmod(_selected_index + direction, OPTION_Y.size())
	queue_redraw()


func _change_selected(direction: int) -> void:
	match _selected_index:
		0:
			_selected_stage = wrapi(
				_selected_stage + direction,
				1,
				LevelCatalog.STAGE_COUNT + 1
			)
			queue_redraw()
		1:
			DisplayController.cycle_window_mode(direction)
		2:
			AudioSettings.cycle_level(direction)


func _activate_selected() -> void:
	match _selected_index:
		0:
			start_requested.emit(_selected_stage)
		1:
			DisplayController.cycle_window_mode()
		2:
			AudioSettings.cycle_level(-1)


func _get_option_text(option_index: int) -> String:
	match option_index:
		0:
			return "PLAY STAGE %02d" % _selected_stage
		1:
			return "WINDOW %s" % DisplayController.get_mode_label()
		2:
			return "SOUND %s" % AudioSettings.get_level_label()

	return ""


func _get_option_rect(option_index: int) -> Rect2:
	return Rect2(52, OPTION_Y[option_index] - 3, 152, 11)


func _get_option_at(position: Vector2) -> int:
	for option_index in range(OPTION_Y.size()):
		if _get_option_rect(option_index).has_point(position):
			return option_index

	return -1


func _on_display_mode_changed(_label: String) -> void:
	queue_redraw()


func _on_audio_level_changed(_level: int) -> void:
	queue_redraw()
