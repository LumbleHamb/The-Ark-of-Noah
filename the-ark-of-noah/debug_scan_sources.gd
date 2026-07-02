extends SceneTree

func _init() -> void:
	var scene: PackedScene = load("res://scenes/world/map_biomes.tscn") as PackedScene
	if scene == null:
		printerr("load failed")
		quit(1)
		return
	var root: Node = scene.instantiate()
	var id_counts: Dictionary = {}
	_scan(root, id_counts)
	for key: int in id_counts.keys():
		print("source_id=", key, " cells=", id_counts[key])
	quit()

func _scan(node: Node, id_counts: Dictionary) -> void:
	if node is TileMapLayer:
		var layer: TileMapLayer = node as TileMapLayer
		for cell: Vector2i in layer.get_used_cells():
			var sid: int = layer.get_cell_source_id(cell)
			id_counts[sid] = int(id_counts.get(sid, 0)) + 1
	for child: Node in node.get_children():
		_scan(child, id_counts)
