extends Node

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame

	_measure(
		"FIRST_STAGE",
		func() -> void: main.call("_start_new_game", 17)
	)
	_measure(
		"ESCAPE_MENU",
		func() -> void: main.call("_show_main_menu")
	)
	_measure(
		"REVISIT_STAGE",
		func() -> void: main.call("_start_new_game", 17)
	)
	_measure(
		"NEXT_STAGE",
		func() -> void: main.call("_continue_campaign")
	)

	await get_tree().process_frame
	MusicController.shutdown()
	get_tree().quit()


func _measure(label: String, transition: Callable) -> void:
	var started := Time.get_ticks_usec()
	transition.call()
	print(
		"TRANSITION_%s_USEC=%d" % [
			label,
			Time.get_ticks_usec() - started,
		]
	)

