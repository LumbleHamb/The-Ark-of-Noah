class_name BiomeDefinition
extends Resource

@export var biome_id: String = "default"
@export var display_name: String = "Default"
@export var enemy_entries: Array[BiomeEnemyEntry] = []
@export var loot_table_ids: PackedStringArray = PackedStringArray()
@export var music_event: String = ""
@export var ambient_event: String = ""
@export var lighting_tint: Color = Color(1.0, 1.0, 1.0, 1.0)
@export var lighting_energy_multiplier: float = 1.0
@export var difficulty_multiplier: float = 1.0
@export var encounter_density_multiplier: float = 1.0
@export var movement_speed_multiplier: float = 1.0
