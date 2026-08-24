class_name BallTrail
extends Node2D

@export var lifetime := 0.12
@export var minimum_point_distance := 2.0
@export var afterimage_size := 2

const AFTERIMAGE_COLORS := [
	Color("#f7f4ff"),
	Color("#74ddff"),
	Color("#287fc4"),
	Color("#12345b"),
]

var _samples: Array[Dictionary] = []


func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	visible = false

	var ball := get_parent() as BreakerBall
	ball.launched.connect(_on_ball_launched)
	ball.deactivated.connect(_on_ball_deactivated)


func _process(delta: float) -> void:
	var ball := get_parent() as BreakerBall
	if not ball.is_active():
		_clear()
		return

	for sample in _samples:
		sample.age += delta

	while not _samples.is_empty() and _samples[0].age > lifetime:
		_samples.pop_front()

	var parent_node := get_parent() as Node2D
	var current_position: Vector2 = parent_node.global_position
	if _samples.is_empty() or _samples.back().position.distance_to(current_position) >= minimum_point_distance:
		_samples.append({
			"position": current_position.round(),
			"age": 0.0,
		})

	queue_redraw()


func get_sample_count() -> int:
	return _samples.size()


func _on_ball_launched() -> void:
	_clear()
	visible = true


func _on_ball_deactivated() -> void:
	visible = false
	_clear()


func _clear() -> void:
	if _samples.is_empty():
		return

	_samples.clear()
	queue_redraw()


func _draw() -> void:
	for sample in _samples:
		var progress: float = clampf(sample.age / lifetime, 0.0, 1.0)
		var palette_index := mini(
			floori(progress * AFTERIMAGE_COLORS.size()),
			AFTERIMAGE_COLORS.size() - 1
		)
		var position: Vector2 = sample.position
		draw_rect(
			Rect2(
				position - Vector2.ONE * afterimage_size / 2.0,
				Vector2.ONE * afterimage_size
			),
			AFTERIMAGE_COLORS[palette_index]
		)
