extends StaticBody2D

@export var min_hits := 1
@export var max_hits := 2

const LOG_SCENE = preload("res://scenes/trees/logs.tscn")

var hp := 0
var is_dead := false

@onready var anim_sprite: AnimatedSprite2D = $trunks_animation
@onready var leaves_container = get_node_or_null("Leaves")

func _ready():
	randomize()
	hp = randi_range(min_hits, max_hits)

func hit():
	if is_dead: return
	hp -= 1
	
	# Stardew-style Shake: Rotate left and right
	var shake_tween = create_tween()
	# Rotate 5 degrees left, then 5 degrees right, then back to center
	shake_tween.tween_property(self, "rotation_degrees", 5.0, 0.05)
	shake_tween.tween_property(self, "rotation_degrees", -5.0, 0.05)
	shake_tween.tween_property(self, "rotation_degrees", 0.0, 0.05)

	if hp <= 0:
		call_deferred("break_tree")

func break_tree():
	if is_dead: return
	is_dead = true

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	# 1. Realistic Fall Animation
	var start_rot = rotation
	var start_pos = position
	var target_rot = deg_to_rad(90) 
	var target_pos = position + Vector2(16, 0) 

	var duration := 1.0 
	var elapsed := 0.0

	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t = clamp(elapsed / duration, 0.0, 1.0)
		var ease_t = t * t 
		rotation = lerp_angle(start_rot, target_rot, ease_t)
		position = start_pos.lerp(target_pos, ease_t)
		await get_tree().process_frame

	# 2. IMPACT BOUNCE & SHAKE
	var impact_tween = create_tween()
	impact_tween.tween_property(self, "scale", Vector2(1.1, 0.9), 0.1)
	impact_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)
	
	var players = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var player_cam = players[0].get_node_or_null("Camera2D")
		if player_cam:
			for i in range(3):
				impact_tween.tween_property(player_cam, "offset", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.05)
			impact_tween.tween_property(player_cam, "offset", Vector2.ZERO, 0.05)
	
	await impact_tween.finished

	# 3. Spawn Log
	if LOG_SCENE:
		var log_instance = LOG_SCENE.instantiate()
		get_tree().current_scene.add_child(log_instance)
		log_instance.global_position = global_position
		log_instance.rotation = target_rot + (PI / 2) 
		log_instance.add_to_group("log")

	# 4. Unified Fade-Out
	var fade_tween = create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(anim_sprite, "modulate:a", 0.0, 1.5)
	if leaves_container:
		for child in leaves_container.get_children():
			if child is CanvasItem:
				fade_tween.tween_property(child, "modulate:a", 0.0, 1.5)
	
	await fade_tween.finished
	
	# Unregister from chunk manager before freeing
	var chunk_manager: Node = get_tree().current_scene.find_child("ChunkManager", false, false)
	if chunk_manager != null and chunk_manager.has_method(&"unregister_node"):
		chunk_manager.unregister_node(self)
	
	queue_free()
