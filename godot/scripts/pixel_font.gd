class_name PixelFont
extends RefCounted

const GLYPHS := {
	"0": ["111", "101", "101", "101", "111"],
	"1": ["010", "110", "010", "010", "111"],
	"2": ["110", "001", "010", "100", "111"],
	"3": ["110", "001", "010", "001", "110"],
	"4": ["101", "101", "111", "001", "001"],
	"5": ["111", "100", "110", "001", "110"],
	"6": ["011", "100", "110", "101", "010"],
	"7": ["111", "001", "010", "010", "010"],
	"8": ["010", "101", "010", "101", "010"],
	"9": ["010", "101", "011", "001", "110"],
	"A": ["010", "101", "111", "101", "101"],
	"B": ["110", "101", "110", "101", "110"],
	"C": ["011", "100", "100", "100", "011"],
	"D": ["110", "101", "101", "101", "110"],
	"E": ["111", "100", "110", "100", "111"],
	"F": ["111", "100", "110", "100", "100"],
	"G": ["011", "100", "101", "101", "011"],
	"H": ["101", "101", "111", "101", "101"],
	"I": ["111", "010", "010", "010", "111"],
	"J": ["001", "001", "001", "101", "010"],
	"K": ["101", "101", "110", "101", "101"],
	"L": ["100", "100", "100", "100", "111"],
	"M": ["101", "111", "111", "101", "101"],
	"N": ["101", "111", "111", "111", "101"],
	"O": ["010", "101", "101", "101", "010"],
	"P": ["110", "101", "110", "100", "100"],
	"Q": ["010", "101", "101", "111", "011"],
	"R": ["110", "101", "110", "101", "101"],
	"S": ["011", "100", "010", "001", "110"],
	"T": ["111", "010", "010", "010", "010"],
	"U": ["101", "101", "101", "101", "111"],
	"V": ["101", "101", "101", "101", "010"],
	"W": ["101", "101", "111", "111", "101"],
	"X": ["101", "101", "010", "101", "101"],
	"Y": ["101", "101", "010", "010", "010"],
	"Z": ["111", "001", "010", "100", "111"],
	":": ["0", "1", "0", "1", "0"],
	"-": ["0", "0", "1", "0", "0"],
	".": ["0", "0", "0", "0", "1"],
	"/": ["001", "001", "010", "100", "100"],
	"&": ["010", "101", "010", "101", "011"],
	"?": ["110", "001", "010", "000", "010"],
}


static func draw_text(
	canvas: CanvasItem,
	text: String,
	position: Vector2,
	color: Color,
	scale: int = 1
) -> void:
	var cursor_x := position.x

	for character in text.to_upper():
		if character == " ":
			cursor_x += 4 * scale
			continue

		var rows: Array = GLYPHS.get(character, GLYPHS["?"])
		for row_index in range(rows.size()):
			var row: String = rows[row_index]
			for column_index in range(row.length()):
				if row.substr(column_index, 1) != "1":
					continue

				canvas.draw_rect(
					Rect2(
						Vector2(
							cursor_x + column_index * scale,
							position.y + row_index * scale
						),
						Vector2(scale, scale)
					),
					color
				)

		cursor_x += 4 * scale


static func draw_centered(
	canvas: CanvasItem,
	text: String,
	y: float,
	color: Color,
	scale: int = 1,
	canvas_width: int = 256
) -> void:
	var text_size := measure(text, scale)
	var x := floorf((canvas_width - text_size.x) / 2.0)
	draw_text(canvas, text, Vector2(x, y), color, scale)


static func measure(text: String, scale: int = 1) -> Vector2:
	if text.is_empty():
		return Vector2.ZERO

	return Vector2((text.length() * 4 - 1) * scale, 5 * scale)
