class_name GameOverScreen
extends Control

signal new_game_requested

const VOID := Color("#050611")
const PANEL := Color("#111329")
const RED := Color("#f15b68")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const BLUE := Color("#287fc4")
const CYAN := Color("#74ddff")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(36, 64, 184, 112), PANEL)
	draw_rect(Rect2(36, 64, 184, 2), RED)
	draw_rect(Rect2(36, 174, 184, 2), BLUE)
	PixelFont.draw_centered(self, "TINYNOID", 10, CYAN)
	PixelFont.draw_centered(self, "GAME OVER", 84, RED, 2)
	PixelFont.draw_centered(self, "SCORE", 118, WHITE)
	PixelFont.draw_centered(self, "%06d" % GameSession.score, 128, YELLOW)
	PixelFont.draw_centered(self, "TAP OR FIRE TO RETRY", 154, WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") or event.is_action_pressed("launch"):
		get_viewport().set_input_as_handled()
		new_game_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if GamePointer.is_primary_press(event):
		accept_event()
		new_game_requested.emit()
