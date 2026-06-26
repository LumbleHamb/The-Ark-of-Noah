class_name AnimalAnimationComponent
extends Component

## Drives the AnimatedSprite2D for animals.
## Centralizes facing, animation selection, and play-state bookkeeping so AI
## scripts stay small and behaviour-driven instead of poking the sprite directly.
##
## Convention: the sprite is flipped horizontally via scale.x for facing.
## flip_h is left untouched so the source art orientation is preserved.

@export var animated_sprite: AnimatedSprite2D = null
@export var flip_facing: bool = true

var _facing_right: bool = true

func _component_ready() -> void:
	if animated_sprite == null:
		var entity := get_entity()
		if entity:
			animated_sprite = entity.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if animated_sprite and animated_sprite.sprite_frames == null:
		push_warning("AnimalAnimationComponent: AnimatedSprite2D has no SpriteFrames on ", get_entity().name)

func get_sprite() -> AnimatedSprite2D:
	return animated_sprite

func play(anim_name: String) -> void:
	if animated_sprite == null:
		return
	if animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		return
	if animated_sprite.animation == anim_name and animated_sprite.is_playing():
		return
	animated_sprite.play(anim_name)

func play_unique(anim_name: String) -> void:
	if animated_sprite == null or animated_sprite.sprite_frames == null:
		return
	if not animated_sprite.sprite_frames.has_animation(anim_name):
		return
	animated_sprite.stop()
	animated_sprite.frame = 0
	animated_sprite.play(anim_name)

func stop() -> void:
	if animated_sprite:
		animated_sprite.stop()

func current() -> String:
	if animated_sprite == null:
		return ""
	return String(animated_sprite.animation)

func is_playing() -> bool:
	return animated_sprite != null and animated_sprite.is_playing()

func has(anim_name: String) -> bool:
	return animated_sprite != null and animated_sprite.sprite_frames != null and animated_sprite.sprite_frames.has_animation(anim_name)

## Faces left/right based on a movement direction vector.
func face_from_direction(dir: Vector2) -> void:
	if not flip_facing or animated_sprite == null:
		return
	if dir == Vector2.ZERO:
		return
	_facing_right = dir.x >= 0.0
	animated_sprite.scale.x = 1.0 if _facing_right else -1.0

func is_facing_right() -> bool:
	return _facing_right

## Picks a vertical walk animation (front/back/side) from a direction.
## Used by frogs & ducks which have walk_front / walk_back / walk_side sheets.
func directional_walk_anim(dir: Vector2) -> String:
	if abs(dir.y) > abs(dir.x) * 1.3:
		return "walk_back" if dir.y < 0.0 else "walk_front"
	return "walk_side"
