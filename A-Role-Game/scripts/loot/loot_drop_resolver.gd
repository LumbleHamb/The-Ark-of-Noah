class_name LootDropResolver
extends RefCounted

static func spawn_enemy_drops(enemy: Node2D, config: EnemyLootConfig, biome_id: String, difficulty_level: float) -> void:
	if enemy == null or config == null:
		return
	var item_registry_node: Node = _find_item_registry(enemy)
	if item_registry_node == null:
		return
	var parent_node: Node = enemy.get_parent()
	if parent_node == null:
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = int(Time.get_ticks_usec()) + int(enemy.get_instance_id())
	var chance_mult: float = _resolve_chance_multiplier(config, biome_id, difficulty_level)
	for table: LootTable in config.guaranteed_tables:
		_spawn_from_table(table, parent_node, enemy.global_position, item_registry_node, rng, chance_mult)
	var weighted_table: LootTable = _pick_weighted_table(config, rng)
	if weighted_table != null:
		_spawn_from_table(weighted_table, parent_node, enemy.global_position, item_registry_node, rng, chance_mult)
	for _roll: int in range(maxi(0, config.bonus_rolls)):
		var bonus_table: LootTable = _pick_weighted_table(config, rng)
		if bonus_table != null:
			_spawn_from_table(bonus_table, parent_node, enemy.global_position, item_registry_node, rng, chance_mult)

static func _spawn_from_table(table: LootTable, parent_node: Node, origin: Vector2, item_registry_node: Node, rng: RandomNumberGenerator, chance_mult: float) -> void:
	if table == null:
		return
	var roll_count: int = maxi(0, table.get_roll_count(rng))
	for _roll: int in range(roll_count):
		var entry: LootEntry = _pick_entry(table, rng)
		if entry == null:
			continue
		if not entry.guaranteed:
			if rng.randf() > clampf(entry.chance * chance_mult, 0.0, 1.0):
				continue
		var quantity: int = maxi(1, entry.roll_quantity(rng))
		var stack: ItemStack = item_registry_node.call("create_stack", entry.item_id, quantity) as ItemStack
		if stack == null:
			continue
		var spread: Vector2 = Vector2(rng.randf_range(-24.0, 24.0), rng.randf_range(-16.0, -4.0))
		HarvestPickup.spawn(stack, parent_node, origin + spread)

static func _pick_entry(table: LootTable, rng: RandomNumberGenerator) -> LootEntry:
	var total: float = 0.0
	for entry: LootEntry in table.entries:
		if entry == null:
			continue
		total += maxf(0.0, entry.weight)
	if total <= 0.0001:
		return null
	var roll: float = rng.randf_range(0.0, total)
	var acc: float = 0.0
	for entry: LootEntry in table.entries:
		if entry == null:
			continue
		acc += maxf(0.0, entry.weight)
		if roll <= acc:
			return entry
	return null

static func _pick_weighted_table(config: EnemyLootConfig, rng: RandomNumberGenerator) -> LootTable:
	if config.weighted_tables.is_empty():
		return null
	if config.weighted_tables.size() != config.weighted_table_weights.size():
		return config.weighted_tables[rng.randi_range(0, config.weighted_tables.size() - 1)]
	var total: float = 0.0
	for weight: float in config.weighted_table_weights:
		total += maxf(0.0, weight)
	if total <= 0.0001:
		return config.weighted_tables[rng.randi_range(0, config.weighted_tables.size() - 1)]
	var roll: float = rng.randf_range(0.0, total)
	var acc: float = 0.0
	for i: int in range(config.weighted_tables.size()):
		acc += maxf(0.0, config.weighted_table_weights[i])
		if roll <= acc:
			return config.weighted_tables[i]
	return config.weighted_tables[config.weighted_tables.size() - 1]

static func _resolve_chance_multiplier(config: EnemyLootConfig, biome_id: String, difficulty_level: float) -> float:
	var biome_mult: float = 1.0
	if config.biome_chance_multiplier.has(biome_id):
		biome_mult = float(config.biome_chance_multiplier.get(biome_id, 1.0))
	var diff_mult: float = maxf(0.1, config.difficulty_chance_multiplier * maxf(0.2, difficulty_level))
	return biome_mult * diff_mult

static func _find_item_registry(context: Node) -> Node:
	var singleton: Variant = Engine.get_singleton("ItemRegistry")
	if singleton is Node:
		return singleton as Node
	if context.get_tree() == null:
		return null
	return context.get_tree().root.get_node_or_null("ItemRegistry")
