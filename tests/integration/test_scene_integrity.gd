extends GutTest
## Every game scene loads and instantiates cleanly, and authored data matches the art.

const SCENE_DIRS := ["res://actors", "res://world", "res://ui", "res://fx", "res://game"]


func _scenes(dir: String) -> Array[String]:
	var found: Array[String] = []
	for file in ResourceLoader.list_directory(dir):
		var path := dir.path_join(file)
		if file.ends_with("/"):
			found.append_array(_scenes(path.trim_suffix("/")))
		elif file.ends_with(".tscn"):
			found.append(path)
	return found


func test_all_scenes_instantiate() -> void:
	var count := 0
	for dir in SCENE_DIRS:
		for path in _scenes(dir):
			var packed := load(path) as PackedScene
			assert_not_null(packed, path)
			var node := packed.instantiate()
			assert_not_null(node, path)
			node.free()
			count += 1
	assert_gt(count, 15, "found the game's scenes")


func test_player_animations_match_the_sheets() -> void:
	var frames: SpriteFrames = load("res://actors/player/player_frames.tres")
	for dir in Facing.NAMES.values():
		assert_eq(frames.get_frame_count(StringName("idle_" + dir)), 1)
		assert_eq(frames.get_frame_count(StringName("walk_" + dir)), 4)
		assert_eq(frames.get_frame_count(StringName("attack_" + dir)), 3, "wind-up, strike, follow-through")
		assert_false(frames.get_animation_loop(StringName("attack_" + dir)))


func test_musgorico_animations_match_the_sheet() -> void:
	var frames: SpriteFrames = load("res://actors/musgorico/musgorico_frames.tres")
	for dir in Facing.NAMES.values():
		assert_eq(frames.get_frame_count(StringName("walk_" + dir)), 4)
		var tex := frames.get_frame_texture(StringName("walk_" + dir), 0)
		assert_eq(tex.get_size(), Vector2(16, 16))


func test_every_painted_tile_exists_in_the_tileset() -> void:
	var forest: Level = load("res://world/forest/forest.tscn").instantiate()
	add_child_autofree(forest)
	for layer_name in [^"Ground", ^"Decor"]:
		var layer := forest.get_node(layer_name) as TileMapLayer
		var cells := layer.get_used_cells()
		assert_gt(cells.size(), 0, str(layer_name))
		for cell in cells:
			if layer.get_cell_tile_data(cell) == null:
				fail_test("%s has a cell %s with no tile data" % [layer_name, cell])
				return


func test_forest_has_its_cast_and_a_full_ground() -> void:
	var forest: Level = load("res://world/forest/forest.tscn").instantiate()
	add_child_autofree(forest)
	assert_not_null(forest.player)
	assert_eq(forest.ground.get_used_rect(), Rect2i(0, 0, 40, 28))
	var entities := forest.get_node(^"Entities")
	assert_true(entities.y_sort_enabled, "actors and props are depth sorted")
	var hedgehogs := entities.get_children().filter(func(n: Node) -> bool: return n is Musgorico)
	assert_eq(hedgehogs.size(), 3)
	var shrines := entities.get_children().filter(func(n: Node) -> bool: return n is Shrine)
	assert_eq(shrines.size(), 1)


func test_camera_is_limited_to_the_ground() -> void:
	var forest: Level = load("res://world/forest/forest.tscn").instantiate()
	add_child_autofree(forest)
	var cam := forest.player.camera
	assert_eq(Vector4i(cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom), Vector4i(0, 0, 640, 448))
