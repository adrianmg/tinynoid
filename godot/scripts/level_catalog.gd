class_name LevelCatalog
extends RefCounted

const STAGE_COUNT := 33
const GRID_COLUMNS := 13
const GRID_ROWS := 10
const RAINBOW_GATE := [
	"  RRRRRRRRR  ",
	" OOOOOOOOOOO ",
	"YYYYY   YYYYY",
	" GGGGGGGGGGG ",
	"  CCCCCCCCC  ",
	" BB  BBB  BB ",
	"   PPPPPPP   ",
]
const MOTIF_NAMES := [
	"PULSE GRID",
	"PRISM CORE",
	"TWIN CHEVRON",
	"CHECKER DRIFT",
	"TOWER LINK",
	"HOURGLASS",
	"ORBIT LOCK",
	"WAVEFORM",
]
const PHASE_NAMES := ["I", "II", "III", "IV"]


static func get_layout(stage_number: int) -> Array[String]:
	_validate_stage(stage_number)
	if stage_number == 1:
		var rainbow_layout: Array[String] = []
		for row in RAINBOW_GATE:
			rainbow_layout.append(row)
		return rainbow_layout

	var stage_index := stage_number - 2
	var motif := stage_index % MOTIF_NAMES.size()
	var variant := floori(float(stage_index) / MOTIF_NAMES.size())
	var rows: Array[String] = []

	for y in range(GRID_ROWS):
		var row := ""
		for x in range(GRID_COLUMNS):
			if not _is_active(motif, variant, x, y):
				row += " "
				continue

			var code := BrickRules.get_regular_code(
				x + y * 2 + stage_number
			)
			if stage_number >= 4 and (
				x * 3 + y * 5 + stage_number
			) % 19 == 0:
				code = "S"
			if stage_number >= 8 and (
				x * 7 + y * 3 + stage_number
			) % 37 == 0:
				code = "X"
			row += code

		rows.append(row)

	return rows


static func get_stage_name(stage_number: int) -> String:
	_validate_stage(stage_number)
	if stage_number == 1:
		return "RAINBOW GATE"

	var stage_index := stage_number - 2
	var motif := stage_index % MOTIF_NAMES.size()
	var variant := floori(float(stage_index) / MOTIF_NAMES.size())
	return "%s %s" % [MOTIF_NAMES[motif], PHASE_NAMES[variant]]


static func _is_active(
	motif: int,
	variant: int,
	x: int,
	y: int
) -> bool:
	match motif:
		0:
			return (
				(y % 2 == 0 or (variant >= 2 and y == 5))
				and (x + variant) % (4 + variant) != 0
			)
		1:
			var distance := absi(x - 6) + absi(y - 4)
			var radius := 4 + variant % 2
			return (
				distance <= radius
				and (distance <= 1 or (x + y + variant) % 3 != 0)
			)
		2:
			var base_ridge := 1 + floori(absf(float(x - 6)) / 2.0)
			var ridge_shift := variant % 2
			var upper_ridge := base_ridge + ridge_shift
			var lower_ridge := 8 - base_ridge - ridge_shift
			return (
				y == upper_ridge
				or y == lower_ridge
				or (
					variant >= 2
					and y == 4
					and x % 2 == variant % 2
				)
			)
		3:
			return (
				(x + y + variant) % 2 == 0
				or (variant >= 2 and (x == 1 or x == 11))
			)
		4:
			var tower_width := 1 + variant % 2
			var left_tower := x >= 1 and x <= 1 + tower_width
			var right_tower := x >= 11 - tower_width and x <= 11
			return (
				((left_tower or right_tower) and y >= 1 and y <= 8)
				or (y == 2 + variant and x >= 3 and x <= 9)
			)
		5:
			var spread := absi(y - 4) + 1
			var inside := absi(x - 6) <= spread
			if variant == 2:
				return inside
			if variant == 3:
				return (
					inside
					and ((x + y) % 3 != 0 or absi(x - 6) <= 1)
				)
			return inside and (x + y + variant) % 2 == 0
		6:
			var outer_ring := (
				((x == 1 or x == 11) and y >= 1 and y <= 8)
				or ((y == 1 or y == 8) and x >= 1 and x <= 11)
			)
			var inner_radius := 1 + variant % 2
			var inner_ring := (
				(absi(x - 6) == inner_radius and absi(y - 4) <= inner_radius)
				or (absi(y - 4) == inner_radius and absi(x - 6) <= inner_radius)
			)
			var connector := (
				variant >= 2
				and (
					(x == 6 and y >= 2 and y <= 7)
					or (variant == 3 and y == 4 and x >= 2 and x <= 10)
				)
			)
			return outer_ring or inner_ring or connector
		7:
			var first_wave := 3 + roundi(
				sin((float(x) + variant) * 0.75) * 2.0
			)
			var second_wave := 6 + roundi(
				cos((float(x) - variant) * 0.65) * 2.0
			)
			return (
				y == first_wave
				or (variant >= 1 and y == second_wave)
				or (variant == 0 and y == second_wave and x % 2 == 0)
				or (variant == 3 and y == 9 and x % 2 == 0)
			)

	return false


static func _validate_stage(stage_number: int) -> void:
	assert(
		stage_number >= 1 and stage_number <= STAGE_COUNT,
		"Stage must be between 1 and %d." % STAGE_COUNT
	)
