class_name EnemyLootConfig
extends Resource

@export var config_id: String = ""
@export var guaranteed_tables: Array[LootTable] = []
@export var weighted_tables: Array[LootTable] = []
@export var weighted_table_weights: Array[float] = []
@export var bonus_rolls: int = 0
@export var despawn_after_seconds: float = 20.0
@export var biome_chance_multiplier: Dictionary[String, float] = {}
@export var difficulty_chance_multiplier: float = 1.0
