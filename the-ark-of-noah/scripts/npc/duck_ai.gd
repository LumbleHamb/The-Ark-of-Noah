extends AnimalNPC
## Duck NPC — water-bound wanderer with dual-layer rendering.
##
## The duck has a secondary AnimatedSprite2D (Ripples) positioned underneath
## the main sprite, playing the "water" animation synchronised to the duck.
##
## Idle priority: base animation is idle3. Occasional random triggers select
## idle or idle2 for variety.  While idle, the ripples layer loops.
##
## Walking is replaced by "swim" when near_water is true (uses water anim
## on the main sprite and ripples underneath).

class_name DuckAI

# ============================================================================
# DUCK-SPECIFIC EXPORTS
# ============================================================================
## When true, the duck uses water/swim animations instead of walk animations.
@export var near_water: bool = false

# ============================================================================
# NODE REFERENCES
# ============================================================================
## Secondary sprite for water ripples, rendered underneath the duck.
@onready var ripples_sprite: AnimatedSprite2D = $Ripples

# ============================================================================
# STATE
# ============================================================================
## Tracks which idle variant was last chosen so we don't repeat immediately.
var _last_idle: String = "idle3"
var _idle_change_timer: float = 0.0
## How often to consider switching idle variants (seconds).
const IDLE_VARIANT_COOLDOWN: float = 3.0

# ============================================================================
# LIFECYCLE
# ============================================================================
func _ready() -> void:
	super._ready()
	# Start ripples animation (child node auto-follows the duck's position).
	if ripples_sprite and ripples_sprite.sprite_frames:
		ripples_sprite.play(&"water")

# ============================================================================
# IDLE ANIMATION — idle3 as base, idle/idle2 as occasional variety
# ============================================================================
func _handle_idle_animation(delta: float = 0.0) -> void:
	if anim.is_playing() and anim.animation != &"idle" \
		and anim.animation != &"idle2" and anim.animation != &"idle3":
		return

	_idle_change_timer -= delta
	if _idle_change_timer <= 0.0:
		_idle_change_timer = IDLE_VARIANT_COOLDOWN + randf_range(0.0, 3.0)

		# Weighted selection: idle3 is the default base, idle/idle2 are occasional.
		var roll: float = randf()
		var chosen: String
		if roll < 0.50:
			chosen = "idle3"
		elif roll < 0.80:
			chosen = "idle"
		else:
			chosen = "idle2"

		# Avoid repeating the same variant twice in a row.
		if chosen == _last_idle and randf() < 0.5:
			# Pick a different variant.
			var alternatives: Array[String] = ["idle", "idle2", "idle3"]
			alternatives.erase(chosen)
			chosen = alternatives[randi() % alternatives.size()]

		_last_idle = chosen
		if not anim.is_playing() or anim.animation != chosen:
			anim.play(chosen)

	# Sync ripples animation speed to main animation speed.
	if ripples_sprite and ripples_sprite.sprite_frames:
		if not ripples_sprite.is_playing():
			ripples_sprite.play(&"water")

# ============================================================================
# WALK / SWIM
# ============================================================================
func _play_walk_animation(dir: Vector2) -> void:
	if near_water:
		# Swimming — use water animation on main sprite.
		if anim.animation != &"water":
			anim.play(&"water")
	else:
		var walk_name := _get_walk_anim(dir)
		if anim.animation != walk_name:
			anim.play(walk_name)

func _get_walk_anim(dir: Vector2) -> String:
	if abs(dir.y) > abs(dir.x) * 1.3:
		return "walk_back" if dir.y < 0 else "walk_front"
	else:
		return "walk_side"

# ============================================================================
# FLEEING — waddle / swim away quickly
# ============================================================================
func _on_start_flee() -> void:
	if near_water:
		anim.play(&"water")
	else:
		anim.play(&"walk_side")

func _play_flee_animation(dir: Vector2) -> void:
	if near_water:
		if anim.animation != &"water":
			anim.play(&"water")
	else:
		var walk_name := _get_walk_anim(dir)
		if anim.animation != walk_name:
			anim.play(walk_name)

func _on_flee_safe() -> void:
	_change_state(AnimalState.IDLE)
	_pick_new_idle_time()
	anim.play(&"idle3")
	finished_fleeing.emit()

# ============================================================================
# ANIMATION FINISHED
# ============================================================================
func _on_animation_finished() -> void:
	pass

# ============================================================================
# VISIBILITY / CLEANUP
# ============================================================================
func _on_fade_out_complete() -> void:
	# Hide ripples before cleanup.
	if ripples_sprite and is_instance_valid(ripples_sprite):
		ripples_sprite.visible = false
	super._on_fade_out_complete()
