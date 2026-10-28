extends "res://tests/integration/adventure_case.gd"
## The western lookout: the walk out of the forest and back, the pass the Cardosas guard, the
## lookout with its disc, the gorge, the hollow in the pines and what the village makes of it.

const FIXTURES := "res://tests/fixtures/saves"
const EAST_ENTRY := Vector2(450, 300)
const LOOKOUT := Vector2(108, 72)
const GLINT_SEEN: Array[StringName] = [&"forest_shrine_awakened", &"heard_of_shrine",
		&"ruin_warden_defeated", &"ruin_heart_awakened", &"forest_echo_thicket_cut",
		&"forest_echo_found"]


func _continue_in(area: StringName, entry: StringName, flags: Array[StringName]) -> void:
	var state := Adventure.new(area, entry)
	for flag in flags:
		state.set_flag(flag)
	if state.has_flag(&"ruin_heart_awakened"):
		state.checkpoint_area = &"ruin"
		state.checkpoint_entry = &"heart"
	elif state.has_flag(&"forest_shrine_awakened"):
		state.checkpoint_area = &"forest"
		state.checkpoint_entry = &"shrine"
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


func _node(path: String) -> Node:
	return game.level.get_node(path)


func _mirror() -> LookoutMirror:
	return _node("Entities/LookoutMirror") as LookoutMirror


func _steer(direction: Vector2) -> void:
	var keys := {&"move_left": direction.x < -0.3, &"move_right": direction.x > 0.3,
			&"move_up": direction.y < -0.3, &"move_down": direction.y > 0.3}
	for action: StringName in keys:
		if keys[action]:
			Input.action_press(action)
		else:
			Input.action_release(action)


## Walks the hero through `points` with held move actions; true if every point was reached.
func _walk_through(points: Array[Vector2], seconds_each: float = 6.0) -> bool:
	for point in points:
		var left := seconds_each
		while _player().global_position.distance_to(point) > 6.0 and left > 0.0:
			_steer((point - _player().global_position).normalized())
			await wait_physics_frames(1)
			left -= get_physics_process_delta_time()
		if left <= 0.0:
			_steer(Vector2.ZERO)
			gut.p("stuck at %s on the way to %s" % [_player().global_position, point])
			return false
	_steer(Vector2.ZERO)
	await wait_physics_frames(2)
	return true


## Interacts with a real key press from where the hero stands; returns what was said.
func _press_interact() -> String:
	var said := [""]
	var listen := func(_target: Interactable, message: String) -> void: said[0] = message
	_player().interactor.interacted.connect(listen)
	Input.action_press(&"interact")
	await wait_physics_frames(2)
	Input.action_release(&"interact")
	await wait_physics_frames(2)
	_player().interactor.interacted.disconnect(listen)
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	return said[0]


## Flood fill with the hero's body over the level's collisions.
func _can_reach(from: Vector2i, to: Vector2i) -> bool:
	var body: CollisionShape2D = _player().get_node(^"Collision")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.collision_mask = 1
	query.exclude = [_player().get_rid()]
	var space := _player().get_world_2d().direct_space_state
	var bounds := Rect2i(0, 0, 480, 384)
	var frontier: Array[Vector2i] = [from]
	var seen := {from: true}
	var index := 0
	while index < frontier.size():
		var at := frontier[index]
		index += 1
		if at.distance_to(to) <= 4.0:
			return true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + offset * 4
			if not bounds.has_point(next) or seen.has(next):
				continue
			seen[next] = true
			query.transform = Transform2D(0.0, Vector2(next) + body.position)
			if space.intersect_shape(query, 1).is_empty():
				frontier.append(next)
	return false


func test_the_forest_path_leads_west_and_back_on_foot() -> void:
	game.start_new()
	await _settle()
	game.travel(&"forest", &"south")
	await _settle()
	for trip in 3:
		await _take_exit("ToWest")
		_assert_at_entry(&"west", &"east")
		assert_eq(game.adventure.area, &"west", "trip %d" % trip)
		# Back the way they came, walking east into the forest.
		assert_true(await _walk_until_travelling(Vector2.RIGHT, 3.0), "trip %d back" % trip)
		await _settle()
		_assert_at_entry(&"forest", &"west")
	assert_true(_can_reach_in_forest(Vector2i(24, 296), Vector2i(328, 416)),
			"the west path joins the forest's own paths")


## Holds a move action until the hero walks into an area's exit; true once the trip started.
func _walk_until_travelling(direction: Vector2, seconds: float) -> bool:
	var left := seconds
	while not game.is_travelling() and left > 0.0:
		_steer(direction)
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	_steer(Vector2.ZERO)
	return game.is_travelling()


func _can_reach_in_forest(from: Vector2i, to: Vector2i) -> bool:
	var body: CollisionShape2D = _player().get_node(^"Collision")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.collision_mask = 1
	query.exclude = [_player().get_rid()]
	var space := _player().get_world_2d().direct_space_state
	var frontier: Array[Vector2i] = [from]
	var seen := {from: true}
	var index := 0
	while index < frontier.size():
		var at := frontier[index]
		index += 1
		if at.distance_to(to) <= 4.0:
			return true
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + offset * 4
			if not Rect2i(8, 8, 624, 432).has_point(next) or seen.has(next):
				continue
			seen[next] = true
			query.transform = Transform2D(0.0, Vector2(next) + body.position)
			if space.intersect_shape(query, 1).is_empty():
				frontier.append(next)
	return false


func test_every_place_of_the_slope_can_be_reached_and_left() -> void:
	await _continue_in(&"west", &"east", [&"forest_shrine_awakened"])
	var entry := Vector2i(EAST_ENTRY)
	var places := {"the pass": Vector2i(210, 150), "the lookout": Vector2i(LOOKOUT),
			"the fallen bridge": Vector2i(64, 84), "the fire ring": Vector2i(150, 84),
			"the hollow in the pines": Vector2i(70, 372), "the cache": Vector2i(44, 364)}
	for place: String in places:
		assert_true(_can_reach(entry, places[place]), "%s can be reached" % place)
		assert_true(_can_reach(places[place], entry), "%s can be left" % place)
	assert_false(_can_reach(entry, Vector2i(20, 60)), "nobody walks into the gorge")


func test_the_hero_walks_up_through_the_pass_to_the_lookout() -> void:
	await _continue_in(&"west", &"east", [&"forest_shrine_awakened"])
	var route: Array[Vector2] = [Vector2(400, 298), Vector2(330, 286), Vector2(262, 254),
			Vector2(226, 216), Vector2(212, 176), Vector2(206, 140), Vector2(150, 108), LOOKOUT]
	assert_true(await _walk_through(route), "the hero reaches the lookout on foot")
	assert_false(_player().health.is_dead(), "the Cardosas hurt but do not stop a careful climb")
	assert_eq(await _press_interact(), "WEST_MIRROR_FIRST")


func test_before_the_glint_the_disc_rests_and_turns_toward_the_forest() -> void:
	await _continue_in(&"west", &"east", [&"forest_shrine_awakened"])
	_player().global_position = LOOKOUT
	await wait_physics_frames(3)
	assert_eq(_mirror().turn, LookoutMirror.Turn.SOUTH)
	assert_false((_node("Decals/Footprints") as Node2D).visible, "no fresh footprints yet")
	assert_eq(await _press_interact(), "WEST_MIRROR_FIRST")
	assert_true(game.adventure.has_flag(&"west_lookout_seen"))
	assert_false(_mirror().is_reflecting(), "no reflection while it faces the slope")
	assert_eq(await _press_interact(), "WEST_MIRROR_FOREST")
	assert_eq(_mirror().turn, LookoutMirror.Turn.FOREST)
	assert_true(_mirror().is_reflecting(), "turned to the forest, it throws daylight east")
	assert_eq(await _press_interact(), "WEST_MIRROR_SOUTH")
	assert_eq(await _press_interact(), "WEST_MIRROR_FOREST", "it can be turned again and again")


func test_after_the_glint_the_disc_already_faces_the_forest() -> void:
	await _continue_in(&"west", &"east", GLINT_SEEN)
	assert_true((_node("Decals/Footprints") as Node2D).visible, "fresh footprints in the dust")
	assert_eq(_mirror().turn, LookoutMirror.Turn.FOREST)
	_player().global_position = LOOKOUT
	await wait_physics_frames(3)
	var reflected := [0]
	_mirror().reflected.connect(func() -> void: reflected[0] += 1)
	assert_eq(await _press_interact(), "WEST_MIRROR_FIRST_GLINT")
	assert_eq(reflected[0], 1, "the first look already shows the reflection")
	_player().global_position = Vector2(58, 50)
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "WEST_BRIDGE_GLINT")
	_player().global_position = Vector2(150, 84)
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "WEST_FIRE_RING_GLINT")


func test_the_heart_in_the_pines_is_taken_once() -> void:
	await _continue_in(&"west", &"east", [&"forest_shrine_awakened"])
	var max_before := _player().health.max_health
	_player().global_position = Vector2(44, 366)
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "WEST_CACHE")
	_player().global_position = Vector2(70, 372)
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "HEART_VESSEL_FOUND")
	assert_true(game.adventure.has_flag(&"heart_vessel_west"))
	await wait_physics_frames(3)
	assert_eq(_player().health.max_health, max_before + Game.HEART_VESSEL_HEALTH)
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_null(game.level.get_node_or_null(^"Entities/HeartVessel"), "never there twice")
	assert_eq(_player().health.max_health, max_before + Game.HEART_VESSEL_HEALTH)


func test_continuing_in_the_west_and_falling_there() -> void:
	await _continue_in(&"west", &"east", GLINT_SEEN)
	_player().global_position = LOOKOUT
	await wait_physics_frames(3)
	await _press_interact()
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	_assert_at_entry(&"west", &"east")
	assert_true(game.adventure.has_flag(&"west_lookout_seen"))
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")
	game.travel(&"west", &"east")
	await _settle()
	assert_eq(_mirror().turn, LookoutMirror.Turn.FOREST)


func test_the_village_talks_about_the_lookout_once() -> void:
	var flags := GLINT_SEEN.duplicate()
	flags.append_array([&"elder_thanked", &"west_lookout_seen"])
	await _continue_in(&"village", &"north", flags)
	assert_eq(await _talk("Lia"), "LIA_WEST_GLINT")
	assert_eq(await _talk("Lia"), "LIA_ECHO_PATH", "said once, then her other lines")
	assert_eq(await _talk("Anselmo"), "ANSELMO_WEST")
	assert_ne(await _talk("Anselmo"), "ANSELMO_WEST")


func test_a_lookout_found_before_the_glint_is_told_without_it() -> void:
	await _continue_in(&"village", &"north", [&"forest_shrine_awakened", &"heard_of_shrine",
			&"elder_thanked", &"west_lookout_seen"])
	assert_eq(await _talk("Lia"), "LIA_WEST")
	assert_eq(await _talk("Anselmo"), "ANSELMO_WEST")


func test_saves_from_before_the_west_still_load_and_reach_it() -> void:
	for file_name: String in ["v1_back_in_village.json", "v2_stall_worked.json"]:
		var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
		file.close()
		assert_true(game.continue_saved(), file_name)
		await _settle()
		game.travel(&"forest", &"south")
		await _settle()
		await _take_exit("ToWest")
		_assert_at_entry(&"west", &"east")
		assert_false(game.adventure.has_flag(&"west_lookout_seen"), file_name)
		await _restart()
