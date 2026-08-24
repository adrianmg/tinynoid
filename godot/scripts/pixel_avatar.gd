class_name PixelAvatar
extends RefCounted

const PANEL := Color("#12345b")
const CYAN := Color("#74ddff")


static func draw(
	canvas: CanvasItem,
	identity: String,
	position: Vector2,
	scale: int = 1
) -> void:
	var avatar_size := 8 * scale
	var texture := AvatarCache.get_avatar(identity)
	if texture != null:
		canvas.draw_texture_rect(
			texture,
			Rect2(position, Vector2(avatar_size, avatar_size)),
			false
		)
		return

	AvatarCache.request_avatar(identity)
	canvas.draw_rect(
		Rect2(position, Vector2(avatar_size, avatar_size)),
		PANEL
	)
	canvas.draw_rect(
		Rect2(
			position + Vector2(3, 2) * scale,
			Vector2(2, 3) * scale
		),
		CYAN
	)
