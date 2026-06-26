extends AnimalNPC
class_name DuckAI

## Duck NPC.
## Water-bound wanderer with a secondary ripples sprite beneath it.
## Idle: cycles idle / idle2 / idle3 for natural variety.
## Walk: swim ("water") when near_water, else directional walk sheets.
## Flee: swims or waddles away quickly, then settles back to idle.

@export var near_water: bool = false

var _last_idle: String = "idle3"
var _idle_change_timer: float = 0.0
const IDLE_VARIANT_COOLDOWN: float = 3.0

func _ready() -> void:
	super._ready()
	_ensure_ripples_playing()

func _ensure_ripples_playing() -> void:
	var ripples: AnimatedSprite2D = get_node_or_null("Ripples") as AnimatedSprite2D
	if ripples and ripples.sprite_frames:
		if not ripples.is_playing():
			ripples.play("water")

# --- Idle: weighted variety across the three idle sheets -----------------
func _handle_idle(delta: float) -> void:
	if animator == null:
		return
	# Don't interrupt non-idle animations (e.g. a walk in progress).
	var cur: String = animator.current()
	if cur != "" and cur != "idle" and cur != "idle2" and cur != "idle3" and animator.is_playing():
		return
	_idle_change_timer -= delta
	if _idle_change_timer > 0.0:
		return
	_idle_change_timer = IDLE_VARIANT_COOLDOWN + randf_range(0.0, 3.0)
	var roll: float = randf()
	var chosen: String
	if roll < 0.50:
		chosen = "idle3"
	elif roll < 0.80:
		chosen = "idle"
	else:
		chosen = "idle2"
	if chosen == _last_idle and randf() < 0.5:
		var alternatives: Array[String] = ["idle", "idle2", "idle3"]
		alternatives.erase(chosen)
		chosen = alternatives[randi() % alternatives.size()]
	_last_idle = chosen
	animator.play(chosen)

# --- Walk: swim or directional waddle ------------------------------------
func _play_walk(dir: Vector2) -> void:
	if animator == null:
		return
	if near_water:
		animator.play("water")
		return
	animator.play(animator.directional_walk_anim(dir))

# --- Flee: swim or waddle away quickly -----------------------------------
func _on_start_flee() -> void:
	if animator == null:
		return
	if near_water:
		animator.play("water")
	else:
		animator.play("walk_side")

func _play_flee(dir: Vector2) -> void:
	_play_walk(dir)

func _on_flee_safe() -> void:
	if animator:
		_last_idle = "idle3"
		animator.play("idle3")

func _on_animation_finished() -> void:
	pass

func _on_fade_out_complete() -> void:
	var ripples: AnimatedSprite2D = get_node_or_null("Ripples") as AnimatedSprite2D
	if ripples and is_instance_valid(ripples):
		ripples.visible = false
	super._on_fade_out_complete()
