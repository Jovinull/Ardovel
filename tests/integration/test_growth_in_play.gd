extends "res://tests/integration/adventure_case.gd"
## Milestone 7.3, played on the real game scene: experience for a creature of the area beaten with
## real swings (not for a blow, not twice, not for one left alive or unloaded, again when the area
## brings it back), the warden counted once, deeds and first arrivals, a level reached with the
## notice and the glint while the hero keeps moving, points spent in the status page with real keys
## and a simulated gamepad (cancelled, refused, confirmed), what the points change in play and that
## the page shows exactly what the hero uses, growth kept through saving, Continue, travel and a
## fall, an older save credited once, and the texts in both languages.

const FIXTURES := "res://tests/fixtures/saves"


func after_each() -> void:
	super.after_each()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"interact"]:
		Input.action_release(action)


func _state(area: StringName, entry: StringName, experience: int = 0, flags: Array[StringName] = []) -> Adventure:
	var state := Adventure.new(area, entry)
	for flag in [&"heard_of_shrine", &"equipment_seen"] + flags:
		state.set_flag(flag)
	state.experience = experience
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	return state


func _continue_with(state: Adventure) -> void:
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


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


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


func _musgoricos() -> Array[Musgorico]:
	var found: Array[Musgorico] = []
	for node in game.level.find_children("*", "", true, false):
		if node is Musgorico and not (node as Musgorico).health.is_dead():
			found.append(node)
	return found


## One real swing at `musgo` from its left (the hero stands there, facing it).
func _swing_at(musgo: Musgorico) -> void:
	_player().global_position = musgo.global_position + Vector2(-16, 0)
	_player().reset_physics_interpolation()
	_player().face(Vector2.RIGHT)
	await wait_physics_frames(1)
	Input.action_press(&"attack")
	await wait_physics_frames(2)
	Input.action_release(&"attack")
	await _wait_until(func() -> bool: return _player().state != Player.State.ATTACK, 2.0)
	await wait_physics_frames(2)


## Swings at `musgo` until it falls; how many swings landed.
func _beat(musgo: Musgorico) -> int:
	var defeated := [false]
	musgo.defeated.connect(func() -> void: defeated[0] = true)
	var swings := 0
	var health := musgo.health
	while not health.is_dead() and swings < 12:
		var before := health.current
		await _swing_at(musgo)
		if health.current < before:
			swings += 1
		await _wait_until(func() -> bool: return not health.is_invulnerable(), 1.0)
	await _wait_until(func() -> bool: return defeated[0], 3.0)
	assert_true(defeated[0], "the musgorico was beaten")
	return swings


func _hud() -> Hud:
	return game.get_node(^"HUD")


func _menu() -> HeroMenu:
	return game.hero_menu()


# ---------------------------------------------------------------- experience

func test_a_creature_beaten_with_real_swings_gives_its_experience_once() -> void:
	await _continue_with(_state(&"village", &"north"))
	assert_eq(game.adventure.experience, 0, "continuing at home gives nothing")
	game.travel(&"forest", &"south")
	await _settle()
	var arrived := game.adventure.experience
	assert_eq(arrived, HeroGrowth.ARRIVALS[&"forest"], "the forest reached for the first time")
	_player().health.max_health = 99
	_player().health.restore_full()
	var musgo := _musgoricos()[0]
	await _swing_at(musgo)
	assert_lt(musgo.health.current, musgo.health.max_health, "a blow landed")
	assert_eq(game.adventure.experience, arrived, "nothing for a blow")
	await _beat(musgo)
	assert_eq(game.adventure.experience, arrived + 4, "four for a Musgorico")
	assert_true(_hud().is_experience_bar_visible(), "the bar shows for a moment")
	await wait_physics_frames(90)
	assert_eq(game.adventure.experience, arrived + 4, "never twice")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.experience, arrived + 4, "not again on Continue")


func test_a_creature_left_alive_gives_nothing_and_one_brought_back_counts_again() -> void:
	var state := _state(&"forest", &"south")
	state.give_reward(&"arrived_forest", HeroGrowth.ARRIVALS[&"forest"])  # reached before
	await _continue_with(state)
	_player().health.max_health = 99
	_player().health.restore_full()
	var start := game.adventure.experience
	var count := _musgoricos().size()
	await _swing_at(_musgoricos()[0])
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(game.adventure.experience, start, "a creature hurt and left behind gives nothing")
	game.travel(&"forest", &"south")
	await _settle()
	assert_eq(_musgoricos().size(), count, "the forest's creatures are back")
	assert_eq(game.adventure.experience, start, "and coming back is not a new arrival")
	await _beat(_musgoricos()[0])
	assert_eq(game.adventure.experience, start + 4)
	game.travel(&"village", &"north")
	await _settle()
	game.travel(&"forest", &"south")
	await _settle()
	await _beat(_musgoricos()[0])
	assert_eq(game.adventure.experience, start + 8, "one that came back counts again")


func test_the_warden_counts_once_as_a_deed() -> void:
	var state := _state(&"ruin", &"gate", 0, [&"forest_shrine_awakened", &"ruin_lights_solved",
			&"ruin_roots_solved", &"ruin_heart_awakened"])
	for area: StringName in [&"forest", &"ruin"]:
		state.give_reward(StringName(HeroGrowth.ARRIVAL_PREFIX + String(area)), HeroGrowth.ARRIVALS[area])  # walked before
	await _continue_with(state)
	var before := game.adventure.experience
	var warden: RootWarden = null
	for node in game.level.find_children("*", "", true, false):
		if node is RootWarden:
			warden = node
	assert_not_null(warden)
	var defeated := [false]
	warden.defeated.connect(func() -> void: defeated[0] = true)
	warden.health.take_damage(99)
	await _wait_until(func() -> bool: return defeated[0], 6.0)
	await wait_physics_frames(3)
	assert_true(game.adventure.has_flag(&"ruin_warden_defeated"))
	assert_eq(game.adventure.experience, before + 60, "sixty, once")
	assert_true(game.adventure.has_reward(&"warden_defeated"))
	game.travel(&"forest", &"ruin")
	await _settle()
	game.travel(&"ruin", &"gate")
	await _settle()
	assert_eq(game.adventure.experience, before + 60, "not again on coming back")
	await _fall_and_retry()
	assert_eq(game.adventure.experience, before + 60, "nor after a fall")


func test_deeds_already_done_are_counted_when_the_game_starts_and_never_again() -> void:
	await _continue_with(_state(&"village", &"north", 0, [&"forest_shrine_awakened", &"village_hens_settled"]))
	assert_eq(game.adventure.experience, 25, "the shrine (10) and the hens (15)")
	game.adventure.set_flag(&"ruin_heart_awakened")
	await wait_physics_frames(2)
	assert_eq(game.adventure.experience, 65, "a deed done in play is counted at once")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.experience, 65)


# ---------------------------------------------------------------- levels

func test_a_level_reached_shows_and_the_hero_keeps_going() -> void:
	await _continue_with(_state(&"forest", &"south", HeroGrowth.experience_for(2) - 4))
	_player().health.max_health = 99
	_player().health.restore_full()
	assert_eq(HeroGrowth.level(game.adventure), 1, "four short of level 2")
	await _beat(_musgoricos()[0])
	assert_eq(HeroGrowth.level(game.adventure), 2)
	assert_true(_hud().is_level_notice_visible(), "the notice")
	assert_string_contains(_hud().level_notice_text(), "2")
	assert_not_null(_player().get_node_or_null(^"LevelGlint"), "the glint around the hero")
	assert_true(_hud().is_points_mark_visible(), "a point waits")
	var from := _player().global_position
	Input.action_press(&"move_left")
	await wait_physics_frames(12)
	Input.action_release(&"move_left")
	assert_lt(_player().global_position.x, from.x - 4.0, "the hero moves while it plays")
	assert_true(await _wait_until(func() -> bool: return not _hud().is_level_notice_visible(), 5.0), "and it goes")
	await wait_physics_frames(60)
	assert_null(_player().get_node_or_null(^"LevelGlint"), "the glint is gone")


# ---------------------------------------------------------------- points

func _open_status() -> void:
	game.open_equipment()
	await _press(&"menu_next")
	await _press(&"menu_next")
	assert_eq(_menu().page, HeroMenu.Page.STATUS)


func test_points_are_spent_in_the_status_page_with_real_keys() -> void:
	await _continue_with(_state(&"village", &"north", HeroGrowth.experience_for(4)))
	var health_before := _player().health.current
	var max_before := _player().health.max_health
	await _open_status()
	await _press(&"interact")
	assert_true(_menu().is_distributing())
	await _press(&"move_down")
	assert_eq(_menu().selected_attribute(), HeroGrowth.STRENGTH)
	await _press(&"move_right")
	await _press(&"move_right")
	await _press(&"move_left")
	assert_eq(_menu().plan(), {HeroGrowth.STRENGTH: 1})
	await _press(&"menu_next")
	assert_eq(_menu().page, HeroMenu.Page.STATUS, "the page stays while spending")
	await _press(&"ui_cancel")
	assert_false(_menu().is_distributing())
	assert_eq(HeroGrowth.points_invested(game.adventure), 0, "cancelled: nothing spent")
	assert_eq(HeroGrowth.points_free(game.adventure), 3, "and nothing lost")
	await _press(&"interact")
	await _press(&"interact")
	assert_true(_menu().is_distributing(), "confirming nothing is refused")
	for i in 4:
		await _press(&"move_right")
	assert_eq(_menu().plan(), {HeroGrowth.VIGOR: 3}, "never more than the points free")
	var shown := (_menu().get_node(^"Root/Status/Values/Value0") as Label).text
	assert_eq(shown, _menu()._hearts(max_before + 3), "the preview shows the hearts to come")
	assert_eq(_player().health.max_health, max_before, "only a preview")
	await _press(&"interact")
	assert_false(_menu().is_distributing())
	assert_eq(game.adventure.attribute(HeroGrowth.VIGOR), 3)
	assert_eq(_player().health.max_health, max_before + 3, "in play at once")
	assert_eq(_player().health.current, health_before, "without healing")
	assert_false(_hud().is_points_mark_visible())
	_menu().close()
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.attribute(HeroGrowth.VIGOR), 3, "kept")
	assert_eq(HeroGrowth.points_free(game.adventure), 0, "not earned twice")
	assert_eq(_player().health.max_health, max_before + 3)


func test_closing_the_menu_while_spending_loses_nothing() -> void:
	await _continue_with(_state(&"village", &"north", HeroGrowth.experience_for(3)))
	await _open_status()
	await _press(&"interact")
	await _press(&"move_right")
	await _press(&"equipment")
	assert_false(game.is_equipment_open())
	assert_eq(HeroGrowth.points_free(game.adventure), 2)
	assert_eq(HeroGrowth.points_invested(game.adventure), 0)
	await _open_status()
	assert_false(_menu().is_distributing(), "a fresh start")


func test_points_are_spent_with_a_gamepad() -> void:
	await _continue_with(_state(&"village", &"north", HeroGrowth.experience_for(3)))
	game.open_equipment()
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(_menu().page, HeroMenu.Page.STATUS)
	await _button(JOY_BUTTON_A)
	await _button(JOY_BUTTON_DPAD_UP)
	assert_eq(_menu().selected_attribute(), HeroGrowth.BREATH, "up from the first goes round to the last")
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_A)
	assert_eq(game.adventure.attribute(HeroGrowth.BREATH), 2)
	assert_eq(_player().stamina.maximum, 112.0, "breath held grows at once")
	await _button(JOY_BUTTON_B)
	assert_false(game.is_equipment_open())


func test_what_points_change_in_play_and_the_page_shows_what_is_used() -> void:
	var state := _state(&"forest", &"south", HeroGrowth.experience_for(HeroGrowth.MAX_LEVEL))
	HeroGrowth.invest(state, {HeroGrowth.STRENGTH: 5, HeroGrowth.ENDURANCE: 4, HeroGrowth.BREATH: 3, HeroGrowth.VIGOR: 2})
	await _continue_with(state)
	var profile := game.hero_profile()
	assert_almost_eq(_player().weapon_attack().power, 1.5, 0.0001, "strength reaches the swing")
	assert_eq(_player().health.defense_percent, 12.0, "endurance reaches the defence")
	assert_eq(_player().poise_percent, 16.0)
	assert_eq(_player().stamina.maximum, 118.0, "breath reaches the breath held")
	assert_almost_eq(_player().stamina.regen_factor, 1.15, 0.0001, "and its pace")
	assert_eq(_player().health.max_health, 14, "vigour reaches the hearts")
	game.open_equipment()
	_menu().page = HeroMenu.Page.STATUS
	_menu()._refresh()
	var values := _menu().get_node(^"Root/Status/Values")
	assert_eq((values.get_node(^"Value0") as Label).text, _menu()._hearts(_player().health.max_health))
	assert_eq((values.get_node(^"Value2") as Label).text, "%d%%" % roundi(_player().health.defense_percent))
	assert_eq((values.get_node(^"Value4") as Label).text, str(roundi(_player().stamina.maximum)))
	assert_eq((values.get_node(^"Value7") as Label).text, _menu().blow_text(profile.blow()))
	_menu().close()
	_player().health.max_health = 99
	_player().health.restore_full()
	var swings := await _beat(_musgoricos()[0])
	assert_eq(swings, 2, "strength 5: a Musgorico falls in two sword blows, not three")


func test_growth_stays_through_travel_and_a_fall() -> void:
	var state := _state(&"forest", &"south", 200)
	HeroGrowth.invest(state, {HeroGrowth.VIGOR: 2, HeroGrowth.STRENGTH: 1})
	await _continue_with(state)
	var experience := game.adventure.experience
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(game.adventure.experience, experience)
	assert_eq(_player().health.max_health, 14)
	await _fall_and_retry()
	assert_eq(game.adventure.experience, experience)
	assert_eq(game.adventure.attribute(HeroGrowth.VIGOR), 2)
	assert_eq(_player().health.max_health, 14, "after a fall")
	assert_almost_eq(_player().weapon_attack().power, 1.1, 0.0001)


func test_a_save_from_7_2_is_credited_once_and_keeps_everything() -> void:
	var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join("v5_chest_kept.json")))
	file.close()
	assert_true(game.continue_saved())
	await _settle()
	var expected := 0
	for id in HeroGrowth.DEEDS:
		if game.adventure.has_flag(HeroGrowth.DEEDS[id][0]):
			expected += HeroGrowth.DEEDS[id][1]
	assert_eq(game.adventure.experience, expected, "every deed its flags prove, once")
	assert_eq(game.adventure.stored(&"corn_bread"), 3, "the chest kept")
	assert_eq(game.adventure.equipped(ItemCatalog.MAIN_HAND), &"quarry_maul")
	assert_true(_hud().is_points_mark_visible(), "points wait to be spent")
	assert_eq(game.save_now(), OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_slot.path))
	assert_eq(int(data["version"]), 6)
	assert_eq(int(data["experience"]), expected)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.experience, expected, "not credited twice")
	assert_true(FileAccess.file_exists(game.save_slot.path + ".bak"), "the backup is kept")


func test_growth_speaks_both_languages_and_fits() -> void:
	var keys := ["HUD_LEVEL", "HUD_XP_GAIN", "HUD_LEVEL_UP", "HUD_POINTS_ONE", "HUD_POINTS", "MENU_LEVEL", "MENU_EXPERIENCE",
			"MENU_LEVEL_MAX", "MENU_POINTS", "MENU_ATTRIBUTES", "MENU_VALUES", "MENU_PREVIEW", "MENU_NO_POINTS",
			"MENU_PLAN_EMPTY", "MENU_POINTS_SPENT", "MENU_HINT_CONFIRM", "MENU_HINT_POINT", "MENU_HINT_SPEND", "ATTR_VIGOR",
			"ATTR_STRENGTH", "ATTR_ENDURANCE", "ATTR_BREATH", "ATTR_VIGOR_EFFECT", "ATTR_STRENGTH_EFFECT",
			"ATTR_ENDURANCE_EFFECT", "ATTR_BREATH_EFFECT", "STAT_BREATH", "STAT_BREATH_REGEN"]
	var state := _state(&"village", &"north", HeroGrowth.experience_for(9) + 40)
	HeroGrowth.invest(state, {HeroGrowth.VIGOR: 3})
	await _continue_with(state)
	for locale in ["pt_BR", "en"]:
		TranslationServer.set_locale(locale)
		for key: String in keys:
			assert_ne(tr(key), key, "%s in %s" % [key, locale])
		game.open_equipment()
		_menu().page = HeroMenu.Page.STATUS
		_menu()._distributing = true
		_menu()._plan = {HeroGrowth.STRENGTH: 2}
		_menu()._refresh()
		await wait_process_frames(1)
		for path in ["Growth/Level", "Growth/Experience", "Growth/Points", "Attributes/Title", "Values/Title"]:
			_assert_fits("Root/Status/" + path, locale)
		for r in HeroGrowth.ATTRIBUTES.size():
			for part in ["Name", "Effect"]:
				_assert_fits("Root/Status/Attributes/Row%d/%s" % [r, part], locale)
			var name := _menu().get_node("Root/Status/Attributes/Row%d/Name" % r) as Label
			var value := _menu().get_node("Root/Status/Attributes/Row%d/Value" % r) as Label
			assert_lte(name.get_minimum_size().x + value.get_minimum_size().x + 2, value.position.x + value.size.x - name.position.x,
					"%s attribute %d: %s %s" % [locale, r, name.text, value.text])
		for r in HeroMenu.VALUE_ROWS * 2:
			var name := _menu().get_node("Root/Status/Values/Name%d" % r) as Label
			var value := _menu().get_node("Root/Status/Values/Value%d" % r) as Label
			assert_lte(name.get_minimum_size().x + value.get_minimum_size().x + 3, name.size.x,
					"%s value %d: %s %s" % [locale, r, name.text, value.text])
		_assert_fits("Root/Hint", locale)
		_menu().close()
		_hud().show_level_up(10, 3)
		await wait_process_frames(1)
		var level_box := _hud().get_node(^"Frame/LevelUp") as Control
		for part in ["Title", "Points"]:
			var label := level_box.get_node(part) as Label
			assert_lte(label.get_minimum_size().x, label.size.x + 1.0, "%s level notice: %s" % [locale, label.text])
	TranslationServer.set_locale("pt_BR")


func _assert_fits(path: String, what: String) -> void:
	var label := _menu().get_node(path) as Label
	if label.text.is_empty():
		return
	assert_lte(label.get_line_count(), 1, "%s %s: %s" % [what, path, label.text])
	assert_lte(label.get_minimum_size().x, label.size.x + 1.0, "%s %s fits across: %s" % [what, path, label.text])
