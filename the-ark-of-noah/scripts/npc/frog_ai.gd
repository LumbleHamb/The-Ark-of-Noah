extends AnimalNPC
## Frog NPC — hops along the ground, turns between movements.
##
## Idle rules:
##   - idle_front (idle1) is the base animation.
##   - random triggers select idle2_front / idle2_side or idle3_front / idle3_side
##     based on current facing direction.
##
## Walk animations: walk_front, walk_back, walk_side (directional).
## Turn animation: a single "walk" frame snap (no dedicated turn anim in the
## spritesheet — the frog uses the appropriate walk anim on each hop burst).

class_name FrogAI

# ============================================================================
# FROG-SPECIFIC EXPORTS
# ============================================================================
@export var hop_distance: float = 24.0
@export var hop_cooldown: float = 0.4
## Probability of playing a non-base idle variant when idle timer ticks.
@export var idle_variant_chance: float = 0.35

# ============================================================================
# STATE
# ============================================================================
var hop_timer: float = 0.0
var idle_front_index: int = 0
## Tracks whether an idle variant is currently playing.
var _idle_variant_playing: bool = false

# ============================================================================
# IDLE ANIMATION — idle_front (idle1) base, idle2/idle3 by direction
# ============================================================================
func _handle_idle_animation(_delta: float = 0.0) -> void:
	if anim.is_playing():
		return

	if randf() < idle_variant_chance and not _idle_variant_playing:
		# Pick idle2 or idle3 variant (front-facing).
		_idle_variant_playing = true
		var variant: int = randi() % 2
		match variant:
			0:
				anim.play(&"idle2_front")
			1:
				anim.play(&"idle3_front")
	else:
		# Default base idle.
		_idle_variant_playing = false
		anim.play(&"idle_front")

# ============================================================================
# WANDERING (hopping movement)
# ============================================================================
func _process_wandering(delta: float) -> void:
	hop_timer -= delta

	if player_ref != null and _player_is_too_close():
		_start_fleeing()
		return

	var dist := global_position.distance_squared_to(target_position)
	if dist < 16.0:
		_pick_new_idle_time()
		_change_state(AnimalState.IDLE)
		stopped_wandering.emit()
		return

	if hop_timer <= 0.0:
		var dir := global_position.direction_to(target_position)
		velocity = dir * walk_speed * 3.0
		move_and_slide()

		_facing_from_dir(dir)
		_play_walk_animation(dir)

		hop_timer = hop_cooldown
	else:
		velocity = Vector2.ZERO
		if not anim.is_playing():
			anim.play(&"idle_front")

func _play_walk_animation(dir: Vector2) -> void:
	var walk_name := _get_walk_anim(dir)
	anim.play(walk_name)

func _get_walk_anim(dir: Vector2) -> String:
	if abs(dir.y) > abs(dir.x) * 1.3:
		return "walk_back" if dir.y < 0 else "walk_front"
	else:
		return "walk_side"

# ============================================================================
# FLEEING — hop away fast
# ============================================================================
func _on_start_flee() -> void:
	hop_timer = 0.0

func _play_flee_animation(dir: Vector2) -> void:
	var walk_name := _get_walk_anim(dir)
	anim.play(walk_name)

func _on_flee_safe() -> void:
	_change_state(AnimalState.IDLE)
	_pick_new_idle_time()
	anim.play(&"idle_front")
	finished_fleeing.emit()

# ============================================================================
# ANIMATION FINISHED
# ============================================================================
func _on_animation_finished() -> void:
	# Reset idle variant flag when a variant animation finishes.
	if anim.animation == &"idle2_front" or anim.animation == &"idle3_front":
		_idle_variant_playing = false
