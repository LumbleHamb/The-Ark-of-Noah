extends Node2D
class_name VillageHouse

@export var house_anim_speed: float = 1.5
@export var smoke_anim_speed: float = 5.0

@onready var house_sprite: AnimatedSprite2D = $HouseSprite
@onready var smoke_sprite: AnimatedSprite2D = $SmokeSprite

func _ready() -> void:
	if house_sprite != null:
		house_sprite.speed_scale = house_anim_speed
		house_sprite.play(&"idle")
	if smoke_sprite != null:
		smoke_sprite.speed_scale = smoke_anim_speed
		smoke_sprite.play(&"smoke")
