extends CharacterBody2D
class_name AnimalNPC

## Modular base NPC for animals using the component architecture.
##
## Entity (this CharacterBody2D) owns the physics body + sprite.
## Behaviour is delegated to child components:
##   - AnimalAnimationComponent: sprite play / facing
##   - DetectionComponent: proximity sensing of the Player group
##   - WanderComponent: random idle-to-wander cycling
##   - FleeComponent: flee movement + safe-distance detection
##   - FadeComponent: spawn/despawn fade transitions
##
## Subclasses (BirdAI, DuckAI, FrogAI) override the virtual _play_* hooks
## and _on_* hooks for species-specific animation selection.

signal started_wandering()
signal stopped_wandering()
signal started_fleeing()
signal finished_fleeing()
signal fade_complete()

# --- Tunables ---------------------------------------------------------------
@export var wander_radius: float = 128.0
@export var flee_distance: float = 48.0
@export var flee_safe_distance: float = 200.0
@export var walk_speed: float = 30.0
@export var flee_speed: float = 60.0
@export var idle_time_min: float = 3.0
@export var idle_time_max: float = 8.0
@export var wander_chance: float = 0.4

@export_group("Fade")
@export var auto_fade_in: bool = true

# --- State machine ---------------------------------------------------------
enum AnimalState { IDLE, WANDERING, FLEEING, FLEEING_FINISHED, FADING_OUT }
var state: AnimalState = AnimalState.IDLE

var home_position: Vector2 = Vector2.ZERO
var target_position: Vector2 = Vector2.ZERO
var idle_timer: float = 0.0
var flee_direction: Vector2 = Vector2.ZERO

# --- Component refs (resolved in _ready) -----------------------------------
var animator: AnimalAnimationComponent = null
var fade_component: FadeComponent = null
var detection: DetectionComponent = null
var wander: WanderComponent = null
var flee: FleeComponent = null

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------
func _ready() -> void:
	home_position = global_position
	_resolve_components()
	_pick_new_idle_time()
	_on_enter_state(AnimalState.IDLE)
	if fade_component:
		fade_component.fade_in()
		fade_component.fade_completed.connect(_on_fade_completed)
	elif auto_fade_in:
		_start_fade_in()
	else:
		modulate.a = 1.0

func _resolve_components() -> void:
	animator = get_node_or_null("AnimalAnimationComponent") as AnimalAnimationComponent
	fade_component = get_node_or_null("FadeComponent") as FadeComponent
	detection = get_node_or_null("DetectionComponent") as DetectionComponent
	wander = get_node_or_null("WanderComponent") as WanderComponent
	flee = get_node_or_null("FleeComponent") as FleeComponent

func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	match state:
		AnimalState.IDLE:
			_process_idle(delta)
		AnimalState.WANDERING:
			_process_wandering(delta)
		AnimalState.FLEEING:
			_process_fleeing(delta)
		AnimalState.FLEEING_FINISHED:
			_process_flee_finished(delta)
		AnimalState.FADING_OUT:
			velocity = Vector2.ZERO

# ---------------------------------------------------------------------------
# Idle
# ---------------------------------------------------------------------------
func _process_idle(delta: float) -> void:
	if _should_flee():
		_start_fleeing()
		return
	idle_timer -= delta
	if idle_timer <= 0.0:
		if randf() < wander_chance:
			_start_wandering()
		else:
			_pick_new_idle_time()
	_handle_idle(delta)

func _pick_new_idle_time() -> void:
	idle_timer = randf_range(idle_time_min, idle_time_max)

# ---------------------------------------------------------------------------
# Wandering
# ---------------------------------------------------------------------------
func _start_wandering() -> void:
	_change_state(AnimalState.WANDERING)
	if wander:
		wander.start_wandering()
	else:
		target_position = _pick_wander_target()
	started_wandering.emit()

func _process_wandering(delta: float) -> void:
	if _should_flee():
		_start_fleeing()
		return
	if wander:
		if wander.process_wander(delta, self):
			_end_wandering()
			return
		var wdir: Vector2 = wander.get_move_direction()
		if wdir != Vector2.ZERO:
			_face(wdir)
			_play_walk(wdir)
		return
	var dist: float = global_position.distance_squared_to(target_position)
	if dist < 16.0:
		_end_wandering()
		return
	var tdir: Vector2 = global_position.direction_to(target_position)
	velocity = tdir * walk_speed
	move_and_slide()
	_face(tdir)
	_play_walk(tdir)

func _end_wandering() -> void:
	_pick_new_idle_time()
	_change_state(AnimalState.IDLE)
	stopped_wandering.emit()

func _pick_wander_target() -> Vector2:
	var offset := Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)
	return home_position + offset

# ---------------------------------------------------------------------------
# Fleeing
# ---------------------------------------------------------------------------
func _should_flee() -> bool:
	if flee:
		return flee.should_start_fleeing()
	if detection:
		return detection.is_target_too_close(flee_distance)
	return false

func _start_fleeing() -> void:
	_change_state(AnimalState.FLEEING)
	if flee:
		flee.start_fleeing()
		flee_direction = flee.get_flee_direction()
	else:
		flee_direction = _get_flee_direction()
	started_fleeing.emit()
	_on_start_flee()

func _process_fleeing(_delta: float) -> void:
	if flee:
		if flee.process_flee(self):
			flee_direction = flee.get_flee_direction()
			_face(flee_direction)
			_play_flee(flee_direction)
			_end_flee()
		else:
			flee_direction = flee.get_flee_direction()
			_face(flee_direction)
			_play_flee(flee_direction)
		return
	flee_direction = _get_flee_direction()
	velocity = flee_direction * flee_speed
	move_and_slide()
	_face(flee_direction)
	_play_flee(flee_direction)
	if _player_is_safe():
		_end_flee()

func _end_flee() -> void:
	_change_state(AnimalState.IDLE)
	_pick_new_idle_time()
	finished_fleeing.emit()
	_on_flee_safe()

func _get_flee_direction() -> Vector2:
	if detection == null or not detection.has_target():
		return Vector2.RIGHT
	var target: Node2D = detection.get_closest_target()
	var away: Vector2 = global_position - target.global_position
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT
	return away.normalized()

func _player_is_safe() -> bool:
	if detection == null or not detection.has_target():
		return true
	return detection.is_target_safe(flee_safe_distance)

func _process_flee_finished(_delta: float) -> void:
	_change_state(AnimalState.IDLE)

# ---------------------------------------------------------------------------
# Facing / animation (overridable hooks)
# ---------------------------------------------------------------------------
func _face(dir: Vector2) -> void:
	if animator:
		animator.face_from_direction(dir)

func _handle_idle(_delta: float) -> void:
	pass

func _play_walk(_dir: Vector2) -> void:
	pass

func _play_flee(_dir: Vector2) -> void:
	pass

func _on_start_flee() -> void:
	pass

func _on_flee_safe() -> void:
	pass

func _on_animation_finished() -> void:
	pass

# ---------------------------------------------------------------------------
# State transitions
# ---------------------------------------------------------------------------
func _change_state(new_state: AnimalState) -> void:
	state = new_state
	_on_enter_state(new_state)

func _on_enter_state(_new_state: AnimalState) -> void:
	pass

# ---------------------------------------------------------------------------
# Fade
# ---------------------------------------------------------------------------
func _on_fade_completed(_direction: String) -> void:
	fade_complete.emit()

func _start_fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.5)
	await tween.finished
	fade_complete.emit()

func _on_fade_out_complete() -> void:
	queue_free()
