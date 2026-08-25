class_name DailyChallengeScreen
extends Control

signal play_requested
signal back_requested

const PANEL := Color("#111329")
const RAIL_DARK := Color("#12345b")
const BLUE := Color("#287fc4")
const CYAN := Color("#74ddff")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const MAGENTA := Color("#c967e8")
const ROW_Y := 104
const ROW_HEIGHT := 10
const VISIBLE_ROWS := 7
const OPTION_Y := [187, 204]

var _view: Dictionary = {}
var _selected_index := 0
var _requested_daily_id := ""
var _scroll_offset := 0
var _touch_scroll_remainder := 0.0


func configure_daily_id(daily_id: String) -> void:
	_requested_daily_id = daily_id


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	DailyChallenge.changed.connect(_on_daily_changed)
	_view = DailyChallenge.open(_requested_daily_id)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(18, 42, 220, 132), PANEL)
	draw_rect(Rect2(18, 42, 220, 2), CYAN)
	draw_rect(Rect2(18, 172, 220, 2), BLUE)
	PixelFont.draw_centered(self, "DAILY CARTRIDGE", 10, CYAN, 2)

	var cartridge: Dictionary = _view.get("cartridge", {})
	var level: Dictionary = cartridge.get("level", {})
	var daily_id := String(cartridge.get("daily_id", _requested_daily_id))
	PixelFont.draw_centered(
		self,
		daily_id if not daily_id.is_empty() else "UTC DAILY RUN",
		32,
		YELLOW
	)
	if not level.is_empty():
		PixelFont.draw_centered(
			self,
			_fit_text(String(level.get("level_name", "DAILY LEVEL")), 204),
			50,
			WHITE
		)
		PixelFont.draw_centered(
			self,
			"BY %s" % CommunityCatalogClient.format_creator_name(
				String(level.get("creator_display_name", "UNKNOWN"))
			),
			62,
			MAGENTA
		)

	var scores: Array = _view.get("top_scores", [])
	var message := String(_view.get("message", ""))
	if not message.is_empty():
		PixelFont.draw_centered(self, _fit_text(message, 204), 78, MAGENTA)
	elif scores.is_empty():
		PixelFont.draw_centered(self, "WORLD TOP SCORES", 78, CYAN)
	else:
		var end_index := mini(
			scores.size(),
			_scroll_offset + VISIBLE_ROWS
		)
		PixelFont.draw_centered(
			self,
			"WORLD %03d-%03d / %03d" % [
				_scroll_offset + 1,
				end_index,
				scores.size(),
			],
			78,
			CYAN
		)

	if scores.is_empty():
		PixelFont.draw_centered(self, "NO DAILY SCORES YET", 126, WHITE)
	else:
		var visible_end := mini(
			scores.size(),
			_scroll_offset + VISIBLE_ROWS
		)
		for index in range(_scroll_offset, visible_end):
			var entry: Dictionary = scores[index]
			var y := ROW_Y + (index - _scroll_offset) * ROW_HEIGHT
			PixelFont.draw_text(
				self,
				"%02d" % int(entry.get("rank", index + 1)),
				Vector2(28, y),
				YELLOW
			)
			PixelFont.draw_text(
				self,
				_fit_text(String(entry.get("player_name", "PLAYER")), 100),
				Vector2(54, y),
				WHITE
			)
			PixelFont.draw_text(
				self,
				"%06d" % int(entry.get("score", 0)),
				Vector2(178, y),
				CYAN
			)

	for option_index in range(2):
		var rect := _option_rect(option_index)
		if option_index == _selected_index:
			draw_rect(rect, RAIL_DARK)
			draw_rect(Rect2(rect.position, Vector2(2, rect.size.y)), CYAN)
		var enabled := option_index == 1 or _can_play()
		PixelFont.draw_centered(
			self,
			"PLAY DAILY" if option_index == 0 else "RETURN TO MENU",
			OPTION_Y[option_index],
			(
				YELLOW
				if option_index == _selected_index and enabled
				else WHITE
				if enabled
				else BLUE
			)
		)
	PixelFont.draw_centered(
		self,
		"SAME CARTRIDGE FOR EVERYONE",
		228,
		CYAN
	)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back_requested.emit()
	elif event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down"):
		_selected_index = 1 - _selected_index
		UiAudio.play_move()
		queue_redraw()
	elif event.is_action_pressed("ui_left"):
		_scroll_scores(-VISIBLE_ROWS)
	elif event.is_action_pressed("ui_right"):
		_scroll_scores(VISIBLE_ROWS)
	elif event.is_action_pressed("launch") or event.is_action_pressed("ui_accept"):
		_activate_selected()
	else:
		return
	get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	if GamePointer.is_primary_drag(event):
		_touch_scroll_remainder -= event.relative.y
		while absf(_touch_scroll_remainder) >= ROW_HEIGHT:
			var direction := signi(_touch_scroll_remainder)
			_scroll_scores(direction)
			_touch_scroll_remainder -= direction * ROW_HEIGHT
		accept_event()
	elif event is InputEventMouseMotion:
		var option := _option_at(event.position)
		if option >= 0 and option != _selected_index:
			_selected_index = option
			UiAudio.play_move()
			queue_redraw()
	elif GamePointer.is_primary_press(event):
		var option := _option_at(event.position)
		if option >= 0:
			_selected_index = option
			accept_event()
			_activate_selected()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_scores(-1)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_scores(1)
			accept_event()


func _activate_selected() -> void:
	UiAudio.play_confirm()
	if _selected_index == 0:
		if _can_play():
			play_requested.emit()
	else:
		back_requested.emit()


func _can_play() -> bool:
	var cartridge: Dictionary = _view.get("cartridge", {})
	return (
		String(_view.get("phase", "")) == String(DailyChallenge.PHASE_READY)
		and bool(_view.get("live", false))
		and bool(cartridge.get("playable_now", false))
	)


func _option_rect(index: int) -> Rect2:
	return Rect2(52, OPTION_Y[index] - 4, 152, 12)


func _option_at(position: Vector2) -> int:
	for index in range(2):
		if _option_rect(index).has_point(position):
			return index
	return -1


func _on_daily_changed(view: Dictionary) -> void:
	_view = view.duplicate(true)
	var scores: Array = _view.get("top_scores", [])
	_scroll_offset = mini(
		_scroll_offset,
		maxi(0, scores.size() - VISIBLE_ROWS)
	)
	queue_redraw()


func _scroll_scores(direction: int) -> void:
	var scores: Array = _view.get("top_scores", [])
	var maximum := maxi(0, scores.size() - VISIBLE_ROWS)
	_scroll_offset = clampi(_scroll_offset + direction, 0, maximum)
	UiAudio.play_move()
	queue_redraw()


func _fit_text(text: String, maximum_width: int) -> String:
	if PixelFont.measure(text).x <= maximum_width:
		return text
	var shortened := text
	while shortened.length() > 1:
		shortened = shortened.left(shortened.length() - 1)
		if PixelFont.measure(shortened + "...").x <= maximum_width:
			return shortened + "..."
	return "..."
