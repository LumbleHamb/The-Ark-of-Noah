extends AnimalNPC
class_name BirdAI

## Bird NPC.
## Ground: idles (alternating idle / idle2), occasionally hops via the
## "flying" wing-flap sheet used as a ground hop cycle.
## Flee: lifts off (lift_off), flies away from the player (flying), circles
## back home when safe, then lands (landing) and returns to grounded idle.
##
## The lift-off / landing are short one-shot anims; flight uses physics
## velocity so the bird actually moves in the world instead of teleporting.

enum BirdSubState { GROUNDED, LIFTING, FLYING_AWAY, RETURNING_HOME, LANDING }

@export var fly_speed: float = 120.0
@export var fly_height: float = 56.0
@export var fly_return_distance: float = 150.0
@export var hop_chance: float = 0.5

var bird_substate: BirdSubState = BirdSubState.GROUNDED
var flying_target: Vector2 = Vector2.ZERO
var _idle_alt: bool = false

func _ready() -> void:
	super._ready()
	# Birds are skittish: detect the player from further away.
	flee_distance = maxf(flee_distance, 96.0)

# --- Grounded idle: alternate idle / idle2 -------------------------------
func _handle_idle(_delta: float) -> void:
	if animator == null:
		return
	if not animator.is_playing() or (animator.current() != "idle" and animator.current() != "idle2"):
		_idle_alt = not _idle_alt
		animator.play("idle2" if _idle_alt else "idle")

# --- Ground wander: flap-hop across the ground ---------------------------
func _play_walk(_dir: Vector2) -> void:
	if animator:
		animator.play("flying")

# --- Flee onset: lift off, then fly away ---------------------------------
func _on_start_flee() -> void:
	bird_substate = BirdSubState.LIFTING
	if animator:
		animator.play_unique("lift_off")
		# Wait for the one-shot lift_off to finish before flying.
		await animator.get_sprite().animation_finished
		if not is_inside_tree():
			return
	bird_substate = BirdSubState.FLYING_AWAY

func _process_fleeing(_delta: float) -> void:
	# While lifting off the bird stays put and lets the anim play.
	if bird_substate == BirdSubState.LIFTING:
		velocity = Vector2.ZERO
		return

	if bird_substate == BirdSubState.FLYING_AWAY:
		# Keep updating the flee direction so the bird tracks the player.
		flee_direction = _get_flee_direction()
		velocity = flee_direction * fly_speed
		move_and_slide()
		_face(flee_direction)
		if animator:
			animator.play("flying")
		# Once safe, switch to returning home.
		if _player_is_safe():
			bird_substate = BirdSubState.RETURNING_HOME
			flying_target = home_position + Vector2(randf_range(-32.0, 32.0), -fly_height)
		return

	# Returning home / landing are handled in the FLEEING_FINISHED state.
	if detection != null and detection.has_target():
		if not detection.is_target_safe(flee_safe_distance * 0.8):
			bird_substate = BirdSubState.FLYING_AWAY
			return
	velocity = Vector2.ZERO

func _on_flee_safe() -> void:
	# Transition to the return-home + landing sub-sequence.
	_change_state(AnimalState.FLEEING_FINISHED)
	bird_substate = BirdSubState.RETURNING_HOME
	flying_target = home_position + Vector2(randf_range(-32.0, 32.0), -fly_height)

func _process_flee_finished(_delta: float) -> void:
	match bird_substate:
		BirdSubState.RETURNING_HOME:
			var dist_home := global_position.distance_squared_to(home_position)
			if dist_home < fly_return_distance * fly_return_distance:
				_start_landing()
				return
			# Flee again if the player chases while returning.
			if detection != null and detection.has_target() and not detection.is_target_safe(flee_safe_distance * 0.6):
				_change_state(AnimalState.FLEEING)
				bird_substate = BirdSubState.FLYING_AWAY
				return
			var hdir: Vector2 = global_position.direction_to(flying_target)
			velocity = hdir * fly_speed
			move_and_slide()
			_face(hdir)
			if animator:
				animator.play("flying")
		BirdSubState.LANDING:
			velocity = Vector2.ZERO
		_:
			velocity = Vector2.ZERO

func _start_landing() -> void:
	bird_substate = BirdSubState.LANDING
	# Drop down to ground height before the landing frame plays.
	global_position = Vector2(home_position.x, home_position.y - 4.0)
	if animator:
		animator.play_unique("landing")
		await animator.get_sprite().animation_finished
		if not is_inside_tree():
			return
	bird_substate = BirdSubState.GROUNDED
	_pick_new_idle_time()
	_change_state(AnimalState.IDLE)
	_idle_alt = false
	if animator:
		animator.play("idle")

func _on_animation_finished() -> void:
	pass
