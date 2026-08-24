class_name PixelAvatar
extends RefCounted

const PANEL := Color("#12345b")
const WHITE := Color("#f7f4ff")
const COLORS := [
	Color("#74ddff"),
	Color("#ffd84a"),
	Color("#f15b68"),
	Color("#ff8a3d"),
	Color("#56d46f"),
	Color("#6d83f2"),
	Color("#c967e8"),
]


static func draw(
	canvas: CanvasItem,
	identity: String,
	position: Vector2,
	scale: int = 1
) -> void:
	var avatar_size := 8 * scale
	canvas.draw_rect(
		Rect2(position, Vector2(avatar_size, avatar_size)),
		PANEL
	)

	var identity_hash := _identity_hash(identity)
	var primary: Color = COLORS[posmod(identity_hash, COLORS.size())]
	var secondary: Color = COLORS[
		posmod(identity_hash >> 8, COLORS.size())
	]
	for y in range(3):
		for x in range(3):
			var bit_index := y * 3 + x
			if ((identity_hash >> bit_index) & 1) == 0:
				continue
			var color := primary if (bit_index % 2 == 0) else secondary
			_draw_mirrored_pixel(
				canvas,
				position,
				x,
				y,
				color,
				scale
			)

	canvas.draw_rect(
		Rect2(
			position + Vector2(3, 6) * scale,
			Vector2(2, 1) * scale
		),
		WHITE
	)


static func _draw_mirrored_pixel(
	canvas: CanvasItem,
	position: Vector2,
	x: int,
	y: int,
	color: Color,
	scale: int
) -> void:
	var left := position + Vector2(x + 1, y + 1) * scale
	canvas.draw_rect(Rect2(left, Vector2.ONE * scale), color)

	var mirrored_x := 6 - x
	if mirrored_x == x + 1:
		return
	var right := position + Vector2(mirrored_x, y + 1) * scale
	canvas.draw_rect(Rect2(right, Vector2.ONE * scale), color)


static func _identity_hash(identity: String) -> int:
	var value := 2166136261
	var normalized := identity.strip_edges().to_upper()
	if normalized.begins_with("@"):
		normalized = normalized.substr(1)
	for index in range(normalized.length()):
		value = (value ^ normalized.unicode_at(index)) * 16777619
		value &= 0x7fffffff
	return value
