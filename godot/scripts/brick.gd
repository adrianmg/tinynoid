class_name Brick
extends StaticBody2D

enum HitKind {
	REGULAR,
	DURABLE,
	INDESTRUCTIBLE,
}

signal broken(
	points: int,
	world_position: Vector2,
	effect_color: Color,
	power_up_type: int
)
signal struck(
	world_position: Vector2,
	effect_color: Color,
	hit_kind: int
)

const HIT_FLASH_DURATION := 0.08
const FLASH_COLOR := Color("#f7f4ff")

@export_range(1, 99, 1) var hit_points := 1
@export var score := 50
@export var brick_color := Color("#f15b68")
@export var shadow_color := Color("#8b263d")
@export var power_up_type := -1
@export var indestructible := false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _broken := false
var _max_hit_points := 1
var _flash_time_left := 0.0


func _ready() -> void:
	_max_hit_points = maxi(hit_points, 1)
	set_process(false)
	queue_redraw()


func _process(delta: float) -> void:
	_flash_time_left = maxf(0.0, _flash_time_left - delta)
	queue_redraw()
	if _flash_time_left <= 0.0:
		set_process(false)


func _draw() -> void:
	var damage_ratio := 0.0
	if not indestructible and _max_hit_points > 1:
		damage_ratio = 1.0 - float(hit_points) / _max_hit_points
	var display_color := (
		FLASH_COLOR
		if is_flashing()
		else brick_color.darkened(damage_ratio * 0.28)
	)

	draw_rect(Rect2(-7, -4, 14, 8), Color("#111329"))
	draw_rect(Rect2(-6, -3, 12, 6), display_color)
	draw_rect(
		Rect2(-5, -2, 10, 1),
		FLASH_COLOR if is_flashing() else display_color.lightened(0.38)
	)
	draw_rect(Rect2(-5, 2, 10, 1), shadow_color)
	draw_rect(Rect2(5, -1, 1, 3), shadow_color)

	if indestructible:
		draw_rect(Rect2(-3, 0, 6, 1), Color("#f7f4ff"))
	elif _max_hit_points > 1 and hit_points > 0:
		for pip_index in range(mini(hit_points, 5)):
			draw_rect(
				Rect2(-5 + pip_index * 2, 1, 1, 1),
				Color("#f7f4ff")
			)


func hit() -> void:
	if _broken:
		return

	var hit_kind := HitKind.REGULAR
	if indestructible:
		hit_kind = HitKind.INDESTRUCTIBLE
	elif _max_hit_points > 1:
		hit_kind = HitKind.DURABLE
	struck.emit(global_position, brick_color, hit_kind)
	if indestructible:
		return

	hit_points -= 1
	if hit_points > 0:
		if hit_kind == HitKind.DURABLE:
			_flash_time_left = HIT_FLASH_DURATION
			set_process(true)
		queue_redraw()
		return

	_broken = true
	collision_shape.set_deferred("disabled", true)
	broken.emit(score, global_position, brick_color, power_up_type)
	queue_free()


func is_flashing() -> bool:
	return _flash_time_left > 0.0
