extends "res://tests/integration/adventure_case.gd"
## The second spring: Iara getting ready to walk her oil to Pedrabranca after an absence, the big
## stone walked aside on her count with real input (a heave on her call, a slip before it, nothing
## lost by missing it), the night, her going ahead, the road west and its evidence at the slab
## bridge (the crew's work ends there), her decision and departure, and what the far bank keeps.

const FIXTURES := "res://tests/fixtures/saves"
## Everything up to the end of the road's repair (milestone 6.6).
const AFTER_ROAD: Array[StringName] = [&"forest_shrine_awakened", &"far_bank_bridge_tied", &"far_bank_iara_met",
		&"road_work_started", &"road_bar_lent", &"road_trunk_loosened", &"road_ditch_cleared",
		&"road_iara_heard_cleared", &"road_clearing_progressed"]
## Where the hero stands to bear down on the bar (its grip), reached on foot from the bridge.
const TO_THE_BAR: Array[Vector2] = [Vector2(300, 126), Vector2(214, 126), Vector2(176, 170), Vector2(130, 192),
		Vector2(110, 212), Vector2(84, 213), Vector2(70, 211)]
const GAP := Vector2(4, 194)


func after_each() -> void:
	super.after_each()
	_steer(Vector2.ZERO)


func _with(extra: Array) -> Array[StringName]:
	var flags: Array[StringName] = AFTER_ROAD.duplicate()
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


func _stone() -> BigStone:
	return game.level.get_node(^"Entities/BigStone") as BigStone


func _iara() -> Npc:
	return game.level.get_node_or_null(^"Entities/Iara") as Npc


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


func _examine(node_name: String, from: Vector2) -> String:
	_player().global_position = from
	await wait_physics_frames(3)
	var said := [""]
	var listen := func(target: Interactable, message: String) -> void:
		if target.get_parent().name == node_name:
			said[0] = message
	_player().interactor.interacted.connect(listen)
	await _press_interact()
	_player().interactor.interacted.disconnect(listen)
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


## On the bar with real input; then heaves on `heaves` of Iara's calls.
func _take_the_bar_and_heave(heaves: int) -> void:
	assert_true(await _walk_through(TO_THE_BAR), "to the bar's grip on foot")
	assert_eq(await _press_interact(), "SPRING_BAR_TAKE")
	assert_true(_stone().is_held())
	for i in heaves:
		assert_true(await _wait_until(_stone().is_calling, 4.0), "Iara calls, heave %d" % (i + 1))
		assert_eq((_iara() as IaraWorker).current_emote(), &"now", "her call shows")
		await _press_interact()
		if game.is_travelling():
			return


func test_nothing_of_the_spring_before_she_has_stacked_the_stones() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([]))
	assert_false((_stone().get_node(^"Bar") as CanvasItem).visible, "no crew's bar yet")
	assert_null(game.level.get_node_or_null(^"WayWest/ToRoadWest"), "no way west")
	assert_false((game.level.get_node(^"Entities/LoadReady") as CanvasItem).visible, "no load packed")
	assert_true((_iara() as IaraWorker).is_at_the_rockfall())
	assert_false(_can_reach(Vector2i(game.level.entry(&"bridge").global_position), Vector2i(GAP),
			Rect2i(0, 0, 416, 288)), "the biggest stone closes the road")
	# going up the slope and back is not being away
	await _take_exit("ToSlope")
	game.travel(&"far_bank", &"slope")
	await _settle()
	assert_false(game.adventure.has_flag(Spring.READY))


func test_one_absence_after_the_ditch_is_enough_for_both_the_stones_and_her_plan() -> void:
	var flags: Array[StringName] = AFTER_ROAD.duplicate()
	flags.erase(&"road_clearing_progressed")
	await _continue_in(&"far_bank", &"slope", flags)
	assert_true(await _walk_until_travelling(Vector2.UP, 3.0), "a look at the slope is not being away")
	await _settle()
	assert_false(game.adventure.has_flag(RoadWork.PROGRESSED))
	game.travel(&"far_bank", &"bridge")
	await _settle()
	assert_true(await _walk_until_travelling(Vector2.RIGHT, 4.0), "off over the bridge, once")
	await _settle()
	assert_true(game.adventure.has_flag(RoadWork.PROGRESSED), "the smaller stones stacked")
	assert_true(game.adventure.has_flag(Spring.READY), "and Iara ready, in the same absence")
	await _take_exit("ToFarBank")
	assert_true((_iara() as IaraWorker).is_at_the_stone())
	assert_eq(await _talk("Iara"), "IARA_SPRING_PLAN")


## A save from between the two (stones stacked, not yet ready) catches up on the next absence.
func test_after_an_absence_she_is_ready_at_the_stone_and_tells_her_plan() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([]))
	assert_true(await _walk_until_travelling(Vector2.RIGHT, 4.0), "off over the bridge")
	await _settle()
	assert_true(game.adventure.has_flag(Spring.READY), "time passes while the hero is away")
	await _take_exit("ToFarBank")
	var iara := _iara() as IaraWorker
	assert_true(iara.is_at_the_stone(), "crouched at the big stone")
	assert_true((_stone().get_node(^"Bar") as CanvasItem).visible, "the crew's long bar against it")
	assert_true((game.level.get_node(^"Entities/LoadReady/LoadAtCamp") as CanvasItem).is_visible_in_tree(),
			"her load packed by the press")
	assert_eq(await _talk("Iara"), "IARA_SPRING_PLAN")
	assert_eq(await _talk("Iara"), "IARA_SPRING_COUNT")
	assert_eq(await _talk("Iara"), "IARA_SPRING_COUNT")


func test_the_stone_walks_aside_on_her_count_with_real_input() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([Spring.READY, Spring.PLAN_HEARD]))
	var moved: Array[int] = []
	_stone().notch_moved.connect(func(n: int) -> void: moved.append(n))
	var start: Vector2 = (_stone().get_node(^"Stone") as Node2D).position
	await _take_the_bar_and_heave(BigStone.NOTCHES)
	assert_eq(moved, [1, 2, 3, 4, 5] as Array[int], "a notch a heave")
	await _settle()
	assert_true(game.adventure.has_flag(Spring.SHIFTED))
	_assert_at_entry(&"far_bank", &"stone")
	assert_eq((_stone().get_node(^"Stone") as Node2D).position, start + BigStone.STEP * BigStone.NOTCHES,
			"the next morning the stone sits at the edge")
	assert_true((_stone().get_node(^"Drag") as CanvasItem).visible, "with its furrows behind it")
	var iara := _iara() as IaraWorker
	assert_true(iara.is_waiting_by_the_gap(), "Iara by the gap")
	assert_true((iara.get_node(^"Load") as CanvasItem).visible, "her load on her back")
	assert_false((game.level.get_node(^"Entities/LoadReady/LoadAtCamp") as CanvasItem).is_visible_in_tree())
	assert_true(_can_reach(Vector2i(game.level.entry(&"stone").global_position), Vector2i(GAP),
			Rect2i(0, 0, 416, 288)), "people on foot get by")
	assert_eq(String(game.level.get_node(^"Entities/Rockfall").call(&"_text")), "FAR_STONE_SHIFTED")


func test_heaving_too_soon_slips_and_missing_her_call_costs_nothing() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([Spring.READY, Spring.PLAN_HEARD]))
	await _take_the_bar_and_heave(1)
	assert_eq(_stone().notch(), 1)
	assert_false(_stone().is_calling(), "she counts again")
	await _press_interact()  # before her call
	assert_eq(_stone().notch(), 0, "the bar slips and the stone settles back")
	assert_eq((_iara() as IaraWorker).current_emote(), &"frown")
	await _press_interact()  # before her call again, with nothing to lose
	assert_eq(_stone().notch(), 0, "never below the start")
	assert_true(await _wait_until(_stone().is_calling, 4.0))
	assert_true(await _wait_until(func() -> bool: return not _stone().is_calling(), 2.0), "the call passes")
	assert_eq(_stone().notch(), 0, "missing it costs nothing")
	assert_true(_stone().is_held(), "and she counts on")


func test_letting_go_midway_and_coming_back() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([Spring.READY, Spring.PLAN_HEARD]))
	await _take_the_bar_and_heave(2)
	assert_eq(_stone().notch(), 2)
	assert_true(await _walk_through([Vector2(110, 186)]), "walking off")
	assert_false(_stone().is_held(), "lets go of the bar")
	assert_eq((_iara() as IaraWorker).current_emote(), &"", "she stops counting")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(_stone().notch(), 0, "the notches are not kept")
	assert_false(game.adventure.has_flag(Spring.SHIFTED))
	assert_true((_stone().get_node(^"Bar") as CanvasItem).visible, "the bar is still there to take")


func test_she_goes_ahead_and_the_road_west_shows_where_the_crew_stops() -> void:
	await _continue_in(&"far_bank", &"stone", _with([Spring.READY, Spring.PLAN_HEARD, Spring.SHIFTED]))
	assert_eq(await _talk("Iara"), "IARA_SPRING_MORNING")
	assert_true(game.adventure.has_flag(Spring.AHEAD))
	assert_true(await _wait_until(func() -> bool: return _iara() == null, 6.0), "she goes through the gap")
	_player().global_position = game.level.entry(&"stone").global_position
	await wait_physics_frames(3)
	assert_true(await _walk_through([Vector2(40, 196), Vector2(16, 194)]), "into the gap on foot")
	assert_true(await _walk_until_travelling(Vector2.LEFT, 3.0), "and on to the road west")
	await _settle()
	_assert_at_entry(&"road_west", &"far_bank")
	var iara := _iara() as IaraTraveler
	assert_true(iara.is_waiting_at_the_bridge(), "she is at the slab bridge")
	assert_true((iara.get_node(^"Load") as CanvasItem).visible)
	assert_eq(await _examine("DitchChoked", Vector2(264, 96)), "SPRING_DITCH_CHOKED")
	assert_true(await _walk_through([Vector2(200, 96), Vector2(140, 92), Vector2(100, 92)]), "over the bridge on foot")
	assert_eq(await _examine("DitchCleared", Vector2(80, 96)), "SPRING_DITCH_CLEARED")
	assert_eq(await _examine("CrewMarks", Vector2(134, 138)), "SPRING_MARKS")
	assert_true(game.adventure.has_flag(Spring.MARKS_SEEN))
	assert_eq(await _examine("Milestone", Vector2(36, 96)), "SPRING_MILESTONE")
	_player().global_position = iara.global_position + Vector2(-14, 0)
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "IARA_SPRING_BRIDGE")
	assert_true(game.adventure.has_flag(Spring.IARA_LEFT))
	assert_true(await _wait_until(func() -> bool: return _iara() == null, 8.0), "she walks on west, out of sight")
	assert_eq(await _examine("Stake", Vector2(124, 96)), "SPRING_STAKE")
	assert_true(await _walk_until_travelling(Vector2.RIGHT, 12.0), "back east")
	await _settle()
	_assert_at_entry(&"far_bank", &"road_west")
	assert_null(_iara(), "Iara is not on the far bank")
	assert_eq(await _examine("Note", Vector2(156, 154)), "SPRING_NOTE")
	assert_eq(await _examine("Knots", Vector2(352, 120)), "SPRING_KNOTS")
	assert_true(game.adventure.has_flag(Spring.KNOTS_CHECKED))
	assert_eq(await _examine("Knots", Vector2(352, 120)), "SPRING_KNOTS_AFTER")


func test_the_road_west_holds_its_edges() -> void:
	await _continue_in(&"road_west", &"far_bank", _with([Spring.READY, Spring.SHIFTED, Spring.AHEAD]))
	var from := Vector2i(game.level.entry(&"far_bank").global_position)
	var bounds := Rect2i(0, 0, 416, 192)
	for place: Vector2i in [Vector2i(100, 96), Vector2i(36, 96), Vector2i(134, 138), Vector2i(300, 150)]:
		assert_true(_can_reach(from, place, bounds), "%s can be reached" % place)
	assert_false(_can_reach(from, Vector2i(200, 72), bounds), "nobody walks in the ditch")
	assert_false(_can_reach(from, Vector2i(152, 30), bounds), "nor in the brook")
	assert_false(_can_reach(from, Vector2i(200, 30), bounds), "nor past the ditch into the pines")


func test_what_stays_after_continuing_and_after_a_fall() -> void:
	await _continue_in(&"road_west", &"far_bank", _with([Spring.READY, Spring.SHIFTED, Spring.AHEAD]))
	await _fall_and_retry()
	game.travel(&"road_west", &"far_bank")
	await _settle()
	assert_not_null(_iara(), "she is still at the bridge after the hero's fall")
	game.adventure.set_flag(Spring.IARA_LEFT)
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_null(_iara(), "gone west")
	game.travel(&"far_bank", &"road_west")
	await _settle()
	assert_eq((_stone().get_node(^"Stone") as Node2D).position, BigStone.STEP * BigStone.NOTCHES,
			"the stone stays at the edge")
	assert_not_null(game.level.get_node_or_null(^"WayWest/ToRoadWest"), "and the way west stays open")


func test_saves_from_before_find_the_stone_where_it_was() -> void:
	for file_name: String in ["v1_back_in_village.json", "v2_stall_worked.json"]:
		var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
		file.close()
		assert_true(game.continue_saved(), file_name)
		await _settle()
		game.travel(&"far_bank", &"bridge")
		await _settle()
		assert_eq(_stone().notch(), 0, file_name)
		assert_false((_stone().get_node(^"Bar") as CanvasItem).visible, file_name)
		assert_null(game.level.get_node_or_null(^"WayWest/ToRoadWest"), file_name)
		for flag in [Spring.READY, Spring.SHIFTED, Spring.AHEAD, Spring.IARA_LEFT]:
			assert_false(game.adventure.has_flag(flag), "%s %s" % [file_name, flag])
		await _restart()


func test_texts_exist_in_both_languages() -> void:
	for key in ["IARA_SPRING_PLAN", "IARA_SPRING_COUNT", "SPRING_BAR_TAKE", "SPRING_STONE_NIGHT",
			"IARA_SPRING_MORNING", "FAR_STONE_SHIFTED", "SPRING_NOTE", "SPRING_KNOTS", "SPRING_KNOTS_AFTER",
			"SPRING_STAKE", "SPRING_MARKS", "SPRING_DITCH_CHOKED", "SPRING_DITCH_CLEARED", "SPRING_MILESTONE",
			"IARA_SPRING_BRIDGE", "IARA_SPRING_GOING"]:
		for locale in ["pt_BR", "en"]:
			var translation := TranslationServer.get_translation_object(locale)
			assert_ne(String(translation.get_message(key)), "", "%s in %s" % [key, locale])
