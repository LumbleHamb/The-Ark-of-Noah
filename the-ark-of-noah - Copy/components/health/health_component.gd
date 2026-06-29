class_name HealthComponent
extends Component

## Reusable health/damage system for any destructible entity.
## Call take_damage() to deal damage; connect died signal for death logic.

signal health_changed(old_value: int, new_value: int)
signal damaged(amount: int, remaining: int)
signal healed(amount: int, current: int)
signal died()

@export var min_hp: int = 0
@export var max_hp: int = 2
@export var start_hp: int = -1

var current_hp: int = 0:
	set(v):
		var old := current_hp
		current_hp = clampi(v, 0, max_hp)
		if current_hp != old:
			health_changed.emit(old, current_hp)

var is_dead: bool = false

func _component_ready() -> void:
	if start_hp < 0:
		current_hp = randi_range(min_hp, max_hp)
	else:
		current_hp = clampi(start_hp, min_hp, max_hp)

## Applies damage. Emits damaged and possibly died signals.
func take_damage(amount: int) -> void:
	if is_dead or not active:
		return
	current_hp -= amount
	var dealt := mini(amount, current_hp + amount)
	damaged.emit(dealt, current_hp)
	if current_hp <= 0:
		is_dead = true
		current_hp = 0
		died.emit()

## Heals by the given amount, up to max_hp.
func heal(amount: int) -> void:
	if is_dead or not active:
		return
	var old := current_hp
	current_hp = mini(current_hp + amount, max_hp)
	var actual := current_hp - old
	if actual > 0:
		healed.emit(actual, current_hp)

## Sets HP directly, clamped to valid range.
func set_hp(value: int) -> void:
	current_hp = clampi(value, 0, max_hp)

func get_hp() -> int:
	return current_hp

## Returns HP as a ratio from 0.0 to 1.0.
func get_hp_ratio() -> float:
	return float(current_hp) / float(max_hp) if max_hp > 0 else 0.0

## Resets to full HP and clears the dead flag.
func reset() -> void:
	is_dead = false
	current_hp = max_hp
