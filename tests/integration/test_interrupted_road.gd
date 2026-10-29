extends "res://tests/integration/adventure_case.gd"
## The road to Pedrabranca: Iara turning to the rockfall after the hero's first visit, her pry
## bar, the slope above the road where stones roll down the runoff from the choked ditch, the
## trunk levered loose and the branches that jam it wrenched out from inside a chute, with real
## input, the ditch running again, and what that changes on the far bank as time passes.

const FIXTURES := "res://tests/fixtures/saves"
const MET: Array[StringName] = [&"forest_shrine_awakened", &"far_bank_bridge_tied", &"far_bank_iara_met"]
const DAM_FRONT := Vector2(270, 98)
## Below the branches jammed against the trunk's upper end, on the last chute's course.
const BRANCHES_FRONT := Vector2(248, 96)
const TRAIL_UP: Array[Vector2] = [Vector2(92, 176), Vector2(112, 130), Vector2(160, 108), Vector2(220, 102),
		DAM_FRONT]
## The foot of the trail on the far bank, beside the runoff.
const TRAIL_FOOT := Vector2(90, 24)


func after_each() -> void:
	super.after_each()
	_steer(Vector2.ZERO)


func _with(extra: Array) -> Array[StringName]:
	var flags: Array[StringName] = MET.duplicate()
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


func _iara() -> IaraWorker:
	return game.level.get_node(^"Entities/Iara") as IaraWorker


func _dam() -> DitchDam:
	return game.level.get_node(^"Entities/DitchDam") as DitchDam


func _chutes() -> Array[RollingStones]:
	var chutes: Array[RollingStones] = []
	for node in game.level.get_node(^"Entities").get_children():
		if node is RollingStones:
			chutes.append(node)
	return chutes


## Waits for the chute to send a stone and for the stone to roll on past its top.
func _wait_for_a_stone_to_pass(chute: RollingStones) -> bool:
	var rolled := [false]
	var listen := func(_stone: Projectile) -> void: rolled[0] = true
	chute.rolled.connect(listen)
	var came := await _wait_until(func() -> bool: return rolled[0], chute.interval + chute.first_delay + 2.0)
	chute.rolled.disconnect(listen)
	await wait_physics_frames(30)
	return came


## How far a point is from the course the chute's stones roll down.
func _distance_to_course(chute: RollingStones, point: Vector2) -> float:
	var top := chute.global_position
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, top, top + chute.fall))


## From in front of the trunk, round to below the branches (stepping up last, to face them).
func _work_the_branches() -> String:
	assert_true(await _wait_for_a_stone_to_pass(_chutes()[2]), "a stone rolls down the last chute")
	assert_true(await _walk_through([Vector2(248, 104), BRANCHES_FRONT]), "into the chute, between stones")
	return await _press_interact()


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


func test_on_the_first_visit_nothing_of_the_road_has_begun() -> void:
	await _continue_in(&"far_bank", &"bridge", [&"forest_shrine_awakened", &"far_bank_bridge_tied"])
	assert_false(_iara().is_at_the_rockfall(), "she waits by the bridge")
	assert_eq(await _talk("Iara"), "IARA_MEET")
	assert_false(game.adventure.has_flag(RoadWork.STARTED), "the road waits for a later visit")
	assert_true((game.level.get_node(^"Decals/Runoff") as CanvasItem).visible, "water already runs onto the road")


func test_after_the_hero_leaves_iara_turns_to_the_rockfall_and_lends_her_bar() -> void:
	await _continue_in(&"far_bank", &"bridge", MET)
	assert_false(_iara().is_at_the_rockfall(), "at her press on the visit she was met")
	_player().global_position = TRAIL_FOOT
	await wait_physics_frames(3)
	assert_true(await _walk_until_travelling(Vector2.UP, 3.0), "up the trail")
	await _settle()
	assert_true(await _walk_until_travelling(Vector2.DOWN, 3.0), "and straight back down")
	await _settle()
	assert_false(game.adventure.has_flag(RoadWork.STARTED), "the slope above the camp is not being away")
	assert_false(_iara().is_at_the_rockfall())
	_player().global_position = game.level.entry(&"bridge").global_position
	await wait_physics_frames(3)
	assert_true(await _walk_until_travelling(Vector2.RIGHT, 4.0), "off over the bridge")
	await _settle()
	assert_true(game.adventure.has_flag(RoadWork.STARTED), "time passes while the hero is away")
	await _take_exit("ToFarBank")
	_assert_at_entry(&"far_bank", &"bridge")
	assert_true(_iara().is_at_the_rockfall(), "she is at the rockfall now")
	assert_true((_iara().get_node(^"PryBar") as CanvasItem).visible, "her bar beside her")
	assert_eq(await _talk("Iara"), "IARA_ROAD_BAR")
	assert_true(game.adventure.has_flag(RoadWork.BAR_LENT))
	assert_false((_iara().get_node(^"PryBar") as CanvasItem).visible, "lent to the hero")
	assert_eq(await _talk("Iara"), "IARA_ROAD_WAITING")
	assert_eq(await _talk("Iara"), "IARA_ROAD_WAITING")


func test_the_trail_leads_up_the_slope_and_back_on_foot() -> void:
	await _continue_in(&"far_bank", &"bridge", _with([RoadWork.STARTED]))
	assert_true(_can_reach(Vector2i(game.level.entry(&"bridge").global_position), Vector2i(TRAIL_FOOT),
			Rect2i(0, 0, 416, 288)), "the trail's foot can be reached from the bridge on foot")
	for trip in 3:
		_player().global_position = TRAIL_FOOT
		await wait_physics_frames(3)
		assert_true(await _walk_until_travelling(Vector2.UP, 3.0), "up the trail, trip %d" % trip)
		await _settle()
		_assert_at_entry(&"road_slope", &"trail")
		assert_almost_eq(_player().global_position.x, TRAIL_FOOT.x, 2.0, "the trail meets itself at the edge")
		assert_true(await _walk_until_travelling(Vector2.DOWN, 3.0), "and down again, trip %d" % trip)
		await _settle()
		_assert_at_entry(&"far_bank", &"slope")


func test_the_slope_can_be_walked_and_its_edges_hold() -> void:
	await _continue_in(&"road_slope", &"trail", _with([RoadWork.STARTED]))
	var from := Vector2i(game.level.entry(&"trail").global_position)
	var bounds := Rect2i(0, 0, 416, 224)
	var places := {"the trunk in the ditch": Vector2i(DAM_FRONT), "the spring": Vector2i(40, 100),
			"the shelter": Vector2i(330, 190), "the tally board": Vector2i(286, 164)}
	for place: String in places:
		assert_true(_can_reach(from, places[place], bounds), "%s can be reached" % place)
		assert_true(_can_reach(places[place], from, bounds), "%s can be left" % place)
	assert_false(_can_reach(from, Vector2i(200, 72), bounds), "nobody walks in the ditch")
	assert_false(_can_reach(from, Vector2i(200, 40), bounds), "nor past it into the pines")
	assert_false(_can_reach(from, Vector2i(396, 140), bounds), "nor into the gorge")
	for tool: String in ["Shovel", "Pickaxe"]:
		var foot: Vector2 = game.level.get_node(NodePath("Entities/" + tool)).global_position
		assert_false(_can_reach(from, Vector2i(foot) + Vector2i(0, -2), bounds), "the %s stands solid" % tool)


func test_stones_roll_down_the_runoff_after_a_warning_and_hurt() -> void:
	await _continue_in(&"road_slope", &"trail", _with([RoadWork.STARTED]))
	var chute: RollingStones = _chutes()[1]
	assert_true(chute.is_active())
	var stones := []
	chute.rolled.connect(func(stone: Projectile) -> void: stones.append(stone))
	# Standing on the chute's course, a little below its top.
	_player().global_position = chute.global_position + (chute.fall.normalized() * 50.0)
	await wait_physics_frames(3)
	var health := _player().health.current
	assert_true(await _wait_until(func() -> bool: return not stones.is_empty(), 4.0), "a stone breaks loose")
	assert_true(await _wait_until(func() -> bool: return _player().health.current < health, 3.0),
			"and hits whoever stands in its way")
	await wait_physics_frames(200)
	assert_false(is_instance_valid(stones[0]), "it ends in dust at the bottom")


func test_without_the_bar_the_trunk_does_not_move() -> void:
	await _continue_in(&"road_slope", &"trail", _with([RoadWork.STARTED]))
	_player().global_position = DAM_FRONT
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "ROAD_DAM")
	_player().global_position = BRANCHES_FRONT
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "ROAD_DAM", "nor do the branches")
	assert_false(_dam().is_cleared())
	assert_false((game.level.get_node(^"Ditch") as Ditch).is_running_at(20), "dry below the trunk")
	game.adventure.set_flag(RoadWork.BAR_LENT)
	assert_eq(await _press_interact(), "ROAD_DEBRIS_PINNED", "the trunk's weight holds the branches")
	assert_false(_dam().is_loosened())


func test_the_hero_climbs_to_the_trunk_with_real_input_and_frees_the_ditch() -> void:
	await _continue_in(&"road_slope", &"trail", _with([RoadWork.STARTED, RoadWork.BAR_LENT]))
	var ditch: Ditch = game.level.get_node(^"Ditch")
	assert_true(await _walk_through(TRAIL_UP), "up the trail and along the ditch, across the chutes")
	assert_false(_player().health.is_dead(), "the stones hurt but do not stop a careful climb")
	assert_eq(await _press_interact(), "ROAD_DAM_LOOSENED")
	assert_true(_dam().is_loosened())
	assert_false(ditch.is_running_at(20), "the trunk has only rolled a hand's width")
	assert_eq(await _press_interact(), "ROAD_DAM_JAMMED")
	assert_lt(_distance_to_course(_chutes()[2], BRANCHES_FRONT), 6.0, "the branches are worked from the chute")
	assert_eq(await _work_the_branches(), "ROAD_DAM_CLEARED")
	assert_true(game.adventure.has_flag(RoadWork.DITCH_CLEARED))
	assert_true(ditch.is_running_at(20), "the water runs past the trunk")
	assert_true(ditch.is_running_at(22), "all the way to the gorge")
	for chute in _chutes():
		assert_false(chute.is_active(), "%s is quiet" % chute.name)
	assert_false((game.level.get_node(^"Decals/Runoff") as CanvasItem).visible, "no more runoff")
	assert_true((game.level.get_node(^"Decals/Waterfall") as CanvasItem).visible, "it pours into the gorge")
	assert_false((_dam().get_node(^"Branches") as Interactable).enabled, "the branches went with the water")
	_player().global_position = DAM_FRONT
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "ROAD_DAM_AFTER")


func test_a_stone_hurts_whoever_waits_at_the_branches() -> void:
	await _continue_in(&"road_slope", &"trail", _with([RoadWork.STARTED, RoadWork.BAR_LENT, RoadWork.LOOSENED]))
	_player().global_position = BRANCHES_FRONT
	var before := _player().health.current
	assert_true(await _wait_until(func() -> bool: return _player().health.current < before, 6.0),
			"standing in the chute's course, the next stone hits")


func test_the_loosened_trunk_and_the_freed_ditch_stay_after_continuing() -> void:
	await _continue_in(&"road_slope", &"trail", _with([RoadWork.STARTED, RoadWork.BAR_LENT]))
	_player().global_position = DAM_FRONT
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "ROAD_DAM_LOOSENED")
	var shifted := (_dam().get_node(^"Log") as Node2D).position
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_true(_dam().is_loosened(), "the trunk stays where it rolled")
	assert_eq((_dam().get_node(^"Log") as Node2D).position, shifted)
	_player().global_position = DAM_FRONT
	await wait_physics_frames(3)
	assert_eq(await _press_interact(), "ROAD_DAM_JAMMED")
	assert_eq(await _work_the_branches(), "ROAD_DAM_CLEARED")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	_assert_at_entry(&"road_slope", &"trail")
	assert_true(_dam().is_cleared())
	for chute in _chutes():
		assert_false(chute.is_active())
	await wait_physics_frames(240)
	for node in game.level.get_node(^"Entities").get_children():
		assert_false(node is Projectile, "no stone rolls any more")


func test_falling_on_the_slope_and_coming_back() -> void:
	await _continue_in(&"road_slope", &"trail", _with([RoadWork.STARTED, RoadWork.BAR_LENT]))
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")
	game.travel(&"road_slope", &"trail")
	await _settle()
	assert_false(_dam().is_cleared(), "the trunk waits")
	assert_true(_chutes()[0].is_active())


func test_iara_hears_of_the_ditch_and_the_road_moves_on_while_the_hero_is_away() -> void:
	await _continue_in(&"far_bank", &"slope", _with([RoadWork.STARTED, RoadWork.BAR_LENT, RoadWork.DITCH_CLEARED]))
	assert_true(_iara().is_at_the_rockfall())
	assert_false((game.level.get_node(^"Decals/Runoff") as CanvasItem).visible, "the road is dry")
	assert_eq(await _talk("Iara"), "IARA_ROAD_CLEARED")
	assert_true(game.adventure.has_flag(RoadWork.HEARD))
	assert_true((_iara().get_node(^"PryBar") as CanvasItem).visible, "she has her bar back")
	assert_eq(await _talk("Iara"), "IARA_ROAD_CLEARING")
	assert_not_null(game.level.get_node_or_null(^"Entities/RockfallLoose"), "nothing moved in front of the hero")
	await _take_exit("ToSlope")
	assert_false(game.adventure.has_flag(RoadWork.PROGRESSED), "a look at the ditch is not being away")
	game.travel(&"far_bank", &"slope")
	await _settle()
	await _take_exit("ToWest")
	assert_true(game.adventure.has_flag(RoadWork.PROGRESSED), "she worked while the hero was away")
	game.travel(&"far_bank", &"slope")
	await _settle()
	assert_null(game.level.get_node_or_null(^"Entities/RockfallLoose"), "the smaller stones are gone from the road")
	assert_not_null(game.level.get_node_or_null(^"Entities/RockfallStacked"), "stacked by its side")
	assert_eq(await _talk("Iara"), "IARA_ROAD_PROGRESS")
	var rockfall: Node2D = game.level.get_node(^"Entities/Rockfall")
	var said: String = (rockfall.get_node(^"Interactable") as Interactable).action.call(_player())
	assert_eq(said, "FAR_ROCKFALL_CLEARING")
	assert_true(_can_reach(Vector2i(game.level.entry(&"slope").global_position), Vector2i(104, 222),
			Rect2i(0, 0, 416, 288)), "the stacked stones leave the road and Iara reachable")
	assert_false(_can_reach(Vector2i(game.level.entry(&"slope").global_position), Vector2i(8, 206),
			Rect2i(0, 0, 416, 288)), "the biggest stone still closes the road")


func test_saves_from_before_find_the_road_as_it_was() -> void:
	for file_name: String in ["v1_back_in_village.json", "v2_stall_worked.json"]:
		var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
		file.close()
		assert_true(game.continue_saved(), file_name)
		await _settle()
		game.travel(&"road_slope", &"trail")
		await _settle()
		assert_false(_dam().is_cleared(), file_name)
		_player().global_position = DAM_FRONT
		await wait_physics_frames(3)
		assert_eq(await _press_interact(), "ROAD_DAM", "no bar, %s" % file_name)
		for flag in [RoadWork.STARTED, RoadWork.BAR_LENT, RoadWork.LOOSENED, RoadWork.DITCH_CLEARED]:
			assert_false(game.adventure.has_flag(flag), "%s %s" % [file_name, flag])
		await _restart()


func test_texts_exist_in_both_languages() -> void:
	for key in ["IARA_ROAD_BAR", "IARA_ROAD_WAITING", "IARA_ROAD_CLEARED", "IARA_ROAD_CLEARING",
			"IARA_ROAD_PROGRESS", "FAR_ROCKFALL_CLEARING", "ROAD_DAM", "ROAD_DAM_LOOSENED", "ROAD_DAM_JAMMED",
			"ROAD_DEBRIS_PINNED", "ROAD_DAM_CLEARED", "ROAD_DAM_AFTER",
			"ROAD_SPRING", "ROAD_SHELTER", "ROAD_TALLY"]:
		for locale in ["pt_BR", "en"]:
			var translation := TranslationServer.get_translation_object(locale)
			assert_ne(String(translation.get_message(key)), "", "%s in %s" % [key, locale])
