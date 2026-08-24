class_name GameSessionState
extends Node

signal state_changed(score: int, balls_remaining: int, level: int)

enum BallLossOutcome {
	RESTART_LEVEL,
	GAME_OVER,
}

const STARTING_BALLS := 3
const RUN_CAMPAIGN := &"campaign"
const RUN_COMMUNITY := &"community"

var score := 0
var high_score := 0
var balls_remaining := STARTING_BALLS
var level := 1
var run_seed := 0
var starter_capsule_pending := true
var run_id := ""
var run_start_stage := 1
var run_kind: StringName = RUN_CAMPAIGN
var community_level: Dictionary = {}
var _run_result_captured := false


func new_game(start_level: int = 1, run_seed_override: int = -1) -> void:
	assert(
		start_level >= 1 and start_level <= LevelCatalog.STAGE_COUNT,
		"Start level is outside the campaign."
	)
	score = 0
	balls_remaining = STARTING_BALLS
	level = start_level
	run_seed = (
		run_seed_override
		if run_seed_override >= 0
		else _generate_run_seed()
	)
	starter_capsule_pending = true
	run_id = _create_run_id()
	run_start_stage = start_level
	run_kind = RUN_CAMPAIGN
	community_level = {}
	_run_result_captured = false
	_emit_state_changed()


func new_community_game(
	level_data: Dictionary,
	run_seed_override: int = -1
) -> void:
	assert(
		CommunityCatalogClient.validate_level(level_data).ok,
		"Community runs require a validated level."
	)
	score = 0
	balls_remaining = STARTING_BALLS
	level = 1
	run_seed = (
		run_seed_override
		if run_seed_override >= 0
		else _generate_run_seed()
	)
	starter_capsule_pending = true
	run_id = ""
	run_start_stage = 0
	run_kind = RUN_COMMUNITY
	community_level = level_data.duplicate(true)
	_run_result_captured = false
	_emit_state_changed()


func restart_current_run() -> void:
	if is_community_run():
		new_community_game(community_level)
	else:
		new_game(level)


func is_community_run() -> bool:
	return run_kind == RUN_COMMUNITY


func get_active_layout() -> Array[String]:
	if not is_community_run():
		return LevelCatalog.get_layout(level)
	var layout: Array[String] = []
	for row in community_level.get("layout", []):
		layout.append(String(row))
	return layout


func get_active_level_name() -> String:
	if is_community_run():
		return String(community_level.get("level_name", "COMMUNITY LEVEL"))
	return LevelCatalog.get_stage_name(level)


func award(points: int) -> void:
	assert(points >= 0, "Score awards cannot be negative.")
	score += points
	high_score = maxi(high_score, score)
	_emit_state_changed()


func register_ball_lost() -> int:
	assert(balls_remaining > 0, "A ball cannot be lost after game over.")
	balls_remaining -= 1
	_emit_state_changed()

	if balls_remaining > 0:
		return BallLossOutcome.RESTART_LEVEL

	return BallLossOutcome.GAME_OVER


func add_ball() -> void:
	balls_remaining += 1
	_emit_state_changed()


func advance_level() -> void:
	assert(level < LevelCatalog.STAGE_COUNT, "The campaign is already complete.")
	level += 1
	_emit_state_changed()


func mark_starter_capsule_spawned() -> void:
	starter_capsule_pending = false


func can_submit_score() -> bool:
	return (
		run_kind == RUN_CAMPAIGN
		and run_start_stage == 1
		and not _run_result_captured
	)


func capture_run_result(outcome: String) -> Dictionary:
	if is_community_run():
		return {}
	if _run_result_captured:
		return {}
	if outcome != "game_over" and outcome != "campaign_clear":
		push_error("Unknown leaderboard outcome: %s" % outcome)
		return {}
	if outcome == "campaign_clear" and level != LevelCatalog.STAGE_COUNT:
		push_error("Campaign clear can only be captured on the final stage.")
		return {}

	_run_result_captured = true
	return {
		"run_id": run_id,
		"score": score,
		"outcome": outcome,
		"completed_stage": level,
		"start_stage": run_start_stage,
		"run_kind": String(run_kind),
		"eligible": run_kind == RUN_CAMPAIGN and run_start_stage == 1,
	}


static func _create_run_id() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	assert(bytes.size() == 16, "Could not generate a leaderboard run ID.")
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


func _emit_state_changed() -> void:
	state_changed.emit(score, balls_remaining, level)


func _generate_run_seed() -> int:
	return int(
		(
			Time.get_ticks_usec()
			^ int(Time.get_unix_time_from_system() * 1000000.0)
			^ randi()
		) & 0x7fffffff
	)
