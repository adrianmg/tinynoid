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
const NAME_ENTRY_SCENE: PackedScene = preload("res://scenes/name_entry.tscn")
const HIGH_SCORES_SCENE: PackedScene = preload("res://scenes/high_scores.tscn")
const COMMUNITY_LAB_SCENE: PackedScene = preload(
	"res://scenes/community_lab.tscn"
)
const BRICK_BREAK_EFFECT_SCENE: PackedScene = preload(
	"res://scenes/effects/brick_break_effect.tscn"
)

var _failures := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if "--ball-physics-only" in OS.get_cmdline_user_args():
		await _test_ball_direction_invariant()
		await _test_thru_physics()
		await _test_paddle_bounce_angles()
		await _test_physics_signal_wiring()
		await _test_paddle_wall_edge_escape()
		await _test_power_up_effects()
		await _test_wall_collision()
		await _test_brick_collision_flow()
		await _finish("Ball physics tests")
		return

	await _test_pixel_perfect_settings()
	await _test_generated_music()
	await _test_streaming_music_preview()
	await _test_generated_ui_audio()
	await _test_audio_levels()
	await _test_display_modes()
	await _test_main_menu()
	await _test_community_catalog()
	await _test_name_entry_and_high_scores()
	await _test_touch_controls()
	await _test_campaign_routing()
	await _test_game_session()
	await _test_player_profile()
	await _test_leaderboard_client()
	await _test_level_catalog()
	await _test_capsule_drop_director()
	await _test_dynamic_power_up_flow()
	await _test_brick_rules()
	await _test_thru_physics()
	await _test_gold_stage_clear()
	await _test_level_content()
	await _test_brick_scores_once()
	await _test_paddle_bounce_angles()
	await _test_ball_direction_invariant()
	await _test_ball_launch()
	await _test_brick_break_effect()
	await _test_brick_audio_pitch()
	await _test_power_up_chip()
	await _test_result_screens()
	await _test_score_storage_failure()
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

	await _finish("All Godot port tests")


func _finish(suite_name: String) -> void:
	if _failures == 0:
		print("%s passed." % suite_name)
	else:
		push_error("%d %s failed." % [_failures, suite_name.to_lower()])

	MusicController.shutdown()
	await get_tree().process_frame
	get_tree().quit(_failures)


func _test_generated_music() -> void:
	_check(Pcm8.decode(Pcm8.encode(0.0, 92.0)) == 0, "Signed PCM encodes silence at zero.")
	_check(Pcm8.decode(Pcm8.encode(1.0, 92.0)) == 92, "Signed PCM preserves positive samples.")
	_check(Pcm8.decode(Pcm8.encode(-1.0, 92.0)) == -92, "Signed PCM preserves negative samples.")
	var music_player := MusicControllerState._create_music_player()
	_check(
		music_player.playback_type == AudioServer.PLAYBACK_TYPE_STREAM,
		"Procedural background music forces stream playback for web exports."
	)
	music_player.free()

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
		ProjectSettings.get_setting("application/config/name") == "TINYNOID",
		"The Godot project is named TINYNOID."
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

	GameSession.new_game(1, 8080)
	var menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	var start_requested := [-1]
	var high_scores_requested := [false]
	var community_lab_requested := [false]
	var quit_requested := [false]
	menu.start_requested.connect(
		func(stage_number: int) -> void:
			start_requested[0] = stage_number
	)
	menu.high_scores_requested.connect(
		func() -> void: high_scores_requested[0] = true
	)
	menu.community_lab_requested.connect(
		func() -> void: community_lab_requested[0] = true
	)
	menu.quit_requested.connect(func() -> void: quit_requested[0] = true)
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	_check(
		MainMenu.SUBTITLE == "A TINY ARKANOID TRIBUTE BY @ADRIANMG",
		"The menu carries the concise tribute subtitle."
	)
	_check(
		MainMenu.instruction_lines_for(false) == [
			"Arrow keys to move & select",
			"Enter / Space to select",
			"ESC to quit",
		],
		"The desktop menu advertises keyboard controls."
	)
	_check(
		MainMenu.instruction_lines_for(true) == [
			"Tap and drag to move",
			"Tap to select / launch / fire",
			"Swipe lists to scroll",
		],
		"The mobile menu advertises touch controls."
	)
	_check(
		menu.call("_get_option_at", Vector2(40, 80)) == 0,
		"The menu gives touch input the full width of each option row."
	)
	_check(PixelFont.GLYPHS.has("."), "The bitmap font supports the domain period.")
	_check(PixelFont.GLYPHS.has("/"), "The bitmap font supports the instruction slash.")
	_check(PixelFont.GLYPHS.has("&"), "The bitmap font supports the instruction ampersand.")
	_check(PixelFont.GLYPHS.has("@"), "The bitmap font supports player handles.")
	_check(PixelFont.GLYPHS.has("#"), "The bitmap font supports leaderboard ranks.")
	_check(PixelFont.GLYPHS.has("_"), "The bitmap font supports handle underscores.")
	_check(PixelFont.GLYPHS.has("—"), "The bitmap font supports attribution separators.")
	menu.call(
		"_on_latest_score_updated",
		Leaderboard.STATE_READY,
		{"player_name": "@ADRIANMG", "score": 1235},
		"2026-08-23T21:50:00"
	)
	_check(
		menu.get_recent_score_text()
		== "@ADRIANMG HIT 1235 POINTS RECENTLY",
		"The main menu highlights the most recent player and score."
	)
	menu.call(
		"_on_latest_score_updated",
		Leaderboard.STATE_READY,
		{
			"player_name": "@123456789012345",
			"score": Leaderboard.MAX_SCORE,
		},
		"2026-08-23T21:50:00"
	)
	_check(
		PixelFont.measure(menu.get_recent_score_text()).x <= 256,
		"The longest recent-score message fits the logical canvas."
	)
	menu.call(
		"_on_latest_score_updated",
		Leaderboard.STATE_EMPTY,
		{},
		"2026-08-23T21:50:00"
	)
	_check(
		menu.get_recent_score_text() == "NO RECENT SCORES YET",
		"The main menu handles an empty leaderboard."
	)
	var web_menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	web_menu.set("_web_mode", true)
	get_tree().root.add_child(web_menu)
	await get_tree().process_frame
	_check(
		web_menu.call("_option_count") == 4
		and web_menu.call("_get_option_text", 3).begins_with("SOUND"),
		"Web menus omit native window controls and keep Sound contiguous."
	)
	for web_option_index in range(web_menu.call("_option_count")):
		_check(
			not String(
				web_menu.call("_get_option_text", web_option_index)
			).begins_with("WINDOW"),
			"Web menu options never expose Window mode."
		)
	web_menu.queue_free()
	await get_tree().process_frame

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
	_check(menu.get_selected_index() == 1, "Menu navigation selects Community Lab.")
	_check(
		UiAudio.get_move_count() == move_count + 1,
		"Up/Down navigation plays the movement tick."
	)

	menu._unhandled_input(fire_event)
	_check(community_lab_requested[0], "FIRE opens Community Lab.")

	menu._unhandled_input(down_event)
	_check(menu.get_selected_index() == 2, "Menu navigation selects High Scores.")
	menu._unhandled_input(fire_event)
	_check(high_scores_requested[0], "FIRE opens the global leaderboard.")

	menu._unhandled_input(down_event)
	_check(menu.get_selected_index() == 3, "Menu navigation selects Window mode.")
	DisplayController.set_window_scale(2)
	menu._unhandled_input(right_event)
	_check(DisplayController.get_mode_label() == "3X", "Menu arrows change window mode.")
	_check(
		UiAudio.get_move_count() >= move_count + 3,
		"Left/Right interaction plays the movement tick."
	)

	menu._unhandled_input(down_event)
	_check(menu.get_selected_index() == 4, "Menu navigation selects Sound.")
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

	var featured_level := _community_level_fixture()
	var featured_menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	var featured_requested: Array[Dictionary] = []
	featured_menu.configure_featured_community_level(featured_level)
	featured_menu.community_level_requested.connect(
		func(level: Dictionary) -> void:
			featured_requested.append(level)
	)
	get_tree().root.add_child(featured_menu)
	await get_tree().process_frame
	_check(
		featured_menu.has_featured_community_level()
		and featured_menu.get_selected_index() == 0,
		"A shared community level is preselected on the main menu."
	)
	_check(
		featured_menu.call("_get_option_text", 0) == "PLAY SHARED LEVEL"
		and featured_menu.get_recent_score_text()
			== "NEON TEST — BY @BUILDER",
		"The shared menu identifies the selected level and creator."
	)
	featured_menu._unhandled_input(fire_event)
	_check(
		featured_requested.size() == 1
		and featured_requested[0].id == featured_level.id,
		"FIRE starts the preselected shared level."
	)
	featured_menu._unhandled_input(right_event)
	_check(
		not featured_menu.has_featured_community_level()
		and featured_menu.get_selected_stage() == 2
		and featured_menu.call("_get_option_text", 0) == "PLAY STAGE 02",
		"Left or Right exits shared selection into campaign stages."
	)
	featured_menu.queue_free()
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

	application_menu = main.find_child(
		"MainMenu",
		true,
		false
	) as MainMenu
	application_menu._unhandled_input(down_event)
	application_menu._unhandled_input(fire_event)
	await get_tree().process_frame
	_check(
		main.find_child("CommunityLab", true, false) != null,
		"The main menu opens the Community Lab chooser."
	)
	var application_lab := main.find_child(
		"CommunityLab",
		true,
		false
	) as CommunityLab
	application_lab._unhandled_input(cancel_event)
	await get_tree().process_frame
	_check(
		main.find_child("MainMenu", true, false) != null,
		"Escape returns from Community Lab to the main menu."
	)

	application_menu = main.find_child(
		"MainMenu",
		true,
		false
	) as MainMenu
	application_menu._unhandled_input(down_event)
	application_menu._unhandled_input(down_event)
	application_menu._unhandled_input(fire_event)
	await get_tree().process_frame
	_check(
		main.find_child("HighScores", true, false) != null,
		"The main menu opens the Top 100 screen."
	)
	var application_scores := main.find_child(
		"HighScores",
		true,
		false
	) as HighScoresScreen
	application_scores._unhandled_input(cancel_event)
	await get_tree().process_frame
	_check(
		main.find_child("MainMenu", true, false) != null,
		"Escape returns from High Scores to the main menu."
	)

	main.queue_free()
	await get_tree().process_frame


func _test_community_catalog() -> void:
	var pending_level := _community_level_fixture()
	var validation := CommunityCatalogClient.validate_level(pending_level)
	_check(
		validation.ok,
		"The Community Lab accepts the canonical schema."
	)
	_check(
		validation.level.layout.size() == 10
		and String(validation.level.layout[0]).length() == 13,
		"Validated community layouts preserve the 13 by 10 runtime grid."
	)

	var lowercase_name := pending_level.duplicate(true)
	lowercase_name.level_name = "Neon Test"
	_check(
		not CommunityCatalogClient.validate_level(lowercase_name).ok,
		"Community display fields must already be normalized uppercase."
	)
	var invalid_code := pending_level.duplicate(true)
	invalid_code.layout[0] = "WWWWWWWW?...."
	_check(
		not CommunityCatalogClient.validate_level(invalid_code).ok,
		"Community layouts reject non-native brick codes."
	)
	var too_few_bricks := pending_level.duplicate(true)
	too_few_bricks.layout[0] = "WWWWWWW......"
	too_few_bricks.populated_count = 7
	_check(
		not CommunityCatalogClient.validate_level(too_few_bricks).ok,
		"Community layouts require eight destructible cells."
	)
	var quarantined := pending_level.duplicate(true)
	quarantined.status = "quarantined"
	_check(
		not CommunityCatalogClient.validate_level(quarantined).ok,
		"Quarantined community records are filtered out."
	)
	_check(
		not CommunityCatalogClient.parse_exact_response(
			[pending_level],
			"cl_ffffffffffffffffffffffff"
		).ok,
		"An exact freshness response must match the requested id."
	)
	_check(
		CommunityCatalogClient.parse_exact_response(
			[],
			pending_level.id
		).get("unavailable", false),
		"An empty exact response definitively marks a level unavailable."
	)
	_check(
		CommunityCatalogClient.deep_link_id(
			"?foo=bar&community=cl_0123456789abcdef01234567"
		) == pending_level.id,
		"Web community deep links accept canonical ids."
	)
	_check(
		CommunityCatalogClient.format_creator_name("adrianmg")
			== "@ADRIANMG"
		and CommunityCatalogClient.format_creator_name("@ADRIANMG")
			== "@ADRIANMG",
		"Community creator labels consistently include one at sign."
	)
	_check(
		BrickRules.get_color("R") == BrickRules.get_definition("R", 1).color,
		"Community previews reuse runtime brick colors."
	)
	_check(
		BrickRules.get_color("?") == BrickRules.PREVIEW_FALLBACK_COLOR,
		"Community previews remain safe if a future code is unsupported."
	)

	var catalog_client := CommunityCatalogClient.new()
	get_tree().root.add_child(catalog_client)
	await get_tree().process_frame
	var test_cache_path := "user://community_levels_test.json"
	catalog_client.set("_cache_path", test_cache_path)
	_check(
		catalog_client.call("_request_headers").size() == 2,
		"Community requests include the publishable API key."
	)
	var response_body := JSON.stringify([pending_level]).to_utf8_buffer()
	catalog_client.call(
		"_on_catalog_completed",
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		response_body
	)
	_check(
		not catalog_client.is_confirmed_playable(pending_level.id),
		"Catalog and cached rows are not fresh enough to play."
	)
	catalog_client.set("_requested_id", pending_level.id)
	catalog_client.call(
		"_on_exact_completed",
		HTTPRequest.RESULT_CANT_CONNECT,
		0,
		PackedStringArray(),
		PackedByteArray()
	)
	_check(
		catalog_client.cached_entries().size() == 1,
		"Offline exact checks retain cached levels for later verification."
	)
	catalog_client.set("_requested_id", pending_level.id)
	catalog_client.call(
		"_on_exact_completed",
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		response_body
	)
	_check(
		catalog_client.is_confirmed_playable(pending_level.id),
		"An exact online lookup unlocks a pending or listed level."
	)
	catalog_client.set("_requested_id", pending_level.id)
	catalog_client.call(
		"_on_exact_completed",
		HTTPRequest.RESULT_SUCCESS,
		200,
		PackedStringArray(),
		JSON.stringify([quarantined]).to_utf8_buffer()
	)
	_check(
		not catalog_client.is_confirmed_playable(pending_level.id)
		and catalog_client.cached_entries().is_empty(),
		"A definitive hidden response revokes playability and evicts memory cache."
	)
	var persisted_cache: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(test_cache_path)
	)
	_check(
		persisted_cache is Dictionary
		and persisted_cache.get("entries", []).is_empty(),
		"A definitive hidden response evicts the persistent cache entry."
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_cache_path))
	catalog_client.queue_free()
	await get_tree().process_frame

	var lab: CommunityLab = COMMUNITY_LAB_SCENE.instantiate()
	get_tree().root.add_child(lab)
	await get_tree().process_frame
	var lab_entries: Array[Dictionary] = [pending_level]
	lab.call(
		"_on_catalog_updated",
		CommunityCatalog.STATE_STALE,
		lab_entries,
		"2026-08-23T22:00:00Z",
		"offline"
	)
	_check(
		lab.get_entries().size() == 1
		and lab.get_status_text() == "OFFLINE CACHE - RECHECK REQUIRED",
		"The chooser labels cached offline content and requires verification."
	)
	_check(
		lab.call("_get_entry_author_text", pending_level) == "BY @BUILDER"
		and lab.call("_get_entry_status_text", pending_level) == "UNREVIEWED",
		"Community rows place the author on a line before moderation status."
	)
	var editor_requests := [0]
	lab.editor_requested.connect(
		func() -> void:
			editor_requests[0] += 1
	)
	lab.set("_selected_index", lab.call("_editor_index"))
	lab.call("_activate_selected")
	_check(
		editor_requests[0] == 1,
		"Community Lab exposes the level editor as a footer action."
	)
	var original_catalog_entries := CommunityCatalog.cached_entries()
	var singleton_catalog_entry: Array[Dictionary] = [pending_level]
	CommunityCatalog.set("_entries", singleton_catalog_entry)
	lab.set("_checking_id", pending_level.id)
	lab.call(
		"_on_level_checked",
		pending_level.id,
		false,
		{},
		"Community service is offline."
	)
	_check(
		lab.get_entries().size() == 1
		and lab.get_status_text() == "OFFLINE CACHE - RECHECK REQUIRED",
		"An offline exact failure retains and labels the cached level."
	)
	var empty_catalog_entries: Array[Dictionary] = []
	CommunityCatalog.set("_entries", empty_catalog_entries)
	lab.set("_checking_id", pending_level.id)
	lab.call(
		"_on_level_checked",
		pending_level.id,
		false,
		{},
		"Community level is no longer available."
	)
	_check(
		lab.get_entries().is_empty(),
		"A definitively hidden level disappears from the chooser."
	)
	_check(
		lab.get_status_text() != "OFFLINE CACHE - RECHECK REQUIRED",
		"A definitively hidden level is not labeled as offline cache."
	)
	CommunityCatalog.set("_entries", original_catalog_entries)
	lab.set("_notice", "")
	var no_entries: Array[Dictionary] = []
	lab.call(
		"_on_catalog_updated",
		CommunityCatalog.STATE_LOADING,
		no_entries,
		"",
		""
	)
	_check(
		lab.get_status_text() == "LOADING COMMUNITY LEVELS",
		"The chooser exposes its loading state."
	)
	lab.call(
		"_on_catalog_updated",
		CommunityCatalog.STATE_EMPTY,
		no_entries,
		"2026-08-23T22:00:00Z",
		""
	)
	_check(
		lab.get_status_text() == "NO COMMUNITY LEVELS YET",
		"The chooser exposes an empty catalog state."
	)
	lab.call(
		"_on_catalog_updated",
		CommunityCatalog.STATE_ERROR,
		no_entries,
		"",
		"offline"
	)
	_check(
		lab.get_status_text() == "COMMUNITY SERVICE OFFLINE",
		"The chooser exposes an uncached offline error state."
	)
	lab.queue_free()
	await get_tree().process_frame

	GameSession.new_community_game(pending_level, 2468)
	_check(
		GameSession.is_community_run()
		and not GameSession.can_submit_score()
		and GameSession.run_id.is_empty(),
		"Community sessions are explicit unranked runs without score ids."
	)
	_check(
		not GameSession.restart_current_run()
		and GameSession.is_community_run()
		and GameSession.community_level.id == pending_level.id,
		"Community sessions cannot restart directly from cached level data."
	)
	_check(
		GameSession.capture_run_result("game_over").is_empty(),
		"Community runs never capture leaderboard results."
	)
	var level: Level01 = LEVEL_SCENE.instantiate()
	get_tree().root.add_child(level)
	await get_tree().process_frame
	_check(
		level.get_brick_count() == 8
		and level.get_destructible_brick_count() == 8,
		"Community dots become spaces at the existing brick spawn seam."
	)
	_check(
		level.get_stage_name() == pending_level.level_name,
		"Community runtime generation retains its level attribution."
	)
	level.queue_free()
	await get_tree().process_frame
	var community_hud := RetroHud.new()
	get_tree().root.add_child(community_hud)
	await get_tree().process_frame
	_check(
		community_hud.get_stage_value_text() == pending_level.level_name,
		"The HUD replaces the community stage number with the level name."
	)
	_check(
		PixelFont.measure(community_hud.get_stage_value_text()).x
			<= RetroHud.STAGE_COLUMN_WIDTH,
		"Community level names remain inside the Stage column."
	)
	_check(
		community_hud.get_community_author_text() == "@BUILDER",
		"The HUD keeps the community avatar and author in the Stage column."
	)
	community_hud.queue_free()
	await get_tree().process_frame

	var community_submission := {
		"run_id": "0198d71f-1ef3-7000-8000-000000000003",
		"run_kind": "community",
		"community_id": pending_level.id,
		"player_name": "@PLAYER_ONE",
		"score": 100,
		"outcome": "game_over",
		"completed_stage": 1,
		"start_stage": 1,
	}
	_check(
		not Leaderboard.validate_submission(community_submission).is_empty(),
		"Leaderboard validation rejects community submissions."
	)

	var main: Node = MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	GameSession.new_community_game(pending_level, 2468)
	main.set("_community_retry_id", pending_level.id)
	main.call(
		"_on_level_checked",
		pending_level.id,
		false,
		{},
		"Community level is no longer available."
	)
	await get_tree().process_frame
	var retry_screen: Node = main.get("_current_screen")
	_check(
		not GameSession.is_community_run()
		and retry_screen is CommunityLab
		and retry_screen.get_status_text()
			== "COMMUNITY LEVEL IS NO LONGER AVAILABLE.",
		"A hidden community retry clears stale gameplay and returns to the Lab."
	)
	GameSession.new_community_game(pending_level, 2468)
	main.set("_community_retry_id", pending_level.id)
	main.call("_show_main_menu")
	main.call(
		"_on_level_checked",
		pending_level.id,
		true,
		pending_level,
		""
	)
	await get_tree().process_frame
	_check(
		main.get("_current_screen") is MainMenu
		and String(main.get("_community_retry_id")).is_empty(),
		"A retry response cannot reopen gameplay after navigation."
	)
	main.set("_deep_link_id", pending_level.id)
	main.call("_show_high_scores")
	main.call(
		"_on_level_checked",
		pending_level.id,
		true,
		pending_level,
		""
	)
	await get_tree().process_frame
	_check(
		main.get("_current_screen") is HighScoresScreen
		and String(main.get("_deep_link_id")).is_empty(),
		"A deep-link response cannot replace a newer navigation target."
	)
	GameSession.new_game()
	main.call("_show_main_menu")
	var confirmed_levels := {
		pending_level.id: pending_level,
	}
	CommunityCatalog.set("_confirmed_levels", confirmed_levels)
	main.set("_deep_link_id", pending_level.id)
	main.call(
		"_on_level_checked",
		pending_level.id,
		true,
		pending_level,
		""
	)
	await get_tree().process_frame
	var shared_menu := main.get("_current_screen") as MainMenu
	_check(
		shared_menu != null
		and shared_menu.has_featured_community_level()
		and not GameSession.is_community_run(),
		"A verified deep link opens a preselected menu instead of auto-launching."
	)
	shared_menu.call("_activate_selected")
	await get_tree().process_frame
	_check(
		String(main.get("_featured_request_id")) == pending_level.id
		and main.get("_current_screen") is MainMenu,
		"Starting a featured level rechecks online freshness."
	)
	var featured_request := CommunityCatalog.get("_exact_request") as HTTPRequest
	if is_instance_valid(featured_request):
		featured_request.cancel_request()
	CommunityCatalog.set("_exact_in_flight", false)
	CommunityCatalog.set("_requested_id", "")
	CommunityCatalog.set(
		"_confirmed_levels",
		{pending_level.id: pending_level}
	)
	main.call(
		"_on_level_checked",
		pending_level.id,
		true,
		pending_level,
		""
	)
	await get_tree().process_frame
	_check(
		main.get("_current_screen") is Gameplay
		and GameSession.is_community_run()
		and GameSession.community_level.id == pending_level.id,
		"The preselected menu starts the verified community level."
	)
	var shared_cancel := InputEventAction.new()
	shared_cancel.action = "ui_cancel"
	shared_cancel.pressed = true
	main.call("_unhandled_input", shared_cancel)
	await get_tree().process_frame
	var replay_menu := main.get("_current_screen") as MainMenu
	_check(
		replay_menu != null
		and replay_menu.has_featured_community_level()
		and replay_menu.get_featured_community_level().id == pending_level.id,
		"Returning from shared gameplay keeps the level preselected for replay."
	)
	replay_menu.call("_activate_selected")
	await get_tree().process_frame
	featured_request = CommunityCatalog.get("_exact_request") as HTTPRequest
	if is_instance_valid(featured_request):
		featured_request.cancel_request()
	CommunityCatalog.set("_exact_in_flight", false)
	CommunityCatalog.set("_requested_id", "")
	main.call(
		"_on_level_checked",
		pending_level.id,
		false,
		{},
		"Community level is no longer available."
	)
	await get_tree().process_frame
	_check(
		main.get("_current_screen") is MainMenu
		and not GameSession.is_community_run(),
		"Removed featured levels cannot replay from cached data."
	)
	CommunityCatalog.set("_confirmed_levels", {})
	main.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_name_entry_and_high_scores() -> void:
	var stored_handle := PlayerProfile.player_name
	_check(
		NameEntryScreen.TITLE == "X / TWITTER HANDLE",
		"Handle entry explicitly names X and Twitter."
	)
	_check(
		NameEntryScreen.HANDLE_HINT == "@ IS ADDED FOR YOU",
		"Handle entry explains that the at sign is implicit."
	)
	var name_entry: NameEntryScreen = NAME_ENTRY_SCENE.instantiate()
	name_entry.configure("@PLAYER", 1235, true)
	get_tree().root.add_child(name_entry)
	await get_tree().process_frame
	name_entry.call("_append_character", "1")
	_check(
		name_entry.get_player_name() == "PLAYER1",
		"The name-entry screen supports controller-style character entry."
	)
	name_entry.call("_delete_character")
	_check(
		name_entry.get_player_name() == "PLAYER",
		"The name-entry screen supports deletion."
	)
	name_entry.set("_selected_row", NameEntryScreen.GRID_ROWS - 1)
	name_entry.set("_selected_column", 4)
	name_entry.call("_move_horizontal", 1)
	_check(
		name_entry.get("_selected_column") == 0,
		"The partial final handle row wraps without selecting empty cells."
	)
	name_entry.queue_free()
	await get_tree().process_frame

	PlayerProfile.player_name = ""
	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	GameSession.award(1235)
	main.call("_finish_run", "game_over")
	await get_tree().process_frame
	_check(
		main.find_child("NameEntry", true, false) != null,
		"A first-time handle prompt appears only after a terminal score."
	)
	main.queue_free()
	await get_tree().process_frame
	PlayerProfile.player_name = stored_handle
	GameSession.new_game()

	var entries: Array[Dictionary] = []
	for entry_index in range(20):
		entries.append({
			"rank": entry_index + 1,
			"player_name": "PLAYER%d" % entry_index,
			"score": 20000 - entry_index,
			"completed_stage": 3,
		})
	var high_scores: HighScoresScreen = HIGH_SCORES_SCENE.instantiate()
	get_tree().root.add_child(high_scores)
	await get_tree().process_frame
	high_scores.call(
		"_on_top_scores_updated",
		Leaderboard.STATE_READY,
		entries,
		"2026-08-23T22:00:00"
	)
	high_scores.call("_select_relative", 15)
	_check(
		high_scores.get_selected_index() == 15,
		"Leaderboard selection moves through the Top 100."
	)
	_check(
		high_scores.get_scroll_offset() == 2,
		"Leaderboard scroll follows selection beyond the visible rows."
	)
	var score_back_requests := [0]
	high_scores.back_requested.connect(
		func() -> void:
			score_back_requests[0] += 1
	)
	var score_back_click := InputEventMouseButton.new()
	score_back_click.button_index = MOUSE_BUTTON_LEFT
	score_back_click.position = Vector2(128, 217)
	score_back_click.pressed = true
	high_scores._gui_input(score_back_click)
	_check(
		score_back_requests[0] == 1
		and high_scores.get_selected_index() == entries.size(),
		"High Scores reuses the Community Lab Return to Menu action."
	)
	high_scores.queue_free()
	await get_tree().process_frame


func _test_touch_controls() -> void:
	_check(
		ProjectSettings.get_setting(
			"input_devices/pointing/emulate_mouse_from_touch",
			false
		),
		"Touch events are translated to the existing mouse control path."
	)

	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.position = Vector2(128, 86)
	tap.pressed = true
	var secondary_click := InputEventMouseButton.new()
	secondary_click.button_index = MOUSE_BUTTON_RIGHT
	secondary_click.position = Vector2(128, 86)
	secondary_click.pressed = true
	_check(GamePointer.is_primary_press(tap), "An emulated tap is a primary click.")
	_check(
		not GamePointer.is_primary_press(secondary_click),
		"Non-primary clicks do not activate touch actions."
	)

	GameSession.new_game(1, 8080)
	var menu: MainMenu = MAIN_MENU_SCENE.instantiate()
	var tapped_stage := [-1]
	menu.start_requested.connect(
		func(stage_number: int) -> void:
			tapped_stage[0] = stage_number
	)
	get_tree().root.add_child(menu)
	await get_tree().process_frame
	menu._gui_input(tap)
	_check(tapped_stage[0] == 1, "Tapping Play activates the selected stage.")
	menu.queue_free()
	await get_tree().process_frame

	var touch_lab: CommunityLab = COMMUNITY_LAB_SCENE.instantiate()
	var touch_level := _community_level_fixture()
	var touch_lab_entries: Array[Dictionary] = [touch_level]
	var lab_back_requests := [0]
	touch_lab.back_requested.connect(
		func() -> void:
			lab_back_requests[0] += 1
	)
	get_tree().root.add_child(touch_lab)
	await get_tree().process_frame
	touch_lab.call(
		"_on_catalog_updated",
		CommunityCatalog.STATE_READY,
		touch_lab_entries,
		"2026-08-24T00:00:00Z",
		""
	)
	secondary_click.position = Vector2(128, 70)
	touch_lab._gui_input(secondary_click)
	_check(
		String(touch_lab.get("_checking_id")).is_empty(),
		"A non-primary click does not activate a Community Lab level."
	)
	tap.position = Vector2(128, 70)
	touch_lab._gui_input(tap)
	_check(
		String(touch_lab.get("_checking_id")) == String(touch_level.id),
		"A primary tap activates the selected Community Lab level."
	)
	tap.position = Vector2(128, 217)
	touch_lab._gui_input(tap)
	secondary_click.position = tap.position
	touch_lab._gui_input(secondary_click)
	_check(
		lab_back_requests[0] == 1,
		"A tap returns from Community Lab without a secondary activation."
	)
	var exact_request := CommunityCatalog.get("_exact_request") as HTTPRequest
	if is_instance_valid(exact_request):
		exact_request.cancel_request()
	CommunityCatalog.set("_exact_in_flight", false)
	CommunityCatalog.set("_requested_id", "")
	touch_lab.queue_free()
	await get_tree().process_frame

	var touch_scores: HighScoresScreen = HIGH_SCORES_SCENE.instantiate()
	get_tree().root.add_child(touch_scores)
	await get_tree().process_frame
	var touch_entries: Array[Dictionary] = []
	for entry_index in range(20):
		touch_entries.append({
			"rank": entry_index + 1,
			"player_name": "@PLAYER%d" % entry_index,
			"score": 20000 - entry_index,
			"completed_stage": 3,
		})
	touch_scores.call(
		"_on_top_scores_updated",
		Leaderboard.STATE_READY,
		touch_entries,
		"2026-08-24T00:00:00"
	)
	var score_drag := InputEventMouseMotion.new()
	score_drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	score_drag.position = Vector2(128, 140)
	score_drag.relative = Vector2(0, -20)
	touch_scores._gui_input(score_drag)
	_check(
		touch_scores.get_selected_index() == 2,
		"Swiping the Top 100 advances touch selection."
	)
	touch_scores.queue_free()
	await get_tree().process_frame

	GameSession.new_game(1, 8080)
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame

	tap.position = Vector2(196, 200)
	gameplay.paddle._input(tap)
	gameplay._unhandled_input(tap)
	for physics_step in range(2):
		await get_tree().physics_frame
	_check(gameplay.ball.is_active(), "A gameplay tap launches the held ball.")
	_check(
		is_equal_approx(gameplay.paddle.global_position.x, 196.0),
		"A gameplay tap moves the paddle to the touch position."
	)

	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.position = Vector2(72, 200)
	gameplay.paddle._input(drag)
	await get_tree().physics_frame
	_check(
		is_equal_approx(gameplay.paddle.global_position.x, 72.0),
		"Dragging a primary touch steers the paddle."
	)

	gameplay.apply_power_up(PowerUp.PowerType.LASER)
	tap.position = Vector2(128, 200)
	gameplay._unhandled_input(tap)
	_check(gameplay.lasers.get_child_count() == 2, "A tap fires an equipped Laser.")
	for active_ball in gameplay._get_balls():
		active_ball.deactivate()
	gameplay.queue_free()
	await get_tree().process_frame

	var game_over: GameOverScreen = GAME_OVER_SCENE.instantiate()
	var retry_requested := [false]
	game_over.new_game_requested.connect(func() -> void: retry_requested[0] = true)
	get_tree().root.add_child(game_over)
	await get_tree().process_frame
	tap.position = Vector2(128, 151)
	tap.pressed = true
	Input.parse_input_event(tap)
	await get_tree().process_frame
	_check(retry_requested[0], "A tap retries from Game Over.")
	tap.pressed = false
	Input.parse_input_event(tap)
	game_over.queue_free()
	await get_tree().process_frame

	var stage_clear: StageClearScreen = STAGE_CLEAR_SCENE.instantiate()
	var continue_requested := [false]
	stage_clear.replay_requested.connect(func() -> void: continue_requested[0] = true)
	get_tree().root.add_child(stage_clear)
	await get_tree().process_frame
	tap.position = Vector2(128, 151)
	tap.pressed = true
	Input.parse_input_event(tap)
	await get_tree().process_frame
	_check(continue_requested[0], "A tap continues from Stage Clear.")
	tap.pressed = false
	Input.parse_input_event(tap)
	stage_clear.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


func _test_campaign_routing() -> void:
	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame

	main.call(&"_start_new_game", 32)
	await get_tree().process_frame
	_check(GameSession.level == 32, "Campaign routing starts a selected late stage.")
	_check(MusicController.get_current_track_id() == 32, "Stage 32 uses song 32.")
	var stage_32_stream_id := MusicController.get_stream().get_instance_id()
	GameSession.register_ball_lost()
	_check(GameSession.balls_remaining == 2, "The campaign can reach Stage Clear with two lives.")
	main.call(&"_show_gameplay")
	await get_tree().process_frame
	_check(
		MusicController.get_stream().get_instance_id() == stage_32_stream_id,
		"Reloading stage 32 keeps its current song stream."
	)

	main.call(&"_continue_campaign")
	await get_tree().process_frame
	_check(GameSession.level == 33, "Clearing stage 32 advances to stage 33.")
	_check(
		GameSession.balls_remaining == 2,
		"Advancing after Stage Clear preserves the current life count."
	)
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
	session.new_game(1, 12345)

	_check(session.score == 0, "A new game starts with zero score.")
	_check(session.balls_remaining == 3, "A new game starts with three balls.")
	_check(session.run_seed == 12345, "A supplied run seed is preserved for replay.")
	_check(session.starter_capsule_pending, "A new run starts with its beginner reward pending.")
	session.mark_starter_capsule_spawned()
	_check(
		not session.starter_capsule_pending,
		"Spawning the first capsule consumes the beginner reward."
	)
	session.add_ball()
	_check(session.balls_remaining == 4, "Extra Ball adds one ball.")
	session.new_game(17)
	_check(session.level == 17, "A new game can start from a selected stage.")
	var selected_stage_seed := session.run_seed
	session.mark_starter_capsule_spawned()
	_check(
		not session.can_submit_score(),
		"Runs started after Stage 1 are not globally eligible."
	)
	var local_only_result := session.capture_run_result("game_over")
	_check(
		not local_only_result.is_empty()
		and not local_only_result.eligible,
		"Later-stage runs still produce a local result."
	)
	session.add_ball()
	session.advance_level()
	_check(session.level == 18, "Campaign progression advances one stage.")
	_check(session.balls_remaining == 4, "Campaign progression preserves earned lives.")
	_check(session.run_seed == selected_stage_seed, "Campaign progression keeps the run seed.")
	_check(
		not session.starter_capsule_pending,
		"Campaign progression does not restore the one-time beginner reward."
	)
	session.new_game()
	_check(session.starter_capsule_pending, "A true restart restores the beginner reward.")

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
	var run_id := session.run_id
	var submission := session.capture_run_result("game_over")
	_check(
		not submission.is_empty()
		and submission.run_id == run_id
		and submission.start_stage == 1,
		"Stage 1 runs capture one terminal leaderboard submission."
	)
	_check(
		session.capture_run_result("game_over").is_empty(),
		"A run cannot be captured twice."
	)
	_check(
		run_id.length() == 36
		and run_id.substr(14, 1) == "4",
		"Leaderboard run IDs are random UUIDv4 values."
	)

	session.queue_free()
	await get_tree().process_frame


func _test_leaderboard_client() -> void:
	_check(
		Leaderboard.MAX_SCORE == 212690,
		"The leaderboard uses the current protected-drop campaign ceiling."
	)
	_check(
		_calculate_campaign_score_ceilings()
		== Leaderboard.MAX_SCORE_BY_STAGE,
		"Every stage ceiling follows the current capsule budget."
	)
	var valid_submission := {
		"run_id": "0198d71f-1ef3-7000-8000-000000000002",
		"run_token": "test-ticket",
		"player_name": "@PLAYER_ONE",
		"score": 12345,
		"outcome": "game_over",
		"completed_stage": 7,
		"start_stage": 1,
	}
	_check(
		Leaderboard.validate_submission(valid_submission).is_empty(),
		"Valid leaderboard submissions pass client validation."
	)

	var invalid_run_id := valid_submission.duplicate()
	invalid_run_id.run_id = "not-a-uuid"
	_check(
		not Leaderboard.validate_submission(invalid_run_id).is_empty(),
		"Leaderboard submissions require an idempotent UUID."
	)

	var invalid_name := valid_submission.duplicate()
	invalid_name.player_name = "NO!"
	_check(
		not Leaderboard.validate_submission(invalid_name).is_empty(),
		"Leaderboard names are restricted to the pixel-font character set."
	)

	var impossible_score := valid_submission.duplicate()
	impossible_score.score = Leaderboard.MAX_SCORE + 1
	_check(
		not Leaderboard.validate_submission(impossible_score).is_empty(),
		"Impossible leaderboard scores are rejected before networking."
	)
	var impossible_stage_score := valid_submission.duplicate()
	impossible_stage_score.completed_stage = 1
	impossible_stage_score.score = 6451
	_check(
		not Leaderboard.validate_submission(impossible_stage_score).is_empty(),
		"Scores above the completed-stage ceiling are rejected."
	)
	var invalid_clear := valid_submission.duplicate()
	invalid_clear.outcome = "campaign_clear"
	_check(
		not Leaderboard.validate_submission(invalid_clear).is_empty(),
		"Campaign-clear submissions require Stage 33."
	)

	var serialized_state := JSON.stringify({
		"pending_submissions": [valid_submission],
	})
	var restored_state: Variant = JSON.parse_string(serialized_state)
	var restored_client := LeaderboardClient.new()
	restored_client.call("_restore_state", restored_state)
	_check(
		restored_client.pending_submission_count() == 1,
		"Offline submissions survive a JSON save-and-reload cycle."
	)
	restored_client.call("_remember_local_score", {
		"run_id": valid_submission.run_id,
		"player_name": "@PLAYER_ONE",
		"score": 12345,
		"outcome": "game_over",
		"completed_stage": 7,
		"start_stage": 1,
		"submitted_at": "2026-08-23T22:00:00Z",
		"local": true,
	})
	_check(
		restored_client.cached_local_scores().size() == 1,
		"Local results remain available when the global board is offline."
	)
	_check(
		restored_client.call("_is_permanent_submission_failure", 400),
		"Invalid submissions are removed instead of blocking the queue."
	)
	_check(
		not restored_client.call("_is_permanent_submission_failure", 429),
		"Rate-limited submissions remain queued for retry."
	)
	restored_client.free()

	var storage_fails := [true]
	var storage_state: Array[Dictionary] = [{}]
	var storage_client := LeaderboardClient.new()
	storage_client.set_state_writer_for_tests(
		func(state: Dictionary) -> bool:
			if storage_fails[0]:
				return false
			storage_state[0] = state.duplicate(true)
			return true
	)
	var failed_run := {
		"run_id": "0198d71f-1ef3-7000-8000-000000000099",
		"score": 100,
		"outcome": "game_over",
		"completed_stage": 1,
		"start_stage": 1,
		"eligible": false,
	}
	_check(
		not storage_client.record_score(failed_run, "GUEST"),
		"Local persistence failure is returned to the caller."
	)
	_check(
		storage_client.has_save_failure(failed_run.run_id),
		"Failed terminal scores remain available for recovery."
	)
	storage_fails[0] = false
	_check(
		storage_client.retry_failed_score(failed_run.run_id),
		"Retrying after storage recovery persists the terminal score."
	)
	_check(
		not storage_client.has_save_failure(failed_run.run_id)
		and storage_client.has_local_score(failed_run.run_id),
		"Successful recovery clears the explicit save failure."
	)
	storage_client.free()
	var restored_storage_client := LeaderboardClient.new()
	restored_storage_client.call("_restore_state", storage_state[0])
	_check(
		not restored_storage_client.has_save_failure(failed_run.run_id),
		"A successful local-only retry clears its persisted failure."
	)
	restored_storage_client.free()

	var proof_run := {
		"run_id": "0198d71f-1ef3-7000-8000-000000000098",
		"score": 100,
		"outcome": "game_over",
		"completed_stage": 1,
		"start_stage": 1,
		"eligible": true,
	}
	var durable_proof_state := {
		"failed_records": {
			proof_run.run_id: {
				"run_result": proof_run,
				"player_name": "@PROOFTEST",
			},
		},
	}
	var proof_write_count := [0]
	var proof_client := LeaderboardClient.new()
	proof_client.call("_restore_state", durable_proof_state)
	proof_client.set_state_writer_for_tests(
		func(_state: Dictionary) -> bool:
			proof_write_count[0] += 1
			return false
	)
	proof_client.set("_run_tickets", {
		proof_run.run_id: {
			"run_token": "test-ticket",
			"expires_unix": int(Time.get_unix_time_from_system()) + 3600,
		},
	})
	_check(
		not proof_client.retry_failed_score(proof_run.run_id),
		"Failure to atomically persist queued proof propagates to the caller."
	)
	_check(
		proof_client.has_save_failure(proof_run.run_id),
		"Failed durable handoff retains the retry marker in memory."
	)
	proof_client.free()
	var restored_proof_client := LeaderboardClient.new()
	restored_proof_client.call("_restore_state", durable_proof_state)
	_check(
		restored_proof_client.has_save_failure(proof_run.run_id),
		"Failed durable handoff retains the prior retry marker on disk."
	)
	restored_proof_client.free()

	var late_ticket_state: Array[Dictionary] = [{}]
	var late_client := LeaderboardClient.new()
	late_client.set_state_writer_for_tests(
		func(state: Dictionary) -> bool:
			late_ticket_state[0] = state.duplicate(true)
			return true
	)
	var late_run := {
		"run_id": "0198d71f-1ef3-7000-8000-000000000097",
		"score": 100,
		"outcome": "game_over",
		"completed_stage": 1,
		"start_stage": 1,
		"eligible": true,
	}
	late_client.set("_ticket_requested", {late_run.run_id: true})
	_check(
		late_client.record_score(late_run, "@LATETEST"),
		"A terminal score waits while its pre-play ticket is still in flight."
	)
	_check(
		(
			late_ticket_state[0].get("awaiting_ticket_records", {})
			as Dictionary
		).has(late_run.run_id),
		"Awaiting ticket work is persisted before score submission."
	)
	var serialized_awaiting_state := JSON.stringify(late_ticket_state[0])
	var parsed_awaiting_state: Variant = JSON.parse_string(
		serialized_awaiting_state
	)
	var restored_awaiting_client := LeaderboardClient.new()
	restored_awaiting_client.set_state_writer_for_tests(
		func(_state: Dictionary) -> bool:
			return true
	)
	restored_awaiting_client.call(
		"_restore_state",
		parsed_awaiting_state as Dictionary
	)
	var restored_awaiting: Dictionary = (
		restored_awaiting_client.get("_awaiting_ticket_records")
		as Dictionary
	)
	_check(
		restored_awaiting.has(late_run.run_id)
		and typeof(
			(
				restored_awaiting[late_run.run_id].submission
				as Dictionary
			).score
		) == TYPE_INT,
		"Awaiting ticket work restores integer fields after a JSON round trip."
	)
	restored_awaiting_client.set("_run_tickets", {
		late_run.run_id: {
			"run_token": "restored-ticket",
			"expires_unix": int(Time.get_unix_time_from_system()) + 3600,
		},
	})
	restored_awaiting_client.set("_write_in_flight", true)
	restored_awaiting_client.call(
		"_submit_awaiting_ticket_record",
		late_run.run_id
	)
	_check(
		restored_awaiting_client.pending_submission_count() == 1,
		"Restored awaiting work enters the persisted send queue."
	)
	restored_awaiting_client.free()
	late_client.set("_run_tickets", {
		late_run.run_id: {
			"run_token": "late-ticket",
			"expires_unix": int(Time.get_unix_time_from_system()) + 3600,
		},
	})
	late_client.set("_write_in_flight", true)
	late_client.call("_submit_awaiting_ticket_record", late_run.run_id)
	_check(
		late_client.pending_submission_count() == 1,
		"A late ticket moves the completed run into the persisted send queue."
	)
	late_client.free()
	var restored_late_client := LeaderboardClient.new()
	restored_late_client.call("_restore_state", late_ticket_state[0])
	_check(
		not (
			restored_late_client.get("_awaiting_ticket_records")
			as Dictionary
		).has(late_run.run_id),
		"Persisted awaiting work is removed after it enters the send queue."
	)
	restored_late_client.free()

	var failed_ticket_state: Array[Dictionary] = [{}]
	var failed_ticket_client := LeaderboardClient.new()
	failed_ticket_client.set_state_writer_for_tests(
		func(state: Dictionary) -> bool:
			failed_ticket_state[0] = state.duplicate(true)
			return true
	)
	failed_ticket_client.set("_ticket_requested", {late_run.run_id: true})
	_check(
		failed_ticket_client.record_score(late_run, "@LATETEST"),
		"A terminal score can wait for its initial ticket response."
	)
	failed_ticket_client.set("_run_tickets", {
		late_run.run_id: {
			"run_token": "expired-ticket",
			"expires_unix": int(Time.get_unix_time_from_system()) - 1,
		},
	})
	failed_ticket_client.set("_active_ticket_run_id", late_run.run_id)
	failed_ticket_client.call(
		"_on_ticket_completed",
		HTTPRequest.RESULT_SUCCESS,
		500,
		PackedStringArray(),
		PackedByteArray()
	)
	_check(
		failed_ticket_client.has_save_failure(late_run.run_id),
		"An expired failed ticket becomes retryable instead of remaining stuck."
	)
	failed_ticket_client.free()
	var recovered_ticket_client := LeaderboardClient.new()
	recovered_ticket_client.call(
		"_restore_state",
		JSON.parse_string(
			JSON.stringify(failed_ticket_state[0])
		) as Dictionary
	)
	_check(
		recovered_ticket_client.has_save_failure(late_run.run_id),
		"A retryable ticket failure survives a client reload."
	)
	recovered_ticket_client.set_state_writer_for_tests(
		func(_state: Dictionary) -> bool:
			return true
	)
	recovered_ticket_client.call("_resume_recoverable_records")
	_check(
		not recovered_ticket_client.has_save_failure(late_run.run_id)
		and (
			recovered_ticket_client.get("_awaiting_ticket_records")
			as Dictionary
		).has(late_run.run_id),
		"Reloaded failures automatically return to the ticket queue."
	)
	recovered_ticket_client.free()
	var malformed_failure_client := LeaderboardClient.new()
	malformed_failure_client.call("_restore_state", {
		"failed_records": {
			late_run.run_id: {"player_name": "@LATETEST"},
		},
	})
	_check(
		not malformed_failure_client.has_save_failure(late_run.run_id),
		"Malformed persisted failures are ignored safely."
	)
	malformed_failure_client.free()
	var refresh_client := LeaderboardClient.new()
	refresh_client.set("_top_in_flight", true)
	refresh_client.set("_latest_in_flight", true)
	refresh_client.request_top_scores(25)
	refresh_client.request_latest_score()
	_check(
		bool(refresh_client.get("_top_refresh_requested"))
		and int(refresh_client.get("_top_refresh_limit")) == 25
		and bool(refresh_client.get("_latest_refresh_requested")),
		"Concurrent leaderboard refreshes remain queued instead of being dropped."
	)
	var refresh_pending: Array[Dictionary] = [valid_submission.duplicate()]
	refresh_client.set("_pending_submissions", refresh_pending)
	refresh_client.call("_flush_deferred_score_reads")
	_check(
		not bool(refresh_client.get("_write_in_flight"))
		and refresh_client.pending_submission_count() == 1,
		"Deferred reads never retry a failed pending score write."
	)
	refresh_client.free()


func _test_player_profile() -> void:
	_check(
		PlayerProfileState.normalize_name("  @adrian_mg  ")
		== "ADRIAN_MG",
		"X handles are stored without the implicit at sign."
	)
	_check(
		PlayerProfileState.get_name_error("@ADRIAN_MG").is_empty(),
		"Handles are valid player names."
	)
	_check(
		PlayerProfileState.format_handle("adrian_mg") == "@ADRIAN_MG",
		"X handles display with an implicit at sign."
	)
	_check(
		PixelAvatar._identity_hash("ADRIANMG")
		== PixelAvatar._identity_hash("@ADRIANMG"),
		"Generated avatar identity ignores the display-only at sign."
	)
	_check(
		PixelAvatar._identity_hash("ADRIANMG")
		!= PixelAvatar._identity_hash("OTHER_PLAYER"),
		"Generated avatars vary deterministically by player identity."
	)
	_check(
		not PlayerProfileState.get_name_error("NO-DASH").is_empty(),
		"X handles reject characters Twitter does not support."
	)
	_check(
		not PlayerProfileState.get_name_error("NO!").is_empty(),
		"Unsupported player-name glyphs are rejected."
	)
	var score_share_text := ScoreShare._share_text(10, "game_over")
	_check(
		score_share_text
		== "I scored 10 points in TINYNOID!\nhttps://tinynoid.vercel.app/",
		"Score sharing uses a first-person message with the game link."
	)
	var score_intent := ScoreShare._x_intent_url(score_share_text)
	_check(
		score_intent.begins_with("https://x.com/intent/post?text=")
		and score_intent.contains(ScoreShare.GAME_URL.uri_encode())
		and not score_intent.contains("&url="),
		"Score sharing embeds one game link in the X message."
	)
	_check(
		ScoreShare._share_text(10, "campaign_clear")
		== (
			"I cleared TINYNOID with 10 points!\n"
			+ "https://tinynoid.vercel.app/"
		),
		"Campaign sharing uses a first-person message with the game link."
	)


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


func _test_capsule_drop_director() -> void:
	_check(CapsuleDropDirector.calculate_budget(19) == 2, "Sparse stages budget two capsules.")
	_check(CapsuleDropDirector.calculate_budget(24) == 3, "A 24-brick stage budgets three capsules.")
	_check(CapsuleDropDirector.calculate_budget(64) == 8, "A 64-brick stage budgets eight capsules.")
	_check(CapsuleDropDirector.calculate_budget(78) == 8, "Dense stages cap at eight capsules.")

	var trace_a := _simulate_capsule_stage(4242, 1, 64, true)
	var trace_b := _simulate_capsule_stage(4242, 1, 64, true)
	_check(trace_a == trace_b, "The same seed and event stream reproduce every drop decision.")
	_check(
		trace_a.types[0] in [
			PowerUp.PowerType.WIDE,
			PowerUp.PowerType.SLOW,
			PowerUp.PowerType.MULTI,
		],
		"The first run reward comes from the beginner-friendly pool."
	)

	var blocked_director := CapsuleDropDirector.new(91, 1, 64, true)
	var blocked_drop_count := 0
	for break_number in range(1, 21):
		var blocked_snapshot := CapsuleDropDirector.DropSnapshot.new(
			64 - break_number,
			CapsuleDropDirector.MAX_FALLING_CAPSULES,
			0,
			3,
			1
		)
		if (
			blocked_director.on_brick_destroyed(blocked_snapshot)
			!= CapsuleDropDirector.NO_DROP
		):
			blocked_drop_count += 1
	_check(
		blocked_drop_count == 0,
		"Visible capsules suspend drop rolls without advancing pity."
	)
	var resumed_drop_break := -1
	for break_number in range(21, 27):
		var resumed_snapshot := CapsuleDropDirector.DropSnapshot.new(
			64 - break_number,
			0,
			0,
			3,
			1
		)
		if blocked_director.on_brick_destroyed(resumed_snapshot) >= 0:
			resumed_drop_break = break_number
			break
	_check(
		resumed_drop_break >= 23 and resumed_drop_break <= 26,
		"Drop pity resumes from zero after visible capsules clear."
	)

	var active_filter_director := CapsuleDropDirector.new(617, 7, 40, false)
	var active_filter_violations := 0
	for break_number in range(1, 40):
		var active_filter_snapshot := CapsuleDropDirector.DropSnapshot.new(
			40 - break_number,
			0,
			(1 << PowerUp.PowerType.WIDE) | (1 << PowerUp.PowerType.LASER),
			3,
			1
		)
		var filtered_type := active_filter_director.on_brick_destroyed(
			active_filter_snapshot
		)
		if filtered_type in [
			PowerUp.PowerType.WIDE,
			PowerUp.PowerType.LASER,
		]:
			active_filter_violations += 1
	_check(
		active_filter_violations == 0,
		"All active capsule types are excluded from random selection."
	)

	var starter_mask := (
		(1 << PowerUp.PowerType.WIDE)
		| (1 << PowerUp.PowerType.SLOW)
		| (1 << PowerUp.PowerType.MULTI)
	)
	var blocked_starter_director := CapsuleDropDirector.new(29, 1, 64, true)
	var blocked_starter_drops := 0
	for break_number in range(1, 13):
		var blocked_starter_snapshot := CapsuleDropDirector.DropSnapshot.new(
			64 - break_number,
			0,
			starter_mask,
			3,
			1
		)
		if blocked_starter_director.on_brick_destroyed(blocked_starter_snapshot) >= 0:
			blocked_starter_drops += 1
	_check(
		blocked_starter_drops == 0,
		"The beginner pool waits while all starter effects are active."
	)
	var resumed_starter := blocked_starter_director.on_brick_destroyed(
		CapsuleDropDirector.DropSnapshot.new(51, 0, 0, 3, 1)
	)
	_check(
		resumed_starter in [
			PowerUp.PowerType.WIDE,
			PowerUp.PowerType.SLOW,
			PowerUp.PowerType.MULTI,
		],
		"The guaranteed beginner drop resumes when a starter effect becomes useful."
	)

	var all_persistent_mask := 0
	for active_type in [
		PowerUp.PowerType.WIDE,
		PowerUp.PowerType.SLOW,
		PowerUp.PowerType.MULTI,
		PowerUp.PowerType.CATCH,
		PowerUp.PowerType.LASER,
		PowerUp.PowerType.THRU,
	]:
		all_persistent_mask |= 1 << active_type
	var exhausted_pool_director := CapsuleDropDirector.new(19, 1, 64, false)
	var exhausted_pool_types: Array[int] = []
	var exhausted_pool_positions: Array[int] = []
	for break_number in range(1, 41):
		var exhausted_snapshot := CapsuleDropDirector.DropSnapshot.new(
			64 - break_number,
			0,
			all_persistent_mask,
			3,
			1
		)
		var exhausted_type := exhausted_pool_director.on_brick_destroyed(
			exhausted_snapshot
		)
		if exhausted_type >= 0:
			exhausted_pool_types.append(exhausted_type)
			exhausted_pool_positions.append(break_number)
			if exhausted_pool_types.size() == 2:
				break
	_check(
		exhausted_pool_types == [
			PowerUp.PowerType.EXTRA_BALL,
			PowerUp.PowerType.BREAK,
		],
		"An exhausted type pool waits for the next useful capsule."
	)
	_check(
		exhausted_pool_positions[1] == 32,
		"Pity remains guaranteed when Break becomes eligible."
	)

	var total_stage_runs := 0
	var total_drops := 0
	var total_density := 0.0
	var capped_stage_runs := 0
	var player_drops := 0
	var stages_with_break := 0
	var opening_violations := 0
	var budget_violations := 0
	var gap_violations := 0
	var repeat_violations := 0
	for run_seed in range(10000):
		for stage_number in range(1, LevelCatalog.STAGE_COUNT + 1):
			var destructible_count := _get_destructible_layout_count(stage_number)
			var simulation := _simulate_capsule_stage(
				run_seed,
				stage_number,
				destructible_count,
				stage_number == 1
			)
			var positions: Array = simulation.positions
			var types: Array = simulation.types
			var budget := CapsuleDropDirector.calculate_budget(destructible_count)
			total_stage_runs += 1
			total_drops += types.size()
			total_density += float(types.size()) / destructible_count
			capped_stage_runs += 1 if types.size() == budget else 0
			var stage_has_break := false

			if positions[0] < 3 or positions[0] > 6:
				opening_violations += 1
			if types.size() > budget:
				budget_violations += 1
			for drop_index in range(types.size()):
				var power_type: int = types[drop_index]
				player_drops += 1 if power_type == PowerUp.PowerType.EXTRA_BALL else 0
				stage_has_break = stage_has_break or power_type == PowerUp.PowerType.BREAK
				if drop_index == 0:
					continue
				var gap: int = positions[drop_index] - positions[drop_index - 1]
				if gap < 3 or gap > 10:
					gap_violations += 1
				if types[drop_index] == types[drop_index - 1]:
					repeat_violations += 1
			stages_with_break += 1 if stage_has_break else 0

	var mean_drops := float(total_drops) / total_stage_runs
	var mean_density := total_density / total_stage_runs
	var cap_rate := float(capped_stage_runs) / total_stage_runs
	var mean_player_drops := float(player_drops) / total_stage_runs
	var break_stage_rate := float(stages_with_break) / total_stage_runs
	print(
		"Capsule simulation: %.3f drops/stage, %.3f%% density, %.2f%% caps."
		% [mean_drops, mean_density * 100.0, cap_rate * 100.0]
	)
	_check(
		opening_violations == 0,
		"Every simulated stage rewards its first 3-6 eligible breaks."
	)
	_check(budget_violations == 0, "Capsule simulations never exceed the stage budget.")
	_check(gap_violations == 0, "Drop gaps stay inside the cooldown and pity bounds.")
	_check(repeat_violations == 0, "Capsule types never repeat immediately.")
	_check(
		mean_drops >= 5.3 and mean_drops <= 5.7,
		"Campaign simulations average 5.3-5.7 capsule drops per stage."
	)
	_check(
		mean_density >= 0.115 and mean_density <= 0.128,
		"Campaign simulations keep mean capsule density near 12%."
	)
	_check(
		cap_rate >= 0.80 and cap_rate <= 0.90,
		"Most, but not all, simulated stages exhaust their capsule budget."
	)
	_check(mean_player_drops <= 0.4, "Player capsules remain below 0.4 spawns per stage.")
	_check(break_stage_rate <= 0.08, "Break appears in no more than 8% of simulated stages.")


func _test_dynamic_power_up_flow() -> void:
	GameSession.new_game(1, 4242)
	var gameplay: Gameplay = GAMEPLAY_SCENE.instantiate()
	get_tree().root.add_child(gameplay)
	await get_tree().process_frame

	var destroyed_bricks := 0
	while gameplay.power_ups.get_child_count() == 0 and destroyed_bricks < 6:
		var target := gameplay.level.bricks.get_child(0) as Brick
		target.hit()
		destroyed_bricks += 1
		await get_tree().process_frame

	_check(
		destroyed_bricks >= 3 and destroyed_bricks <= 6,
		"Gameplay spawns the first capsule within 3-6 brick breaks."
	)
	_check(gameplay.power_ups.get_child_count() == 1, "A drop decision spawns one falling capsule.")
	var chip := gameplay.power_ups.get_child(0) as PowerUp
	_check(
		chip.power_type in [
			PowerUp.PowerType.WIDE,
			PowerUp.PowerType.SLOW,
			PowerUp.PowerType.MULTI,
		],
		"The first gameplay capsule uses the beginner pool."
	)
	_check(
		not GameSession.starter_capsule_pending,
		"Spawning the first gameplay capsule consumes the run-level beginner reward."
	)
	var score_before_pickup := GameSession.score
	var collected_type := chip.power_type
	chip.collect(gameplay.paddle)
	await get_tree().process_frame
	_check(
		GameSession.score == score_before_pickup + Gameplay.POWER_UP_SCORE,
		"Collecting a dynamic capsule awards 100 points."
	)
	_check(
		gameplay.has_active_power_up(collected_type),
		"The dynamically selected capsule applies its gameplay effect."
	)

	for active_ball in gameplay._get_balls():
		active_ball.deactivate()
	gameplay.queue_free()
	await get_tree().process_frame
	GameSession.new_game()


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
			_effect_color: Color
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
			_effect_color: Color
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


func _test_thru_physics() -> void:
	var silver_world := Node2D.new()
	var silver_brick: Brick = BRICK_SCENE.instantiate()
	var silver_ball: BreakerBall = BALL_SCENE.instantiate()
	silver_brick.hit_points = 3
	silver_brick.position = Vector2(100, 100)
	silver_ball.position = Vector2(72, 100)
	silver_world.add_child(silver_brick)
	silver_world.add_child(silver_ball)
	get_tree().root.add_child(silver_world)
	await get_tree().process_frame

	silver_ball.set_piercing(true)
	await get_tree().process_frame
	_check(
		not silver_ball.get_collision_mask_value(4),
		"Thru disables physical collisions with destructible bricks."
	)
	silver_ball.launch_in_direction(Vector2.RIGHT)
	for physics_step in range(12):
		await get_tree().physics_frame
	_check(
		silver_brick.hit_points == 2,
		"Thru damages Silver once per pass (remaining hits: %d)." % silver_brick.hit_points
	)
	_check(silver_ball.velocity.x > 0.0, "Thru does not bounce off Silver.")
	_check_ball_motion_invariant(silver_ball, "Thru Silver pass")
	silver_world.queue_free()
	await get_tree().process_frame

	var gold_world := Node2D.new()
	var gold_brick: Brick = BRICK_SCENE.instantiate()
	var gold_ball: BreakerBall = BALL_SCENE.instantiate()
	gold_brick.indestructible = true
	gold_brick.position = Vector2(100, 100)
	gold_ball.position = Vector2(72, 100)
	gold_world.add_child(gold_brick)
	gold_world.add_child(gold_ball)
	get_tree().root.add_child(gold_world)
	await get_tree().process_frame

	gold_ball.set_piercing(true)
	await get_tree().process_frame
	gold_ball.launch_in_direction(Vector2.RIGHT)
	for physics_step in range(12):
		await get_tree().physics_frame
	_check(is_instance_valid(gold_brick), "Thru never destroys Gold.")
	_check(gold_ball.velocity.x < 0.0, "Gold remains solid while Thru is active.")
	_check_ball_motion_invariant(gold_ball, "Thru Gold collision")
	gold_world.queue_free()
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
	for child in level.bricks.get_children():
		var brick := child as Brick
		total_score += brick.score

	_check(total_score == 5650, "The rainbow gate has the expected score value.")
	_check(_brick_score_at(level, Vector2(64, 52)) == 90, "The red crown is present.")
	_check(_brick_score_at(level, Vector2(48, 62)) == 60, "The orange row is present.")
	_check(_brick_score_at(level, Vector2(32, 72)) == 120, "The yellow split row is present.")
	_check(_brick_score_at(level, Vector2(48, 82)) == 80, "The green row is present.")
	_check(_brick_score_at(level, Vector2(64, 92)) == 70, "The light-blue row is present.")
	_check(_brick_score_at(level, Vector2(48, 102)) == 100, "The blue clusters are present.")
	_check(_brick_score_at(level, Vector2(80, 112)) == 110, "The magenta foundation is present.")
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
			_effect_color: Color
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


func _test_ball_direction_invariant() -> void:
	var world := Node2D.new()
	var unsafe_up: BreakerBall = BALL_SCENE.instantiate()
	var unsafe_down: BreakerBall = BALL_SCENE.instantiate()
	var safe_ball: BreakerBall = BALL_SCENE.instantiate()
	var horizontal_ball: BreakerBall = BALL_SCENE.instantiate()
	world.add_child(unsafe_up)
	world.add_child(unsafe_down)
	world.add_child(safe_ball)
	world.add_child(horizontal_ball)
	get_tree().root.add_child(world)
	await get_tree().process_frame

	unsafe_up.launch_in_direction(Vector2(1.0, -0.01))
	unsafe_down.launch_in_direction(Vector2(1.0, 0.01))
	safe_ball.launch_in_direction(Vector2(0.8, -0.6))
	horizontal_ball.launch_in_direction(Vector2.RIGHT)

	var upward_direction := unsafe_up.velocity.normalized()
	var downward_direction := unsafe_down.velocity.normalized()
	_check(
		is_equal_approx(
			absf(upward_direction.y),
			BreakerBall.MIN_VERTICAL_COMPONENT
		),
		"An unsafe upward trajectory receives the minimum vertical component."
	)
	_check(
		is_equal_approx(upward_direction.y, -downward_direction.y)
		and is_equal_approx(upward_direction.x, downward_direction.x),
		"Minimum-angle correction is symmetrical upward and downward."
	)
	_check(
		upward_direction.x > 0.0
		and upward_direction.y < 0.0
		and downward_direction.y > 0.0,
		"Minimum-angle correction preserves horizontal and vertical signs."
	)
	_check(
		safe_ball.velocity.normalized().is_equal_approx(Vector2(0.8, -0.6)),
		"Already-safe normalized trajectories remain unchanged."
	)
	_check(
		horizontal_ball.velocity.x > 0.0
		and is_equal_approx(
			horizontal_ball.velocity.normalized().y,
			-BreakerBall.MIN_VERTICAL_COMPONENT
		),
		"An exactly horizontal launch deterministically escapes upward."
	)
	_check_ball_motion_invariant(unsafe_up, "Corrected upward launch")
	_check_ball_motion_invariant(unsafe_down, "Corrected downward launch")

	world.queue_free()
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
		PowerUp.PowerType.THRU: "T",
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
	var down_event := InputEventAction.new()
	down_event.action = "ui_down"
	down_event.pressed = true
	var up_event := InputEventAction.new()
	up_event.action = "ui_up"
	up_event.pressed = true

	var game_over: GameOverScreen = GAME_OVER_SCENE.instantiate()
	var retry_requested := [false]
	game_over.new_game_requested.connect(func() -> void: retry_requested[0] = true)
	get_tree().root.add_child(game_over)
	game_over._unhandled_input(down_event)
	_check(
		game_over.get_selected_index() == 1,
		"Game Over exposes Share on Twitter as a second action."
	)
	_check(
		game_over.call("_get_option_label", 1) == "SHARE ON TWITTER",
		"The Twitter share action is explicit."
	)
	game_over._unhandled_input(up_event)
	game_over._unhandled_input(fire_event)
	_check(retry_requested[0], "FIRE retries from Game Over.")
	game_over.queue_free()
	await get_tree().process_frame

	GameSession.new_game(2)
	var intermediate_clear: StageClearScreen = STAGE_CLEAR_SCENE.instantiate()
	get_tree().root.add_child(intermediate_clear)
	await get_tree().process_frame
	_check(
		intermediate_clear.call("_option_count") == 1,
		"Intermediate stage clear does not offer terminal score sharing."
	)
	_check(
		intermediate_clear.get("_score_status").is_empty(),
		"Intermediate stage clear does not claim the score was persisted."
	)
	intermediate_clear.queue_free()
	await get_tree().process_frame

	var stage_clear: StageClearScreen = STAGE_CLEAR_SCENE.instantiate()
	var replay_requested := [false]
	GameSession.new_game(LevelCatalog.STAGE_COUNT)
	stage_clear.replay_requested.connect(func() -> void: replay_requested[0] = true)
	get_tree().root.add_child(stage_clear)
	stage_clear._unhandled_input(down_event)
	_check(
		stage_clear.get_selected_index() == 1,
		"Campaign Clear exposes Share on Twitter."
	)
	stage_clear._unhandled_input(up_event)
	stage_clear._unhandled_input(fire_event)
	_check(replay_requested[0], "FIRE replays from Stage Clear.")
	stage_clear.queue_free()
	await get_tree().process_frame


func _test_score_storage_failure() -> void:
	var original_handle := PlayerProfile.player_name
	var storage_fails := [true]
	Leaderboard.set_state_writer_for_tests(
		func(_state: Dictionary) -> bool:
			return not storage_fails[0]
	)
	PlayerProfile.player_name = "FAILTEST"

	var main := MAIN_SCENE.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	GameSession.award(100)
	main.call("_finish_run", "game_over")
	await get_tree().process_frame

	var game_over := main.find_child(
		"GameOver",
		true,
		false
	) as GameOverScreen
	_check(game_over != null, "A save failure still presents the terminal score.")
	_check(
		game_over.get("_score_status") == "SCORE NOT SAVED - RETRY",
		"Local save failure replaces success-shaped score status."
	)
	_check(
		game_over.call("_get_option_label", 1) == "RETRY SAVE",
		"Local save failure exposes a deterministic recovery action."
	)

	storage_fails[0] = false
	game_over.set("_selected_index", 1)
	game_over.call("_activate_selected")
	_check(
		game_over.get("_score_status") == "SAVED ON THIS DEVICE",
		"Retry Save confirms persistence only after storage recovers."
	)

	main.queue_free()
	await get_tree().process_frame
	Leaderboard.set_state_writer_for_tests(Callable())
	PlayerProfile.player_name = original_handle
	GameSession.new_game()


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
		RetroHud.LAUNCH_PROMPT == "Press SPACEBAR or tap to fire",
		"The launch advice names keyboard and touch actions."
	)
	var launch_event := InputEventAction.new()
	launch_event.action = "launch"
	launch_event.pressed = true
	gameplay._unhandled_input(launch_event)
	_check(gameplay.ball.is_active(), "The Gameplay input seam launches a held ball.")
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
	_check_ball_motion_invariant(
		paddle_gameplay.ball,
		"Real paddle collision"
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
	_check_ball_motion_invariant(gameplay.ball, "Paddle-wall edge escape")

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

	gameplay.apply_power_up(PowerUp.PowerType.WIDE)
	_check(gameplay.paddle.paddle_width == 56.0, "Wide enlarges the paddle.")
	_check(
		gameplay.has_active_power_up(PowerUp.PowerType.WIDE),
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
	_check(
		gameplay.paddle.paddle_width == 56.0,
		"Slow complements Wide instead of replacing it."
	)
	_check(
		gameplay.has_active_power_up(PowerUp.PowerType.WIDE)
		and gameplay.has_active_power_up(PowerUp.PowerType.SLOW),
		"Wide and Slow remain active together."
	)

	gameplay.apply_power_up(PowerUp.PowerType.CATCH)
	_check(gameplay.paddle.catch_enabled, "Catch enables the paddle catch surface.")
	_check(gameplay.paddle.paddle_width == 56.0, "Catch complements Wide.")

	gameplay.ball.reset_for_serve(gameplay.paddle)
	gameplay._apply_active_ball_effects(gameplay.ball)
	gameplay.ball.global_position = Vector2(128, 208)
	gameplay.ball.launch_in_direction(Vector2.DOWN)
	for physics_step in range(8):
		await get_tree().physics_frame
	_check(not gameplay.ball.is_active(), "Catch holds a returning ball.")
	_check(
		gameplay.ball.global_position == Vector2(128, 212),
		"Catch docks the held ball above the paddle."
	)

	gameplay.apply_power_up(PowerUp.PowerType.LASER)
	_check(gameplay.paddle.laser_enabled, "Laser equips the paddle emitters.")
	_check(gameplay.paddle.catch_enabled, "Laser complements Catch.")
	_check(
		gameplay.hud.get_power_up_label() == Gameplay.LASER_TIP,
		"Laser collection shows the keyboard and touch firing tip."
	)
	_check(
		is_equal_approx(gameplay.hud.get_power_up_time_left(), 3.0),
		"Laser usage tip remains visible for three seconds."
	)
	var fire_event := InputEventAction.new()
	fire_event.action = "launch"
	fire_event.pressed = true
	gameplay._unhandled_input(fire_event)
	_check(gameplay.ball.is_active(), "FIRE releases a caught ball while Laser is active.")
	_check(gameplay.lasers.get_child_count() == 2, "The same FIRE press launches a paired shot.")
	gameplay._clear_lasers()

	gameplay.apply_power_up(PowerUp.PowerType.THRU)
	await get_tree().process_frame
	_check(gameplay.ball.is_piercing(), "Thru enables piercing on the active ball.")
	_check(gameplay.paddle.laser_enabled, "Thru complements Laser.")
	_check(gameplay.paddle.catch_enabled, "Thru complements Catch.")
	_check(gameplay.paddle.paddle_width == 56.0, "Thru preserves Wide.")
	_check(gameplay.ball.speed == 150.0, "Thru preserves Slow.")

	gameplay.apply_power_up(PowerUp.PowerType.MULTI)
	_check(gameplay.balls.get_child_count() == 3, "Disruption creates three active balls.")
	for active_ball in gameplay.balls.get_children():
		var split_ball := active_ball as BreakerBall
		_check(split_ball.speed == 150.0, "Disruption balls inherit Slow.")
		_check(split_ball.is_piercing(), "Disruption balls inherit Thru.")

	var score_before_extra := GameSession.score
	gameplay.apply_power_up(PowerUp.PowerType.EXTRA_BALL)
	_check(GameSession.balls_remaining == 4, "Player increments the life counter.")
	_check(
		GameSession.score == score_before_extra + Gameplay.POWER_UP_SCORE,
		"Every collected power-up awards 100 points."
	)
	_check(
		gameplay.get_active_power_ups().size() == 6,
		"Immediate Player leaves all six complementary effects active."
	)

	var lost_ball := gameplay.balls.get_child(1) as BreakerBall
	gameplay._on_death_zone_body_entered(lost_ball)
	await get_tree().process_frame
	_check(gameplay.balls.get_child_count() == 2, "Losing one split ball keeps play active.")
	_check(GameSession.balls_remaining == 4, "A partial split-ball loss costs no life.")
	_check(
		gameplay.has_active_power_up(PowerUp.PowerType.MULTI),
		"Disruption remains active while another split ball survives."
	)
	gameplay.apply_power_up(PowerUp.PowerType.MULTI)
	await get_tree().process_frame
	_check(
		gameplay.balls.get_child_count() == 2,
		"Collecting duplicate Disruption does not refill a lost split ball."
	)

	var second_lost_ball := gameplay.balls.get_child(1) as BreakerBall
	gameplay._on_death_zone_body_entered(second_lost_ball)
	await get_tree().process_frame
	_check(gameplay.balls.get_child_count() == 1, "A second split-ball loss leaves one ball.")
	_check(
		not gameplay.has_active_power_up(PowerUp.PowerType.MULTI),
		"Disruption ends naturally when only one ball remains."
	)
	_check(
		gameplay.get_active_power_ups().size() == 5,
		"Disruption ending preserves every other complementary effect."
	)
	_check(gameplay.ball.speed == 150.0, "Slow survives the end of Disruption.")
	_check(gameplay.ball.is_piercing(), "Thru survives the end of Disruption.")
	_check(
		gameplay.paddle.catch_enabled
		and gameplay.paddle.laser_enabled
		and gameplay.paddle.paddle_width == 56.0,
		"Wide, Catch, and Laser survive the end of Disruption."
	)

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

	gameplay.ball.reset_for_serve(gameplay.paddle)
	gameplay._apply_active_ball_effects(gameplay.ball)
	await get_tree().process_frame

	var bricks_before_thru := gameplay.level.get_brick_count()
	gameplay.ball.global_position = Vector2(50, 52)
	gameplay.ball.launch_in_direction(Vector2(1.0, 0.625))
	for physics_step in range(35):
		await get_tree().physics_frame
	await get_tree().process_frame
	_check(
		gameplay.level.get_brick_count() <= bricks_before_thru - 4,
		"Thru destroys several colored bricks in one traversal (%d removed)."
		% (bricks_before_thru - gameplay.level.get_brick_count())
	)
	_check(
		gameplay.ball.velocity.x > 0.0,
		"Thru keeps traveling forward through destructible bricks."
	)

	gameplay.apply_power_up(PowerUp.PowerType.WIDE)
	await get_tree().process_frame
	_check(gameplay.ball.is_piercing(), "Collecting duplicate Wide does not clear Thru.")
	_check(gameplay.paddle.laser_enabled, "Collecting duplicate Wide does not clear Laser.")

	var break_requested := [false]
	gameplay.stage_clear_requested.connect(
		func() -> void:
			break_requested[0] = true
	)
	gameplay.apply_power_up(PowerUp.PowerType.BREAK)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(break_requested[0], "Break immediately requests the next stage.")
	_check(gameplay.get_active_power_ups().is_empty(), "Stage clear removes all active effects.")
	_check(not gameplay.ball.is_piercing(), "Stage clear removes Thru piercing.")
	_check(gameplay.ball.speed == BreakerBall.BASE_SPEED, "Stage clear removes Slow.")
	_check(
		gameplay.paddle.paddle_width == PaddleController.STANDARD_WIDTH,
		"Stage clear removes Wide."
	)
	_check(
		not gameplay.paddle.catch_enabled and not gameplay.paddle.laser_enabled,
		"Stage clear removes Catch and Laser."
	)

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
	var drop_director_id := gameplay._drop_director.get_instance_id()
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
	gameplay.apply_power_up(PowerUp.PowerType.SLOW)
	gameplay.apply_power_up(PowerUp.PowerType.CATCH)
	gameplay.apply_power_up(PowerUp.PowerType.LASER)
	gameplay.apply_power_up(PowerUp.PowerType.THRU)
	preserved_score = GameSession.score
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
		gameplay._drop_director.get_instance_id() == drop_director_id,
		"Life loss preserves capsule budget and pity state."
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
	_check(GameSession.score == preserved_score, "Score persists after life loss.")
	_check(GameSession.balls_remaining == 2, "Life loss consumes exactly one ball.")
	_check(gameplay.paddle.paddle_width == 40.0, "Life loss resets Wide.")
	_check(gameplay.ball.speed == BreakerBall.BASE_SPEED, "Life loss resets Slow speed.")
	_check(not gameplay.ball.is_piercing(), "Life loss resets Thru.")
	_check(
		not gameplay.paddle.catch_enabled and not gameplay.paddle.laser_enabled,
		"Life loss resets Catch and Laser."
	)
	_check(gameplay.get_active_power_ups().is_empty(), "Life loss clears all active effects.")
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
		gameplay.get_active_power_ups().is_empty(),
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
	_check_ball_motion_invariant(gameplay.ball, "Real wall collision")

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
	_check_ball_motion_invariant(gameplay.ball, "Real brick collision")

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


func _simulate_capsule_stage(
	run_seed: int,
	stage_number: int,
	destructible_brick_count: int,
	starter_pool_pending: bool
) -> Dictionary:
	var director := CapsuleDropDirector.new(
		run_seed,
		stage_number,
		destructible_brick_count,
		starter_pool_pending
	)
	var positions: Array[int] = []
	var types: Array[int] = []
	for break_number in range(1, destructible_brick_count + 1):
		var snapshot := CapsuleDropDirector.DropSnapshot.new(
			destructible_brick_count - break_number,
			0,
			0,
			GameSessionState.STARTING_BALLS,
			1
		)
		var power_type := director.on_brick_destroyed(snapshot)
		if power_type < 0:
			continue
		positions.append(break_number)
		types.append(power_type)

	return {
		"positions": positions,
		"types": types,
	}


func _get_destructible_layout_count(stage_number: int) -> int:
	var count := 0
	for row in LevelCatalog.get_layout(stage_number):
		for character in row:
			if character != " " and character != "X":
				count += 1
	return count


func _calculate_campaign_score_ceilings() -> Array[int]:
	var total := 0
	var ceilings: Array[int] = []
	for stage_number in range(1, LevelCatalog.STAGE_COUNT + 1):
		var destructible_bricks := 0
		for row in LevelCatalog.get_layout(stage_number):
			for code in row:
				if code == " ":
					continue
				var definition := BrickRules.get_definition(
					code,
					stage_number
				)
				if definition.indestructible:
					continue
				destructible_bricks += 1
				total += int(definition.score)
		total += (
			CapsuleDropDirector.calculate_budget(destructible_bricks)
			* Gameplay.POWER_UP_SCORE
		)
		ceilings.append(total)
	return ceilings


func _find_power_up_brick(level: Level01, power_type: int) -> Brick:
	for child in level.bricks.get_children():
		var brick := child as Brick
		if brick.power_up_type == power_type:
			return brick
	return null


func _community_level_fixture() -> Dictionary:
	return {
		"id": "cl_0123456789abcdef01234567",
		"schema_version": 1,
		"level_name": "NEON TEST",
		"creator_display_name": "@BUILDER",
		"layout": [
			"WWWWWWWW.....",
			".............",
			".............",
			".............",
			".............",
			".............",
			".............",
			".............",
			".............",
			".............",
		],
		"status": "pending",
		"populated_count": 8,
		"created_at": "2026-08-23T22:00:00Z",
	}


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
		return

	_failures += 1
	push_error("FAIL: %s" % message)


func _check_ball_motion_invariant(ball: BreakerBall, context: String) -> void:
	var travel_direction := ball.velocity.normalized()
	_check(
		is_equal_approx(ball.velocity.length(), ball.speed),
		"%s preserves configured speed." % context
	)
	_check(
		absf(travel_direction.y) >= BreakerBall.MIN_VERTICAL_COMPONENT,
		"%s preserves the minimum vertical angle." % context
	)


func _signed_pcm_mean(data: PackedByteArray) -> float:
	if data.is_empty():
		return 0.0

	var total := 0.0
	for encoded_byte in data:
		total += Pcm8.decode(encoded_byte)
	return total / data.size()
