class_name GameSessionState
extends Node

signal state_changed(score: int, balls_remaining: int, level: int)

enum BallLossOutcome {
	RESTART_LEVEL,
	GAME_OVER,
}

const STARTING_BALLS := 3

var score := 0
var high_score := 0
var balls_remaining := STARTING_BALLS
var level := 1


func new_game(start_level: int = 1) -> void:
	assert(
		start_level >= 1 and start_level <= LevelCatalog.STAGE_COUNT,
		"Start level is outside the campaign."
	)
	score = 0
	balls_remaining = STARTING_BALLS
	level = start_level
	_emit_state_changed()


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


func _emit_state_changed() -> void:
	state_changed.emit(score, balls_remaining, level)
