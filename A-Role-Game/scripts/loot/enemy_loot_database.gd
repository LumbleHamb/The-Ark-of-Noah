class_name EnemyLootDatabase
extends Resource

@export var entries: Array[EnemyLootEntry] = []

func get_config_for_scene(scene: PackedScene) -> EnemyLootConfig:
	if scene == null:
		return null
	for entry: EnemyLootEntry in entries:
		if entry == null:
			continue
		if entry.enemy_scene == scene:
			return entry.loot_config
	return null
