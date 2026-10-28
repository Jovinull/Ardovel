extends "res://tests/integration/adventure_case.gd"
## The forest revisiting prototype uses the existing adventure flags and keeps both shrines intact.


func _continue_in_forest(heart_awake: bool) -> void:
	var state := Adventure.new(&"forest", &"ruin")
	state.set_flag(&"forest_shrine_awakened")
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	if heart_awake:
		state.set_flag(&"ruin_guardian_defeated")
		state.set_flag(&"ruin_heart_awakened")
		state.checkpoint_area = &"ruin"
		state.checkpoint_entry = &"heart"
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


func _thicket() -> EchoThicket:
	return game.level.get_node(^"Entities/EchoThicket") as EchoThicket


func _stone() -> EchoStone:
	return game.level.get_node(^"Entities/EchoStone") as EchoStone


func _strike_thicket() -> void:
	(_thicket().get_node(^"Hurtbox") as Hurtbox).receive_hit(
			Hit.new(1, 0.0, _thicket().global_position))


func test_the_old_forest_has_no_usable_echo_before_the_heart_wakes() -> void:
	await _continue_in_forest(false)
	assert_false(_thicket().is_cut())
	_strike_thicket()
	assert_false(game.adventure.has_flag(&"forest_echo_thicket_cut"))
	assert_eq((_stone().get_node(^"Interactable") as Interactable).interact(_player()),
			"ECHO_STONE_DARK")
	assert_false(game.adventure.has_flag(&"forest_echo_found"))
	assert_eq(game.adventure.checkpoint_area, &"forest")
	assert_false((game.level.get_node(^"Entities/EchoTrail") as EchoTrail).visible)


func test_a_returning_hero_opens_the_path_without_optional_readings() -> void:
	await _continue_in_forest(true)
	assert_true((game.level.get_node(^"Entities/EchoTrail") as EchoTrail).visible)
	assert_false(game.adventure.has_flag(&"ruin_mural_read"))
	assert_false(game.adventure.has_flag(&"ruin_tablet_read"))
	assert_eq((_stone().get_node(^"Interactable") as Interactable).interact(_player()),
			"ECHO_STONE_BLOCKED")
	_strike_thicket()
	await wait_physics_frames(2)
	assert_true(_thicket().is_cut())
	assert_true((_thicket().get_node(^"Collision") as CollisionShape2D).disabled)
	var answers := [0]
	_stone().answered.connect(func() -> void: answers[0] += 1)
	assert_eq((_stone().get_node(^"Interactable") as Interactable).interact(_player()),
			"ECHO_STONE_REPLY")
	assert_true(game.adventure.has_flag(&"forest_echo_found"))
	assert_eq((_stone().get_node(^"Interactable") as Interactable).interact(_player()),
			"ECHO_STONE_AFTER", "no repeated event")
	assert_eq(answers[0], 1, "the reply only plays on the first discovery")
	assert_eq(game.adventure.checkpoint_area, &"ruin")
	assert_eq(game.adventure.checkpoint_entry, &"heart")


func test_cidas_change_survives_save_continue_and_respawn() -> void:
	await _continue_in_forest(true)
	_strike_thicket()
	(_stone().get_node(^"Interactable") as Interactable).interact(_player())
	game.travel(&"village", &"north")
	await _settle()
	var stack: WoodStack = game.level.get_node(^"Entities/WoodStack")
	assert_false(stack.visible, "the stall changes when Cida acknowledges the path")
	assert_eq(await _talk("Cida"), "CIDA_PATH_OPEN")
	assert_true(stack.visible)
	assert_eq(await _talk("Cida"), "CIDA_PATH_AFTER")
	assert_eq(await _talk("Lia"), "LIA_ECHO_PATH")
	assert_eq(await _talk("Anselmo"), "ANSELMO_ECHO_PATH")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_true(game.adventure.has_flag(&"cida_path_acknowledged"))
	assert_true((game.level.get_node(^"Entities/WoodStack") as WoodStack).visible)
	assert_eq(await _talk("Cida"), "CIDA_PATH_AFTER")
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")
