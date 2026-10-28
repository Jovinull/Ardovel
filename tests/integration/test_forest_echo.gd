extends "res://tests/integration/adventure_case.gd"
## The forest clearing: the roots are an ordinary obstacle that a sword opens at any time, the
## stone answers only after the ruin's heart wakes, and both shrines stay reachable.


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


func _can_reach(from: Vector2i, to: Vector2i, bounds: Rect2i) -> bool:
	# Flood a grid using the real player's body and the level's collision layer.
	# Starting at different exterior points tests the entire ring, not one scripted route.
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


func test_before_the_heart_wakes_the_roots_cut_but_the_stone_stays_dark() -> void:
	await _continue_in_forest(false)
	assert_false(_thicket().is_cut())
	_strike_thicket()
	await wait_physics_frames(2)
	assert_true(game.adventure.has_flag(&"forest_echo_thicket_cut"), "an ordinary obstacle")
	assert_true((_thicket().get_node(^"Collision") as CollisionShape2D).disabled)
	var answers := [0]
	_stone().answered.connect(func() -> void: answers[0] += 1)
	assert_eq((_stone().get_node(^"Interactable") as Interactable).interact(_player()),
			"ECHO_STONE_DARK")
	assert_eq(answers[0], 0)
	assert_false(game.adventure.has_flag(&"forest_echo_found"))
	assert_eq(game.adventure.checkpoint_area, &"forest")
	assert_false((game.level.get_node(^"Entities/EchoTrail") as EchoTrail).visible)
	assert_false((game.level.get_node(^"Entities/DistantGlint") as Sprite2D).visible)


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
	assert_eq(await _talk("Lia"), "LIA_AT_ARCH")
	assert_eq(await _talk("Anselmo"), "ANSELMO_ECHO_PATH")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_true(game.adventure.has_flag(&"cida_path_acknowledged"))
	assert_true((game.level.get_node(^"Entities/WoodStack") as WoodStack).visible)
	assert_eq(await _talk("Cida"), "CIDA_PATH_AFTER")
	game.travel(&"forest", &"south")
	await _settle()
	assert_true(_thicket().is_cut(), "the opened passage survives a save reload")
	assert_eq((_stone().get_node(^"Sprite") as Sprite2D).region_rect.position.x, 48.0,
			"the stone keeps its discovered frame")
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")


func test_the_clearing_is_physically_closed_until_the_sword_opens_it() -> void:
	await _continue_in_forest(true)
	await _check_the_closed_clearing_and_open_it()


func test_before_the_ruin_the_clearing_closes_and_opens_the_same_way() -> void:
	await _continue_in_forest(false)
	await _check_the_closed_clearing_and_open_it(false)


func _check_the_closed_clearing_and_open_it(heart_awake: bool = true) -> void:
	# The four starts represent approaches from the south, west, east and north.
	var pocket := Rect2i(116, 180, 200, 152)
	for start in [Vector2i(216, 300), Vector2i(120, 252),
			Vector2i(308, 252), Vector2i(216, 184)]:
		assert_false(_can_reach(start, Vector2i(216, 256), pocket),
				"the stone cannot be reached around the intact roots from %s" % start)
	assert_false(game.adventure.has_flag(&"forest_echo_found"))
	_player().global_position = Vector2(216, 301)
	await wait_physics_frames(3)
	await _walk(&"move_up", 25)
	assert_gt(_player().global_position.y, 282.0, "the closed gate stops the hero")
	await _press(&"attack")
	await wait_physics_frames(22)
	assert_true(_thicket().is_cut(), "a normal sword swing cuts the roots")
	assert_true(_can_reach(Vector2i(216, 300), Vector2i(216, 256), pocket),
			"the opened gate connects the path to the stone")
	assert_true(_can_reach(Vector2i(216, 256), Vector2i(216, 300), pocket),
			"the hero can always leave the opened pocket")
	await _walk(&"move_up", 26)
	assert_lt(_player().global_position.y, 267.0, "the hero crosses the opened gate")
	var answers := [0]
	_stone().answered.connect(func() -> void: answers[0] += 1)
	await _press(&"interact")
	assert_eq(game.adventure.has_flag(&"forest_echo_found"), heart_awake,
			"the normal interaction discovers the stone only after the heart wakes")
	assert_eq(answers[0], 1 if heart_awake else 0)
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	await _press(&"interact")
	assert_eq(answers[0], 1 if heart_awake else 0, "the reply never repeats")
	assert_eq(game.adventure.checkpoint_area, &"ruin" if heart_awake else &"forest")


func test_the_earlier_route_still_connects_village_shrine_and_ruin() -> void:
	var whole_map := Rect2i(8, 8, 624, 432)
	for heart_awake in [false, true]:
		await _continue_in_forest(heart_awake)
		for cut in [false, true]:
			if cut:
				_strike_thicket()
				await wait_physics_frames(2)
			assert_true(_can_reach(Vector2i(328, 416), Vector2i(320, 128), whole_map),
					"shrine (heart %s, cut %s)" % [heart_awake, cut])
			assert_true(_can_reach(Vector2i(328, 416), Vector2i(448, 96), whole_map),
					"ruin (heart %s, cut %s)" % [heart_awake, cut])
		await _restart()
