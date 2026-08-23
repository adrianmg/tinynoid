class_name DisplayControllerState
extends Node

signal mode_changed(label: String)

enum WindowMode {
	SCALE_2X,
	SCALE_3X,
	FULLSCREEN,
}

const LOGICAL_SIZE := Vector2i(256, 240)

var mode := WindowMode.SCALE_3X
var _windowed_scale := 3


func _ready() -> void:
	call_deferred("_apply_windowed_scale", _windowed_scale)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return

	if event.keycode == KEY_F2:
		set_window_scale(2)
	elif event.keycode == KEY_F3:
		set_window_scale(3)
	elif event.keycode == KEY_F11 or (
		event.keycode == KEY_ENTER and event.alt_pressed
	):
		toggle_fullscreen()
	else:
		return

	get_viewport().set_input_as_handled()


func set_window_scale(scale: int) -> void:
	assert(scale == 2 or scale == 3, "Window scale must be 2x or 3x.")
	_windowed_scale = scale
	mode = WindowMode.SCALE_2X if scale == 2 else WindowMode.SCALE_3X
	_apply_windowed_scale(scale)
	mode_changed.emit(get_mode_label())


func set_fullscreen() -> void:
	mode = WindowMode.FULLSCREEN
	if not _is_headless():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	mode_changed.emit(get_mode_label())


func toggle_fullscreen() -> void:
	if mode == WindowMode.FULLSCREEN:
		set_window_scale(_windowed_scale)
	else:
		set_fullscreen()


func cycle_window_mode(direction: int = 1) -> void:
	var modes := [
		WindowMode.SCALE_2X,
		WindowMode.SCALE_3X,
		WindowMode.FULLSCREEN,
	]
	var current_index := modes.find(mode)
	var next_index := posmod(current_index + signi(direction), modes.size())

	match modes[next_index]:
		WindowMode.SCALE_2X:
			set_window_scale(2)
		WindowMode.SCALE_3X:
			set_window_scale(3)
		WindowMode.FULLSCREEN:
			set_fullscreen()


func get_mode_label() -> String:
	match mode:
		WindowMode.SCALE_2X:
			return "2X"
		WindowMode.SCALE_3X:
			return "3X"
		WindowMode.FULLSCREEN:
			return "FULL"

	return "3X"


func _apply_windowed_scale(scale: int) -> void:
	if _is_headless():
		return

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	var target_size := LOGICAL_SIZE * scale
	DisplayServer.window_set_size(target_size)

	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var centered_position := usable_rect.position + (usable_rect.size - target_size) / 2
	DisplayServer.window_set_position(centered_position)


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"

