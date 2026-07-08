extends SceneTree

func _init() -> void:
	var paths: Array[String] = [
		"res://scripts/loot/loot_entry.gd",
		"res://scripts/loot/loot_table.gd",
		"res://scripts/loot/enemy_loot_config.gd",
		"res://scripts/loot/enemy_loot_entry.gd",
		"res://scripts/loot/enemy_loot_database.gd",
		"res://scripts/world/biome_enemy_entry.gd",
		"res://scripts/world/biome_definition.gd",
		"res://scripts/world/biome_database.gd"
	]
	for p: String in paths:
		var res: Script = load(p) as Script
		if res == null:
			print("FAIL:", p)
		else:
			print("OK:", p, " class=", String(res.get_global_name()))
	quit()