class_name PlayerProfileState
extends Node

signal name_changed(player_name: String)

const MAX_NAME_LENGTH := 16
const SUPPORTED_NAME_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@_.-"
const STATE_PATH := "user://player_profile.json"

var player_name := ""
var identity_chosen := false


func _ready() -> void:
	_load()


func set_player_name(value: String) -> bool:
	var normalized := normalize_name(value)
	var validation_error := get_name_error(normalized)
	if not validation_error.is_empty():
		push_error(validation_error)
		return false
	if not _save(normalized):
		return false

	player_name = normalized
	identity_chosen = true
	name_changed.emit(player_name)
	return true


func clear_player_name() -> bool:
	if not _save("", true):
		return false

	player_name = ""
	identity_chosen = true
	name_changed.emit(player_name)
	return true


func has_player_name() -> bool:
	return not player_name.is_empty()


func get_display_name() -> String:
	return player_name if has_player_name() else "GUEST"


static func normalize_name(value: String) -> String:
	return value.strip_edges().to_upper()


static func get_name_error(value: String) -> String:
	var normalized := normalize_name(value)
	if (
		normalized.is_empty()
		or normalized.length() > MAX_NAME_LENGTH
	):
		return "Player name must contain 1 to %d characters." % MAX_NAME_LENGTH

	for character in normalized:
		if not SUPPORTED_NAME_CHARACTERS.contains(character):
			return "Player name contains unsupported characters."
	return ""


func _load() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return

	var state_file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if state_file == null:
		push_error(
			"Could not open player profile: %s"
			% error_string(FileAccess.get_open_error())
		)
		return

	var parser := JSON.new()
	var parse_error := parser.parse(state_file.get_as_text())
	state_file.close()
	if parse_error != OK:
		push_error(
			"Could not parse player profile at line %d: %s"
			% [parser.get_error_line(), parser.get_error_message()]
		)
		return
	if not parser.data is Dictionary:
		push_error("Player profile root must be an object.")
		return

	identity_chosen = bool(parser.data.get("identity_chosen", false))
	var stored_name := normalize_name(
		String(parser.data.get("player_name", ""))
	)
	if stored_name.is_empty():
		return
	var validation_error := get_name_error(stored_name)
	if not validation_error.is_empty():
		push_error("Stored player profile is invalid: %s" % validation_error)
		return
	player_name = stored_name
	identity_chosen = true


func _save(value: String, chosen: bool = true) -> bool:
	var state_file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if state_file == null:
		push_error(
			"Could not save player profile: %s"
			% error_string(FileAccess.get_open_error())
		)
		return false

	state_file.store_string(JSON.stringify({
		"identity_chosen": chosen,
		"player_name": value,
	}))
	state_file.close()
	return true
