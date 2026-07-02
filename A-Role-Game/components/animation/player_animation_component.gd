class_name PlayerAnimationComponent
extends Component

## Handles player animation selection based on movement state and direction.
## Works with MovementComponent and AttackComponent to determine animation + offset.

@export var anim_sprite: AnimatedSprite2D = null

const BASE_OFFSET: Vector2 = Vector2(-32, -43)
const ATTACK_OFFSET: Vector2 = Vector2(-48, -59)

func _component_ready() -> void:
	if not anim_sprite:
		var entity := get_entity()
		if entity:
			anim_sprite = entity.get_node_or_null("player_animation") as AnimatedSprite2D
	if anim_sprite:
		anim_sprite.offset = BASE_OFFSET

## Sets the animated sprite reference manually.
func setup(sprite: AnimatedSprite2D) -> void:
	anim_sprite = sprite
	if anim_sprite:
		anim_sprite.offset = BASE_OFFSET

## Plays idle animation for the given direction key.
func play_idle(dir_key: String) -> void:
	if anim_sprite:
		anim_sprite.offset = BASE_OFFSET
		var next_anim: String = "idle_" + dir_key
		if anim_sprite.animation != next_anim:
			anim_sprite.play(next_anim)

## Plays walk animation for the given direction key.
func play_walk(dir_key: String) -> void:
	if anim_sprite:
		anim_sprite.offset = BASE_OFFSET
		var next_anim: String = "walk_" + dir_key
		if anim_sprite.animation != next_anim:
			anim_sprite.play(next_anim)

## Plays run animation for the given direction key.
func play_run(dir_key: String) -> void:
	if anim_sprite:
		anim_sprite.offset = BASE_OFFSET
		var next_anim: String = "run_" + dir_key
		if anim_sprite.animation != next_anim:
			anim_sprite.play(next_anim)

## Plays attack animation with attack offset for the given direction.
func play_attack(dir_key: String) -> void:
	if anim_sprite:
		anim_sprite.offset = ATTACK_OFFSET
		anim_sprite.stop()
		anim_sprite.frame = 0
		anim_sprite.play("attack_" + dir_key)

## Stops the currently playing animation.
func stop_animation() -> void:
	if anim_sprite:
		anim_sprite.stop()

## Returns true if the animated sprite is currently playing.
func is_playing() -> bool:
	return anim_sprite and anim_sprite.is_playing()

## Converts a movement vector to a compass key (N, NE, E, SE, S, SW, W, NW).
func get_dir_from_vector(v: Vector2) -> String:
	if v == Vector2.ZERO:
		return "S"
	var angle: float = rad_to_deg(atan2(v.y, v.x))
	if angle < 0:
		angle += 360
	if angle < 22.5 or angle >= 337.5:
		return "E"
	elif angle < 67.5:
		return "SE"
	elif angle < 112.5:
		return "S"
	elif angle < 157.5:
		return "SW"
	elif angle < 202.5:
		return "W"
	elif angle < 247.5:
		return "NW"
	elif angle < 292.5:
		return "N"
	else:
		return "NE"
