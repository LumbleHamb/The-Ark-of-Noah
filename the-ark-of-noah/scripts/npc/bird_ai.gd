extends AnimalNPC
## Bird NPC — ground wanders, flies away from danger, lands when safe.
##
## Animations (from spritesheet):
##   GROUNDED: idle, idle2 (alternating)
##   FLYING:   flying (looping), lift_off (one-shot), landing (one-shot)

class_name BirdAI

# ============================================================================
# BIRD-SPECIFIC STATE
# ============================================================================
enum BirdSubState { GROUNDED, FLYING, LANDING }
var bird_substate: BirdSubState = BirdSubState.GROUNDED

@export var fly_speed: float = 100.0
@export var fly_height: float = 60.0
@export var fly_return_distance: float = 150.0

var flying_target: Vector2 = Vector2.ZERO
var is_landing: bool = false
var idle_anim_index: int = 0

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	super._ready()
	flee_distance = maxf(flee_distance, 80.0)

# ============================================================================
# IDLE ANIMATION — alternate between idle and idle2
# ============================================================================
func _handle_idle_animation(_delta: float = 0.0) -> void:
	if not anim.is_playing() or anim.animation == &"idle" or anim.animation == &"idle2":
		idle_anim_index = 0 if idle_anim_index == 1 else 1
		anim.play(&"idle" if idle_anim_index == 0 else &"idle2")

# ============================================================================
# WALKING
# ============================================================================
func _play_walk_animation(_dir: Vector2) -> void:
	# On the ground the bird hops — use the flying animation (which is the
	# bird's only walk-cycle anim in the spritesheet).
	if anim.animation != &"flying":
		anim.play(&"flying")

# ============================================================================
# FLEEING — lift off, then fly away
# ============================================================================
func _on_start_flee() -> void:
	bird_substate = BirdSubState.FLYING
	is_landing = false
	anim.play(&"lift_off")
	await anim.animation_finished

func _process_fleeing(delta: float) -> void:
	if bird_substate != BirdSubState.FLYING:
		return

	if player_ref != null:
		flee_direction = _get_flee_direction()

	var target := global_position + flee_direction * fly_speed * delta * 10.0
	global_position = global_position.lerp(target, 0.1)
	_facing_from_dir(flee_direction)

	# Use the looping flying animation.
	if anim.animation != &"flying" or not anim.is_playing():
		anim.play(&"flying")

	if _player_is_safe():
		_change_state(AnimalState.FLEEING_FINISHED)
		_on_flee_safe()
		finished_fleeing.emit()

# ============================================================================
# RETURN & LAND
# ============================================================================
func _on_flee_safe() -> void:
	flying_target = home_position + Vector2(randf_range(-32.0, 32.0), -fly_height)

func _process_flee_finished(delta: float) -> void:
	match bird_substate:
		BirdSubState.FLYING:
			if not is_landing:
				var dist_to_home := global_position.distance_squared_to(home_position)
				if dist_to_home < fly_return_distance * fly_return_distance:
					_start_landing()
				else:
					var dir := global_position.direction_to(flying_target)
					global_position += dir * fly_speed * delta
					_facing_from_dir(dir)
					if anim.animation != &"flying" or not anim.is_playing():
						anim.play(&"flying")
			else:
				_process_landing(delta)
		BirdSubState.LANDING:
			_process_landing(delta)
		_:
			pass

func _start_landing() -> void:
	is_landing = true
	bird_substate = BirdSubState.LANDING
	global_position = Vector2(home_position.x, home_position.y - 8.0)
	anim.play(&"landing")
	await anim.animation_finished
	bird_substate = BirdSubState.GROUNDED
	is_landing = false
	_pick_new_idle_time()
	_change_state(AnimalState.IDLE)
	anim.play(&"idle")

func _process_landing(_delta: float) -> void:
	pass

# ============================================================================
# FLEE ANIMATION (unused — flying is position-based)
# ============================================================================
func _play_flee_animation(_dir: Vector2) -> void:
	pass

# ============================================================================
# ANIMATION FINISHED
# ============================================================================
func _on_animation_finished() -> void:
	# flying is looping and handled by _process_fleeing, nothing to do here.
	pass
