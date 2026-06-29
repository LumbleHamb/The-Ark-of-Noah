class_name StaminaComponent
extends Component

## Manages player stamina for sprinting.
##
## Depletes stamina while the player sprints (RUN state), regenerates it
## when walking or idle. Uses a speed modifier on MovementComponent so that
## speed scales with remaining stamina — at empty stamina the player moves
## at walk speed even when holding the run key.
##
## Connect to signals for UI updates:
##   stamina_changed(current, max)  — every frame while changing
##   stamina_depleted()             — when stamina first hits 0
##   stamina_regenerated()          — when stamina recovers above 0

signal stamina_changed(current_stamina: float, max_stamina: float)
signal stamina_depleted()
signal stamina_regenerated()

# Inspector-accessible properties — tweak per entity in the editor.
@export var max_stamina: float = 100.0
@export var depletion_rate: float = 20.0              # points lost per second while sprinting
@export var regeneration_rate: float = 25.0            # points gained per second while resting
@export var regen_delay: float = 1.0                   # seconds before regen begins after sprinting
@export var min_speed_ratio: float = 0.5               # speed multiplier when stamina = 0 (0.5 ≈ walk speed / run speed)

var current_stamina: float = 100.0:
	set(v):
		current_stamina = v
		stamina_changed.emit(current_stamina, max_stamina)

var _regen_timer: float = 0.0
var _is_empty: bool = false
var _movement: MovementComponent = null


# ============================================================================
# LIFECYCLE
# ============================================================================

func _component_ready() -> void:
	current_stamina = max_stamina
	_movement = get_sibling_component_by_name("MovementComponent") as MovementComponent
	if _movement == null:
		_movement = get_sibling_component(MovementComponent)


func _process(delta: float) -> void:
	if not active or _movement == null:
		return

	# Determine if the player is actively sprinting.
	var is_sprinting: bool = _movement.move_state == MovementComponent.MoveState.RUN

	if is_sprinting and current_stamina > 0.0:
		# --- Deplete ---
		current_stamina = maxf(0.0, current_stamina - depletion_rate * delta)
		_regen_timer = 0.0

		if current_stamina <= 0.0 and not _is_empty:
			_is_empty = true
			stamina_depleted.emit()
	else:
		# --- Regenerate ---
		if current_stamina < max_stamina:
			_regen_timer += delta
			if _regen_timer >= regen_delay:
				var prev := current_stamina
				current_stamina = minf(max_stamina, current_stamina + regeneration_rate * delta)
				if prev <= 0.0 and current_stamina > 0.0:
					_is_empty = false
					stamina_regenerated.emit()

	# Apply speed modifier — full speed at full stamina, min_speed_ratio at 0.
	var stamina_ratio: float = current_stamina / max_stamina if max_stamina > 0.0 else 1.0
	var speed_mod: float = min_speed_ratio + (1.0 - min_speed_ratio) * stamina_ratio
	_movement.set_speed_modifier(speed_mod)

	stamina_changed.emit(current_stamina, max_stamina)


# ============================================================================
# PUBLIC API
# ============================================================================

## Returns the current stamina as a ratio 0.0–1.0.
func get_stamina_ratio() -> float:
	return current_stamina / max_stamina if max_stamina > 0.0 else 1.0


## Reset stamina to full.
func refill() -> void:
	current_stamina = max_stamina
	_regen_timer = 0.0
	_is_empty = false
	if _movement:
		_movement.set_speed_modifier(1.0)


## Add or subtract a flat amount (e.g. from a stamina potion).
func modify(amount: float) -> void:
	current_stamina = clampf(current_stamina + amount, 0.0, max_stamina)
