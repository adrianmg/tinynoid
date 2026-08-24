class_name BreakerBall
extends CharacterBody2D

signal launched
signal deactivated

const BASE_SPEED := 200.0
const SLOW_SPEED := 150.0
const PADDLE_TOP_NORMAL_THRESHOLD := -0.75
const BRICK_COLLISION_MASK := 1 << 3

@export var speed := BASE_SPEED
@export var hold_offset_y := -8.0
@export_range(1, 8, 1) var max_collisions_per_tick := 4

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _paddle: PaddleController
var _direction := Vector2.ZERO
var _active := false
var _piercing_enabled := false
var _piercing_contacts: Dictionary[int, bool] = {}


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-2, -3, 4, 6), Color("#18244f"))
	draw_rect(Rect2(-3, -2, 6, 4), Color("#18244f"))
	draw_rect(Rect2(-2, -2, 4, 4), Color("#f7f4ff"))
	draw_rect(Rect2(-1, -2, 2, 1), Color("#74ddff"))
	if _piercing_enabled:
		draw_rect(Rect2(-4, 0, 1, 1), Color("#ffd84a"))
		draw_rect(Rect2(3, 0, 1, 1), Color("#ffd84a"))
		draw_rect(Rect2(0, -4, 1, 1), Color("#ffd84a"))
		draw_rect(Rect2(0, 3, 1, 1), Color("#ffd84a"))


func attach_to(paddle: PaddleController) -> void:
	assert(paddle != null, "The ball requires a paddle.")
	_paddle = paddle
	_follow_paddle()


func launch() -> void:
	if _active:
		return
	if _paddle == null:
		push_error("The ball cannot launch before attach_to() is called.")
		return

	var horizontal_direction := _paddle.get_launch_horizontal_direction()
	launch_in_direction(Vector2(horizontal_direction * 0.5, -1.0))


func launch_in_direction(direction: Vector2) -> void:
	if _active:
		return
	if direction.is_zero_approx():
		push_error("The ball requires a non-zero launch direction.")
		return

	_direction = direction.normalized()
	velocity = _direction * speed
	_active = true
	launched.emit()


func deactivate() -> void:
	_active = false
	velocity = Vector2.ZERO
	set_physics_process(false)
	deactivated.emit()


func is_active() -> bool:
	return _active


func apply_slow() -> void:
	speed = SLOW_SPEED
	if _active:
		velocity = _direction * speed


func reset_speed() -> void:
	speed = BASE_SPEED
	if _active:
		velocity = _direction * speed


func reset_for_serve(paddle: PaddleController) -> void:
	deactivate()
	speed = BASE_SPEED
	set_piercing(false)
	_paddle = paddle
	set_physics_process(true)
	_follow_paddle()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("launch") and not _active:
		launch()
		get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not _active:
		_follow_paddle()
		return

	_move_with_bounces(delta)
	if _piercing_enabled:
		_damage_overlapping_bricks()


func _follow_paddle() -> void:
	if _paddle == null:
		return

	global_position = Vector2(
		_paddle.global_position.x,
		_paddle.global_position.y + hold_offset_y
	)
	velocity = Vector2.ZERO


func _move_with_bounces(delta: float) -> void:
	velocity = _direction.normalized() * speed
	var remaining_motion := velocity * delta

	for collision_index in range(max_collisions_per_tick):
		if remaining_motion.is_zero_approx():
			return

		var collision := move_and_collide(remaining_motion)
		if collision == null:
			return

		var collider := collision.get_collider()
		var collider_node := collider as Node
		var remaining_distance := collision.get_remainder().length()

		if collider is PaddleController:
			var collision_normal := collision.get_normal()
			if (
				_direction.y > 0.0
				and collision_normal.y <= PADDLE_TOP_NORMAL_THRESHOLD
			):
				if collider.catch_enabled:
					catch_on_paddle(collider)
					return
				_direction = collider.get_bounce_direction(
					global_position.x,
					_direction
				)
			else:
				_direction = _direction.bounce(
					collision_normal
				).normalized()
		else:
			_direction = _direction.bounce(collision.get_normal()).normalized()
			if collider_node != null and collider_node.is_in_group("bricks"):
				collider_node.call(&"hit")
				velocity = _direction * speed
				return

		velocity = _direction * speed
		remaining_motion = _direction * remaining_distance


func catch_on_paddle(paddle: PaddleController) -> void:
	_active = false
	velocity = Vector2.ZERO
	_paddle = paddle
	set_physics_process(true)
	deactivated.emit()
	_follow_paddle()


func set_piercing(enabled: bool) -> void:
	_piercing_enabled = enabled
	if not enabled:
		_piercing_contacts.clear()
	queue_redraw()
	call_deferred("_apply_piercing_state", enabled)


func is_piercing() -> bool:
	return _piercing_enabled


func _apply_piercing_state(enabled: bool) -> void:
	if enabled != _piercing_enabled:
		return

	set_collision_mask_value(4, not enabled)


func _damage_overlapping_bricks() -> void:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = collision_shape.shape
	query.transform = global_transform
	query.collision_mask = BRICK_COLLISION_MASK
	query.collide_with_areas = false
	query.collide_with_bodies = true

	var current_contacts: Dictionary[int, bool] = {}
	for result in get_world_2d().direct_space_state.intersect_shape(query, 8):
		var body := result.get("collider") as Node
		if (
			body == null
			or not body.is_in_group("bricks")
			or body.get("indestructible")
		):
			continue

		var body_id := body.get_instance_id()
		current_contacts[body_id] = true
		if not _piercing_contacts.has(body_id):
			body.call(&"hit")

	_piercing_contacts = current_contacts
