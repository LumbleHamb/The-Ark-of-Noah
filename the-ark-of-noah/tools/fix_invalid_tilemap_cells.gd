extends SceneTree

func _init() -> void:
	var scene_path: String = "res://scenes/world/map_biomes.tscn"
	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		printerr("FAILED: could not load scene")
		quit(1)
		return

	var root: Node = packed.instantiate()
	var total_removed: int = 0
	var layers_changed: int = 0

	for node: Node in _collect_nodes(root):
		if node is TileMapLayer:
			var layer: TileMapLayer = node as TileMapLayer
			var tile_set: TileSet = layer.tile_set
			if tile_set == null:
				continue

			var removed_here: int = 0
			for cell: Vector2i in layer.get_used_cells():
				var source_id: int = layer.get_cell_source_id(cell)
				if source_id == -1:
					continue
				if not tile_set.has_source(source_id):
					layer.erase_cell(cell)
					removed_here += 1
					continue
				var source: TileSetSource = tile_set.get_source(source_id)
				if source is TileSetAtlasSource:
					var atlas_source: TileSetAtlasSource = source as TileSetAtlasSource
					var atlas_coords: Vector2i = layer.get_cell_atlas_coords(cell)
					if not atlas_source.has_tile(atlas_coords):
						layer.erase_cell(cell)
						removed_here += 1
			if removed_here > 0:
				layers_changed += 1
				total_removed += removed_here
				print("layer=", layer.get_path(), " removed=", removed_here)

	if total_removed > 0:
		var repacked: PackedScene = PackedScene.new()
		var ok: Error = repacked.pack(root)
		if ok != OK:
			printerr("FAILED: pack error ", ok)
			quit(2)
			return
		var save_ok: Error = ResourceSaver.save(repacked, scene_path)
		if save_ok != OK:
			printerr("FAILED: save error ", save_ok)
			quit(3)
			return

	print("SUMMARY layers_changed=", layers_changed, " total_removed=", total_removed)
	quit()

func _collect_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var node: Node = stack.pop_back()
		out.append(node)
		for child: Node in node.get_children():
			stack.append(child)
	return out
