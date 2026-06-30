extends CharacterBody2D
class_name Player

# Direct script reference for the construction area (avoids depending on the
# global class_name registry being rescanned for newly-added scripts).

## Player entity using component architecture.
##
## Components (added as children in scene):
##   - MovementComponent: input reading, velocity calculation, speed modifiers
##   - PlayerAnimationComponent: animation selection based on state/direction
##   - AttackComponent: melee attack state, hitbox management
##   - InventoryComponent: tool/seed inventory, slot selection
##   - FarmingComponent: tilling, planting, harvesting actions
##
## This script coordinates between components. It owns the top-level
## state machine (IDLE, WALK, RUN, ATTACK, FARMING) and delegates
## to components for specific behaviors.

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var anim: AnimatedSprite2D = $player_animation
@onready var hitbox: Area2D = $hitbox
@onready var rope_range: Area2D = $rope_range
@onready var rope_line: Line2D = $rope_line
@onready var tool_sprite: Sprite2D = $tool_sprite

@onready var action_bar: ActionBar = get_node_or_null("%ActionBar") as ActionBar

# ============================================================================
# COMPONENT REFERENCES
# ============================================================================
var movement: MovementComponent = null
var animator: PlayerAnimationComponent = null
var attack: AttackComponent = null
var inventory: InventoryComponent = null
var farming: FarmingComponent = null
var stamina: StaminaComponent = null
var bucket: Node = null

# ============================================================================
# STATE
# ============================================================================
enum State { IDLE, WALK, RUN, ATTACK, FARMING }

var state: State = State.IDLE
var last_dir: Vector2 = Vector2.DOWN
var attached_log: Node2D = null
var input_enabled: bool = true
var _footstep_timer: float = 0.0

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	# Find components
	movement = get_node_or_null("MovementComponent") as MovementComponent
	animator = get_node_or_null("PlayerAnimationComponent") as PlayerAnimationComponent
	attack = get_node_or_null("AttackComponent") as AttackComponent
	inventory = get_node_or_null("InventoryComponent") as InventoryComponent
	farming = get_node_or_null("FarmingComponent") as FarmingComponent
	stamina = get_node_or_null("StaminaComponent") as StaminaComponent
	bucket = get_node_or_null("BucketComponent") as Node
	
	# Hitbox handling is delegated to AttackComponent
	
	if rope_line:
		rope_line.visible = false
	
	# Setup inventory with action bar
	if inventory and action_bar:
		inventory.setup_with_action_bar(action_bar)
		inventory.slot_selected.connect(_on_slot_selected)
	
	# Setup farming with inventory
	if farming and inventory:
		var farm_mgr: FarmManager = _find_farm_manager()
		if farm_mgr:
			farming.setup(farm_mgr, inventory)
	
	# Load starter equipment
	_load_starter_equipment()
	
	# Update action bar visuals
	if inventory:
		inventory.update_action_bar()


func _physics_process(delta: float) -> void:
	if movement:
		movement.read_input()
	
	# Inventory toggle must always work, even when player input is disabled
	# (e.g. when a chest or other overlay is open).
	if Input.is_action_just_pressed("inventory"):
		var inventory_window: CanvasLayer = _get_inventory_window()
		if inventory_window and inventory_window.has_method(&"toggle_ui"):
			inventory_window.call("toggle_ui")
		return
	
	# Dev menu toggle — always works.
	if Input.is_action_just_pressed("devmenu"):
		var dev_menu: CanvasLayer = _get_dev_menu()
		if dev_menu and dev_menu.has_method(&"toggle_ui"):
			dev_menu.call("toggle_ui")
	
	if not input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Process input actions (number keys, attack, interact)
	_process_input_actions()
	
	match state:
		State.ATTACK:
			_handle_attack_state()
		State.FARMING:
			_handle_farming_state()
		_:
			_handle_movement_state()
	
	move_and_slide()
	_update_animation()
	_update_rope_visuals()
	_update_step_stats(delta)
	
	if farming:
		farming.process_cooldown(delta)

# ============================================================================
# PUBLIC API
# ============================================================================
func set_player_paused(paused: bool) -> void:
	input_enabled = not paused
	if movement:
		movement.set_input_enabled(not paused)
	if paused:
		velocity = Vector2.ZERO
		state = State.IDLE


func set_speed_modifier(mod: float) -> void:
	if movement:
		movement.set_speed_modifier(mod)

# ============================================================================
# MOVEMENT
# ============================================================================
func _handle_movement_state() -> void:
	if movement:
		var input_dir := movement.input_dir
		if input_dir != Vector2.ZERO:
			last_dir = input_dir.normalized()
		
		velocity = movement.calculate_velocity()
		
		match movement.move_state:
			MovementComponent.MoveState.IDLE:
				state = State.IDLE
			MovementComponent.MoveState.WALK:
				state = State.WALK
			MovementComponent.MoveState.RUN:
				state = State.RUN
	else:
		# Fallback: basic movement
		velocity = Vector2.ZERO
		state = State.IDLE

# ============================================================================
# ATTACK
# ============================================================================
func _handle_attack_state() -> void:
	if attack:
		if attack.process_attack():
			state = State.IDLE

func _on_hitbox_body_entered(_body: Node) -> void:
	# Handled by AttackComponent's body_hit signal
	pass

# ============================================================================
# FARMING
# ============================================================================
func _handle_farming_state() -> void:
	# Farming state is handled by timer in _do_farming_anim
	pass

# ============================================================================
# INPUT
# ============================================================================
func _process_input_actions() -> void:
	if not input_enabled:
		return
	
	# Number keys 1-8 for slot selection (matches 8-slot action bar).
	for i in range(8):
		if Input.is_key_pressed(KEY_1 + i):
			if inventory:
				inventory.select_slot(i)
			return
	
	# Attack (Space)
	if state not in [State.ATTACK, State.FARMING] and Input.is_action_just_pressed("attack"):
		_start_attack()
	
	# Interact (E)
	if state not in [State.ATTACK, State.FARMING] and Input.is_action_just_pressed("interact"):
		_handle_interact()

# ============================================================================
# INTERACTION
# ============================================================================
func _handle_interact() -> void:
	# 1. Try rope attach/detach
	if attached_log != null:
		_detach_rope()
		return
	_try_attach_rope()
	if attached_log != null:
		return
	
	# 2. Try chest open/close (if standing in a chest's interaction zone)
	if _handle_chest():
		return

	# 2.5. Try collecting resources (pitch source etc.)
	if _handle_resource_collection():
		return

	# 2.6. Try construction-area deposit (if standing in a construction zone)
	if _handle_construction_deposit():
		return

	# 2.7. Try blacksmith shop interaction.
	if _handle_blacksmith_shop():
		return

	# 2.8. Try crafting bench interaction.
	if _handle_crafting():
		return

	# 3. Try harvest on a ripe crop (works with any equipped item, or none)
	if farming and farming.try_harvest(global_position, last_dir):
		_do_farming_anim()
		return

	# 4. Check if axe is equipped and no log nearby → attack instead
	if _can_attack_with_axe():
		_start_attack()
		return

	# 4.5. Check if pickaxe is equipped → mine rock
	if _can_attack_with_pickaxe():
		_start_attack()
		return

	# 5. Try farming action (till soil / plant seed)
	if inventory and inventory.selected_slot >= 0 and farming:
		if farming.do_farming_action(global_position, last_dir):
			_do_farming_anim()
			return


func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	if animator:
		var dir_key := animator.get_dir_from_vector(last_dir)
		animator.play_attack(dir_key)
	if attack:
		attack.start_attack(animator.get_dir_from_vector(last_dir) if animator else "S")

# ============================================================================
# ROPE
# ============================================================================
func _try_attach_rope() -> void:
	for body in rope_range.get_overlapping_bodies():
		if body.is_in_group("log"):
			_attach_rope(body)
			return


func _attach_rope(log_body: Node2D) -> void:
	if log_body.has_method("attach_to_target"):
		if not log_body.attach_to_target(self):
			return
	attached_log = log_body


func _detach_rope() -> void:
	if attached_log and attached_log.has_method("detach"):
		attached_log.detach()
	attached_log = null
	if rope_line:
		rope_line.visible = false

# ============================================================================
# CHEST
# ============================================================================
## Opens the nearest chest the player is standing in, via the ChestUI autoload.
## Returns true if a chest was opened (so the caller can stop the interact
## chain).  While the chest UI is open the player is paused; ChestUI.close_ui()
## restores player input when the player presses E/Esc again (see chest_ui.gd).
func _handle_chest() -> bool:
	var chest_ui: CanvasLayer = safe_get_chest_ui()
	# If a chest UI is already open, close it via ChestUI (which also unpauses the
	# player).  We do this here rather than in ChestUI._process so the interact
	# press is handled exactly once — avoids a race where ChestUI closes and then
	# Player reopens on the same frame.
	if chest_ui and chest_ui.visible:
		if chest_ui.has_method(&"close_ui"):
			chest_ui.call("close_ui")
		return true
	# Find a chest whose interaction zone currently contains the player.
	for node: Node in get_tree().get_nodes_in_group(&"chest"):
		if node is ChestComponent:
			var chest: ChestComponent = node as ChestComponent
			if chest.is_player_in_zone():
				chest.open_for(self)
				if chest_ui and chest_ui.has_method(&"show_for"):
					chest_ui.show_for(chest)
				# Pause player movement while the chest is open.
				set_player_paused(true)
				return true
	return false

## Resolves the ChestUI autoload without importing it (duck-typed).
func safe_get_chest_ui() -> CanvasLayer:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("ChestUI") as CanvasLayer

func _is_pause_menu_open() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var pause_menu: CanvasLayer = tree.root.get_node_or_null("PauseMenu") as CanvasLayer
	if pause_menu == null:
		return false
	if pause_menu.has_method(&"is_open"):
		return bool(pause_menu.call("is_open"))
	return pause_menu.visible

func _get_inventory_window() -> CanvasLayer:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("InventoryUI") as CanvasLayer

func _get_dev_menu() -> CanvasLayer:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	# DevMenu is a child of the current scene (world), not the root.
	var scene_root: Node = tree.current_scene
	if scene_root == null:
		return null
	return scene_root.get_node_or_null("DevMenu") as CanvasLayer

# ============================================================================
# CONSTRUCTION AREA — deposit resources into a nearby construction site.
# ============================================================================
## If the player is standing in a construction area, deposit any accepted
## resources the player is carrying into the current stage.  Returns true if a
## deposit happened (so the caller can stop the interact chain).
func _handle_construction_deposit() -> bool:
	for node: Node in get_tree().get_nodes_in_group(&"construction_area"):
		if node is Node and node.has_method("is_finished") and node.has_method("is_player_in_zone") and node.has_method("try_deposit"):
			var area: Node = node
			if area.is_finished():
				continue
			if not area.is_player_in_zone():
				continue
			return _deposit_into_area(area)
	return false

## Deposits every accepted resource the player carries into the area's current
## stage.  Returns true if at least one item was deposited.
func _deposit_into_area(area: Node) -> bool:
	if inventory == null:
		return false
	var deposited_any: bool = false
	var consumed_pitch_buckets: int = 0
	var stacks_snapshot: Array[ItemStack] = inventory.items.duplicate()
	for stack: ItemStack in stacks_snapshot:
		if stack == null or stack.count <= 0:
			continue
		var item_id: String = stack.item_id
		var deposit_item_id: String = item_id
		if item_id == "bucket_pitch":
			deposit_item_id = "pitch"
		var carried_count: int = inventory.count_of(item_id)
		if carried_count <= 0:
			continue
		var accepted_count: int = area.try_deposit(deposit_item_id, carried_count)
		if accepted_count <= 0:
			continue
		var removed_count: int = inventory.remove_item(item_id, accepted_count)
		if removed_count <= 0:
			continue
		if item_id == "bucket_pitch":
			consumed_pitch_buckets += removed_count
		deposited_any = true
	if consumed_pitch_buckets > 0:
		var empty_bucket_stack: ItemStack = ItemStack.new()
		empty_bucket_stack.item_id = "bucket_empty"
		empty_bucket_stack.item_name = "Empty Bucket"
		empty_bucket_stack.count = consumed_pitch_buckets
		empty_bucket_stack.max_stack = 1
		empty_bucket_stack.stackable = false
		inventory.add_item(empty_bucket_stack)
	return deposited_any


func _handle_resource_collection() -> bool:
	if inventory == null:
		return false
	for node: Node in get_tree().get_nodes_in_group(&"resource_collector"):
		if node is Node and node.has_method("is_player_in_zone") and node.has_method("collect_into"):
			if node.is_player_in_zone():
				return node.collect_into(inventory) > 0
	return false

func _handle_blacksmith_shop() -> bool:
	if inventory == null:
		return false
	var shop_ui: CanvasLayer = safe_get_blacksmith_shop()
	# If the shop UI is already open, close it.
	if shop_ui and shop_ui.visible:
		if shop_ui.has_method(&"close_ui"):
			shop_ui.call("close_ui")
		return true
	# Find a blacksmith whose interaction zone contains the player.
	for node: Node in get_tree().get_nodes_in_group(&"blacksmith_shop"):
		if node is BlacksmithShopComponent:
			var shop: BlacksmithShopComponent = node as BlacksmithShopComponent
			if shop.is_player_in_zone():
				shop.open_for(self)
				if shop_ui and shop_ui.has_method(&"show_for"):
					shop_ui.show_for(shop)
				set_player_paused(true)
				return true
	return false

## Resolves the BlacksmithShop autoload without importing it.
func safe_get_blacksmith_shop() -> CanvasLayer:
	var tree: SceneTree = get_tree()
	if tree == null:
		return null
	return tree.root.get_node_or_null("BlacksmithShop") as CanvasLayer

func _handle_crafting() -> bool:
	if inventory == null:
		return false
	for node: Node in get_tree().get_nodes_in_group(&"crafting_bench"):
		if node is Node and node.has_method("is_player_in_zone") and node.has_method("craft_first_available"):
			if node.is_player_in_zone():
				return node.craft_first_available(inventory)
	return false

func _update_rope_visuals() -> void:
	if not is_instance_valid(attached_log) or not rope_line:
		if attached_log:
			_detach_rope()
		return
	rope_line.visible = true
	var log_anchor: Vector2 = attached_log.get_rope_anchor_global()
	rope_line.points = [Vector2.ZERO, to_local(log_anchor)]
	
	# Detach if too far
	if attached_log is Log:
		var log_rope: RopeComponent = attached_log.get_node_or_null("RopeComponent") as RopeComponent
		if log_rope and log_rope.is_attached():
			var dist := global_position.distance_to(attached_log.global_position)
			if dist > 140.0:
				_detach_rope()

# ============================================================================
# AXE ATTACK CHECK
# ============================================================================
func _can_attack_with_axe() -> bool:
	if not inventory:
		return false
	var tool: ToolData = inventory.get_selected_tool()
	if not tool or tool.tool_type != ToolData.ToolType.AXE:
		return false
	# Don't attack if there's a log to interact with (rope priority)
	for body in rope_range.get_overlapping_bodies():
		if body.is_in_group("log"):
			return false
	return true

# ============================================================================
# PICKAXE ATTACK CHECK
# ============================================================================
func _can_attack_with_pickaxe() -> bool:
	if not inventory:
		return false
	var tool: ToolData = inventory.get_selected_tool()
	if not tool or tool.tool_type != ToolData.ToolType.PICKAXE:
		return false
	return true

# ============================================================================
# FARMING ANIMATION
# ============================================================================
func _do_farming_anim() -> void:
	state = State.FARMING
	velocity = Vector2.ZERO
	if animator:
		var dir_key := animator.get_dir_from_vector(last_dir)
		animator.play_attack(dir_key)
	
	await get_tree().create_timer(0.3).timeout
	if state == State.FARMING:
		state = State.IDLE

func _on_slot_selected(_index: int) -> void:
	# Update tool visual if needed
	if tool_sprite:
		tool_sprite.visible = false

# ============================================================================
# ANIMATION
# ============================================================================
func _update_animation() -> void:
	if not animator:
		return
	
	var dir_key := animator.get_dir_from_vector(last_dir)
	
	match state:
		State.IDLE:
			animator.play_idle(dir_key)
		State.WALK:
			animator.play_walk(dir_key)
		State.RUN:
			animator.play_run(dir_key)
		State.ATTACK, State.FARMING:
			# Attack animation already playing
			pass

# ============================================================================
# STARTER EQUIPMENT
# ============================================================================
func _load_starter_equipment() -> void:
	if not inventory:
		return
	
	var hoe: ToolData = ResourceLoader.load("res://resources/tools/hoes_starter.tres")
	if hoe:
		inventory.add_tool(hoe)
	
	var axe: ToolData = ResourceLoader.load("res://resources/tools/axe_starter.tres")
	if axe:
		inventory.add_tool(axe)
	
	var pickaxe: ToolData = ResourceLoader.load("res://resources/tools/pickaxe_starter.tres")
	if pickaxe:
		inventory.add_tool(pickaxe)
	
	var crops_to_load: Array[String] = [
		"res://resources/crops/crop_carrot.tres",
		"res://resources/crops/crop_potato.tres",
		"res://resources/crops/crop_parsnip.tres",
	]
	for path: String in crops_to_load:
		var crop_entry: CropData = ResourceLoader.load(path)
		if crop_entry:
			inventory.add_seed(crop_entry)
	
	if inventory.get_total_slots() > 0:
		inventory.select_slot(0)
	
	inventory.update_action_bar()

# ============================================================================
# HELPERS
# ============================================================================
func _find_farm_manager() -> FarmManager:
	var fm: FarmManager = get_tree().get_first_node_in_group(&"farm_manager")
	if fm == null:
		fm = get_tree().root.find_child("FarmManager", true, false) as FarmManager
	return fm

func _update_step_stats(delta: float) -> void:
	if velocity.length() <= 1.0:
		_footstep_timer = 0.0
		return
	var stats_node: Node = get_node_or_null("/root/game_stats")
	if stats_node != null and stats_node.has_method("increment_stat"):
		var steps_to_add: int = int((velocity.length() * delta) / 8.0)
		if steps_to_add > 0:
			stats_node.call("increment_stat", "steps_walked", steps_to_add)
	_footstep_timer += delta
	var cadence: float = 0.22 if state == State.RUN else 0.34
	if _footstep_timer >= cadence:
		_footstep_timer = 0.0
		_spawn_footstep_feedback()

func _spawn_footstep_feedback() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var particles: GPUParticles2D = GPUParticles2D.new()
	particles.one_shot = true
	particles.amount = 5
	particles.lifetime = 0.24
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.global_position = global_position + Vector2(0.0, 11.0)
	particles.z_index = 3
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 1.5
	process.gravity = Vector3(0.0, 24.0, 0.0)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 24.0
	process.color = Color(0.65, 0.63, 0.56, 0.85)
	process.set_param_min(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, 16.0)
	process.set_param_max(ParticleProcessMaterial.PARAM_INITIAL_LINEAR_VELOCITY, 38.0)
	particles.process_material = process
	parent_node.add_child(particles)
	particles.restart()
	var stats_node: Node = get_node_or_null("/root/game_stats")
	if stats_node != null:
		stats_node.set_meta(&"last_footstep_surface", _resolve_surface_tag())
		stats_node.set_meta(&"last_audio_cue", "footstep_%s" % _resolve_surface_tag())
	var cleanup_timer: SceneTreeTimer = get_tree().create_timer(0.4)
	cleanup_timer.timeout.connect(func() -> void:
		if is_instance_valid(particles):
			particles.queue_free())

func _resolve_surface_tag() -> String:
	var map_node: Node = get_parent().get_node_or_null("map") if get_parent() != null else null
	if map_node == null:
		return "ground"
	var water_layer: TileMapLayer = map_node.get_node_or_null("Water") as TileMapLayer
	if water_layer != null:
		var water_tile: Vector2i = water_layer.local_to_map(global_position - water_layer.global_position)
		if water_layer.get_cell_source_id(water_tile) != -1:
			return "water"
	var beach_layer: TileMapLayer = map_node.get_node_or_null("Beach") as TileMapLayer
	if beach_layer != null:
		var beach_tile: Vector2i = beach_layer.local_to_map(global_position - beach_layer.global_position)
		if beach_layer.get_cell_source_id(beach_tile) != -1:
			return "sand"
	return "grass"
