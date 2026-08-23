class_name BrickRules
extends RefCounted

const BASE_RULES := {
	"W": {
		"name": "WHITE",
		"color": Color("#f7f4ff"),
		"shadow": Color("#8994b8"),
		"score": 50,
	},
	"O": {
		"name": "ORANGE",
		"color": Color("#ff715b"),
		"shadow": Color("#9e3d28"),
		"score": 60,
	},
	"C": {
		"name": "LIGHT BLUE",
		"color": Color("#45c7f2"),
		"shadow": Color("#23639b"),
		"score": 70,
	},
	"G": {
		"name": "GREEN",
		"color": Color("#7ed321"),
		"shadow": Color("#397818"),
		"score": 80,
	},
	"R": {
		"name": "RED",
		"color": Color("#e83d10"),
		"shadow": Color("#7d250f"),
		"score": 90,
	},
	"B": {
		"name": "BLUE",
		"color": Color("#1465d8"),
		"shadow": Color("#263d8f"),
		"score": 100,
	},
	"P": {
		"name": "PINK",
		"color": Color("#f06ab5"),
		"shadow": Color("#8f356d"),
		"score": 110,
	},
	"Y": {
		"name": "YELLOW",
		"color": Color("#ffa43d"),
		"shadow": Color("#9e5a24"),
		"score": 120,
	},
	"S": {
		"name": "SILVER",
		"color": Color("#b8c0c8"),
		"shadow": Color("#626b78"),
		"score": 0,
	},
	"X": {
		"name": "GOLD",
		"color": Color("#e6b422"),
		"shadow": Color("#8a6416"),
		"score": 0,
	},
}
const REGULAR_CODES := ["W", "O", "C", "G", "R", "B", "P", "Y"]


static func get_definition(code: String, stage_number: int) -> Dictionary:
	assert(BASE_RULES.has(code), "Unknown brick code: %s" % code)
	assert(stage_number >= 1)

	var definition: Dictionary = BASE_RULES[code].duplicate()
	definition["code"] = code
	definition["hit_points"] = 1
	definition["indestructible"] = false

	if code == "S":
		definition["hit_points"] = mini(
			2 + floori(float(stage_number - 1) / 8.0),
			5
		)
		definition["score"] = 50 * stage_number
	elif code == "X":
		definition["hit_points"] = 0
		definition["indestructible"] = true

	return definition


static func get_regular_code(index: int) -> String:
	return REGULAR_CODES[posmod(index, REGULAR_CODES.size())]

