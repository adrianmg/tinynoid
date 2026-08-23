class_name AudioSettingsState
extends Node

signal level_changed(level: int)

const MIN_LEVEL := 0
const MAX_LEVEL := 3
const VOLUME_DB := {
	0: -12.0,
	1: -12.0,
	2: -6.0,
	3: 0.0,
}

var level := MAX_LEVEL


func _ready() -> void:
	_apply_level()


func set_level(next_level: int) -> void:
	assert(
		next_level >= MIN_LEVEL and next_level <= MAX_LEVEL,
		"Sound level must be between OFF and III."
	)
	if next_level == level:
		return

	level = next_level
	_apply_level()
	level_changed.emit(level)


func cycle_level(direction: int) -> void:
	assert(direction != 0, "Sound level cycle requires a direction.")
	set_level(
		wrapi(
			level + signi(direction),
			MIN_LEVEL,
			MAX_LEVEL + 1
		)
	)


func get_level_label() -> String:
	match level:
		3:
			return "III"
		2:
			return "II"
		1:
			return "I"
		0:
			return "OFF"

	return "III"


func is_enabled() -> bool:
	return level > MIN_LEVEL


func _apply_level() -> void:
	var master_bus := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master_bus, not is_enabled())
	AudioServer.set_bus_volume_db(master_bus, VOLUME_DB[level])

