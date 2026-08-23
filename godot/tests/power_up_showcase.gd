extends Node2D

const POWER_UP_SCENE: PackedScene = preload(
	"res://scenes/entities/power_up.tscn"
)

@onready var gameplay: Gameplay = $Gameplay


func _ready() -> void:
	var types := [
		PowerUp.PowerType.WIDE,
		PowerUp.PowerType.SLOW,
		PowerUp.PowerType.MULTI,
		PowerUp.PowerType.EXTRA_BALL,
	]

	for type_index in range(types.size()):
		var power_up: PowerUp = POWER_UP_SCENE.instantiate()
		power_up.configure(types[type_index])
		power_up.fall_speed = 0.0
		gameplay.power_ups.add_child(power_up)
		power_up.global_position = Vector2(92 + type_index * 24, 174)

