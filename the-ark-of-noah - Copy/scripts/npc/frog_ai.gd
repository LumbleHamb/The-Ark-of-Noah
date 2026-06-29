extends AnimalNPC
class_name FrogAI

## Frog NPC.
## Ground hopper with front/side idle variants. Hops in bursts while wandering
## (brief velocity pulse + cooldown) and frog-hops away quickly when fleeing.
## Uses the AnimalAnimationComponent for facing + directional walk sheet choice.

@export var hop_distance: float = 24.0
@export var hop_cooldown: float = 0.5
@export var idle_variant_chance: float = 0.35

var _hop_timer: float = 0.0
var _idle_variant_playing: bool = false

# --- Idle: base idle_front, occasional idle2/idle3 variants ---------------
func _handle_idle(_delta: float) -> void:
	if animator == null:
		return
	# Only pick a new idle when the current animation has finished, so we
	# don't cut off in-progress frames.
	if animator.is_playing():
		return
	if randf() < idle_variant_chance and not _idle_variant_playing:
		_idle_variant_playing = true
		var variant: int = randi() % 2
		animator.play("idle3_front" if variant == 0 else "idle2_front")
	else:
		_idle_variant_playing = false
		animator.play("idle_front")

# --- Wander: hop in bursts toward the target -----------------------------
func _process_wandering(delta: float) -> void:
	if _should_flee():
		_start_fleeing()
		return
	if wander:
		_hop_step(delta, wander.get_move_direction(), walk_speed)
		return
	# Legacy direct-to-target wander.
	var dist: float = global_position.distance_squared_to(target_position)
	if dist < 16.0:
		_end_wandering()
		return
	_hop_step(delta, global_position.direction_to(target_position), walk_speed)

## Applies one hop burst when the cooldown elapses, otherwise holds still.
func _hop_step(delta: float, dir: Vector2, speed: float) -> void:
	_hop_timer -= delta
	if dir == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	if _hop_timer <= 0.0:
		velocity = dir * speed * 3.0
		move_and_slide()
		_face(dir)
		_play_walk(dir)
		_hop_timer = hop_cooldown
	else:
		velocity = Vector2.ZERO
		if animator and not animator.is_playing():
			animator.play("idle_front")

func _play_walk(dir: Vector2) -> void:
	if animator == null:
		return
	animator.play(animator.directional_walk_anim(dir))

# --- Flee: frog-hop away quickly -----------------------------------------
func _on_start_flee() -> void:
	_hop_timer = 0.0

func _play_flee(dir: Vector2) -> void:
	_play_walk(dir)

func _on_flee_safe() -> void:
	if animator:
		_idle_variant_playing = false
		animator.play("idle_front")

func _on_animation_finished() -> void:
	if animator and (animator.current() == "idle2_front" or animator.current() == "idle3_front"):
		_idle_variant_playing = false
