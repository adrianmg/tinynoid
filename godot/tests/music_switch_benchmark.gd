extends Node


func _ready() -> void:
	_measure_switch("stage_01", func() -> void: MusicController.play_stage(1))
	_measure_switch("stage_17", func() -> void: MusicController.play_stage(17))
	_measure_switch("stage_33", func() -> void: MusicController.play_stage(33))
	_measure_switch("menu", func() -> void: MusicController.play_menu())
	await get_tree().process_frame
	MusicController.shutdown()
	get_tree().quit()


func _measure_switch(label: String, switch_action: Callable) -> void:
	var started := Time.get_ticks_usec()
	switch_action.call()
	print(
		"MUSIC_SWITCH_%s_USEC=%d" % [
			label.to_upper(),
			Time.get_ticks_usec() - started,
		]
	)

