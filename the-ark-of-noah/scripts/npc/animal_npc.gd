extends CharacterBody2D
## Modular base NPC for animals.  Handles shared movement, proximity detection,
## fade-in/fade-out transitions, and automatic memory cleanup.
##
## Subclasses (Bird, Duck, Frog) override virtual methods to supply
## species-specific animations and state transitions.

class_name AnimalNPC

# ============================================================================
# SIGNALS
# ============================================================================
signal started_wandering()
signal stopped_wandering()
signal started_fleeing()
signal finished_fleeing()
signal fade_complete()                               # emitted after fade-out finishes

# ============================================================================
# EXPORTS
# ============================================================================
@export var wander_radius: float = 128.0            ## How far the animal wanders from its origin.
@export var flee_distance: float = 48.0             ## Distance to player that triggers flee.
@export var flee_safe_distance: float = 200.0       ## Distance from player where fleeing stops.
@export var walk_speed: float = 30.0
@export var flee_speed: float = 60.0
@export var idle_time_min: float = 3.0              ## Minimum idle duration before deciding to wander (seconds).
@export var idle_time_max: float = 8.0              ## Maximum idle duration before deciding to wander (seconds).
@export var wander_chance: float = 0.4              ## Probability of wandering when idle timer expires.

@export_group("Fade")
## Seconds for fade-in when the animal spawns.
@export var fade_in_duration: float = 0.5
## Seconds for fade-out before the animal despawns (e.g. after fleeing off-screen).
@export var fade_out_duration: float = 0.8
## If true, fade in on _ready automatically.
@export var auto_fade_in: bool = true

# ============================================================================
# NODE REFERENCES
# ============================================================================
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection_area: Area2D = $DetectionArea

# ============================================================================
# STATE
# ============================================================================
enum AnimalState { IDLE, WANDERING, FLEEING, FLEEING_FINISHED, FADING_OUT }

var state: AnimalState = AnimalState.IDLE
var home_position: Vector2
var target_position: Vector2
var idle_timer: float = 0.0
var rest_time: float = 0.0
var player_ref: CharacterBody2D = null
var flee_direction: Vector2 = Vector2.ZERO
var facing_right: bool = true

# Fade tween running during fade-in / fade-out.
var _fade_tween: Tween = null

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	home_position = global_position
	anim.animation_finished.connect(_on_animation_finished)
	# Set the detection area to detect the player (collision_layer 2).
	# Player is on layer 2; default detection_mask is 1 which won't overlap.
	detection_area.collision_mask = 2
	detection_area.body_entered.connect(_on_detection_area_body_entered)
	detection_area.body_exited.connect(_on_detection_area_body_exited)

	_pick_new_idle_time()
	_on_enter_state(AnimalState.IDLE)

	if auto_fade_in:
		_start_fade_in()
	else:
		modulate.a = 1.0

func _process(_delta: float) -> void:
	# Override in subclasses for per-frame updates (e.g. ripples sync).
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
			# No movement while fading out.
			velocity = Vector2.ZERO

# ============================================================================
# IDLE
# ============================================================================
func _process_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0.0:
		if player_ref != null and _player_is_too_close():
			_start_fleeing()
		elif randf() < wander_chance:
			_start_wandering()
		else:
			_pick_new_idle_time()

	_handle_idle_animation(delta)

## Override in subclasses for species-specific idle animation cycling.
## @delta: time since last physics frame (set by _physics_process).
func _handle_idle_animation(_delta: float = 0.0) -> void:
	pass

# ============================================================================
# WANDERING
# ============================================================================
func _start_wandering() -> void:
	_change_state(AnimalState.WANDERING)
	target_position = _pick_wander_target()
	started_wandering.emit()

func _process_wandering(_delta: float) -> void:
	if player_ref != null and _player_is_too_close():
		_start_fleeing()
		return

	var dist := global_position.distance_squared_to(target_position)
	if dist < 16.0:
		_pick_new_idle_time()
		_change_state(AnimalState.IDLE)
		stopped_wandering.emit()
		return

	var dir := global_position.direction_to(target_position)
	velocity = dir * walk_speed
	move_and_slide()

	_facing_from_dir(dir)
	_play_walk_animation(dir)

func _pick_wander_target() -> Vector2:
	var offset := Vector2(
		randf_range(-wander_radius, wander_radius),
		randf_range(-wander_radius, wander_radius)
	)
	return home_position + offset

# ============================================================================
# FLEEING
# ============================================================================
func _player_is_too_close() -> bool:
	if player_ref == null:
		return false
	var d := global_position.distance_squared_to(player_ref.global_position)
	return d < flee_distance * flee_distance

func _player_is_safe() -> bool:
	if player_ref == null:
		return true
	var d := global_position.distance_squared_to(player_ref.global_position)
	return d > flee_safe_distance * flee_safe_distance

func _start_fleeing() -> void:
	_change_state(AnimalState.FLEEING)
	flee_direction = _get_flee_direction()
	started_fleeing.emit()
	_on_start_flee()

## Override in subclasses for flee-specific setup (e.g. bird plays lift_off anim).
func _on_start_flee() -> void:
	pass

func _process_fleeing(_delta: float) -> void:
	if player_ref != null:
		flee_direction = _get_flee_direction()

	velocity = flee_direction * flee_speed
	move_and_slide()

	_facing_from_dir(flee_direction)
	_play_flee_animation(flee_direction)

	if _player_is_safe():
		_change_state(AnimalState.FLEEING_FINISHED)
		_on_flee_safe()
		finished_fleeing.emit()

## Override for behaviour when the animal has reached a safe distance.
func _on_flee_safe() -> void:
	pass

func _process_flee_finished(_delta: float) -> void:
	# Subclass can override to handle return / fade-out.
	pass

func _get_flee_direction() -> Vector2:
	if player_ref == null:
		return Vector2.RIGHT
	var away := global_position - player_ref.global_position
	if away.length_squared() < 1.0:
		away = Vector2.RIGHT
	return away.normalized()

# ============================================================================
# FADE SYSTEM
# ============================================================================
func _start_fade_in() -> void:
	modulate.a = 0.0
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, ^"modulate:a", 1.0, fade_in_duration)

func _start_fade_out() -> void:
	_kill_fade_tween()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, ^"modulate:a", 0.0, fade_out_duration)
	_fade_tween.finished.connect(_on_fade_out_complete)

func _on_fade_out_complete() -> void:
	fade_complete.emit()
	# Default: free after fade-out. Subclasses can override to do something else.
	_unregister_from_chunk_manager()
	queue_free()

func _unregister_from_chunk_manager() -> void:
	var chunk_manager: Node = get_tree().current_scene.find_child(&"ChunkManager", false, false)
	if chunk_manager != null and chunk_manager.has_method(&"unregister_node"):
		chunk_manager.unregister_node(self)

func _kill_fade_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = null

# ============================================================================
# MEMORY CLEANUP — remove if far from home and off-screen
# ============================================================================
func _on_viewport_exited(_viewport: Viewport) -> void:
	# Only auto-cleanup if we're not in the middle of player interaction.
	if state == AnimalState.IDLE or state == AnimalState.WANDERING:
		if home_position.distance_squared_to(global_position) > 4096.0:
			_start_fade_out()

# ============================================================================
# HELPERS
# ============================================================================
func _change_state(new_state: AnimalState) -> void:
	var old_state := state
	state = new_state
	_on_exit_state(old_state)
	_on_enter_state(new_state)

func _on_exit_state(_old_state: AnimalState) -> void:
	pass

func _on_enter_state(_new_state: AnimalState) -> void:
	pass

func _pick_new_idle_time() -> void:
	idle_timer = randf_range(idle_time_min, idle_time_max)

## Sets flip_h so the walk_side animation (which faces LEFT in source art)
## is mirrored when moving right and shown as-is when moving left.
func _facing_from_dir(dir: Vector2) -> void:
	if abs(dir.x) > 0.01:
		facing_right = dir.x > 0
	# walk_side art faces left → flip when moving right (facing_right = true)
	anim.flip_h = facing_right

# ============================================================================
# ANIMATION HELPERS (override in subclasses)
# ============================================================================
func _play_walk_animation(_dir: Vector2) -> void:
	pass

func _play_flee_animation(_dir: Vector2) -> void:
	pass

func _on_animation_finished() -> void:
	pass

# ============================================================================
# DETECTION
# ============================================================================
func _on_detection_area_body_entered(body: Node) -> void:
	if body.is_in_group(&"Player"):
		player_ref = body as CharacterBody2D

func _on_detection_area_body_exited(body: Node) -> void:
	if body == player_ref:
		player_ref = null
