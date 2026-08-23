class_name LaserShot
extends Area2D

@export var speed := 340.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	position.y -= speed * delta
	if global_position.y < 24.0:
		queue_free()


func _draw() -> void:
	draw_rect(Rect2(-1, -4, 2, 8), Color("#111329"))
	draw_rect(Rect2(0, -3, 1, 6), Color("#f15b68"))
	draw_rect(Rect2(0, -3, 1, 2), Color("#f7f4ff"))


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("bricks"):
		return

	body.call(&"hit")
	queue_free()

