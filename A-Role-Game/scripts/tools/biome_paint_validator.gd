class_name BiomePaintValidator
extends RefCounted

static func validate_paint_layer(biome_system: BiomeSystem) -> Dictionary[String, Variant]:
	var report: Dictionary[String, Variant] = {
		"ok": true,
		"issues": PackedStringArray(),
		"biome_count": 0,
		"painted_cells": 0,
	}
	if biome_system == null:
		report["ok"] = false
		report["issues"] = PackedStringArray(["BiomeSystem is null"])
		return report
	if biome_system.biome_database == null:
		report["ok"] = false
		report["issues"] = PackedStringArray(["BiomeDatabase is missing"])
		return report
	var issues: PackedStringArray = PackedStringArray()
	var biomes: Array[BiomeDefinition] = biome_system.biome_database.biomes
	report["biome_count"] = biomes.size()
	if biomes.is_empty():
		issues.append("BiomeDatabase contains no biomes")
	var paint_layer: TileMapLayer = biome_system.get_node_or_null(biome_system.biome_paint_layer_path) as TileMapLayer
	if paint_layer == null:
		issues.append("Biome paint layer path is invalid")
		report["ok"] = false
		report["issues"] = issues
		return report
	var used: Rect2i = paint_layer.get_used_rect()
	if used.size == Vector2i.ZERO:
		issues.append("Biome paint layer has no painted cells")
	else:
		for y: int in range(used.position.y, used.position.y + used.size.y):
			for x: int in range(used.position.x, used.position.x + used.size.x):
				var cell: Vector2i = Vector2i(x, y)
				var source_id: int = paint_layer.get_cell_source_id(cell)
				if source_id < 0:
					continue
				report["painted_cells"] = int(report["painted_cells"]) + 1
				var atlas: Vector2i = paint_layer.get_cell_atlas_coords(cell)
				if atlas.x < 0:
					issues.append("Cell %s has invalid atlas coords" % [str(cell)])
				elif atlas.x >= biomes.size():
					issues.append("Cell %s atlas x=%d has no matching biome" % [str(cell), atlas.x])
	report["issues"] = issues
	report["ok"] = issues.is_empty()
	return report
