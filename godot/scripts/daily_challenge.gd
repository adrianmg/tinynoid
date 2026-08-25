class_name DailyChallengeState
extends Node

signal changed(view: Dictionary)
signal run_ready
signal submission_changed(run_id: String)

const API_BASE := "https://ugkygoijpqrreooylpnc.supabase.co/functions/v1"
const PUBLISHABLE_KEY := "sb_publishable_GMQxCnYtLe3qCkV1Nc3N2w_5JXyve-X"
const DAILY_URL := API_BASE + "/daily-challenge"
const START_URL := API_BASE + "/start-daily-run"
const SUBMIT_URL := API_BASE + "/submit-daily-score"
const SHARE_URL := "https://tinynoid.vercel.app/"
const STATE_PATH := "user://daily_challenge.json"
const STATE_FILE := "daily_challenge.json"
const STATE_TEMP_FILE := "daily_challenge.json.tmp"
const STATE_BACKUP_FILE := "daily_challenge.json.bak"
const REQUEST_TIMEOUT := 8.0
const MAX_SUBMIT_RETRIES := 2

const PHASE_EMPTY := &"empty"
const PHASE_LOADING := &"loading"
const PHASE_READY := &"ready"
const PHASE_STARTING := &"starting"
const PHASE_ERROR := &"error"

var _phase: StringName = PHASE_EMPTY
var _cartridge: Dictionary = {}
var _top_scores: Array[Dictionary] = []
var _message := ""
var _fetched_at := ""
var _live := false
var _target_daily_id := ""
var _queued_daily_id := ""
var _has_queued_daily_request := false
var _daily_in_flight := false
var _start_run_id := ""
var _start_in_flight := false
var _submit_in_flight := false
var _active_submit_run_id := ""
var _submit_attempts: Dictionary = {}
var _retry_scheduled := false
var _run_tokens: Dictionary = {}
var _pending_submissions: Array[Dictionary] = []
var _failed_submissions: Dictionary = {}
var _receipts: Dictionary = {}
var _daily_request: HTTPRequest
var _start_request: HTTPRequest
var _submit_request: HTTPRequest
var _state_writer: Callable


func _ready() -> void:
	_load_state()
	_daily_request = _create_request(_on_daily_completed)
	_start_request = _create_request(_on_start_completed)
	_submit_request = _create_request(_on_submit_completed)
	_resume_failed_submissions()
	_flush_pending_submission()


func open(daily_id: String = "") -> Dictionary:
	if _daily_in_flight:
		if daily_id != _target_daily_id:
			_queued_daily_id = daily_id
			_has_queued_daily_request = true
			_phase = PHASE_LOADING
			_message = "LOADING DAILY CARTRIDGE"
			_emit_changed()
		return get_view()
	_target_daily_id = daily_id
	if (
		not _cartridge.is_empty()
		and (
			daily_id.is_empty()
			or String(_cartridge.get("daily_id", "")) == daily_id
		)
	):
		_phase = PHASE_LOADING
		_live = false
		_message = "REFRESHING DAILY CARTRIDGE"
	else:
		_phase = PHASE_LOADING
		_cartridge = {}
		_top_scores.clear()
		_live = false
		_message = "LOADING DAILY CARTRIDGE"
	_emit_changed()
	if DisplayServer.get_name() == "headless":
		return get_view()
	_daily_in_flight = true
	var url := DAILY_URL
	if not daily_id.is_empty():
		url += "?date=%s" % daily_id.uri_encode()
	var error := _daily_request.request(
		url,
		_request_headers(),
		HTTPClient.METHOD_GET
	)
	if error != OK:
		_daily_in_flight = false
		_phase = PHASE_ERROR
		_message = "DAILY CARTRIDGE OFFLINE"
		_emit_changed()
	return get_view()


func start() -> bool:
	if (
		_phase != PHASE_READY
		or not _live
		or _cartridge.is_empty()
		or _start_in_flight
	):
		return false
	if not _is_currently_playable():
		_message = "THIS DAILY CARTRIDGE IS CLOSED"
		_emit_changed()
		open()
		return false
	_start_run_id = _create_run_id()
	_start_in_flight = true
	_phase = PHASE_STARTING
	_message = "LOADING DAILY RUN"
	_emit_changed()
	var error := _start_request.request(
		START_URL,
		_request_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify({
			"run_id": _start_run_id,
			"daily_id": String(_cartridge.daily_id),
		})
	)
	if error != OK:
		_start_in_flight = false
		_start_run_id = ""
		_phase = PHASE_READY
		_message = "DAILY RUN COULD NOT START"
		_emit_changed()
		return false
	return true


func cancel_start() -> void:
	if not _start_in_flight:
		return
	_start_request.cancel_request()
	_start_in_flight = false
	_start_run_id = ""
	_phase = PHASE_READY
	_message = "DAILY START CANCELLED"
	_emit_changed()


func record_result(run_result: Dictionary, player_name: String) -> bool:
	if String(run_result.get("run_kind", "")) != "daily":
		return false
	var run_id := String(run_result.get("run_id", ""))
	var record := {
		"run_id": run_id,
		"run_token": String(_run_tokens.get(run_id, "")),
		"daily_id": String(run_result.get("daily_id", "")),
		"level_id": String(run_result.get("level_id", "")),
		"player_name": (
			"GUEST"
			if player_name == "GUEST"
			else PlayerProfileState.format_handle(player_name)
		),
		"score": int(run_result.get("score", 0)),
		"outcome": String(run_result.get("outcome", "")),
	}
	if record.player_name == "GUEST":
		_receipts[run_id] = {
			"status": "local",
			"score": record.score,
			"rank": 0,
			"competitor_count": 0,
			"personal_best": false,
		}
		_save_state()
		submission_changed.emit(run_id)
		_emit_changed()
		return true
	if record.run_token.is_empty():
		_receipts.erase(run_id)
		_failed_submissions[run_id] = record
		_save_state()
		submission_changed.emit(run_id)
		_emit_changed()
		return false
	_receipts.erase(run_id)
	_pending_submissions.append(record)
	_failed_submissions.erase(run_id)
	if not _save_state():
		_pending_submissions.pop_back()
		_failed_submissions[run_id] = record
		return false
	submission_changed.emit(run_id)
	_emit_changed()
	_flush_pending_submission()
	return true


func retry_result(run_id: String) -> bool:
	if _failed_submissions.has(run_id):
		var record: Dictionary = _failed_submissions[run_id]
		_failed_submissions.erase(run_id)
		_pending_submissions.append(record.duplicate(true))
		if not _save_state():
			_pending_submissions.pop_back()
			_failed_submissions[run_id] = record
			return false
	_submit_attempts.erase(run_id)
	_retry_scheduled = false
	_flush_pending_submission()
	return _has_pending(run_id)


func get_view() -> Dictionary:
	var cartridge := _cartridge.duplicate(true)
	if not cartridge.is_empty():
		cartridge["playable_now"] = _is_currently_playable()
	return {
		"phase": _phase,
		"cartridge": cartridge,
		"top_scores": _duplicate_entries(_top_scores),
		"message": _message,
		"fetched_at": _fetched_at,
		"live": _live,
	}


func get_result(run_id: String) -> Dictionary:
	if _receipts.has(run_id):
		return (_receipts[run_id] as Dictionary).duplicate(true)
	if _has_pending(run_id):
		return {"status": "pending"}
	if _failed_submissions.has(run_id):
		return {"status": "failed"}
	return {}


func share_url(daily_id: String) -> String:
	return "%s?daily=%s" % [SHARE_URL, daily_id.uri_encode()]


func set_state_writer_for_tests(writer: Callable) -> void:
	_state_writer = writer


static func parse_daily_response(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {"ok": false, "error": "Daily response must be an object."}
	var source: Dictionary = value
	var daily_id := String(source.get("daily_id", ""))
	if not is_valid_daily_id(daily_id):
		return {"ok": false, "error": "Daily id is invalid."}
	var level_validation := CommunityCatalogClient.validate_level(
		source.get("level", {})
	)
	if not level_validation.ok:
		return level_validation
	if (
		not _is_nonnegative_integer(source.get("run_seed"))
		or not _is_nonnegative_integer(source.get("max_score"))
		or typeof(source.get("server_now")) != TYPE_STRING
		or typeof(source.get("opens_at")) != TYPE_STRING
		or typeof(source.get("closes_at")) != TYPE_STRING
		or typeof(source.get("accept_until")) != TYPE_STRING
		or not source.get("top_scores", []) is Array
	):
		return {"ok": false, "error": "Daily cartridge fields are invalid."}
	var top_scores: Array[Dictionary] = []
	for value_entry in source.top_scores:
		if not value_entry is Dictionary:
			return {"ok": false, "error": "Daily score row is invalid."}
		var entry: Dictionary = value_entry
		if (
			not _is_nonnegative_integer(entry.get("rank"))
			or not _is_nonnegative_integer(entry.get("score"))
			or typeof(entry.get("player_name")) != TYPE_STRING
		):
			return {"ok": false, "error": "Daily score row is invalid."}
		top_scores.append(entry.duplicate(true))
	var server_unix := Time.get_unix_time_from_datetime_string(
		String(source.server_now)
	)
	var closes_unix := Time.get_unix_time_from_datetime_string(
		String(source.closes_at)
	)
	return {
		"ok": true,
		"cartridge": {
			"daily_id": daily_id,
			"opens_at": String(source.opens_at),
			"closes_at": String(source.closes_at),
			"accept_until": String(source.accept_until),
			"run_seed": int(source.run_seed),
			"max_score": int(source.max_score),
			"level": level_validation.level,
			"server_unix": server_unix,
			"closes_unix": closes_unix,
			"fetched_local_unix": Time.get_unix_time_from_system(),
			"playable_now": server_unix < closes_unix,
		},
		"top_scores": top_scores,
	}


static func is_valid_daily_id(value: String) -> bool:
	if value.length() != 10:
		return false
	var parts := value.split("-")
	if parts.size() != 3:
		return false
	if (
		parts[0].length() != 4
		or parts[1].length() != 2
		or parts[2].length() != 2
		or not parts[0].is_valid_int()
		or not parts[1].is_valid_int()
		or not parts[2].is_valid_int()
	):
		return false
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	if month < 1 or month > 12 or day < 1:
		return false
	var days := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	var leap := (
		year % 400 == 0
		or (year % 4 == 0 and year % 100 != 0)
	)
	if leap:
		days[1] = 29
	return day <= days[month - 1]


static func _is_nonnegative_integer(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	return float(value) >= 0.0 and floorf(float(value)) == float(value)


static func deep_link_id(query_string: String) -> String:
	var query := query_string.trim_prefix("?")
	for pair in query.split("&"):
		var separator := pair.find("=")
		if separator < 0:
			continue
		var key := pair.substr(0, separator).uri_decode()
		var value := pair.substr(separator + 1).uri_decode()
		if key == "daily" and is_valid_daily_id(value):
			return value
	return ""


func _on_daily_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_daily_in_flight = false
	if _has_queued_daily_request:
		var queued_id := _queued_daily_id
		_queued_daily_id = ""
		_has_queued_daily_request = false
		open(queued_id)
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_phase = PHASE_ERROR
		_live = false
		_message = (
			"NO DAILY CARTRIDGE YET"
			if response_code == 404
			else "DAILY CARTRIDGE OFFLINE"
		)
		_emit_changed()
		return
	var decoded: Variant = JSON.parse_string(body.get_string_from_utf8())
	var parsed := parse_daily_response(decoded)
	if (
		not parsed.ok
		or (
			not _target_daily_id.is_empty()
			and String(parsed.cartridge.daily_id) != _target_daily_id
		)
	):
		_phase = PHASE_ERROR
		_live = false
		_message = "DAILY CARTRIDGE INVALID"
		_emit_changed()
		return
	_cartridge = parsed.cartridge
	_top_scores = parsed.top_scores
	_phase = PHASE_READY
	_live = true
	_message = ""
	_fetched_at = Time.get_datetime_string_from_system(true)
	_save_state()
	_emit_changed()


func _on_start_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	if not _start_in_flight:
		return
	_start_in_flight = false
	var run_id := _start_run_id
	_start_run_id = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code not in [200, 201]:
		_phase = PHASE_READY
		_message = "DAILY RUN COULD NOT START"
		_emit_changed()
		return
	var value: Variant = JSON.parse_string(body.get_string_from_utf8())
	if (
		not value is Dictionary
		or String(value.get("run_id", "")) != run_id
		or String(value.get("daily_id", "")) != String(_cartridge.daily_id)
		or String(value.get("level_id", "")) != String(_cartridge.level.id)
		or String(value.get("run_token", "")).length() != 64
		or int(value.get("run_seed", -1)) != int(_cartridge.run_seed)
	):
		_phase = PHASE_READY
		_message = "DAILY RUN RESPONSE INVALID"
		_emit_changed()
		return
	_run_tokens[run_id] = String(value.run_token)
	if not _save_state():
		_run_tokens.erase(run_id)
		_phase = PHASE_READY
		_message = "DAILY RUN COULD NOT BE SAVED"
		_emit_changed()
		return
	GameSession.new_daily_game(_cartridge, run_id)
	_phase = PHASE_READY
	_message = ""
	run_ready.emit()
	_emit_changed()


func _flush_pending_submission() -> void:
	if (
		_submit_in_flight
		or _retry_scheduled
		or _pending_submissions.is_empty()
	):
		return
	var submission := _pending_submissions[0]
	_active_submit_run_id = String(submission.run_id)
	_submit_in_flight = true
	var error := _submit_request.request(
		SUBMIT_URL,
		_request_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(submission)
	)
	if error != OK:
		_submit_in_flight = false
		_active_submit_run_id = ""
		var run_id := run_id_from_submission(submission)
		_handle_transient_submission(run_id)
		submission_changed.emit(run_id)
		_emit_changed()


func _on_submit_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_submit_in_flight = false
	var run_id := _active_submit_run_id
	_active_submit_run_id = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		_handle_transient_submission(run_id)
		submission_changed.emit(run_id)
		return
	if response_code < 200 or response_code >= 300:
		if response_code in [400, 401, 403, 404, 409, 422]:
			var failed := _remove_pending(run_id)
			if not failed.is_empty():
				_failed_submissions[run_id] = failed
				_save_state()
		else:
			_handle_transient_submission(run_id)
		submission_changed.emit(run_id)
		_emit_changed()
		return
	var value: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not value is Dictionary or String(value.get("run_id", "")) != run_id:
		_handle_transient_submission(run_id)
		submission_changed.emit(run_id)
		return
	_remove_pending(run_id)
	_submit_attempts.erase(run_id)
	_run_tokens.erase(run_id)
	_receipts[run_id] = {
		"status": "submitted",
		"rank": int(value.get("rank", 0)),
		"best_score": int(value.get("best_score", 0)),
		"competitor_count": int(value.get("competitor_count", 0)),
		"personal_best": bool(value.get("personal_best", false)),
		"submitted_at": String(value.get("submitted_at", "")),
	}
	_save_state()
	submission_changed.emit(run_id)
	_emit_changed()
	_flush_pending_submission()


func _handle_transient_submission(run_id: String) -> void:
	var attempts := int(_submit_attempts.get(run_id, 0)) + 1
	_submit_attempts[run_id] = attempts
	if attempts > MAX_SUBMIT_RETRIES:
		var failed := _remove_pending(run_id)
		if not failed.is_empty():
			_failed_submissions[run_id] = failed
			_save_state()
		_submit_attempts.erase(run_id)
		_retry_scheduled = false
		_flush_pending_submission()
		return
	_retry_scheduled = true
	call_deferred("_retry_submission_after_delay", pow(2.0, attempts))


func _retry_submission_after_delay(delay_seconds: float) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	_retry_scheduled = false
	_flush_pending_submission()


func _resume_failed_submissions() -> void:
	for run_id in _failed_submissions.keys():
		if _has_pending(String(run_id)):
			continue
		_pending_submissions.append(
			(_failed_submissions[run_id] as Dictionary).duplicate(true)
		)
		_failed_submissions.erase(run_id)
	if not _pending_submissions.is_empty():
		_save_state()


func _is_currently_playable() -> bool:
	if _cartridge.is_empty() or not _live:
		return false
	var server_unix := float(_cartridge.get("server_unix", 0.0))
	var fetched_local := float(
		_cartridge.get("fetched_local_unix", 0.0)
	)
	var closes_unix := float(_cartridge.get("closes_unix", 0.0))
	if server_unix <= 0.0 or fetched_local <= 0.0 or closes_unix <= 0.0:
		return false
	var estimated_server_now := (
		server_unix
		+ Time.get_unix_time_from_system()
		- fetched_local
	)
	return estimated_server_now < closes_unix


func run_id_from_submission(submission: Dictionary) -> String:
	return String(submission.get("run_id", ""))


func _has_pending(run_id: String) -> bool:
	for submission in _pending_submissions:
		if String(submission.get("run_id", "")) == run_id:
			return true
	return false


func _remove_pending(run_id: String) -> Dictionary:
	for index in range(_pending_submissions.size()):
		if String(_pending_submissions[index].get("run_id", "")) == run_id:
			return _pending_submissions.pop_at(index)
	return {}


func _request_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % PUBLISHABLE_KEY,
		"Content-Type: application/json",
	])


func _create_request(callback: Callable) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.accept_gzip = false
	request.timeout = REQUEST_TIMEOUT
	request.request_completed.connect(callback)
	add_child(request)
	return request


func _emit_changed() -> void:
	changed.emit(get_view())


func _save_state() -> bool:
	var state := {
		"cartridge": _cartridge,
		"top_scores": _top_scores,
		"fetched_at": _fetched_at,
		"run_tokens": _run_tokens,
		"pending_submissions": _pending_submissions,
		"failed_submissions": _failed_submissions,
		"receipts": _receipts,
	}
	if _state_writer.is_valid():
		return bool(_state_writer.call(state))
	return _write_state_file(state)


func _write_state_file(state: Dictionary) -> bool:
	var directory := DirAccess.open("user://")
	if directory == null:
		return false
	if directory.file_exists(STATE_TEMP_FILE):
		directory.remove(STATE_TEMP_FILE)
	var file := FileAccess.open(
		"user://%s" % STATE_TEMP_FILE,
		FileAccess.WRITE
	)
	if file == null:
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		directory.remove(STATE_TEMP_FILE)
		return false
	if directory.file_exists(STATE_BACKUP_FILE):
		directory.remove(STATE_BACKUP_FILE)
	var had_state := directory.file_exists(STATE_FILE)
	if had_state:
		var backup_error := directory.rename(STATE_FILE, STATE_BACKUP_FILE)
		if backup_error != OK:
			directory.remove(STATE_TEMP_FILE)
			return false
	var promote_error := directory.rename(STATE_TEMP_FILE, STATE_FILE)
	if promote_error != OK:
		if had_state:
			directory.rename(STATE_BACKUP_FILE, STATE_FILE)
		return false
	if had_state:
		directory.remove(STATE_BACKUP_FILE)
	return true


func _load_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if file == null:
		return
	var value: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not value is Dictionary:
		return
	var state: Dictionary = value
	if state.get("cartridge", {}) is Dictionary:
		_cartridge = (state.cartridge as Dictionary).duplicate(true)
	if state.get("top_scores", []) is Array:
		for entry in state.top_scores:
			if entry is Dictionary:
				_top_scores.append((entry as Dictionary).duplicate(true))
	_fetched_at = String(state.get("fetched_at", ""))
	if state.get("run_tokens", {}) is Dictionary:
		_run_tokens = (state.run_tokens as Dictionary).duplicate(true)
	if state.get("pending_submissions", []) is Array:
		for entry in state.pending_submissions:
			if entry is Dictionary:
				_pending_submissions.append(
					_normalize_submission(entry as Dictionary)
				)
	if state.get("failed_submissions", {}) is Dictionary:
		_failed_submissions = (
			state.failed_submissions as Dictionary
		).duplicate(true)
	if state.get("receipts", {}) is Dictionary:
		_receipts = (state.receipts as Dictionary).duplicate(true)
	if not _cartridge.is_empty():
		_phase = PHASE_LOADING
		_message = "CACHED DAILY CARTRIDGE"


func _normalize_submission(value: Dictionary) -> Dictionary:
	return {
		"run_id": String(value.get("run_id", "")),
		"run_token": String(value.get("run_token", "")),
		"daily_id": String(value.get("daily_id", "")),
		"level_id": String(value.get("level_id", "")),
		"player_name": String(value.get("player_name", "")),
		"score": int(value.get("score", 0)),
		"outcome": String(value.get("outcome", "")),
	}


func _duplicate_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for entry in entries:
		copies.append(entry.duplicate(true))
	return copies


static func _create_run_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var encoded := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [
		encoded.substr(0, 8),
		encoded.substr(8, 4),
		encoded.substr(12, 4),
		encoded.substr(16, 4),
		encoded.substr(20, 12),
	]
