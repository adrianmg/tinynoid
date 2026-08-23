class_name UiAudioControllerState
extends Node

const SAMPLE_RATE := 11025
const MOVE_DURATION := 0.045
const CONFIRM_DURATION := 0.13

var _move_stream: AudioStreamWAV
var _confirm_stream: AudioStreamWAV
var _move_player: AudioStreamPlayer
var _confirm_player: AudioStreamPlayer
var _move_count := 0
var _confirm_count := 0


func _ready() -> void:
	_move_stream = _create_move_stream()
	_confirm_stream = _create_confirm_stream()
	if DisplayServer.get_name().to_lower() == "headless":
		return

	_move_player = _create_player("MenuMove", _move_stream, -7.0)
	_confirm_player = _create_player("MenuConfirm", _confirm_stream, -5.0)


func play_move() -> void:
	_move_count += 1
	if is_instance_valid(_move_player):
		_move_player.play()


func play_confirm() -> void:
	_confirm_count += 1
	if is_instance_valid(_confirm_player):
		_confirm_player.play()


func get_move_stream() -> AudioStreamWAV:
	return _move_stream


func get_confirm_stream() -> AudioStreamWAV:
	return _confirm_stream


func get_move_count() -> int:
	return _move_count


func get_confirm_count() -> int:
	return _confirm_count


func _create_player(
	player_name: String,
	stream: AudioStreamWAV,
	volume_db: float
) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	return player


func _create_move_stream() -> AudioStreamWAV:
	var sample_count := roundi(SAMPLE_RATE * MOVE_DURATION)
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count)

	for sample_index in range(sample_count):
		var time := float(sample_index) / SAMPLE_RATE
		var progress := time / MOVE_DURATION
		var frequency := lerpf(780.0, 620.0, progress)
		var pulse := 1.0 if fmod(time * frequency, 1.0) < 0.25 else -1.0
		var envelope := 1.0 - progress
		sample_data[sample_index] = Pcm8.encode(
			pulse * envelope,
			42.0
		)

	return _create_stream(sample_data)


func _create_confirm_stream() -> AudioStreamWAV:
	var sample_count := roundi(SAMPLE_RATE * CONFIRM_DURATION)
	var sample_data := PackedByteArray()
	sample_data.resize(sample_count)

	for sample_index in range(sample_count):
		var time := float(sample_index) / SAMPLE_RATE
		var progress := time / CONFIRM_DURATION
		var frequency := 660.0 if progress < 0.48 else 990.0
		var note_progress := fmod(progress * 2.0, 1.0)
		var pulse := 1.0 if fmod(time * frequency, 1.0) < 0.5 else -1.0
		var envelope := 1.0 - note_progress * 0.65
		sample_data[sample_index] = Pcm8.encode(
			pulse * envelope,
			46.0
		)

	return _create_stream(sample_data)


func _create_stream(sample_data: PackedByteArray) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = sample_data
	return stream


func _exit_tree() -> void:
	for player in [_move_player, _confirm_player]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	_move_stream = null
	_confirm_stream = null
