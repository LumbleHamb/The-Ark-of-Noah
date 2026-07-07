class_name HealthComponent
extends Component


## Reusable health and damage system.
##
## Used by:
## - Player
## - Enemies
## - Bosses
## - Destructible objects
##
## Works with AttackComponent.


# ==================================================
# SIGNALS
# ==================================================

signal health_changed(old_value: int, new_value: int)

signal damaged(amount: int, remaining: int)

signal healed(amount: int, current: int)

signal died()

signal knockback_received(direction: Vector2, force: float)



# ==================================================
# HEALTH SETTINGS
# ==================================================

@export_category("Health Settings")

@export var min_hp: int = 0

@export var max_hp: int = 10

## Set -1 to start at max health.
@export var start_hp: int = -1



# ==================================================
# COMBAT SETTINGS
# ==================================================

@export_category("Combat Settings")


## Invincibility frames after taking damage.
@export var invincibility_time: float = 0.35


## Allows this entity to receive knockback.
@export var can_be_knocked_back: bool = true



# ==================================================
# VARIABLES
# ==================================================

var current_hp: int = 0

var is_dead: bool = false

var is_invincible: bool = false

var invincibility_timer: float = 0.0


## Last thing that damaged this entity.
var last_attacker: Node = null



# ==================================================
# COMPONENT READY
# ==================================================

func _component_ready() -> void:


	if start_hp < 0:

		current_hp = max_hp

	else:

		current_hp = clampi(
			start_hp,
			min_hp,
			max_hp
		)



# ==================================================
# PROCESS
# ==================================================

func _process(delta: float) -> void:


	if invincibility_timer <= 0:

		return



	invincibility_timer -= delta



	if invincibility_timer <= 0:

		is_invincible = false



# ==================================================
# DAMAGE
# ==================================================


## Called by AttackComponent.
##
## Example:
## target.hit(attacker, damage)

func hit(
	attacker: Node,
	damage_amount: int = 1
) -> void:


	take_damage(
		damage_amount,
		attacker
	)



## Applies damage.

func take_damage(
	amount: int,
	attacker: Node = null
) -> void:


	if not active:

		return



	if is_dead:

		return



	if is_invincible:

		return



	if amount <= 0:

		return



	last_attacker = attacker



	var old_hp: int = current_hp



	current_hp = clampi(
		current_hp - amount,
		0,
		max_hp
	)



	var actual_damage: int = old_hp - current_hp



	if actual_damage <= 0:

		return



	health_changed.emit(
		old_hp,
		current_hp
	)



	damaged.emit(
		actual_damage,
		current_hp
	)



	_start_invincibility()



	if current_hp <= 0:

		_die()



# ==================================================
# DEATH
# ==================================================

func _die() -> void:


	if is_dead:

		return



	is_dead = true


	current_hp = 0


	died.emit()



# ==================================================
# INVINCIBILITY
# ==================================================

func _start_invincibility() -> void:


	if invincibility_time <= 0:

		return



	is_invincible = true


	invincibility_timer = invincibility_time



# ==================================================
# KNOCKBACK
# ==================================================

func apply_knockback(
	direction: Vector2,
	force: float
) -> void:


	if not can_be_knocked_back:

		return



	knockback_received.emit(
		direction,
		force
	)



# ==================================================
# HEALING
# ==================================================

func heal(amount: int) -> void:


	if not active:

		return



	if is_dead:

		return



	if amount <= 0:

		return



	var old_hp: int = current_hp



	current_hp = mini(
		current_hp + amount,
		max_hp
	)



	var healed_amount: int = current_hp - old_hp



	if healed_amount > 0:


		health_changed.emit(
			old_hp,
			current_hp
		)



		healed.emit(
			healed_amount,
			current_hp
		)



# ==================================================
# UTILITY
# ==================================================

func set_hp(value: int) -> void:


	var old_hp: int = current_hp



	current_hp = clampi(
		value,
		0,
		max_hp
	)



	health_changed.emit(
		old_hp,
		current_hp
	)



	if current_hp <= 0:

		_die()



func get_hp() -> int:

	return current_hp



func get_hp_ratio() -> float:


	if max_hp <= 0:

		return 0.0



	return float(current_hp) / float(max_hp)



func reset() -> void:


	is_dead = false


	current_hp = max_hp


	is_invincible = false


	invincibility_timer = 0.0


	last_attacker = null



func increase_max_hp(amount: int) -> void:


	max_hp += amount


	current_hp += amount
