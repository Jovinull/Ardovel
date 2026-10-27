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
	var plants := entities.get_children().filter(func(n: Node) -> bool: return n is Cardosa)
	assert_eq(plants.size(), 2)


func test_forest_instances_inherit_their_scene_settings() -> void:
	# Instances must not carry stale copies of layers or scripts from the scene they come from.
	var forest: Level = load("res://world/forest/forest.tscn").instantiate()
	add_child_autofree(forest)
	for node in forest.get_node(^"Entities").get_children():
		if node is Musgorico:
			assert_eq((node as Musgorico).collision_layer, 4, node.name)
			assert_eq((node as Musgorico).collision_mask, 7, node.name)
	var text := FileAccess.get_file_as_string("res://world/forest/forest.tscn")
	assert_false(text.contains("
collision_layer = 4
"), "no per-instance layer overrides in the forest scene")


func test_camera_is_limited_to_the_ground() -> void:
	var forest: Level = load("res://world/forest/forest.tscn").instantiate()
	add_child_autofree(forest)
	var cam := forest.player.camera
	assert_eq(Vector4i(cam.limit_left, cam.limit_top, cam.limit_right, cam.limit_bottom), Vector4i(0, 0, 640, 448))


func test_every_area_knows_its_id_and_has_a_return_point_for_each_passage() -> void:
	for area in Game.AREAS:
		var level: Level = load(Game.AREAS[area]).instantiate()
		assert_eq(level.area_id, area, "%s scene declares its id" % area)
		assert_not_null(level.music, "%s has music" % area)
		var exits := level.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is AreaExit)
		assert_gt(exits.size(), 0, "%s can be left" % area)
		for exit: AreaExit in exits:
			assert_true(Game.AREAS.has(exit.target_area), "%s leads to a known area" % exit.name)
			var target: Level = load(Game.AREAS[exit.target_area]).instantiate()
			assert_not_null(target.entry(exit.target_entry), "%s arrives at %s/%s" % [exit.name, exit.target_area, exit.target_entry])
			target.free()
		level.free()


func test_a_new_adventure_and_the_shrine_point_to_real_entries() -> void:
	var start := Adventure.new()
	var village: Level = load(Game.AREAS[start.area]).instantiate()
	assert_not_null(village.entry(start.entry))
	village.free()
	var forest: Level = load(Game.AREAS[&"forest"]).instantiate()
	var shrine: Shrine = forest.get_node(^"Entities/Shrine")
	assert_not_null(forest.entry(shrine.return_entry))
	forest.free()


func test_village_has_its_cast() -> void:
	var village: Level = load("res://world/village/village.tscn").instantiate()
	var npcs := village.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Npc)
	assert_eq(npcs.size(), 3)
	for npc: Npc in npcs:
		assert_false(npc.display_name.is_empty())
		assert_not_null(npc.sheet)
		assert_not_null(npc.faceset)
		assert_gt(npc.lines.size(), 0)
		assert_true(npc.lines.back().requires.is_empty(), "%s always has something to say" % npc.name)
	assert_eq(village.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is GuardianStatue).size(), 1)
	assert_eq(village.find_children("*", "", true, false).filter(func(n: Node) -> bool: return n is Player).size(), 1)
	village.free()


func test_the_ruin_has_its_pieces() -> void:
	var ruin: Level = load(Game.AREAS[&"ruin"]).instantiate()
	var count := func(type: Variant) -> int:
		return ruin.find_children("*", "", true, false).filter(func(n: Node) -> bool: return is_instance_of(n, type)).size()
	assert_eq(count.call(RuinGuardian), 4, "the clue")
	assert_eq(count.call(LightPedestal), 4, "the answer")
	assert_eq(count.call(PressurePlate), 1)
	assert_eq(count.call(PushBlock), 1)
	assert_eq(count.call(RootWarden), 1)
	assert_eq(count.call(Player), 1)
	assert_eq(count.call(HeartVessel), 1)
	var heart: Shrine = ruin.get_node(^"Entities/RootHeart")
	assert_not_null(ruin.entry(heart.return_entry), "the heart is a checkpoint with a real entry")
	var puzzle: LightsPuzzle = ruin.get_node(^"LightsPuzzle")
	assert_eq(puzzle.pedestals.size(), puzzle.clues.size(), "one orb per guardian")
	ruin.free()
