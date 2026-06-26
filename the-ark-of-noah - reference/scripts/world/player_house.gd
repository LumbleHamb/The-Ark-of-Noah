extends Node2D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var chimney_smoke: AnimatedSprite2D = $chimney_smoke


func _on_doorway_body_entered(body: Node2D) -> void:
	print("ENTER:", body.name)

	if body.is_in_group("Player"):
		chimney_smoke.visible = false
		anim_player.play("open_house")


func _on_doorway_body_exited(body: Node2D) -> void:
	print("EXIT:", body.name)

	if body.is_in_group("Player"):
		chimney_smoke.visible = true
		anim_player.play_backwards("open_house")
