class_name RetroArena
extends Node2D

# THESIS: The arena feels printed by a console, not dressed like a modern UI.
# OWN-WORLD: Ink-black space, segmented ice-blue rails, one-pixel stars, hard edges.
# STORY: Read score, launch instantly, clear the rainbow gate, replay.
# FIRST VIEWPORT: A compact HUD crowns a framed vertical arena at native 256x240.
# FORM: Full-palette cartridge-era experience; the playfield remains the hero.

const VOID := Color("#050611")
const RAIL_DARK := Color("#12345b")
const RAIL_MID := Color("#287fc4")
const RAIL_LIGHT := Color("#74ddff")
const STAR_DIM := Color("#28366f")
const STAR_BRIGHT := Color("#8da9ff")
const STARS := [
	Vector2i(25, 42), Vector2i(47, 129), Vector2i(72, 37),
	Vector2i(91, 154), Vector2i(112, 44), Vector2i(139, 139),
	Vector2i(161, 38), Vector2i(184, 158), Vector2i(212, 43),
	Vector2i(227, 122), Vector2i(35, 184), Vector2i(78, 204),
	Vector2i(121, 176), Vector2i(168, 201), Vector2i(218, 187),
]


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 256, 240), VOID)

	for star_index in range(STARS.size()):
		var star_color := STAR_BRIGHT if star_index % 4 == 0 else STAR_DIM
		draw_rect(Rect2(STARS[star_index], Vector2.ONE), star_color)

	_draw_horizontal_rail()
	_draw_vertical_rail(8)
	_draw_vertical_rail(240)


func _draw_horizontal_rail() -> void:
	draw_rect(Rect2(8, 24, 240, 8), RAIL_DARK)
	draw_rect(Rect2(9, 25, 238, 2), RAIL_LIGHT)
	draw_rect(Rect2(9, 27, 238, 3), RAIL_MID)
	for x in range(16, 248, 16):
		draw_rect(Rect2(x, 29, 8, 2), RAIL_DARK)


func _draw_vertical_rail(x: int) -> void:
	draw_rect(Rect2(x, 32, 8, 208), RAIL_DARK)

	for y in range(32, 240, 8):
		var segment_color := RAIL_MID if (y / 8 as int) % 2 == 0 else RAIL_DARK
		draw_rect(Rect2(x + 1, y, 6, 7), segment_color)
		draw_rect(Rect2(x + 1, y, 1, 7), RAIL_LIGHT)
		draw_rect(Rect2(x + 2, y, 4, 1), RAIL_LIGHT)
