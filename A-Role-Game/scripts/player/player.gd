class_name Player
extends CharacterBody2D


## Player controller.
##
## Handles:
## - Movement
## - Combat
## - Player states
## - Health reactions
##
## Components:
## - MovementComponent
## - PlayerAnimationComponent
## - AttackComponent
## - HealthComponent
## - StaminaComponent
## - BlockComponent


# ==================================================
# COMPONENT REFERENCES
# ==================================================

@onready var movement: MovementComponent = $MovementComponent

@onready var animator: PlayerAnimationComponent = $PlayerAnimationComponent

@onready var attack: AttackComponent = $AttackComponent

@onready var health: HealthComponent = $HealthComponent

@onready var stamina: StaminaComponent = $StaminaComponent


# ==================================================
# STATE
# ==================================================

enum State
{
	IDLE,
	WALK,
	RUN,
	SPRINT,
	ATTACK,
	BOW,
	DEAD,
	DASH,
	ROLL
}


var state: State = State.IDLE

var last_direction: Vector2 = Vector2.DOWN

var input_enabled: bool = true


# ==================================================
# ATTACK COMBO
# ==================================================

var combo_step: int = 0

var combo_timer: float = 0.0

const COMBO_WINDOW: float = 0.6
const HOLD_ATTACK_THRESHOLD: float = 0.18
const STAB_SEQUENCE: Array[String] = ["stab", "stab1", "stab2"]
const HEAVY_SEQUENCE: Array[String] = ["attack", "attack2", "attack3"]
const DIRECTION_KEYS: Array[String] = ["E", "W", "N", "S", "NE", "NW", "SE", "SW"]


# ==================================================
# BACKDASH
# ==================================================

var previous_direction: Vector2 = Vector2.DOWN

var direction_switch_timer: float = 999.0

const BACKDASH_WINDOW: float = 0.3


# ==================================================
# DASH / ROLL COOLDOWN
# ==================================================

## Minimum delay (seconds) before dash/roll can be used again after one ends.
@export var dash_cooldown: float = 0.3

## Countdown timer for the dash/roll cooldown (0 = ready).
var dash_cooldown_timer: float = 0.0


# ==================================================
# READY
# ==================================================

func _ready() -> void:

	# Set FLOATING motion mode for top-down physics (better push behavior)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


	if attack:

		attack.attack_started.connect(
			_on_attack_started
		)


	if animator:

		animator.attack_animation_finished.connect(
			_on_attack_animation_finished
		)


	# Connect to the animated sprite directly to handle dash/roll/walktorun end
	var anim_sprite: AnimatedSprite2D = $player_animation

	if anim_sprite and not anim_sprite.animation_finished.is_connected(
		_on_player_animation_finished
	):

		anim_sprite.animation_finished.connect(
			_on_player_animation_finished
		)



	if health:

		health.damaged.connect(
			_on_damaged
		)

		health.died.connect(
			_on_died
		)



	_ensure_player_directional_placeholders()
	_setup_combat_debug_hud()

	# Block component removed


# ==================================================
# MAIN LOOP
# ==================================================

func _physics_process(_delta: float) -> void:


	if state == State.DEAD:

		velocity = Vector2.ZERO

		move_and_slide()

		return



	if not input_enabled:

		velocity = Vector2.ZERO

		move_and_slide()

		return



	_process_input()



	# Attack, dash, and roll override movement input.
	# Attack zeros velocity (no movement during attack).
	# Dash/roll preserve their own velocity set by movement.calculate_velocity().
	var overrides_movement: bool = (
		state == State.ATTACK
		or state == State.BOW
		or state == State.DASH
		or state == State.ROLL
	)

	if not overrides_movement:

		_process_movement()



	if state == State.ATTACK or state == State.BOW:

		velocity = Vector2.ZERO



	move_and_slide()

	# Push enemies when colliding with them (prevents getting stuck)
	_push_colliding_enemies()


	_update_animation()





# ==================================================
# MOVEMENT
# ==================================================

func _process_movement() -> void:


	if not movement:

		return



	movement.read_input()



	if movement.input_dir != Vector2.ZERO:

		var new_dir: Vector2 = movement.input_dir.normalized()

		if new_dir != last_direction:

			previous_direction = last_direction

			direction_switch_timer = 0.0

		last_direction = new_dir



	velocity = movement.calculate_velocity()



	match movement.move_state:


		MovementComponent.MoveState.IDLE:

			state = State.IDLE


		MovementComponent.MoveState.WALK:

			state = State.WALK


		MovementComponent.MoveState.RUN:

			state = State.RUN


		MovementComponent.MoveState.SPRINT:

			state = State.SPRINT





# ==================================================
# PROCESS (combo timer, direction switch timer)
# ==================================================

func _process(delta: float) -> void:

	# Only count combo timer outside of attack state
	# During attack, combo is tracked via the buffered input system
	if combo_step > 0 and state != State.ATTACK:

		combo_timer += delta

		if combo_timer > current_combo_window:

			_reset_combo()

	if attack_pressing and Input.is_action_pressed("attack"):
		attack_hold_time += delta

	if bow_is_charging:
		bow_charge_time += delta
		if not bow_loaded and bow_charge_time >= bow_min_charge_time:
			bow_loaded = true
		if bow_loaded and animator != null:
			var expected_loaded: String = "bowloadedidle_" + bow_charge_direction
			var anim_sprite: AnimatedSprite2D = $player_animation
			if anim_sprite != null and anim_sprite.animation != expected_loaded:
				animator.play_bow_loaded_idle(bow_charge_direction)

	if direction_switch_timer < BACKDASH_WINDOW:

		direction_switch_timer += delta

	if dash_cooldown_timer > 0:

		dash_cooldown_timer = max(0.0, dash_cooldown_timer - delta)

	_update_combat_debug_hud()



# ==================================================
# INPUT
# ==================================================

var combo_buffered: bool = false
var queued_combo_variant: String = ""
var attack_hold_time: float = 0.0
var attack_pressing: bool = false
var current_combo_variant: String = ""
var current_combo_window: float = COMBO_WINDOW

@export_category("Combat - Combo")
@export var combo_damage_light: Array[int] = [2, 3, 4]
@export var combo_damage_heavy: Array[int] = [4, 6, 8]
@export var combo_duration_light: Array[float] = [0.24, 0.26, 0.30]
@export var combo_duration_heavy: Array[float] = [0.38, 0.44, 0.52]
@export var combo_cooldown_light: Array[float] = [0.10, 0.12, 0.18]
@export var combo_cooldown_heavy: Array[float] = [0.16, 0.20, 0.28]
@export var combo_input_window_light: Array[float] = [0.55, 0.48, 0.40]
@export var combo_input_window_heavy: Array[float] = [0.62, 0.55, 0.48]
@export var combo_hit_start_ratio_light: Array[float] = [0.20, 0.22, 0.26]
@export var combo_hit_end_ratio_light: Array[float] = [0.62, 0.66, 0.72]
@export var combo_hit_start_ratio_heavy: Array[float] = [0.28, 0.30, 0.34]
@export var combo_hit_end_ratio_heavy: Array[float] = [0.78, 0.82, 0.88]

@export_category("Combat - Bow")
@export var bow_projectile_scene: PackedScene = preload("res://scenes/characters/projectile/projectile.tscn")
@export var bow_projectile_damage: int = 2
@export var bow_projectile_speed: float = 420.0
@export var bow_projectile_lifetime: float = 1.5
@export var bow_spawn_offset: Vector2 = Vector2(28.0, 0.0)
@export var bow_min_charge_time: float = 0.15
@export var bow_full_charge_time: float = 0.90
@export var bow_cancel_if_under_min_charge: bool = true
@export var bow_max_damage_multiplier: float = 2.0
@export var bow_max_speed_multiplier: float = 1.7
@export var bow_require_ammo: bool = false
@export var bow_ammo_item_id: String = "arrow"
@export var bow_ammo_per_shot: int = 1

@export_category("Debug")
@export var show_combat_debug_hud: bool = false

var bow_is_charging: bool = false
var bow_loaded: bool = false
var bow_charge_direction: String = "S"
var bow_charge_time: float = 0.0
var _combat_debug_layer: CanvasLayer = null
var _combat_debug_label: Label = null

func _process_input() -> void:

	if InputMap.has_action("bow") and Input.is_action_just_pressed("bow"):
		_begin_bow_charge()

	if InputMap.has_action("bow") and Input.is_action_just_released("bow"):
		_release_bow()

	if Input.is_action_just_pressed("attack"):
		attack_pressing = true
		attack_hold_time = 0.0

	if Input.is_action_just_released("attack"):
		var release_variant: String = _attack_variant_from_hold(attack_hold_time)
		attack_pressing = false
		if state == State.ATTACK:
			combo_buffered = true
			queued_combo_variant = release_variant
		elif combo_step > 0 and combo_timer < COMBO_WINDOW:
			_advance_combo(release_variant)
		else:
			_start_attack(release_variant)

	if Input.is_action_just_pressed("dash"):

		_start_dash()


	if Input.is_action_just_pressed("roll"):

		_start_roll()

	if InputMap.has_action("interact") and Input.is_action_just_pressed("interact"):
		_handle_interact()


	# Block, squat, and jump removed





# ==================================================
# ATTACK
# ==================================================

func _start_attack(variant: String = "") -> void:

	if not attack:

		return

	if not attack.can_attack():

		return

	state = State.ATTACK
	combo_step = 1
	combo_timer = 0.0
	current_combo_variant = variant if variant != "" else _attack_variant_from_hold(attack_hold_time)

	var direction: String = "S"
	if animator:
		direction = animator.get_dir_from_vector(last_direction)

	_play_combo_animation_step(direction, combo_step, current_combo_variant)


func _advance_combo(variant: String = "") -> void:

	if not attack:
		return

	combo_step += 1
	combo_timer = 0.0
	if combo_step > 3:
		combo_step = 1

	if variant != "":
		current_combo_variant = variant

	var direction: String = "S"
	if animator:
		direction = animator.get_dir_from_vector(last_direction)

	state = State.ATTACK
	_play_combo_animation_step(direction, combo_step, current_combo_variant)


func _attack_variant_from_hold(hold_time: float) -> String:
	if hold_time >= HOLD_ATTACK_THRESHOLD:
		return "heavy"
	return "light"


func _combo_damage_for(step: int, variant: String) -> int:
	var index: int = clampi(step - 1, 0, 2)
	if variant == "heavy":
		return int(combo_damage_heavy[index])
	return int(combo_damage_light[index])


func _combo_duration_for(step: int, variant: String) -> float:
	var index: int = clampi(step - 1, 0, 2)
	if variant == "heavy":
		return float(combo_duration_heavy[index])
	return float(combo_duration_light[index])


func _combo_cooldown_for(step: int, variant: String) -> float:
	var index: int = clampi(step - 1, 0, 2)
	if variant == "heavy":
		return float(combo_cooldown_heavy[index])
	return float(combo_cooldown_light[index])


func _combo_window_for(step: int, variant: String) -> float:
	var index: int = clampi(step - 1, 0, 2)
	if variant == "heavy":
		return float(combo_input_window_heavy[index])
	return float(combo_input_window_light[index])


func _combo_hit_start_for(step: int, variant: String) -> float:
	var index: int = clampi(step - 1, 0, 2)
	if variant == "heavy":
		return float(combo_hit_start_ratio_heavy[index])
	return float(combo_hit_start_ratio_light[index])


func _combo_hit_end_for(step: int, variant: String) -> float:
	var index: int = clampi(step - 1, 0, 2)
	if variant == "heavy":
		return float(combo_hit_end_ratio_heavy[index])
	return float(combo_hit_end_ratio_light[index])


func _play_combo_animation_step(direction: String, step: int, variant: String) -> void:
	var damage_value: int = _combo_damage_for(step, variant)
	var duration_value: float = _combo_duration_for(step, variant)
	var cooldown_value: float = _combo_cooldown_for(step, variant)
	var hit_start_ratio: float = _combo_hit_start_for(step, variant)
	var hit_end_ratio: float = _combo_hit_end_for(step, variant)
	current_combo_window = _combo_window_for(step, variant)
	if variant == "heavy":
		if step == 1:
			if animator != null:
				animator.play_attack(direction)
		elif step == 2:
			if animator != null:
				animator.play_attack2(direction)
		else:
			if animator != null:
				animator.play_attack3(direction)
	else:
		if step == 1:
			if animator != null:
				animator.play_stab(direction)
		elif step == 2:
			if animator != null:
				animator.play_stab1(direction)
		else:
			if animator != null:
				animator.play_stab2(direction)
	attack.start_attack_forced_custom_window(direction, damage_value, duration_value, cooldown_value, hit_start_ratio, hit_end_ratio)


func _begin_bow_charge() -> void:
	if state == State.DEAD or state == State.DASH or state == State.ROLL:
		return
	if bow_is_charging:
		return
	bow_is_charging = true
	bow_loaded = false
	bow_charge_time = 0.0
	state = State.BOW
	if animator != null:
		bow_charge_direction = animator.get_dir_from_vector(last_direction)
		animator.play_bow_reload(bow_charge_direction)


func _release_bow() -> void:
	if not bow_is_charging:
		return
	bow_is_charging = false
	var charge_ratio: float = _get_bow_charge_ratio()
	if bow_cancel_if_under_min_charge and charge_ratio <= 0.0:
		bow_loaded = false
		state = State.IDLE
		return
	if not bow_loaded:
		state = State.IDLE
		return
	if bow_require_ammo and not _consume_bow_ammo(bow_ammo_per_shot):
		state = State.IDLE
		return
	if animator != null:
		animator.play_bow_fire(bow_charge_direction)
	_fire_bow_projectile(bow_charge_direction, charge_ratio)
	bow_loaded = false
	bow_charge_time = 0.0
	state = State.IDLE


func _fire_bow_projectile(direction_key: String, charge_ratio: float) -> void:
	if bow_projectile_scene == null:
		return
	var projectile: Node = bow_projectile_scene.instantiate()
	if projectile == null:
		return
	var dir_vec: Vector2 = _dir_key_to_vector(direction_key)
	projectile.global_position = global_position + dir_vec * bow_spawn_offset.length()
	if projectile is Projectile:
		var shot: Projectile = projectile as Projectile
		var damage_mult: float = lerpf(1.0, bow_max_damage_multiplier, charge_ratio)
		var speed_mult: float = lerpf(1.0, bow_max_speed_multiplier, charge_ratio)
		shot.damage = maxi(1, int(round(float(bow_projectile_damage) * damage_mult)))
		shot.speed = bow_projectile_speed * speed_mult
		shot.lifetime = bow_projectile_lifetime
		shot.init(dir_vec, self)
	get_tree().current_scene.add_child(projectile)


func _dir_key_to_vector(direction_key: String) -> Vector2:
	match direction_key:
		"E": return Vector2.RIGHT
		"NE": return Vector2(1.0, -1.0).normalized()
		"N": return Vector2.UP
		"NW": return Vector2(-1.0, -1.0).normalized()
		"W": return Vector2.LEFT
		"SW": return Vector2(-1.0, 1.0).normalized()
		"S": return Vector2.DOWN
		"SE": return Vector2(1.0, 1.0).normalized()
		_: return Vector2.DOWN


func _get_bow_charge_ratio() -> float:
	if bow_full_charge_time <= bow_min_charge_time:
		return 1.0 if bow_charge_time >= bow_min_charge_time else 0.0
	var t: float = (bow_charge_time - bow_min_charge_time) / (bow_full_charge_time - bow_min_charge_time)
	return clampf(t, 0.0, 1.0)


func _consume_bow_ammo(amount: int) -> bool:
	if amount <= 0:
		return true
	var inventory: InventoryComponent = _find_inventory_component()
	if inventory == null:
		return false
	var removed: int = inventory.remove_item(bow_ammo_item_id, amount)
	return removed >= amount


func _find_inventory_component() -> InventoryComponent:
	for child: Node in get_children():
		if child is InventoryComponent:
			return child as InventoryComponent
	return null


func _handle_interact() -> void:
	if state == State.DEAD:
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var chest_ui: CanvasLayer = tree.root.get_node_or_null("ChestUI") as CanvasLayer
	if chest_ui != null and chest_ui.visible:
		if chest_ui.has_method(&"close_ui"):
			chest_ui.call("close_ui")
		return

	var chest_nodes: Array[Node] = tree.get_nodes_in_group(&"chest")
	var nearest_chest: ChestComponent = null
	var nearest_distance: float = INF
	for node: Node in chest_nodes:
		var chest: ChestComponent = node as ChestComponent
		if chest == null:
			continue
		if not chest.is_player_in_zone():
			continue
		var chest_entity: Node2D = chest.get_entity() as Node2D
		if chest_entity == null:
			continue
		var dist: float = global_position.distance_to(chest_entity.global_position)
		if dist < nearest_distance:
			nearest_distance = dist
			nearest_chest = chest

	if nearest_chest == null:
		return

	nearest_chest.open_for(self)
	if chest_ui != null and chest_ui.has_method(&"show_for"):
		set_player_paused(true)
		chest_ui.call("show_for", nearest_chest)


func _reset_combo() -> void:

	combo_step = 0
	combo_timer = 0.0
	current_combo_variant = ""
	queued_combo_variant = ""
	current_combo_window = COMBO_WINDOW



func _cancel_attack_state() -> void:


	if attack:

		attack.end_attack()


	if animator:

		animator.cancel_attack()


	combo_step = 0
	combo_timer = 0.0
	combo_buffered = false
	queued_combo_variant = ""
	current_combo_variant = ""
	attack_pressing = false
	attack_hold_time = 0.0



func _start_dash() -> void:


	if not movement:

		return


	if state == State.DASH or state == State.ROLL or state == State.DEAD:

		return


	if dash_cooldown_timer > 0:

		return


	# Can interrupt attack with a dash
	if state == State.ATTACK:

		_cancel_attack_state()


	state = State.DASH


	# Backdash should be intentional: only trigger when current movement input is
	# opposite to facing direction. Otherwise do a normal forward dash.
	var dash_input_dir: Vector2 = movement.input_dir.normalized() if movement.input_dir.length() > 0.01 else Vector2.ZERO
	var facing_dir: Vector2 = last_direction.normalized() if last_direction.length() > 0.01 else Vector2.DOWN
	var should_backdash: bool = dash_input_dir != Vector2.ZERO and dash_input_dir.dot(facing_dir) <= -0.35

	if should_backdash:
		movement.start_backdash(-facing_dir)
		if animator:
			animator.play_backdash(
				animator.get_dir_from_vector(-facing_dir)
			)
	else:
		movement.start_dash(facing_dir)
		if animator:
			animator.play_dash(
				animator.get_dir_from_vector(facing_dir)
			)


	velocity = movement.calculate_velocity()


	# Dash duration is frame-dependent; animation_finished signal handles ending it


func _start_roll() -> void:


	if not movement:

		return


	if state == State.DASH or state == State.ROLL or state == State.DEAD:

		return


	if dash_cooldown_timer > 0:

		return


	# Can interrupt attack with a roll
	if state == State.ATTACK:

		_cancel_attack_state()


	state = State.ROLL

	movement.start_roll(last_direction)

	velocity = movement.calculate_velocity()


	if animator:

		animator.play_roll(
			animator.get_dir_from_vector(last_direction)
		)


	# Roll duration is frame-dependent; animation_finished signal handles ending it



# Block, squat, and jump removed





func _on_player_animation_finished() -> void:

	# Handle dash/roll end — these are frame-dependent, not timer-based
	if state == State.DASH:

		state = State.IDLE

		dash_cooldown_timer = dash_cooldown

		if movement:

			movement.end_special()


	elif state == State.ROLL:

		state = State.IDLE

		dash_cooldown_timer = dash_cooldown

		if movement:

			movement.end_special()


	# Walktorun is handled by the animation component's play_run detection
	# ATTACK is handled by attack_animation_finished signal


func _on_attack_started(_direction: String) -> void:
	# Combo logic drives animation explicitly via _play_combo_animation_step.
	# Keep handler for compatibility but do not override active combo animations.
	if combo_step > 0:
		return





func _on_attack_animation_finished(completed_combo_step: int) -> void:

	# End the attack component's attack state
	if attack:

		attack.end_attack()


	# If combo was buffered during this attack animation, advance immediately
	if combo_buffered and completed_combo_step < 3:
		combo_buffered = false
		var buffered_variant: String = queued_combo_variant
		queued_combo_variant = ""
		_advance_combo(buffered_variant)
		return


	# No further combo — return to idle
	combo_step = 0

	combo_timer = 0.0

	state = State.IDLE





# ==================================================
# DAMAGE
# ==================================================

func _is_invincible_frame() -> bool:


	# Always invincible when dead
	if state == State.DEAD:

		return true


	# Only dash/roll/backdash have invincibility windows
	if state != State.DASH and state != State.ROLL:

		return false


	var anim_sprite: AnimatedSprite2D = $player_animation

	if not anim_sprite or not anim_sprite.is_playing():

		return false


	var anim_name: String = anim_sprite.animation

	if not anim_name.begins_with("dash_") and not anim_name.begins_with("roll_") and not anim_name.begins_with("backdash_"):

		return false


	var total_frames: int = anim_sprite.sprite_frames.get_frame_count(

		anim_name
	)

	var half_frames: int = int(total_frames / 2.0)


	# First half of the animation = invincible
	return anim_sprite.frame < half_frames



func _on_damaged(
	_amount: int,
	_remaining: int
) -> void:


	if _is_invincible_frame():

		return

	# Hurt animation removed — player uses visual hit indicator later
	# For now, just let the player continue whatever they were doing





func _on_died() -> void:


	state = State.DEAD

	velocity = Vector2.ZERO



	# Hide the player — they disappear on death
	visible = false



	# Disable collision so the player doesn't interact while dead
	# Use set_deferred to avoid 'Can't change this state while flushing queries'
	$CollisionShape2D.set_deferred(&"disabled", true)



	# Start the respawn timer
	_start_respawn()



func _start_respawn() -> void:

	# Wait ~3.5 seconds before respawning
	await get_tree().create_timer(3.5).timeout



	# Don't proceed if the node was freed while we were waiting
	if not is_instance_valid(self):

		return



	# Teleport the player to the world origin
	global_position = Vector2.ZERO



	# Reset health component
	if health:

		health.current_hp = health.max_hp

		health.is_dead = false

		health.is_invincible = false

		health.invincibility_timer = 0.0



	# Reset state
	state = State.IDLE



	# Re-enable collision
	$CollisionShape2D.disabled = false



	# Show the player again
	visible = true



	# Camera2D has position_smoothing_enabled = true with speed 8.0,
	# so it will smoothly travel from the death location to the spawn point.





# ==================================================
# ENEMY PUSH
# ==================================================

func _push_colliding_enemies() -> void:

	# When the player collides with enemies, push them away
	# to prevent the 'getting stuck' problem.
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if not collision:
			continue
		var collider := collision.get_collider()
		if collider is CharacterBody2D and collider != self:
			# Check if this has a HealthComponent (it is an enemy)
			if collider.get_node_or_null("HealthComponent") != null:
				# Push the enemy away from the player
				var push_dir: Vector2 = (collider.global_position - global_position).normalized()
				var dot_product: float = collider.velocity.dot(push_dir)
				# Only add push if enemy is not already moving away fast enough
				if dot_product < 80.0:
					collider.velocity += push_dir * 200.0



# Block callbacks removed


# ==================================================
# ANIMATION
# ==================================================

func _update_animation() -> void:


	if not animator:

		return



	# Never override attack or bow action animations
	if state == State.ATTACK or state == State.BOW:

		return



	var direction: String = animator.get_dir_from_vector(
		last_direction
	)



	match state:


		State.IDLE:

			animator.play_idle(
				direction
			)


		State.WALK:

			animator.play_walk(
				direction
			)


		State.RUN:

			animator.play_run(
				direction
			)


		State.SPRINT:

			animator.play_sprint(
				direction
			)


		State.DEAD:

			pass


		# DASH and ROLL are handled by the animation component's
		# _on_movement_state_changed signal handler, not here.
		# This avoids re-starting their animations every physics frame.

		# Block removed





# ==================================================
# DEBUG + ANIMATION PLACEHOLDERS
# ==================================================

func _ensure_player_directional_placeholders() -> void:
	if animator == null or animator.anim_sprite == null:
		return
	var sf: SpriteFrames = animator.anim_sprite.sprite_frames
	if sf == null:
		return
	var prefixes: Array[String] = ["stab", "stab1", "stab2", "bowreload", "bowloadedidle", "bowfire"]
	for prefix: String in prefixes:
		var source_anim: StringName = StringName(prefix + "_E")
		if not sf.has_animation(source_anim):
			continue
		for dir_key: String in DIRECTION_KEYS:
			var target_anim: StringName = StringName(prefix + "_" + dir_key)
			if sf.has_animation(target_anim):
				continue
			sf.add_animation(target_anim)
			sf.set_animation_speed(target_anim, sf.get_animation_speed(source_anim))
			sf.set_animation_loop(target_anim, sf.get_animation_loop(source_anim))
			var frame_count: int = sf.get_frame_count(source_anim)
			for i: int in range(frame_count):
				sf.add_frame(target_anim, sf.get_frame_texture(source_anim, i), sf.get_frame_duration(source_anim, i), -1)


func _setup_combat_debug_hud() -> void:
	if not show_combat_debug_hud:
		if _combat_debug_layer != null:
			_combat_debug_layer.visible = false
		return
	if _combat_debug_layer != null:
		_combat_debug_layer.visible = true
		return
	_combat_debug_layer = CanvasLayer.new()
	_combat_debug_layer.layer = 50
	_combat_debug_layer.name = "CombatDebugHUD"
	add_child(_combat_debug_layer)
	_combat_debug_label = Label.new()
	_combat_debug_label.name = "CombatDebugLabel"
	_combat_debug_label.position = Vector2(14.0, 14.0)
	_combat_debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_combat_debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_combat_debug_layer.add_child(_combat_debug_label)


func _update_combat_debug_hud() -> void:
	if not show_combat_debug_hud:
		if _combat_debug_layer != null:
			_combat_debug_layer.visible = false
		return
	if _combat_debug_layer == null or _combat_debug_label == null:
		_setup_combat_debug_hud()
	if _combat_debug_label == null:
		return
	if _combat_debug_layer != null:
		_combat_debug_layer.visible = true
	var charge_ratio: float = _get_bow_charge_ratio()
	var text_lines: Array[String] = []
	text_lines.append("State: %s" % [str(state)])
	text_lines.append("Combo: %s step=%d buffered=%s" % [current_combo_variant, combo_step, str(combo_buffered)])
	text_lines.append("Combo Window: %.2f" % [current_combo_window])
	text_lines.append("Attack Hold: %.2f" % [attack_hold_time])
	text_lines.append("Bow Charge: %.2f (ratio %.2f)" % [bow_charge_time, charge_ratio])
	text_lines.append("Bow Loaded: %s" % [str(bow_loaded)])
	if bow_require_ammo:
		var inventory: InventoryComponent = _find_inventory_component()
		var ammo_count: int = inventory.count_of(bow_ammo_item_id) if inventory != null else -1
		text_lines.append("Ammo %s: %d" % [bow_ammo_item_id, ammo_count])
	_combat_debug_label.text = "\n".join(text_lines)


# ==================================================
# PUBLIC FUNCTIONS
# ==================================================

func set_player_paused(paused: bool) -> void:


	input_enabled = not paused



	if movement:

		movement.set_input_enabled(
			not paused
		)



	if paused:

		velocity = Vector2.ZERO





func set_speed_modifier(mod: float) -> void:


	if movement:

		movement.set_speed_modifier(
			mod
		)
