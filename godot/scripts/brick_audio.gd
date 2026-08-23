class_name BrickAudio
extends Node

const REGULAR_PITCH_VARIANTS := [0.90, 0.95, 1.0, 1.06, 1.12]
const DURABLE_PITCH_VARIANTS := [1.18, 1.25, 1.32, 1.40]
const INDESTRUCTIBLE_PITCH_VARIANTS := [0.68, 0.74, 0.80]

static var _last_regular_pitch_index := -1
static var _last_durable_pitch_index := -1
static var _last_indestructible_pitch_index := -1

var _regular_stream: AudioStreamWAV
var _durable_stream: AudioStreamWAV
var _indestructible_stream: AudioStreamWAV
var _last_pitch := 1.0
var _hit_count := 0
var _last_hit_kind := Brick.HitKind.REGULAR


func _ready() -> void:
	_regular_stream = _create_hit_sound(Brick.HitKind.REGULAR)
	_durable_stream = _create_hit_sound(Brick.HitKind.DURABLE)
	_indestructible_stream = _create_hit_sound(
		Brick.HitKind.INDESTRUCTIBLE
	)


func play_hit(hit_kind: int = Brick.HitKind.REGULAR) -> void:
	if _regular_stream == null:
		_regular_stream = _create_hit_sound(Brick.HitKind.REGULAR)
	if _durable_stream == null:
		_durable_stream = _create_hit_sound(Brick.HitKind.DURABLE)
	if _indestructible_stream == null:
		_indestructible_stream = _create_hit_sound(
			Brick.HitKind.INDESTRUCTIBLE
		)

	var pitch_variants := _get_pitch_variants(hit_kind)
	var previous_pitch_index := _get_last_pitch_index(hit_kind)
	var pitch_index := randi_range(0, pitch_variants.size() - 1)
	if pitch_index == previous_pitch_index:
		pitch_index = (
			pitch_index + randi_range(1, pitch_variants.size() - 1)
		) % pitch_variants.size()
	_set_last_pitch_index(hit_kind, pitch_index)
	_last_pitch = pitch_variants[pitch_index]
	_last_hit_kind = hit_kind
	_hit_count += 1

	var player := AudioStreamPlayer.new()
	player.stream = _get_stream(hit_kind)
	player.pitch_scale = _last_pitch
	add_child(player)
	player.finished.connect(_on_player_finished.bind(player))
	player.play()


func get_last_pitch() -> float:
	return _last_pitch


func get_hit_count() -> int:
	return _hit_count


func get_last_hit_kind() -> int:
	return _last_hit_kind


func get_regular_stream() -> AudioStreamWAV:
	return _regular_stream


func get_durable_stream() -> AudioStreamWAV:
	return _durable_stream


func get_indestructible_stream() -> AudioStreamWAV:
	return _indestructible_stream


func _on_player_finished(player: AudioStreamPlayer) -> void:
	player.stream = null
	player.queue_free()


func _create_hit_sound(hit_kind: int) -> AudioStreamWAV:
	const SAMPLE_RATE := 11025
	var sound_duration := 0.10
	if hit_kind == Brick.HitKind.DURABLE:
		sound_duration = 0.075
	elif hit_kind == Brick.HitKind.INDESTRUCTIBLE:
		sound_duration = 0.14
	var sample_count := floori(SAMPLE_RATE * sound_duration)
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count)

	for sample_index in range(sample_count):
		var time := float(sample_index) / SAMPLE_RATE
		var progress := time / sound_duration
		var frequency := lerpf(860.0, 260.0, progress)
		var duty_cycle := 0.5
		if hit_kind == Brick.HitKind.DURABLE:
			frequency = lerpf(1420.0, 620.0, progress)
			duty_cycle = 0.25
		elif hit_kind == Brick.HitKind.INDESTRUCTIBLE:
			frequency = lerpf(320.0, 110.0, progress)
			duty_cycle = 0.5
		var square_wave := (
			1.0
			if fmod(time * frequency, 1.0) < duty_cycle
			else -1.0
		)
		var metallic_overtone := (
			sin(TAU * frequency * 2.5 * time) * 0.30
			if hit_kind == Brick.HitKind.DURABLE
			else 0.0
		)
		var stubborn_clunk := 0.0
		if hit_kind == Brick.HitKind.INDESTRUCTIBLE:
			var second_impact := (
				exp(-absf(progress - 0.38) * 45.0) * -0.55
			)
			stubborn_clunk = (
				sin(TAU * frequency * 0.5 * time) * 0.45
				+ second_impact
			)
		var grit := sin(float(sample_index) * 12.9898) * (
			0.08
			if hit_kind == Brick.HitKind.DURABLE
			else 0.14
		)
		var envelope := 1.0 - progress
		sample_data[sample_index] = Pcm8.encode(
			(
				square_wave
				+ metallic_overtone
				+ stubborn_clunk
				+ grit
			) * envelope,
			46.0
		)

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = sample_data
	return stream


func _get_pitch_variants(hit_kind: int) -> Array:
	match hit_kind:
		Brick.HitKind.DURABLE:
			return DURABLE_PITCH_VARIANTS
		Brick.HitKind.INDESTRUCTIBLE:
			return INDESTRUCTIBLE_PITCH_VARIANTS
		_:
			return REGULAR_PITCH_VARIANTS


func _get_last_pitch_index(hit_kind: int) -> int:
	match hit_kind:
		Brick.HitKind.DURABLE:
			return _last_durable_pitch_index
		Brick.HitKind.INDESTRUCTIBLE:
			return _last_indestructible_pitch_index
		_:
			return _last_regular_pitch_index


func _set_last_pitch_index(hit_kind: int, pitch_index: int) -> void:
	match hit_kind:
		Brick.HitKind.DURABLE:
			_last_durable_pitch_index = pitch_index
		Brick.HitKind.INDESTRUCTIBLE:
			_last_indestructible_pitch_index = pitch_index
		_:
			_last_regular_pitch_index = pitch_index


func _get_stream(hit_kind: int) -> AudioStreamWAV:
	match hit_kind:
		Brick.HitKind.DURABLE:
			return _durable_stream
		Brick.HitKind.INDESTRUCTIBLE:
			return _indestructible_stream
		_:
			return _regular_stream


func _exit_tree() -> void:
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	_regular_stream = null
	_durable_stream = null
	_indestructible_stream = null
