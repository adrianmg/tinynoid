class_name LeaderboardClient
extends Node

signal top_scores_updated(
	state: StringName,
	entries: Array[Dictionary],
	fetched_at: String
)
signal latest_score_updated(
	state: StringName,
	entry: Dictionary,
	fetched_at: String
)
signal score_submitted(run_id: String, created: bool)
signal submission_failed(run_id: String, message: String)

const MAX_ENTRIES := 100
const MAX_SCORE := 999999
const SUPABASE_URL := "https://ugkygoijpqrreooylpnc.supabase.co"
const SUPABASE_PUBLISHABLE_KEY := "sb_publishable_GMQxCnYtLe3qCkV1Nc3N2w_5JXyve-X"
const SUBMISSION_URL := SUPABASE_URL + "/functions/v1/submit-score"
const STATE_PATH := "user://leaderboard.json"
const REQUEST_TIMEOUT := 8.0

const STATE_LOADING := &"loading"
const STATE_READY := &"ready"
const STATE_EMPTY := &"empty"
const STATE_STALE := &"stale"
const STATE_ERROR := &"error"
const STATE_LOCAL := &"local"

var _cached_entries: Array[Dictionary] = []
var _cached_latest_score: Dictionary = {}
var _local_scores: Array[Dictionary] = []
var _pending_submissions: Array[Dictionary] = []
var _fetched_at := ""
var _latest_fetched_at := ""
var _top_request: HTTPRequest
var _latest_request: HTTPRequest
var _write_request: HTTPRequest
var _top_in_flight := false
var _latest_in_flight := false
var _write_in_flight := false
var _active_run_id := ""


func _ready() -> void:
	_load_state()
	_top_request = _create_request(_on_top_scores_completed)
	_latest_request = _create_request(_on_latest_score_completed)
	_write_request = _create_request(_on_submission_completed)


func request_top_scores(limit: int = MAX_ENTRIES) -> void:
	if _top_in_flight:
		return
	_flush_pending_submission()
	_top_in_flight = true
	top_scores_updated.emit(
		STATE_LOADING,
		cached_top_scores(),
		_fetched_at
	)
	var error := _top_request.request(
		_rpc_url("get_top_scores"),
		_request_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify({"p_limit": clampi(limit, 1, MAX_ENTRIES)})
	)
	if error != OK:
		_top_in_flight = false
		_emit_top_failure(
			"Could not start leaderboard request: %s" % error_string(error)
		)


func request_latest_score() -> void:
	if _latest_in_flight:
		return
	_flush_pending_submission()
	_latest_in_flight = true
	latest_score_updated.emit(
		STATE_LOADING,
		cached_latest_score(),
		_latest_fetched_at
	)
	var error := _latest_request.request(
		_rpc_url("get_latest_score"),
		_request_headers(),
		HTTPClient.METHOD_POST,
		"{}"
	)
	if error != OK:
		_latest_in_flight = false
		_emit_latest_failure(
			"Could not start recent-score request: %s" % error_string(error)
		)


func record_score(run_result: Dictionary, player_name: String) -> bool:
	var local_entry := {
		"run_id": String(run_result.get("run_id", "")),
		"player_name": PlayerProfileState.normalize_name(player_name),
		"score": int(run_result.get("score", 0)),
		"outcome": String(run_result.get("outcome", "")),
		"completed_stage": int(run_result.get("completed_stage", 1)),
		"start_stage": int(run_result.get("start_stage", 1)),
		"submitted_at": Time.get_datetime_string_from_system(true),
		"local": true,
	}
	if local_entry.player_name.is_empty():
		local_entry.player_name = "GUEST"
	_remember_local_score(local_entry)
	if not _save_state():
		return false

	if (
		not bool(run_result.get("eligible", false))
		or local_entry.player_name == "GUEST"
	):
		return true
	return submit_score(local_entry)


func submit_score(submission: Dictionary) -> bool:
	var validation_error := validate_submission(submission)
	var run_id := String(submission.get("run_id", ""))
	if not validation_error.is_empty():
		push_error(validation_error)
		submission_failed.emit(run_id, validation_error)
		return false

	var normalized := _normalize_submission(submission)
	if _has_pending_submission(normalized.run_id):
		return true
	_pending_submissions.append(normalized)
	if not _save_state():
		_pending_submissions.pop_back()
		submission_failed.emit(
			normalized.run_id,
			"Could not persist score before submission."
		)
		return false
	_flush_pending_submission()
	return true


func retry_pending_submissions() -> void:
	_flush_pending_submission()


func cached_top_scores() -> Array[Dictionary]:
	return _duplicate_entries(_cached_entries)


func cached_latest_score() -> Dictionary:
	return _cached_latest_score.duplicate(true)


func cached_local_scores() -> Array[Dictionary]:
	return _duplicate_entries(_local_scores)


func pending_submission_count() -> int:
	return _pending_submissions.size()


func has_pending_submission(run_id: String) -> bool:
	return _has_pending_submission(run_id)


func validate_submission(submission: Dictionary) -> String:
	if not _is_valid_run_id(String(submission.get("run_id", ""))):
		return "Leaderboard submission requires a valid UUID run_id."

	var name_error := PlayerProfileState.get_name_error(
		String(submission.get("player_name", ""))
	)
	if not name_error.is_empty():
		return name_error

	if not submission.has("score") or typeof(submission.score) != TYPE_INT:
		return "Leaderboard score must be an integer."
	var score: int = submission.score
	if score < 0 or score > MAX_SCORE:
		return "Leaderboard score is outside the supported range."

	var outcome := String(submission.get("outcome", ""))
	if outcome != "game_over" and outcome != "campaign_clear":
		return "Leaderboard outcome is invalid."
	if (
		not submission.has("completed_stage")
		or typeof(submission.completed_stage) != TYPE_INT
	):
		return "Completed stage must be an integer."
	var completed_stage: int = submission.completed_stage
	if completed_stage < 1 or completed_stage > LevelCatalog.STAGE_COUNT:
		return "Completed stage is outside the campaign."
	if (
		outcome == "campaign_clear"
		and completed_stage != LevelCatalog.STAGE_COUNT
	):
		return "Campaign clear requires the final stage."
	if (
		not submission.has("start_stage")
		or typeof(submission.start_stage) != TYPE_INT
		or int(submission.start_stage) != 1
	):
		return "Only runs started at Stage 1 can be submitted."
	return ""


func _flush_pending_submission() -> void:
	if _write_in_flight or _pending_submissions.is_empty():
		return

	var submission := _pending_submissions[0]
	_active_run_id = String(submission.run_id)
	_write_in_flight = true
	var error := _write_request.request(
		SUBMISSION_URL,
		_request_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(submission)
	)
	if error != OK:
		_write_in_flight = false
		var message := (
			"Could not start score submission: %s" % error_string(error)
		)
		push_warning(message)
		submission_failed.emit(_active_run_id, message)
		_active_run_id = ""


func _on_top_scores_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_top_in_flight = false
	var decoded := _decode_successful_response(
		result,
		response_code,
		body
	)
	if not decoded.ok:
		_emit_top_failure(decoded.error)
		return
	if not decoded.value is Array:
		_emit_top_failure("Leaderboard response was not a score list.")
		return

	var entries: Array[Dictionary] = []
	for value in decoded.value:
		var entry := _score_entry_from_response(value, entries.size() + 1)
		if entry.is_empty():
			_emit_top_failure("Leaderboard response contained an invalid row.")
			return
		entries.append(entry)
	_cached_entries = entries
	_fetched_at = Time.get_datetime_string_from_system(true)
	_save_state()
	top_scores_updated.emit(
		STATE_EMPTY if entries.is_empty() else STATE_READY,
		cached_top_scores(),
		_fetched_at
	)


func _on_latest_score_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_latest_in_flight = false
	var decoded := _decode_successful_response(
		result,
		response_code,
		body
	)
	if not decoded.ok:
		_emit_latest_failure(decoded.error)
		return
	if not decoded.value is Array:
		_emit_latest_failure("Recent-score response was not a list.")
		return

	_latest_fetched_at = Time.get_datetime_string_from_system(true)
	if decoded.value.is_empty():
		_cached_latest_score = {}
		_save_state()
		latest_score_updated.emit(STATE_EMPTY, {}, _latest_fetched_at)
		return

	var entry := _score_entry_from_response(decoded.value[0])
	if entry.is_empty():
		_emit_latest_failure("Recent-score response contained an invalid row.")
		return
	_cached_latest_score = entry
	_save_state()
	latest_score_updated.emit(
		STATE_READY,
		cached_latest_score(),
		_latest_fetched_at
	)


func _on_submission_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	_write_in_flight = false
	var run_id := _active_run_id
	_active_run_id = ""

	if result != HTTPRequest.RESULT_SUCCESS:
		var network_error := (
			"Score submission failed: %s" % _request_result_name(result)
		)
		push_warning(network_error)
		submission_failed.emit(run_id, network_error)
		return
	if response_code < 200 or response_code >= 300:
		var http_error := _http_error_message(response_code, body)
		push_warning(http_error)
		var permanent := _is_permanent_submission_failure(response_code)
		if permanent:
			_remove_pending_submission(run_id)
			_save_state()
		submission_failed.emit(run_id, http_error)
		if permanent:
			_flush_pending_submission()
		return

	var decoded := _decode_json(body)
	if (
		not decoded.ok
		or not decoded.value is Array
		or decoded.value.is_empty()
		or not decoded.value[0] is Dictionary
	):
		var shape_error := "Score submission response was invalid."
		push_warning(shape_error)
		submission_failed.emit(run_id, shape_error)
		return

	var response: Dictionary = decoded.value[0]
	_remove_pending_submission(run_id)
	_save_state()
	score_submitted.emit(run_id, bool(response.get("created", false)))
	_flush_pending_submission()


func _create_request(callback: Callable) -> HTTPRequest:
	var request := HTTPRequest.new()
	request.accept_gzip = false
	request.timeout = REQUEST_TIMEOUT
	request.request_completed.connect(callback)
	add_child(request)
	return request


func _load_state() -> void:
	if not FileAccess.file_exists(STATE_PATH):
		return
	var state_file := FileAccess.open(STATE_PATH, FileAccess.READ)
	if state_file == null:
		push_error(
			"Could not open leaderboard state: %s"
			% error_string(FileAccess.get_open_error())
		)
		return

	var parser := JSON.new()
	var parse_error := parser.parse(state_file.get_as_text())
	state_file.close()
	if parse_error != OK:
		push_error(
			"Could not parse leaderboard state at line %d: %s"
			% [parser.get_error_line(), parser.get_error_message()]
		)
		return
	if parser.data is Dictionary:
		_restore_state(parser.data)
	else:
		push_error("Leaderboard state root must be an object.")


func _restore_state(state: Dictionary) -> void:
	_cached_entries = _restore_entries(state.get("top_scores", []))
	_local_scores = _restore_entries(state.get("local_scores", []))
	_cached_latest_score = (
		state.get("latest_score", {}).duplicate(true)
		if state.get("latest_score", {}) is Dictionary
		else {}
	)
	_pending_submissions.clear()
	var pending: Variant = state.get("pending_submissions", [])
	if pending is Array:
		for submission in pending:
			if not submission is Dictionary:
				continue
			var normalized := _normalize_submission(submission)
			if validate_submission(normalized).is_empty():
				_pending_submissions.append(normalized)
	_fetched_at = String(state.get("fetched_at", ""))
	_latest_fetched_at = String(state.get("latest_fetched_at", ""))


func _save_state() -> bool:
	var state_file := FileAccess.open(STATE_PATH, FileAccess.WRITE)
	if state_file == null:
		push_error(
			"Could not save leaderboard state: %s"
			% error_string(FileAccess.get_open_error())
		)
		return false
	state_file.store_string(JSON.stringify({
		"top_scores": _cached_entries,
		"fetched_at": _fetched_at,
		"latest_score": _cached_latest_score,
		"latest_fetched_at": _latest_fetched_at,
		"local_scores": _local_scores,
		"pending_submissions": _pending_submissions,
	}))
	state_file.close()
	return true


func _remember_local_score(entry: Dictionary) -> void:
	var replaced := false
	for index in range(_local_scores.size()):
		if _local_scores[index].get("run_id", "") == entry.run_id:
			_local_scores[index] = entry.duplicate(true)
			replaced = true
			break
	if not replaced:
		_local_scores.append(entry.duplicate(true))
	_local_scores.sort_custom(
		func(left: Dictionary, right: Dictionary) -> bool:
			if int(left.score) == int(right.score):
				return String(left.submitted_at) < String(right.submitted_at)
			return int(left.score) > int(right.score)
	)
	if _local_scores.size() > MAX_ENTRIES:
		_local_scores.resize(MAX_ENTRIES)
	for index in range(_local_scores.size()):
		_local_scores[index]["rank"] = index + 1


func _normalize_submission(submission: Dictionary) -> Dictionary:
	return {
		"run_id": String(submission.get("run_id", "")).strip_edges(),
		"player_name": PlayerProfileState.normalize_name(
			String(submission.get("player_name", ""))
		),
		"score": int(submission.get("score", -1)),
		"outcome": String(submission.get("outcome", "")),
		"completed_stage": int(submission.get("completed_stage", 0)),
		"start_stage": int(submission.get("start_stage", 0)),
	}


func _score_entry_from_response(
	value: Variant,
	fallback_rank: int = 0
) -> Dictionary:
	if not value is Dictionary:
		return {}
	var player_name := String(value.get("player_name", ""))
	if player_name.is_empty():
		return {}
	return {
		"rank": int(value.get("rank", fallback_rank)),
		"player_name": player_name,
		"score": int(value.get("score", 0)),
		"outcome": String(value.get("outcome", "")),
		"completed_stage": int(value.get("completed_stage", 1)),
		"submitted_at": String(value.get("submitted_at", "")),
	}


func _decode_successful_response(
	result: int,
	response_code: int,
	body: PackedByteArray
) -> Dictionary:
	if result != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error": "Leaderboard request failed: %s"
				% _request_result_name(result),
		}
	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": _http_error_message(response_code, body),
		}
	return _decode_json(body)


func _decode_json(body: PackedByteArray) -> Dictionary:
	var parser := JSON.new()
	var parse_error := parser.parse(body.get_string_from_utf8())
	if parse_error != OK:
		return {
			"ok": false,
			"error": "Could not parse leaderboard response: %s"
				% parser.get_error_message(),
		}
	return {"ok": true, "value": parser.data}


func _http_error_message(
	response_code: int,
	body: PackedByteArray
) -> String:
	var decoded := _decode_json(body)
	if decoded.ok and decoded.value is Dictionary:
		var detail := String(
			decoded.value.get(
				"message",
				decoded.value.get("error", "")
			)
		)
		if not detail.is_empty():
			return "Leaderboard HTTP %d: %s" % [response_code, detail]
	return "Leaderboard request returned HTTP %d." % response_code


func _emit_top_failure(message: String) -> void:
	push_warning(message)
	top_scores_updated.emit(
		STATE_ERROR if _cached_entries.is_empty() else STATE_STALE,
		cached_top_scores(),
		_fetched_at
	)


func _emit_latest_failure(message: String) -> void:
	push_warning(message)
	latest_score_updated.emit(
		STATE_ERROR if _cached_latest_score.is_empty() else STATE_STALE,
		cached_latest_score(),
		_latest_fetched_at
	)


func _has_pending_submission(run_id: String) -> bool:
	for submission in _pending_submissions:
		if submission.run_id == run_id:
			return true
	return false


func _remove_pending_submission(run_id: String) -> void:
	for index in range(_pending_submissions.size() - 1, -1, -1):
		if _pending_submissions[index].run_id == run_id:
			_pending_submissions.remove_at(index)


func _is_permanent_submission_failure(response_code: int) -> bool:
	return (
		response_code >= 400
		and response_code < 500
		and response_code != 408
		and response_code != 429
	)


func _is_valid_run_id(run_id: String) -> bool:
	var parts := run_id.to_lower().split("-")
	var expected_lengths := [8, 4, 4, 4, 12]
	if parts.size() != expected_lengths.size():
		return false
	for part_index in range(parts.size()):
		var part: String = parts[part_index]
		if part.length() != expected_lengths[part_index]:
			return false
		for character in part:
			if not "0123456789abcdef".contains(character):
				return false
	return true


func _rpc_url(function_name: String) -> String:
	return "%s/rest/v1/rpc/%s" % [SUPABASE_URL, function_name]


func _request_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: %s" % SUPABASE_PUBLISHABLE_KEY,
		"Content-Type: application/json",
	])


func _duplicate_entries(entries: Array[Dictionary]) -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for entry in entries:
		copy.append(entry.duplicate(true))
	return copy


func _restore_entries(value: Variant) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	if value is Array:
		for entry in value:
			if entry is Dictionary:
				entries.append(entry.duplicate(true))
	return entries


func _request_result_name(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_CONNECT:
			return "cannot connect"
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "cannot resolve host"
		HTTPRequest.RESULT_CONNECTION_ERROR:
			return "connection error"
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "TLS handshake error"
		HTTPRequest.RESULT_NO_RESPONSE:
			return "no response"
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "response too large"
		HTTPRequest.RESULT_BODY_DECOMPRESS_FAILED:
			return "body decompression failed"
		HTTPRequest.RESULT_REQUEST_FAILED:
			return "request failed"
		HTTPRequest.RESULT_TIMEOUT:
			return "timeout"
		_:
			return "network result %d" % result
