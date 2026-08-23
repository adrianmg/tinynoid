extends SceneTree

const EMPTY_CELL := "-"


func _initialize() -> void:
	var arguments := OS.get_cmdline_user_args()
	if arguments.is_empty():
		push_error("Usage: -- <output-path>")
		quit(1)
		return

	var output_path: String = arguments[0]
	var output := FileAccess.open(output_path, FileAccess.WRITE)
	if output == null:
		push_error(
			"Cannot write level catalog to %s: %s" % [
				output_path,
				error_string(FileAccess.get_open_error()),
			]
		)
		quit(1)
		return

	_write_header(output)
	for stage_number in range(1, LevelCatalog.STAGE_COUNT + 1):
		_write_stage(output, stage_number)

	output.close()
	print("Wrote %d stages to %s" % [LevelCatalog.STAGE_COUNT, output_path])
	quit()


func _write_header(output: FileAccess) -> void:
	output.store_line("# TINYNOID stage layouts")
	output.store_line("")
	output.store_line(
		"These grids are generated directly from `LevelCatalog`. "
		+ "Each character becomes one brick; `-` marks an empty cell."
	)
	output.store_line("")
	output.store_line("## Legend")
	output.store_line("")
	output.store_line("| Symbol | Brick | Points | Hits |")
	output.store_line("| --- | --- | ---: | ---: |")
	output.store_line("| `W` | White | 50 | 1 |")
	output.store_line("| `O` | Orange | 60 | 1 |")
	output.store_line("| `C` | Light Blue | 70 | 1 |")
	output.store_line("| `G` | Green | 80 | 1 |")
	output.store_line("| `R` | Red | 90 | 1 |")
	output.store_line("| `B` | Blue | 100 | 1 |")
	output.store_line("| `P` | Pink | 110 | 1 |")
	output.store_line("| `Y` | Yellow | 120 | 1 |")
	output.store_line("| `S` | Silver | 50 x stage | 2-5 |")
	output.store_line("| `X` | Gold | 0 | Indestructible |")
	output.store_line("| `-` | Empty | - | - |")
	output.store_line("")


func _write_stage(output: FileAccess, stage_number: int) -> void:
	var layout := LevelCatalog.get_layout(stage_number)
	var brick_count := 0
	var silver_count := 0
	var gold_count := 0

	for row in layout:
		for character in row:
			if character == " ":
				continue
			brick_count += 1
			silver_count += 1 if character == "S" else 0
			gold_count += 1 if character == "X" else 0

	output.store_line(
		"## Stage %02d - %s" % [
			stage_number,
			LevelCatalog.get_stage_name(stage_number),
		]
	)
	output.store_line("")
	output.store_line(
		"**Bricks:** %d | **Silver:** %d | **Gold:** %d" % [
			brick_count,
			silver_count,
			gold_count,
		]
	)
	output.store_line("")
	output.store_line("```text")
	for row in layout:
		output.store_line(row.replace(" ", EMPTY_CELL))
	output.store_line("```")
	output.store_line("")
