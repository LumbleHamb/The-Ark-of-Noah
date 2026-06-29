extends Node

## ============================================================================
## ITEM REGISTRY — Central registry for all ItemDefinition resources.
##
## Loads every .tres file from res://resources/items/definitions/ at startup
## and provides lookups by item_id.  Systems that need an item's icon, name,
## category, or other metadata go through this registry instead of hardcoding.
##
## Usage (after it's registered as an autoload):
##   var def: ItemDefinition = ItemRegistry.get_item("animal_bone")
##   var stack: ItemStack      = ItemRegistry.create_stack("animal_bone", 5)
## ============================================================================

var _items: Dictionary = {}  # item_id → ItemDefinition

func _ready() -> void:
	_load_all_definitions()


## Loads all ItemDefinition .tres files from the definitions folder.
func _load_all_definitions() -> void:
	var dir: DirAccess = DirAccess.open("res://resources/items/definitions/")
	if dir == null:
		push_warning("ItemRegistry: definitions directory not found.")
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres") or file_name.ends_with(".res"):
			var path: String = "res://resources/items/definitions/" + file_name
			var def_resource: Resource = load(path)
			if def_resource is ItemDefinition:
				var def: ItemDefinition = def_resource as ItemDefinition
				if def.item_id != "":
					if _items.has(def.item_id):
						push_warning("ItemRegistry: duplicate item_id '%s' in %s" % [def.item_id, file_name])
					_items[def.item_id] = def
		file_name = dir.get_next()
	dir.list_dir_end()


## Returns the ItemDefinition for the given item_id, or null.
func get_item(item_id: String) -> ItemDefinition:
	return _items.get(item_id, null)


## Returns true if an item with this item_id exists in the registry.
func has_item(item_id: String) -> bool:
	return _items.has(item_id)


## Creates an ItemStack from the definition, with icon/name pre-filled.
## Returns null if the item_id is not registered.
func create_stack(item_id: String, amount: int = 1) -> ItemStack:
	var def: ItemDefinition = get_item(item_id)
	if def == null:
		push_warning("ItemRegistry: unknown item_id '%s'" % item_id)
		return null
	return def.create_stack(amount)


## Returns a list of all registered item IDs.
func get_all_item_ids() -> Array[String]:
	return _items.keys()


## Returns a list of all registered ItemDefinitions.
func get_all_definitions() -> Array[ItemDefinition]:
	return _items.values()


## Returns all item IDs that match the given category.
func get_items_by_category(category: ItemDefinition.ItemCategory) -> Array[String]:
	var result: Array[String] = []
	for item_id: String in _items:
		if _items[item_id].category == category:
			result.append(item_id)
	return result
