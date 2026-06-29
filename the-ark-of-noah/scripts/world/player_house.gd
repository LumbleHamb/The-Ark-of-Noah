extends Node2D
class_name PlayerHouse

## Controls the player house open/close visual state and indoor/outdoor layering.

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var chimney_smoke: AnimatedSprite2D = $chimney_smoke
@onready var roof: AnimatedSprite2D = $roof
@onready var front_wall: Sprite2D = $front_wall
@onready var cabin_interior: Sprite2D = $CabinInterior
@onready var porch: Sprite2D = $porch
@onready var doorway: Area2D = $doorway

var _player_inside: bool = false

func _ready() -> void:
	_apply_layer_state(false)

func _on_doorway_body_entered(body: Node2D) -> void:
	if body == null:
		return
	if body.is_in_group(&"Player") or body.is_in_group(&"player"):
		_player_inside = true
		chimney_smoke.visible = false
		anim_player.play("open_house")
		_apply_layer_state(true)

func _on_doorway_body_exited(body: Node2D) -> void:
	if body == null:
		return
	if body.is_in_group(&"Player") or body.is_in_group(&"player"):
		_player_inside = false
		chimney_smoke.visible = true
		anim_player.play_backwards("open_house")
		_apply_layer_state(false)

func _apply_layer_state(player_inside: bool) -> void:
	# Outside: roof/front wall draw above player. Inside: reveal interior floor.
	if player_inside:
		if roof != null:
			roof.z_index = 0
		if front_wall != null:
			front_wall.visible = false
		if cabin_interior != null:
			cabin_interior.z_index = 2
		if porch != null:
			porch.z_index = 1
	else:
		if roof != null:
			roof.z_index = 20
		if front_wall != null:
			front_wall.visible = true
		if cabin_interior != null:
			cabin_interior.z_index = 0
		if porch != null:
			porch.z_index = 1
