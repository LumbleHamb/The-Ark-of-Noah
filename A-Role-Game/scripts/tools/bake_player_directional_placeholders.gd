extends SceneTree

func _init() -> void:
	var scene_path: String = "res://scenes/player/player.tscn"
	var packed: PackedScene = ResourceLoader.load(scene_path) as PackedScene
	if packed == null:
		push_error("Failed to load player scene")
		quit(1)
		return
	var root: Node = packed.instantiate()
	if root == null:
		push_error("Failed to instantiate player scene")
		quit(1)
		return
	var sprite: AnimatedSprite2D = root.get_node_or_null("player_animation") as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		push_error("Missing player_animation or sprite_frames")
		quit(1)
		return
	var sf: SpriteFrames = sprite.sprite_frames
	var prefixes: Array[String] = ["stab", "stab1", "stab2", "bowfire", "bowloadedidle", "bowreload"]
	var dirs: Array[String] = ["W", "N", "S", "NE", "NW", "SE", "SW"]
	var added: int = 0
	for prefix: String in prefixes:
		var src_name: StringName = StringName(prefix + "_E")
		if not sf.has_animation(src_name):
			continue
		for dir_key: String in dirs:
			var dst_name: StringName = StringName(prefix + "_" + dir_key)
			if sf.has_animation(dst_name):
				continue
			sf.add_animation(dst_name)
			sf.set_animation_speed(dst_name, sf.get_animation_speed(src_name))
			sf.set_animation_loop(dst_name, sf.get_animation_loop(src_name))
			var frame_count: int = sf.get_frame_count(src_name)
			for i: int in range(frame_count):
				sf.add_frame(dst_name, sf.get_frame_texture(src_name, i), sf.get_frame_duration(src_name, i), -1)
			added += 1
	var repacked: PackedScene = PackedScene.new()
	var pack_err: int = repacked.pack(root)
	if pack_err != OK:
		push_error("PackedScene.pack failed: %d" % pack_err)
		quit(1)
		return
	var save_err: int = ResourceSaver.save(repacked, scene_path)
	if save_err != OK:
		push_error("ResourceSaver.save failed: %d" % save_err)
		quit(1)
		return
	print("Baked directional placeholders. Added animations: %d" % added)
	quit()