class_name BrickBreakEffect
extends Node2D

const DURATION := 0.35
const SHARD_DIRECTIONS := [
	Vector2(-1.0, -0.6),
	Vector2(-0.4, -1.0),
	Vector2(0.4, -1.0),
	Vector2(1.0, -0.6),
	Vector2(-1.0, 0.5),
	Vector2(-0.3, 1.0),
	Vector2(0.3, 1.0),
	Vector2(1.0, 0.5),
]

var effect_color := Color("#ffd84a")
var _elapsed := 0.0


func configure(color: Color) -> void:
	effect_color = color


func _ready() -> void:
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()

	if _elapsed >= DURATION:
		queue_free()


func _draw() -> void:
	var progress := clampf(_elapsed / DURATION, 0.0, 1.0)
	var step_index := mini(floori(progress * 4.0), 3)
	var distances := [1.0, 5.0, 10.0, 16.0]
	var shard_size := 2.0 if step_index < 2 else 1.0
	var shard_colors := [
		Color("#f7f4ff"),
		effect_color.lightened(0.35),
		effect_color,
		effect_color.darkened(0.45),
	]
	var shard_color: Color = shard_colors[step_index]

	if step_index == 0:
		draw_rect(Rect2(-5, -3, 10, 6), Color("#f7f4ff"))

	for direction in SHARD_DIRECTIONS:
		var shard_direction: Vector2 = direction
		var position: Vector2 = shard_direction.normalized() * distances[step_index]
		draw_rect(
			Rect2(position - Vector2.ONE * shard_size / 2.0, Vector2.ONE * shard_size),
			shard_color
		)
