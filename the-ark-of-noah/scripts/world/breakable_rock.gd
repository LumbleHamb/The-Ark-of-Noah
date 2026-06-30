extends StaticBody2D
class_name BreakableRock

@export var max_health: int = 3
@export var drop_item_id: String = "stone"
@export var drop_count_min: int = 1
@export var drop_count_max: int = 3
@export var hit_shake_degrees: float = 4.0
@export var impact_flash_color: Color = Color(1.0, 0.93, 0.75, 1.0)
@export var impact_particle_amount: int = 14
@export var break_particle_amount: int = 26
@export var camera_shake_hit: float = 1.2
@export var camera_shake_break: float = 2.4
@export var enable_audio_hooks: bool = true
@export var hit_audio_cue: StringName = &"mining_hit"
@export var break_audio_cue: StringName = &"mining_break"

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var current_health: int = 0
var is_broken: bool = false

func _ready() -> void:
	add_to_group(&"breakable_rock")
	current_health = max_health

func hit(hitter: Node = null) -> void:
	if is_broken:
		return
	if not _hitter_has_pickaxe(hitter):
		return
	current_health -= 1
	_play_hit_feedback()
	if current_health <= 0:
		_break_rock()

func get_save_data() -> Dictionary:
	return {
		"health": current_health,
		"broken": is_broken,
	}

func load_from_save(data: Dictionary) -> void:
	current_health = int(data.get("health", max_health))
	is_broken = bool(data.get("broken", false))
	if is_broken:
		queue_free()

func _play_hit_feedback() -> void:
	var hit_tween: Tween = create_tween()
	hit_tween.tween_property(self, "rotation_degrees", hit_shake_degrees, 0.04)
	hit_tween.tween_property(self, "rotation_degrees", -hit_shake_degrees, 0.04)
	hit_tween.tween_property(self, "rotation_degrees", 0.0, 0.04)
	_play_impact_flash(0.09)
	_spawn_hit_particles(false)
	_apply_camera_shake(camera_shake_hit)
	_play_audio_hook(hit_audio_cue)

func _break_rock() -> void:
	is_broken = true
	set_deferred("collision_layer", 0)
	set_deferred("collision_mask", 0)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	_play_impact_flash(0.14)
	_spawn_hit_particles(true)
	_apply_camera_shake(camera_shake_break)
	_play_audio_hook(break_audio_cue)
	if sprite != null:
		var break_tween: Tween = create_tween()
		break_tween.set_parallel(true)
		break_tween.tween_property(sprite, "modulate:a", 0.0, 0.18)
		break_tween.tween_property(sprite, "scale", Vector2(1.2, 0.8), 0.18)
		await break_tween.finished
	_spawn_drops()
	var stats_node: Node = get_node_or_null("/root/game_stats")
	if stats_node != null and stats_node.has_method("increment_stat"):
		stats_node.call("increment_stat", "rocks_mined", 1)
	queue_free()

func _spawn_drops() -> void:
	var item_registry: Node = get_node_or_null("/root/ItemRegistry")
	if item_registry == null or not item_registry.has_method("create_stack"):
		return
	var drop_count: int = randi_range(drop_count_min, drop_count_max)
	var stack: ItemStack = item_registry.call("create_stack", drop_item_id, drop_count) as ItemStack
	if stack == null:
		return
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	HarvestPickup.spawn(stack, parent_node, global_position + Vector2(0.0, -8.0))

func _play_impact_flash(duration: float) -> void:
	if sprite == null:
		return
	var start_modulate: Color = sprite.modulate
	sprite.modulate = impact_flash_color
	var flash_tween: Tween = create_tween()
	flash_tween.tween_property(sprite, "modulate", start_modulate, duration)

func _spawn_hit_particles(is_break: bool) -> void:
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = break_particle_amount if is_break else impact_particle_amount
	particles.lifetime = 0.35 if is_break else 0.22
	particles.local_coords = false
	particles.global_position = global_position
	particles.z_index = 25
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 3.0
	process.gravity = Vector3(0.0, 120.0, 0.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 38.0
	process.set_param_min(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, 38.0)
	process.set_param_max(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, 96.0 if is_break else 70.0)
	process.set_param_min(ParticleProcessMaterial.PARAM_SCALE, 1.1)
	process.set_param_max(ParticleProcessMaterial.PARAM_SCALE, 2.0)
	process.color = Color(0.78, 0.74, 0.62, 1.0)
	particles.process_material = process
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	parent_node.add_child(particles)
	particles.restart()
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(0.6)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free())

func _apply_camera_shake(amount: float) -> void:
	if amount <= 0.01 or get_tree() == null:
		return
	var player_node: Player = get_tree().get_first_node_in_group(&"Player") as Player
	if player_node == null:
		player_node = get_tree().get_first_node_in_group(&"player") as Player
	if player_node == null:
		return
	var cam: Camera2D = player_node.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	var start_offset: Vector2 = cam.offset
	var shake_tween: Tween = create_tween()
	shake_tween.set_parallel(false)
	shake_tween.tween_property(cam, "offset", start_offset + Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.03)
	shake_tween.tween_property(cam, "offset", start_offset + Vector2(randf_range(-amount * 0.6, amount * 0.6), randf_range(-amount * 0.6, amount * 0.6)), 0.04)
	shake_tween.tween_property(cam, "offset", start_offset, 0.05)

func _hitter_has_pickaxe(hitter: Node) -> bool:
	if hitter == null:
		return false
	if not "inventory" in hitter or not hitter.inventory:
		# Try alternate path for InventoryComponent.
		var inv: Node = hitter.get_node_or_null("InventoryComponent") as Node
		if inv == null:
			return false
		if not inv.has_method("get_selected_tool"):
			return false
		var tool: ToolData = inv.call("get_selected_tool") as ToolData
		return tool != null and tool.tool_type == ToolData.ToolType.PICKAXE
	var tool: ToolData = hitter.inventory.get_selected_tool() as ToolData
	return tool != null and tool.tool_type == ToolData.ToolType.PICKAXE

func _play_audio_hook(cue_name: StringName) -> void:
	if not enable_audio_hooks:
		return
	var stats_node: Node = get_node_or_null("/root/game_stats")
	if stats_node != null:
		stats_node.set_meta(&"last_audio_cue", String(cue_name))
