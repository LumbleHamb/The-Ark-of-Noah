extends SceneTree

func _init() -> void:
	var validator_script: Script = load("res://scripts/tools/enemy_animation_contract_validator.gd") as Script
	if validator_script == null:
		print("FAIL: validator script missing")
		quit(1)
		return
	var scene_paths: PackedStringArray = PackedStringArray([
		"res://scenes/characters/enemies/Creatures/goblin.tscn",
		"res://scenes/characters/enemies/Creatures/moose_beast.tscn",
		"res://scenes/characters/enemies/Creatures/moose_beast_2.tscn",
		"res://scenes/characters/enemies/Creatures/moose_beast_3.tscn",
		"res://scenes/characters/enemies/Creatures/pot_enemy.tscn",
		"res://scenes/characters/enemies/Creatures/stone_golem.tscn",
		"res://scenes/characters/enemies/Creatures/stone_golem_2.tscn",
		"res://scenes/characters/enemies/orcs/crystal_orc.tscn",
		"res://scenes/characters/enemies/orcs/orc_1.tscn",
		"res://scenes/characters/enemies/orcs/orc_2.tscn",
		"res://scenes/characters/enemies/orcs/orc_3.tscn",
		"res://scenes/characters/enemies/orcs/orc_mage_1.tscn",
		"res://scenes/characters/enemies/orcs/orc_mage_2.tscn"
	])
	var results: Array[Dictionary] = validator_script.call("validate_scenes", scene_paths) as Array[Dictionary]
	var failures: int = 0
	for entry: Dictionary in results:
		var scene_path: String = String(entry.get("scene", ""))
		var invalid: bool = bool(entry.get("invalid", true))
		if invalid:
			failures += 1
			print("INVALID: %s | components=%s | anims=%s" % [scene_path, str(entry.get("missing_components", [])), str(entry.get("missing_animations", []))])
		else:
			print("OK: %s" % scene_path)
	if failures > 0:
		print("RESULT: FAIL (%d invalid scenes)" % failures)
		quit(1)
	else:
		print("RESULT: PASS")
		quit(0)
