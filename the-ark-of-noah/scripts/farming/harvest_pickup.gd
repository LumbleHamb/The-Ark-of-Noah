class_name HarvestPickup
extends Node2D

## ============================================================================
## HARVEST PICKUP — A floating, bobbing item dropped on the ground that the
## player auto-collects by walking close.
##
## Spawned by FarmManager when a crop is harvested.  It:
##   1. Appears at the harvest tile and rises slightly with a small pop.
##   2. Bobs gently up and down forever (a sine-wave offset on position.y).
##   3. When the player enters its collect radius, it flies toward the player,
##      plays a collect "pop", adds its ItemStack to the player's inventory,
##      and frees itself.
##
## Reusable: any system that drops a ground item (farming harvest, tree felling,
## mining) can call HarvestPickup.spawn(item_stack, world_position).
##
## It finds the player via the "player" group and the player's
## InventoryComponent child, so it has no hard dependencies — drop it anywhere.
## ============================================================================

## Radius (pixels) within which the pickup auto-collects.
@export var collect_radius: float = 28.0

## How fast the pickup flies toward the player when collecting (px/s).
@export var collect_speed: float = 420.0

## How high it bobs (pixels).
@export var bob_height: float = 4.0

## How fast it bobs (cycles per second).
@export var bob_speed: float = 2.5
@export var pickup_particle_amount: int = 10
@export var floating_text_rise: float = 16.0
@export var floating_text_duration: float = 0.45
@export var enable_audio_hooks: bool = true
@export var pickup_audio_cue: StringName = &"item_pickup"

var _stack: ItemStack = null
var _sprite: Sprite2D = null
var _player: Node2D = null
var _player_inventory: InventoryComponent = null
var _origin_y: float = 0.0
var _age: float = 0.0
var _collecting: bool = false
var _collected: bool = false

static var _empty_texture: Texture2D = preload("res://images/ui/Individual files/ui_images/Item slots/Slot_01_Empty.png")

## Convenience spawner: creates a pickup in the given parent at a world position.
static func spawn(stack: ItemStack, parent: Node, world_position: Vector2) -> HarvestPickup:
	var pickup_scene: PackedScene = load("res://scenes/farming/harvest_pickup.tscn") as PackedScene
	var pickup: HarvestPickup = pickup_scene.instantiate()
	# Must set position BEFORE add_child so that _ready() captures the correct Y.
	pickup.global_position = world_position
	parent.add_child(pickup)
	pickup.set_stack(stack)
	return pickup

func _ready() -> void:
	_origin_y = global_position.y
	# Build a sprite to show the item icon.
	_sprite = Sprite2D.new()
	_sprite.texture = _empty_texture
	_sprite.z_index = 20
	add_child(_sprite)
	# Spawn pop: start small and scale up, and rise from the ground.
	scale = Vector2(0.2, 0.2)
	var pop_tween: Tween = create_tween().set_parallel()
	pop_tween.tween_property(self, "scale", Vector2.ONE, 0.18).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(self, "_origin_y", _origin_y - 24.0, 0.35).set_ease(Tween.EASE_OUT)
	# Register so the player can find nearby pickups if needed.
	add_to_group(&"pickup")

func _process(delta: float) -> void:
	_age += delta
	# Bob gently around the origin height.
	global_position.y = _origin_y - sin(_age * bob_speed * TAU) * bob_height
	if _sprite:
		_sprite.rotation = sin(_age * 2.0) * 0.05
	_resolve_player()
	if _collected:
		return
	if _collecting and is_instance_valid(_player):
		# Fly toward the player.
		var to_player: Vector2 = _player.global_position - global_position
		var dist: float = to_player.length()
		if dist < 6.0:
			_collect()
			return
		global_position += to_player.normalized() * collect_speed * delta
		_origin_y = global_position.y
		return
	# Check if the player is within the collect radius.
	if is_instance_valid(_player):
		var d: float = global_position.distance_to(_player.global_position)
		if d <= collect_radius:
			_collecting = true

## Sets the item stack this pickup represents and updates the sprite.
func set_stack(stack: ItemStack) -> void:
	_stack = stack
	if _sprite and stack and stack.icon:
		_sprite.texture = stack.icon

func _resolve_player() -> void:
	if is_instance_valid(_player):
		return
	if get_tree() == null:
		return
	_player = get_tree().get_first_node_in_group(&"player") as Node2D
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"Player") as Node2D
	if _player and _player_inventory == null:
		for child: Node in _player.get_children():
			if child is InventoryComponent:
				_player_inventory = child as InventoryComponent
				break

func _collect() -> void:
	if _collected:
		return
	_collected = true
	# Add the stack to the player's inventory (merging if possible).
	if _player_inventory and _stack:
		var leftover: int = _player_inventory.add_item(_stack)
		if leftover > 0:
			# Couldn't fit everything; leave the remainder on the ground.
			_stack.count = leftover
			_collecting = false
			_collected = false
			return
		var stats_node: Node = get_node_or_null("/root/game_stats")
		if stats_node != null and stats_node.has_method("increment_stat"):
			stats_node.call("increment_stat", "crops_harvested", 1)
	_spawn_pickup_particles()
	_spawn_floating_text()
	_play_audio_hook()
	# Collect pop animation, then free.
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.06)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.12).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _spawn_pickup_particles() -> void:
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = pickup_particle_amount
	particles.lifetime = 0.28
	particles.local_coords = false
	particles.global_position = global_position
	particles.z_index = 40
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 2.0
	process.gravity = Vector3(0.0, 45.0, 0.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 40.0
	process.color = Color(1.0, 0.96, 0.55, 1.0)
	process.set_param_min(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, 25.0)
	process.set_param_max(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, 85.0)
	particles.process_material = process
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	parent_node.add_child(particles)
	particles.restart()
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(0.5)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free())

func _spawn_floating_text() -> void:
	if _stack == null:
		return
	var label: Label = Label.new()
	label.text = "+%d %s" % [_stack.count, _stack.item_name]
	label.z_index = 50
	label.position = Vector2(-22.0, -14.0)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.97, 0.72, 1.0))
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	add_child(label)
	var text_tween: Tween = create_tween()
	text_tween.set_parallel(true)
	text_tween.tween_property(label, "position:y", label.position.y - floating_text_rise, floating_text_duration)
	text_tween.tween_property(label, "modulate:a", 0.0, floating_text_duration)
	text_tween.tween_callback(label.queue_free)

func _play_audio_hook() -> void:
	if not enable_audio_hooks:
		return
	var stats_node: Node = get_node_or_null("/root/game_stats")
	if stats_node != null:
		stats_node.set_meta(&"last_audio_cue", String(pickup_audio_cue))
