extends SceneTree

func _init() -> void:
	var resource_paths: Array[String] = [
		"res://resources/loot/tables/enemy_common_melee.tres",
		"res://resources/loot/tables/enemy_rare_gems.tres",
		"res://resources/loot/configs/enemy_default_config.tres",
		"res://resources/loot/configs/enemy_caves_heavy_config.tres",
		"res://resources/loot/enemy_loot_database.tres",
		"res://resources/world/biomes/entries/meadows_goblin.tres",
		"res://resources/world/biomes/meadows_biome_def.tres",
		"res://resources/world/biomes/forest_biome_def.tres",
		"res://resources/world/biomes/caves_biome_def.tres",
		"res://resources/world/biomes/world_biome_database.tres"
	]
	for p: String in resource_paths:
		var r: Resource = load(p) as Resource
		if r == null:
			print("FAIL:", p)
		else:
			var script_text: String = ""
			var script_ref: Script = r.get_script() as Script
			if script_ref != null:
				script_text = script_ref.resource_path
			print("OK:", p, " class=", r.get_class(), " script=", script_text)
	quit()