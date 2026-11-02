extends "res://tests/integration/adventure_case.gd"
## Milestone 7.4, played on the real game scene with real key events (and simulated gamepad
## buttons): each technique against real creatures (Passo Perfurante steps in and stops at a wall,
## Golpe de Ruptura gets through a bracing Musgorico and shuts a Cardosa without pushing it, Varrida
## do Bordão hits each one in its arc once and nothing through a wall, Resposta da Guarda answers a
## clean block once and never a blow from behind, an unblockable one or a broken guard), what keeps a
## technique from starting (weapon, shield, breath, the moment), the passive skills in play, the
## Techniques page (learning with a confirmation, cancelling, slots, the passive), the HUD, a blow
## taken or a fall during a technique, no stale swing after one, and everything kept through
## saving, Continue, travel and a fall.

const MusgoricoScene := preload("res://actors/musgorico/musgorico.tscn")
const CardosaScene := preload("res://actors/cardosa/cardosa.tscn")
const SPOT := Vector2(380, 144)


func after_each() -> void:
	super.after_each()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"block",
			&"technique_1", &"technique_2", &"dodge"]:
		Input.action_release(action)


## A hero at `level` at the halt (no creature of its own), with `items` and `worn`, the skills
## `learned`, `slots` (two technique slots) and `passive`.
func _state(level: int, items: Dictionary = {}, worn: Dictionary = {}, learned: Array[StringName] = [],
		slots: Array[StringName] = [&"", &""], passive: StringName = &"") -> Adventure:
	var state := Adventure.new(&"waystop", &"east")
	for flag in [&"heard_of_shrine", &"equipment_seen", &"forest_shrine_awakened"]:
		state.set_flag(flag)
	state.experience = HeroGrowth.experience_for(level)
	for id: StringName in items:
		state.add_item(id, items[id])
	for slot: StringName in worn:
		if state.count(worn[slot]) <= state.equipped_copies(worn[slot]):
			state.add_item(worn[slot])
		assert_true(state.equip(slot, worn[slot]), "%s in %s" % [worn[slot], slot])
	for id in learned:
		assert_true(Skills.learn(state, id), String(id))
	state.set_skill_slots(slots)
	state.set_passive_skill(passive)
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	return state


func _continue_with(state: Adventure) -> void:
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()
	_player().global_position = SPOT
	_player().reset_physics_interpolation()
	_player().health.max_health = 99
	_player().health.restore_full()
	await wait_physics_frames(2)


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_process_frames(2)
		await wait_physics_frames(1)


func _button(index: JoyButton) -> void:
	for pressed in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = index
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_process_frames(2)
		await wait_physics_frames(1)


func _trigger(axis: JoyAxis) -> void:
	for value in [1.0, 0.0]:
		var event := InputEventJoypadMotion.new()
		event.axis = axis
		event.axis_value = value
		Input.parse_input_event(event)
		await wait_process_frames(2)
		await wait_physics_frames(1)


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


func _done() -> void:
	await _wait_until(func() -> bool: return _player().state != Player.State.TECHNIQUE, 2.0)
	await wait_physics_frames(2)


## A Musgorico to spar with: everything as usual, but its touch hurts nobody (a hurt hero cannot start
## a technique, and these tests are about the techniques).
func _musgorico(offset: Vector2) -> Musgorico:
	var musgo: Musgorico = MusgoricoScene.instantiate()
	musgo.rng_seed = 4
	game.level.get_node(^"Entities").add_child(musgo)
	musgo.global_position = _player().global_position + offset
	(musgo.get_node(^"ContactHitbox") as Hitbox).damage = 0
	return musgo


## A Musgorico that also stays where it is put (it still reacts to every blow).
func _still_musgorico(offset: Vector2) -> Musgorico:
	var musgo := _musgorico(offset)
	musgo.wander_speed = 0.0
	musgo.chase_speed = 0.0
	musgo.lunge_speed = 0.0
	return musgo


## A solid post (the world layer, as walls and trunks are) at `offset` from the hero.
func _wall(offset: Vector2, size: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	game.level.get_node(^"Entities").add_child(wall)
	wall.global_position = _player().global_position + offset
	return wall


func _hud() -> Hud:
	return game.get_node(^"HUD")


func _menu() -> HeroMenu:
	return game.hero_menu()


## A blow of `damage` arriving from `offset`, through the hero's own hurtbox (and so their guard).
func _blow(offset: Vector2, damage: int = 2, blockable: bool = true) -> void:
	var hit := Hit.new(damage, 120.0, _player().global_position + offset)
	hit.blockable = blockable
	(_player().get_node(^"Hurtbox") as Hurtbox).receive_hit(hit)
	await wait_physics_frames(1)


# ---------------------------------------------------------------- Passo Perfurante

func test_the_piercing_step_steps_in_and_strikes() -> void:
	await _continue_with(_state(2, {}, {}, [&"piercing_step"], [&"piercing_step", &""]))
	_player().face(Vector2.LEFT)  # away from the halt's east way out
	var musgo := _still_musgorico(Vector2(-40, 0))
	var from := _player().global_position
	await _press(&"technique_1")
	assert_eq(_player().state, Player.State.TECHNIQUE, "the O key starts it")
	assert_almost_eq(_player().stamina.current, 70.0, 1.0, "thirty breath")
	await _done()
	assert_lt(_player().global_position.x, from.x - 20.0, "the hero stepped in")
	assert_eq(musgo.health.current, 2, "1.5 quarters: one taken, half carried")
	assert_eq(_player().weapon_attack(), _player().weapon_swing(), "the sword's own swing is back")
	await wait_physics_frames(40)
	_player().face(Vector2.LEFT)
	_player().global_position = musgo.global_position + Vector2(40, 0)
	_player().reset_physics_interpolation()
	_player().stamina.refill()
	await wait_physics_frames(2)
	await _press(&"technique_1")
	await _done()
	assert_true(musgo.health.is_dead(), "1.5 + the half carried: the second step fells it")


func test_the_piercing_step_stops_at_a_wall_and_strikes_nothing_behind_it() -> void:
	await _continue_with(_state(2, {}, {}, [&"piercing_step"], [&"piercing_step", &""]))
	_player().face(Vector2.RIGHT)
	var wall := _wall(Vector2(22, 0), Vector2(6, 40))
	var musgo := _musgorico(Vector2(40, 0))
	await wait_physics_frames(2)
	await _press(&"technique_1")
	await _done()
	assert_lt(_player().global_position.x, wall.global_position.x - 3.0, "never through the wall")
	assert_eq(musgo.health.current, musgo.health.max_health, "nothing struck through it")


func test_a_technique_needs_its_weapon_and_its_breath() -> void:
	await _continue_with(_state(4, {&"quarry_maul": 1}, {&"main_hand": &"quarry_maul"}, [&"piercing_step"],
			[&"piercing_step", &""]))
	assert_true(_hud().is_technique_shown(0))
	assert_true(_hud().is_technique_dimmed(0), "dim: not for the maul")
	await _press(&"technique_1")
	assert_eq(_player().state, Player.State.MOVE, "nothing happens with the maul")
	assert_eq(_player().stamina.current, 100.0, "and nothing is spent")
	game.adventure.equip(ItemCatalog.MAIN_HAND, &"wayfarer_sword")
	await wait_physics_frames(2)
	assert_false(_hud().is_technique_dimmed(0), "the sword in hand again: ready")
	var refusals: Array[StringName] = []
	_player().techniques().refused.connect(func(_slot: int, reason: StringName) -> void: refusals.append(reason))
	_player().stamina.current = 10.0
	await _press(&"technique_1")
	assert_eq(_player().state, Player.State.MOVE, "not enough breath")
	assert_eq(refusals, [&"breath"] as Array[StringName])
	assert_lt(_hud().technique_tint(0).g, 0.9, "the slot flashes red")
	assert_lt(_player().stamina.current, 30.0, "nothing was spent (only what came back on its own)")


# ---------------------------------------------------------------- Golpe de Ruptura

func test_the_breaking_blow_gets_through_a_bracing_musgorico() -> void:
	await _continue_with(_state(4, {&"woodcutter_hatchet": 1}, {&"main_hand": &"woodcutter_hatchet"},
			[&"breaking_blow"], [&"breaking_blow", &""]))
	_player().face(Vector2.RIGHT)
	var musgo := _still_musgorico(Vector2(16, 0))
	await wait_physics_frames(2)
	musgo.set(&"_steady_until", musgo.get(&"_clock") + 30.0)
	await _press(&"attack")
	await _wait_until(func() -> bool: return _player().state == Player.State.MOVE, 2.0)
	assert_lt(musgo.health.current, 3, "the hatchet's swing landed")
	assert_ne(musgo.state, Musgorico.State.HURT, "but it braces and keeps going")
	await wait_physics_frames(20)
	_player().global_position = musgo.global_position - Vector2(16, 0)
	_player().reset_physics_interpolation()
	_player().face(Vector2.RIGHT)
	await wait_physics_frames(2)
	assert_true(musgo.is_steady(), "still bracing")
	await _press(&"technique_1")
	await _wait_until(func() -> bool: return musgo.state == Musgorico.State.HURT or musgo.health.is_dead(), 1.5)
	assert_true(musgo.state == Musgorico.State.HURT or musgo.health.is_dead(), "the breaking blow gets through")


func test_the_breaking_blow_shuts_a_cardosa_without_pushing_it() -> void:
	await _continue_with(_state(4, {&"quarry_maul": 1}, {&"main_hand": &"quarry_maul"}, [&"breaking_blow"],
			[&"breaking_blow", &""]))
	_player().face(Vector2.RIGHT)
	var cardosa: Cardosa = CardosaScene.instantiate()
	game.level.get_node(^"Entities").add_child(cardosa)
	cardosa.global_position = _player().global_position + Vector2(16, 0)
	cardosa.health.max_health = 20
	cardosa.health.restore_full()
	await wait_physics_frames(2)
	var at := cardosa.global_position
	await _press(&"technique_1")
	await _wait_until(func() -> bool: return cardosa.state == Cardosa.State.HURT, 1.5)
	assert_eq(cardosa.state, Cardosa.State.HURT, "shut")
	assert_gte(cardosa.get(&"_state_left"), 1.0, "for longer than a swing shuts it")
	assert_eq(cardosa.global_position, at, "rooted: never pushed")
	assert_eq(cardosa.health.current, 17, "the maul's 2 x1.5: three quarters")


# ---------------------------------------------------------------- Varrida do Bordão

func test_the_staff_sweep_hits_each_in_its_arc_once_and_nothing_behind() -> void:
	await _continue_with(_state(4, {&"traveller_staff": 1}, {&"main_hand": &"traveller_staff"}, [&"staff_sweep"],
			[&"staff_sweep", &""]))
	_player().face(Vector2.DOWN)
	var left := _musgorico(Vector2(-15, 10))
	var right := _musgorico(Vector2(15, 10))
	var behind := _musgorico(Vector2(0, -24))
	await wait_physics_frames(1)
	await _press(&"technique_1")
	await _done()
	assert_eq(left.health.current, 2, "the left one, once")
	assert_eq(right.health.current, 2, "the right one, once")
	assert_eq(behind.health.current, 3, "nothing behind the hero")


func test_the_staff_sweep_never_lands_through_a_wall() -> void:
	await _continue_with(_state(4, {&"traveller_staff": 1}, {&"main_hand": &"traveller_staff"}, [&"staff_sweep"],
			[&"staff_sweep", &""]))
	_player().face(Vector2.DOWN)
	_wall(Vector2(0, 9), Vector2(40, 4))
	var beyond := _musgorico(Vector2(0, 20))
	await wait_physics_frames(1)
	await _press(&"technique_1")
	await _done()
	assert_eq(beyond.health.current, 3, "the wall is between")


# ---------------------------------------------------------------- Resposta da Guarda

func _guarded() -> Adventure:
	return _state(6, {&"crew_board_shield": 1}, {&"off_hand": &"crew_board_shield"}, [&"guard_response"],
			[&"", &"guard_response"])


func _raise() -> void:
	_player().face(Vector2.RIGHT)
	Input.action_press(&"block")
	await wait_physics_frames(12)
	assert_true(_player().is_guarding())


func test_the_guard_response_answers_a_clean_block_once() -> void:
	await _continue_with(_guarded())
	var musgo := _musgorico(Vector2(18, 0))
	await _raise()
	await _press(&"technique_2")
	assert_ne(_player().state, Player.State.TECHNIQUE, "nothing to answer yet")
	await _blow(Vector2(18, 0))
	assert_true(_player().techniques().is_response_open(), "a clean block opens the moment")
	assert_true(_hud().is_technique_ready_marked(1), "and the slot shows it")
	await _press(&"technique_2")
	assert_eq(_player().state, Player.State.TECHNIQUE, "the answer")
	await _done()
	assert_lt(musgo.health.current, 3, "it lands")
	assert_false(_player().techniques().is_response_open(), "one answer per block")
	await _press(&"technique_2")
	assert_ne(_player().state, Player.State.TECHNIQUE, "not twice")


func test_no_answer_to_a_blow_from_behind_an_unblockable_one_or_a_broken_guard() -> void:
	await _continue_with(_guarded())
	await _raise()
	await _blow(Vector2(-18, 0))
	assert_false(_player().techniques().is_response_open(), "from behind: not blocked, nothing to answer")
	await _wait_until(func() -> bool: return _player().state != Player.State.HURT, 2.0)
	await wait_physics_frames(30)
	Input.action_release(&"block")
	await wait_physics_frames(2)
	await _raise()
	await _blow(Vector2(18, 0), 4, false)
	assert_false(_player().techniques().is_response_open(), "an unblockable blow")
	await _wait_until(func() -> bool: return _player().state != Player.State.HURT, 2.0)
	await wait_physics_frames(30)
	Input.action_release(&"block")
	await wait_physics_frames(2)
	await _raise()
	_player().stamina.current = 1.0
	await _blow(Vector2(18, 0))
	assert_false(_player().techniques().is_response_open(), "a broken guard answers nothing")


func test_letting_go_of_the_shield_and_answering_at_once_still_answers() -> void:
	await _continue_with(_guarded())
	var musgo := _still_musgorico(Vector2(18, 0))
	await _raise()
	await _blow(Vector2(18, 0))
	Input.action_release(&"block")
	Input.action_press(&"technique_2")
	await wait_physics_frames(2)
	Input.action_release(&"technique_2")
	assert_eq(_player().state, Player.State.TECHNIQUE, "the shield coming down and the answer, in the same moment")
	await _done()
	assert_lt(musgo.health.current, 3)


func test_the_moment_to_answer_passes() -> void:
	await _continue_with(_guarded())
	await _raise()
	await _blow(Vector2(18, 0))
	assert_true(_player().techniques().is_response_open())
	await wait_physics_frames(40)
	assert_false(_player().techniques().is_response_open(), "0.45 s later, gone")
	await _press(&"technique_2")
	assert_ne(_player().state, Player.State.TECHNIQUE)


# ---------------------------------------------------------------- passive skills

func test_trained_steps_make_a_dodge_cheaper() -> void:
	await _continue_with(_state(2, {}, {}, [&"trained_steps"], [&"", &""], &"trained_steps"))
	await _press(&"dodge")
	assert_almost_eq(_player().stamina.current, 100.0 - 17.5, 0.5, "17.5 breath, not 25")


func test_a_firm_stance_takes_blows_held_still_more_cheaply() -> void:
	await _continue_with(_state(6, {&"crew_board_shield": 1}, {&"off_hand": &"crew_board_shield"}, [&"firm_stance"],
			[&"", &""], &"firm_stance"))
	await _raise()
	await _blow(Vector2(18, 0), 2)
	assert_almost_eq(_player().stamina.current, 100.0 - 2 * 7.0 * 0.6, 0.6, "held still: 60% of the breath")
	await wait_physics_frames(40)
	_player().stamina.refill()
	Input.action_press(&"move_up")
	await wait_physics_frames(3)
	await _blow(Vector2(18, -2), 2)
	Input.action_release(&"move_up")
	assert_almost_eq(_player().stamina.current, 100.0 - 2 * 7.0, 0.6, "moving: the full cost")


# ---------------------------------------------------------------- the Techniques page

func test_skills_are_learned_and_slotted_with_real_keys() -> void:
	await _continue_with(_state(6))
	await _press(&"equipment")
	await _press(&"menu_prev")
	assert_eq(_menu().page, HeroMenu.Page.SKILLS, "the fourth page")
	assert_eq(_menu().selected_skill(), &"piercing_step")
	await _press(&"interact")
	assert_true(_menu().is_confirming_learn(), "asks first")
	await _press(&"ui_cancel")
	assert_false(_menu().is_confirming_learn())
	assert_true(_menu().is_open(), "the back key only cancels")
	assert_false(game.get_node(^"PauseScreen").call(&"is_open"), "and opens no pause")
	assert_eq(Skills.points_free(game.adventure), 3, "nothing spent")
	await _press(&"interact")
	await _press(&"interact")
	assert_true(game.adventure.has_skill(&"piercing_step"), "learned")
	assert_eq(Skills.points_free(game.adventure), 2)
	await _press(&"interact")
	assert_true(_menu().is_choosing_slot())
	await _press(&"move_right")
	await _press(&"interact")
	assert_eq(game.adventure.skill_slots(), [&"", &"piercing_step"] as Array[StringName], "in the second slot")
	await _press(&"move_down")
	assert_eq(_menu().selected_skill(), &"trained_steps")
	await _press(&"interact")
	await _press(&"interact")
	await _press(&"interact")
	assert_eq(game.adventure.passive_skill, &"trained_steps", "learned and in use")
	await _press(&"move_right")
	await _press(&"interact")
	assert_eq(_menu().notice(), "SKILLS_STATE_POINTS" if Skills.points_free(game.adventure) < 1 else "", "")
	await _press(&"equipment")
	assert_false(_menu().is_open())
	_player().face(Vector2.RIGHT)
	await _press(&"technique_2")
	assert_eq(_player().state, Player.State.TECHNIQUE, "used at once from its slot")


func test_the_page_and_the_techniques_with_a_gamepad() -> void:
	await _continue_with(_state(4, {}, {}, [&"piercing_step"], [&"", &""]))
	game.open_equipment()
	for i in 3:
		await _button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(_menu().page, HeroMenu.Page.SKILLS)
	await _button(JOY_BUTTON_A)
	assert_true(_menu().is_choosing_slot())
	await _button(JOY_BUTTON_A)
	assert_eq(game.adventure.skill_slots()[0], &"piercing_step")
	await _button(JOY_BUTTON_BACK)
	assert_false(_menu().is_open())
	_player().face(Vector2.RIGHT)
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(_player().state, Player.State.TECHNIQUE, "RB uses the first slot")
	await _done()
	Skills.equip(game.adventure, &"piercing_step", 1)
	await wait_physics_frames(2)
	_player().stamina.refill()
	await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	assert_eq(_player().state, Player.State.TECHNIQUE, "RT the second")


# ---------------------------------------------------------------- states

func test_a_blow_taken_cancels_a_technique_and_nothing_is_left_behind() -> void:
	await _continue_with(_state(4, {&"woodcutter_hatchet": 1}, {&"main_hand": &"woodcutter_hatchet"},
			[&"breaking_blow"], [&"breaking_blow", &""]))
	var swing := _player().weapon_swing()
	_player().face(Vector2.RIGHT)
	await _press(&"technique_1")
	assert_eq(_player().state, Player.State.TECHNIQUE)
	await _blow(Vector2(-18, 0))
	assert_eq(_player().state, Player.State.HURT, "a blow in the long windup")
	assert_false(_player().techniques().is_running())
	assert_eq(_player().weapon_attack(), swing, "the hatchet's own swing back, no technique left in it")
	assert_null((_player().get_node(^"AttackPivot/SwordHitbox") as Hitbox).sight_from)


func test_no_old_swing_fires_after_a_technique() -> void:
	await _continue_with(_state(2, {}, {}, [&"piercing_step"], [&"piercing_step", &""]))
	_player().face(Vector2.RIGHT)
	await _press(&"technique_1")
	await _press(&"attack")
	await _done()
	assert_eq(_player().state, Player.State.MOVE, "the swing pressed during it is dropped")


func test_a_fall_during_a_technique_and_everything_kept() -> void:
	await _continue_with(_state(8, {&"crew_board_shield": 1}, {&"off_hand": &"crew_board_shield"},
			[&"piercing_step", &"guard_response", &"firm_stance"], [&"piercing_step", &"guard_response"], &"firm_stance"))
	_player().face(Vector2.RIGHT)
	await _press(&"technique_1")
	_player().health.take_damage(999)
	assert_false(_player().techniques().is_running(), "a fall stops it")
	await _wait_until(func() -> bool: return _player().state == Player.State.DEAD, 1.0)
	await WaitFor.signal_or_timeout(get_tree(), _player().died, 4.0)
	game.respawn()
	await _settle()
	assert_eq(_player().state, Player.State.MOVE, "back at the shrine, free")
	assert_eq(game.adventure.skill_slots(), [&"piercing_step", &"guard_response"] as Array[StringName])
	assert_true(_player().firm_stance)
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.skills(), [&"piercing_step", &"guard_response", &"firm_stance"] as Array[StringName])
	assert_eq(Skills.points_free(game.adventure), 0, "level 8: four points, all spent; never charged or given twice")
	assert_true(_hud().is_technique_shown(0))
	game.travel(&"village", &"north")
	await _settle()
	assert_true(_hud().is_technique_shown(1), "after travel")
	assert_false(_player().techniques().is_running())


func test_a_technique_wears_the_armour() -> void:
	await _continue_with(_state(2, {}, {&"head": &"quarry_helm", &"torso": &"quarry_breastplate"}, [&"piercing_step"],
			[&"piercing_step", &""]))
	var look := game.hero_profile().look()
	assert_not_null(look.technique)
	var frames := (_player().get_node(^"Sprite") as AnimatedSprite2D).sprite_frames
	for direction in ["down", "up", "left", "right"]:
		var frame := frames.get_frame_texture(StringName("technique_" + direction), 1) as AtlasTexture
		assert_eq(frame.atlas, look.technique, "the thrust drawn with the helm and plate, " + direction)
	_player().face(Vector2.LEFT)
	await _press(&"technique_1")
	await wait_physics_frames(12)
	assert_eq((_player().get_node(^"Sprite") as AnimatedSprite2D).animation, &"technique_left")
	await _done()


func test_the_hud_keys_and_the_page_texts_in_both_languages() -> void:
	await _continue_with(_state(10, {}, {}, [&"piercing_step", &"guard_response"], [&"piercing_step", &"guard_response"]))
	assert_eq(_hud().technique_key(0), "O")
	assert_eq(_hud().technique_key(1), "P")
	game.call(&"_set_active_joypad", 0)
	await wait_physics_frames(1)
	assert_eq(_hud().technique_key(0), "R1", "the gamepad's own buttons")
	assert_eq(_hud().technique_key(1), "R2", "a trigger is named too")
	game.call(&"_set_keyboard_active")
	for locale in ["pt_BR", "en"]:
		TranslationServer.set_locale(locale)
		game.open_equipment()
		_menu().page = HeroMenu.Page.SKILLS
		for r in HeroMenu.SKILL_ROWS.size():
			for i in (HeroMenu.SKILL_ROWS[r] as Array).size():
				_menu()._skill_row = r
				_menu()._skill_index = i
				_menu()._refresh()
				await wait_process_frames(1)
				for path in ["Points", "Info/Name", "Info/Kind", "Info/Needs", "Info/State"]:
					_assert_fits("Root/Skills/" + path, 1, locale)
				_assert_fits("Root/Skills/Info/Weapons", 2, locale)
				_assert_fits("Root/Skills/Info/Description", 3, locale)
				_assert_fits("Root/Skills/Info/Effect", 3, locale)
				for s in Skills.ACTIVE_SLOTS + 1:
					_assert_fits("Root/Skills/Slots/Slot%d/Name" % s, 1, locale)
				_assert_fits("Root/Hint", 1, locale)
		_menu().close()
	TranslationServer.set_locale("pt_BR")


func _assert_fits(path: String, lines: int, what: String) -> void:
	var label := _menu().get_node(path) as Label
	if label.text.is_empty():
		return
	assert_lte(label.get_line_count(), lines, "%s %s: %s" % [what, path, label.text])
	if lines == 1:
		assert_lte(label.get_minimum_size().x, label.size.x + 1.0, "%s %s fits across: %s" % [what, path, label.text])
