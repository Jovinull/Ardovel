extends "res://tests/integration/adventure_case.gd"
## Pedrabranca's east quarter: the road on west from the halt (a day and a half, with an
## interlude), Iara in town, the works yard crossed with real input in step with the carriers (a
## bump costs no health), Mestra Rufina on the quarry terrace and why the line moved, the halt she
## calls, her facing Iara in the yard, the notice coming down at the gate, Teodoro, and what stays.

const FIXTURES := "res://tests/fixtures/saves"
## Everything up to the witch going east (milestone 6.8).
const AFTER_BLANK: Array[StringName] = [&"forest_shrine_awakened", &"far_bank_bridge_tied", &"far_bank_iara_met",
		&"road_work_started", &"road_bar_lent", &"road_trunk_loosened", &"road_ditch_cleared",
		&"road_iara_heard_cleared", &"road_clearing_progressed", &"spring_iara_ready", &"spring_plan_heard",
		&"spring_stone_shifted", &"spring_iara_ahead", &"spring_iara_left", &"blank_witch_met",
		&"blank_view_seen", &"blank_map_drawn", &"blank_witch_gone"]
## Up the yard at one column: below the lowest lane, between the lanes, and above the highest.
const YARD_X := 240.0
const STOPS: Array[float] = [190.0, 150.0, 116.0, 78.0]
const ON_THE_TERRACE: Array[Vector2] = [Vector2(240, 56), Vector2(240, 24), Vector2(284, 24)]
const OUT_OF_HER_WAY: Array[Vector2] = [Vector2(284, 8), Vector2(330, 8), Vector2(344, 20)]
const DOWN_THE_STEPS: Array[Vector2] = [Vector2(240, 24), Vector2(240, 56), Vector2(240, 92), Vector2(240, 150),
		Vector2(226, 178)]
const TO_THE_YARD: Array[Vector2] = [Vector2(410, 222), Vector2(300, 226), Vector2(YARD_X, 226), Vector2(YARD_X, 190)]
const BY_IARA: Array[Vector2] = [Vector2(410, 222), Vector2(372, 222), Vector2(374, 236)]
const BACK_TO_IARA: Array[Vector2] = [Vector2(YARD_X, 226), Vector2(372, 222), Vector2(374, 236)]


func after_each() -> void:
	super.after_each()
	_steer(Vector2.ZERO)


func _with(extra: Array) -> Array[StringName]:
	var flags: Array[StringName] = AFTER_BLANK.duplicate()
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


func _rufina() -> Rufina:
	return game.level.get_node(^"Entities/Rufina") as Rufina


func _iara() -> IaraInTown:
	return game.level.get_node(^"Entities/Iara") as IaraInTown


func _carriers() -> Array[Carrier]:
	var found: Array[Carrier] = []
	for i in 3:
		found.append(game.level.get_node("Entities/Carriers%d" % (i + 1)) as Carrier)
	return found


func _all_resting() -> bool:
	for carrier in _carriers():
		if not carrier.is_resting():
			return false
	return true


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


func _talk_facing(direction: StringName) -> String:
	await _tap(direction)
	return await _press_interact()


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


## The pair on this lane has just gone past the hero's column, walking away from it.
func _gone_past(carrier: Carrier) -> bool:
	var dx := carrier.global_position.x - YARD_X
	return absf(dx) > 34.0 and absf(dx) < 60.0 and signf(dx) == carrier.heading()


## Up the yard with real input, waiting below each lane for its pair to go past.
func _cross_the_yard() -> void:
	var lanes := _carriers()
	assert_true(await _walk_through([Vector2(YARD_X, STOPS[0])]), "to the foot of the yard")
	for i in 3:
		var carrier := lanes[2 - i]
		assert_true(await _wait_until(_gone_past.bind(carrier), 12.0), "the pair on lane %d goes past" % (3 - i))
		assert_true(await _walk_through([Vector2(YARD_X, STOPS[i + 1])], 3.0), "across lane %d" % (3 - i))


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


func test_the_road_goes_on_west_from_the_halt() -> void:
	await _continue_in(&"waystop", &"east", _with([]))
	assert_true(await _walk_through([Vector2(200, 150), Vector2(40, 144)]), "across the halt")
	assert_true(await _walk_until_travelling(Vector2.LEFT, 4.0), "west on foot")
	assert_true(await _wait_until(game.is_showing_interlude, 3.0), "a day and a half on the road")
	await _settle()
	_assert_at_entry(&"pedrabranca", &"east")
	assert_true(await _walk_until_travelling(Vector2.RIGHT, 4.0), "and back out of the gate")
	assert_true(await _wait_until(game.is_showing_interlude, 3.0))
	await _settle()
	_assert_at_entry(&"waystop", &"west")


func test_iara_in_town_asks_the_hero_up_to_the_quarry() -> void:
	await _continue_in(&"pedrabranca", &"east", _with([]))
	assert_true(_iara().is_at_the_stall())
	assert_true(_rufina().is_on_the_terrace())
	assert_true(await _walk_through(BY_IARA), "to Iara's stall on foot")
	assert_eq(await _talk_facing(&"move_right"), "IARA_TOWN_MEET")
	assert_true(game.adventure.has_flag(Town.IARA_MET))
	assert_eq(await _talk_facing(&"move_right"), "IARA_TOWN_WAIT")


func test_a_bump_from_the_carriers_costs_no_health_and_clears_the_lane() -> void:
	await _continue_in(&"pedrabranca", &"east", _with([Town.IARA_MET]))
	var carrier := _carriers()[2]
	var health := _player().health.current
	_player().global_position = carrier.global_position + Vector2(0, 2)
	await wait_physics_frames(4)
	assert_eq(_player().state, Player.State.HURT, "shoved")
	await wait_physics_frames(30)
	assert_eq(_player().health.current, health, "but not hurt")
	assert_gt(_player().global_position.y, carrier.global_position.y + 6.0, "and out of the lane, to the street side")


func test_up_the_yard_rufina_hears_who_lives_past_the_laje() -> void:
	await _continue_in(&"pedrabranca", &"east", _with([Town.IARA_MET]))
	var from := Vector2i(game.level.entry(&"east").global_position)
	assert_true(await _walk_through(TO_THE_YARD), "along the street to the yard")
	assert_true(_carriers()[0].heading() != 0.0, "the carriers are at work")
	await _cross_the_yard()
	assert_true(await _walk_through(ON_THE_TERRACE), "up the steps to the terrace")
	assert_eq(await _talk_facing(&"move_right"), "RUFINA_UP")
	assert_true(game.adventure.has_flag(Town.HEARD))
	assert_true(await _walk_through(OUT_OF_HER_WAY), "out of her way")
	assert_true(await _wait_until(_all_resting, 8.0), "she stops the loading")
	assert_true(await _wait_until(_rufina().is_in_the_yard, 20.0), "and comes down to the yard")
	assert_true(await _wait_until(_iara().is_in_the_yard, 20.0), "where Iara comes to meet her")
	assert_true(_can_reach(from, Vector2i(300, 20), Rect2i(0, 0, 480, 288)))


func test_rufina_faces_iara_and_the_notice_comes_down() -> void:
	await _continue_in(&"pedrabranca", &"east", _with([Town.IARA_MET, Town.HEARD]))
	var notice := game.level.get_node(^"Entities/Notice")
	assert_true((notice.get_node(^"Board") as CanvasItem).visible)
	assert_true(_all_resting(), "the loading stays stopped")
	assert_true(await _walk_through(TO_THE_YARD), "to the yard")
	assert_true(await _walk_through([Vector2(226, 178)]))
	assert_eq(await _talk_facing(&"move_down"), "RUFINA_YARD")
	assert_true(game.adventure.has_flag(Town.FACED))
	assert_true(_rufina().is_walking(), "she sets off at once")
	assert_true(await _wait_until(_rufina().is_at_the_gate, 20.0), "she goes to the gate")
	assert_true(game.adventure.has_flag(Town.NOTICE_DOWN), "and takes the notice down")
	assert_false((notice.get_node(^"Board") as CanvasItem).visible)
	assert_true((notice.get_node(^"Post") as CanvasItem).visible)
	assert_true(await _wait_until(_iara().is_at_the_stall, 20.0), "Iara goes back to her stall")
	assert_true(await _wait_until(func() -> bool: return _carriers()[0].heading() != 0.0, 2.0), "the loading goes on")
	assert_true(await _walk_through(BACK_TO_IARA), "to Iara on foot")
	assert_eq(await _talk_facing(&"move_right"), "IARA_TOWN_DEAL")
	assert_true(game.adventure.has_flag(Town.DEALT))
	assert_eq(await _talk_facing(&"move_right"), "IARA_TOWN_STAY")


func test_teodoro_and_the_marks_on_the_bridge() -> void:
	await _continue_in(&"pedrabranca", &"east", _with([Town.IARA_MET]))
	assert_true(await _walk_through([Vector2(410, 222), Vector2(300, 226), Vector2(300, 204)]), "to Teodoro")
	assert_eq(await _talk_facing(&"move_right"), "TEODORO_MARKS")
	assert_true(game.adventure.has_flag(Town.TEODORO_TOLD))
	assert_eq(await _talk_facing(&"move_right"), "TEODORO_BUSY")
	game.adventure.set_flag(Town.NOTICE_DOWN)
	assert_eq(await _talk_facing(&"move_right"), "TEODORO_EAST")


func test_what_stays_after_continuing_and_after_a_fall() -> void:
	await _continue_in(&"pedrabranca", &"east", _with([Town.IARA_MET, Town.HEARD, Town.FACED]))
	assert_true(game.adventure.has_flag(Town.NOTICE_DOWN), "left on her way, she has reached the gate")
	assert_true(_rufina().is_at_the_gate())
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	var notice := game.level.get_node(^"Entities/Notice")
	assert_false((notice.get_node(^"Board") as CanvasItem).visible, "the notice stays down")
	assert_true(_rufina().is_at_the_gate())
	assert_true(_iara().is_at_the_stall())
	assert_false(_all_resting(), "the loading goes on")
	await _fall_and_retry()
	game.travel(&"pedrabranca", &"east")
	await _settle()
	assert_false((game.level.get_node(^"Entities/Notice/Board") as CanvasItem).visible)
	assert_true(await _walk_through([Vector2(430, 222)]), "to the gate post")
	assert_eq(await _talk_facing(&"move_up"), "TOWN_NOTICE_DOWN")


func test_the_town_holds_its_edges() -> void:
	await _continue_in(&"pedrabranca", &"east", _with([]))
	var from := Vector2i(game.level.entry(&"east").global_position)
	var bounds := Rect2i(0, 0, 480, 288)
	for place: Vector2i in [Vector2i(374, 236), Vector2i(YARD_X, 190), Vector2i(24, 230), Vector2i(300, 204)]:
		assert_true(_can_reach(from, place, bounds), "%s can be reached" % place)
	for place: Vector2i in [Vector2i(60, 120), Vector2i(420, 120), Vector2i(60, 20)]:
		assert_false(_can_reach(from, place, bounds), "%s is closed" % place)


func test_saves_from_before_know_nothing_of_the_town() -> void:
	for file_name: String in ["v1_back_in_village.json", "v2_stall_worked.json"]:
		var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
		file.close()
		assert_true(game.continue_saved(), file_name)
		await _settle()
		for flag in [Town.IARA_MET, Town.HEARD, Town.FACED, Town.DEALT, Town.NOTICE_DOWN, Town.TEODORO_TOLD]:
			assert_false(game.adventure.has_flag(flag), "%s %s" % [file_name, flag])
		await _restart()


func test_texts_exist_in_both_languages() -> void:
	for key in ["NPC_RUFINA", "NPC_TEODORO", "IARA_TOWN_MEET", "IARA_TOWN_WAIT", "IARA_TOWN_YARD", "IARA_TOWN_DEAL",
			"IARA_TOWN_STAY", "RUFINA_BUSY", "RUFINA_UP", "RUFINA_WALKING", "RUFINA_YARD", "RUFINA_GATE",
			"TEODORO_MARKS", "TEODORO_BUSY", "TEODORO_EAST", "TOWN_NOTICE", "TOWN_NOTICE_DOWN", "TOWN_ROAD_WEST",
			"TOWN_ROAD_EAST"]:
		for locale in ["pt_BR", "en"]:
			var translation := TranslationServer.get_translation_object(locale)
			assert_ne(String(translation.get_message(key)), "", "%s in %s" % [key, locale])
