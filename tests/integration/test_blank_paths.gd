extends "res://tests/integration/adventure_case.gd"
## The halt on the road to Pedrabranca: the way west opening once Iara has gone (half a day on, with
## an interlude), the travelling witch and Breu (his greeting, his lead through the brush, his perch),
## the old path cut open with real input, the view from the high stone, the stretch drawn on her map
## and pinned on the board, her going east, and what stays.

const FIXTURES := "res://tests/fixtures/saves"
## Everything up to the end of the second spring (milestone 6.7).
const AFTER_SPRING: Array[StringName] = [&"forest_shrine_awakened", &"far_bank_bridge_tied", &"far_bank_iara_met",
		&"road_work_started", &"road_bar_lent", &"road_trunk_loosened", &"road_ditch_cleared",
		&"road_iara_heard_cleared", &"road_clearing_progressed", &"spring_iara_ready", &"spring_plan_heard",
		&"spring_stone_shifted", &"spring_iara_ahead", &"spring_iara_left"]
## From the road up the old path, stopping below each tangle.
const PATH_FOOT := Vector2(120, 140)
const BELOW: Array[Vector2] = [Vector2(120, 130), Vector2(120, 108), Vector2(120, 86)]
const AT_THE_VIEW := Vector2(120, 68)
const BY_THE_WITCH := Vector2(220, 172)


func after_each() -> void:
	super.after_each()
	_steer(Vector2.ZERO)


func _with(extra: Array) -> Array[StringName]:
	var flags: Array[StringName] = AFTER_SPRING.duplicate()
	for flag: StringName in extra:
		flags.append(flag)
	return flags


func _continue_in(area: StringName, entry: StringName, flags: Array[StringName]) -> void:
	var state := Adventure.new(area, entry)
	for flag in flags:
		state.set_flag(flag)
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


func _witch() -> WitchTraveler:
	return game.level.get_node_or_null(^"Entities/Witch") as WitchTraveler


func _breu() -> Breu:
	var witch := _witch()
	return witch.get_node(^"Breu") as Breu if witch != null else null


func _tangle(i: int) -> BrushTangle:
	return game.level.get_node("Entities/Tangle%d" % i) as BrushTangle


func _steer(direction: Vector2) -> void:
	var keys := {&"move_left": direction.x < -0.3, &"move_right": direction.x > 0.3,
			&"move_up": direction.y < -0.3, &"move_down": direction.y > 0.3}
	for action: StringName in keys:
		if keys[action]:
			Input.action_press(action)
		else:
			Input.action_release(action)


func _walk_through(points: Array[Vector2], seconds_each: float = 8.0) -> bool:
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


func _walk_until_travelling(direction: Vector2, seconds: float) -> bool:
	var left := seconds
	while not game.is_travelling() and left > 0.0:
		_steer(direction)
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	_steer(Vector2.ZERO)
	return game.is_travelling()


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)
	await wait_physics_frames(2)


func _press_interact() -> String:
	var said := [""]
	var listen := func(_target: Interactable, message: String) -> void: said[0] = message
	_player().interactor.interacted.connect(listen)
	await _tap(&"interact")
	_player().interactor.interacted.disconnect(listen)
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	return said[0]


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


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


func _talk_to_the_witch() -> String:
	assert_true(await _walk_through([BY_THE_WITCH]), "to the witch on foot")
	await _tap(&"move_down")
	return await _press_interact()


func _hovering_over(i: int) -> bool:
	var target := _tangle(i).global_position + Breu.HOVER
	return _breu().next_tangle() == _tangle(i) and _breu().global_position.distance_to(target) < 3.0


## Up the old path with real input, cutting each tangle as Breu hovers over it.
func _cut_the_way_up() -> void:
	assert_true(await _walk_through([PATH_FOOT]), "to the foot of the old path")
	for i in BELOW.size():
		assert_true(await _wait_until(_hovering_over.bind(i + 1), 4.0), "Breu hovers over tangle %d" % (i + 1))
		assert_true(await _walk_through([BELOW[i]]), "below tangle %d" % (i + 1))
		await _tap(&"move_up")
		await _tap(&"attack")
		assert_true(await _wait_until(_tangle(i + 1).is_cut, 1.0), "tangle %d cut by the sword" % (i + 1))
		await wait_physics_frames(20)


func test_the_way_west_opens_only_once_iara_has_gone() -> void:
	var flags := _with([])
	flags.erase(&"spring_iara_left")
	await _continue_in(&"road_west", &"far_bank", flags)
	assert_null(game.level.get_node_or_null(^"WayWest/ToWaystop"), "not while Iara waits at the bridge")
	await _restart()
	await _continue_in(&"road_west", &"far_bank", _with([]))
	_player().global_position = Vector2(60, 96)
	await wait_physics_frames(3)
	assert_true(await _walk_until_travelling(Vector2.LEFT, 4.0), "west on foot")
	assert_true(await _wait_until(game.is_showing_interlude, 3.0), "half a day on the road")
	await _settle()
	_assert_at_entry(&"waystop", &"east")
	assert_true(await _walk_until_travelling(Vector2.RIGHT, 4.0), "and back east")
	assert_true(await _wait_until(game.is_showing_interlude, 3.0))
	await _settle()
	_assert_at_entry(&"road_west", &"west")


func test_meeting_the_witch_and_breus_greeting() -> void:
	await _continue_in(&"waystop", &"east", _with([]))
	var breu := _breu()
	assert_eq(breu.state, Breu.State.SHOULDER, "at her shoulder")
	assert_true(await _walk_through([Vector2(260, 160)]), "towards the halt")
	assert_true(await _wait_until(func() -> bool: return breu.state == Breu.State.GREETING, 3.0), "he comes to greet")
	assert_true(await _wait_until(func() -> bool: return breu.state == Breu.State.SHOULDER, 3.0), "and goes back")
	assert_eq(await _talk_to_the_witch(), "WITCH_MEET")
	assert_true(game.adventure.has_flag(Blank.MET))
	assert_eq(await _talk_to_the_witch(), "WITCH_WAITING")
	assert_true(await _wait_until(func() -> bool: return breu.state == Breu.State.LEADING, 2.0), "off to show the way")
	assert_eq(breu.next_tangle(), _tangle(1))


func test_breu_leads_up_the_old_path_and_the_tangles_fall_to_the_sword() -> void:
	await _continue_in(&"waystop", &"east", _with([Blank.MET]))
	var from := Vector2i(game.level.entry(&"east").global_position)
	var bounds := Rect2i(0, 0, 416, 224)
	assert_false(_can_reach(from, Vector2i(AT_THE_VIEW), bounds), "the brush closes the old path")
	await _cut_the_way_up()
	assert_true(await _walk_through([AT_THE_VIEW]), "up to the high stone")
	assert_true(await _wait_until(_breu().is_perched, 3.0), "Breu perches on the high stone")
	await _tap(&"move_up")
	assert_eq(await _press_interact(), "BLANK_VIEW")
	assert_true(game.adventure.has_flag(Blank.VIEW_SEEN))
	assert_true(await _wait_until(func() -> bool: return _breu().state == Breu.State.SHOULDER, 2.0), "and flies back to her")


func test_she_draws_the_stretch_and_pins_her_note() -> void:
	await _continue_in(&"waystop", &"east", _with([Blank.MET, Blank.VIEW_SEEN]))
	var note := game.level.get_node(^"Entities/Board/WitchNote") as CanvasItem
	assert_false(note.visible)
	assert_eq(await _talk_to_the_witch(), "WITCH_DRAW")
	assert_true(game.adventure.has_flag(Blank.DRAWN))
	assert_true(await _wait_until(_witch().is_pinning, 1.0), "she walks to the board")
	assert_true(await _walk_through([Vector2(180, 170)]), "out of her way")
	assert_true(await _wait_until(func() -> bool: return note.visible, 15.0), "and pins her note")
	assert_true(await _wait_until(func() -> bool: return not _witch().is_pinning(), 15.0), "and walks back")
	assert_eq(_witch().position, _witch().camp_spot)
	assert_true(await _walk_through([Vector2(300, 142)]), "to the board on foot")
	await _tap(&"move_up")
	assert_eq(await _press_interact(), "BLANK_BOARD_AFTER")
	assert_eq(await _talk_to_the_witch(), "WITCH_AFTER")


func test_her_map_is_blank_past_the_bridge_until_she_draws_it() -> void:
	await _continue_in(&"waystop", &"east", _with([Blank.MET]))
	var map := game.level.get_node(^"Entities/WitchMap") as MapSheet
	_player().global_position = Vector2(198, 198)
	await wait_physics_frames(3)
	await _tap(&"interact")
	assert_true(map.is_open(), "it fills the screen")
	assert_eq((map.get_node(^"View/Picture") as TextureRect).texture, map.blank)
	var before := _player().global_position
	_steer(Vector2.LEFT)
	await wait_physics_frames(20)
	_steer(Vector2.ZERO)
	assert_eq(_player().global_position, before, "the area holds still while it is open")
	await wait_physics_frames(20)
	await _tap(&"interact")
	assert_false(map.is_open(), "pressing on closes it")
	game.adventure.set_flag(Blank.DRAWN)
	await wait_physics_frames(3)
	await _tap(&"interact")
	assert_eq((map.get_node(^"View/Picture") as TextureRect).texture, map.drawn, "drawn on to the gorge")
	await wait_physics_frames(20)
	await _tap(&"interact")


func test_she_goes_east_once_the_hero_has_walked_off() -> void:
	await _continue_in(&"waystop", &"east", _with([Blank.MET, Blank.VIEW_SEEN, Blank.DRAWN]))
	assert_not_null(_witch())
	assert_true(await _walk_until_travelling(Vector2.RIGHT, 4.0))
	await _settle()
	assert_true(game.adventure.has_flag(Blank.GONE), "she sets off while the hero is away")
	game.travel(&"waystop", &"east")
	await _settle()
	assert_null(_witch(), "she has gone east, Breu with her")
	assert_null(game.level.get_node_or_null(^"Entities/WitchMap"), "and her map")
	assert_true((game.level.get_node(^"Entities/Board/WitchNote") as CanvasItem).visible, "her note stays on the board")


func test_what_stays_after_continuing_and_after_a_fall() -> void:
	await _continue_in(&"waystop", &"east", _with([Blank.MET]))
	await _cut_the_way_up()
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_false(_tangle(1).is_cut(), "the cuts are not kept before the view is seen")
	game.adventure.set_flag(Blank.VIEW_SEEN)
	await _fall_and_retry()
	game.travel(&"waystop", &"east")
	await _settle()
	for i in 3:
		assert_true(_tangle(i + 1).is_cut(), "once seen, the old path stays open (%d)" % (i + 1))
	assert_true(_can_reach(Vector2i(game.level.entry(&"east").global_position), Vector2i(AT_THE_VIEW),
			Rect2i(0, 0, 416, 224)))
	assert_not_null(_witch(), "she waits for the hero to come back and tell")


func test_the_halt_holds_its_edges() -> void:
	await _continue_in(&"waystop", &"east", _with([]))
	var from := Vector2i(game.level.entry(&"east").global_position)
	var bounds := Rect2i(0, 0, 416, 224)
	for place: Vector2i in [Vector2i(BY_THE_WITCH), Vector2i(300, 142), Vector2i(36, 136), Vector2i(PATH_FOOT)]:
		assert_true(_can_reach(from, place, bounds), "%s can be reached" % place)
	assert_false(_can_reach(from, Vector2i(60, 80), bounds), "the pines west of the old path are closed")
	assert_false(_can_reach(from, Vector2i(300, 60), bounds), "and east of it")


func test_saves_from_before_find_no_way_west() -> void:
	for file_name: String in ["v1_back_in_village.json", "v2_stall_worked.json"]:
		var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
		file.close()
		assert_true(game.continue_saved(), file_name)
		await _settle()
		for flag in [Blank.MET, Blank.VIEW_SEEN, Blank.DRAWN, Blank.GONE, Spring.IARA_LEFT]:
			assert_false(game.adventure.has_flag(flag), "%s %s" % [file_name, flag])
		game.travel(&"road_west", &"far_bank")
		await _settle()
		assert_null(game.level.get_node_or_null(^"WayWest/ToWaystop"), file_name)
		await _restart()


func test_texts_exist_in_both_languages() -> void:
	for key in ["NPC_WITCH", "WITCH_MEET", "WITCH_WAITING", "WITCH_DRAW", "WITCH_AFTER", "BLANK_VIEW",
			"BLANK_BOARD", "BLANK_BOARD_AFTER", "BLANK_MILESTONE", "BLANK_ROAD_WEST", "BLANK_ROAD_EAST"]:
		for locale in ["pt_BR", "en"]:
			var translation := TranslationServer.get_translation_object(locale)
			assert_ne(String(translation.get_message(key)), "", "%s in %s" % [key, locale])
