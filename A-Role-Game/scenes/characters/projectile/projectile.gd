class_name Projectile
extends Area2D


## Simple projectile that moves in a set direction and damages on contact.
##
## Spawned by EnemyAIComponent's special attack (or any other spawner).
## Self-destructs after lifetime expires or on first hit.


@export_category("Movement")
@export var speed: float = 200.0

## How long the projectile lives before vanishing (seconds).
@export var lifetime: float = 3.0


@export_category("Damage")
@export var damage: int = 1


var direction: Vector2 = Vector2.RIGHT
var attacker: Node2D = null

var _age: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return

	global_position += direction * speed * delta


## Initialize the projectile's direction and who fired it.
func init(dir: Vector2, from: Node2D) -> void:
	direction = dir.normalized()
	attacker = from


func _on_body_entered(body: Node) -> void:
	if not body or not attacker:
		return
	if body == attacker:
		return

	# Prevent friendly fire: only damage player unless attacker allows allies
	if not attacker.is_in_group("player") and not body.is_in_group("player"):
		var atk_comp := _find_attack_component(attacker)
		if atk_comp and not atk_comp.can_hit_allies:
			return

	var health := body.get_node_or_null("HealthComponent") as HealthComponent
	if health:
		health.take_damage(damage, attacker)
		queue_free()
		return

	if body.has_method("hit"):
		body.hit(attacker, damage)
		queue_free()


## Fetches AttackComponent from attacker (assumed child or sibling pattern).
func _find_attack_component(from: Node) -> AttackComponent:
	# Try direct child first
	var comp := from.get_node_or_null("AttackComponent") as AttackComponent
	if comp:
		return comp
	# Try sibling (component pattern)
	if from.get_parent():
		for child in from.get_parent().get_children():
			if child is AttackComponent:
				return child
	return null
