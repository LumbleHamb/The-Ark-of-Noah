class_name BiomeDatabase
extends Resource

@export var biomes: Array[BiomeDefinition] = []


func get_biome_by_id(biome_id: String) -> BiomeDefinition:
	for biome: BiomeDefinition in biomes:
		if biome != null and biome.biome_id == biome_id:
			return biome
	return null
