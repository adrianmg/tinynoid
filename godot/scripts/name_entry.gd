class_name NameEntryScreen
extends Control

signal name_confirmed(player_name: String)
signal guest_selected

const PANEL := Color("#111329")
const RAIL_DARK := Color("#12345b")
const BLUE := Color("#287fc4")
const CYAN := Color("#74ddff")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const MAGENTA := Color("#c967e8")
const GRID_COLUMNS := 8
const GRID_ROWS := 5
const CELL_SIZE := Vector2(20, 12)
const GRID_ORIGIN := Vector2(48, 88)
const ACTION_Y := 154
const TITLE := "X / TWITTER HANDLE"
const HANDLE_HINT := "@ IS ADDED FOR YOU"
const CHARACTER_KEYS := [
	"A", "B", "C", "D", "E", "F", "G", "H",
	"I", "J", "K", "L", "M", "N", "O", "P",
	"Q", "R", "S", "T", "U", "V", "W", "X",
	"Y", "Z", "0", "1", "2", "3", "4", "5",
	"6", "7", "8", "9", "_",
]
const ACTION_KEYS := ["DELETE", "SKIP", "SAVE"]

var _player_name := ""
var _score := 0
var _for_score_submission := false
var _selected_row := 0
var _selected_column := 0
var _selected_action := 2
var _status := ""


func configure(
	initial_name: String,
	score: int = 0,
	for_score_submission: bool = false
) -> void:
	_player_name = PlayerProfileState.normalize_name(initial_name)
	_score = score
	_for_score_submission = for_score_submission
	if not _player_name.is_empty():
		_selected_row = GRID_ROWS
		_selected_action = 2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(28, 28, 200, 164), PANEL)
	draw_rect(Rect2(28, 28, 200, 2), CYAN)
	draw_rect(Rect2(28, 190, 200, 2), BLUE)
	PixelFont.draw_centered(
		self,
		TITLE,
		40,
		CYAN,
		2
	)
	if _for_score_submission:
		PixelFont.draw_centered(
			self,
			"%06d POINTS" % _score,
			58,
			YELLOW
		)

	var display_handle := (
		PlayerProfileState.format_handle(_player_name)
		if not _player_name.is_empty()
		else "@YOUR_HANDLE"
	)
	PixelFont.draw_centered(
		self,
		display_handle,
		72,
		YELLOW if not _player_name.is_empty() else WHITE
	)

	for key_index in range(CHARACTER_KEYS.size()):
		var row := floori(float(key_index) / GRID_COLUMNS)
		var column := key_index % GRID_COLUMNS
		var rect := _get_character_rect(row, column)
		var selected := (
			_selected_row == row
			and _selected_column == column
		)
		if selected:
			draw_rect(rect, RAIL_DARK)
			draw_rect(
				Rect2(rect.position, Vector2(1, rect.size.y)),
				CYAN
			)
		_draw_text_in_rect(
			self,
			CHARACTER_KEYS[key_index],
			rect,
			YELLOW if selected else WHITE,
		)

	for action_index in range(ACTION_KEYS.size()):
		var rect := _get_action_rect(action_index)
		var selected := (
			_selected_row == GRID_ROWS
			and _selected_action == action_index
		)
		if selected:
			draw_rect(rect, RAIL_DARK)
		_draw_text_in_rect(
			self,
			ACTION_KEYS[action_index],
			rect,
			YELLOW if selected else WHITE,
		)

	if not _status.is_empty():
		PixelFont.draw_centered(self, _status, 176, MAGENTA)
	PixelFont.draw_centered(self, "TYPE HANDLE OR USE ARROWS / FIRE", 208, CYAN)
	PixelFont.draw_centered(self, HANDLE_HINT, 220, WHITE)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if _handle_typed_character(event):
		if is_instance_valid(viewport):
			viewport.set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel"):
		if _player_name.is_empty():
			if PlayerProfile.clear_player_name():
				guest_selected.emit()
		else:
			_delete_character()
	elif event.is_action_pressed("ui_left"):
		_move_horizontal(-1)
	elif event.is_action_pressed("ui_right"):
		_move_horizontal(1)
	elif event.is_action_pressed("ui_up"):
		_move_vertical(-1)
	elif event.is_action_pressed("ui_down"):
		_move_vertical(1)
	elif event.is_action_pressed("launch") or event.is_action_pressed("ui_accept"):
		UiAudio.play_confirm()
		_activate_selected()
		if is_instance_valid(viewport):
			viewport.set_input_as_handled()
		return
	else:
		return

	UiAudio.play_move()
	if is_instance_valid(viewport):
		viewport.set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_select_at(event.position)
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		if _select_at(event.position):
			UiAudio.play_confirm()
			accept_event()
			_activate_selected()


func get_player_name() -> String:
	return _player_name


func _handle_typed_character(event: InputEvent) -> bool:
	if (
		not event is InputEventKey
		or not event.pressed
		or event.echo
	):
		return false
	if event.keycode == KEY_BACKSPACE:
		_delete_character()
		return true
	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		_confirm_name()
		return true
	if event.unicode <= 0:
		return false

	var character := String.chr(event.unicode).to_upper()
	if character == "@":
		return true
	if not PlayerProfileState.SUPPORTED_NAME_CHARACTERS.contains(character):
		return false
	_append_character(character)
	return true


func _append_character(character: String) -> void:
	if _player_name.length() >= PlayerProfileState.MAX_NAME_LENGTH:
		_status = "HANDLE IS FULL"
		queue_redraw()
		return
	_player_name += character
	_status = ""
	queue_redraw()


func _delete_character() -> void:
	if _player_name.is_empty():
		_status = "SELECT SKIP TO CONTINUE"
	else:
		_player_name = _player_name.left(_player_name.length() - 1)
		_status = ""
	queue_redraw()


func _move_horizontal(direction: int) -> void:
	if _selected_row == GRID_ROWS:
		_selected_action = posmod(
			_selected_action + direction,
			ACTION_KEYS.size()
		)
	else:
		var column_count := _get_column_count(_selected_row)
		_selected_column = posmod(
			_selected_column + direction,
			column_count
		)
	queue_redraw()


func _move_vertical(direction: int) -> void:
	if _selected_row == GRID_ROWS:
		if direction < 0:
			_selected_row = GRID_ROWS - 1
			_selected_column = mini(
				_get_column_count(_selected_row) - 1,
				_selected_action * 3 + 1
			)
	else:
		var next_row := _selected_row + direction
		if next_row >= GRID_ROWS:
			_selected_row = GRID_ROWS
			_selected_action = mini(
				ACTION_KEYS.size() - 1,
				floori(float(_selected_column) * ACTION_KEYS.size() / GRID_COLUMNS)
			)
		elif next_row < 0:
			_selected_row = GRID_ROWS
		else:
			_selected_row = next_row
			_selected_column = mini(
				_selected_column,
				_get_column_count(_selected_row) - 1
			)
	queue_redraw()


func _activate_selected() -> void:
	if _selected_row < GRID_ROWS:
		var key_index := _selected_row * GRID_COLUMNS + _selected_column
		if key_index >= CHARACTER_KEYS.size():
			return
		_append_character(CHARACTER_KEYS[key_index])
		return

	match _selected_action:
		0:
			_delete_character()
		1:
			if PlayerProfile.clear_player_name():
				guest_selected.emit()
		2:
			_confirm_name()


func _confirm_name() -> void:
	if _player_name.is_empty():
		_status = "ENTER HANDLE OR SKIP"
		queue_redraw()
	elif PlayerProfile.set_player_name(_player_name):
		name_confirmed.emit(PlayerProfile.player_name)
	else:
		_status = "HANDLE COULD NOT BE SAVED"
		queue_redraw()


func _select_at(position: Vector2) -> bool:
	for key_index in range(CHARACTER_KEYS.size()):
		var row := floori(float(key_index) / GRID_COLUMNS)
		var column := key_index % GRID_COLUMNS
		if _get_character_rect(row, column).has_point(position):
			_selected_row = row
			_selected_column = column
			queue_redraw()
			return true

	for action_index in range(ACTION_KEYS.size()):
		if _get_action_rect(action_index).has_point(position):
			_selected_row = GRID_ROWS
			_selected_action = action_index
			queue_redraw()
			return true
	return false


func _get_character_rect(row: int, column: int) -> Rect2:
	return Rect2(
		GRID_ORIGIN + Vector2(column, row) * CELL_SIZE,
		CELL_SIZE
	)


func _get_action_rect(action_index: int) -> Rect2:
	return Rect2(44 + action_index * 57, ACTION_Y, 54, 14)


func _get_column_count(row: int) -> int:
	return mini(
		GRID_COLUMNS,
		CHARACTER_KEYS.size() - row * GRID_COLUMNS
	)


func _draw_text_in_rect(
	canvas: CanvasItem,
	text: String,
	rect: Rect2,
	color: Color
) -> void:
	var text_size := PixelFont.measure(text)
	var position := Vector2(
		floorf(rect.position.x + (rect.size.x - text_size.x) / 2.0),
		floorf(rect.position.y + (rect.size.y - text_size.y) / 2.0)
	)
	PixelFont.draw_text(canvas, text, position, color)
