extends Node

const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/level_01.tscn")
const BRICK_SCENE: PackedScene = preload("res://scenes/entities/brick.tscn")
const PADDLE_SCENE: PackedScene = preload("res://scenes/entities/paddle.tscn")
const BALL_SCENE: PackedScene = preload("res://scenes/entities/ball.tscn")
const POWER_UP_SCENE: PackedScene = preload("res://scenes/entities/power_up.tscn")
const LASER_SCENE: PackedScene = preload("res://scenes/entities/laser_shot.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const MAIN_MENU_SCENE: PackedScene = preload("res://scenes/main_menu.tscn")
const GAMEPLAY_SCENE: PackedScene = preload("res://scenes/gameplay.tscn")
const GAME_OVER_SCENE: PackedScene = preload("res://scenes/game_over.tscn")
const STAGE_CLEAR_SCENE: PackedScene = preload("res://scenes/stage_clear.tscn")
const BRICK_BREAK_EFFECT_SCENE: PackedScene = preload(
	"res://scenes/effects/brick_break_effect.tscn"
)

var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await _test_pixel_perfect_settings()
	await _test_generated_music()
	await _test_streaming_music_preview()
	await _test_generated_ui_audio()
	await _test_audio_levels()
	await _test_display_modes()
	await _test_main_menu()
	await _test_campaign_routing()
	await _test_game_session()
	await _test_level_catalog()
	await _test_brick_rules()
	await _test_gold_stage_clear()
	await _test_level_content()
	await _test_brick_scores_once()
	await _test_paddle_bounce_angles()
	await _test_ball_launch()
	await _test_brick_break_effect()
	await _test_brick_audio_pitch()
	await _test_power_up_chip()
	await _test_result_screens()
	await _test_gameplay_scene()
	await _test_manual_restart_resets_session()
	await _test_physics_signal_wiring()
	await _test_paddle_wall_edge_escape()
	await _test_multi_pickup_physics_flush()
	await _test_power_up_effects()
	await _test_life_loss_preserves_round()
	await _test_deferred_pickup_transition_guard()
	await _test_final_life_game_over()
	await _test_wall_collision()
	await _test_brick_collision_flow()

	if _failures == 0:
		print("All Godot port tests passed.")
	else:
		push_error("%d Godot port test(s) failed." % _failures)

	MusicController.shutdown()
	await get_tree().process_frame
	get_tree().quit(_failures)


func _test_generated_music() -> void:
	_check(Pcm8.decode(Pcm8.encode(0.0, 92.0)) == 0, "Signed PCM encodes silence at zero.")
	_check(Pcm8.decode(Pcm8.encode(1.0, 92.0)) == 92, "Signed PCM preserves positive samples.")
	_check(Pcm8.decode(Pcm8.encode(-1.0, 92.0)) == -92, "Signed PCM preserves negative samples.")

	var stream := MusicController.get_stream()
	var menu_stream_id := stream.get_instance_id()
	_check(
		MusicController.get_current_track_id() == 0,
		"The menu starts with its own generated arrangement."
	)
	_check(stream is AudioStreamWAV, "Background music is generated as PCM audio.")
	_check(
		stream.format == AudioStreamWAV.FORMAT_8_BITS,
		"Background music uses an 8-bit chiptune signal."
	)
	_check(stream.mix_rate == 22050, "Background music uses a compact 22.05 kHz mix.")
	_check(
		stream.loop_mode == AudioStreamWAV.LOOP_FORWARD,
		"Background music is configured as a forward loop."
	)
	_check(
		is_equal_approx(
			MusicController.get_loop_duration(),
			60.0 / 88.0 / 4.0 * 128.0
		),
		"The dreamy menu overture runs at 88 BPM."
	)
	_check(
		MusicController.get_voice_count() == 4,
		"The arrangement has melody, arpeggio, bass, and drum voices."
	)
	_check(
		stream.data.size() == roundi(
			stream.mix_rate * MusicController.get_loop_duration()
		),
		"The generated PCM data covers exactly one loop."
	)
	_check(
		MusicController.get_peak_amplitude() > 0.20
		and MusicController.get_peak_amplitude() < 1.0,
		"The generated mix is audible without digital clipping."
	)
	_check(
		not MusicController.is_playing(),
		"Headless validation does not allocate an audio playback device."
	)
	_check(
		absf(_signed_pcm_mean(stream.data)) < 4.0,
		"Signed music PCM remains centered around zero."
	)

	var arrangement_signatures := {}
	for track_id in range(LevelCatalog.STAGE_COUNT + 1):
		arrangement_signatures[
			MusicController.get_arrangement_signature(track_id)
		] = true
	_check(
		arrangement_signatures.size() == LevelCatalog.STAGE_COUNT + 1,
		"The menu and all 33 stages have distinct arrangement definitions."
	)

	MusicController.play_stage(1)
	var stage_one_stream := MusicController.get_stream()
	var stage_one_hash := hash(stage_one_stream.data)
	var stage_one_id := stage_one_stream.get_instance_id()
	_check(MusicController.get_current_track_id() == 1, "Stage 1 selects song 1.")

	MusicController.play_stage(2)
	var stage_two_stream := MusicController.get_stream()
	_check(MusicController.get_current_track_id() == 2, "Stage 2 selects song 2.")
	_check(
		hash(stage_two_stream.data) != stage_one_hash,
		"Different stages generate different PCM songs."
	)
	_check(
		stage_two_stream.data.size() != stage_one_stream.data.size(),
		"Stage tempo variation changes the generated loop duration."
	)

	var stage_two_id := stage_two_stream.get_instance_id()
	MusicController.play_stage(2)
	_check(
		MusicController.get_stream().get_instance_id() == stage_two_id,
		"Reloading the same stage does not regenerate or restart its song."
	)
	_check(
		MusicController.get_last_switch_duration_usec() < 10_000,
		"Same-stage song reuse completes in under 10 ms."
	)
	_check(
		stage_one_id != stage_two_id,
		"Changing stages replaces the generated stream."
	)

	MusicController.play_menu()
	_check(MusicController.get_current_track_id() == 0, "Returning to menu restores menu music.")
	_check(
		MusicController.get_stream().get_instance_id() == menu_stream_id,
		"Returning to menu reuses the cached menu song."
	)
	_check(
		MusicController.get_last_switch_duration_usec() < 10_000,
		"Cached menu music switching completes in under 10 ms."
	)
	_check(
		MusicController.get_cached_track_count() == 3,
		"Generated menu and stage songs remain cached for reuse."
	)


func _test_streaming_music_preview() -> void:
	var sample_count := MusicController.get_runtime_sample_count(0)
	var preview := MusicController.render_streaming_preview(0, 1024)
	_check(preview.size() == 1024, "Streaming preview produces the requested frame count.")

	var peak := 0.0
	for sample in preview:
		peak = maxf(peak, absf(sample))
	_check(peak > 0.05 and peak <= 1.0, "Streaming preview frames are audible and bounded.")

	var wrapped := MusicController.render_streaming_preview(
		0,
		4,
		sample_count - 2
	)
	var loop_start := MusicController.render_streaming_preview(0, 2, 0)
	_check(
		is_equal_approx(wrapped[2], loop_start[0])
		and is_equal_approx(wrapped[3], loop_start[1]),
		"Streaming cursor wraps exactly to the loop start."
	)
	_check(
		absf(wrapped[1] - wrapped[2]) < 1.5,
		"Streaming loop crossfade keeps the boundary bounded."
	)


func _test_generated_ui_audio() -> void:
	var move_stream := UiAudio.get_move_stream()
	var confirm_stream := UiAudio.get_confirm_stream()
	_check(move_stream is AudioStreamWAV, "Menu movement audio is generated PCM.")
	_check(confirm_stream is AudioStreamWAV, "Menu confirmation audio is generated PCM.")
	_check(
		move_stream.format == AudioStreamWAV.FORMAT_8_BITS
		and confirm_stream.format == AudioStreamWAV.FORMAT_8_BITS,
		"Menu sound effects use 8-bit chiptune signals."
	)
	_check(
		move_stream.data.size() == roundi(11025 * 0.045),
		"The movement tick is a compact 45 ms sound."
	)
	_check(
		confirm_stream.data.size() == roundi(11025 * 0.13),
		"The confirmation chirp is a distinct 130 ms sound."
	)

	var move_count := UiAudio.get_move_count()
	var confirm_count := UiAudio.get_confirm_count()
	UiAudio.play_move()
	UiAudio.play_confirm()
	_check(UiAudio.get_move_count() == move_count + 1, "Movement audio can be triggered.")
	_check(
		UiAudio.get_confirm_count() == confirm_count + 1,
		"Confirmation audio can be triggered."
	)


func _test_audio_levels() -> void:
	var master_bus := AudioServer.get_bus_index(&"Master")

	AudioSettings.set_level(3)
	_check(AudioSettings.get_level_label() == "III", "Sound level III is available.")
	_check(not AudioServer.is_bus_mute(master_bus), "Sound level III is unmuted.")
	_check(
		is_equal_approx(AudioServer.get_bus_volume_db(master_bus), 0.0),
		"Sound level III uses full master volume."
	)

	AudioSettings.set_level(2)
	_check(AudioSettings.get_level_label() == "II", "Sound level II is available.")
	_check(
		is_equal_approx(AudioServer.get_bus_volume_db(master_bus), -6.0),
		"Sound level II uses -6 dB."
	)

	AudioSettings.set_level(1)
	_check(AudioSettings.get_level_label() == "I", "Sound level I is available.")
	_check(
		is_equal_approx(AudioServer.get_bus_volume_db(master_bus), -12.0),
		"Sound level I uses -12 dB."
	)

	AudioSettings.set_level(0)
	_check(AudioSettings.get_level_label() == "OFF", "Sound level OFF is available.")
	_check(AudioServer.is_bus_mute(master_bus), "Sound OFF mutes the master bus.")

	AudioSettings.cycle_level(-1)
	_check(AudioSettings.level == 3, "Cycling down from OFF wraps to III.")


func _test_pixel_perfect_settings() -> void:
	_check(
		ProjectSettings.get_setting("display/window/size/viewport_width") == 256,
		"The logical viewport is 256 pixels wide."
	)
	_check(
		ProjectSettings.get_setting("application/config/name") == "Pikonoid",
		"The Godot project is named Pikonoid."
	)
	_check(
		ProjectSettings.get_setting("display/window/size/viewport_height") == 240,
		"The logical viewport is 240 pixels high."
	)
	_check(
		ProjectSettings.get_setting("display/window/stretch/mode") == "viewport",
		"Viewport stretching preserves the logical render target."
	)
	_check(
		ProjectSettings.get_setting("display/window/stretch/scale_mode") == "integer",
		"Window scaling uses whole-number multiples."
	)
	_check(
		ProjectSettings.get_setting(
			"rendering/textures/canvas_textures/default_texture_filter"
		) == 0,
		"Canvas texture filtering is nearest-neighbor."
	)
	_check(
		ProjectSettings.get_setting(
			"rendering/2d/snap/snap_2d_transforms_to_pixel"
		),
		"Moving CanvasItems render on the logical pixel grid."
	)
	_check(
		not ProjectSettings.get_setting(
			"rendering/2d/snap/snap_2d_vertices_to_pixel",
			false
		),
		"Vertex snapping stays disabled to avoid double-snap jitter."
	)


func _test_display_modes() -> void:
	var shortcut_event := InputEventKey.new()
	shortcut_event.pressed = true

	shortcut_event.keycode = KEY_F2
	DisplayController._input(shortcut_event)
	_check(DisplayController.get_mode_label() == "2X", "F2 selects 2x mode.")

	shortcut_event.keycode = KEY_F3
	DisplayController._input(shortcut_event)
	_check(DisplayController.get_mode_label() == "3X", "F3 selects 3x mode.")

	shortcut_event.keycode = KEY_F11
	DisplayController._input(shortcut_event)
	_check(DisplayController.get_mode_label() == "FULL", "F11 selects fullscreen.")

	DisplayController.toggle_fullscreen()
	_check(DisplayController.get_mode_label() == "3X", "Fullscreen restores the prior window scale.")


func _test_main_menu() -> void:
	AudioSettings.set_level(3)

	var menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	var start_requested := [-1]
	var quit_requested := [false]
	menu.start_requested.connect(
		func(stage_number: int) -> void:
			start_requested[0] = stage_number
	)
	menu.quit_requested.connect(func() -> void: quit_requested[0] = true)
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	_check(
		MainMenu.SUBTITLE == "A tiny tribute from me to the original game",
		"The menu carries the requested tribute subtitle."
	)
	_check(
		MainMenu.INSTRUCTION_LINES == [
			"Arrow keys to move & select",
			"Enter / Spacebar to select",
			"ESC to quit",
		],
		"The menu carries only the requested keyboard instructions."
	)
	_check(PixelFont.GLYPHS.has("."), "The bitmap font supports the domain period.")
	_check(PixelFont.GLYPHS.has("/"), "The bitmap font supports the instruction slash.")
	_check(PixelFont.GLYPHS.has("&"), "The bitmap font supports the instruction ampersand.")

	var fire_event := InputEventAction.new()
	fire_event.action = "launch"
	fire_event.pressed = true
	var accept_event := InputEventAction.new()
	accept_event.action = "ui_accept"
	accept_event.pressed = true

	var right_event := InputEventAction.new()
	right_event.action = "ui_right"
	right_event.pressed = true
	var left_event := InputEventAction.new()
	left_event.action = "ui_left"
	left_event.pressed = true

	menu._unhandled_input(left_event)
	_check(
		menu.get_selected_stage() == LevelCatalog.STAGE_COUNT,
		"Left from stage 1 wraps to stage 33."
	)
	menu._unhandled_input(right_event)
	_check(menu.get_selected_stage() == 1, "Right from stage 33 wraps to stage 1.")
	menu._unhandled_input(right_event)
	_check(menu.get_selected_stage() == 2, "Right selects the next starting stage.")
	var confirm_count := UiAudio.get_confirm_count()

	menu._unhandled_input(accept_event)
	_check(start_requested[0] == 2, "Enter starts the selected stage from the menu.")
	_check(
		UiAudio.get_confirm_count() == confirm_count + 1,
		"Enter plays the confirmation chirp."
	)

	var down_event := InputEventAction.new()
	down_event.action = "ui_down"
	down_event.pressed = true
	var move_count := UiAudio.get_move_count()
	menu._unhandled_input(down_event)
	_check(menu.get_selected_index() == 1, "Menu navigation selects Window mode.")
	_check(
		UiAudio.get_move_count() == move_count + 1,
		"Up/Down navigation plays the movement tick."
	)

	DisplayController.set_window_scale(2)
	menu._unhandled_input(right_event)
	_check(DisplayController.get_mode_label() == "3X", "Menu arrows change window mode.")
	_check(
		UiAudio.get_move_count() == move_count + 2,
		"Left/Right interaction plays the movement tick."
	)

	menu._unhandled_input(down_event)
	_check(menu.get_selected_index() == 2, "Menu navigation selects Sound.")
	menu._unhandled_input(fire_event)
	_check(menu.get_sound_level() == 2, "FIRE lowers Sound from III to II.")
	menu._unhandled_input(fire_event)
	_check(menu.get_sound_level() == 1, "FIRE lowers Sound from II to I.")
	menu._unhandled_input(fire_event)
	_check(menu.get_sound_level() == 0, "FIRE lowers Sound from I to OFF.")
	_check(not menu.is_sound_enabled(), "Sound OFF disables the master bus.")
	menu._unhandled_input(fire_event)
	_check(menu.get_sound_level() == 3, "FIRE wraps Sound from OFF to III.")
	_check(menu.is_sound_enabled(), "Sound III enables the master bus.")

	var menu_cancel_event := InputEventAction.new()
	menu_cancel_event.action = "ui_cancel"
	menu_cancel_event.pressed = true
	menu._unhandled_input(menu_cancel_event)
	_check(quit_requested[0], "Escape requests quit from the main menu.")

	menu.queue_free()
	await get_tree().process_frame

	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	_check(
		main.find_child("MainMenu", true, false) != null,
		"The application starts at the main menu."
	)
	_check(MusicController.get_current_track_id() == 0, "Main menu routing selects menu music.")

	var application_menu := main.find_child(
		"MainMenu",
		true,
		false
	) as MainMenu
	application_menu._unhandled_input(right_event)
	application_menu._unhandled_input(fire_event)
	await get_tree().process_frame
	_check(
		main.find_child("Gameplay", true, false) != null,
		"Play transitions from the menu into gameplay."
	)
	_check(GameSession.level == 2, "The application starts the stage selected in the menu.")
	_check(MusicController.get_current_track_id() == 2, "Selected stage routing selects its song.")

	var cancel_event := InputEventAction.new()
	cancel_event.action = "ui_cancel"
	cancel_event.pressed = true
	main.call(&"_unhandled_input", cancel_event)
	await get_tree().process_frame
	_check(
		main.find_child("MainMenu", true, false) != null,
		"Escape returns gameplay to the main menu."
	)
	_check(MusicController.get_current_track_id() == 0, "Escape restores menu music.")

	main.queue_free()
	await get_tree().process_frame


func _test_campaign_routing() -> void:
	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame

	main.call(&"_start_new_game", 32)
	await get_tree().process_frame
	_check(GameSession.level == 32, "Campaign routing starts a selected late stage.")
	_check(MusicController.get_current_track_id() == 32, "Stage 32 uses song 32.")
	var stage_32_stream_id := MusicController.get_stream().get_instance_id()
	main.call(&"_show_gameplay")
	await get_tree().process_frame
	_check(
		MusicController.get_stream().get_instance_id() == stage_32_stream_id,
		"Reloading stage 32 keeps its current song stream."
	)

	main.call(&"_continue_campaign")
	await get_tree().process_frame
	_check(GameSession.level == 33, "Clearing stage 32 advances to stage 33.")
	_check(MusicController.get_current_track_id() == 33, "Stage 33 switches to song 33.")
	_check(
		main.find_child("Gameplay", true, false) != null,
		"Advancing the campaign loads the next gameplay stage."
	)

	main.call(&"_show_stage_clear")
	await get_tree().process_frame
	main.call(&"_continue_campaign")
	await get_tree().process_frame
	_check(
		main.find_child("MainMenu", true, false) != null,
		"Completing stage 33 returns to the main menu."
	)
	_check(MusicController.get_current_track_id() == 0, "Campaign completion restores menu music.")

	main.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_game_session() -> void:
	var session := GameSessionState.new()
	get_tree().root.add_child(session)
	session.new_game()

	_check(session.score == 0, "A new game starts with zero score.")
	_check(session.balls_remaining == 3, "A new game starts with three balls.")
	session.add_ball()
	_check(session.balls_remaining == 4, "Extra Ball adds one ball.")
	session.new_game(17)
	_check(session.level == 17, "A new game can start from a selected stage.")
	session.advance_level()
	_check(session.level == 18, "Campaign progression advances one stage.")
	session.new_game()

	session.award(50)
	_check(session.score == 50, "Score awards are accumulated.")
	_check(session.high_score == 50, "The session remembers the high score.")
	_check(
		session.register_ball_lost() == GameSessionState.BallLossOutcome.RESTART_LEVEL,
		"The first lost ball restarts the level."
	)
	_check(
		session.register_ball_lost() == GameSessionState.BallLossOutcome.RESTART_LEVEL,
		"The second lost ball restarts the level."
	)
	_check(
		session.register_ball_lost() == GameSessionState.BallLossOutcome.GAME_OVER,
		"The third lost ball ends the game."
	)

	session.queue_free()
	await get_tree().process_frame


func _test_level_catalog() -> void:
	var signatures := {}
	var geometry_signatures := {}
	var found_silver := false
	var found_gold := false

	for stage_number in range(1, LevelCatalog.STAGE_COUNT + 1):
		var layout := LevelCatalog.get_layout(stage_number)
		var signature := "\n".join(layout)
		signatures[signature] = true
		var geometry_rows: Array[String] = []
		for geometry_row in layout:
			var normalized_row := ""
			for column_index in range(geometry_row.length()):
				normalized_row += (
					" "
					if geometry_row.substr(column_index, 1) == " "
					else "#"
				)
			geometry_rows.append(normalized_row)
		geometry_signatures["\n".join(geometry_rows)] = true
		var brick_count := 0

		for row in layout:
			_check(
				row.length() == LevelCatalog.GRID_COLUMNS,
				"Stage %02d stays inside the 13-column grid." % stage_number
			)
			for character in row:
				if character == " ":
					continue
				brick_count += 1
				found_silver = found_silver or character == "S"
				found_gold = found_gold or character == "X"

		_check(
			brick_count >= 16,
			"Stage %02d has a playable brick count." % stage_number
		)
		_check(
			not LevelCatalog.get_stage_name(stage_number).is_empty(),
			"Stage %02d has an original name." % stage_number
		)

	_check(
		signatures.size() == LevelCatalog.STAGE_COUNT,
		"All 33 campaign layouts are unique."
	)
	_check(
		geometry_signatures.size() == LevelCatalog.STAGE_COUNT,
		"All 33 campaign geometries are unique before color assignment."
	)
	_check(found_silver, "The campaign includes Silver bricks.")
	_check(found_gold, "The campaign includes Gold bricks.")


func _test_brick_rules() -> void:
	var expected_scores := {
		"W": 50,
		"O": 60,
		"C": 70,
		"G": 80,
		"R": 90,
		"B": 100,
		"P": 110,
		"Y": 120,
	}
	for code in expected_scores:
		var definition := BrickRules.get_definition(code, 1)
		_check(
			definition.score == expected_scores[code],
			"%s bricks award %d points." % [
				definition.name,
				expected_scores[code],
			]
		)
		_check(definition.hit_points == 1, "Standard color bricks break in one hit.")

	var silver_1 := BrickRules.get_definition("S", 1)
	var silver_9 := BrickRules.get_definition("S", 9)
	var silver_17 := BrickRules.get_definition("S", 17)
	var silver_25 := BrickRules.get_definition("S", 25)
	_check(
		silver_1.hit_points == 2 and silver_1.score == 50,
		"Stage 1 Silver takes two hits and awards 50 points."
	)
	_check(
		silver_9.hit_points == 3 and silver_9.score == 450,
		"Stage 9 Silver takes three hits and awards 450 points."
	)
	_check(
		silver_17.hit_points == 4 and silver_17.score == 850,
		"Stage 17 Silver takes four hits and awards 850 points."
	)
	_check(
		silver_25.hit_points == 5 and silver_25.score == 1250,
		"Stage 25 Silver takes five hits and awards 1250 points."
	)

	var gold := BrickRules.get_definition("X", 33)
	_check(gold.indestructible, "Gold bricks are indestructible.")
	_check(gold.score == 0, "Gold bricks award no destruction score.")

	var silver_brick: Brick = BRICK_SCENE.instantiate()
	silver_brick.hit_points = silver_9.hit_points
	silver_brick.score = silver_9.score
	var silver_score := [0]
	silver_brick.broken.connect(
		func(
			points: int,
			_world_position: Vector2,
			_effect_color: Color,
			_power_up_type: int
		) -> void:
			silver_score[0] += points
	)
	get_tree().root.add_child(silver_brick)
	silver_brick.hit()
	_check(silver_brick.is_flashing(), "A surviving Silver hit starts a white flash.")
	await get_tree().create_timer(0.09).timeout
	_check(not silver_brick.is_flashing(), "The Silver impact flash ends after 80 ms.")
	silver_brick.hit()
	_check(silver_score[0] == 0, "Silver survives until its final required hit.")
	silver_brick.hit()
	_check(silver_score[0] == 450, "Silver awards its stage-scaled score on break.")
	await get_tree().process_frame

	var gold_brick: Brick = BRICK_SCENE.instantiate()
	gold_brick.indestructible = true
	var gold_broken := [false]
	var gold_hit_kind := [-1]
	gold_brick.broken.connect(
		func(
			_points: int,
			_world_position: Vector2,
			_effect_color: Color,
			_power_up_type: int
		) -> void:
			gold_broken[0] = true
	)
	gold_brick.struck.connect(
		func(
			_world_position: Vector2,
			_effect_color: Color,
			hit_kind: int
		) -> void:
			gold_hit_kind[0] = hit_kind
	)
	get_tree().root.add_child(gold_brick)
	for hit_index in range(8):
		gold_brick.hit()
	_check(not gold_broken[0], "Repeated hits never destroy Gold.")
	_check(
		gold_hit_kind[0] == Brick.HitKind.INDESTRUCTIBLE,
		"Gold contacts identify the indestructible hit kind."
	)
	gold_brick.queue_free()
	await get_tree().process_frame


func _test_gold_stage_clear() -> void:
	var gold_stage := -1
	for stage_number in range(1, LevelCatalog.STAGE_COUNT + 1):
		if "X" in "\n".join(LevelCatalog.get_layout(stage_number)):
			gold_stage = stage_number
			break

	_check(gold_stage > 0, "At least one campaign stage contains Gold.")
	GameSession.new_game(gold_stage)
	var level: Level01 = LEVEL_SCENE.instantiate()
	var level_cleared := [false]
	level.level_cleared.connect(func() -> void: level_cleared[0] = true)
	get_tree().root.add_child(level)
	await get_tree().process_frame

	var gold_count := 0
	for child in level.bricks.get_children():
		var brick := child as Brick
		if brick.indestructible:
			gold_count += 1
			continue
		for required_hit in range(brick.hit_points):
			brick.hit()

	await get_tree().process_frame
	_check(gold_count > 0, "The selected special stage spawned Gold bricks.")
	_check(level_cleared[0], "Gold bricks do not block stage clear.")
	_check(
		level.get_brick_count() == gold_count,
		"Indestructible Gold remains after all destructible bricks clear."
	)

	level.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_level_content() -> void:
	GameSession.new_game(1)
	var level: Level01 = LEVEL_SCENE.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame

	_check(level.background is RetroArena, "Level 1 uses the procedural retro arena.")
	_check(level.get_brick_count() == 64, "Level 1 has a 64-brick rainbow gate.")

	var total_score := 0
	var power_up_types := {}
	for child in level.bricks.get_children():
		var brick := child as Brick
		total_score += brick.score
		if brick.power_up_type >= 0:
			power_up_types[brick.power_up_type] = true

	_check(total_score == 5650, "The rainbow gate has the expected score value.")
	_check(_brick_score_at(level, Vector2(64, 52)) == 90, "The red crown is present.")
	_check(_brick_score_at(level, Vector2(48, 62)) == 60, "The orange row is present.")
	_check(_brick_score_at(level, Vector2(32, 72)) == 120, "The yellow split row is present.")
	_check(_brick_score_at(level, Vector2(48, 82)) == 80, "The green row is present.")
	_check(_brick_score_at(level, Vector2(64, 92)) == 70, "The light-blue row is present.")
	_check(_brick_score_at(level, Vector2(48, 102)) == 100, "The blue clusters are present.")
	_check(_brick_score_at(level, Vector2(80, 112)) == 110, "The magenta foundation is present.")
	_check(
		power_up_types.size() == PowerUp.POWER_TYPE_COUNT,
		"Each stage contains all seven power-up drops."
	)
	for power_type in range(PowerUp.POWER_TYPE_COUNT):
		_check(
			power_up_types.has(power_type),
			"Stage 1 includes power-up type %d." % power_type
		)

	var level_cleared := [false]
	level.level_cleared.connect(func() -> void: level_cleared[0] = true)
	for child in level.bricks.get_children():
		(child as Brick).hit()
	await get_tree().process_frame
	_check(level_cleared[0], "Clearing every brick completes the stage.")

	level.queue_free()
	await get_tree().process_frame


func _test_brick_scores_once() -> void:
	var brick: Brick = BRICK_SCENE.instantiate()
	brick.score = 70
	get_tree().root.add_child(brick)

	var awards := [0]
	brick.broken.connect(
		func(
			points: int,
			_world_position: Vector2,
			_effect_color: Color,
			_power_up_type: int
		) -> void:
			awards[0] += points
	)
	brick.hit()
	brick.hit()

	_check(awards[0] == 70, "A brick awards its score exactly once.")
	await get_tree().process_frame


func _test_ball_launch() -> void:
	var world := Node2D.new()
	var paddle: PaddleController = PADDLE_SCENE.instantiate()
	var ball: BreakerBall = BALL_SCENE.instantiate()
	paddle.position = Vector2(128, 220)
	ball.position = Vector2(128, 212)
	world.add_child(paddle)
	world.add_child(ball)
	get_tree().root.add_child(world)

	ball.attach_to(paddle)
	var trail := ball.get_node("Trail") as BallTrail
	await get_tree().process_frame
	_check(not trail.visible, "The docked ball has no visible afterimage halo.")
	_check(trail.get_sample_count() == 0, "The docked ball does not accumulate trail samples.")

	ball.launch()
	await get_tree().physics_frame
	await get_tree().process_frame

	_check(ball.is_active(), "The ball becomes active after launch.")
	_check(is_equal_approx(ball.velocity.length(), 200.0), "The ball launches at 200 pixels per second.")
	_check(ball.velocity.x > 0.0, "A stationary centered paddle launches toward the right.")
	_check(ball.velocity.y < 0.0, "The ball launches upward in Godot coordinates.")
	_check(is_equal_approx(trail.lifetime, 0.12), "The ball trail has a short retro persistence.")
	_check(trail.afterimage_size == 2, "The ball trail uses two-pixel stepped afterimages.")
	_check(trail.visible, "The afterimage trail appears after launch.")
	_check(trail.get_sample_count() > 0, "The launched ball accumulates trail samples.")

	ball.deactivate()
	_check(not trail.visible, "The afterimage trail hides when the ball deactivates.")
	_check(trail.get_sample_count() == 0, "Deactivation clears all trail samples.")
	world.queue_free()
	await get_tree().process_frame


func _test_paddle_bounce_angles() -> void:
	var paddle: PaddleController = PADDLE_SCENE.instantiate()
	paddle.position = Vector2(128, 220)
	get_tree().root.add_child(paddle)
	await get_tree().process_frame

	var center := paddle.get_bounce_direction(128, Vector2.DOWN)
	var inner_right := paddle.get_bounce_direction(132, Vector2.DOWN)
	var middle_right := paddle.get_bounce_direction(140, Vector2.DOWN)
	var edge_right := paddle.get_bounce_direction(148, Vector2.DOWN)
	var edge_left := paddle.get_bounce_direction(108, Vector2.DOWN)

	_check(is_zero_approx(center.x), "A stationary center hit travels straight upward.")
	_check(center.y < 0.0, "Every paddle bounce exits upward.")
	_check(
		inner_right.x < middle_right.x and middle_right.x < edge_right.x,
		"Impact position produces continuously increasing rightward angles."
	)
	_check(
		is_equal_approx(absf(edge_left.x), edge_right.x)
		and is_equal_approx(edge_left.y, edge_right.y),
		"Left and right edge angles are symmetrical."
	)

	var edge_angle := rad_to_deg(atan2(absf(edge_right.x), -edge_right.y))
	_check(
		is_equal_approx(edge_angle, 68.0),
		"Edge hits use the bounded 68-degree maximum angle."
	)
	_check(
		is_equal_approx(center.length(), 1.0)
		and is_equal_approx(inner_right.length(), 1.0)
		and is_equal_approx(middle_right.length(), 1.0)
		and is_equal_approx(edge_right.length(), 1.0),
		"Every paddle bounce direction is normalized."
	)

	paddle.horizontal_velocity = paddle.speed
	var moving_center := paddle.get_bounce_direction(128, Vector2.DOWN)
	_check(
		moving_center.x > 0.0 and moving_center.y < 0.0,
		"Rightward paddle motion adds bounded rightward English."
	)

	paddle.queue_free()
	await get_tree().process_frame


func _test_brick_break_effect() -> void:
	var effect: BrickBreakEffect = BRICK_BREAK_EFFECT_SCENE.instantiate()
	effect.configure(Color("#ffd84a"))
	get_tree().root.add_child(effect)
	await get_tree().process_frame

	_check(effect.effect_color == Color("#ffd84a"), "The effect inherits its brick color.")

	await get_tree().create_timer(0.4).timeout
	_check(not is_instance_valid(effect), "The brick effect cleans itself up.")


func _test_brick_audio_pitch() -> void:
	var brick_audio := BrickAudio.new()
	get_tree().root.add_child(brick_audio)
	await get_tree().process_frame

	brick_audio.play_hit()
	var first_pitch := brick_audio.get_last_pitch()
	brick_audio.play_hit()
	var second_pitch := brick_audio.get_last_pitch()

	_check(
		first_pitch >= 0.90 and first_pitch <= 1.12,
		"Brick pitch variation stays inside the intended range."
	)
	_check(
		second_pitch >= 0.90 and second_pitch <= 1.12,
		"Every randomized pitch stays inside the intended range."
	)
	_check(
		not is_equal_approx(first_pitch, second_pitch),
		"Consecutive brick contacts never repeat the same pitch."
	)
	brick_audio.play_hit(Brick.HitKind.DURABLE)
	var durable_pitch := brick_audio.get_last_pitch()
	_check(
		durable_pitch >= 1.18 and durable_pitch <= 1.40,
		"Durable bricks use the higher metallic pitch range."
	)
	_check(
		brick_audio.get_last_hit_kind() == Brick.HitKind.DURABLE,
		"Durable brick contact selects the durable sound."
	)
	_check(
		hash(brick_audio.get_regular_stream().data)
		!= hash(brick_audio.get_durable_stream().data),
		"Durable and regular bricks use different generated waveforms."
	)
	brick_audio.play_hit(Brick.HitKind.INDESTRUCTIBLE)
	var gold_pitch := brick_audio.get_last_pitch()
	_check(
		gold_pitch >= 0.68 and gold_pitch <= 0.80,
		"Gold contacts use the low stubborn pitch range."
	)
	_check(
		brick_audio.get_last_hit_kind() == Brick.HitKind.INDESTRUCTIBLE,
		"Gold contact selects the indestructible sound."
	)
	_check(
		hash(brick_audio.get_indestructible_stream().data)
		!= hash(brick_audio.get_regular_stream().data)
		and hash(brick_audio.get_indestructible_stream().data)
		!= hash(brick_audio.get_durable_stream().data),
		"Gold uses a waveform distinct from regular and Silver bricks."
	)

	await get_tree().create_timer(0.2).timeout
	brick_audio.queue_free()
	await get_tree().process_frame


func _test_power_up_chip() -> void:
	var world := Node2D.new()
	var paddle: PaddleController = PADDLE_SCENE.instantiate()
	var power_up: PowerUp = POWER_UP_SCENE.instantiate()
	var picked_type := [-1]
	power_up.configure(PowerUp.PowerType.WIDE)
	power_up.picked_up.connect(func(type: int) -> void: picked_type[0] = type)
	paddle.position = Vector2(128, 220)
	power_up.position = Vector2(128, 206)
	world.add_child(paddle)
	world.add_child(power_up)
	get_tree().root.add_child(world)
	await get_tree().process_frame

	var expected_symbols := {
		PowerUp.PowerType.WIDE: "E",
		PowerUp.PowerType.SLOW: "S",
		PowerUp.PowerType.MULTI: "D",
		PowerUp.PowerType.EXTRA_BALL: "P",
		PowerUp.PowerType.CATCH: "C",
		PowerUp.PowerType.LASER: "L",
		PowerUp.PowerType.BREAK: "B",
	}
	for power_type in expected_symbols:
		_check(
			PowerUp.get_type_symbol(power_type) == expected_symbols[power_type],
			"Capsule type %d uses the expected symbol." % power_type
		)
	for physics_step in range(20):
		await get_tree().physics_frame
	_check(
		picked_type[0] == PowerUp.PowerType.WIDE,
		"Falling chips are collected by the paddle."
	)

	world.queue_free()
	await get_tree().process_frame


func _test_result_screens() -> void:
	var fire_event := InputEventAction.new()
	fire_event.action = "launch"
	fire_event.pressed = true

	var game_over: GameOverScreen = GAME_OVER_SCENE.instantiate()
	var retry_requested := [false]
	game_over.new_game_requested.connect(func() -> void: retry_requested[0] = true)
	get_tree().root.add_child(game_over)
	game_over._unhandled_input(fire_event)
	_check(retry_requested[0], "FIRE retries from Game Over.")
	game_over.queue_free()
	await get_tree().process_frame

	var stage_clear: StageClearScreen = STAGE_CLEAR_SCENE.instantiate()
	var replay_requested := [false]
	stage_clear.replay_requested.connect(func() -> void: replay_requested[0] = true)
	get_tree().root.add_child(stage_clear)
	stage_clear._unhandled_input(fire_event)
	_check(replay_requested[0], "FIRE replays from Stage Clear.")
	stage_clear.queue_free()
	await get_tree().process_frame


func _test_gameplay_scene() -> void:
	GameSession.new_game()
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame

	_check(gameplay.level.get_brick_count() == 64, "The gameplay scene loads the rainbow gate.")
	_check(gameplay.ball.global_position == Vector2(128, 212), "The ball starts above the paddle.")
	_check(gameplay.paddle.global_position == Vector2(128, 220), "The paddle starts centered.")
	_check(gameplay.hud.is_launch_ready(), "The HUD initially shows the launch cue.")
	_check(
		RetroHud.LAUNCH_PROMPT == "Press spacebar to fire the ball",
		"The launch advice names the Spacebar action."
	)
	gameplay.ball.launch()
	_check(not gameplay.hud.is_launch_ready(), "The launch cue clears when the ball launches.")

	gameplay.queue_free()
	await get_tree().process_frame


func _test_manual_restart_resets_session() -> void:
	GameSession.new_game(12)
	GameSession.award(750)
	GameSession.register_ball_lost()
	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame

	main.call("_start_new_game", 12)
	GameSession.award(750)
	GameSession.register_ball_lost()
	main.call("_restart_current_stage")
	await get_tree().process_frame

	_check(GameSession.level == 12, "Manual restart preserves the selected stage.")
	_check(GameSession.score == 0, "Manual restart resets score.")
	_check(
		GameSession.balls_remaining == GameSessionState.STARTING_BALLS,
		"Manual restart resets the ball counter."
	)

	main.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_physics_signal_wiring() -> void:
	GameSession.new_game()
	var paddle_gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(paddle_gameplay)
	await get_tree().process_frame
	await get_tree().physics_frame

	paddle_gameplay.ball.global_position = Vector2(128, 208)
	paddle_gameplay.ball.launch_in_direction(Vector2.DOWN)
	for physics_step in range(8):
		await get_tree().physics_frame
	_check(
		paddle_gameplay.ball.velocity.y < 0.0,
		"A real physics collision bounces the ball upward from the paddle."
	)
	_check(
		GameSession.balls_remaining == 3,
		"Paddle collision does not consume a ball."
	)

	paddle_gameplay.ball.deactivate()
	paddle_gameplay.queue_free()
	await get_tree().process_frame

	GameSession.new_game()
	var death_gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(death_gameplay)
	await get_tree().process_frame
	await get_tree().physics_frame

	var level_id := death_gameplay.level.get_instance_id()
	death_gameplay.ball.global_position = Vector2(30, 232)
	death_gameplay.ball.launch_in_direction(Vector2.DOWN)
	for physics_step in range(10):
		await get_tree().physics_frame
	await get_tree().process_frame

	_check(
		GameSession.balls_remaining == 2,
		"A real Area2D death-zone signal consumes one ball."
	)
	_check(
		death_gameplay.level.get_instance_id() == level_id,
		"Physical death-zone entry preserves the live level instance."
	)
	_check(
		not death_gameplay.ball.is_active(),
		"Physical death-zone entry resets to a docked serve."
	)

	death_gameplay.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_paddle_wall_edge_escape() -> void:
	GameSession.new_game()
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame
	await get_tree().physics_frame

	gameplay.paddle.global_position.x = gameplay.paddle.right_boundary
	gameplay.ball.global_position = Vector2(236.5, 209.0)
	gameplay.ball.launch_in_direction(Vector2(0.35, 1.0))

	for physics_step in range(20):
		await get_tree().physics_frame

	_check(
		gameplay.ball.is_active(),
		"The right-edge paddle contact keeps the ball active."
	)
	_check(
		GameSession.balls_remaining == 3,
		"The right-edge paddle contact does not consume a ball."
	)
	_check(
		gameplay.ball.global_position.y < 200.0,
		"The right-edge paddle contact escapes upward instead of sticking."
	)
	_check(
		is_equal_approx(
			gameplay.ball.velocity.length(),
			BreakerBall.BASE_SPEED
		),
		"The edge escape preserves constant ball speed."
	)

	gameplay.ball.deactivate()
	gameplay.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_multi_pickup_physics_flush() -> void:
	GameSession.new_game()
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame
	await get_tree().physics_frame

	var multi_chip: PowerUp = POWER_UP_SCENE.instantiate()
	multi_chip.configure(PowerUp.PowerType.MULTI)
	multi_chip.picked_up.connect(gameplay._on_power_up_picked)
	multi_chip.position = Vector2(128, 206)
	gameplay.power_ups.add_child(multi_chip)

	for physics_step in range(20):
		await get_tree().physics_frame
	await get_tree().process_frame
	_check(
		gameplay.balls.get_child_count() == 3,
		"A real physics pickup safely creates Multi-ball after query flush."
	)

	for active_ball in gameplay._get_balls():
		active_ball.deactivate()
	gameplay.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_power_up_effects() -> void:
	GameSession.new_game()
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame

	var wide_brick := _find_power_up_brick(
		gameplay.level,
		PowerUp.PowerType.WIDE
	)
	_check(wide_brick != null, "The stage exposes a Wide drop brick.")
	wide_brick.hit()
	await get_tree().process_frame
	_check(gameplay.power_ups.get_child_count() == 1, "Marked bricks spawn power-up chips.")

	var wide_chip := gameplay.power_ups.get_child(0) as PowerUp
	_check(wide_chip.power_type == PowerUp.PowerType.WIDE, "The Wide brick drops Wide.")
	wide_chip.collect(gameplay.paddle)
	await get_tree().process_frame
	_check(gameplay.paddle.paddle_width == 56.0, "Wide enlarges the paddle.")
	_check(
		gameplay.get_active_power_up() == PowerUp.PowerType.WIDE,
		"Wide remains active after collection."
	)
	await get_tree().create_timer(0.1).timeout
	_check(
		gameplay.paddle.paddle_width == 56.0,
		"Wide has no timer and remains active during the current life."
	)

	gameplay.ball.launch()
	gameplay.apply_power_up(PowerUp.PowerType.SLOW)
	_check(gameplay.ball.speed == 150.0, "Slow reduces ball speed to 150 pixels per second.")
	_check(gameplay.paddle.paddle_width == 40.0, "Slow replaces the prior Wide effect.")
	_check(
		gameplay.get_active_power_up() == PowerUp.PowerType.SLOW,
		"Only Slow remains active after replacement."
	)

	gameplay.apply_power_up(PowerUp.PowerType.MULTI)
	_check(gameplay.balls.get_child_count() == 3, "Multi-ball creates three active balls.")
	for active_ball in gameplay.balls.get_children():
		_check(
			(active_ball as BreakerBall).speed == 200.0,
			"Multi-ball replaces Slow and restores base speed."
		)

	var score_before_extra := GameSession.score
	gameplay.apply_power_up(PowerUp.PowerType.EXTRA_BALL)
	_check(GameSession.balls_remaining == 4, "Extra Ball increments the session counter.")
	_check(
		GameSession.score == score_before_extra + Gameplay.POWER_UP_SCORE,
		"Every collected power-up awards 100 points."
	)
	_check(
		gameplay.get_active_power_up() == PowerUp.PowerType.MULTI,
		"Instant Extra Ball does not replace the active temporary effect."
	)

	var lost_ball := gameplay.balls.get_child(1) as BreakerBall
	gameplay._on_death_zone_body_entered(lost_ball)
	await get_tree().process_frame
	_check(gameplay.balls.get_child_count() == 2, "Losing one multi-ball keeps play active.")
	_check(GameSession.balls_remaining == 4, "A partial multi-ball loss costs no life.")
	_check(
		gameplay.get_active_power_up() == PowerUp.PowerType.MULTI,
		"Multi-ball remains active while another split ball survives."
	)

	var second_lost_ball := gameplay.balls.get_child(1) as BreakerBall
	gameplay._on_death_zone_body_entered(second_lost_ball)
	await get_tree().process_frame
	_check(gameplay.balls.get_child_count() == 1, "A second split-ball loss leaves one ball.")
	_check(
		gameplay.get_active_power_up() == -1,
		"Multi-ball ends naturally when only one ball remains."
	)

	gameplay.apply_power_up(PowerUp.PowerType.WIDE)
	await get_tree().process_frame
	_check(gameplay.balls.get_child_count() == 1, "Wide keeps the remaining single ball.")
	_check(gameplay.paddle.paddle_width == 56.0, "The replacement Wide effect activates.")

	gameplay.apply_power_up(PowerUp.PowerType.CATCH)
	_check(gameplay.paddle.catch_enabled, "Catch enables the paddle catch surface.")
	_check(gameplay.paddle.paddle_width == 40.0, "Catch replaces Expand.")

	gameplay.ball.reset_for_serve(gameplay.paddle)
	gameplay.ball.global_position = Vector2(128, 208)
	gameplay.ball.launch_in_direction(Vector2.DOWN)
	for physics_step in range(8):
		await get_tree().physics_frame
	_check(not gameplay.ball.is_active(), "Catch holds a returning ball.")
	_check(
		gameplay.ball.global_position == Vector2(128, 212),
		"Catch docks the held ball above the paddle."
	)
	gameplay.ball.launch()
	_check(gameplay.ball.is_active(), "FIRE releases a caught ball.")

	gameplay.apply_power_up(PowerUp.PowerType.LASER)
	_check(gameplay.paddle.laser_enabled, "Laser equips the paddle emitters.")
	_check(not gameplay.paddle.catch_enabled, "Laser replaces Catch.")
	gameplay._spawn_lasers()
	_check(gameplay.lasers.get_child_count() == 2, "Laser fires a paired shot.")

	var laser_target: Brick
	for child in gameplay.level.bricks.get_children():
		var candidate := child as Brick
		if (
			not candidate.indestructible
			and (
				laser_target == null
				or candidate.global_position.y > laser_target.global_position.y
			)
		):
			laser_target = candidate
	var brick_count_before_laser := gameplay.level.get_brick_count()
	var probe_laser: LaserShot = LASER_SCENE.instantiate()
	var laser_contact := [false]
	probe_laser.body_entered.connect(
		func(body: Node2D) -> void:
			if body == laser_target:
				laser_contact[0] = true
	)
	gameplay.lasers.add_child(probe_laser)
	probe_laser.global_position = (
		laser_target.global_position + Vector2(0, 14)
	)
	for physics_step in range(10):
		await get_tree().physics_frame
	await get_tree().process_frame
	_check(laser_contact[0], "Laser Area2D detects the target brick.")
	_check(
		gameplay.level.get_brick_count() == brick_count_before_laser - 1,
		"Laser shots damage and destroy destructible bricks."
	)

	var break_requested := [false]
	gameplay.stage_clear_requested.connect(
		func() -> void:
			break_requested[0] = true
	)
	gameplay.apply_power_up(PowerUp.PowerType.BREAK)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(break_requested[0], "Break immediately requests the next stage.")

	for active_ball in gameplay._get_balls():
		active_ball.deactivate()
	await get_tree().create_timer(0.4).timeout
	gameplay.queue_free()
	await get_tree().process_frame


func _test_life_loss_preserves_round() -> void:
	var persistence_stage := -1
	for stage_number in range(1, LevelCatalog.STAGE_COUNT + 1):
		if "S" in "\n".join(LevelCatalog.get_layout(stage_number)):
			persistence_stage = stage_number
			break

	_check(persistence_stage > 0, "The campaign exposes a Silver persistence stage.")
	GameSession.new_game(persistence_stage)
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	var restart_requested := [false]
	gameplay.restart_requested.connect(func() -> void: restart_requested[0] = true)
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame

	var level_id := gameplay.level.get_instance_id()
	var silver_brick: Brick
	var regular_brick: Brick
	for child in gameplay.level.bricks.get_children():
		var brick := child as Brick
		if silver_brick == null and brick.hit_points > 1:
			silver_brick = brick
		elif regular_brick == null and not brick.indestructible and brick.hit_points == 1:
			regular_brick = brick

	_check(silver_brick != null, "The persistence stage contains Silver.")
	_check(regular_brick != null, "The persistence stage contains a regular brick.")
	var silver_starting_hits := silver_brick.hit_points
	silver_brick.hit()
	_check(
		gameplay.brick_audio.get_last_hit_kind() == Brick.HitKind.DURABLE,
		"Silver contact routes through the durable audio path."
	)
	regular_brick.hit()
	await get_tree().process_frame

	var remaining_bricks := gameplay.level.get_brick_count()
	var preserved_score := GameSession.score
	var falling_chip: PowerUp = POWER_UP_SCENE.instantiate()
	falling_chip.configure(PowerUp.PowerType.SLOW)
	gameplay.power_ups.add_child(falling_chip)
	falling_chip.global_position = Vector2(80, 160)
	gameplay.apply_power_up(PowerUp.PowerType.WIDE)
	gameplay.ball.launch()
	gameplay._on_death_zone_body_entered(gameplay.ball)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(not restart_requested[0], "Life loss no longer reloads the gameplay scene.")
	_check(
		gameplay.level.get_instance_id() == level_id,
		"Life loss keeps the same level instance."
	)
	_check(
		gameplay.level.get_brick_count() == remaining_bricks,
		"Destroyed bricks stay destroyed after life loss."
	)
	_check(
		is_instance_valid(silver_brick)
		and silver_brick.hit_points == silver_starting_hits - 1,
		"Damaged Silver keeps its remaining hit points."
	)
	_check(GameSession.score == preserved_score + Gameplay.POWER_UP_SCORE, "Score persists after life loss.")
	_check(GameSession.balls_remaining == 2, "Life loss consumes exactly one ball.")
	_check(gameplay.paddle.paddle_width == 40.0, "Life loss resets Wide.")
	_check(gameplay.ball.speed == BreakerBall.BASE_SPEED, "Life loss resets Slow speed.")
	_check(gameplay.get_active_power_up() == -1, "Life loss clears the active power-up.")
	_check(gameplay.power_ups.get_child_count() == 0, "Life loss clears falling chips.")
	_check(not gameplay.ball.is_active(), "Life loss docks a fresh serve.")
	_check(gameplay.ball.global_position == Vector2(128, 212), "The serve resets above center paddle.")
	_check(gameplay.hud.is_launch_ready(), "The launch cue returns after life loss.")

	await get_tree().create_timer(0.4).timeout
	gameplay.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_deferred_pickup_transition_guard() -> void:
	GameSession.new_game()
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame

	gameplay._on_power_up_picked(PowerUp.PowerType.WIDE)
	gameplay._on_death_zone_body_entered(gameplay.ball)
	await get_tree().process_frame
	await get_tree().process_frame

	_check(
		gameplay.get_active_power_up() == -1,
		"A same-frame pickup cannot survive life-loss reset."
	)
	_check(
		gameplay.paddle.paddle_width == PaddleController.STANDARD_WIDTH,
		"Stale deferred Wide cannot alter the fresh serve."
	)
	_check(
		gameplay.balls.get_child_count() == 1,
		"Stale deferred Multi cannot spawn balls after a transition."
	)

	gameplay.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_final_life_game_over() -> void:
	GameSession.new_game(5)
	GameSession.register_ball_lost()
	GameSession.register_ball_lost()
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	var game_over_requested := [false]
	gameplay.game_over_requested.connect(
		func() -> void:
			game_over_requested[0] = true
	)
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame

	gameplay.ball.launch()
	gameplay._on_death_zone_body_entered(gameplay.ball)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(game_over_requested[0], "Losing the final ball still requests Game Over.")
	_check(GameSession.balls_remaining == 0, "Final life loss leaves zero balls.")

	gameplay.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_wall_collision() -> void:
	GameSession.new_game()
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame

	gameplay.ball.global_position = Vector2(236, 160)
	gameplay.ball.launch()
	for physics_step in range(10):
		await get_tree().physics_frame

	_check(gameplay.ball.velocity.x < 0.0, "The ball reflects from the right wall.")
	_check(
		is_equal_approx(gameplay.ball.velocity.length(), 200.0),
		"Wall collisions preserve constant ball speed."
	)

	gameplay.ball.deactivate()
	gameplay.queue_free()
	await get_tree().process_frame


func _test_brick_collision_flow() -> void:
	GameSession.new_game()
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame
	await get_tree().physics_frame

	var target_brick := _brick_at(gameplay.level, Vector2(64, 102))
	_check(target_brick != null, "The collision target brick exists.")
	_check(target_brick.collision_layer == 8, "The target brick uses the brick collision layer.")
	var target_shape := target_brick.get_node("CollisionShape2D") as CollisionShape2D
	_check(not target_shape.disabled, "The target brick collision shape is active.")

	var point_query := PhysicsPointQueryParameters2D.new()
	point_query.position = Vector2(64, 102)
	point_query.collision_mask = 8
	var point_hits := gameplay.get_world_2d().direct_space_state.intersect_point(point_query)
	_check(not point_hits.is_empty(), "The target brick is registered in the physics space.")

	gameplay.ball.global_position = Vector2(64, 112)
	var collision_probe := gameplay.ball.move_and_collide(Vector2(0, -8), true)
	_check(collision_probe != null, "The ball shape can sweep into the target brick.")
	gameplay.ball.launch_in_direction(Vector2.UP)
	_check(gameplay.ball.is_physics_processing(), "The launched ball is processing physics.")
	for physics_step in range(5):
		await get_tree().physics_frame
	await get_tree().process_frame

	_check(
		gameplay.level.get_brick_count() == 63,
		"A ball collision destroys one brick (ball at %s)." % gameplay.ball.global_position
	)
	_check(GameSession.score == 100, "A brick collision awards the brick's score.")
	_check(gameplay.effects.get_child_count() == 1, "A broken brick spawns its effect.")
	_check(gameplay.brick_audio.get_hit_count() == 1, "Brick contact triggers pitch-varied audio.")
	_check(gameplay.ball.velocity.y > 0.0, "The ball reflects downward from a brick's lower face.")

	gameplay.ball.deactivate()
	await get_tree().create_timer(0.4).timeout
	gameplay.queue_free()
	await get_tree().process_frame


func _brick_score_at(level: Level01, position: Vector2) -> int:
	var brick := _brick_at(level, position)
	return brick.score if brick != null else -1


func _brick_at(level: Level01, position: Vector2) -> Brick:
	for child in level.bricks.get_children():
		var brick := child as Brick
		if brick.position == position:
			return brick

	return null


func _find_power_up_brick(level: Level01, power_type: int) -> Brick:
	for child in level.bricks.get_children():
		var brick := child as Brick
		if brick.power_up_type == power_type:
			return brick

	return null

func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return

	_failures += 1
	push_error("FAIL: %s" % message)


func _signed_pcm_mean(data: PackedByteArray) -> float:
	if data.is_empty():
		return 0.0

	var total := 0.0
	for encoded_byte in data:
		total += Pcm8.decode(encoded_byte)
	return total / data.size()
