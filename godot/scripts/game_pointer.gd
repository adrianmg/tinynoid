class_name GamePointer
extends RefCounted


static func is_primary_press(event: InputEvent) -> bool:
	return (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	)


static func has_primary_position(event: InputEvent) -> bool:
	return (
		event is InputEventMouseMotion
		or (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and event.pressed
		)
	)


static func get_position(event: InputEvent) -> Vector2:
	assert(
		has_primary_position(event),
		"The input event does not carry a primary pointer position."
	)
	if event is InputEventMouseMotion:
		return event.position
	if event is InputEventMouseButton:
		return event.position
	return Vector2.ZERO


static func is_primary_drag(event: InputEvent) -> bool:
	return (
		event is InputEventMouseMotion
		and bool(event.button_mask & MOUSE_BUTTON_MASK_LEFT)
	)


static func is_mobile_device() -> bool:
	return (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)
