class_name PowerUp
extends Area2D

signal picked_up(power_type: int)

enum PowerType {
	WIDE,
	SLOW,
	MULTI,
	EXTRA_BALL,
	CATCH,
	LASER,
	BREAK,
}

const WHITE := Color("#f7f4ff")
const OUTLINE := Color("#111329")
const POWER_TYPE_COUNT := 7

@export var fall_speed := 70.0

var power_type := PowerType.WIDE
var _collected := false


func configure(type: int) -> void:
	assert(type >= PowerType.WIDE and type < POWER_TYPE_COUNT)
	power_type = type


func _ready() -> void:
	body_entered.connect(collect)
	queue_redraw()


func _physics_process(delta: float) -> void:
	position.y += fall_speed * delta
	if global_position.y > 244:
		queue_free()


func _draw() -> void:
	var chip_color := get_type_color(power_type)
	draw_rect(Rect2(-6, -4, 12, 8), OUTLINE)
	draw_rect(Rect2(-5, -3, 10, 6), chip_color)
	draw_rect(Rect2(-4, -2, 8, 1), chip_color.lightened(0.4))
	draw_rect(Rect2(-5, -2, 1, 4), WHITE)
	draw_rect(Rect2(4, -2, 1, 4), chip_color.darkened(0.45))
	PixelFont.draw_text(
		self,
		get_type_symbol(power_type),
		Vector2(-1, -2),
		WHITE
	)


func collect(body: Node2D) -> void:
	if _collected or not body is PaddleController:
		return

	_collected = true
	set_deferred("monitoring", false)
	picked_up.emit(power_type)
	queue_free()


static func get_type_label(type: int) -> String:
	match type:
		PowerType.WIDE:
			return "EXPAND"
		PowerType.SLOW:
			return "SLOW"
		PowerType.MULTI:
			return "DISRUPT"
		PowerType.EXTRA_BALL:
			return "PLAYER"
		PowerType.CATCH:
			return "CATCH"
		PowerType.LASER:
			return "LASER"
		PowerType.BREAK:
			return "BREAK"

	return ""


static func get_type_symbol(type: int) -> String:
	match type:
		PowerType.WIDE:
			return "E"
		PowerType.SLOW:
			return "S"
		PowerType.MULTI:
			return "D"
		PowerType.EXTRA_BALL:
			return "P"
		PowerType.CATCH:
			return "C"
		PowerType.LASER:
			return "L"
		PowerType.BREAK:
			return "B"

	return "?"


static func get_type_color(type: int) -> Color:
	match type:
		PowerType.WIDE:
			return Color("#45c7f2")
		PowerType.SLOW:
			return Color("#ff8a3d")
		PowerType.MULTI:
			return Color("#74ddff")
		PowerType.EXTRA_BALL:
			return Color("#b8c0c8")
		PowerType.CATCH:
			return Color("#56d46f")
		PowerType.LASER:
			return Color("#f15b68")
		PowerType.BREAK:
			return Color("#c967e8")

	return WHITE
