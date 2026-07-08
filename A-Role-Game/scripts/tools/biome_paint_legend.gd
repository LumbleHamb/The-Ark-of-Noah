class_name BiomePaintLegend
extends RefCounted

static func build_legend(database: BiomeDatabase) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	if database == null:
		lines.append("No biome database assigned")
		return lines
	for i: int in range(database.biomes.size()):
		var biome: BiomeDefinition = database.biomes[i]
		if biome == null:
			lines.append("%d -> <null biome>" % i)
			continue
		lines.append("%d -> %s (%s)" % [i, biome.display_name, biome.biome_id])
	return lines
