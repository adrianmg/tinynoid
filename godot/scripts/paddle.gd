class_name PaddleController
extends CharacterBody2D

const PLAYFIELD_CENTER_X := 128.0
const ARENA_LEFT := 16.0
const ARENA_RIGHT := 240.0
const STANDARD_WIDTH := 40.0
const WIDE_WIDTH := 56.0
const MAX_BOUNCE_ANGLE := deg_to_rad(68.0)
const PADDLE_ENGLISH_WEIGHT := 0.18

@export var speed := 240.0
@export var left_boundary := 36.0
@export var right_boundary := 220.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var horizontal_velocity := 0.0
var paddle_width := STANDARD_WIDTH
var catch_enabled := false
var laser_enabled := false
var _pointer_target_x := PLAYFIELD_CENTER_X
var _pointer_moved := false


func _ready() -> void:
	_pointer_target_x = global_position.x
	queue_redraw()


func _draw() -> void:
	var half_width := paddle_width / 2.0
	draw_rect(Rect2(-half_width, -4, paddle_width, 8), Color("#111329"))
	draw_rect(
		Rect2(-half_width + 2, -3, paddle_width - 4, 6),
		Color("#f7f4ff")
	)
	draw_rect(
		Rect2(-half_width + 2, -3, paddle_width - 4, 1),
		Color("#bff3ff")
	)
	draw_rect(Rect2(-half_width, -3, 4, 6), Color("#36bff2"))
	draw_rect(Rect2(half_width - 4, -3, 4, 6), Color("#36bff2"))
	draw_rect(
		Rect2(-half_width + 6, 2, paddle_width - 12, 1),
		Color("#8994b8")
	)
	if catch_enabled:
		draw_rect(
			Rect2(-half_width + 7, -1, paddle_width - 14, 2),
			Color("#ffd84a")
		)
	if laser_enabled:
		draw_rect(Rect2(-half_width, -5, 4, 2), Color("#f15b68"))
		draw_rect(Rect2(half_width - 4, -5, 4, 2), Color("#f15b68"))


func _input(event: InputEvent) -> void:
	if GamePointer.has_primary_position(event):
		_pointer_target_x = GamePointer.get_position(event).x
		_pointer_moved = true


func _physics_process(delta: float) -> void:
	var action_axis := Input.get_axis("move_left", "move_right")
	var ui_axis := Input.get_axis("ui_left", "ui_right")
	var input_axis := action_axis if not is_zero_approx(action_axis) else ui_axis
	var previous_x := global_position.x

	if not is_zero_approx(input_axis):
		_pointer_moved = false
		global_position.x = clampf(
			global_position.x + input_axis * speed * delta,
			left_boundary,
			right_boundary
		)
	elif _pointer_moved:
		global_position.x = clampf(_pointer_target_x, left_boundary, right_boundary)
		_pointer_moved = false

	horizontal_velocity = (global_position.x - previous_x) / delta
	velocity = Vector2(horizontal_velocity, 0.0)


func get_launch_horizontal_direction() -> float:
	if not is_zero_approx(horizontal_velocity):
		return signf(horizontal_velocity)

	return -1.0 if global_position.x < PLAYFIELD_CENTER_X else 1.0


func get_bounce_direction(
	ball_x: float,
	incoming_direction: Vector2 = Vector2.UP
) -> Vector2:
	var half_width := paddle_width / 2.0
	var impact_offset := clampf(
		(ball_x - global_position.x) / half_width,
		-1.0,
		1.0
	)
	var motion_influence := clampf(
		horizontal_velocity / speed,
		-1.0,
		1.0
	) * PADDLE_ENGLISH_WEIGHT
	var steered_offset := clampf(
		impact_offset + motion_influence,
		-1.0,
		1.0
	)

	if is_zero_approx(steered_offset) and not is_zero_approx(incoming_direction.x):
		steered_offset = signf(incoming_direction.x) * 0.08

	var bounce_angle := steered_offset * MAX_BOUNCE_ANGLE
	return Vector2(sin(bounce_angle), -cos(bounce_angle)).normalized()


func apply_wide() -> void:
	_set_width(WIDE_WIDTH)


func enable_catch() -> void:
	catch_enabled = true
	queue_redraw()


func enable_laser() -> void:
	laser_enabled = true
	queue_redraw()


func clear_power_mode() -> void:
	catch_enabled = false
	laser_enabled = false
	queue_redraw()


func reset_width() -> void:
	_set_width(STANDARD_WIDTH)


func reset_for_serve() -> void:
	reset_width()
	clear_power_mode()
	global_position.x = PLAYFIELD_CENTER_X
	horizontal_velocity = 0.0
	velocity = Vector2.ZERO
	_pointer_target_x = PLAYFIELD_CENTER_X
	_pointer_moved = false


func _set_width(width: float) -> void:
	paddle_width = width
	var rectangle_shape := collision_shape.shape as RectangleShape2D
	rectangle_shape.size.x = paddle_width
	left_boundary = ARENA_LEFT + paddle_width / 2.0
	right_boundary = ARENA_RIGHT - paddle_width / 2.0
	global_position.x = clampf(global_position.x, left_boundary, right_boundary)
	queue_redraw()
