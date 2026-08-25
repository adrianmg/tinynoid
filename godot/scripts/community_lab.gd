class_name CommunityLab
extends Control

signal level_requested(level: Dictionary)
signal back_requested

const VOID := Color("#050611")
const PANEL := Color("#111329")
const RAIL_DARK := Color("#12345b")
const BLUE := Color("#287fc4")
const CYAN := Color("#74ddff")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const MAGENTA := Color("#c967e8")
const ROW_TOP := 61
const ROW_HEIGHT := 22
const VISIBLE_ROWS := 6
const BACK_RECT := Rect2(75, 211, 106, 14)
const PREVIEW_X := 199
const PREVIEW_SIZE := Vector2(29, 14)

var _state: StringName = CommunityCatalog.STATE_LOADING
var _entries: Array[Dictionary] = []
var _selected_index := 0
var _scroll_offset := 0
var _message := ""
var _checking_id := ""
var _notice := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	CommunityCatalog.catalog_updated.connect(_on_catalog_updated)
	CommunityCatalog.level_checked.connect(_on_level_checked)
	_entries = CommunityCatalog.cached_entries()
	if not _entries.is_empty():
		_state = CommunityCatalog.STATE_STALE
	if DisplayServer.get_name() != "headless":
		CommunityCatalog.request_catalog()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(18, 29, 220, 177), PANEL)
	draw_rect(Rect2(18, 29, 220, 2), CYAN)
	draw_rect(Rect2(18, 204, 220, 2), BLUE)
	PixelFont.draw_centered(self, "COMMUNITY LAB", 11, CYAN, 2)
	PixelFont.draw_centered(self, get_status_text(), 40, _status_color())

	if _entries.is_empty():
		_draw_empty_state()
	else:
		_draw_entries()

	var back_selected := _entries.is_empty() or _selected_index == _entries.size()
	if back_selected:
		draw_rect(BACK_RECT, RAIL_DARK)
		draw_rect(Rect2(BACK_RECT.position, Vector2(2, BACK_RECT.size.y)), CYAN)
	PixelFont.draw_centered(
		self,
		"RETURN TO MENU",
		215,
		YELLOW if back_selected else WHITE
	)
	PixelFont.draw_centered(self, "SELECT TO VERIFY ONLINE", 230, CYAN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		UiAudio.play_confirm()
		back_requested.emit()
	elif event.is_action_pressed("ui_up"):
		_select_relative(-1)
	elif event.is_action_pressed("ui_down"):
		_select_relative(1)
	elif event.is_action_pressed("launch") or event.is_action_pressed("ui_accept"):
		_activate_selected()
	else:
		return
	var viewport := get_viewport()
	if is_instance_valid(viewport):
		viewport.set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var hovered := _get_item_at(event.position)
		if hovered >= 0 and hovered != _selected_index:
			_selected_index = hovered
			_ensure_selection_visible()
			UiAudio.play_move()
			queue_redraw()
	elif GamePointer.is_primary_press(event):
		var clicked := _get_item_at(event.position)
		if clicked >= 0:
			_selected_index = clicked
			UiAudio.play_confirm()
			accept_event()
			_activate_selected()


func get_entries() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry in _entries:
		copy.append(entry.duplicate(true))
	return copy


func get_selected_index() -> int:
	return _selected_index


func get_status_text() -> String:
	if not _checking_id.is_empty():
		return "VERIFYING ONLINE - PLEASE WAIT"
	if not _notice.is_empty():
		return _notice.to_upper()
	match _state:
		CommunityCatalog.STATE_LOADING:
			return "LOADING COMMUNITY LEVELS"
		CommunityCatalog.STATE_EMPTY:
			return "NO COMMUNITY LEVELS YET"
		CommunityCatalog.STATE_STALE:
			return "OFFLINE CACHE - RECHECK REQUIRED"
		CommunityCatalog.STATE_ERROR:
			return "COMMUNITY SERVICE OFFLINE"
	return "%d LEVELS ONLINE" % _entries.size()


func _draw_empty_state() -> void:
	var primary := "THE LAB IS EMPTY"
	var secondary := "TRY AGAIN LATER"
	if _state == CommunityCatalog.STATE_LOADING:
		primary = "CONTACTING THE LAB"
		secondary = "LOADING..."
	elif _state == CommunityCatalog.STATE_ERROR:
		primary = "COULD NOT REACH THE LAB"
		secondary = _fit_text(_message.to_upper(), 208)
	PixelFont.draw_centered(self, primary, 103, YELLOW)
	PixelFont.draw_centered(self, secondary, 116, WHITE)


func _draw_entries() -> void:
	var visible_end := mini(_scroll_offset + VISIBLE_ROWS, _entries.size())
	for entry_index in range(_scroll_offset, visible_end):
		var row_index := entry_index - _scroll_offset
		var row_rect := Rect2(26, ROW_TOP + row_index * ROW_HEIGHT, 204, 20)
		if entry_index == _selected_index:
			draw_rect(row_rect, RAIL_DARK)
			draw_rect(Rect2(row_rect.position, Vector2(2, row_rect.size.y)), CYAN)
		var entry: Dictionary = _entries[entry_index]
		var title := "%s — BY %s" % [
			String(entry.level_name),
			CommunityCatalogClient.format_creator_name(
				String(entry.creator_display_name)
			),
		]
		PixelFont.draw_text(
			self,
			_fit_text(title, 164),
			Vector2(31, row_rect.position.y + 3),
			YELLOW if entry_index == _selected_index else WHITE
		)
		var status_text := (
			"UNREVIEWED"
			if String(entry.status) == "pending"
			else "LISTED"
		)
		PixelFont.draw_text(
			self,
			status_text,
			Vector2(31, row_rect.position.y + 11),
			MAGENTA if String(entry.status) == "pending" else CYAN
		)
		_draw_level_preview(
			entry,
			Vector2(PREVIEW_X, row_rect.position.y + 3),
			entry_index == _selected_index
		)


func _draw_level_preview(
	entry: Dictionary,
	position: Vector2,
	selected: bool
) -> void:
	var preview_rect := Rect2(position, PREVIEW_SIZE)
	draw_rect(preview_rect, VOID)
	draw_rect(
		preview_rect,
		YELLOW if selected else BLUE,
		false,
		1.0
	)
	var layout: Array = entry.get("layout", [])
	var grid_origin := position + Vector2(1, 2)
	for row_index in range(mini(layout.size(), 10)):
		var row := String(layout[row_index])
		for column_index in range(mini(row.length(), 13)):
			var code := row.substr(column_index, 1)
			if code == ".":
				continue
			draw_rect(
				Rect2(
					grid_origin + Vector2(column_index * 2, row_index),
					Vector2(2, 1)
				),
				BrickRules.get_color(code)
			)


func _select_relative(direction: int) -> void:
	var item_count := _entries.size() + 1
	_selected_index = posmod(_selected_index + direction, item_count)
	_ensure_selection_visible()
	UiAudio.play_move()
	queue_redraw()


func _activate_selected() -> void:
	UiAudio.play_confirm()
	if _entries.is_empty() or _selected_index == _entries.size():
		back_requested.emit()
		return
	if not _checking_id.is_empty():
		return
	_notice = ""
	_checking_id = String(_entries[_selected_index].id)
	_message = ""
	queue_redraw()
	if not CommunityCatalog.request_exact(_checking_id):
		_checking_id = ""
		queue_redraw()


func show_notice(message: String) -> void:
	_notice = message
	queue_redraw()


func _ensure_selection_visible() -> void:
	if _selected_index >= _entries.size():
		return
	if _selected_index < _scroll_offset:
		_scroll_offset = _selected_index
	elif _selected_index >= _scroll_offset + VISIBLE_ROWS:
		_scroll_offset = _selected_index - VISIBLE_ROWS + 1


func _get_item_at(position: Vector2) -> int:
	if BACK_RECT.has_point(position):
		return _entries.size()
	for row_index in range(VISIBLE_ROWS):
		var entry_index := _scroll_offset + row_index
		if entry_index >= _entries.size():
			break
		var rect := Rect2(26, ROW_TOP + row_index * ROW_HEIGHT, 204, 20)
		if rect.has_point(position):
			return entry_index
	return -1


func _on_catalog_updated(
	state: StringName,
	entries: Array[Dictionary],
	_fetched_at: String,
	message: String
) -> void:
	_state = state
	_entries = entries
	_message = message
	_selected_index = clampi(_selected_index, 0, _entries.size())
	_ensure_selection_visible()
	queue_redraw()


func _on_level_checked(
	level_id: String,
	playable: bool,
	level: Dictionary,
	message: String
) -> void:
	if level_id != _checking_id:
		return
	_checking_id = ""
	if playable and CommunityCatalog.is_confirmed_playable(level_id):
		level_requested.emit(level)
		return
	var cached_entries := CommunityCatalog.cached_entries()
	var remains_cached := cached_entries.any(
		func(entry: Dictionary) -> bool:
			return String(entry.get("id", "")) == level_id
	)
	if not remains_cached:
		_entries = cached_entries
		_selected_index = clampi(_selected_index, 0, _entries.size())
		_ensure_selection_visible()
		_state = (
			CommunityCatalog.STATE_EMPTY
			if _entries.is_empty()
			else CommunityCatalog.STATE_STALE
		)
		_notice = (
			message
			if not message.is_empty()
			else "Community level is no longer available."
		)
		_message = ""
		queue_redraw()
		return
	_state = (
		CommunityCatalog.STATE_STALE
		if not _entries.is_empty()
		else CommunityCatalog.STATE_ERROR
	)
	_message = message
	queue_redraw()


func _status_color() -> Color:
	if _state == CommunityCatalog.STATE_ERROR or _state == CommunityCatalog.STATE_STALE:
		return MAGENTA
	if _state == CommunityCatalog.STATE_EMPTY:
		return YELLOW
	return CYAN


func _fit_text(text: String, maximum_width: int) -> String:
	if PixelFont.measure(text).x <= maximum_width:
		return text
	var shortened := text
	while shortened.length() > 3:
		shortened = shortened.left(shortened.length() - 1)
		if PixelFont.measure(shortened + "...").x <= maximum_width:
			return shortened + "..."
	return "..."
