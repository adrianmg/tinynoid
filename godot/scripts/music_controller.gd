class_name MusicControllerState
extends Node

const SAMPLE_RATE := 22050
const RUNTIME_BUFFER_LENGTH := 0.12
const OUTPUT_GAIN := 92.0 / 127.0
const LOOP_CROSSFADE_SAMPLES := 256
const STEPS_PER_BEAT := 4
const STEP_COUNT := 128
const VOICE_COUNT := 4
const MENU_TRACK_ID := 0
const STAGE_COUNT := 33
const PROGRESSIONS := [
	[48, 44, 51, 46],
	[45, 48, 43, 50],
	[50, 46, 53, 48],
	[43, 50, 46, 51],
	[47, 42, 49, 44],
	[52, 48, 55, 50],
]
const MENU_PROGRESSION := [45, 40, 43, 38]
const SCALES := [
	[0, 2, 3, 5, 7, 8, 10, 12],
	[0, 2, 3, 5, 7, 9, 10, 12],
	[0, 2, 4, 5, 7, 9, 11, 12],
	[0, 3, 5, 7, 10, 12, 15, 17],
]
const LEAD_DEGREES := [
	0, -1, 2, -1, 4, -1, 6, -1,
	4, -1, 2, -1, 0, -1, 1, -1,
]
const MENU_LEAD_DEGREES := [
	0, -1, -1, 4, -1, -1, 6, -1,
	5, -1, -1, 2, -1, -1, 4, -1,
	0, -1, 4, -1, 6, -1, 7, -1,
	5, -1, 2, -1, 1, -1, 0, -1,
]
const DUTY_CYCLES := [0.125, 0.25, 0.5]

var _player: AudioStreamPlayer
var _stream: AudioStreamWAV
var _generator: AudioStreamGenerator
var _playback: AudioStreamGeneratorPlayback
var _current_track_id := -1
var _peak_amplitude := 0.0
var _loop_duration := 0.0
var _track_cache := {}
var _last_switch_duration_usec := 0
var _runtime_config := {}
var _runtime_sample_cursor := 0
var _runtime_sample_count := 0


func _ready() -> void:
	if not _is_headless():
		_generator = AudioStreamGenerator.new()
		_generator.mix_rate = SAMPLE_RATE
		_generator.buffer_length = RUNTIME_BUFFER_LENGTH
		_player = _create_music_player()
		_player.stream = _generator
		add_child(_player)
		_player.play()
		_playback = (
			_player.get_stream_playback()
			as AudioStreamGeneratorPlayback
		)
	play_menu()


static func _create_music_player() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = "GeneratedMusic"
	player.volume_db = -10.0
	# Web sample playback cannot drive an AudioStreamGenerator.
	player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	return player


func _process(_delta: float) -> void:
	_fill_runtime_buffer()


func play_menu() -> void:
	_switch_track(MENU_TRACK_ID)


func play_stage(stage_number: int) -> void:
	assert(
		stage_number >= 1 and stage_number <= STAGE_COUNT,
		"Music stage is outside the campaign."
	)
	_switch_track(stage_number)


func is_playing() -> bool:
	return is_instance_valid(_player) and _player.playing


func get_loop_duration() -> float:
	return _loop_duration


func get_voice_count() -> int:
	return VOICE_COUNT


func get_stream() -> AudioStreamWAV:
	return _stream


func get_peak_amplitude() -> float:
	return _peak_amplitude


func get_current_track_id() -> int:
	return _current_track_id


func get_cached_track_count() -> int:
	return _track_cache.size()


func get_last_switch_duration_usec() -> int:
	return _last_switch_duration_usec


func get_runtime_sample_count(track_id: int) -> int:
	var config := _get_track_config(track_id)
	var step_duration: float = (
		60.0 / float(config.bpm) / STEPS_PER_BEAT
	)
	return roundi(
		SAMPLE_RATE * step_duration * STEP_COUNT
	)


func render_streaming_preview(
	track_id: int,
	frame_count: int,
	start_cursor: int = 0
) -> PackedFloat32Array:
	assert(frame_count >= 0, "Preview frame count cannot be negative.")
	var config := _get_track_config(track_id)
	var sample_count := get_runtime_sample_count(track_id)
	var preview := PackedFloat32Array()
	preview.resize(frame_count)

	for frame_index in range(frame_count):
		var cursor := posmod(
			start_cursor + frame_index,
			sample_count
		)
		preview[frame_index] = _render_track_sample(
			cursor,
			config,
			sample_count
		)

	return preview


func get_arrangement_signature(track_id: int) -> String:
	var config := _get_track_config(track_id)
	return "%02d:%03d:%d:%d:%d:%d:%d:%d" % [
		track_id,
		roundi(config.bpm),
		config.progression_index,
		config.scale_index,
		config.lead_rotation,
		config.duty_index,
		config.arp_direction,
		config.drum_variant,
	]


func shutdown() -> void:
	stop_for_shutdown()
	if is_instance_valid(_player):
		_player.stream = null
		if _player.get_parent() == self:
			remove_child(_player)
		_player.free()
		_player = null
	_playback = null
	_generator = null
	_stream = null
	_current_track_id = -1
	_track_cache.clear()
	_runtime_config.clear()
	_runtime_sample_cursor = 0
	_runtime_sample_count = 0


func stop_for_shutdown() -> void:
	set_process(false)
	if is_instance_valid(_player):
		_player.stop()


func _switch_track(track_id: int) -> void:
	var switch_started := Time.get_ticks_usec()
	if (
		track_id == _current_track_id
		and (_stream != null or not _is_headless())
	):
		if is_instance_valid(_player) and not _player.playing:
			_player.play()
		_last_switch_duration_usec = (
			Time.get_ticks_usec() - switch_started
		)
		return

	if not _is_headless():
		_switch_runtime_track(track_id)
		_last_switch_duration_usec = Time.get_ticks_usec() - switch_started
		return

	var cache_entry: Dictionary
	if _track_cache.has(track_id):
		cache_entry = _track_cache[track_id]
	else:
		var config := _get_track_config(track_id)
		var next_stream := _create_music_stream(config)
		cache_entry = {
			"stream": next_stream,
			"loop_duration": _loop_duration,
			"peak_amplitude": _peak_amplitude,
		}
		_track_cache[track_id] = cache_entry

	if is_instance_valid(_player):
		_player.stop()
		_player.stream = null

	_stream = cache_entry.stream
	_loop_duration = cache_entry.loop_duration
	_peak_amplitude = cache_entry.peak_amplitude
	_current_track_id = track_id

	if is_instance_valid(_player):
		_player.stream = _stream
		_player.play()

	_last_switch_duration_usec = Time.get_ticks_usec() - switch_started


func _switch_runtime_track(track_id: int) -> void:
	_runtime_config = _get_track_config(track_id)
	var step_duration: float = (
		60.0 / float(_runtime_config.bpm) / STEPS_PER_BEAT
	)
	_loop_duration = step_duration * STEP_COUNT
	_runtime_sample_count = roundi(SAMPLE_RATE * _loop_duration)
	_runtime_sample_cursor = 0
	_current_track_id = track_id

	if is_instance_valid(_playback):
		_fill_runtime_buffer()


func _fill_runtime_buffer() -> void:
	if (
		not is_instance_valid(_playback)
		or _runtime_config.is_empty()
		or _runtime_sample_count <= 0
	):
		return

	var available_frames := _playback.get_frames_available()
	for frame_index in range(available_frames):
		var sample := _render_runtime_sample(_runtime_sample_cursor)
		_playback.push_frame(
			Vector2(sample, sample) * OUTPUT_GAIN
		)
		_runtime_sample_cursor = (
			_runtime_sample_cursor + 1
		) % _runtime_sample_count


func _render_runtime_sample(sample_cursor: int) -> float:
	return _render_track_sample(
		sample_cursor,
		_runtime_config,
		_runtime_sample_count
	)


func _render_track_sample(
	sample_cursor: int,
	config: Dictionary,
	sample_count: int
) -> float:
	var step_duration: float = (
		60.0 / float(config.bpm) / STEPS_PER_BEAT
	)
	var time := float(sample_cursor) / SAMPLE_RATE
	var sample := _render_sample(
		sample_cursor,
		time,
		step_duration,
		config
	)
	var crossfade_start := (
		sample_count - LOOP_CROSSFADE_SAMPLES
	)

	if sample_cursor >= crossfade_start:
		var head_cursor := sample_cursor - crossfade_start
		var head_time := float(head_cursor) / SAMPLE_RATE
		var head_sample := _render_sample(
			head_cursor,
			head_time,
			step_duration,
			config
		)
		var blend := float(head_cursor + 1) / LOOP_CROSSFADE_SAMPLES
		sample = lerpf(sample, head_sample, blend)

	return sample


func _get_track_config(track_id: int) -> Dictionary:
	assert(
		track_id >= MENU_TRACK_ID and track_id <= STAGE_COUNT,
		"Unknown music track."
	)
	if track_id == MENU_TRACK_ID:
		return {
			"track_id": track_id,
			"bpm": 88.0,
			"progression_index": -1,
			"scale_index": 0,
			"lead_rotation": 0,
			"duty_index": 0,
			"arp_direction": 1,
			"drum_variant": 0,
			"bass_turnaround": 7,
			"noise_seed": 17,
			"lead_gain": 0.16,
			"arp_gain": 0.09,
			"bass_gain": 0.14,
			"drum_gain": 0.04,
			"relaxed": true,
		}

	return {
		"track_id": track_id,
		"bpm": float(138 + (track_id * 7) % 23),
		"progression_index": (track_id * 5 + 1) % PROGRESSIONS.size(),
		"scale_index": (track_id * 3 + 2) % SCALES.size(),
		"lead_rotation": (track_id * 5) % LEAD_DEGREES.size(),
		"duty_index": (track_id * 2 + 1) % DUTY_CYCLES.size(),
		"arp_direction": -1 if track_id % 2 == 0 else 1,
		"drum_variant": track_id % 4,
		"bass_turnaround": SCALES[
			(track_id * 3 + 2) % SCALES.size()
		][2 + track_id % 3],
		"noise_seed": track_id * 977 + 17,
		"lead_gain": 0.24,
		"arp_gain": 0.12,
		"bass_gain": 0.22,
		"drum_gain": 0.30,
		"relaxed": false,
	}


func _create_music_stream(config: Dictionary) -> AudioStreamWAV:
	var step_duration: float = (
		60.0 / float(config.bpm) / STEPS_PER_BEAT
	)
	_loop_duration = step_duration * STEP_COUNT
	var sample_count := roundi(SAMPLE_RATE * _loop_duration)
	var mixed_samples := PackedFloat32Array()
	mixed_samples.resize(sample_count)

	for sample_index in range(sample_count):
		var time := float(sample_index) / SAMPLE_RATE
		mixed_samples[sample_index] = _render_sample(
			sample_index,
			time,
			step_duration,
			config
		)

	for fade_index in range(LOOP_CROSSFADE_SAMPLES):
		var blend := float(fade_index + 1) / LOOP_CROSSFADE_SAMPLES
		var tail_index := (
			sample_count - LOOP_CROSSFADE_SAMPLES + fade_index
		)
		mixed_samples[tail_index] = lerpf(
			mixed_samples[tail_index],
			mixed_samples[fade_index],
			blend
		)

	var sample_data := PackedByteArray()
	sample_data.resize(sample_count)
	_peak_amplitude = 0.0

	for sample_index in range(sample_count):
		var sample := clampf(mixed_samples[sample_index], -1.0, 1.0)
		_peak_amplitude = maxf(_peak_amplitude, absf(sample))
		sample_data[sample_index] = Pcm8.encode(sample, 92.0)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = sample_count
	stream.data = sample_data
	return stream


func _render_sample(
	sample_index: int,
	time: float,
	step_duration: float,
	config: Dictionary
) -> float:
	var step_position := time / step_duration
	var step_index := floori(step_position) % STEP_COUNT
	var step_phase := fmod(step_position, 1.0)
	var bar_index := floori(float(step_index) / 16.0)
	var chord_index := bar_index % 4
	var step_in_bar := step_index % 16
	var progression: Array = (
		MENU_PROGRESSION
		if config.relaxed
		else PROGRESSIONS[config.progression_index]
	)
	var root_note: int = progression[chord_index]

	var lead := _render_lead(
		time,
		step_phase,
		root_note,
		step_in_bar,
		bar_index,
		config
	)
	var arpeggio := _render_arpeggio(
		time,
		step_phase,
		root_note,
		step_in_bar,
		config
	)
	var bass := _render_bass(
		time,
		step_position,
		root_note,
		step_in_bar,
		config
	)
	var drums := _render_drums(
		sample_index,
		step_phase,
		step_in_bar,
		bar_index,
		step_duration,
		config
	)

	return tanh(
		lead * float(config.lead_gain)
		+ arpeggio * float(config.arp_gain)
		+ bass * float(config.bass_gain)
		+ drums * float(config.drum_gain)
	)


func _render_lead(
	time: float,
	step_phase: float,
	root_note: int,
	step_in_bar: int,
	bar_index: int,
	config: Dictionary
) -> float:
	var lead_pattern: Array = (
		MENU_LEAD_DEGREES
		if config.relaxed
		else LEAD_DEGREES
	)
	var phrase_offset := 16 * (bar_index % 2) if config.relaxed else 0
	var pattern_index := posmod(
		step_in_bar + phrase_offset + config.lead_rotation,
		lead_pattern.size()
	)
	var degree: int = lead_pattern[pattern_index]
	if degree < 0:
		if config.drum_variant < 2 or step_in_bar % 4 != 3:
			return 0.0
		degree = (step_in_bar + bar_index) % 5

	var scale: Array = SCALES[config.scale_index]
	var note_offset: int = scale[degree % scale.size()]
	if bar_index >= 4 and step_in_bar == 12:
		note_offset += 12

	var frequency := _midi_to_frequency(root_note + 12 + note_offset)
	var attack_time := 0.20 if config.relaxed else 0.08
	var decay_power := 0.18 if config.relaxed else 0.55
	var attack := minf(step_phase / attack_time, 1.0)
	var decay := pow(1.0 - step_phase, decay_power)
	var primary := _pulse(
		frequency,
		time,
		DUTY_CYCLES[config.duty_index]
	) * attack * decay
	if not config.relaxed:
		return primary

	var fifth_frequency := _midi_to_frequency(
		root_note + 19 + note_offset
	)
	var shimmer := _pulse(
		fifth_frequency,
		time + 0.017,
		0.125
	) * attack * decay
	var drift := 0.88 + sin(TAU * time * 0.18) * 0.12
	return (primary * 0.82 + shimmer * 0.18) * drift


func _render_arpeggio(
	time: float,
	step_phase: float,
	root_note: int,
	step_in_bar: int,
	config: Dictionary
) -> float:
	if config.relaxed and step_in_bar % 4 != 0:
		return 0.0

	var scale: Array = SCALES[config.scale_index]
	var arp_degrees := [0, 2, 4, 6]
	var arp_index := (
		floori(float(step_in_bar) / 4.0)
		if config.relaxed
		else step_in_bar
	) % arp_degrees.size()
	if config.arp_direction < 0:
		arp_index = arp_degrees.size() - 1 - arp_index
	var interval: int = scale[arp_degrees[arp_index]]
	var frequency := _midi_to_frequency(root_note + 24 + interval)
	var envelope := pow(
		1.0 - step_phase,
		0.45 if config.relaxed else 1.7
	)
	var duty_index: int = (
		int(config.duty_index) + 1
	) % DUTY_CYCLES.size()
	return _pulse(
		frequency,
		time,
		DUTY_CYCLES[duty_index]
	) * envelope


func _render_bass(
	time: float,
	step_position: float,
	root_note: int,
	step_in_bar: int,
	config: Dictionary
) -> float:
	var bass_note := root_note - 12
	if step_in_bar >= 12:
		bass_note += config.bass_turnaround

	var frequency := _midi_to_frequency(bass_note)
	var beat_phase := fmod(step_position / 4.0, 1.0)
	var envelope := 0.72 + (1.0 - beat_phase) * 0.28
	return _triangle(frequency, time) * envelope


func _render_drums(
	sample_index: int,
	step_phase: float,
	step_in_bar: int,
	bar_index: int,
	step_duration: float,
	config: Dictionary
) -> float:
	var drums := 0.0
	if config.relaxed:
		if step_in_bar == 0 and bar_index % 2 == 0:
			var relaxed_kick_frequency := lerpf(105.0, 48.0, step_phase)
			var relaxed_kick_envelope := exp(-step_phase * 7.0)
			drums += sin(
				TAU
				* relaxed_kick_frequency
				* step_phase
				* step_duration
			) * relaxed_kick_envelope

		if step_in_bar == 8 and bar_index % 2 == 1:
			var relaxed_snare_envelope := exp(-step_phase * 9.0)
			drums += _noise(
				sample_index,
				config.noise_seed
			) * relaxed_snare_envelope * 0.55

		if step_in_bar == 0 or step_in_bar == 8:
			var relaxed_hat_envelope := exp(-step_phase * 15.0)
			drums += _noise(
				sample_index * 3 + 17,
				config.noise_seed
			) * relaxed_hat_envelope * 0.14

		return drums

	var kick_offset: int = config.drum_variant % 2
	var snare_offset: int = 0 if config.drum_variant < 2 else 2

	if (
		step_in_bar == kick_offset
		or step_in_bar == 8 + kick_offset
	):
		var kick_frequency := lerpf(120.0, 45.0, step_phase)
		var kick_envelope := exp(-step_phase * 8.0)
		drums += sin(
			TAU * kick_frequency * step_phase * step_duration
		) * kick_envelope

	if (
		step_in_bar == 4 + snare_offset
		or step_in_bar == 12 + snare_offset
	):
		var snare_envelope := exp(-step_phase * 10.0)
		drums += _noise(
			sample_index,
			config.noise_seed
		) * snare_envelope * 0.72

	var hat_spacing := 2 if config.drum_variant != 3 else 1
	if step_in_bar % hat_spacing == 0:
		var hat_envelope := exp(-step_phase * 18.0)
		drums += _noise(
			sample_index * 3 + 17,
			config.noise_seed
		) * hat_envelope * 0.24

	return drums


func _pulse(frequency: float, time: float, duty_cycle: float) -> float:
	return 1.0 if fmod(time * frequency, 1.0) < duty_cycle else -1.0


func _triangle(frequency: float, time: float) -> float:
	var phase := fmod(time * frequency, 1.0)
	return 4.0 * absf(phase - 0.5) - 1.0


func _noise(sample_index: int, seed: int) -> float:
	var hash := (
		sample_index * 1103515245 + seed * 12345
	) & 0x7fffffff
	return float(hash % 65536) / 32767.5 - 1.0


func _midi_to_frequency(note: int) -> float:
	return 440.0 * pow(2.0, float(note - 69) / 12.0)


func _is_headless() -> bool:
	return DisplayServer.get_name().to_lower() == "headless"


func _exit_tree() -> void:
	shutdown()
