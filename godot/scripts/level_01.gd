class_name Level01
extends Node2D

signal brick_broken(
	points: int,
	world_position: Vector2,
	effect_color: Color
)
signal brick_struck(
	world_position: Vector2,
	effect_color: Color,
	hit_kind: int
)
signal level_cleared

const BRICK_SCENE: PackedScene = preload("res://scenes/entities/brick.tscn")
const BRICK_PATTERN_ORIGIN := Vector2(24, 48)
const BRICK_CELL_SIZE := Vector2(16, 10)

@onready var background: RetroArena = $Background
@onready var bricks: Node2D = $Bricks

var _remaining_bricks := 0


func _ready() -> void:
	_spawn_bricks()


func get_brick_count() -> int:
	return bricks.get_child_count()


func get_destructible_brick_count() -> int:
	return _remaining_bricks


func get_stage_name() -> String:
	return GameSession.get_active_level_name()


func _spawn_bricks() -> void:
	var layout := GameSession.get_active_layout()
	var destructible_bricks: Array[Brick] = []

	for row_index in range(layout.size()):
		var pattern_row: String = layout[row_index]
		for column_index in range(pattern_row.length()):
			var brick_type := pattern_row.substr(column_index, 1)
			if brick_type == ".":
				brick_type = " "
			if brick_type == " ":
				continue

			var definition := BrickRules.get_definition(
				brick_type,
				GameSession.level
			)
			var brick: Brick = BRICK_SCENE.instantiate()
			brick.position = BRICK_PATTERN_ORIGIN + Vector2(
				column_index * BRICK_CELL_SIZE.x + BRICK_CELL_SIZE.x / 2.0,
				row_index * BRICK_CELL_SIZE.y + 4.0
			)
			brick.brick_color = definition.color
			brick.shadow_color = definition.shadow
			brick.score = definition.score
			brick.hit_points = definition.hit_points
			brick.indestructible = definition.indestructible
			brick.struck.connect(_on_brick_struck)
			brick.broken.connect(_on_brick_broken)
			bricks.add_child(brick)
			if not brick.indestructible:
				destructible_bricks.append(brick)

	_remaining_bricks = destructible_bricks.size()


func _on_brick_struck(
	world_position: Vector2,
	effect_color: Color,
	hit_kind: int
) -> void:
	brick_struck.emit(world_position, effect_color, hit_kind)


func _on_brick_broken(
	points: int,
	world_position: Vector2,
	effect_color: Color
) -> void:
	_remaining_bricks -= 1
	brick_broken.emit(points, world_position, effect_color)

	if _remaining_bricks == 0:
		level_cleared.emit()
