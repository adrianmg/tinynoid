class_name HighScoresScreen
extends Control

signal back_requested

const PANEL := Color("#111329")
const RAIL_DARK := Color("#12345b")
const BLUE := Color("#287fc4")
const CYAN := Color("#74ddff")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const MAGENTA := Color("#c967e8")
const VISIBLE_ROWS := 14
const ROW_Y := 57
const ROW_HEIGHT := 10
const BACK_RECT := Rect2(207, 8, 30, 13)
const ATTRIBUTION_RECT := Rect2(76, 216, 104, 10)

var _entries: Array[Dictionary] = []
var _state := Leaderboard.STATE_LOADING
var _selected_index := 0
var _scroll_offset := 0
var _touch_scroll_remainder := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	AvatarCache.avatar_updated.connect(_on_avatar_updated)
	Leaderboard.top_scores_updated.connect(_on_top_scores_updated)
	_entries = Leaderboard.cached_top_scores()
	if not _entries.is_empty():
		_state = Leaderboard.STATE_STALE
	elif not Leaderboard.cached_local_scores().is_empty():
		_entries = Leaderboard.cached_local_scores()
		_state = Leaderboard.STATE_LOCAL
	if DisplayServer.get_name() != "headless":
		Leaderboard.request_top_scores()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(18, 28, 220, 176), PANEL)
	draw_rect(Rect2(18, 28, 220, 2), CYAN)
	draw_rect(Rect2(18, 202, 220, 2), BLUE)
	PixelFont.draw_centered(self, "HIGH SCORES", 10, CYAN, 2)
	PixelFont.draw_text(self, "BACK", Vector2(214, 12), WHITE)
	PixelFont.draw_text(self, "#", Vector2(24, 43), WHITE)
	PixelFont.draw_text(self, "PLAYER", Vector2(54, 43), WHITE)
	PixelFont.draw_text(self, "ST", Vector2(142, 43), WHITE)
	PixelFont.draw_text(self, "SCORE", Vector2(185, 43), WHITE)

	if _entries.is_empty():
		PixelFont.draw_centered(self, _empty_state_text(), 112, _state_color())
	else:
		var visible_end := mini(
			_entries.size(),
			_scroll_offset + VISIBLE_ROWS
		)
		for entry_index in range(_scroll_offset, visible_end):
			_draw_entry(
				entry_index,
				ROW_Y + (entry_index - _scroll_offset) * ROW_HEIGHT
			)

	PixelFont.draw_centered(self, _range_text(), 211, _state_color())
	PixelFont.draw_centered(self, "AVATARS BY UNAVATAR", 220, CYAN)
	PixelFont.draw_centered(self, "ARROWS SCROLL  FIRE REFRESH  ESC BACK", 232, WHITE)


func _unhandled_input(event: InputEvent) -> void:
	var viewport := get_viewport()
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
	elif event.is_action_pressed("ui_up"):
		_select_relative(-1)
	elif event.is_action_pressed("ui_down"):
		_select_relative(1)
	elif event.is_action_pressed("ui_left"):
		_select_relative(-VISIBLE_ROWS)
	elif event.is_action_pressed("ui_right"):
		_select_relative(VISIBLE_ROWS)
	elif event.is_action_pressed("launch") or event.is_action_pressed("ui_accept"):
		Leaderboard.request_top_scores()
	else:
		return

	UiAudio.play_move()
	if is_instance_valid(viewport):
		viewport.set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenDrag and event.index == 0:
		_touch_scroll_remainder -= event.relative.y
		while absf(_touch_scroll_remainder) >= ROW_HEIGHT:
			var direction := signi(_touch_scroll_remainder)
			_select_relative(direction)
			_touch_scroll_remainder -= direction * ROW_HEIGHT
		accept_event()
	elif event is InputEventMouseMotion:
		var row := _get_row_at(event.position)
		if row >= 0 and row != _selected_index:
			_selected_index = row
			_ensure_selected_visible()
			UiAudio.play_move()
			queue_redraw()
	elif GamePointer.is_primary_press(event):
		if BACK_RECT.has_point(event.position):
			accept_event()
			back_requested.emit()
		elif ATTRIBUTION_RECT.has_point(event.position):
			accept_event()
			OS.shell_open("https://unavatar.io")
		else:
			var row := _get_row_at(event.position)
			if row >= 0:
				_selected_index = row
				_ensure_selected_visible()
				accept_event()
				queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_select_relative(-1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_select_relative(1)
			accept_event()


func get_selected_index() -> int:
	return _selected_index


func get_scroll_offset() -> int:
	return _scroll_offset


func _draw_entry(entry_index: int, y: float) -> void:
	var entry := _entries[entry_index]
	var selected := entry_index == _selected_index
	if selected:
		draw_rect(Rect2(21, y - 2, 214, 9), RAIL_DARK)
		draw_rect(Rect2(21, y - 2, 1, 9), CYAN)

	PixelFont.draw_text(
		self,
		"%03d" % int(entry.get("rank", entry_index + 1)),
		Vector2(24, y),
		YELLOW if selected else WHITE
	)
	PixelAvatar.draw(
		self,
		String(entry.get("player_name", "PLAYER")),
		Vector2(42, y - 1)
	)
	PixelFont.draw_text(
		self,
		String(entry.get("player_name", "PLAYER")),
		Vector2(54, y),
		YELLOW if selected else WHITE
	)
	PixelFont.draw_text(
		self,
		"%02d" % int(entry.get("completed_stage", 1)),
		Vector2(142, y),
		CYAN
	)
	PixelFont.draw_text(
		self,
		"%06d" % int(entry.get("score", 0)),
		Vector2(185, y),
		YELLOW
	)


func _select_relative(direction: int) -> void:
	if _entries.is_empty():
		return
	_selected_index = clampi(
		_selected_index + direction,
		0,
		_entries.size() - 1
	)
	_ensure_selected_visible()
	queue_redraw()


func _ensure_selected_visible() -> void:
	if _selected_index < _scroll_offset:
		_scroll_offset = _selected_index
	elif _selected_index >= _scroll_offset + VISIBLE_ROWS:
		_scroll_offset = _selected_index - VISIBLE_ROWS + 1


func _get_row_at(position: Vector2) -> int:
	if position.y < ROW_Y - 2:
		return -1
	var visible_row := floori((position.y - (ROW_Y - 2)) / ROW_HEIGHT)
	if visible_row < 0 or visible_row >= VISIBLE_ROWS:
		return -1
	var entry_index := _scroll_offset + visible_row
	return entry_index if entry_index < _entries.size() else -1


func _empty_state_text() -> String:
	match _state:
		Leaderboard.STATE_LOADING:
			return "LOADING SCORES"
		Leaderboard.STATE_ERROR:
			return "SCORES OFFLINE"
		_:
			return "NO SCORES YET"


func _range_text() -> String:
	if _entries.is_empty():
		return "OFFLINE CACHE EMPTY" if _state == Leaderboard.STATE_ERROR else ""
	var end_index := mini(
		_entries.size(),
		_scroll_offset + VISIBLE_ROWS
	)
	var prefix := ""
	if _state == Leaderboard.STATE_STALE:
		prefix = "OFFLINE  "
	elif _state == Leaderboard.STATE_LOCAL:
		prefix = "LOCAL  "
	return "%s%03d-%03d / %03d" % [
		prefix,
		_scroll_offset + 1,
		end_index,
		_entries.size(),
	]


func _state_color() -> Color:
	return (
		MAGENTA
		if _state == Leaderboard.STATE_STALE
		or _state == Leaderboard.STATE_ERROR
		or _state == Leaderboard.STATE_LOCAL
		else CYAN
	)


func _on_top_scores_updated(
	state: StringName,
	entries: Array[Dictionary],
	_fetched_at: String
) -> void:
	_state = state
	_entries = entries
	if (
		_entries.is_empty()
		and (
			state == Leaderboard.STATE_EMPTY
			or state == Leaderboard.STATE_ERROR
		)
		and not Leaderboard.cached_local_scores().is_empty()
	):
		_entries = Leaderboard.cached_local_scores()
		_state = Leaderboard.STATE_LOCAL
	_selected_index = mini(
		_selected_index,
		maxi(0, _entries.size() - 1)
	)
	_ensure_selected_visible()
	queue_redraw()


func _on_avatar_updated(_handle: String) -> void:
	queue_redraw()
