class_name Projectile
extends Area2D

@export_category("Movement")
@export var speed: float = 200.0
@export var lifetime: float = 3.0

@export_category("Damage")
@export var damage: int = 1
@export var splash_radius: float = 0.0
@export var splash_damage: int = 0

@export_category("Behavior")
## How many enemies this projectile can pass through before stopping.
## 0 = stop on the first enemy hit; 1 = pass through 1 enemy, stop on the 2nd; etc.
@export var pierce_count: int = 0
## If true, show an explosion effect when the projectile stops/dies.
@export var explode_on_hit: bool = false
## Animation name to play on explosion (only used if explode_on_hit is true).
@export var explode_animation: String = ""

var direction: Vector2 = Vector2.RIGHT
var attacker: Node2D = null

var _age: float = 0.0
var _exploded: bool = false
var _pierces_left: int = 0
var _explode_frames: SpriteFrames = null

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_pierces_left = pierce_count

func _physics_process(delta: float) -> void:
	if _exploded:
		return
	_age += delta
	if _age >= lifetime:
		_despawn()
		return
	if not is_inside_tree():
		return
	global_position += direction * speed * delta

func init(dir: Vector2, from: Node2D) -> void:
	direction = dir.normalized()
	attacker = from
	_pierces_left = pierce_count

func set_flight_animation(frames: SpriteFrames, animation_name: String) -> void:
	if frames == null or animation_name.is_empty() or not frames.has_animation(animation_name):
		return
	if sprite != null:
		sprite.visible = false
	var anim: AnimatedSprite2D = AnimatedSprite2D.new()
	anim.name = "FlightFX"
	anim.sprite_frames = frames
	anim.animation = StringName(animation_name)
	anim.play()
	add_child(anim)

func set_explode_frames(frames: SpriteFrames) -> void:
	_explode_frames = frames

func _on_body_entered(body: Node) -> void:
	if _exploded:
		return
	if body == null or attacker == null:
		return
	if body == attacker:
		return

	if not attacker.is_in_group("player") and not body.is_in_group("player"):
		var atk_comp: AttackComponent = _find_attack_component(attacker)
		if atk_comp != null and not atk_comp.can_hit_allies:
			return

	var did_hit: bool = false
	var health: HealthComponent = body.get_node_or_null("HealthComponent") as HealthComponent
	if health != null:
		health.take_damage(damage, attacker)
		did_hit = true
		# Show floating damage number
		if damage > 0 and get_tree() != null:
			var world: Node = get_tree().current_scene
			if world != null:
				DamageNumber.spawn(damage, body.global_position, world)
	elif body.has_method("hit"):
		body.hit(attacker, damage)
		did_hit = true

	if not did_hit:
		return

	# Piercing: decrement and keep flying if pierces remain
	_pierces_left -= 1
	if _pierces_left >= 0:
		return

	# No more pierces — stop
	if explode_on_hit:
		_explode()
	else:
		_despawn()

func _despawn() -> void:
	# Cleanly remove the projectile without explosion effects.
	if _exploded:
		return
	_exploded = true
	set_deferred("monitoring", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	queue_free()

func _explode() -> void:
	if _exploded:
		return
	_exploded = true
	set_deferred("monitoring", false)
	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)
	_apply_splash_damage()

	var played_anim: bool = false
	if not explode_animation.is_empty() and _explode_frames != null and _explode_frames.has_animation(explode_animation):
		if sprite != null:
			sprite.visible = false
		var explode_fx: AnimatedSprite2D = AnimatedSprite2D.new()
		explode_fx.name = "ExplodeFX"
		explode_fx.sprite_frames = _explode_frames
		explode_fx.animation = StringName(explode_animation)
		explode_fx.play()
		add_child(explode_fx)
		await explode_fx.animation_finished
		played_anim = true

	if not played_anim:
		await get_tree().create_timer(0.05).timeout
	queue_free()

func _apply_splash_damage() -> void:
	if splash_radius <= 0.0 or splash_damage <= 0:
		return
	if attacker == null or get_tree() == null:
		return
	var world: World2D = get_world_2d()
	if world == null:
		return
	var query_shape: CircleShape2D = CircleShape2D.new()
	query_shape.radius = splash_radius
	var params: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	params.shape = query_shape
	params.transform = Transform2D(0.0, global_position)
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.collision_mask = collision_mask
	params.exclude = [self, attacker]
	var hits: Array[Dictionary] = world.direct_space_state.intersect_shape(params, 32)
	for hit: Dictionary in hits:
		var collider_var: Variant = hit.get("collider", null)
		if not (collider_var is Node):
			continue
		var target: Node = collider_var as Node
		if target == null or target == attacker:
			continue
		if not attacker.is_in_group("player") and not target.is_in_group("player"):
			var atk_comp: AttackComponent = _find_attack_component(attacker)
			if atk_comp != null and not atk_comp.can_hit_allies:
				continue
		var target_health: HealthComponent = target.get_node_or_null("HealthComponent") as HealthComponent
		if target_health != null:
			target_health.take_damage(splash_damage, attacker)
		elif target.has_method("hit"):
			target.hit(attacker, splash_damage)

func _find_attack_component(from: Node) -> AttackComponent:
	var comp: AttackComponent = from.get_node_or_null("AttackComponent") as AttackComponent
	if comp != null:
		return comp
	if from.get_parent() != null:
		for child: Node in from.get_parent().get_children():
			if child is AttackComponent:
				return child as AttackComponent
	return null
