class_name RetroHud
extends Control

const LAUNCH_PROMPT := "Press spacebar to fire the ball"
const VOID := Color("#050611")
const WHITE := Color("#f7f4ff")
const CYAN := Color("#74ddff")
const YELLOW := Color("#ffd84a")

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
	_on_state_changed(GameSession.score, GameSession.balls_remaining, GameSession.level)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 256, 24), VOID)

	PixelFont.draw_text(self, "SCORE", Vector2(8, 3), WHITE)
	PixelFont.draw_text(self, "%06d" % _score, Vector2(8, 11), YELLOW)

	PixelFont.draw_text(self, "STAGE", Vector2(108, 3), WHITE)
	PixelFont.draw_text(self, "%02d" % _stage, Vector2(116, 11), CYAN)

	PixelFont.draw_text(self, "BALL", Vector2(196, 3), WHITE)
	PixelFont.draw_text(self, "%02d" % _balls, Vector2(204, 11), YELLOW)

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
	if _power_up_time_left <= 0.0:
		return

	_power_up_time_left = maxf(0.0, _power_up_time_left - delta)
	queue_redraw()


func _on_state_changed(score: int, balls_remaining: int, stage: int) -> void:
	_score = score
	_balls = balls_remaining
	_stage = stage
	queue_redraw()


func set_launch_ready(is_ready: bool) -> void:
	_launch_ready = is_ready
	queue_redraw()


func is_launch_ready() -> bool:
	return _launch_ready


func show_power_up(label: String, color: Color) -> void:
	_power_up_label = label
	_power_up_color = color
	_power_up_time_left = 1.5
	queue_redraw()


func clear_power_up_status() -> void:
	_power_up_label = ""
	_power_up_time_left = 0.0
	queue_redraw()
