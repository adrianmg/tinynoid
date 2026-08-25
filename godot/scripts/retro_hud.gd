class_name RetroHud
extends Control

const LAUNCH_PROMPT := "Press SPACEBAR or tap to fire"
const VOID := Color("#050611")
const WHITE := Color("#f7f4ff")
const CYAN := Color("#74ddff")
const YELLOW := Color("#ffd84a")
const STAGE_COLUMN_WIDTH := 116

var _score := 0
var _balls := 3
var _stage := 1
var _launch_ready := true
var _power_up_label := ""
var _power_up_color := CYAN
var _power_up_time_left := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	GameSession.state_changed.connect(_on_state_changed)
	PlayerProfile.name_changed.connect(_on_player_name_changed)
	_on_state_changed(GameSession.score, GameSession.balls_remaining, GameSession.level)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 256, 24), VOID)

	PixelFont.draw_text(self, "SCORE", Vector2(8, 3), WHITE)
	PixelFont.draw_text(self, "%06d" % _score, Vector2(8, 11), YELLOW)

	PixelFont.draw_text(self, "STAGE", Vector2(108, 3), WHITE)
	if GameSession.is_community_run():
		_draw_community_stage()
	else:
		PixelFont.draw_text(self, "%02d" % _stage, Vector2(116, 11), CYAN)

	PixelFont.draw_text(self, "BALL", Vector2(196, 3), WHITE)
	PixelFont.draw_text(self, "%02d" % _balls, Vector2(204, 11), YELLOW)
	if PlayerProfile.has_player_name() and not GameSession.is_community_run():
		PixelAvatar.draw(
			self,
			PlayerProfile.player_name,
			Vector2(184, 9)
		)

	if _launch_ready:
		PixelFont.draw_centered(self, LAUNCH_PROMPT, 231, CYAN)

	if _power_up_time_left > 0.0:
		PixelFont.draw_centered(
			self,
			_power_up_label,
			198,
			_power_up_color
		)


func _process(delta: float) -> void:
	if _power_up_time_left > 0.0:
		_power_up_time_left = maxf(0.0, _power_up_time_left - delta)
		queue_redraw()


func _draw_community_stage() -> void:
	var community := GameSession.community_level
	PixelFont.draw_centered(
		self,
		get_stage_value_text(),
		9,
		CYAN
	)
	var author := get_community_author_text()
	var author_width := PixelFont.measure(author).x
	var group_width := 8.0 + 2.0 + author_width
	var group_x := floorf((256.0 - group_width) / 2.0)
	PixelAvatar.draw(
		self,
		String(community.get("creator_display_name", "")),
		Vector2(group_x, 15)
	)
	PixelFont.draw_text(
		self,
		author,
		Vector2(group_x + 10.0, 17),
		WHITE
	)


func get_stage_value_text() -> String:
	if not GameSession.is_community_run():
		return "%02d" % _stage
	return _fit_text(
		String(GameSession.community_level.get("level_name", "LEVEL")),
		STAGE_COLUMN_WIDTH
	)


func get_community_author_text() -> String:
	if not GameSession.is_community_run():
		return ""
	return CommunityCatalogClient.format_creator_name(
		String(
			GameSession.community_level.get(
				"creator_display_name",
				"UNKNOWN"
			)
		)
	)


func _on_state_changed(score: int, balls_remaining: int, stage: int) -> void:
	_score = score
	_balls = balls_remaining
	_stage = stage
	queue_redraw()


func _on_player_name_changed(_player_name: String) -> void:
	queue_redraw()


func set_launch_ready(is_ready: bool) -> void:
	_launch_ready = is_ready
	queue_redraw()


func is_launch_ready() -> bool:
	return _launch_ready


func show_power_up(
	label: String,
	color: Color,
	duration: float = 1.5
) -> void:
	_power_up_label = label
	_power_up_color = color
	_power_up_time_left = duration
	queue_redraw()


func get_power_up_label() -> String:
	return _power_up_label


func get_power_up_time_left() -> float:
	return _power_up_time_left


func clear_power_up_status() -> void:
	_power_up_label = ""
	_power_up_time_left = 0.0
	queue_redraw()


func _fit_text(text: String, maximum_width: int) -> String:
	if PixelFont.measure(text).x <= maximum_width:
		return text
	var shortened := text
	while shortened.length() > 3:
		shortened = shortened.left(shortened.length() - 1)
		if PixelFont.measure(shortened + "...").x <= maximum_width:
			return shortened + "..."
	return "..."
