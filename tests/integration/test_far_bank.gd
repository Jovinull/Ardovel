extends "res://tests/integration/adventure_case.gd"
## The other bank of the western gorge: the shout from across, the messenger line caught and
## hauled with real input (and lost, snagged and dropped), the bridge tied for good, the far
## bank with Iara and her camp, the road closed by the rockfall, and what the village says.

const FIXTURES := "res://tests/fixtures/saves"
const BY_THE_BRIDGE := Vector2(62, 54)
const SHRINE_ONLY: Array[StringName] = [&"forest_shrine_awakened"]
const GLINT_SEEN: Array[StringName] = [&"forest_shrine_awakened", &"heard_of_shrine",
		&"ruin_warden_defeated", &"ruin_heart_awakened", &"forest_echo_thicket_cut",
		&"forest_echo_found"]


func after_each() -> void:
	super.after_each()
	_steer(Vector2.ZERO)


func _continue_in(area: StringName, entry: StringName, flags: Array[StringName]) -> void:
	var state := Adventure.new(area, entry)
	for flag in flags:
		state.set_flag(flag)
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


## The shrine awake (the checkpoint) plus `extra`.
func _with(extra: Array) -> Array[StringName]:
	var flags: Array[StringName] = SHRINE_ONLY.duplicate()
	for flag: StringName in extra:
		flags.append(flag)
	return flags


func _bridge() -> RopeBridge:
	return game.level.get_node(^"Entities/RopeBridge") as RopeBridge


func _iara() -> IaraWorker:
	return game.level.get_node(^"Entities/Iara") as IaraWorker


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
		while _player().global_position.distance_to(point) > 4.0 and left > 0.0:
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


## Holds a move action until a trip to another area starts; true once it has.
func _walk_until_travelling(direction: Vector2, seconds: float) -> bool:
	var left := seconds
	while not game.is_travelling() and left > 0.0:
		_steer(direction)
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	_steer(Vector2.ZERO)
	return game.is_travelling()


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


## Waits (in physics frames, up to `seconds`) until `condition` holds.
func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


## From the shout to the line in hand, with real input: the hero walks onto the stone of the
## first throw as it slides back.
func _catch_the_line() -> void:
	_player().global_position = BY_THE_BRIDGE
	await wait_physics_frames(3)
	if _bridge().stage == RopeBridge.Stage.FALLEN:
		assert_eq(await _press_interact(), "WEST_BRIDGE_HAIL")
	assert_true(await _wait_until(func() -> bool: return _bridge().stage == RopeBridge.Stage.SLIDING, 4.0),
			"the line lands on the shelf")
	var left := 4.0
	while _bridge().stage == RopeBridge.Stage.SLIDING and left > 0.0:
		_steer((_bridge().weight_position() - _player().global_position).normalized())
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	_steer(Vector2.ZERO)
	await wait_physics_frames(2)
	assert_eq(_bridge().stage, RopeBridge.Stage.HELD, "the hero has the line")


## Hauls the deck across along the clear lane north of the lookout's rocks, with real input.
func _haul_along_the_clear_lane() -> bool:
	var lane: Array[Vector2] = [Vector2(100, 46), Vector2(160, 44), Vector2(230, 46)]
	assert_true(await _walk_through(lane, 8.0), "the clear lane is walkable")
	return _bridge().stage == RopeBridge.Stage.HAULED


## Flood fill with the hero's body over the level's collisions, inside `bounds`.
func _can_reach(from: Vector2i, to: Vector2i, bounds: Rect2i) -> bool:
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
			if not bounds.has_point(next) or seen.has(next):
				continue
			seen[next] = true
			query.transform = Transform2D(0.0, Vector2(next) + body.position)
			if space.intersect_shape(query, 1).is_empty():
				frontier.append(next)
	return false


func test_until_someone_answers_the_bridge_is_just_fallen() -> void:
	await _continue_in(&"west", &"east", SHRINE_ONLY)
	assert_eq(_bridge().stage, RopeBridge.Stage.FALLEN)
	assert_false(_can_reach(Vector2i(62, 54), Vector2i(6, 53), Rect2i(0, 0, 480, 384)),
			"the drop is closed where the bridge was")
	_player().global_position = Vector2(200, 60)
	await wait_physics_frames(60)
	assert_eq(_bridge().stage, RopeBridge.Stage.FALLEN, "nobody throws before the hero has looked")


func test_a_line_left_alone_slides_back_and_comes_again() -> void:
	await _continue_in(&"west", &"east", SHRINE_ONLY)
	_player().global_position = BY_THE_BRIDGE
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "WEST_BRIDGE_HAIL")
	assert_true(game.adventure.has_flag(RopeBridge.HAILED_FLAG))
	_player().global_position = Vector2(140, 100)  # near, but nowhere near the stone
	await wait_physics_frames(3)
	assert_true(await _wait_until(func() -> bool: return _bridge().stage == RopeBridge.Stage.SLIDING, 4.0))
	var first := _bridge().weight_position()
	assert_true(await _wait_until(func() -> bool: return _bridge().stage == RopeBridge.Stage.WAITING, 5.0),
			"it slides back over the edge")
	assert_true(await _wait_until(func() -> bool: return _bridge().stage == RopeBridge.Stage.SLIDING, 4.0),
			"and the far side throws again")
	assert_ne(_bridge().weight_position().round(), first.round(), "landing somewhere else")
	_player().global_position = Vector2(400, 300)
	await wait_physics_frames(3)
	assert_true(await _wait_until(func() -> bool: return _bridge().stage == RopeBridge.Stage.WAITING, 5.0))
	await wait_physics_frames(150)
	assert_eq(_bridge().stage, RopeBridge.Stage.WAITING, "no throws while the hero is away")


func test_the_hero_catches_hauls_and_ties_the_bridge_with_real_input() -> void:
	await _continue_in(&"west", &"east", SHRINE_ONLY)
	await _catch_the_line()
	assert_lt(_player().max_speed, 72.0, "the weight of the deck slows the hero")
	assert_true(await _haul_along_the_clear_lane(), "the deck's end comes up between the posts")
	assert_eq(_player().max_speed, 72.0, "free again once it is up")
	assert_true(await _walk_through([Vector2(120, 50), BY_THE_BRIDGE]))
	assert_eq(await _press_interact(), "FAR_TIED")
	assert_true(game.adventure.has_flag(RopeBridge.TIED_FLAG))
	assert_true(_bridge().is_tied())
	assert_eq(await _press_interact(), "WEST_BRIDGE_TIED")
	# Across on foot, between the posts and over the deck.
	assert_true(await _walk_until_travelling(Vector2.LEFT, 4.0), "the bridge leads across")
	await _settle()
	_assert_at_entry(&"far_bank", &"bridge")


func test_a_rock_in_the_way_snags_the_line() -> void:
	await _continue_in(&"west", &"east", SHRINE_ONLY)
	await _catch_the_line()
	# Behind the lookout's disc and the grey stones, the line runs into stone.
	_player().global_position = Vector2(228, 66)
	await wait_physics_frames(4)
	var hauled := _bridge().hauled
	await wait_physics_frames(20)
	assert_ne(_bridge().snag_point, Vector2.INF, "the line catches on the way")
	assert_eq(_bridge().hauled, hauled, "nothing more comes up while it is caught")
	assert_eq(_bridge().stage, RopeBridge.Stage.HELD)
	assert_true(await _walk_through([Vector2(228, 44)]), "stepping where it runs free")
	assert_eq(_bridge().snag_point, Vector2.INF)
	assert_gt(_bridge().hauled, hauled)


func test_a_blow_makes_the_hero_let_go_and_the_line_waits_where_it_fell() -> void:
	await _continue_in(&"west", &"east", SHRINE_ONLY)
	await _catch_the_line()
	assert_true(await _walk_through([Vector2(110, 46)]))
	var hauled := _bridge().hauled
	_player().health.take_damage(1)
	await wait_physics_frames(3)
	assert_eq(_bridge().stage, RopeBridge.Stage.DROPPED, "the hero let go")
	assert_eq(_player().max_speed, 72.0)
	var dropped_at := _bridge().weight_position()
	await wait_physics_frames(90)
	assert_eq(_bridge().weight_position(), dropped_at, "the line stays where it fell")
	assert_eq(_bridge().hauled, hauled, "what was hauled stays hauled")
	assert_true(await _walk_through([Vector2(140, 46), dropped_at + Vector2(0, 2)]))
	assert_eq(_bridge().stage, RopeBridge.Stage.HELD, "picked up again")


func test_a_half_haul_is_not_kept_but_the_shout_is() -> void:
	await _continue_in(&"west", &"east", SHRINE_ONLY)
	await _catch_the_line()
	assert_true(await _walk_through([Vector2(110, 46)]))
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(_bridge().stage, RopeBridge.Stage.WAITING, "a new throw, no second shout")
	assert_eq(_bridge().hauled, 0.0)
	_player().global_position = BY_THE_BRIDGE
	await wait_physics_frames(3)
	assert_true(await _wait_until(func() -> bool: return _bridge().stage == RopeBridge.Stage.SLIDING, 4.0))


func test_the_tied_bridge_stays_tied_and_leads_both_ways() -> void:
	await _continue_in(&"west", &"east", _with([RopeBridge.HAILED_FLAG, RopeBridge.TIED_FLAG]))
	assert_true(_bridge().is_tied())
	for trip in 3:
		_player().global_position = BY_THE_BRIDGE
		await wait_physics_frames(3)
		assert_true(await _walk_until_travelling(Vector2.LEFT, 4.0), "west over the bridge, trip %d" % trip)
		await _settle()
		_assert_at_entry(&"far_bank", &"bridge")
		assert_true(await _walk_until_travelling(Vector2.RIGHT, 4.0), "and back east, trip %d" % trip)
		await _settle()
		_assert_at_entry(&"west", &"far_bank")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_true(_bridge().is_tied(), "still tied after continuing")


func test_the_far_bank_can_be_walked_but_the_road_is_closed() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([RopeBridge.TIED_FLAG]))
	var from := Vector2i(game.level.entry(&"bridge").global_position)
	var bounds := Rect2i(0, 0, 416, 288)
	var places := {"Iara at the bridge": Vector2i(326, 140), "the press": Vector2i(140, 146),
			"the fire": Vector2i(236, 172), "the signpost": Vector2i(100, 204),
			"the rockfall's edge": Vector2i(82, 212)}
	for place: String in places:
		assert_true(_can_reach(from, places[place], bounds), "%s can be reached" % place)
		assert_true(_can_reach(places[place], from, bounds), "%s can be left" % place)
	assert_false(_can_reach(from, Vector2i(8, 206), bounds), "the rockfall closes the road west")
	assert_false(_can_reach(from, Vector2i(392, 60), bounds), "nobody walks into the gorge")


func test_iara_meets_the_hero_then_goes_back_to_work() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([RopeBridge.TIED_FLAG]))
	assert_false(_iara().is_working(), "she waits by the bridge")
	assert_eq(await _talk("Iara"), "IARA_MEET")
	game.get_node(^"HUD").call(&"_close_box")
	game.get_node(^"HUD").emit_signal(&"dialogue_finished")
	assert_true(game.adventure.has_flag(IaraWorker.MET_FLAG))
	assert_true(await _wait_until(func() -> bool: return _iara().is_working(), 15.0), "she walks back to her press")
	assert_eq(await _talk("Iara"), "IARA_ROAD", "without the glint, nobody's tracks to tell of")
	assert_eq(await _talk("Iara"), "IARA_WORK")
	assert_eq(await _talk("Iara"), "IARA_WORK")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_true(_iara().is_working(), "found at work on a later visit")


func test_after_the_glint_iara_tells_of_who_crossed() -> void:
	var flags: Array[StringName] = GLINT_SEEN.duplicate()
	flags.append(RopeBridge.TIED_FLAG)
	await _continue_in(&"far_bank", &"bridge", flags)
	assert_true((game.level.get_node(^"Decals/Footprints") as Node2D).visible, "tracks on the road")
	assert_eq(await _talk("Iara"), "IARA_MEET")
	assert_eq(await _talk("Iara"), "IARA_CROSSER")
	assert_eq(await _talk("Iara"), "IARA_ROAD")
	assert_eq(await _talk("Iara"), "IARA_WORK")
	var rockfall: Node2D = game.level.get_node(^"Entities/Rockfall")
	_player().global_position = rockfall.global_position + Vector2(12, -6)
	await wait_physics_frames(3)
	_player().face(Vector2.LEFT)
	assert_eq(await _press_interact(), "FAR_ROCKFALL_GLINT")


func test_without_the_glint_there_are_no_tracks_on_the_road() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([RopeBridge.TIED_FLAG]))
	assert_false((game.level.get_node(^"Decals/Footprints") as Node2D).visible)


func test_the_camp_can_be_looked_at() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([RopeBridge.TIED_FLAG]))
	var looks := {"OilPress1": "FAR_PRESS", "SeedBasket1": "FAR_SEEDS", "LampPost1": "FAR_LAMP",
			"Signpost1": "FAR_SIGNPOST"}
	for node_name: String in looks:
		var thing: Node2D = game.level.get_node("Entities/" + node_name)
		var said: String = (thing.get_node(^"Interactable") as Interactable).action.call(_player())
		assert_eq(said, looks[node_name], node_name)


func test_continuing_and_falling_on_the_far_bank() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([RopeBridge.TIED_FLAG]))
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	_assert_at_entry(&"far_bank", &"bridge")
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")
	game.travel(&"west", &"east")
	await _settle()
	assert_true(_bridge().is_tied())


func test_the_village_hears_of_iara_once() -> void:
	await _continue_in(&"village", &"north", [&"forest_shrine_awakened", &"heard_of_shrine",
			&"elder_thanked", IaraWorker.MET_FLAG])
	assert_eq(await _talk("Anselmo"), "ANSELMO_IARA")
	assert_ne(await _talk("Anselmo"), "ANSELMO_IARA")
	assert_eq(await _talk("Cida"), "CIDA_IARA")
	assert_ne(await _talk("Cida"), "CIDA_IARA")


func test_saves_from_before_reach_the_fallen_bridge() -> void:
	for file_name: String in ["v1_back_in_village.json", "v2_stall_worked.json"]:
		var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
		file.close()
		assert_true(game.continue_saved(), file_name)
		await _settle()
		game.travel(&"west", &"east")
		await _settle()
		assert_eq(_bridge().stage, RopeBridge.Stage.FALLEN, file_name)
		_player().global_position = BY_THE_BRIDGE
		await wait_physics_frames(3)
		assert_has(["WEST_BRIDGE_HAIL", "WEST_BRIDGE_GLINT_HAIL"], await _press_interact(), file_name)
		await _restart()


func test_texts_exist_in_both_languages() -> void:
	for key in ["WEST_BRIDGE_HAIL", "WEST_BRIDGE_GLINT_HAIL", "FAR_LINE_HINT", "FAR_TIED",
			"WEST_BRIDGE_TIED", "NPC_IARA", "IARA_MEET", "IARA_CROSSER", "IARA_ROAD", "IARA_WORK",
			"FAR_PRESS", "FAR_SEEDS", "FAR_LAMP", "FAR_SIGNPOST", "FAR_ROCKFALL", "FAR_ROCKFALL_GLINT",
			"ANSELMO_IARA", "CIDA_IARA"]:
		for locale in ["pt_BR", "en"]:
			var translation := TranslationServer.get_translation_object(locale)
			assert_ne(String(translation.get_message(key)), "", "%s in %s" % [key, locale])
