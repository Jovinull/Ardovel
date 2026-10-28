extends "res://tests/integration/adventure_case.gd"
## Cida's hens and Anselmo's old coop: a night under the village light, three neighbours who
## disagree, Anselmo's repair, Cida's grain and the hero driving the hens in with real input.

const FIXTURES := "res://tests/fixtures/saves"
const NIGHT: Array[StringName] = [&"forest_shrine_awakened", &"heard_of_shrine", &"elder_thanked",
		&"ruin_warden_defeated", &"ruin_heart_awakened", &"village_beacon_night"]
const CIDA_HOME := Vector2(382, 306)
const LIA_HOME := Vector2(276, 202)
const ANSELMO_HOME := Vector2(150, 190)
## In the narrow way behind Anselmo's house, east of the gate.
const BEHIND_HOUSE := Vector2(150, 118)
## Just outside the yard's gate, and the yard itself (a little wider than its fence).
const GATE_MOUTH := Vector2(88, 114)
const YARD_AREA := Rect2(46, 52, 70, 50)
const REPAIRED: Array[StringName] = [&"village_coop_offered", &"village_coop_repaired"]


func _load_village(flags: Array[StringName]) -> void:
	var state := Adventure.new(&"village", &"north")
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


func _with(extra: Array[StringName]) -> Array[StringName]:
	var flags := NIGHT.duplicate()
	flags.append_array(extra)
	return flags


func _yard() -> HenYard:
	return game.level.get_node(^"Entities/HenYard") as HenYard


func _cida() -> CidaWorker:
	return game.level.get_node(^"Entities/Cida") as CidaWorker


func _anselmo() -> AnselmoHelper:
	return game.level.get_node(^"Entities/Anselmo") as AnselmoHelper


func _pen() -> HenPen:
	return game.level.get_node(^"Entities/HenPen") as HenPen


## All three hens peck about inside Cida's own pen, its gate shut.
func _assert_hens_at_home(context: String) -> void:
	assert_eq(_hens().size(), 3, context)
	assert_false(_pen().is_open(), context)
	for hen in _hens():
		assert_true(hen.penned, "%s: %s" % [context, hen.name])
		assert_true(_pen().inside().grow(1.0).has_point(hen.global_position),
				"%s: %s at home" % [context, hen.name])


## Saves, closes and reopens the game, continuing where it was left.
func _reload() -> void:
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()


func _penned_count() -> int:
	return _hens().filter(func(hen: Hen) -> bool: return hen.penned).size()


## Where a hen at `at` should be driven next: round the east side of Anselmo's house, along the
## way behind it and to the mouth of the gate.
func _herding_goal(at: Vector2) -> Vector2:
	if at.y < 134.0 and at.x < 170.0:
		return GATE_MOUTH
	if at.x >= 158.0:
		return Vector2(166, 118)
	return Vector2(178, 196)


## Holds the move actions closest to `direction`, like a stick or keys would.
func _steer(direction: Vector2) -> void:
	var keys := {&"move_left": direction.x < -0.3, &"move_right": direction.x > 0.3,
			&"move_up": direction.y < -0.3, &"move_down": direction.y > 0.3}
	for action: StringName in keys:
		if keys[action]:
			Input.action_press(action)
		else:
			Input.action_release(action)


## Drives every loose hen into the yard with the hero's move actions only (no hen is moved by
## the test): get behind the nearest hen, go round it when in front, step aside when stuck,
## leave the yard by its gate. True if all three are in within `seconds`.
func _drive_hens_in(seconds: float) -> bool:
	var frames := 0
	var last_check := _player().global_position
	var dodge := 0
	var dodge_side := 1.0
	while frames < int(seconds * 60.0) and _penned_count() < 3:
		var hero := _player().global_position
		var loose := _hens().filter(func(hen: Hen) -> bool: return not hen.penned)
		loose.sort_custom(func(a: Hen, b: Hen) -> bool:
				return a.global_position.distance_to(hero) < b.global_position.distance_to(hero))
		var at: Vector2 = (loose[0] as Hen).global_position
		var push := (_herding_goal(at) - at).normalized()
		var behind := at - push * 20.0
		var side := Vector2(-push.y, push.x)
		if (hero - at).dot(side) < 0.0:
			side = -side
		var direction := push
		if (hero - at).dot(push) > -6.0 and hero.distance_to(at) < 48.0:
			direction = (side - push * 0.6).normalized()
		elif hero.distance_to(behind) > 3.0:
			direction = (behind - hero).normalized()
		if YARD_AREA.has_point(hero) and not YARD_AREA.has_point(at):
			direction = ((Vector2(88, 122) if hero.y > 96.0 else Vector2(88, 100)) - hero).normalized()
		if dodge > 0:
			dodge -= 1
			direction = Vector2(-direction.y, direction.x) * dodge_side
		_steer(direction)
		await wait_physics_frames(1)
		frames += 1
		if frames % 30 == 0:
			if hero.distance_to(last_check) < 2.0:
				dodge = 20
				dodge_side = -dodge_side
			last_check = hero
	_steer(Vector2.ZERO)
	await wait_physics_frames(2)
	gut.p("drove %d of 3 hens in, %.1f s of play" % [_penned_count(), frames / 60.0])
	return _penned_count() == 3


func _line(npc_name: String) -> String:
	return (game.level.get_node("Entities/" + npc_name) as Npc).current_line().text


func _hens() -> Array[Hen]:
	var found: Array[Hen] = []
	for child in _yard().get_children():
		if child is Hen and not child.is_queued_for_deletion():
			found.append(child)
	return found


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while left > 0.0:
		if condition.call():
			return true
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


## Walks the hero with a real held input for `frames` physics frames.
func _walk(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await wait_physics_frames(frames)
	Input.action_release(action)
	await wait_physics_frames(2)


## Flood fill with a hen-sized body over the level's collisions (the hero is ignored).
func _hen_can_reach(from: Vector2i, to: Vector2i) -> bool:
	var hen := _hens()[0]
	var body: CollisionShape2D = hen.get_node(^"Collision")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.collision_mask = 1
	query.exclude = [hen.get_rid()]
	var space := hen.get_world_2d().direct_space_state
	var bounds := Rect2i(8, 8, 464, 368)
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


func test_nothing_happens_until_a_night_has_passed_under_the_light() -> void:
	await _load_village([&"forest_shrine_awakened", &"heard_of_shrine", &"elder_thanked",
			&"ruin_warden_defeated", &"ruin_heart_awakened"])
	_assert_hens_at_home("the hens are still in Cida's pen on the first evening")
	assert_eq(_cida().position, CIDA_HOME)
	assert_eq(_line("Cida"), "CIDA_RUIN", "the first reactions to the light stay as they were")
	assert_eq(_line("Anselmo"), "ANSELMO_RUIN")
	assert_true(_yard().is_gate_closed())
	# The hero walks out through the arch: the night passes while they are away, and the
	# screen says so on the black between the two areas.
	var night_told := [false]
	var watch := func() -> void: night_told[0] = night_told[0] or game.is_showing_interlude()
	get_tree().physics_frame.connect(watch)
	await _take_exit("ToForest")
	get_tree().physics_frame.disconnect(watch)
	assert_true(night_told[0], "the night is told on the black")
	assert_eq(game.level.area_id, &"forest")
	assert_true(game.adventure.has_flag(&"village_beacon_night"), "leaving lets a night pass")
	await _take_exit("ToVillage")
	assert_false(game.is_showing_interlude(), "and only on that trip")
	assert_eq(game.level.area_id, &"village")
	assert_eq(_hens().size(), 3)
	for hen in _hens():
		assert_false(hen.penned, "%s is loose" % hen.name)
	assert_true(_pen().is_open(), "Cida's pen is left open")
	assert_eq(_cida().position, CidaWorker.SQUARE_SPOT, "Cida is out after them")
	assert_eq(_line("Cida"), "CIDA_HENS_LOOSE")
	assert_eq(_line("Lia"), "LIA_HENS_LIGHT")
	assert_eq(_line("Anselmo"), "ANSELMO_HENS_OFFER")


func test_no_night_passes_before_the_heart_wakes() -> void:
	await _load_village([&"forest_shrine_awakened", &"heard_of_shrine"])
	await _take_exit("ToForest")
	await _take_exit("ToVillage")
	assert_false(game.adventure.has_flag(&"village_beacon_night"))
	_assert_hens_at_home("before the heart")
	await wait_physics_frames(120)
	_assert_hens_at_home("they stay in their pen")
	assert_eq(_line("Cida"), "CIDA_AWAKENED")


func test_only_walking_out_of_the_village_lets_the_night_pass() -> void:
	var first_evening: Array[StringName] = [&"forest_shrine_awakened", &"heard_of_shrine",
			&"elder_thanked", &"ruin_warden_defeated", &"ruin_heart_awakened"]
	await _load_village(first_evening)
	# Loading the save again.
	assert_true(game.continue_saved())
	await _settle()
	assert_false(game.adventure.has_flag(&"village_beacon_night"), "loading is not a night")
	# Back to the title and continuing (saves on the way out).
	game.call(&"_return_to_title")
	await wait_physics_frames(3)
	assert_null(game.level)
	assert_true(game.continue_saved())
	await _settle()
	assert_false(game.adventure.has_flag(&"village_beacon_night"), "the title is not a night")
	# Closing the game and opening it again.
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_false(game.adventure.has_flag(&"village_beacon_night"), "quitting is not a night")
	# Falling in the village: the hero wakes at the ruin's heart.
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")
	assert_false(game.adventure.has_flag(&"village_beacon_night"), "a fall is not a night")
	# Coming back by the forest path still finds the first evening.
	game.travel(&"forest", &"south")
	await _settle()
	await _take_exit("ToVillage")
	_assert_hens_at_home("still the first evening")
	assert_eq(_line("Cida"), "CIDA_RUIN")


func test_the_old_gate_keeps_the_hens_out_until_anselmo_frees_it() -> void:
	await _load_village(_with([]))
	var gate_front := Vector2i(88, 114)
	var inside := Vector2i(88, 86)
	for spot in HenYard.LOOSE_SPOTS:
		assert_true(_hen_can_reach(Vector2i(spot), gate_front), "no hen is cornered at %s" % spot)
	assert_false(_hen_can_reach(gate_front, inside), "the old gate is nailed shut")
	_yard().open_gate()
	await wait_physics_frames(3)
	assert_true(_hen_can_reach(gate_front, inside))


func test_anselmo_mends_the_coop_and_cida_comes_with_grain() -> void:
	await _load_village(_with([]))
	assert_eq(await _talk("Anselmo"), "ANSELMO_HENS_OFFER")
	assert_true(game.adventure.has_flag(&"village_coop_offered"))
	assert_eq(_line("Anselmo"), "ANSELMO_COOP_WORK")
	assert_eq(_line("Cida"), "CIDA_HENS_WAIT")
	# Out of everyone's way while they work.
	_player().global_position = Vector2(220, 300)
	assert_true(await _wait_until(func() -> bool: return _anselmo().position != ANSELMO_HOME, 2.0),
			"Anselmo sets off")
	assert_true(await _wait_until(func() -> bool: return not _yard().is_gate_closed(), 15.0),
			"he frees the gate")
	assert_true(await _wait_until(
			func() -> bool: return game.adventure.has_flag(&"village_coop_repaired"), 15.0),
			"he mends the roof")
	assert_eq((_yard().get_node(^"Coop/Sprite") as Sprite2D).frame, 1)
	assert_true(await _wait_until(func() -> bool: return not _anselmo().is_working(), 15.0),
			"he walks back home")
	assert_eq(_anselmo().position, ANSELMO_HOME)
	assert_true(await _wait_until(
			func() -> bool: return _cida().position == CidaWorker.COOP_ROUTE.back(), 15.0),
			"Cida walks to the gate after him")
	assert_true((_yard().get_node(^"Grain") as Sprite2D).visible, "and scatters grain")
	assert_eq(_line("Cida"), "CIDA_HENS_CALL")
	assert_eq(_line("Lia"), "LIA_HENS_YARD")
	assert_eq(_line("Anselmo"), "ANSELMO_COOP_READY")


func test_the_hero_drives_each_hen_in_with_real_input() -> void:
	await _load_village(_with([&"village_coop_offered", &"village_coop_repaired"]))
	assert_eq(_cida().position, CidaWorker.COOP_ROUTE.back(), "Cida waits at the gate")
	for hen in _hens():
		assert_false(game.adventure.has_flag(&"village_hens_settled"))
		# Bring the hen to the narrow way behind the house, then walk up behind it.
		hen.global_position = BEHIND_HOUSE
		hen.reset_physics_interpolation()
		_player().global_position = BEHIND_HOUSE + Vector2(30, 0)
		_player().reset_physics_interpolation()
		await wait_physics_frames(3)
		await _walk(&"move_left", 24)
		assert_true(await _wait_until(func() -> bool: return hen.penned, 4.0),
				"%s went in, at %s" % [hen.name, hen.global_position])
	assert_true(game.adventure.has_flag(&"village_hens_settled"))
	assert_true(await _wait_until(func() -> bool: return _yard().is_gate_closed(), 2.0),
			"the gate shuts behind them")
	# Penned hens stay put even when the hero comes close.
	_player().global_position = Vector2(88, 116)
	await wait_physics_frames(90)
	for hen in _hens():
		assert_true(_yard().get_node(^"Inside").overlaps_body(hen), "%s stays in" % hen.name)
	assert_eq(_line("Cida"), "CIDA_HENS_AFTER")


func test_a_hen_nobody_chases_goes_to_the_grain_by_itself() -> void:
	await _load_village(_with([&"village_coop_offered", &"village_coop_repaired"]))
	var hen := _hens()[0]
	hen.global_position = Vector2(100, 116)
	hen.reset_physics_interpolation()
	_player().global_position = Vector2(220, 300)
	assert_true(await _wait_until(func() -> bool: return hen.penned, 4.0))


func test_the_settled_yard_is_found_again_after_continue_travel_and_a_fall() -> void:
	await _load_village(_with([&"village_coop_offered", &"village_coop_repaired"]))
	for hen in _hens():
		hen.global_position = Vector2(88, 88)
		hen.reset_physics_interpolation()
	assert_true(await _wait_until(
			func() -> bool: return game.adventure.has_flag(&"village_hens_settled"), 2.0))
	var basket := game.level.get_node(^"Entities/EggBasket") as EggBasket
	assert_false(basket.visible, "the eggs never appear in front of the hero")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_true((game.level.get_node(^"Entities/EggBasket") as EggBasket).visible)
	assert_eq(_cida().position, CIDA_HOME, "Cida is back at her stall another day")
	assert_eq(_line("Cida"), "CIDA_HENS_AFTER")
	assert_eq(await _talk("Cida"), "CIDA_HENS_AFTER")
	assert_eq(_line("Cida"), "CIDA_RUIN", "said once, then her other lines again")
	assert_eq(await _talk("Anselmo"), "ANSELMO_HENS_AFTER")
	assert_eq(await _talk("Lia"), "LIA_HENS_AFTER")
	assert_eq(_line("Lia"), "LIA_RUIN")
	assert_eq(_hens().size(), 3)
	for hen in _hens():
		assert_true(hen.penned)
	assert_true(_yard().is_gate_closed())
	game.travel(&"forest", &"south")
	await _settle()
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(_hens().size(), 3)
	for hen in _hens():
		assert_true(hen.penned)
	assert_eq(_line("Anselmo"), "ANSELMO_RUIN")


func test_the_path_can_still_open_after_the_hens_are_settled() -> void:
	await _load_village(_with([&"village_coop_offered", &"village_coop_repaired",
			&"village_hens_settled", &"cida_eggs_promised", &"forest_echo_thicket_cut"]))
	assert_eq(_cida().position, CIDA_HOME)
	assert_eq(await _talk("Cida"), "CIDA_PATH_OPEN")
	_player().global_position = Vector2(340, 310)
	assert_true(await _wait_until(
			func() -> bool: return game.adventure.has_flag(&"cida_stall_worked"), 4.0))


func test_an_open_path_and_working_stall_wait_while_the_hens_are_loose() -> void:
	await _load_village(_with([&"forest_echo_thicket_cut", &"cida_path_acknowledged",
			&"cida_stall_worked", &"forest_echo_found"]))
	assert_eq(_cida().position, CidaWorker.SQUARE_SPOT, "the hens come first tonight")
	assert_eq(_line("Cida"), "CIDA_HENS_LOOSE")
	assert_eq(_line("Lia"), "LIA_HENS_LIGHT")
	assert_eq((game.level.get_node(^"Entities/Lia") as LiaObserver).position,
			LiaObserver.ARCH_POSITION, "Lia keeps her place at the arch")
	await wait_physics_frames(60)
	assert_eq(_cida().position, CidaWorker.SQUARE_SPOT, "she does not wander off to the stall")


func test_saves_from_before_this_event_load_unchanged() -> void:
	for file_name: String in ["v2_ruin_complete.json", "v2_stall_worked.json"]:
		var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
		file.close()
		assert_true(game.continue_saved())
		await _settle()
		_assert_hens_at_home(file_name)
		assert_false(game.adventure.has_flag(&"village_beacon_night"), file_name)
		assert_true(_yard().is_gate_closed(), file_name)
		await _restart()


func test_with_firewood_at_the_stall_anselmo_mends_the_roof_with_it() -> void:
	await _load_village(_with([&"forest_echo_thicket_cut", &"cida_path_acknowledged",
			&"cida_stall_worked"]))
	assert_eq((game.level.get_node(^"Entities/WoodStack") as WoodStack).frame, 0)
	assert_eq(await _talk("Anselmo"), "ANSELMO_HENS_OFFER_WOOD")
	var pile := game.level.get_node(^"Entities/WoodStack") as WoodStack
	assert_false(game.adventure.has_flag(&"village_coop_wood_from_cida"), "not before he has it")
	assert_eq(_line("Cida"), "CIDA_HENS_WAIT")
	_player().global_position = Vector2(220, 340)
	assert_true(await _wait_until(func() -> bool: return _anselmo().is_carrying_wood(), 20.0),
			"he walks to the stall and lifts two logs")
	assert_true(game.adventure.has_flag(&"village_coop_wood_from_cida"))
	assert_eq(pile.frame, 1, "the pile shrinks as he lifts them")
	assert_eq(_line("Cida"), "CIDA_HENS_WAIT_WOOD")
	assert_true(await _wait_until(func() -> bool: return not _yard().is_gate_closed(), 25.0),
			"he carries them to the coop and frees the gate")
	assert_false(_anselmo().is_carrying_wood(), "the logs are set down by the gate")
	assert_true(await _wait_until(
			func() -> bool: return game.adventure.has_flag(&"village_coop_repaired"), 15.0),
			"he mends the roof with them")
	game.adventure.set_flag(&"village_hens_settled")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq((game.level.get_node(^"Entities/WoodStack") as WoodStack).frame, 1,
			"part of the pile went into the roof")
	assert_eq(await _talk("Anselmo"), "ANSELMO_HENS_AFTER_WOOD", "he thanks Cida and the hero")
	assert_eq(_line("Anselmo"), "ANSELMO_RUIN", "then back to the light, as before the hens")


func test_without_firewood_he_uses_his_own_old_boards() -> void:
	await _load_village(_with([]))
	assert_eq(await _talk("Anselmo"), "ANSELMO_HENS_OFFER")
	assert_false(game.adventure.has_flag(&"village_coop_wood_from_cida"))
	assert_eq(_line("Cida"), "CIDA_HENS_WAIT")
	# The path opens only later: the pile stays whole.
	for flag: StringName in [&"village_coop_repaired", &"village_hens_settled",
			&"forest_echo_thicket_cut", &"cida_path_acknowledged"]:
		game.adventure.set_flag(flag)
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq((game.level.get_node(^"Entities/WoodStack") as WoodStack).frame, 0)
	assert_eq(await _talk("Anselmo"), "ANSELMO_HENS_AFTER")


func _drive_from(start: Vector2) -> void:
	await _load_village(_with(REPAIRED))
	_player().global_position = start
	_player().reset_physics_interpolation()
	await wait_physics_frames(2)
	for hen in _hens():
		assert_false(hen.penned, "%s starts loose in the square" % hen.name)
	assert_true(await _drive_hens_in(150.0), "all three hens driven in from %s" % start)
	assert_true(game.adventure.has_flag(&"village_hens_settled"))
	_steer((Vector2(140, 160) - _player().global_position).normalized())
	await wait_physics_frames(60)
	_steer(Vector2.ZERO)
	assert_true(await _wait_until(func() -> bool: return _yard().is_gate_closed(), 4.0),
			"the gate shuts once the hero is out of the yard")
	assert_false(YARD_AREA.has_point(_player().global_position), "the hero is never shut in")
	for hen in _hens():
		assert_true(_yard().get_node(^"Inside").overlaps_body(hen), "%s stays in" % hen.name)


func test_the_whole_drive_from_the_square_coming_from_the_north() -> void:
	await _drive_from(Vector2(240, 70))


func test_the_whole_drive_from_the_square_coming_from_the_south() -> void:
	await _drive_from(Vector2(128, 312))


func test_leaving_before_anselmo_frees_the_gate_starts_his_work_again() -> void:
	await _load_village(_with([]))
	assert_eq(await _talk("Anselmo"), "ANSELMO_HENS_OFFER")
	_player().global_position = Vector2(220, 300)
	assert_true(await _wait_until(func() -> bool: return _anselmo().position != ANSELMO_HOME, 2.0))
	await _reload()
	assert_eq(_anselmo().position.distance_to(ANSELMO_HOME) < 8.0, true, "he sets off from home again")
	assert_true(_anselmo().is_working())
	assert_true(_yard().is_gate_closed(), "the old gate is shut until he frees it")
	assert_eq(_hens().size(), 3)
	for hen in _hens():
		assert_false(hen.penned)
	assert_eq(_cida().position, CidaWorker.SQUARE_SPOT)


func test_leaving_during_the_repair_resumes_it_without_losing_the_offer() -> void:
	await _load_village(_with([]))
	await _talk("Anselmo")
	_player().global_position = Vector2(220, 300)
	assert_true(await _wait_until(func() -> bool: return not _yard().is_gate_closed(), 15.0))
	assert_false(game.adventure.has_flag(&"village_coop_repaired"))
	await _reload()
	assert_true(game.adventure.has_flag(&"village_coop_offered"), "the offer is kept")
	assert_true(_yard().is_gate_closed(), "the unfinished work starts over from the gate")
	_player().global_position = Vector2(220, 300)
	assert_true(await _wait_until(
			func() -> bool: return game.adventure.has_flag(&"village_coop_repaired"), 25.0),
			"and is finished")
	assert_true(await _wait_until(func() -> bool: return not _anselmo().is_working(), 15.0))
	assert_eq(_anselmo().position, ANSELMO_HOME)


func test_leaving_after_the_repair_finds_cida_waiting_at_the_gate() -> void:
	await _load_village(_with([]))
	await _talk("Anselmo")
	_player().global_position = Vector2(220, 300)
	assert_true(await _wait_until(
			func() -> bool: return game.adventure.has_flag(&"village_coop_repaired"), 25.0))
	await _reload()
	assert_eq(_cida().position, CidaWorker.COOP_ROUTE.back())
	assert_true((_yard().get_node(^"Grain") as Sprite2D).visible)
	assert_false(_yard().is_gate_closed())
	assert_eq(_anselmo().position, ANSELMO_HOME)
	assert_false(_anselmo().is_working(), "no second repair")


## The hen with this scene name (HenWhite, HenBrown, HenBlack).
func _hen(hen_name: String) -> Hen:
	return _yard().get_node(hen_name) as Hen


## Whether `hen` is penned inside the coop's fence (not merely standing somewhere).
func _in_coop(hen: Hen) -> bool:
	return hen.penned and _yard().get_node(^"Inside").overlaps_body(hen)


## Drives one hen in with the hero's input from just behind the house (not a full drive: the
## whole drive from the square is covered by the tests above).
func _push_in(hen: Hen) -> void:
	hen.global_position = BEHIND_HOUSE
	hen.reset_physics_interpolation()
	_player().global_position = BEHIND_HOUSE + Vector2(30, 0)
	_player().reset_physics_interpolation()
	await wait_physics_frames(3)
	Input.action_press(&"move_left")
	await wait_physics_frames(24)
	Input.action_release(&"move_left")
	assert_true(await _wait_until(func() -> bool: return hen.penned, 4.0), "%s went in" % hen.name)
	# The hero steps back out into the square, clear of the yard.
	_player().global_position = Vector2(200, 230)
	_player().reset_physics_interpolation()
	await wait_physics_frames(30)


func _assert_in_coop(names: Array[String], context: String) -> void:
	assert_eq(_hens().size(), 3, "%s: no hen is lost or doubled" % context)
	await wait_physics_frames(2)
	for hen_name: String in HenYard.IN_FLAGS.keys().map(func(key: StringName) -> String: return String(key)):
		await wait_physics_frames(1)
		var hen := _hen(hen_name)
		if hen_name in names:
			assert_true(_in_coop(hen), "%s: %s stays in the coop" % [context, hen_name])
		else:
			assert_false(hen.penned, "%s: %s is still loose" % [context, hen_name])


func test_a_hen_driven_in_stays_in_the_coop_after_a_reload() -> void:
	await _load_village(_with(REPAIRED))
	await _assert_in_coop([], "none driven in yet")
	await _push_in(_hen("HenBrown"))
	assert_true(game.adventure.has_flag(&"village_hen_brown_in"))
	assert_false(game.adventure.has_flag(&"village_hens_settled"))
	await _reload()
	await _assert_in_coop(["HenBrown"], "after a reload")
	assert_false(_yard().is_gate_closed(), "the gate stays open while hens are missing")
	assert_eq(_cida().position, CidaWorker.COOP_ROUTE.back(), "Cida still waits with grain")
	assert_true((_yard().get_node(^"Grain") as Sprite2D).visible)
	await wait_physics_frames(120)
	await _assert_in_coop(["HenBrown"], "it does not wander out through the open gate")


func test_each_hen_is_remembered_on_its_own() -> void:
	for hen_name: String in ["HenWhite", "HenBrown", "HenBlack"]:
		var flags := _with(REPAIRED)
		flags.append(HenYard.IN_FLAGS[StringName(hen_name)])
		await _load_village(flags)
		await _assert_in_coop([hen_name], "only %s remembered" % hen_name)
		await _restart()


func test_two_hens_remembered_both_stay_in_and_the_last_completes_the_event() -> void:
	var flags := _with(REPAIRED)
	flags.append_array([&"village_hen_white_in", &"village_hen_black_in"])
	await _load_village(flags)
	await _assert_in_coop(["HenWhite", "HenBlack"], "two remembered")
	await _push_in(_hen("HenBrown"))
	assert_true(game.adventure.has_flag(&"village_hens_settled"), "the third completes the event")
	assert_true(await _wait_until(func() -> bool: return _yard().is_gate_closed(), 2.0))
	await _reload()
	await _assert_in_coop(["HenWhite", "HenBrown", "HenBlack"], "after the event")
	assert_true(_yard().is_gate_closed())
	assert_true((game.level.get_node(^"Entities/EggBasket") as EggBasket).visible)


func test_three_remembered_without_the_event_flag_complete_it_on_arrival() -> void:
	var flags := _with(REPAIRED)
	flags.append_array([&"village_hen_white_in", &"village_hen_brown_in", &"village_hen_black_in"])
	await _load_village(flags)
	assert_true(game.adventure.has_flag(&"village_hens_settled"))
	await _assert_in_coop(["HenWhite", "HenBrown", "HenBlack"], "all three remembered")
	assert_true(await _wait_until(func() -> bool: return _yard().is_gate_closed(), 2.0),
			"the gate shuts with the hero outside")
	assert_eq(_cida().position, CIDA_HOME, "Cida is back at her stall")


func test_hens_already_in_survive_travel_title_and_a_fall() -> void:
	await _load_village(_with(REPAIRED))
	await _push_in(_hen("HenWhite"))
	await _take_exit("ToForest")
	await _take_exit("ToVillage")
	await _assert_in_coop(["HenWhite"], "after walking out and back")
	game.call(&"_return_to_title")
	await wait_physics_frames(3)
	assert_true(game.continue_saved())
	await _settle()
	await _assert_in_coop(["HenWhite"], "after the title and Continue")
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")
	game.travel(&"village", &"north")
	await _settle()
	await _assert_in_coop(["HenWhite"], "after a fall")


func test_an_old_save_with_the_event_done_has_all_three_in() -> void:
	var flags := _with(REPAIRED)
	flags.append(&"village_hens_settled")
	await _load_village(flags)
	await _assert_in_coop(["HenWhite", "HenBrown", "HenBlack"], "event done before hens had flags")
	assert_true(_yard().is_gate_closed())
	for hen_flag: StringName in HenYard.IN_FLAGS.values():
		assert_false(game.adventure.has_flag(hen_flag), "no flag is added to the old save")


func test_an_old_save_with_the_coop_mended_and_no_hen_in_has_three_loose() -> void:
	await _load_village(_with(REPAIRED))
	await _assert_in_coop([], "coop mended, no hen in")
	assert_eq(_cida().position, CidaWorker.COOP_ROUTE.back())


func test_after_returning_with_hens_in_the_rest_are_driven_from_the_square() -> void:
	for remembered: Array in [[&"village_hen_white_in"],
			[&"village_hen_white_in", &"village_hen_brown_in"]]:
		var flags := _with(REPAIRED)
		flags.append_array(remembered)
		await _load_village(flags)
		_player().global_position = Vector2(240, 70)
		_player().reset_physics_interpolation()
		await wait_physics_frames(2)
		assert_true(await _drive_hens_in(150.0), "the rest driven in from the square")
		assert_true(game.adventure.has_flag(&"village_hens_settled"))
		await _restart()


func _pen_standing() -> bool:
	var pen := game.level.get_node_or_null(^"Entities/HenPen")
	return pen != null and not pen.is_queued_for_deletion()


func test_cidas_empty_pen_is_taken_apart_after_the_next_walk_out() -> void:
	var flags := _with(REPAIRED)
	flags.append_array([&"forest_echo_thicket_cut", &"cida_path_acknowledged",
			&"cida_stall_worked", &"village_coop_wood_from_cida"])
	await _load_village(flags)
	assert_eq(await _talk("Anselmo"), "ANSELMO_COOP_READY", "he says he will take it apart")
	# While hens are missing, walking out changes nothing.
	await _take_exit("ToForest")
	await _take_exit("ToVillage")
	assert_false(game.adventure.has_flag(&"village_pen_cleared"))
	assert_true(_pen_standing())
	for hen in _hens():
		await _push_in(hen)
	assert_true(game.adventure.has_flag(&"village_hens_settled"))
	assert_true(_pen_standing(), "nothing vanishes in front of the hero")
	assert_eq((game.level.get_node(^"Entities/WoodStack") as WoodStack).frame, 1)
	# Back to the title is not time away.
	game.call(&"_return_to_title")
	await wait_physics_frames(3)
	assert_true(game.continue_saved())
	await _settle()
	assert_true(_pen_standing())
	await _take_exit("ToForest")
	assert_true(game.adventure.has_flag(&"village_pen_cleared"))
	await _take_exit("ToVillage")
	assert_false(_pen_standing(), "the old pen is gone")
	assert_eq((game.level.get_node(^"Entities/WoodStack") as WoodStack).frame, 0,
			"its wood fills Cida's pile again")
	await _talk("Cida")  # her line about the hens settling in, said once
	assert_eq(await _talk("Cida"), "CIDA_PEN_WOOD_ROOF")
	assert_eq(_line("Cida"), "CIDA_AT_WORK", "said once, then her work again")
	await _reload()
	assert_false(_pen_standing())
	assert_eq(_hens().size(), 3)
	for hen in _hens():
		assert_true(_in_coop(hen))


func test_without_her_wood_in_the_roof_cida_tells_it_differently() -> void:
	var flags := _with(REPAIRED)
	flags.append_array([&"village_hens_settled", &"cida_eggs_promised", &"village_pen_cleared"])
	await _load_village(flags)
	assert_false(_pen_standing())
	assert_eq(await _talk("Cida"), "CIDA_PEN_WOOD")
