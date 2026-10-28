extends "res://tests/integration/adventure_case.gd"
## The forest path and the stone in every order the player can take: the roots are an ordinary
## obstacle that a sword opens at any time, the glint needs the ruin's heart, and the village
## only speaks of what has already happened. Uses the player's own inputs for the forest.

const FIXTURES := "res://tests/fixtures/saves"
const CIDA_HOME := Vector2(382, 306)
const CIDA_WORK := CIDA_HOME + CidaWorker.WORK_OFFSET
const LIA_HOME := Vector2(276, 202)
const RUIN_FLAGS: Array[StringName] = [&"ruin_warden_defeated", &"ruin_heart_awakened"]


func _thicket() -> EchoThicket:
	return game.level.get_node(^"Entities/EchoThicket") as EchoThicket


func _trail() -> EchoTrail:
	return game.level.get_node(^"Entities/EchoTrail") as EchoTrail


func _glint() -> Sprite2D:
	return game.level.get_node(^"Entities/DistantGlint") as Sprite2D


func _cida() -> CidaWorker:
	return game.level.get_node(^"Entities/Cida") as CidaWorker


func _lia() -> LiaObserver:
	return game.level.get_node(^"Entities/Lia") as LiaObserver


func _line(npc_name: String) -> String:
	return (game.level.get_node("Entities/" + npc_name) as Npc).current_line().text


func _hud() -> Hud:
	return game.get_node(^"HUD") as Hud


func _walk(action: StringName, frames: int) -> void:
	Input.action_press(action)
	await wait_physics_frames(frames)
	Input.action_release(action)
	await wait_physics_frames(2)


func _press(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)
	await wait_physics_frames(2)


## From the path south of the clearing: walk into the roots, swing, walk through to the stone.
func _cut_through_and_reach_the_stone() -> void:
	_player().global_position = Vector2(216, 301)
	_player().reset_physics_interpolation()
	await wait_physics_frames(3)
	await _walk(&"move_up", 25)
	assert_gt(_player().global_position.y, 282.0, "the intact roots stop the hero")
	await _press(&"attack")
	await wait_physics_frames(22)
	assert_true(_thicket().is_cut(), "a normal sword swing cuts the roots")
	await _walk(&"move_up", 26)
	assert_lt(_player().global_position.y, 267.0, "the hero walks through the opening")


## Presses interact at the stone and returns what it said, leaving the dialogue open.
func _examine_stone() -> String:
	var said := [""]
	var listen := func(_target: Interactable, message: String) -> void: said[0] = message
	_player().interactor.interacted.connect(listen)
	await _press(&"interact")
	_player().interactor.interacted.disconnect(listen)
	return said[0]


func _close_dialogue() -> void:
	while _hud().is_message_visible():
		_hud().advance()
	await wait_physics_frames(3)


## Follows the glint for up to `seconds`: true if it showed and was hidden again at the end.
func _glint_showed_and_ended(seconds: float) -> bool:
	var showed := false
	var left := seconds
	while left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
		showed = showed or _glint().visible
		if showed and not _trail().is_replying():
			break
	return showed and not _glint().visible and not _trail().is_replying()


func _continue_from(area: StringName, entry: StringName, flags: Array[StringName]) -> void:
	var state := Adventure.new(area, entry)
	for flag in flags:
		state.set_flag(flag)
	state.checkpoint_area = &"ruin" if state.has_flag(&"ruin_heart_awakened") else &"forest"
	state.checkpoint_entry = &"heart" if state.has_flag(&"ruin_heart_awakened") else &"shrine"
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


func _install_fixture(file_name: String) -> void:
	var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
	file.close()


func test_a_the_path_opens_from_a_new_adventure_and_the_stone_stays_dark() -> void:
	game.start_new()
	await _settle()
	await _take_exit("ToForest")
	assert_false(_trail().visible, "no light marks before the ruin")
	await _cut_through_and_reach_the_stone()
	assert_true(game.adventure.has_flag(&"forest_echo_thicket_cut"))
	assert_eq(await _examine_stone(), "ECHO_STONE_DARK")
	await _close_dialogue()
	await wait_physics_frames(60)
	assert_false(_glint().visible, "no glint without the ruin's heart")
	assert_false(_trail().is_replying())
	assert_false(game.adventure.has_flag(&"forest_echo_found"))
	assert_eq(await _examine_stone(), "ECHO_STONE_DARK", "still only dark grooves")
	await _close_dialogue()
	await _take_exit("ToVillage")
	assert_eq(_line("Lia"), "LIA_STUDY", "Lia knows of no glint")
	assert_eq(_lia().position, LIA_HOME)
	assert_eq(await _talk("Cida"), "CIDA_PATH_OPEN", "Cida recognises the reopened route")
	assert_true((game.level.get_node(^"Entities/WoodStack") as WoodStack).visible)
	_player().global_position = Vector2(340, 310)
	await wait_physics_frames(90)
	assert_true(game.adventure.has_flag(&"cida_stall_worked"), "Cida works at the stall")
	assert_almost_eq(_cida().position, CIDA_WORK, Vector2.ONE)
	assert_eq(_line("Cida"), "CIDA_AT_WORK")
	assert_eq(_lia().position, LIA_HOME, "Lia stays at the statue")
	assert_eq(_line("Lia"), "LIA_STUDY")
	assert_eq(await _talk("Anselmo"), "ANSELMO_RUMOR", "the elder still gives the first lead")
	assert_false(_hud().is_guidance_visible(), "the first-step hint is answered")
	assert_eq(await _talk("Anselmo"), "ANSELMO_REMINDER")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(_cida().position, CIDA_WORK)
	game.travel(&"forest", &"south")
	await _settle()
	assert_true(_thicket().is_cut(), "the opening survives a reload")
	assert_false(game.adventure.has_flag(&"forest_echo_found"))


func test_b_ruin_first_then_roots_then_stone() -> void:
	var flags: Array[StringName] = [&"forest_shrine_awakened", &"elder_thanked"]
	flags.append_array(RUIN_FLAGS)
	await _continue_from(&"forest", &"south", flags)
	assert_true(_trail().visible, "the light marks show after the ruin")
	await _cut_through_and_reach_the_stone()
	var answers := [0]
	(game.level.get_node(^"Entities/EchoStone") as EchoStone).answered.connect(
			func() -> void: answers[0] += 1)
	assert_eq(await _examine_stone(), "ECHO_STONE_REPLY")
	assert_true(game.adventure.has_flag(&"forest_echo_found"))
	assert_true(await _glint_showed_and_ended(6.0), "the glint shows, then is gone")
	await _close_dialogue()
	assert_eq(await _examine_stone(), "ECHO_STONE_AFTER")
	await _close_dialogue()
	assert_eq(answers[0], 1, "the reply plays once")
	assert_false(_glint().visible)
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(_lia().position, LIA_HOME)
	assert_eq(_line("Lia"), "LIA_ECHO_PATH")
	assert_eq(_line("Anselmo"), "ANSELMO_ECHO_PATH")
	assert_eq(await _talk("Cida"), "CIDA_PATH_OPEN")
	assert_eq(_lia().position, LiaObserver.ARCH_POSITION, "Lia goes to look for herself")
	assert_eq(_line("Lia"), "LIA_AT_ARCH")
	assert_eq(await _talk("Anselmo"), "ANSELMO_ECHO_PATH")
	_player().global_position = Vector2(340, 310)
	await wait_physics_frames(90)
	assert_true(game.adventure.has_flag(&"cida_stall_worked"))
	assert_eq(_line("Anselmo"), "ANSELMO_WORK")
	assert_eq(game.adventure.checkpoint_area, &"ruin")


func test_c_path_and_work_first_then_the_ruin_then_the_glint() -> void:
	await _continue_from(&"forest", &"south", [&"forest_shrine_awakened", &"elder_thanked"])
	await _cut_through_and_reach_the_stone()
	assert_eq(await _examine_stone(), "ECHO_STONE_DARK")
	await _close_dialogue()
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(await _talk("Cida"), "CIDA_PATH_OPEN")
	_player().global_position = Vector2(340, 310)
	await wait_physics_frames(90)
	assert_true(game.adventure.has_flag(&"cida_stall_worked"))
	assert_eq(_line("Anselmo"), "ANSELMO_WORK")
	assert_eq(_line("Lia"), "LIA_AWAKENED")
	# The ruin is played in test_ruin.gd; here only its outcome matters.
	for flag in RUIN_FLAGS:
		game.adventure.set_flag(flag)
	# The night under the light that follows (Cida's hens) is played in
	# test_shared_responsibility.gd; here it is already behind the village.
	for flag: StringName in [&"village_beacon_night", &"village_coop_offered",
			&"village_coop_repaired", &"village_hens_settled", &"cida_eggs_promised",
			&"lia_light_edge_noted", &"anselmo_mothers_recalled"]:
		game.adventure.set_flag(flag)
	assert_eq(_line("Anselmo"), "ANSELMO_RUIN", "the elder speaks of the light, not the logs")
	assert_eq(_line("Lia"), "LIA_RUIN")
	assert_eq(_line("Cida"), "CIDA_AT_WORK")
	assert_eq(_lia().position, LIA_HOME, "no glint has been seen yet")
	game.travel(&"forest", &"south")
	await _settle()
	assert_true(_thicket().is_cut())
	_player().global_position = Vector2(216, 300)
	_player().reset_physics_interpolation()
	await wait_physics_frames(3)
	await _walk(&"move_up", 50)
	assert_lt(_player().global_position.y, 267.0, "the old opening still leads to the stone")
	assert_eq(await _examine_stone(), "ECHO_STONE_REPLY", "the stone wakes now")
	assert_true(await _glint_showed_and_ended(6.0))
	await _close_dialogue()
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(_lia().position, LiaObserver.ARCH_POSITION)
	assert_eq(_line("Lia"), "LIA_AT_ARCH")
	assert_eq(_cida().position, CIDA_WORK, "Cida does not walk to the stall again")
	assert_false(_cida().is_physics_processing())
	assert_eq(_line("Cida"), "CIDA_AT_WORK")
	assert_eq(_line("Anselmo"), "ANSELMO_WORK")


func test_d_saves_from_earlier_versions_keep_their_progress() -> void:
	var cases := {
		"v2_ruin_complete.json": [LIA_HOME, CIDA_HOME, "CIDA_RUIN", "LIA_MURAL", "ANSELMO_RUIN"],
		"v2_echo_found.json": [LIA_HOME, CIDA_HOME, "CIDA_PATH_OPEN", "LIA_ECHO_PATH",
				"ANSELMO_ECHO_PATH"],
		"v2_path_acknowledged.json": [LiaObserver.ARCH_POSITION, CIDA_HOME, "CIDA_PATH_AFTER",
				"LIA_AT_ARCH", "ANSELMO_ECHO_PATH"],
		"v2_stall_worked.json": [LiaObserver.ARCH_POSITION, CIDA_WORK, "CIDA_AT_WORK",
				"LIA_AT_ARCH", "ANSELMO_WORK"],
	}
	for file_name: String in cases:
		_install_fixture(file_name)
		var saved: Dictionary = JSON.parse_string(
				FileAccess.get_file_as_string(FIXTURES.path_join(file_name)))
		assert_true(game.continue_saved(), file_name)
		await _settle()
		for flag: String in saved["flags"]:
			assert_true(game.adventure.has_flag(StringName(flag)), "%s keeps %s" % [file_name, flag])
		assert_eq(game.adventure.flags().size(), saved["flags"].size(), file_name)
		assert_eq(game.adventure.checkpoint_area, &"ruin", file_name)
		assert_eq(game.adventure.checkpoint_entry, &"heart", file_name)
		assert_eq(_player().health.current, 11, file_name)
		assert_eq(_player().health.max_health, 16, "%s keeps the heart vessel" % file_name)
		if game.level.area_id != &"village":
			game.travel(&"village", &"north")
			await _settle()
		var expected: Array = cases[file_name]
		assert_eq(_lia().position, expected[0], file_name)
		assert_eq(_cida().position, expected[1], file_name)
		assert_eq(_line("Cida"), expected[2], file_name)
		assert_eq(_line("Lia"), expected[3], file_name)
		assert_eq(_line("Anselmo"), expected[4], file_name)
		game.travel(&"forest", &"south")
		await _settle()
		assert_eq(_thicket().is_cut(), game.adventure.has_flag(&"forest_echo_thicket_cut"), file_name)
		await _restart()


func test_d_a_first_format_save_still_loads_without_the_new_events() -> void:
	_install_fixture("v1_back_in_village.json")
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(_line("Cida"), "CIDA_AWAKENED")
	assert_eq(_lia().position, LIA_HOME)
	assert_false(game.adventure.has_flag(&"forest_echo_thicket_cut"))
	assert_eq(game.adventure.checkpoint_area, &"forest")
