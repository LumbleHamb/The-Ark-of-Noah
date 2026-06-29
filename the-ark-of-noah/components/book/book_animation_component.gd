class_name BookAnimationComponent
extends Node

## ============================================================================
## BOOK ANIMATION COMPONENT — Drives the book open/close cover animation.
##
## Uses an AnimationPlayer (referenced via @export) to play cleanly-organised
## animations rather than imperative script tweening.  The AnimationPlayer is
## expected to own these tracks (designer-built in the editor):
##
##   "book_open"  — cover lifts, pages fan out, content fades in.
##   "book_close" — content fades, pages stack, cover closes.
##
## The component emits signals when each phase completes so the controller can
## react (e.g. show page content after opening, resume gameplay after closing).
##
## Animation approach (feels like opening a real book):
##   1. Cover rotates open (z rotation or scale.x of the cover sprite).
##   2. Pages separate (a stack of page sprites fan out with staggered delays).
##   3. Content settles into place (slight bounce/overshoot on the interior).
## No simple fade — the cover physically lifts and pages physically fan.
## ============================================================================

signal book_opened()
signal book_closed()

## The AnimationPlayer that owns the book animations.
@export var animation_player: AnimationPlayer = null

## Name of the opening animation in the player.
@export var open_animation: String = "book_open"

## Name of the closing animation in the player.
@export var close_animation: String = "book_close"
@export var animation_failsafe_seconds: float = 0.9

var _open_token: int = 0
var _close_token: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if animation_player and is_instance_valid(animation_player):
		animation_player.animation_finished.connect(_on_animation_finished)

## Plays the book-opening animation. Returns immediately; listen for book_opened.
func play_open() -> void:
	_open_token += 1
	var token: int = _open_token
	if animation_player == null or not is_instance_valid(animation_player):
		book_opened.emit()  # Fallback: no animation, just signal.
		return
	if not animation_player.has_animation(open_animation):
		book_opened.emit()
		return
	animation_player.play(open_animation)
	_start_open_failsafe(token)

## Plays the book-closing animation.
func play_close() -> void:
	_close_token += 1
	var token: int = _close_token
	if animation_player == null or not is_instance_valid(animation_player):
		book_closed.emit()  # Fallback.
		return
	if not animation_player.has_animation(close_animation):
		book_closed.emit()
		return
	animation_player.play(close_animation)
	_start_close_failsafe(token)

## Returns true if an animation is currently playing.
func is_animating() -> bool:
	if animation_player == null or not is_instance_valid(animation_player):
		return false
	return animation_player.is_playing()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == open_animation:
		book_opened.emit()
	elif anim_name == close_animation:
		book_closed.emit()

func _start_open_failsafe(token: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(animation_failsafe_seconds).timeout
	if token != _open_token:
		return
	if animation_player != null and animation_player.is_playing() and animation_player.current_animation == open_animation:
		animation_player.stop()
		book_opened.emit()

func _start_close_failsafe(token: int) -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	await tree.create_timer(animation_failsafe_seconds).timeout
	if token != _close_token:
		return
	if animation_player != null and animation_player.is_playing() and animation_player.current_animation == close_animation:
		animation_player.stop()
		book_closed.emit()
