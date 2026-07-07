class_name EnemyAIComponent
extends Component


## Generic enemy AI component.
##
## Handles:
## - Player detection
## - Chasing (with collision push-avoidance)
## - Melee attacks
## - Special attacks (charge/spin for orc 2 style)
## - Damage reactions
## - Death
## - Knockback
## - Sprite flipping (with centering)
##
## Requires:
## Parent:
## CharacterBody2D
##
## Sibling Components:
## - AttackComponent
## - HealthComponent
##
## Child:
## - AnimatedSprite2D


enum State {
	IDLE,
	CHASE,
	ATTACK,
	SPECIAL_ATTACK,
	HURT,
	DEAD
}



# ==================================================
# REFERENCES
# ==================================================

@export_category("References")

@export var sprite: AnimatedSprite2D



# ==================================================
# MOVEMENT
# ==================================================

@export_category("Movement")

@export var move_speed: float = 45.0

@export var detection_range: float = 160.0

## Minimum distance to maintain from the player when at attack range.
## Prevents enemies from walking INTO the player and getting stuck.
@export var personal_space: float = 28.0

## How strongly the enemy pushes away when the player is inside personal space.
@export var push_away_strength: float = 60.0

## How often (seconds) the enemy pauses during chase to idle briefly.
## Makes enemies look like they're sizing up the player instead of charging non-stop.
@export var chase_idle_interval: float = 3.0

## How long (seconds) each idle pause during chase lasts.
@export var chase_idle_duration: float = 1.0


# ==================================================
# LINE OF SIGHT
# ==================================================

@export_category("Line of Sight")

## Master toggle for line-of-sight checks. When enabled, enemies need
## clear LoS to the player (or a breadcrumb) to chase and attack.
@export var los_enabled: bool = true

## Physics layers to check as obstacles for LoS raycasts.
## Layer 1 is typically terrain/walls. Characters are layer 7.
@export var los_collision_mask: int = 1

## Maximum number of breadcrumbs an enemy will follow before giving up.
@export var max_breadcrumb_steps: int = 5

## Range to search for breadcrumbs. If 0, uses detection_range.
@export var breadcrumb_search_range: float = 0.0

## When enabled, draws a colored line showing the LOS ray.
## Green = clear LOS, Red = blocked.
@export var debug_draw_los: bool = false


# ==================================================
# COMBAT
# ==================================================

@export_category("Combat")

@export var attack_range: float = 32.0

@export var attack_cooldown: float = 1.25



# ==================================================
# SPECIAL ATTACK (charge/spin)
# ==================================================

@export_category("Special Attack")

## Whether this enemy can use special attacks (charge/spin).
@export var special_attack_enabled: bool = false

## Chance (0.0 - 1.0) to use a special attack instead of a normal one.
@export var special_attack_chance: float = 0.3

## Animation name for the charge/preparation phase.
@export var special_prep_animation: String = ""

## Animation name for the looping spin phase.
@export var special_spin_animation: String = ""

## Animation name for the end/spin-down phase.
@export var special_end_animation: String = ""

## Speed during the charge/spin dash toward the player.
@export var special_charge_speed: float = 120.0

## How long the charge-up phase lasts (seconds).
@export var special_prep_duration: float = 0.8

## How long the spinning phase lasts (seconds).
@export var special_spin_duration: float = 2.0

## How long the end-spin phase lasts (seconds).
@export var special_end_duration: float = 0.6

## Node path to a dedicated spin hitbox Area2D (e.g. "hitbox_spin").
## If set, this hitbox is enabled during the spin phase and disabled afterward.
@export var hitbox_spin_path: NodePath = NodePath("")

## Damage dealt by the spin hitbox.
@export var spin_attack_damage: int = 1


# ==================================================
# PROJECTILE FX (visual-only attack effect)
# ==================================================

## Name of an animation on this entity's AnimatedSprite2D to use as a
## visual projectile effect (e.g. "crystal orc attack 2 projectiles").
## If set, the special attack spawns this animation in front of the entity
## instead of dashing. The effect plays once in place and disappears.
## Use projectile_custom_prep for the wind-up animation on the entity itself.
@export var projectile_fx_animation: String = ""

## Animation to play on the enemy during the prep wind-up (e.g. "crystal orc attack 2").
## Only used when projectile_fx_animation is set.
@export var projectile_custom_prep: String = ""

## Offset from the entity's center where the FX spawns.
@export var projectile_spawn_offset: Vector2 = Vector2(32, 0)

## Damage dealt by the projectile FX hitbox (0 = no damage).
@export var projectile_damage: int = 1

## Size of the projectile FX collision hitbox (width, height).
@export var projectile_hitbox_size: Vector2 = Vector2(64, 64)

## If set (> 0), the enemy will stop and fire projectiles when the player
## is within this range, instead of chasing all the way to melee range.
@export var ranged_attack_range: float = 0.0


# ==================================================
# ANIMATION NAMES
# ==================================================

@export_category("Animations")

@export var idle_animation: String = "orc 1 idle"

@export var walk_animation: String = "orc 1 walk"

@export var attack_animation: String = "orc 1 attack"

@export var hurt_animation: String = "orc 1 hurt"

@export var death_animation: String = "orc 1 death"



# ==================================================
# SPRITE CENTERING
# ==================================================

@export_category("Sprite Setup")

## (sprite centering uses AnimatedSprite2D.centered instead)



# ==================================================
# VARIABLES
# ==================================================

var entity: CharacterBody2D

var attack_component: AttackComponent

var health_component: HealthComponent


var player: Node2D = null


var state: State = State.IDLE


var attack_timer: float = 0.0

var hurt_timer: float = 0.0

## Chase idle cycle timer. When > 0, enemy chases; when <= 0, enemy idles briefly.
var chase_idle_cycle: float = 0.0

## True when the enemy was blocked during chase (stuck on other enemies).
## Used to force idle instead of running in place.
var _was_blocked: bool = false


# Breadcrumb following state
## Index of the breadcrumb the enemy is currently following (-1 = none).
var _breadcrumb_target_index: int = -1

## How many breadcrumbs the enemy has followed on this trail (resets on new trail).
var _breadcrumb_steps_taken: int = 0

## Cooldown timer to prevent per-frame breadcrumb re-evaluation.
var _breadcrumb_update_timer: float = 0.0

## Debug Line2D node for visualizing the LOS ray.
var _debug_los_line: Line2D = null

## Debug: logs the exact coordinates being set on the LOS line.
var _debug_last_coords: String = ""

## How often (seconds) to re-check LoS when following a breadcrumb.
const BREADCRUMB_UPDATE_INTERVAL: float = 0.25


# Special attack state machine
var _special_phase: String = ""  # "prep", "spin", "end"
var _special_timer: float = 0.0
var _spin_hit_targets: Array[Node] = []



var hitbox_spin: Area2D = null



# ==================================================
# READY
# ==================================================

func _component_ready() -> void:

	entity = get_entity() as CharacterBody2D

	# Set motion mode to FLOATING for top-down movement so enemies
	# don't behave like platformer characters with floor/wall/ceiling.
	entity.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	if sprite == null:
		sprite = entity.get_node_or_null(
			"orc 1 animation"
		) as AnimatedSprite2D

	# Center the sprite so flip_h rotates around the character's center
	# instead of the texture corner, preventing visual position shifting.
	if sprite:
		sprite.centered = true

	attack_component = get_sibling_component(
		AttackComponent
	) as AttackComponent

	health_component = get_sibling_component(
		HealthComponent
	) as HealthComponent



	if health_component:

		health_component.damaged.connect(
			_on_damaged
		)


		health_component.died.connect(
			_on_died
		)



	# Find and prepare the spin hitbox (optional, for special attacks)
	if not hitbox_spin_path.is_empty():
		var spin_hb: Node = get_node_or_null(hitbox_spin_path)
		if spin_hb is Area2D:
			hitbox_spin = spin_hb as Area2D
			hitbox_spin.monitoring = false
			hitbox_spin.body_entered.connect(_on_spin_hitbox_entered)

	if attack_component:

		attack_component.attack_started.connect(
			_on_attack_started
		)


		attack_component.attack_finished.connect(
			_on_attack_finished
		)



	# Create debug LOS line if enabled.
	# MUST use call_deferred — entity is still setting up children during
	# _component_ready(), so direct add_child() fails silently.
	if debug_draw_los:
		_debug_los_line = Line2D.new()
		_debug_los_line.name = "DebugLOSLine"
		_debug_los_line.width = 4.0
		_debug_los_line.default_color = Color.YELLOW
		_debug_los_line.antialiased = true
		# Set test points immediately so it shows as soon as it's parented
		_debug_los_line.points = PackedVector2Array([
			Vector2.ZERO,
			Vector2(50, 0)
		])
		entity.add_child.call_deferred(_debug_los_line)
		print("[ENEMY AI] Debug LOS line created for: ", entity.name)

	play_animation(idle_animation)

	# Initialize chase idle cycle with a random offset for variety
	chase_idle_cycle = randf_range(0.5, chase_idle_interval)



# ==================================================
# PROCESS
# ==================================================

func _physics_process(delta: float) -> void:


	if not active:

		return



	if entity == null:

		return



	if attack_timer > 0:

		attack_timer -= delta

	# Chase idle cycle  - counts down during chase, resets after idle pause
	if chase_idle_cycle > -999:
		chase_idle_cycle -= delta

	# Track pre-move position for blockage detection
	var _pre_move_pos := entity.global_position



	match state:

		State.IDLE:
			_process_idle()

		State.CHASE:
			_process_chase()

		State.ATTACK:
			_process_attack()

		State.SPECIAL_ATTACK:
			_process_special_attack(delta)

		State.HURT:
			_process_hurt(delta)

		State.DEAD:
			entity.velocity = Vector2.ZERO
			return



	entity.move_and_slide()

	# Detect if enemy is blocked during chase (stuck on other enemies).
	# Compares actual movement to expected movement; if much less, enemy is stuck.
	if state == State.CHASE:
		var expected_move := entity.velocity.length() * delta
		var moved_dist := entity.global_position.distance_to(_pre_move_pos)
		_was_blocked = expected_move > 0.5 and moved_dist < expected_move * 0.3
		if _was_blocked and chase_idle_cycle > 0:
			chase_idle_cycle = -chase_idle_duration * 0.3
	else:
		_was_blocked = false



# ==================================================
# IDLE
# ==================================================

func _process_idle() -> void:


	entity.velocity = Vector2.ZERO


	play_animation(idle_animation)



	find_player()



	if player and distance_to_player() <= detection_range:

		state = State.CHASE





# ==================================================
# CHASE
# ==================================================

## Attempt to fire a ranged (projectile FX) special attack.
## Called from _process_chase when player is within ranged_attack_range.
func try_ranged_attack() -> void:

	if state == State.ATTACK or state == State.SPECIAL_ATTACK:
		return

	if attack_timer > 0:
		return

	_start_special_attack()




func _process_chase() -> void:

	if not player or not is_instance_valid(player):
		state = State.IDLE
		return

	# --- Line of sight check ---
	if los_enabled and not has_los_to(player.global_position):
		# No LoS to player — try following breadcrumbs
		if _try_breadcrumb_chase():
			return
		# No breadcrumbs reachable — give up
		_breadcrumb_target_index = -1
		_breadcrumb_steps_taken = 0
		chase_idle_cycle = -999
		state = State.IDLE
		return

	# Direct LoS to player — reset breadcrumb tracking
	_breadcrumb_target_index = -1
	_breadcrumb_steps_taken = 0
	_breadcrumb_update_timer = 0.0

	var distance := distance_to_player()

	# Direction FROM the enemy TO the player
	var direction: Vector2 = (
		player.global_position -
		entity.global_position
	).normalized()

	# --- If within attack range ---
	if distance <= attack_range:
		# Push away from player slightly to avoid getting stuck in each other
		entity.velocity = -direction * push_away_strength
		try_attack()
		return

	# --- If within ranged attack range and has projectile FX ---
	if not projectile_fx_animation.is_empty() and distance <= ranged_attack_range:
		entity.velocity = Vector2.ZERO
		update_facing(direction)
		play_animation(idle_animation)
		try_ranged_attack()
		return

	# --- If too close (inside personal space but not at attack range) ---
	if distance < personal_space:
		entity.velocity = -direction * (move_speed * 0.4)
		update_facing(direction)
		play_animation(walk_animation)
		return

	# --- Normal chase ---
	# Occasionally pause to idle, making the enemy look like it's sizing
	# up the player instead of charging non-stop (only when not in combat).
	if chase_idle_cycle <= 0:
		entity.velocity = Vector2.ZERO
		play_animation(idle_animation)
		if chase_idle_cycle <= -chase_idle_duration:
			chase_idle_cycle = chase_idle_interval + randf_range(-0.5, 0.5)
		return

	# Enemies only visually face left/right, so they prefer to approach
	# from the side rather than diagonally. First step into the player's
	# Y-row, then close the X gap so attacks naturally come from the side.
	var y_diff := player.global_position.y - entity.global_position.y
	var x_diff := player.global_position.x - entity.global_position.x

	if abs(y_diff) > 24.0:
		# Step 1: Get on the same Y level as the player
		entity.velocity = Vector2(0.0, sign(y_diff) * move_speed)
		# Face toward the player even while moving vertically
		if abs(x_diff) > 8.0:
			update_facing(Vector2(sign(x_diff), 0.0))
	else:
		# Step 2: Y-aligned — close the horizontal gap
		if abs(x_diff) > 8.0:
			entity.velocity = Vector2(sign(x_diff) * move_speed, 0.0)
			update_facing(entity.velocity)
		else:
			# On top of the player — nudge directly
			entity.velocity = direction * (move_speed * 0.5)
			update_facing(direction)

	play_animation(walk_animation)

	if distance > detection_range * 1.5:
		state = State.IDLE






# ==================================================
# ATTACK
# ==================================================

func try_attack() -> void:

	if state == State.ATTACK or state == State.SPECIAL_ATTACK:
		return

	if attack_timer > 0:
		return

	if attack_component == null:
		return

	# Check if we should use a special attack instead
	if special_attack_enabled and randf() < special_attack_chance:
		_start_special_attack()
		return

	var direction := get_attack_direction()
	attack_component.start_attack(direction)
	attack_timer = attack_cooldown
	state = State.ATTACK



func _process_attack() -> void:

	# Keep slight push-away during attack to avoid getting stuck
	if player and is_instance_valid(player):
		var dir := (entity.global_position - player.global_position).normalized()
		entity.velocity = dir * (push_away_strength * 0.5)
	else:
		entity.velocity = Vector2.ZERO

	# Wait until AttackComponent finishes.
	if attack_component:
		if not attack_component.is_attacking_now():
			if player:
				state = State.CHASE
			else:
				state = State.IDLE






# ==================================================
# SPECIAL ATTACK (charge + spin)
# ==================================================

func _start_special_attack() -> void:

	state = State.SPECIAL_ATTACK
	_special_phase = "prep"
	_special_timer = special_prep_duration
	_spin_hit_targets.clear()

	if attack_component and attack_component.hitbox:
		attack_component.hitbox.monitoring = false

	if hitbox_spin:
		hitbox_spin.monitoring = false

	# Use projectile_custom_prep if projectile FX mode, else the normal prep anim
	var prep_anim: String = special_prep_animation
	if not projectile_fx_animation.is_empty() and not projectile_custom_prep.is_empty():
		prep_anim = projectile_custom_prep

	if sprite and not prep_anim.is_empty():
		sprite.play(prep_anim)



## Spawns a projectile FX with collision hitbox in front of the entity.
## Creates a temporary Area2D containing:
## - AnimatedSprite2D (visual, from entity's sprite_frames)
## - CollisionShape2D (hitbox, deals projectile_damage)
## Self-destructs when the animation finishes.
func _spawn_projectiles() -> void:

	if projectile_fx_animation.is_empty():
		return
	if not sprite or not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation(projectile_fx_animation):
		return

	# Face toward the player for spawn offset direction
	var base_dir: Vector2 = Vector2.RIGHT
	if player and is_instance_valid(player):
		base_dir = (player.global_position - entity.global_position).normalized()
		update_facing(base_dir)

	# Create the container Area2D
	var fx_area := Area2D.new()
	fx_area.name = &"ProjectileFX"
	fx_area.collision_layer = 7
	fx_area.collision_mask = 7

	# Create the AnimatedSprite2D child (visual)
	var fx_sprite := AnimatedSprite2D.new()
	fx_sprite.name = &"Sprite"
	fx_sprite.sprite_frames = sprite.sprite_frames
	fx_sprite.animation = projectile_fx_animation
	fx_sprite.centered = true
	fx_sprite.z_as_relative = false
	fx_sprite.z_index = 1
	# Flip the projectile visual to match the orc's facing direction
	fx_sprite.flip_h = sprite.flip_h
	fx_area.add_child(fx_sprite)

	# Create the CollisionShape2D child (hitbox)
	var fx_shape := CollisionShape2D.new()
	fx_shape.name = &"Hitbox"
	var rect := RectangleShape2D.new()
	rect.size = projectile_hitbox_size
	fx_shape.shape = rect
	fx_area.add_child(fx_shape)

	# When the animation finishes, destroy the entire Area2D
	fx_sprite.animation_finished.connect(fx_area.queue_free)

	# Damage on contact
	if projectile_damage > 0:
		fx_area.body_entered.connect(
			func(body: Node) -> void:
				if body == entity:
					return
				# Prevent friendly fire
				if not entity.is_in_group("player") and not body.is_in_group("player"):
					if attack_component and not attack_component.can_hit_allies:
						return
				var health := body.get_node_or_null("HealthComponent") as HealthComponent
				if health:
					health.take_damage(projectile_damage, entity)
				elif body.has_method("hit"):
					body.hit(entity, projectile_damage)
		)

	entity.get_parent().add_child(fx_area)
	fx_area.global_position = entity.global_position + \
		projectile_spawn_offset.rotated(base_dir.angle())
	fx_sprite.play()



func _process_special_attack(delta: float) -> void:

	if not player or not is_instance_valid(player):
		state = State.IDLE
		return

	_special_timer -= delta

	match _special_phase:

		"prep":
			entity.velocity = Vector2.ZERO
			if _special_timer <= 0:
				_special_phase = "spin"
				_special_timer = special_spin_duration

				if not projectile_fx_animation.is_empty():
					# Projectile FX mode: spawn visual effect instead of dash/spin
					_spawn_projectiles()
					update_facing((player.global_position - entity.global_position).normalized())
				else:
					# Melee spin mode: enable spin hitbox, play spin animation
					if hitbox_spin:
						hitbox_spin.monitoring = true
					if attack_component and attack_component.hitbox:
						attack_component.hitbox.monitoring = false
					if sprite and not special_spin_animation.is_empty():
						sprite.play(special_spin_animation)

		"spin":
			if not projectile_fx_animation.is_empty():
				# Projectile FX mode: brief pause after spawning, then transition
				entity.velocity = Vector2.ZERO
			else:
				# Melee spin mode: dash toward player
				var dir: Vector2 = (player.global_position - entity.global_position).normalized()
				entity.velocity = dir * special_charge_speed
				update_facing(dir)
			if _special_timer <= 0:
				_special_phase = "end"
				_special_timer = special_end_duration
				if not projectile_fx_animation.is_empty():
					# Projectile FX mode: no spin hitbox or melee attack at end
					pass
				else:
					# Disable spin hitbox, re-enable regular hitbox
					if hitbox_spin:
						hitbox_spin.monitoring = false
					if attack_component and attack_component.can_attack():
						var atk_dir: String = get_attack_direction()
						attack_component.start_attack(atk_dir)
				if sprite and not special_end_animation.is_empty():
					sprite.play(special_end_animation)

		"end":
			entity.velocity = entity.velocity.move_toward(
				Vector2.ZERO,
				special_charge_speed * delta * 2.0
			)
			if _special_timer <= 0:
				if hitbox_spin:
					hitbox_spin.monitoring = false
				if attack_component:
					attack_component.end_attack()
				attack_timer = attack_cooldown
				if player:
					state = State.CHASE
				else:
					state = State.IDLE



# ==================================================
# SPIN HITBOX
# ==================================================

## Handles body_entered on the dedicated spin hitbox.
## Deals spin_attack_damage and tracks hit targets to prevent double-hits.
func _on_spin_hitbox_entered(body: Node) -> void:

	if body == entity:
		return

	if body in _spin_hit_targets:
		return

	_spin_hit_targets.append(body)

	# Try HealthComponent first
	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.take_damage(spin_attack_damage, entity)
		return

	# Fallback to hit() method
	if body.has_method("hit"):
		body.hit(entity, spin_attack_damage)



# ==================================================
# HURT
# ==================================================

func _process_hurt(delta: float) -> void:


	entity.velocity = Vector2.ZERO



	hurt_timer -= delta



	if hurt_timer <= 0:


		if player:

			state = State.CHASE

		else:

			state = State.IDLE






# ==================================================
# PLAYER
# ==================================================

func find_player() -> void:


	if player and is_instance_valid(player):

		return



	var players := get_tree().get_nodes_in_group(
		"player"
	)



	if players.size() > 0:

		player = players[0] as Node2D





func distance_to_player() -> float:


	if player == null:

		return INF



	return entity.global_position.distance_to(
		player.global_position
	)






# ==================================================
# ATTACK DIRECTION
# ==================================================

func get_attack_direction() -> String:


	if player == null:

		return "S"



	var direction := (
		player.global_position -
		entity.global_position
	).normalized()



	if abs(direction.x) > abs(direction.y):

		return "E" if direction.x > 0 else "W"



	return "S" if direction.y > 0 else "N"






# ==================================================
# DAMAGE RECEIVING
# ==================================================

func hit(attacker: Node, damage: int) -> void:


	if health_component:

		health_component.take_damage(
			damage,
			attacker
		)




func apply_knockback(direction: Vector2, force: float) -> void:


	if entity:

		entity.velocity += direction * force






# ==================================================
# ATTACK SIGNALS
# ==================================================

func _on_attack_started(_direction: String) -> void:


	play_animation(
		attack_animation
	)




func _on_attack_finished() -> void:

	if state == State.DEAD:
		return

	# Don't let this fire during special attacks (handled by _process_special_attack)
	if state == State.SPECIAL_ATTACK:
		return

	if player:
		state = State.CHASE
	else:
		state = State.IDLE






# ==================================================
# HEALTH
# ==================================================

func _on_damaged(_amount:int, _remaining:int) -> void:


	if state == State.DEAD:

		return



	state = State.HURT


	hurt_timer = 0.25



	play_animation(
		hurt_animation
	)






func _on_died() -> void:


	state = State.DEAD


	entity.velocity = Vector2.ZERO



	play_animation(
		death_animation
	)



	if sprite:

		await sprite.animation_finished



	entity.queue_free()






# ==================================================
# ANIMATION
# ==================================================

func play_animation(animation_name: String) -> void:


	if sprite == null:

		return



	if sprite.animation != animation_name:

		sprite.play(animation_name)



func update_facing(direction: Vector2) -> void:


	if sprite and direction.x != 0:

		sprite.flip_h = direction.x < 0



# ==================================================
# LINE OF SIGHT
# ==================================================

## Returns true if there's a clear line of sight from this enemy
## to the given target position (no terrain/wall obstacles).
func has_los_to(target_pos: Vector2) -> bool:

	if entity == null:
		return false

	var space_state: PhysicsDirectSpaceState2D = (
		entity.get_world_2d().direct_space_state
	)

	var query := PhysicsRayQueryParameters2D.create(
		entity.global_position,
		target_pos,
		los_collision_mask,
		[entity]  # Exclude self from collision
	)

	# Also exclude the player so the ray doesn't stop on them
	if player and is_instance_valid(player):
		query.exclude.append(player)

	var result: Dictionary = space_state.intersect_ray(query)

	# --- Debug LOS visualization ---
	# Line2D is a child of the entity, so use LOCAL coordinates
	if debug_draw_los and _debug_los_line:
		var clear_los: bool = result.is_empty()
		var local_target: Vector2 = entity.to_local(target_pos)
		_debug_los_line.points = PackedVector2Array([
			Vector2.ZERO,
			local_target
		])
		_debug_los_line.default_color = Color.GREEN if clear_los else Color.RED
		# Log coordinates every 30 frames so we can see what's happening
		var coords_str: String = "pts=[0,0 → %.1f,%.1f] %s dist=%.0f" % [
			local_target.x, local_target.y,
			"CLEAR" if clear_los else "BLOCKED",
			entity.global_position.distance_to(target_pos)
		]
		if coords_str != _debug_last_coords:
			_debug_last_coords = coords_str
			print("[LOS DBG] ", entity.name, " ", coords_str)

	# If nothing was hit, LoS is clear
	return result.is_empty()



# ==================================================
# BREADCRUMB FOLLOWING
# ==================================================

## Attempt to follow the player's breadcrumb trail.
## Returns true if a breadcrumb was found and the enemy is moving toward it.
func _try_breadcrumb_chase() -> bool:

	var trail: Array[Vector2] = BreadcrumbManager.get_trail()

	if trail.is_empty():
		return false

	# --- Timer-based re-evaluation ---
	# Only check LoS / advance to next breadcrumb every ~0.25s
	# to prevent per-frame jitter from geometry edge flicker.
	_breadcrumb_update_timer -= entity.get_physics_process_delta_time()
	var should_update: bool = _breadcrumb_update_timer <= 0.0

	# Already following a breadcrumb
	if _breadcrumb_target_index >= 0 and _breadcrumb_target_index < trail.size():

		var target: Vector2 = trail[_breadcrumb_target_index]

		# Periodically re-check LoS to the current breadcrumb
		if should_update:
			_breadcrumb_update_timer = BREADCRUMB_UPDATE_INTERVAL

			if not has_los_to(target):
				# Lost LoS during update window — give up
				_breadcrumb_target_index = -1
				_breadcrumb_steps_taken = 0
				return false

			var dist: float = entity.global_position.distance_to(target)

			if dist <= 16.0:
				# Reached the breadcrumb — advance to the next one
				_breadcrumb_steps_taken += 1

				# Check if we've exceeded the max follow steps
				if _breadcrumb_steps_taken > max_breadcrumb_steps:
					_breadcrumb_target_index = -1
					_breadcrumb_steps_taken = 0
					return false

				# Try to go to the next breadcrumb (newer = closer to player)
				var next_idx: int = _breadcrumb_target_index + 1

				if next_idx >= trail.size():
					# Caught up to the trail end — check direct LoS to player
					if has_los_to(player.global_position):
						_breadcrumb_target_index = -1
						_breadcrumb_steps_taken = 0
						return false
					else:
						_breadcrumb_target_index = -1
						_breadcrumb_steps_taken = 0
						return false

				# Check LoS to the next breadcrumb
				if has_los_to(trail[next_idx]):
					_breadcrumb_target_index = next_idx
				else:
					_breadcrumb_target_index = -1
					_breadcrumb_steps_taken = 0
					return false

		# Move toward the target (or current breadcrumb if index changed)
		var move_target: Vector2 = trail[_breadcrumb_target_index]
		_move_toward(move_target)
		return true

	# --- Find a breadcrumb to start following ---
	if should_update:
		_breadcrumb_update_timer = BREADCRUMB_UPDATE_INTERVAL

		var search_range: float = (
			breadcrumb_search_range
			if breadcrumb_search_range > 0.0
			else detection_range
		)

		# Search from newest (closest to player) backward to oldest
		for i in range(trail.size() - 1, -1, -1):
			var crumb: Vector2 = trail[i]
			var crumb_dist: float = entity.global_position.distance_to(crumb)

			if crumb_dist <= search_range and has_los_to(crumb):
				_breadcrumb_target_index = i
				_breadcrumb_steps_taken = 0
				_move_toward(crumb)
				return true

	return false


## Move the enemy toward a target position with velocity smoothing
## (lerp) to prevent jittery per-frame direction snaps.
func _move_toward(target: Vector2) -> void:

	var desired_dir: Vector2 = (
		target - entity.global_position
	).normalized()

	# Smooth velocity changes instead of snapping instantly
	var desired_vel: Vector2 = desired_dir * move_speed
	entity.velocity = entity.velocity.lerp(desired_vel, 0.15)

	update_facing(desired_dir)

	# Only play animation if actually moving (prevent flickering)
	if entity.velocity.length_squared() > 1.0:
		play_animation(walk_animation)
