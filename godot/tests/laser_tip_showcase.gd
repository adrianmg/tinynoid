extends Node2D

@onready var gameplay: Gameplay = $Gameplay


func _ready() -> void:
	gameplay.apply_power_up(PowerUp.PowerType.LASER)

