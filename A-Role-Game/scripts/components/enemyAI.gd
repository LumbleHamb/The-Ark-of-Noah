class_name EnemyAIComponent
extends Component


## Generic enemy AI component.
##
## Handles:
## - Player detection
## - Chasing
## - Melee attacks
## - Damage reactions
## - Death
## - Knockback
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



# ==================================================
# COMBAT
# ==================================================

@export_category("Combat")

@export var attack_range: float = 32.0

@export var attack_cooldown: float = 1.25



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
# VARIABLES
# ==================================================

var entity: CharacterBody2D

var attack_component: AttackComponent

var health_component: HealthComponent


var player: Node2D = null


var state: State = State.IDLE


var attack_timer: float = 0.0

var hurt_timer: float = 0.0



# ==================================================
# READY
# ==================================================

func _component_ready() -> void:


	entity = get_entity() as CharacterBody2D


	if sprite == null:

		sprite = entity.get_node_or_null(
			"orc 1 animation"
		) as AnimatedSprite2D



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



	if attack_component:

		attack_component.attack_started.connect(
			_on_attack_started
		)


		attack_component.attack_finished.connect(
			_on_attack_finished
		)



	play_animation(idle_animation)




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



	match state:


		State.IDLE:

			_process_idle()



		State.CHASE:

			_process_chase()



		State.ATTACK:

			_process_attack()



		State.HURT:

			_process_hurt(delta)



		State.DEAD:

			entity.velocity = Vector2.ZERO

			return



	entity.move_and_slide()




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

func _process_chase() -> void:


	if not player or not is_instance_valid(player):

		state = State.IDLE

		return



	var distance := distance_to_player()



	if distance <= attack_range:

		entity.velocity = Vector2.ZERO

		try_attack()

		return



	var direction: Vector2 = (
		player.global_position -
		entity.global_position
	).normalized()



	entity.velocity = direction * move_speed



	update_facing(direction)


	play_animation(walk_animation)



	if distance > detection_range * 1.5:

		state = State.IDLE






# ==================================================
# ATTACK
# ==================================================

func try_attack() -> void:


	if state == State.ATTACK:

		return



	if attack_timer > 0:

		return



	if attack_component == null:

		return



	var direction := get_attack_direction()



	attack_component.start_attack(direction)



	attack_timer = attack_cooldown


	state = State.ATTACK




func _process_attack() -> void:


	entity.velocity = Vector2.ZERO



	# Wait until AttackComponent finishes.

	if attack_component:

		if not attack_component.is_attacking_now():

			if player:

				state = State.CHASE

			else:

				state = State.IDLE






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
