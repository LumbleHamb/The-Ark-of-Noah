extends StaticBody2D
class_name Trunk

## Tree trunk entity using component architecture.
##
## Components (added as children in scene):
##   - HealthComponent: HP management, damage handling
##   - FadeComponent: fade-out on death

const LOG_SCENE: PackedScene = preload("res://scenes/trees/logs.tscn")

var health: HealthComponent = null
var fade: FadeComponent = null
var is_dead: bool = false

@onready var anim_sprite: AnimatedSprite2D = $trunks_animation
@onready var leaves_container: Node = get_node_or_null("Leaves")


func _ready() -> void:
	# Find components
	health = get_node_or_null("HealthComponent") as HealthComponent
	fade = get_node_or_null("FadeComponent") as FadeComponent
	
	if health:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	
	# Register with chunk manager
	add_to_group(&"chunked")


func hit() -> void:
	if is_dead or not health:
		return
	health.take_damage(1)


func _on_damaged(_amount: int, _remaining: int) -> void:
	# Stardew-style Shake: Rotate left and right
	var shake_tween := create_tween()
	shake_tween.tween_property(self, "rotation_degrees", 5.0, 0.05)
	shake_tween.tween_property(self, "rotation_degrees", -5.0, 0.05)
	shake_tween.tween_property(self, "rotation_degrees", 0.0, 0.05)


func _on_died() -> void:
	if is_dead:
		return
	is_dead = true

	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)

	# 1. Realistic Fall Animation
	_do_fall_animation()


func _do_fall_animation() -> void:
	var start_rot := rotation
	var start_pos := position
	var target_rot := deg_to_rad(90.0)
	var target_pos := position + Vector2(16, 0)
	var duration := 1.0
	var elapsed := 0.0

	while elapsed < duration:
		elapsed += get_process_delta_time()
		var t := clampf(elapsed / duration, 0.0, 1.0)
		var ease_t := t * t
		rotation = lerp_angle(start_rot, target_rot, ease_t)
		position = start_pos.lerp(target_pos, ease_t)
		await get_tree().process_frame

	# 2. IMPACT BOUNCE & SHAKE
	_do_impact_effect()


func _do_impact_effect() -> void:
	var impact_tween := create_tween()
	impact_tween.tween_property(self, "scale", Vector2(1.1, 0.9), 0.1)
	impact_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.2).set_trans(Tween.TRANS_BOUNCE)

	# Camera shake
	var players: Array = get_tree().get_nodes_in_group("Player")
	if players.size() > 0:
		var player_cam: Camera2D = players[0].get_node_or_null("Camera2D") as Camera2D
		if player_cam:
			for i in range(3):
				impact_tween.tween_property(player_cam, "offset", Vector2(randf_range(-4, 4), randf_range(-4, 4)), 0.05)
			impact_tween.tween_property(player_cam, "offset", Vector2.ZERO, 0.05)

	await impact_tween.finished

	# 3. Spawn Log
	_spawn_log()

	# 4. Fade out using FadeComponent
	if fade:
		fade.fade_out()
		fade.fade_completed.connect(_on_fade_complete)
	else:
		# Fallback: manual fade
		_manual_fade_out()


func _spawn_log() -> void:
	if not LOG_SCENE:
		return
	var log_instance: Node2D = LOG_SCENE.instantiate()
	get_tree().current_scene.add_child(log_instance)
	log_instance.global_position = global_position
	log_instance.rotation = deg_to_rad(90.0) + (PI / 2)
	log_instance.add_to_group("log")


func _manual_fade_out() -> void:
	var fade_tween := create_tween()
	fade_tween.set_parallel(true)
	fade_tween.tween_property(anim_sprite, "modulate:a", 0.0, 1.5)
	if leaves_container:
		for child in leaves_container.get_children():
			if child is CanvasItem:
				fade_tween.tween_property(child, "modulate:a", 0.0, 1.5)
	await fade_tween.finished
	_cleanup_and_free()


func _on_fade_complete(_direction: String) -> void:
	if fade:
		fade.fade_completed.disconnect(_on_fade_complete)
	_cleanup_and_free()


func _cleanup_and_free() -> void:
	# Unregister from chunk manager before freeing
	var chunk_manager: Node = get_tree().current_scene.find_child("ChunkManager", false, false)
	if chunk_manager != null and chunk_manager.has_method(&"unregister_node"):
		chunk_manager.unregister_node(self)
	
	queue_free()
