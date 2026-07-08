class_name AttackComponent
extends Component


## Universal melee attack component.
##
## Used by:
## - Player
## - Enemies
## - Bosses
##
## Requires:
## Entity:
## - Area2D named "hitbox"
##
## Target:
## - HealthComponent
## OR
## - hit(attacker, damage) function



signal attack_started(direction: String)
signal attack_finished()
signal body_hit(body: Node)



# ==================================================
# REFERENCES
# ==================================================

@export_category("References")

@export var hitbox: Area2D = null



# ==================================================
# DAMAGE SETTINGS
# ==================================================

@export_category("Damage")

@export var attack_damage: int = 1

## If true, this entity's attacks can also damage non-player entities (allies/enemies).
## Default false: enemies only damage the player.
@export var can_hit_allies: bool = false

@export var knockback_force: float = 80.0



# ==================================================
# TIMING SETTINGS
# ==================================================

@export_category("Timing")

## Total length of attack state.
@export var attack_duration: float = 0.65

## Time before another attack can happen.
@export var attack_cooldown: float = 0.8



# ==================================================
# HITBOX SETTINGS
# ==================================================

@export_category("Hitbox Position")

@export var hitbox_offsets: Dictionary = {

	"S": Vector2(0, 24),

	"SE": Vector2(17, 17),

	"E": Vector2(24, 0),

	"NE": Vector2(17, -17),

	"N": Vector2(0, -24),

	"NW": Vector2(-17, -17),

	"W": Vector2(-24, 0),

	"SW": Vector2(-17, 17)

}



# ==================================================
# STATE
# ==================================================

var is_attacking: bool = false

var attack_timer: float = 0.0

var cooldown_timer: float = 0.0

var current_direction: String = "S"

var hit_targets: Array[Node] = []
var attack_total_duration: float = 0.0
var attack_elapsed: float = 0.0

@export var hit_active_start_ratio: float = 0.10
@export var hit_active_end_ratio: float = 0.65



# ==================================================
# READY
# ==================================================

func _component_ready() -> void:


	if hitbox == null:

		hitbox = get_entity().get_node_or_null(
			"hitbox"
		) as Area2D



	if hitbox:

		hitbox.monitoring = false

		hitbox.body_entered.connect(
			_on_hitbox_body_entered
		)





# ==================================================
# PROCESS
# ==================================================

func _process(delta: float) -> void:


	if cooldown_timer > 0:

		cooldown_timer -= delta



	if not is_attacking:

		return



	attack_timer -= delta
	attack_elapsed += delta
	_update_hitbox_active_window()



	if attack_timer <= 0:

		end_attack()





# ==================================================
# ATTACK CONTROL
# ==================================================

func can_attack() -> bool:

	return (
		not is_attacking
		and cooldown_timer <= 0
	)





func start_attack(direction: String = "S") -> void:


	if not can_attack():

		return


	_start_attack_internal(direction, attack_damage, attack_duration, attack_cooldown)


func start_attack_with_damage(direction: String, damage_value: int) -> void:
	if not can_attack():
		return
	_start_attack_internal(direction, damage_value, attack_duration, attack_cooldown)


func start_attack_forced_with_damage(direction: String, damage_value: int) -> void:
	_start_attack_internal(direction, damage_value, attack_duration, attack_cooldown)


func start_attack_with_damage_timing(direction: String, damage_value: int, duration_value: float, cooldown_value: float) -> void:
	if not can_attack():
		return
	_start_attack_internal(direction, damage_value, duration_value, cooldown_value)


func start_attack_forced_custom(direction: String, damage_value: int, duration_value: float, cooldown_value: float) -> void:
	_start_attack_internal(direction, damage_value, duration_value, cooldown_value)


func start_attack_forced_custom_window(direction: String, damage_value: int, duration_value: float, cooldown_value: float, hit_start_ratio_value: float, hit_end_ratio_value: float) -> void:
	_start_attack_internal(direction, damage_value, duration_value, cooldown_value, hit_start_ratio_value, hit_end_ratio_value)


func _start_attack_internal(direction: String, damage_value: int, duration_value: float, cooldown_value: float, hit_start_ratio_value: float = -1.0, hit_end_ratio_value: float = -1.0) -> void:
	is_attacking = true
	current_direction = direction
	attack_damage = damage_value
	attack_timer = duration_value
	attack_total_duration = maxf(0.001, duration_value)
	attack_elapsed = 0.0
	cooldown_timer = cooldown_value
	hit_targets.clear()
	if hit_start_ratio_value >= 0.0:
		hit_active_start_ratio = clampf(hit_start_ratio_value, 0.0, 1.0)
	if hit_end_ratio_value >= 0.0:
		hit_active_end_ratio = clampf(hit_end_ratio_value, 0.0, 1.0)
	if hitbox:
		hitbox.position = hitbox_offsets.get(direction, Vector2.ZERO)
		hitbox.monitoring = false
	_update_hitbox_active_window()
	attack_started.emit(direction)





func end_attack() -> void:


	if not is_attacking:

		return



	is_attacking = false
	attack_elapsed = 0.0
	attack_total_duration = 0.0


	if hitbox:

		hitbox.monitoring = false



	hit_targets.clear()

	attack_finished.emit()


## Force-start an attack, bypassing can_attack checks.
## Used by combo systems where attacks must chain without cooldown.
func start_attack_forced(direction: String = "S") -> void:
	_start_attack_internal(direction, attack_damage, attack_duration, attack_cooldown)





func cancel_attack() -> void:


	end_attack()





# ==================================================
# DAMAGE DETECTION
# ==================================================

func _update_hitbox_active_window() -> void:
	if hitbox == null:
		return
	if not is_attacking:
		hitbox.monitoring = false
		return
	if attack_total_duration <= 0.0:
		hitbox.monitoring = true
		return
	var progress: float = clampf(attack_elapsed / attack_total_duration, 0.0, 1.0)
	var start_ratio: float = minf(hit_active_start_ratio, hit_active_end_ratio)
	var end_ratio: float = maxf(hit_active_start_ratio, hit_active_end_ratio)
	hitbox.monitoring = progress >= start_ratio and progress <= end_ratio


func _on_hitbox_body_entered(body: Node) -> void:


	if not is_attacking:

		return



	if body == get_entity():
		return

	# Prevent friendly fire: enemies only damage the player unless can_hit_allies is true
	if not get_entity().is_in_group("player") and not body.is_in_group("player"):
		if not can_hit_allies:
			return

	if body in hit_targets:

		return



	hit_targets.append(body)



	var health_component := (
		body.get_node_or_null(
			"HealthComponent"
		)
		as HealthComponent
	)



	if health_component:


		health_component.take_damage(
			attack_damage,
			get_entity()
		)


		_apply_knockback(
			body
		)


		body_hit.emit(
			body
		)


		# Show floating damage number
		if attack_damage > 0 and get_tree() != null:
			var world: Node = get_tree().current_scene
			if world != null:
				DamageNumber.spawn(attack_damage, body.global_position, world)


		return





	if body.has_method("hit"):


		body.hit(
			get_entity(),
			attack_damage
		)


		_apply_knockback(
			body
		)


		body_hit.emit(
			body
		)





# ==================================================
# KNOCKBACK
# ==================================================

func _apply_knockback(target: Node) -> void:


	if knockback_force <= 0:

		return



	if target is CharacterBody2D:


		var direction: Vector2 = (
			target.global_position -
			get_entity().global_position
		).normalized()



		target.velocity += (
			direction *
			knockback_force
		)





# ==================================================
# HELPERS
# ==================================================

func is_attacking_now() -> bool:

	return is_attacking
