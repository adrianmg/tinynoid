class_name StageClearScreen
extends Control

signal replay_requested

const VOID := Color("#050611")
const PANEL := Color("#111329")
const CYAN := Color("#74ddff")
const GREEN := Color("#56d46f")
const WHITE := Color("#f7f4ff")
const YELLOW := Color("#ffd84a")
const BLUE := Color("#287fc4")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(28, 64, 200, 112), PANEL)
	draw_rect(Rect2(28, 64, 200, 2), CYAN)
	draw_rect(Rect2(28, 174, 200, 2), BLUE)
	PixelFont.draw_centered(self, "TINYNOID", 10, CYAN)
	var title := (
		"CAMPAIGN CLEAR"
		if GameSession.level >= LevelCatalog.STAGE_COUNT
		else "STAGE %02d CLEAR" % GameSession.level
	)
	PixelFont.draw_centered(self, title, 84, GREEN, 2)
	PixelFont.draw_centered(self, "SCORE", 118, WHITE)
	PixelFont.draw_centered(self, "%06d" % GameSession.score, 128, YELLOW)
	var prompt := (
		"TAP OR FIRE FOR MENU"
		if GameSession.level >= LevelCatalog.STAGE_COUNT
		else "TAP OR FIRE TO CONTINUE"
	)
	PixelFont.draw_centered(self, prompt, 154, CYAN)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") or event.is_action_pressed("launch"):
		get_viewport().set_input_as_handled()
		replay_requested.emit()


func _gui_input(event: InputEvent) -> void:
	if GamePointer.is_primary_press(event):
		accept_event()
		replay_requested.emit()
