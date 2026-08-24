class_name Pcm8
extends RefCounted


static func encode(sample: float, amplitude: float = 127.0) -> int:
	var signed_value := clampi(
		roundi(clampf(sample, -1.0, 1.0) * amplitude),
		-128,
		127
	)
	return signed_value & 0xFF


static func decode(encoded_byte: int) -> int:
	var byte_value := encoded_byte & 0xFF
	return byte_value if byte_value < 128 else byte_value - 256

