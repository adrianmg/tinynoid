class_name Gameplay
extends Node2D

signal restart_requested
signal game_over_requested
signal stage_clear_requested

const BRICK_BREAK_EFFECT_SCENE: PackedScene = preload(
	"res://scenes/effects/brick_break_effect.tscn"
)
const BALL_SCENE: PackedScene = preload("res://scenes/entities/ball.tscn")
const POWER_UP_SCENE: PackedScene = preload(
	"res://scenes/entities/power_up.tscn"
)
const LASER_SCENE: PackedScene = preload(
	"res://scenes/entities/laser_shot.tscn"
)
const POWER_UP_SCORE := 100
const LASER_COOLDOWN := 0.22

@onready var level: Level01 = $Level01
@onready var paddle: PaddleController = $Paddle
@onready var balls: Node2D = $Balls
@onready var ball: BreakerBall = $Balls/Ball
@onready var death_zone: Area2D = $DeathZone
@onready var effects: Node2D = $Effects
@onready var power_ups: Node2D = $PowerUps
@onready var lasers: Node2D = $Lasers
@onready var brick_audio: BrickAudio = $BrickAudio
@onready var hud: RetroHud = $HudLayer/Hud

var _transition_pending := false
var _transition_epoch := 0
var _active_power_up := -1
var _laser_cooldown_remaining := 0.0


func _ready() -> void:
	ball.attach_to(paddle)
	ball.launched.connect(_on_ball_launched)
	level.brick_struck.connect(_on_brick_struck)
	level.brick_broken.connect(_on_brick_broken)
	level.level_cleared.connect(_on_level_cleared)
	death_zone.body_entered.connect(_on_death_zone_body_entered)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart") and not _transition_pending:
		_begin_transition()
		get_viewport().set_input_as_handled()
		call_deferred("_emit_restart_requested")
	elif (
		event.is_action_pressed("launch")
		and _active_power_up == PowerUp.PowerType.LASER
		and not _transition_pending
	):
		_spawn_lasers()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_laser_cooldown_remaining = maxf(
		0.0,
		_laser_cooldown_remaining - delta
	)


func _on_brick_broken(
	points: int,
	world_position: Vector2,
	effect_color: Color,
	power_up_type: int
) -> void:
	GameSession.award(points)

	var effect: BrickBreakEffect = BRICK_BREAK_EFFECT_SCENE.instantiate()
	effect.configure(effect_color)
	effects.add_child(effect)
	effect.global_position = world_position

	if power_up_type >= 0:
		var power_up: PowerUp = POWER_UP_SCENE.instantiate()
		power_up.configure(power_up_type)
		power_up.picked_up.connect(_on_power_up_picked)
		power_ups.add_child(power_up)
		power_up.global_position = world_position


func _on_brick_struck(
	_world_position: Vector2,
	_effect_color: Color,
	hit_kind: int
) -> void:
	brick_audio.play_hit(hit_kind)


func _on_power_up_picked(power_type: int) -> void:
	if _transition_pending:
		return

	call_deferred(
		"_apply_power_up_if_current",
		power_type,
		_transition_epoch
	)


func _apply_power_up_if_current(
	power_type: int,
	captured_epoch: int
) -> void:
	if (
		_transition_pending
		or captured_epoch != _transition_epoch
	):
		return

	apply_power_up(power_type)


func _on_ball_launched() -> void:
	hud.set_launch_ready(false)


func apply_power_up(power_type: int) -> void:
	if _transition_pending:
		return

	var instant := (
		power_type == PowerUp.PowerType.EXTRA_BALL
		or power_type == PowerUp.PowerType.BREAK
	)
	if not instant:
		_clear_active_power_up()

	match power_type:
		PowerUp.PowerType.WIDE:
			paddle.apply_wide()
		PowerUp.PowerType.SLOW:
			for active_ball in _get_balls():
				active_ball.apply_slow()
		PowerUp.PowerType.MULTI:
			_apply_multi_ball()
		PowerUp.PowerType.EXTRA_BALL:
			GameSession.add_ball()
		PowerUp.PowerType.CATCH:
			paddle.enable_catch()
		PowerUp.PowerType.LASER:
			paddle.enable_laser()
		PowerUp.PowerType.BREAK:
			pass
		_:
			push_error("Unknown power-up type: %d" % power_type)
			return

	if not instant:
		_active_power_up = power_type

	GameSession.award(POWER_UP_SCORE)
	hud.show_power_up(
		PowerUp.get_type_label(power_type),
		PowerUp.get_type_color(power_type)
	)
	if power_type == PowerUp.PowerType.BREAK:
		call_deferred("_activate_break")


func _on_level_cleared() -> void:
	if _transition_pending:
		return

	_begin_transition()
	_clear_active_power_up()
	_clear_falling_power_ups()
	for active_ball in _get_balls():
		active_ball.deactivate()
	call_deferred("_emit_stage_clear_requested")


func _on_death_zone_body_entered(body: Node2D) -> void:
	if not body is BreakerBall or _transition_pending:
		return

	var lost_ball := body as BreakerBall
	lost_ball.deactivate()

	var surviving_balls := _get_balls().filter(
		func(candidate: BreakerBall) -> bool:
			return candidate != lost_ball
	)
	if not surviving_balls.is_empty():
		lost_ball.queue_free()
		if (
			_active_power_up == PowerUp.PowerType.MULTI
			and surviving_balls.size() == 1
		):
			_clear_active_power_up()
		return

	_begin_transition()
	var outcome := GameSession.register_ball_lost()
	if outcome == GameSessionState.BallLossOutcome.RESTART_LEVEL:
		call_deferred("_reset_after_life_loss", lost_ball)
	else:
		_clear_active_power_up()
		_clear_falling_power_ups()
		call_deferred("_emit_game_over_requested")


func _emit_restart_requested() -> void:
	restart_requested.emit()


func _emit_game_over_requested() -> void:
	game_over_requested.emit()


func _emit_stage_clear_requested() -> void:
	stage_clear_requested.emit()


func _activate_break() -> void:
	if _transition_pending:
		return
	_on_level_cleared()


func _begin_transition() -> void:
	_transition_pending = true
	_transition_epoch += 1


func _apply_multi_ball() -> void:
	var active_balls := _get_balls()
	if active_balls.is_empty() or active_balls.size() >= 3:
		return

	var source_ball := active_balls[0]
	var spawn_position := source_ball.global_position
	var directions := [
		Vector2(-0.72, -1.0),
		Vector2(0.72, -1.0),
	]

	while active_balls.size() < 3:
		var extra_ball: BreakerBall = BALL_SCENE.instantiate()
		extra_ball.speed = source_ball.speed
		balls.add_child(extra_ball)
		extra_ball.attach_to(paddle)
		extra_ball.global_position = spawn_position
		extra_ball.launch_in_direction(
			directions[active_balls.size() - 1]
		)
		active_balls.append(extra_ball)


func _spawn_lasers() -> void:
	if _laser_cooldown_remaining > 0.0:
		return

	_laser_cooldown_remaining = LASER_COOLDOWN
	var half_width := paddle.paddle_width / 2.0
	for horizontal_offset in [
		-half_width + 4.0,
		half_width - 4.0,
	]:
		var laser: LaserShot = LASER_SCENE.instantiate()
		lasers.add_child(laser)
		laser.global_position = (
			paddle.global_position
			+ Vector2(horizontal_offset, -7.0)
		)


func get_active_power_up() -> int:
	return _active_power_up


func _clear_active_power_up() -> void:
	match _active_power_up:
		PowerUp.PowerType.WIDE:
			paddle.reset_width()
		PowerUp.PowerType.SLOW:
			for active_ball in _get_balls():
				active_ball.reset_speed()
		PowerUp.PowerType.MULTI:
			_collapse_to_single_ball()
		PowerUp.PowerType.CATCH, PowerUp.PowerType.LASER:
			paddle.clear_power_mode()

	_active_power_up = -1
	_clear_lasers()
	hud.clear_power_up_status()


func _collapse_to_single_ball() -> void:
	var active_balls := _get_balls()
	if active_balls.is_empty():
		return

	var keeper := active_balls[0]
	if is_instance_valid(ball) and ball in active_balls:
		keeper = ball

	for active_ball in active_balls:
		if active_ball != keeper:
			active_ball.queue_free()

	ball = keeper


func _clear_falling_power_ups() -> void:
	for power_up in power_ups.get_children():
		power_up.queue_free()


func _clear_lasers() -> void:
	for laser in lasers.get_children():
		laser.queue_free()
	_laser_cooldown_remaining = 0.0


func _reset_after_life_loss(lost_ball: BreakerBall) -> void:
	_clear_active_power_up()
	_clear_falling_power_ups()
	paddle.reset_for_serve()
	ball = lost_ball
	ball.reset_for_serve(paddle)
	hud.set_launch_ready(true)
	_transition_pending = false


func _get_balls() -> Array[BreakerBall]:
	var active_balls: Array[BreakerBall] = []
	for child in balls.get_children():
		if child is BreakerBall and not child.is_queued_for_deletion():
			active_balls.append(child)

	return active_balls
