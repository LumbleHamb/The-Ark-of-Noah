extends SceneTree

func _init() -> void:
	var legend_script: Script = load("res://scripts/tools/biome_paint_legend.gd") as Script
	if legend_script == null:
		print("FAIL: biome legend script missing")
		quit(1)
		return
	var db: BiomeDatabase = load("res://resources/world/biomes/world_biome_database.tres") as BiomeDatabase
	if db == null:
		print("FAIL: biome database missing")
		quit(1)
		return
	var lines: PackedStringArray = legend_script.call("build_legend", db) as PackedStringArray
	if lines.is_empty():
		print("FAIL: biome legend empty")
		quit(1)
		return
	for line: String in lines:
		print("LEGEND: " + line)
	print("RESULT: PASS")
	quit(0)
