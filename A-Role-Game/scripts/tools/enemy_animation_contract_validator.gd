class_name EnemyAnimationContractValidator
extends RefCounted

const REQUIRED_COMPONENTS: Array[String] = ["AttackComponent", "HealthComponent", "enemyAI", "hitbox"]
const REQUIRED_ANIMS: Array[String] = ["idle", "walk", "attack", "hurt", "death"]

static func validate_scene(scene_path: String) -> Dictionary[String, Variant]:
	var result: Dictionary[String, Variant] = {
		"scene": scene_path,
		"missing_components": PackedStringArray(),
		"missing_animations": PackedStringArray(),
		"invalid": false,
		"notes": PackedStringArray(),
	}
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		result["invalid"] = true
		result["notes"] = PackedStringArray(["PackedScene failed to load"])
		return result
	var root: Node = packed.instantiate()
	if root == null:
		result["invalid"] = true
		result["notes"] = PackedStringArray(["PackedScene failed to instantiate"])
		return result

	var missing_components: PackedStringArray = PackedStringArray()
	for node_name: String in REQUIRED_COMPONENTS:
		if root.get_node_or_null(node_name) == null:
			missing_components.append(node_name)
	result["missing_components"] = missing_components

	var ai: Node = root.get_node_or_null("enemyAI") as Node
	var sprite: AnimatedSprite2D = null
	for child: Node in root.get_children():
		if child is AnimatedSprite2D:
			sprite = child as AnimatedSprite2D
			break
	if ai == null:
		result["invalid"] = true
		result["notes"] = PackedStringArray(["Missing EnemyAI component"]) 
		root.queue_free()
		return result

	if sprite == null or sprite.sprite_frames == null:
		result["invalid"] = true
		result["notes"] = PackedStringArray(["Missing AnimatedSprite2D with SpriteFrames"]) 
		root.queue_free()
		return result

	var required_names: PackedStringArray = PackedStringArray([
		str(ai.get("idle_animation")),
		str(ai.get("walk_animation")),
		str(ai.get("attack_animation")),
		str(ai.get("hurt_animation")),
		str(ai.get("death_animation"))
	])
	var missing_anims: PackedStringArray = PackedStringArray()
	for i: int in range(required_names.size()):
		var anim_name: String = required_names[i]
		if anim_name.is_empty() or not sprite.sprite_frames.has_animation(anim_name):
			missing_anims.append(REQUIRED_ANIMS[i] + ":" + anim_name)
	result["missing_animations"] = missing_anims
	result["invalid"] = missing_components.size() > 0 or missing_anims.size() > 0
	root.queue_free()
	return result

static func validate_scenes(scene_paths: PackedStringArray) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for scene_path: String in scene_paths:
		results.append(validate_scene(scene_path))
	return results
