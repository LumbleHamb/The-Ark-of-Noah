class_name PageTurnComponent
extends Node

## ============================================================================
## PAGE TURN COMPONENT — Drives realistic page-turn animations.
##
## Uses an AnimationPlayer to animate the page-curl shader parameter plus the
## turning page's position/rotation, producing a physical page-flip feel — not
## a simple slide.  The shader (page_curl.gdshader) handles the curl itself;
## this component drives the curl_amount uniform and any sprite transforms.
##
## Forward turn:  page curls from right edge → flips left  (next_page anim).
## Backward turn: page curls from left edge  → flips right (prev_page anim).
##
## Emits page_turn_forward / page_turn_backward when each completes so the
## controller can swap page content at the midpoint (when the page is edge-on
## and the swap is invisible).
## ============================================================================

signal turn_completed(direction: int)  # +1 forward, -1 backward
signal turn_midpoint()                  # best moment to swap content invisibly

## The AnimationPlayer owning the turn animations.
@export var animation_player: AnimationPlayer = null

## Name of the forward (next) page-turn animation.
@export var next_animation: String = "next_page"

## Name of the backward (prev) page-turn animation.
@export var prev_animation: String = "previous_page"

## The page sprite whose shader material we drive for the curl (optional —
## if the AnimationPlayer already animates the shader param, leave null).
@export var turning_page: Sprite2D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if animation_player and is_instance_valid(animation_player):
		animation_player.animation_finished.connect(_on_animation_finished)

## Play a forward (next) page turn.
func turn_forward() -> void:
	_play_turn(next_animation, 1)

## Play a backward (prev) page turn.
func turn_backward() -> void:
	_play_turn(prev_animation, -1)

func _play_turn(anim_name: String, direction: int) -> void:
	if animation_player == null or not is_instance_valid(animation_player):
		# No animation — swap immediately and signal.
		turn_midpoint.emit()
		turn_completed.emit(direction)
		return
	# Connect to the animation's midpoint via a method call track or just
	# use a timer approximation. We emit midpoint at ~50% of the anim length.
	var anim: Animation = animation_player.get_animation(anim_name)
	if anim and anim.length > 0.0:
		# Schedule the midpoint swap signal.
		var midpoint_time: float = anim.length * 0.5
		var timer: SceneTreeTimer = get_tree().create_timer(midpoint_time, false, false, false)
		timer.timeout.connect(turn_midpoint.emit)
	animation_player.play(anim_name)

func is_turning() -> bool:
	if animation_player == null or not is_instance_valid(animation_player):
		return false
	return animation_player.is_playing() and (
		animation_player.current_animation == next_animation or
		animation_player.current_animation == prev_animation
	)

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == next_animation:
		turn_completed.emit(1)
	elif anim_name == prev_animation:
		turn_completed.emit(-1)
