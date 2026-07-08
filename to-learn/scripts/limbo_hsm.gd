extends LimboHSM

@export var Character : CharacterBody2D

func _ready() -> void:
	initialize(Character)
	set_active(true)
	
