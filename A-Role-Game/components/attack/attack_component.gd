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



	is_attacking = true


	current_direction = direction


	attack_timer = attack_duration


	cooldown_timer = attack_cooldown


	hit_targets.clear()



	if hitbox:

		hitbox.position = hitbox_offsets.get(
			direction,
			Vector2.ZERO
		)


		hitbox.monitoring = true



	attack_started.emit(
		direction
	)





func end_attack() -> void:


	if not is_attacking:

		return



	is_attacking = false


	if hitbox:

		hitbox.monitoring = false



	hit_targets.clear()



	attack_finished.emit()





func cancel_attack() -> void:


	end_attack()





# ==================================================
# DAMAGE DETECTION
# ==================================================

func _on_hitbox_body_entered(body: Node) -> void:


	if not is_attacking:

		return



	if body == get_entity():

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
