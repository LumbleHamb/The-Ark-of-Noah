extends CharacterBody2D

# ============================================================================
# PLAYER — WITH FARMING INTEGRATION
# ============================================================================

const MobileJoystickScript: Script = preload("res://scripts/ui/virtual_joystick.gd")

@onready var anim: AnimatedSprite2D = $player_animation
@onready var hitbox: Area2D = $hitbox
@onready var rope_range: Area2D = $rope_range
@onready var rope_line: Line2D = $rope_line
@onready var tool_sprite: Sprite2D = $tool_sprite

@export var walk_speed: float = 80.0
@export var run_speed: float = 140.0
@export var rope_hard_limit: float = 140.0

var current_speed_mod: float = 1.0

# Hitbox positions per facing direction (placed in front of the player's swing)
const HITBOX_OFFSETS: Dictionary = {
	"S":  Vector2(0, 24),
	"SE": Vector2(17, 17),
	"E":  Vector2(24, 0),
	"NE": Vector2(17, -17),
	"N":  Vector2(0, -24),
	"NW": Vector2(-17, -17),
	"W":  Vector2(-24, 0),
	"SW": Vector2(-17, 17),
}

# Animation Offsets
var BASE_OFFSET: Vector2 = Vector2(-32, -43)
var ATTACK_OFFSET: Vector2 = Vector2(-48, -59)  # Centers 96x96 attack frame same as 64x64 idle/walk/run

# Tool sprite offsets per facing direction (in local player coords)
# Positioned at the character's right hand (centered sprite, scaled 0.4)
const TOOL_OFFSETS: Dictionary = {
	"S":  Vector2(10, -12),
	"SE": Vector2(12, -13),
	"E":  Vector2(13, -14),
	"NE": Vector2(10, -16),
	"N":  Vector2(8, -16),
	"NW": Vector2(-10, -16),
	"W":  Vector2(-13, -14),
	"SW": Vector2(-12, -13),
}

enum State { IDLE, WALK, RUN, ATTACK, FARMING }

var state: State = State.IDLE
var last_dir: Vector2 = Vector2.DOWN
var input_dir: Vector2 = Vector2.ZERO
var attached_log: Node2D = null

# UI pause — disables player control while world continues
var input_enabled: bool = true

# ---------------------------------------------------------------------------
# FARMING
# ---------------------------------------------------------------------------
@export var farm_manager_path: NodePath = NodePath("")

var farm_manager: FarmManager = null
var tool_inventory: Array[ToolData] = []
var seed_inventory: Array[CropData] = []
var selected_slot: int = -1
var farm_cooldown: float = 0.0
const FARM_COOLDOWN_TIME: float = 0.4

@onready var action_bar: ActionBar = %ActionBar if has_node("%ActionBar") else null

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	hitbox.monitoring = true
	hitbox.body_entered.connect(_on_hitbox_body_entered)
	anim.offset = BASE_OFFSET
	if rope_line:
		rope_line.visible = false
	
	_find_farm_manager()
	_load_starter_equipment()
	
	if action_bar:
		action_bar.tool_selected.connect(_on_action_bar_selected)
	
	# Show equipped tool sprite after loading starter equipment
	_update_equipped_tool()

func _find_farm_manager() -> void:
	if farm_manager_path != NodePath(""):
		farm_manager = get_node(farm_manager_path)
	if farm_manager == null:
		farm_manager = get_tree().get_first_node_in_group(&"farm_manager")
	if farm_manager == null:
		var root := get_tree().root
		farm_manager = root.find_child("FarmManager", true, false)

func _load_starter_equipment() -> void:
	var hoe: ToolData = ResourceLoader.load("res://resources/tools/hoes_starter.tres")
	if hoe:
		tool_inventory.append(hoe)
	
	var axe: ToolData = ResourceLoader.load("res://resources/tools/axe_starter.tres")
	if axe:
		tool_inventory.append(axe)
	
	var pickaxe: ToolData = ResourceLoader.load("res://resources/tools/pickaxe_starter.tres")
	if pickaxe:
		tool_inventory.append(pickaxe)
	
	var crops_to_load: Array[String] = [
		"res://resources/crops/crop_carrot.tres",
		"res://resources/crops/crop_potato.tres",
		"res://resources/crops/crop_parsnip.tres",
	]
	for path in crops_to_load:
		var crop_entry: CropData = ResourceLoader.load(path)
		if crop_entry:
			seed_inventory.append(crop_entry)
	
	if tool_inventory.size() > 0:
		_select_slot(0)
	_update_action_bar()

func _update_action_bar() -> void:
	if not action_bar:
		return
	var idx: int = 0
	for tool in tool_inventory:
		if tool.icon:
			action_bar.set_slot_texture(idx, tool.icon)
		idx += 1
	for entry in seed_inventory:
		if entry.seed_sprite:
			action_bar.set_slot_texture(idx, entry.seed_sprite)
		idx += 1

# ============================================================================
# PHYSICS PROCESS
# ============================================================================
func set_player_paused(paused: bool) -> void:
	"""Disable only player input and physics movement (world continues running)."""
	input_enabled = not paused
	if paused:
		velocity = Vector2.ZERO
		state = State.IDLE

func _physics_process(delta: float) -> void:
	read_input()
	if not input_enabled:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	match state:
		State.ATTACK:
			handle_attack_state()
		State.FARMING:
			handle_farming_state()
		_:
			handle_movement_state()
	
	move_and_slide()
	update_animation()
	apply_anim_offset()
	update_rope_visuals()
	
	if farm_cooldown > 0.0:
		farm_cooldown -= delta

# ============================================================================
# SPEED / ROPE
# ============================================================================
func set_speed_modifier(mod: float) -> void:
	current_speed_mod = mod

func update_rope_visuals() -> void:
	if not is_instance_valid(attached_log) or not rope_line:
		if attached_log:
			detach_rope()
		return
	rope_line.visible = true
	var log_anchor = attached_log.get_rope_anchor_global()
	rope_line.points = [Vector2.ZERO, to_local(log_anchor)]
	if global_position.distance_to(attached_log.global_position) > rope_hard_limit:
		detach_rope()

func try_attach_rope() -> void:
	for body in rope_range.get_overlapping_bodies():
		if body.is_in_group("log"):
			attach_rope(body)
			return

func attach_rope(log_body: Node2D) -> void:
	if log_body.has_method("attach_to_target"):
		if not log_body.attach_to_target(self):
			return  # Log rejected the attachment (e.g. not ready yet)
	attached_log = log_body

func detach_rope() -> void:
	if attached_log and attached_log.has_method("detach"):
		attached_log.detach()
	attached_log = null
	if rope_line:
		rope_line.visible = false

# ============================================================================
# INPUT & MOVEMENT
# ============================================================================
func read_input() -> void:
	if not input_enabled:
		input_dir = Vector2.ZERO
		return

	# Prefer virtual joystick output (touch + mouse emulation) when active;
	# fall back to keyboard input action strengths otherwise. The joystick
	# is a CanvasLayer autoload (MobileJoystick) accessible by name.
	input_dir = _read_movement_input()

	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	if input_dir != Vector2.ZERO:
		last_dir = input_dir.normalized()

	# Number keys 1-0 for slot selection
	for i in range(10):
		if Input.is_key_pressed(KEY_1 + i):
			if _select_slot(i):
				return

	# ========================================================================
	# ATTACK (Space) — ONLY for chopping/attacking trees
	# ========================================================================
	if state != State.ATTACK and state != State.FARMING and Input.is_action_just_pressed("attack"):
		start_attack()

	# ========================================================================
	# INTERACT (E) — everything else: rope, tilling, planting, harvesting
	# ========================================================================
	if state != State.ATTACK and state != State.FARMING and Input.is_action_just_pressed("interact"):
		_do_interact()


# Reads movement input: virtual joystick when active, otherwise keyboard actions.
# Player script does NOT handle raw input events; it only consumes the vector
# output of the joystick system (or the input-map fallback for keyboard).
func _read_movement_input() -> Vector2:
	var js: MobileJoystickScript = _get_joystick()
	if js != null and js.is_active() and js.strength > 0.0:
		# The joystick outputs (direction, strength) — apply strength here.
		return js.direction * js.strength

	# Keyboard fallback: compose from the input map
	var v: Vector2 = Vector2(
		Input.get_action_strength("right") - Input.get_action_strength("left"),
		Input.get_action_strength("down") - Input.get_action_strength("up")
	)
	if v.length() > 1.0:
		v = v.normalized()
	return v


# Resolves the joystick autoload. Returns null if not present (e.g. headless tests).
func _get_joystick() -> MobileJoystickScript:
	var root: Node = get_tree().root if get_tree() else null
	if root == null:
		return null
	var node: Node = root.get_node_or_null("virtual_joystick")
	if node == null:
		return null
	return node as MobileJoystickScript


func handle_movement_state() -> void:
	if input_dir == Vector2.ZERO:
		state = State.IDLE
		velocity = Vector2.ZERO
		return
	# Walk vs run is driven by the joystick's analog strength: 0.6+ runs,
	# anything below walks. This is also compatible with keyboard via the
	# existing "run" action.
	var joystick_running: bool = false
	var js: MobileJoystickScript = _get_joystick()
	if js != null and js.is_active():
		joystick_running = js.strength >= 0.6
	var running: bool = joystick_running or Input.is_action_pressed("run")
	state = State.RUN if running else State.WALK
	velocity = input_dir * (run_speed if running else walk_speed) * current_speed_mod

# ============================================================================
# ATTACK
# ============================================================================
var _attack_min_frames: int = 0  # Prevents instant state flip when is_playing() is briefly false

func start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_attack_min_frames = 0
	anim.stop()
	anim.frame = 0
	var dir_key: String = get_dir(last_dir)
	anim.play("attack_" + dir_key)
	hitbox.position = HITBOX_OFFSETS.get(dir_key, Vector2(0, 24))
	hitbox.monitoring = true

func handle_attack_state() -> void:
	_attack_min_frames += 1
	if _attack_min_frames > 2 and not anim.is_playing():
		state = State.IDLE
		hitbox.monitoring = false

func _on_hitbox_body_entered(body: Node) -> void:
	if state == State.ATTACK and body.has_method("hit"):
		body.hit()

# ============================================================================
# FARMING ACTIONS
# ============================================================================
func _do_farming_action() -> bool:
	"""Perform a farming action based on the selected slot.
	Returns true if a farming action was actually performed.
	Only handles tilling (hoe) and planting (seeds).
	Axe/pickaxe are attack-only — this skips them."""
	if farm_cooldown > 0.0 or farm_manager == null:
		return false
	
	var target_tile: Vector2i = _get_target_tile()
	var tool_count: int = tool_inventory.size()
	
	if selected_slot < tool_count:
		var tool: ToolData = tool_inventory[selected_slot]
		match tool.tool_type:
			ToolData.ToolType.HOE:
				if farm_manager.till_tile(target_tile):
					farm_cooldown = FARM_COOLDOWN_TIME
					_do_farming_anim()
					return true
		# Axe, pickaxe etc. are attack-only — do nothing on interact
		return false
	else:
		var seed_idx: int = selected_slot - tool_count
		if seed_idx < seed_inventory.size():
			return _plant_seed(target_tile, seed_inventory[seed_idx])
		return false

func _plant_seed(tile_pos: Vector2i, crop: CropData) -> bool:
	"""Plant a seed at the given tile. Auto-tills grass if needed.
	Returns true if planting actually succeeded."""
	if farm_manager == null:
		return false

	# Auto-till if the tile is grass but not yet tilled.
	if farm_manager.is_grass_tile(tile_pos) and not farm_manager.get_tile_data(tile_pos)["tilled"]:
		farm_manager.till_tile(tile_pos)

	var planted: bool = false

	# Find the crop_id by matching the CropData reference, then plant.
	for crop_id in farm_manager.crop_registry.keys():
		if farm_manager.crop_registry[crop_id] == crop:
			if farm_manager.plant_crop(tile_pos, crop_id):
				planted = true
			break

	# Fallback: try matching by crop_name if direct reference failed.
	if not planted:
		var crop_name_key: String = crop.crop_name.to_lower().replace(" ", "_")
		if farm_manager.crop_registry.has(crop_name_key):
			if farm_manager.plant_crop(tile_pos, crop_name_key):
				planted = true

	if planted:
		farm_cooldown = FARM_COOLDOWN_TIME
		_do_farming_anim()

	return planted

func _do_interact() -> void:
	"""Interact button (E) handler: rope → farming → harvest."""
	# 1. Try rope attach/detach
	if attached_log != null:
		detach_rope()
		return
	try_attach_rope()
	if attached_log != null:
		return  # Successfully attached rope
	
	# 2. Try farming action (till soil / plant seed)
	if selected_slot >= 0 and _do_farming_action():
		return
	
	# 3. Try harvest crops
	_try_harvest()

func _try_harvest() -> void:
	"""Harvest mature crops at the tile in front of the player.
	Tree chopping is handled by Space → attack instead."""
	if farm_manager == null:
		return
	if farm_cooldown > 0.0:
		return
	var target_tile: Vector2i = _get_target_tile()
	var yield_count: int = farm_manager.harvest_tile(target_tile)
	if yield_count > 0:
		farm_cooldown = FARM_COOLDOWN_TIME
		_do_farming_anim()

func _do_farming_anim() -> void:
	state = State.FARMING
	velocity = Vector2.ZERO
	anim.stop()
	anim.frame = 0
	anim.play("attack_" + get_dir(last_dir))
	await get_tree().create_timer(0.3).timeout
	if state == State.FARMING:
		state = State.IDLE

func handle_farming_state() -> void:
	pass

func _get_target_tile() -> Vector2i:
	var offset: Vector2 = last_dir * 32.0
	var world_pos: Vector2 = global_position + offset
	if farm_manager:
		return farm_manager.get_tile_pos(world_pos)
	return Vector2i(floori(world_pos.x / 32), floori(world_pos.y / 32))

# ============================================================================
# SLOT SELECTION
# ============================================================================
func _select_slot(index: int) -> bool:
	var total: int = tool_inventory.size() + seed_inventory.size()
	if index < 0 or index >= total:
		return false
	if selected_slot == index:
		return true
	selected_slot = index
	if action_bar:
		action_bar.select_slot(index)
	_update_equipped_tool()
	return true

func _on_action_bar_selected(slot_index: int) -> void:
	selected_slot = slot_index
	_update_equipped_tool()

# ============================================================================
# EQUIPPED TOOL VISUAL (right-hand sprite)
# ============================================================================

func _update_equipped_tool() -> void:
	"""Show or hide the tool sprite on the player's right hand based on selection."""
	# Tool sprite is hidden — the action bar highlight shows the equipped item
	if tool_sprite != null:
		tool_sprite.visible = false


func _update_tool_position() -> void:
	"""Position the tool sprite based on the player's facing direction."""
	if tool_sprite == null or not tool_sprite.visible:
		return
	
	var dir_key: String = get_dir(last_dir)
	var offset: Vector2 = TOOL_OFFSETS.get(dir_key, Vector2(18, -14))
	tool_sprite.position = offset
	
	# Flip tool horizontally when facing left (W, NW, SW) so it faces correct way
	var flip_h: bool = dir_key in ["W", "NW", "SW"]
	tool_sprite.flip_h = flip_h

# ============================================================================
# ANIMATION
# ============================================================================
func apply_anim_offset() -> void:
	# Attack and Farming both use the larger 96x96 spritesheet; idle/walk/run use 64x64.
	anim.offset = ATTACK_OFFSET if state in [State.ATTACK, State.FARMING] else BASE_OFFSET

func update_animation() -> void:
	var dir = get_dir(last_dir)
	match state:
		State.IDLE:
			anim.play("idle_" + dir)
		State.WALK:
			anim.play("walk_" + dir)
		State.RUN:
			anim.play("run_" + dir)

func get_dir(v: Vector2) -> String:
	if v == Vector2.ZERO:
		return "S"
	var angle: float = rad_to_deg(atan2(v.y, v.x))
	if angle < 0:
		angle += 360
	if angle < 22.5 or angle >= 337.5:
		return "E"
	elif angle < 67.5:
		return "SE"
	elif angle < 112.5:
		return "S"
	elif angle < 157.5:
		return "SW"
	elif angle < 202.5:
		return "W"
	elif angle < 247.5:
		return "NW"
	elif angle < 292.5:
		return "N"
	else:
		return "NE"
