class_name AttackComponent
extends Component

## Handles melee attack state, hitbox positioning, and damage delivery.
## The entity should have an Area2D child named "hitbox".

signal attack_started(direction: String)
signal attack_finished()
signal body_hit(body: Node)

@export var hitbox: Area2D = null

@export var hitbox_offsets: Dictionary = {
	"S":  Vector2(0, 24),
	"SE": Vector2(17, 17),
	"E":  Vector2(24, 0),
	"NE": Vector2(17, -17),
	"N":  Vector2(0, -24),
	"NW": Vector2(-17, -17),
	"W":  Vector2(-24, 0),
	"SW": Vector2(-17, 17),
}

var is_attacking: bool = false
var _min_frames: int = 0
var _last_dir_key: String = "S"

func _component_ready() -> void:
	if not hitbox:
		hitbox = get_entity().get_node_or_null("hitbox") as Area2D
	if hitbox:
		hitbox.monitoring = true
		hitbox.body_entered.connect(_on_hitbox_body_entered)

## Starts an attack in the given direction. No-op if already attacking.
func start_attack(dir_key: String) -> void:
	if is_attacking:
		return
	is_attacking = true
	_min_frames = 0
	_last_dir_key = dir_key
	if hitbox:
		hitbox.position = hitbox_offsets.get(dir_key, Vector2(0, 24))
		hitbox.monitoring = true
	attack_started.emit(dir_key)

## Processes one frame. Returns true when the attack is complete.
func process_attack() -> bool:
	if not is_attacking:
		return true
	_min_frames += 1
	if _min_frames > 2:
		is_attacking = false
		if hitbox:
			hitbox.monitoring = false
		attack_finished.emit()
		return true
	return false

## Cancels the current attack immediately.
func cancel_attack() -> void:
	if is_attacking:
		is_attacking = false
		if hitbox:
			hitbox.monitoring = false
		attack_finished.emit()

func is_attacking_now() -> bool:
	return is_attacking

func _on_hitbox_body_entered(body: Node) -> void:
	if is_attacking and body.has_method("hit"):
		var entity: Node = get_entity()
		body.hit(entity)
		body_hit.emit(body)
