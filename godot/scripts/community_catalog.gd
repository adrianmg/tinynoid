class_name CommunityCatalogClient
extends Node

signal catalog_updated(
	state: StringName,
	entries: Array[Dictionary],
	fetched_at: String,
	message: String
)
signal level_checked(
	level_id: String,
	playable: bool,
	level: Dictionary,
	message: String
)

const SCHEMA_VERSION := 1
const GRID_COLUMNS := 13
const GRID_ROWS := 10
const MIN_DESTRUCTIBLE := 8
const MAX_POPULATED := 100
const MAX_ENTRIES := 100
const API_BASE := "https://ugkygoijpqrreooylpnc.supabase.co/functions/v1"
const PUBLISHABLE_KEY := "sb_publishable_GMQxCnYtLe3qCkV1Nc3N2w_5JXyve-X"
const CATALOG_URL := API_BASE + "/community-levels?limit=100"
const CACHE_PATH := "user://community_levels.json"
const REQUEST_TIMEOUT := 8.0
const ALLOWED_CODES := ".WOCGRBPYSX"
const ALLOWED_DISPLAY_CHARACTERS := "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 @._-"

const STATE_LOADING := &"loading"
const STATE_READY := &"ready"
const STATE_EMPTY := &"empty"
const STATE_STALE := &"stale"
const STATE_ERROR := &"error"
const STATE_CHECKING := &"checking"

var _entries: Array[Dictionary] = []
var _fetched_at := ""
var _catalog_request: HTTPRequest
var _exact_request: HTTPRequest
var _catalog_in_flight := false
var _exact_in_flight := false
var _requested_id := ""
var _confirmed_levels: Dictionary = {}


func _ready() -> void:
	_load_cache()
	_catalog_request = _create_request(_on_catalog_completed)
	_exact_request = _create_request(_on_exact_completed)


func request_catalog() -> void:
	if _catalog_in_flight:
		return
	_catalog_in_flight = true
	_confirmed_levels.clear()
	catalog_updated.emit(STATE_LOADING, cached_entries(), _fetched_at, "")
	var error := _catalog_request.request(
		CATALOG_URL,
		_request_headers(),
		HTTPClient.METHOD_GET
	)
	if error != OK:
		_catalog_in_flight = false
		_emit_catalog_failure(
			"Could not start Community Lab request: %s" % error_string(error)
		)


func request_exact(level_id: String) -> bool:
	if _exact_in_flight:
		return false
	if not is_valid_id(level_id):
		level_checked.emit(level_id, false, {}, "Invalid community level id.")
		return false
	_confirmed_levels.erase(level_id)
	_exact_in_flight = true
	_requested_id = level_id
	var error := _exact_request.request(
		"%s/community-levels?id=%s" % [API_BASE, level_id],
		_request_headers(),
		HTTPClient.METHOD_GET
	)
	if error != OK:
		_exact_in_flight = false
		_requested_id = ""
		level_checked.emit(
			level_id,
			false,
			{},
			"Could not start freshness check: %s" % error_string(error)
		)
		return false
	return true


func cached_entries() -> Array[Dictionary]:
	return _duplicate_entries(_entries)


func get_fetched_at() -> String:
	return _fetched_at


func is_confirmed_playable(level_id: String) -> bool:
	return _confirmed_levels.has(level_id)


static func validate_level(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": "Community level must be an object."}
	var source: Dictionary = value
	var required_fields := [
		"id",
		"schema_version",
		"level_name",
		"creator_display_name",
		"layout",
		"status",
		"populated_count",
		"created_at",
	]
	for field in required_fields:
		if not source.has(field):
			return {
				"ok": false,
				"error": "Community level is missing %s." % field,
			}

	var level_id := String(source.id)
	if typeof(source.id) != TYPE_STRING or not is_valid_id(level_id):
		return {"ok": false, "error": "Community level id is invalid."}
	if not _is_exact_integer(source.schema_version, SCHEMA_VERSION):
		return {"ok": false, "error": "Community schema version is unsupported."}

	var level_name := String(source.level_name)
	var creator_name := String(source.creator_display_name)
	if (
		typeof(source.level_name) != TYPE_STRING
		or not _is_valid_display_field(level_name, 2, 32)
	):
		return {"ok": false, "error": "Community level name is invalid."}
	if (
		typeof(source.creator_display_name) != TYPE_STRING
		or not _is_valid_display_field(creator_name, 2, 24)
	):
		return {"ok": false, "error": "Community creator name is invalid."}

	var status := String(source.status)
	if (
		typeof(source.status) != TYPE_STRING
		or not is_playable_status(status)
	):
		return {"ok": false, "error": "Community level status is not playable."}
	if not source.layout is Array or source.layout.size() != GRID_ROWS:
		return {"ok": false, "error": "Community layout must contain 10 rows."}

	var layout: Array[String] = []
	var populated := 0
	var destructible := 0
	for row_value in source.layout:
		if typeof(row_value) != TYPE_STRING:
			return {"ok": false, "error": "Community layout rows must be strings."}
		var row := String(row_value)
		if row.length() != GRID_COLUMNS:
			return {"ok": false, "error": "Community layout rows must be 13 columns."}
		for character in row:
			if not ALLOWED_CODES.contains(character):
				return {"ok": false, "error": "Community layout contains an invalid code."}
			if character != ".":
				populated += 1
				if character != "X":
					destructible += 1
		layout.append(row)

	if destructible < MIN_DESTRUCTIBLE:
		return {"ok": false, "error": "Community layout needs 8 destructible cells."}
	if populated > MAX_POPULATED:
		return {"ok": false, "error": "Community layout exceeds 100 populated cells."}
	if not _is_exact_integer(source.populated_count, populated):
		return {"ok": false, "error": "Community populated count does not match layout."}
	if (
		typeof(source.created_at) != TYPE_STRING
		or String(source.created_at).is_empty()
		or String(source.created_at).length() > 64
	):
		return {"ok": false, "error": "Community created_at is invalid."}

	return {
		"ok": true,
		"level": {
			"id": level_id,
			"schema_version": SCHEMA_VERSION,
			"level_name": level_name,
			"creator_display_name": creator_name,
			"layout": layout,
			"status": status,
			"populated_count": populated,
			"created_at": String(source.created_at),
		},
	}


static func parse_catalog_response(value: Variant) -> Dictionary:
	var rows: Variant = value
	if value is Dictionary and value.has("levels"):
		rows = value.levels
	if not rows is Array:
		return {"ok": false, "error": "Community catalog response was not a list."}
	if rows.size() > MAX_ENTRIES:
		return {"ok": false, "error": "Community catalog exceeded 100 entries."}

	var entries: Array[Dictionary] = []
	var seen_ids := {}
	for row in rows:
		var validation := validate_level(row)
		if not validation.ok:
			return validation
		var level: Dictionary = validation.level
		if seen_ids.has(level.id):
			return {"ok": false, "error": "Community catalog contains a duplicate id."}
		seen_ids[level.id] = true
		entries.append(level)
	return {"ok": true, "entries": entries}


static func parse_exact_response(value: Variant, expected_id: String) -> Dictionary:
	if not is_valid_id(expected_id):
		return {"ok": false, "error": "Invalid community level id."}
	var candidate: Variant = value
	if value is Array:
		if value.size() != 1:
			return {"ok": false, "error": "Community level is no longer available."}
		candidate = value[0]
	elif value is Dictionary and value.has("level"):
		candidate = value.level
	elif value is Dictionary and value.has("levels"):
		if not value.levels is Array or value.levels.size() != 1:
			return {"ok": false, "error": "Community level is no longer available."}
		candidate = value.levels[0]
	var validation := validate_level(candidate)
	if not validation.ok:
		return validation
	if String(validation.level.id) != expected_id:
		return {"ok": false, "error": "Community freshness check returned the wrong level."}
	return validation


static func is_valid_id(level_id: String) -> bool:
	if level_id.length() != 27 or not level_id.begins_with("cl_"):
		return false
	for character in level_id.substr(3):
		if not "0123456789abcdef".contains(character):
			return false
	return true


static func is_playable_status(status: String) -> bool:
	return status == "pending" or status == "listed"


static func deep_link_id(query_string: String) -> String:
	var query := query_string.trim_prefix("?")
	for pair in query.split("&"):
		var separator := pair.find("=")
		if separator < 0:
			continue
		var key := pair.substr(0, separator).uri_decode()
		var value := pair.substr(separator + 1).uri_decode()
		if key == "community" and is_valid_id(value):
			return value
	return ""


func _on_catalog_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_catalog_in_flight = false
	var decoded := _decode_response(result, response_code, body)
	if not decoded.ok:
		_emit_catalog_failure(decoded.error)
		return
	var parsed := parse_catalog_response(decoded.value)
	if not parsed.ok:
		_emit_catalog_failure(parsed.error)
		return
	_entries = parsed.entries
	_fetched_at = Time.get_datetime_string_from_system(true)
	_save_cache()
	catalog_updated.emit(
		STATE_EMPTY if _entries.is_empty() else STATE_READY,
		cached_entries(),
		_fetched_at,
		""
	)


func _on_exact_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_exact_in_flight = false
	var level_id := _requested_id
	_requested_id = ""
	var decoded := _decode_response(result, response_code, body)
	if not decoded.ok:
		_confirmed_levels.erase(level_id)
		level_checked.emit(level_id, false, {}, decoded.error)
		return
	var parsed := parse_exact_response(decoded.value, level_id)
	if not parsed.ok:
		_confirmed_levels.erase(level_id)
		level_checked.emit(level_id, false, {}, parsed.error)
		return
	var level: Dictionary = parsed.level
	_confirmed_levels[level_id] = level.duplicate(true)
	level_checked.emit(level_id, true, level.duplicate(true), "")


func _emit_catalog_failure(message: String) -> void:
	push_warning(message)
	catalog_updated.emit(
		STATE_ERROR if _entries.is_empty() else STATE_STALE,
		cached_entries(),
		_fetched_at,
		message
	)


func _create_request(callback: Callable) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.accept_gzip = true
	request.timeout = REQUEST_TIMEOUT
	request.body_size_limit = 1024 * 1024
	request.request_completed.connect(callback)
	add_child(request)
	return request


func _request_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % PUBLISHABLE_KEY,
		"Accept: application/json",
	])


func _decode_response(
	result: int,
	response_code: int,
	body: PackedByteArray
) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "Community service is offline."}
	if response_code < 200 or response_code >= 300:
		if response_code == 404 or response_code == 410:
			return {"ok": false, "error": "Community level is no longer available."}
		return {
			"ok": false,
			"error": "Community service returned HTTP %d." % response_code,
		}
	var parser := JSON.new()
	var parse_error := parser.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return {"ok": false, "error": "Community service returned invalid JSON."}
	return {"ok": true, "value": parser.data}


func _load_cache() -> void:
	if not FileAccess.file_exists(CACHE_PATH):
		return
	var cache_file := FileAccess.open(CACHE_PATH, FileAccess.READ)
	if cache_file == null:
		return
	var value: Variant = JSON.parse_string(cache_file.get_as_text())
	cache_file.close()
	if not value is Dictionary:
		return
	var parsed := parse_catalog_response(value.get("entries", []))
	if not parsed.ok:
		return
	_entries = parsed.entries
	_fetched_at = String(value.get("fetched_at", ""))


func _save_cache() -> bool:
	var cache_file := FileAccess.open(CACHE_PATH, FileAccess.WRITE)
	if cache_file == null:
		push_warning("Could not save the Community Lab cache.")
		return false
	cache_file.store_string(JSON.stringify({
		"schema_version": SCHEMA_VERSION,
		"fetched_at": _fetched_at,
		"entries": _entries,
	}))
	cache_file.close()
	return true


func _duplicate_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry in entries:
		copy.append(entry.duplicate(true))
	return copy


static func _is_valid_display_field(
	value: String,
	minimum: int,
	maximum: int
) -> bool:
	if (
		value.length() < minimum
		or value.length() > maximum
		or value != value.to_upper()
		or value != value.strip_edges()
	):
		return false
	for character in value:
		if not ALLOWED_DISPLAY_CHARACTERS.contains(character):
			return false
	return true


static func _is_exact_integer(value: Variant, expected: int) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return float(value) == float(expected)
