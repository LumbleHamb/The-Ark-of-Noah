extends CharacterBody2D
class_name Player

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
# CONSTANTS
# ============================================================================
const MobileJoystickScript: Script = preload("res://scripts/ui/virtual_joystick.gd")

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

# ============================================================================
# STATE
# ============================================================================
enum State { IDLE, WALK, RUN, ATTACK, FARMING }

var state: State = State.IDLE
var last_dir: Vector2 = Vector2.DOWN
var attached_log: Node2D = null
var input_enabled: bool = true

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
	
	# Number keys 1-0 for slot selection
	for i in range(10):
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
	
	# 2. Check if axe is equipped and no log nearby → attack instead
	if _can_attack_with_axe():
		_start_attack()
		return
	
	# 3. Try farming action (till soil / plant seed)
	if inventory and inventory.selected_slot >= 0 and farming:
		if farming.do_farming_action(global_position, last_dir):
			_do_farming_anim()
			return
	
	# 4. Try harvest
	if farming and farming.try_harvest(global_position, last_dir):
		_do_farming_anim()


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
