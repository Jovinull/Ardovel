extends "res://tests/integration/adventure_case.gd"
## Villagers act on the opened path without changing old saves or blocking the hero.

const HOME := Vector2(382, 306)
const WORK := HOME + CidaWorker.WORK_OFFSET
const ARCH := LiaObserver.ARCH_POSITION


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


func _cida() -> CidaWorker:
	return game.level.get_node(^"Entities/Cida") as CidaWorker


func _lia() -> LiaObserver:
	return game.level.get_node(^"Entities/Lia") as LiaObserver


func test_old_progress_keeps_villagers_in_their_original_places() -> void:
	await _load_village([])
	assert_eq(_cida().position, HOME)
	assert_eq(_lia().position, Vector2(276, 202))
	assert_eq(_cida().current_line().text, "CIDA_EMPTY")
	assert_false(game.adventure.has_flag(&"cida_stall_worked"))
	await wait_physics_frames(90)
	assert_eq(_cida().position, HOME)
	assert_false((game.level.get_node(^"Entities/WoodStack") as WoodStack).visible)


func test_the_ruin_and_stone_alone_do_not_start_the_village_work() -> void:
	await _load_village([&"forest_shrine_awakened", &"ruin_guardian_defeated",
			&"ruin_heart_awakened"])
	assert_eq(_cida().current_line().text, "CIDA_RUIN")
	assert_eq(_lia().position, Vector2(276, 202))
	assert_false(game.adventure.has_flag(&"cida_stall_worked"))
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(_cida().position, HOME)
	game.adventure.set_flag(&"forest_echo_found")
	assert_eq(_cida().current_line().text, "CIDA_PATH_OPEN")
	assert_eq(_lia().position, Vector2(276, 202))
	assert_false((game.level.get_node(^"Entities/WoodStack") as WoodStack).visible)


func test_cida_works_only_after_hearing_about_the_path() -> void:
	await _load_village([&"forest_shrine_awakened", &"ruin_guardian_defeated",
			&"ruin_heart_awakened", &"forest_echo_found"])
	assert_eq(await _talk("Cida"), "CIDA_PATH_OPEN")
	assert_true((game.level.get_node(^"Entities/WoodStack") as WoodStack).visible)
	assert_eq(_lia().position, ARCH)
	assert_eq(_lia().current_line().text, "LIA_AT_ARCH")
	assert_false(game.adventure.has_flag(&"cida_stall_worked"))
	await wait_physics_frames(85)
	assert_true(game.adventure.has_flag(&"cida_stall_worked"),
			"Cida stopped at %s while the hero was at %s" % [_cida().position, _player().position])
	assert_almost_eq(_cida().position, WORK, Vector2.ONE)
	assert_eq(_cida().current_line().text, "CIDA_AT_WORK")
	assert_eq((game.level.get_node(^"Entities/Anselmo") as Npc).current_line().text,
			"ANSELMO_WORK")
	assert_eq(game.adventure.checkpoint_area, &"ruin")
	assert_eq(game.adventure.checkpoint_entry, &"heart")


func test_cida_waits_for_the_hero_instead_of_walking_through_them() -> void:
	await _load_village([&"forest_shrine_awakened", &"ruin_guardian_defeated",
			&"ruin_heart_awakened", &"forest_echo_found"])
	_player().global_position = WORK
	await wait_physics_frames(2)
	game.adventure.set_flag(&"cida_path_acknowledged")
	await wait_physics_frames(90)
	assert_false(game.adventure.has_flag(&"cida_stall_worked"))
	assert_lt(_cida().position.distance_to(HOME), HOME.distance_to(WORK))
	_player().global_position = Vector2(330, 330)
	await wait_physics_frames(90)
	assert_true(game.adventure.has_flag(&"cida_stall_worked"))
	assert_almost_eq(_cida().position, WORK, Vector2.ONE)


func test_the_work_and_new_positions_survive_continue_and_reentry() -> void:
	await _load_village([&"forest_shrine_awakened", &"ruin_guardian_defeated",
			&"ruin_heart_awakened", &"forest_echo_found", &"cida_path_acknowledged"])
	await wait_physics_frames(85)
	assert_false(game.adventure.has_flag(&"cida_stall_worked"),
			"an older save keeps the work visible until the hero reaches the stall")
	assert_eq(_cida().position, HOME)
	_player().global_position = Vector2(340, 310)
	await wait_physics_frames(85)
	assert_true(game.adventure.has_flag(&"cida_stall_worked"))
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(_cida().position, WORK)
	assert_eq(_lia().position, ARCH)
	assert_eq(await _talk("Cida"), "CIDA_AT_WORK")
	game.travel(&"forest", &"south")
	await _settle()
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(_cida().position, WORK)
	assert_eq(_lia().position, ARCH)
	assert_true((game.level.get_node(^"Entities/WoodStack") as WoodStack).visible)
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")
	assert_true(game.adventure.has_flag(&"cida_stall_worked"))
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(_cida().position, WORK)
	assert_eq(_lia().position, ARCH)
