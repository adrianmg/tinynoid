class_name GamePointer
extends RefCounted


static func is_primary_press(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return (
			event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
	if event is InputEventScreenTouch:
		return event.index == 0 and event.pressed
	return false


static func has_primary_position(event: InputEvent) -> bool:
	return (
		event is InputEventMouseMotion
		or (
			event is InputEventScreenTouch
			and event.index == 0
			and event.pressed
		)
		or (
			event is InputEventScreenDrag
			and event.index == 0
		)
	)


static func get_position(event: InputEvent) -> Vector2:
	assert(
		has_primary_position(event),
		"The input event does not carry a primary pointer position."
	)
	if event is InputEventMouseMotion:
		return event.position
	if event is InputEventScreenTouch:
		return event.position
	if event is InputEventScreenDrag:
		return event.position
	return Vector2.ZERO
