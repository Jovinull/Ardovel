extends "res://tests/integration/adventure_case.gd"
## The arsenal and the hero menu, played: pickups found on foot (lying, in a chest, refused by a
## full bag and taken later), the menu's three pages with real key events and simulated gamepad
## buttons, choosing a slot and comparing, taking off, eating, scrolling and categories, weapons
## changing the swing and its frames, light and heavy kits moving differently, defence and poise
## in real hits, what stays through Continue, a fall and travel, saves from every format, unknown
## items, the backup, the menu never opening over something else, and its texts in both languages.

const FIXTURES := "res://tests/fixtures/saves"
const MusgoricoScene := preload("res://actors/musgorico/musgorico.tscn")
const MenuScene := preload("res://ui/hero_menu/hero_menu.tscn")
const GLOVES := &"crew_gloves"
const SWORD := &"wayfarer_sword"
const AFTER_TOWN: Array[StringName] = [&"forest_shrine_awakened", &"heard_of_shrine", &"far_bank_bridge_tied",
		&"far_bank_iara_met", &"road_work_started", &"road_bar_lent", &"road_trunk_loosened", &"road_ditch_cleared",
		&"road_iara_heard_cleared", &"road_clearing_progressed", &"spring_iara_ready", &"spring_plan_heard",
		&"spring_stone_shifted", &"spring_iara_ahead", &"spring_iara_left", &"blank_witch_met", &"blank_view_seen",
		&"blank_map_drawn", &"blank_witch_gone", &"town_iara_met", &"town_rufina_heard", &"town_rufina_faced",
		&"town_iara_dealt", &"town_notice_down"]
const SLOPE_BOUNDS := Rect2i(0, 0, 416, 224)
## Standing just west of the crew gloves, by the shelter.
const BY_THE_GLOVES := Vector2(306, 196)
## Standing just west of the crew's chest on the slope.
const BY_THE_CHEST := Vector2(362, 170)
## Every equippable item, and how many of each food and material the world holds.
const STACKS := {&"corn_bread": 3, &"wild_honey": 3, &"herb_tea": 2, &"white_stone_chip": 5, &"pine_resin": 4,
		&"root_fiber": 3, &"cardosa_seed": 3, &"old_bronze": 2}
const HEAVY := {&"main_hand": &"quarry_maul", &"off_hand": &"crew_board_shield", &"head": &"quarry_helm",
		&"torso": &"quarry_breastplate", &"hands": &"quarry_gauntlets", &"legs": &"quarry_greaves"}
const LIGHT := {&"main_hand": &"crew_machete", &"off_hand": &"bark_shield", &"head": &"straw_hat",
		&"torso": &"padded_doublet", &"hands": &"moss_wraps", &"legs": &"rope_sandals"}


func after_each() -> void:
	super.after_each()
	_steer(Vector2.ZERO)


func _state(area: StringName, entry: StringName, items: Dictionary = {}, worn: Dictionary = {}) -> Adventure:
	var state := Adventure.new(area, entry)
	for flag in AFTER_TOWN:
		state.set_flag(flag)
	for id: StringName in items:
		state.add_item(id, items[id])
	for slot: StringName in worn:
		assert_true(state.equip(slot, worn[slot]), "%s in %s" % [worn[slot], slot])
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	return state


func _continue_with(state: Adventure) -> void:
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


func _everything() -> Dictionary:
	var items := {}
	for id: StringName in ItemCatalog.ITEMS:
		if id != SWORD:
			items[id] = STACKS.get(id, 1)
	return items


func _continue_from_fixture(file_name: String) -> void:
	var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
	file.close()
	assert_true(game.continue_saved(), file_name)
	await _settle()


func _menu() -> HeroMenu:
	return game.hero_menu()


func _steer(direction: Vector2) -> void:
	var keys := {&"move_left": direction.x < -0.3, &"move_right": direction.x > 0.3,
			&"move_up": direction.y < -0.3, &"move_down": direction.y > 0.3}
	for action: StringName in keys:
		if keys[action]:
			Input.action_press(action)
		else:
			Input.action_release(action)


func _tap(action: StringName) -> void:
	Input.action_press(action)
	await wait_physics_frames(2)
	Input.action_release(action)
	await wait_physics_frames(2)


## A key press as the keyboard sends it: an input event (parsed events arrive on the next pass of
## the main loop, so this waits for process frames).
func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_process_frames(2)
		await wait_physics_frames(1)


## A gamepad button as a controller sends it.
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


func _walk_to(target: Vector2) -> bool:
	var body: CollisionShape2D = _player().get_node(^"Collision")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.collision_mask = 1
	query.exclude = [_player().get_rid()]
	var space := _player().get_world_2d().direct_space_state
	var from := Vector2i(_player().global_position.round())
	var came := {from: from}
	var frontier: Array[Vector2i] = [from]
	var index := 0
	var reached := Vector2i(-1, -1)
	while index < frontier.size():
		var at := frontier[index]
		index += 1
		if Vector2(at).distance_to(target) <= 4.0:
			reached = at
			break
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + offset * 4
			if not SLOPE_BOUNDS.has_point(next) or came.has(next):
				continue
			query.transform = Transform2D(0.0, Vector2(next) + body.position)
			if space.intersect_shape(query, 1).is_empty():
				came[next] = at
				frontier.append(next)
	if reached == Vector2i(-1, -1):
		return false
	var points: Array[Vector2] = [target]
	var at := reached
	while at != from:
		points.push_front(Vector2(at))
		at = came[at]
	for point in points:
		var left := 4.0
		while _player().global_position.distance_to(point) > 2.0 and left > 0.0:
			_steer((point - _player().global_position).normalized())
			await wait_physics_frames(1)
			left -= get_physics_process_delta_time()
		if left <= 0.0:
			_steer(Vector2.ZERO)
			return false
	_steer(Vector2.ZERO)
	await wait_physics_frames(2)
	return true


## Moves the equipment page's cursor to `slot` with the arrow keys.
func _to_slot(slot: StringName) -> void:
	for i in 12:
		if _menu().selected_slot() == slot:
			return
		var row := HeroMenu.GROUPS.map(func(g: Array) -> bool: return (g[1] as Array).has(slot)).find(true)
		var current := HeroMenu.GROUPS.map(func(g: Array) -> bool: return (g[1] as Array).has(_menu().selected_slot())).find(true)
		await _press(&"move_down" if row > current else (&"move_up" if row < current else &"move_right"))
	assert_eq(_menu().selected_slot(), slot)


func _to_choice(id: StringName) -> void:
	for i in 12:
		if _menu().selected_choice() == id:
			return
		await _press(&"move_down")
	assert_eq(_menu().selected_choice(), id)


func _to_item(id: StringName) -> void:
	var index := _menu().shown_items().find(id)
	assert_ne(index, -1, "%s is shown" % id)
	for i in index / HeroMenu.GRID_COLUMNS:
		await _press(&"move_down")
	for i in index % HeroMenu.GRID_COLUMNS:
		await _press(&"move_right")
	assert_eq(_menu().selected_item(), id)


func test_items_lying_and_in_chests_are_taken_once_on_foot() -> void:
	await _continue_with(_state(&"road_slope", &"trail"))
	var hud: Hud = game.get_node(^"HUD")
	assert_false(hud.is_guidance_visible(), "no hint for the sword alone")
	assert_true(await _walk_to(BY_THE_GLOVES), "to the gloves")
	await _tap(&"move_right")
	assert_string_contains(await _press_interact(), tr("ITEM_CREW_GLOVES"))
	assert_eq(game.adventure.count(GLOVES), 1)
	assert_true(hud.is_guidance_visible(), "a hint says how to open the menu")
	assert_true(await _walk_to(BY_THE_CHEST), "to the crew's chest")
	await _tap(&"move_right")
	var said := await _press_interact()
	assert_string_contains(said, tr("PICKUP_CREW_CHEST"), "what the chest is")
	assert_string_contains(said, tr("ITEM_CREW_VEST"), "and what was in it")
	assert_eq(await _press_interact(), "", "an open chest has nothing more")
	assert_eq(game.adventure.count(&"crew_vest"), 1)
	game.travel(&"road_slope", &"trail")
	await _settle()
	assert_null(game.level.get_node_or_null(^"Entities/CrewGloves"), "the gloves are gone for good")
	var chest := game.level.get_node(^"Entities/Found_CrewVest") as ItemPickup
	assert_true(chest.is_taken(), "the chest stays open")
	assert_eq((chest.get_node(^"Sprite") as Sprite2D).frame, 1)


func test_a_full_bag_leaves_the_pickup_where_it_is() -> void:
	var state := _state(&"road_slope", &"trail", {&"straw_hat": Bag.CAPACITY})
	await _continue_with(state)
	assert_eq(Bag.free_spaces(game.adventure), 0)
	assert_true(await _walk_to(BY_THE_GLOVES))
	await _tap(&"move_right")
	assert_eq(await _press_interact(), "PICKUP_BAG_FULL")
	assert_false(game.adventure.has_item(GLOVES), "not taken")
	assert_false(game.adventure.has_flag(&"found_slope_crew_gloves"), "nor marked")
	assert_not_null(game.level.get_node_or_null(^"Entities/CrewGloves"), "still lying there")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_not_null(game.level.get_node_or_null(^"Entities/CrewGloves"), "and after Continue")
	await _press(&"equipment")
	await _to_slot(ItemCatalog.HEAD)
	await _press(&"interact")
	await _to_choice(&"straw_hat")
	await _press(&"interact")
	await _press(&"equipment")
	assert_eq(Bag.free_spaces(game.adventure), 1, "wearing the hat freed a space")
	assert_true(await _walk_to(BY_THE_GLOVES))
	await _tap(&"move_right")
	assert_string_contains(await _press_interact(), tr("ITEM_CREW_GLOVES"), "now they fit")
	assert_eq(game.adventure.count(GLOVES), 1)


func test_the_menu_pages_with_real_keys_and_closes_without_the_pause() -> void:
	await _continue_with(_state(&"road_slope", &"trail", {GLOVES: 1}))
	await _press(&"equipment")
	assert_true(_menu().is_open())
	await wait_physics_frames(2)
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_DISABLED, "the area holds still")
	assert_eq(_menu().page, HeroMenu.Page.EQUIPMENT)
	await _press(&"menu_next")
	assert_eq(_menu().page, HeroMenu.Page.INVENTORY)
	await _press(&"menu_next")
	assert_eq(_menu().page, HeroMenu.Page.STATUS)
	await _press(&"menu_next")
	assert_eq(_menu().page, HeroMenu.Page.EQUIPMENT, "round again")
	await _press(&"menu_prev")
	assert_eq(_menu().page, HeroMenu.Page.STATUS)
	await _press(&"attack")
	assert_true(_menu().is_open(), "the sword key does nothing here")
	for closing: StringName in [&"pause", &"ui_cancel", &"equipment"]:
		if not _menu().is_open():
			await _press(&"equipment")
		await _press(closing)
		assert_false(_menu().is_open(), "%s closes it" % closing)
		assert_false(get_tree().paused, "and no pause menu opens (%s)" % closing)
	await wait_physics_frames(2)
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_INHERIT, "the area runs again")
	assert_eq(_player().state, Player.State.MOVE, "and the hero did not swing")
	await _press(&"pause")
	assert_true(get_tree().paused, "the pause key works as usual afterwards")
	await _press(&"equipment")
	assert_false(_menu().is_open(), "the menu does not open over the pause")
	await _press(&"pause")


func test_a_gamepad_opens_pages_and_categories() -> void:
	await _continue_with(_state(&"road_slope", &"trail", _everything()))
	await _button(JOY_BUTTON_BACK)
	assert_true(_menu().is_open(), "Back opens the menu")
	await _button(JOY_BUTTON_RIGHT_SHOULDER)
	assert_eq(_menu().page, HeroMenu.Page.INVENTORY, "RB turns the page")
	await _trigger(JOY_AXIS_TRIGGER_RIGHT)
	assert_eq(_menu().tab(), 1, "RT changes the category")
	await _trigger(JOY_AXIS_TRIGGER_LEFT)
	assert_eq(_menu().tab(), 0)
	await _button(JOY_BUTTON_Y)
	assert_eq(_menu().sort_mode(), HeroMenu.Sort.NAME, "Y changes the order")
	await _button(JOY_BUTTON_LEFT_SHOULDER)
	assert_eq(_menu().page, HeroMenu.Page.EQUIPMENT)
	await _button(JOY_BUTTON_B)
	assert_false(_menu().is_open(), "B closes it")


func test_a_slot_lists_what_fits_compares_and_equips() -> void:
	await _continue_with(_state(&"road_slope", &"trail", {&"straw_hat": 1, &"quarry_helm": 1, &"crew_vest": 1}))
	await _press(&"equipment")
	await _to_slot(ItemCatalog.HEAD)
	await _press(&"interact")
	assert_true(_menu().is_choosing())
	await _to_choice(&"quarry_helm")
	var lines := _menu().compare_lines(game.hero_profile(),
			HeroLoadout.profile_if(game.adventure, game.base_health(), ItemCatalog.HEAD, &"quarry_helm"))
	var text := " ".join(lines.map(func(l: Array) -> String: return l[0]))
	assert_string_contains(text, "0% > 5% (+)", "defence before and after")
	var summary := _menu().get_node(^"Root/Equipment/Summary/Line0") as Label
	assert_eq(summary.text, lines[0][0], "and on screen")
	assert_eq(game.adventure.equipped(ItemCatalog.HEAD), &"", "nothing changed by looking")
	await _press(&"interact")
	assert_false(_menu().is_choosing())
	assert_eq(game.adventure.equipped(ItemCatalog.HEAD), &"quarry_helm")
	assert_eq(_player().health.defense_percent, 5.0, "the hero's defence follows at once")
	await _press(&"interact")
	await _to_choice(&"")
	await _press(&"interact")
	assert_eq(game.adventure.equipped(ItemCatalog.HEAD), &"", "taken off")
	assert_true(game.adventure.has_item(&"quarry_helm"), "and kept")
	await _to_slot(ItemCatalog.MAIN_HAND)
	await _press(&"interact")
	assert_eq(_menu().selected_choice(), SWORD, "the weapon hand offers no 'take off'")
	await _press(&"ui_cancel")
	assert_false(_menu().is_choosing(), "Esc goes back one level")
	assert_true(_menu().is_open())


func test_the_inventory_scrolls_sorts_and_reaches_its_last_item() -> void:
	await _continue_with(_state(&"road_slope", &"trail", _everything()))
	await _press(&"equipment")
	await _press(&"menu_next")
	var shown := _menu().shown_items()
	assert_eq(shown.size(), ItemCatalog.ITEMS.size(), "everything the hero has")
	assert_gt(ceili(float(shown.size()) / HeroMenu.GRID_COLUMNS), HeroMenu.GRID_ROWS, "more than one screen")
	var last := shown[shown.size() - 1]
	await _to_item(last)
	var cell := _menu().get_node(^"Root/Inventory/Grid") as Control
	var chosen := 0
	for c in cell.get_children():
		if (c.get_node(^"Chosen") as CanvasItem).visible:
			chosen += 1
	assert_eq(chosen, 1, "the chosen cell is on screen")
	assert_eq((_menu().get_node(^"Root/Inventory/Info/Name") as Label).text, tr(ItemCatalog.find(last).name_key))
	for t in HeroMenu.TABS.size():
		await _press(&"category_next")
		var categories: Array = HeroMenu.TABS[_menu().tab()][1]
		for id in _menu().shown_items():
			assert_true(categories.is_empty() or categories.has(ItemCatalog.find(id).category))
		assert_true(_menu().selected_item() == &"" or _menu().shown_items().has(_menu().selected_item()), "focus stays valid")
	var found := _menu().shown_items()
	await _press(&"menu_sort")
	var by_name := _menu().shown_items()
	assert_eq(by_name.size(), found.size())
	for i in by_name.size() - 1:
		assert_lte(tr(ItemCatalog.find(by_name[i]).name_key), tr(ItemCatalog.find(by_name[i + 1]).name_key))
	await _press(&"menu_sort")
	await _press(&"menu_sort")
	var by_weight := _menu().shown_items()
	assert_gte(ItemCatalog.find(by_weight[0]).weight, ItemCatalog.find(by_weight[by_weight.size() - 1]).weight)


func test_food_is_eaten_from_the_inventory() -> void:
	await _continue_with(_state(&"road_slope", &"trail", {&"corn_bread": 2}))
	_player().health.take_damage(6)
	var health := _player().health.current
	await _press(&"equipment")
	await _press(&"menu_next")
	for i in 4:
		await _press(&"category_next")
	assert_eq(_menu().shown_items(), [&"corn_bread"] as Array[StringName])
	await _press(&"interact")
	assert_eq(_player().health.current, health + 4, "a heart back")
	assert_eq(game.adventure.count(&"corn_bread"), 1, "one eaten")
	_player().health.restore_full()
	await _press(&"interact")
	assert_eq(game.adventure.count(&"corn_bread"), 1, "not wasted at full health")
	assert_eq(_menu().notice(), "MENU_FULL_HEALTH")


func test_a_weapon_changes_the_swing_its_damage_and_its_frames() -> void:
	await _continue_with(_state(&"road_slope", &"trail", {&"quarry_maul": 1}))
	var sword_frames := _player().weapon_sheet()
	await _press(&"equipment")
	await _press(&"menu_next")
	await _to_item(&"quarry_maul")
	await _press(&"interact")
	await _press(&"equipment")
	assert_eq(game.adventure.equipped(ItemCatalog.MAIN_HAND), &"quarry_maul")
	assert_eq(_player().weapon_sheet(), ItemCatalog.find(&"quarry_maul").attack_sheet, "the maul is drawn in hand")
	assert_ne(_player().weapon_sheet(), sword_frames)
	var frames := (_player().get_node(^"Sprite") as AnimatedSprite2D).sprite_frames
	assert_eq((frames.get_frame_texture(&"attack_down", 1) as AtlasTexture).atlas, ItemCatalog.find(&"quarry_maul").attack_sheet)
	_player().global_position = Vector2(280, 128)
	await wait_physics_frames(3)
	var musgo: Musgorico = MusgoricoScene.instantiate()
	musgo.rng_seed = 3
	musgo.position = _player().global_position + Vector2(18, 0)
	game.level.get_node(^"Entities").add_child(musgo)
	await wait_physics_frames(2)
	_player().facing = Vector2.RIGHT
	var started := Time.get_ticks_msec()
	await _tap(&"attack")
	await _wait_until(func() -> bool: return _player().state == Player.State.MOVE, 2.0)
	assert_eq(musgo.get_node(^"Health").get("current"), 1, "two quarters off a Musgorico")
	assert_almost_eq(_player().weapon_attack().duration(), 0.53, 0.001, "and a slow swing")


func test_light_and_heavy_kits_move_differently_and_take_hits_differently() -> void:
	var speeds := {}
	for kit: Dictionary in [{}, LIGHT, HEAVY]:
		var items := {}
		for slot: StringName in kit:
			items[kit[slot]] = 1
		await _continue_with(_state(&"waystop", &"east", items, kit))
		_player().global_position = Vector2(380, 144)
		await wait_physics_frames(3)
		_steer(Vector2.LEFT)
		await wait_physics_frames(40)
		var top := _player().velocity.length()
		_steer(Vector2.ZERO)
		assert_almost_eq(top, _player().top_speed(), 0.5, "walking at the kit's top speed")
		speeds[kit.size() if kit != HEAVY else 99] = top
		if kit == HEAVY:
			assert_eq(game.hero_profile().band, HeroStats.OVERLOADED)
			var hurtbox: Hurtbox = _player().get_node(^"Hurtbox")
			var before := _player().health.current
			hurtbox.receive_hit(Hit.new(2, 130.0, _player().global_position + Vector2(10, 0)))
			assert_eq(before - _player().health.current, 1, "the heavy kit's defence halves a 2-quarter hit (carried)")
			assert_lt(_player().velocity.length(), 130.0 * 0.5, "and its poise keeps the hero nearly in place")
		await _restart()
	assert_almost_eq(speeds[0], 72.0, 0.5, "the bare hero moves as before")
	assert_gt(speeds[6], speeds[0], "the light kit, with its sandals and wraps, a little quicker")
	assert_lt(speeds[99], speeds[0] * 0.8, "the heavy kit is clearly slower")
	assert_gt(speeds[99], speeds[0] * 0.6, "but never stuck")


func test_everything_stays_through_continue_a_fall_and_travel() -> void:
	await _continue_with(_state(&"road_slope", &"trail", {&"corn_bread": 3, &"whitestone_ring": 2, GLOVES: 1},
			{&"ring_1": &"whitestone_ring", &"ring_2": &"whitestone_ring", &"accessory": GLOVES}))
	assert_eq(_player().health.defense_percent, 10.0)
	assert_eq(game.save_now(), OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_slot.path))
	assert_eq(int(data["version"]), 4)
	assert_false(data.has("defense"), "nothing derived is saved")
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.count(&"corn_bread"), 3)
	assert_eq(game.adventure.equipped_copies(&"whitestone_ring"), 2)
	assert_eq(_player().health.defense_percent, 10.0, "after Continue")
	await _fall_and_retry()
	assert_eq(_player().health.defense_percent, 10.0, "after a fall")
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(_player().weapon_attack().knockback, 225.0, "in another area, the gloves still push")
	assert_eq(game.adventure.count(&"whitestone_ring"), 2, "never doubled")


func test_saves_from_every_format_keep_their_progress_and_find_new_things() -> void:
	for file_name: String in ["v1_back_in_village.json", "v2_stall_worked.json", "v2_after_pedrabranca.json",
			"v3_gloves_worn.json"]:
		var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES.path_join(file_name)))
		await _continue_from_fixture(file_name)
		assert_eq(game.adventure.equipped(ItemCatalog.MAIN_HAND), SWORD, "%s holds the sword" % file_name)
		for flag: String in before["flags"]:
			assert_true(game.adventure.has_flag(StringName(flag)), "%s keeps %s" % [file_name, flag])
		if file_name == "v3_gloves_worn.json":
			assert_eq(game.adventure.equipped(ItemCatalog.ACCESSORY), GLOVES, "the gloves stay worn")
			assert_eq(game.adventure.count(GLOVES), 1)
			assert_eq(_player().weapon_attack().knockback, 225.0)
			assert_null(game.level.get_node_or_null(^"Entities/CrewGloves"), "and their pickup is not offered again")
		assert_eq(game.save_now(), OK)
		var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_slot.path))
		assert_eq(int(after["version"]), 4, "%s is written back in format 4" % file_name)
		await _restart()
	await _continue_from_fixture("v2_after_pedrabranca.json")
	game.travel(&"road_slope", &"trail")
	await _settle()
	assert_true(await _walk_to(BY_THE_GLOVES), "a 6.9 save walks to the shelter")
	await _tap(&"move_right")
	assert_string_contains(await _press_interact(), tr("ITEM_CREW_GLOVES"), "and finds the gloves")


func test_an_unknown_item_is_kept_and_a_broken_save_falls_back() -> void:
	await _continue_from_fixture("v3_unknown_item.json")
	assert_push_warning("does not know (lantern_of_tomorrow)")
	assert_true(game.adventure.has_item(&"lantern_of_tomorrow"))
	await _press(&"equipment")
	await _press(&"menu_next")
	assert_false(_menu().shown_items().has(&"lantern_of_tomorrow"), "never shown")
	await _press(&"equipment")
	assert_eq(game.save_now(), OK)
	assert_eq(game.save_now(), OK)
	var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	file.store_string("{ \"version\": 4, \"inventory\": [")
	file.close()
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.save_slot.status, SaveFile.Status.RECOVERED)
	assert_true(game.adventure.has_item(&"lantern_of_tomorrow"), "the backup keeps it too")
	assert_eq(game.adventure.count(GLOVES), 1)


func test_the_menu_does_not_open_over_a_dialogue_a_swing_the_map_or_a_fall() -> void:
	await _continue_with(_state(&"road_slope", &"trail", {GLOVES: 1}))
	var hud: Hud = game.get_node(^"HUD")
	hud.show_message("ROAD_SHELTER")
	await _press(&"equipment")
	assert_false(_menu().is_open(), "not over a dialogue")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	Input.action_press(&"attack")
	await wait_physics_frames(2)
	await _press(&"equipment")
	Input.action_release(&"attack")
	assert_false(_menu().is_open(), "not in the middle of a swing")
	await wait_physics_frames(30)
	_player().health.take_damage(999)
	await wait_physics_frames(3)
	await _press(&"equipment")
	assert_false(_menu().is_open(), "not after a fall")
	await _restart()
	var state := Adventure.new(&"waystop", &"east")
	state.set_flag(&"spring_iara_left")
	state.set_flag(&"blank_witch_met")
	game.save_slot.save(state)
	game.continue_saved()
	await _settle()
	var map := game.level.get_node(^"Entities/WitchMap") as MapSheet
	_player().global_position = Vector2(198, 198)
	await wait_physics_frames(3)
	await _tap(&"interact")
	assert_true(map.is_open())
	await wait_physics_frames(20)
	await _press(&"equipment")
	assert_false(_menu().is_open(), "not over the witch's map")
	await _press(&"pause")
	assert_false(map.is_open())
	assert_false(get_tree().paused, "Esc on the map still never opens the pause")


func test_the_menu_texts_fit_in_both_languages() -> void:
	var menu: HeroMenu = MenuScene.instantiate()
	add_child_autofree(menu)
	var adventure := Adventure.new()
	for id: StringName in ItemCatalog.ITEMS:
		if id != SWORD:
			adventure.add_item(id, STACKS.get(id, 1))
	var health := Health.new()
	add_child_autofree(health)
	for locale in Settings.LOCALES:
		TranslationServer.set_locale(locale)
		for gamepad in [false, true]:
			menu.set_input_mode(gamepad, "")
			menu.open(adventure, 12, health, func(_id: StringName) -> bool: return false, HeroMenu.Page.INVENTORY)
			for id in menu.shown_items():
				menu._cell = menu.shown_items().find(id)
				menu._refresh()
				await wait_process_frames(1)
				_assert_fits(menu, "Root/Inventory/Info/Name", 1, locale + " " + String(id))
				_assert_fits(menu, "Root/Inventory/Info/Kind", 1, locale + " " + String(id))
				_assert_fits(menu, "Root/Inventory/Info/Description", 4, locale + " " + String(id))
				_assert_fits(menu, "Root/Inventory/Info/Effect", 3, locale + " " + String(id))
			_assert_fits(menu, "Root/Hint", 1, locale + " inventory hint")
			menu.close()
			menu.open(adventure, 12, health, func(_id: StringName) -> bool: return false, HeroMenu.Page.EQUIPMENT)
			for group: Array in HeroMenu.GROUPS:
				for slot: StringName in group[1]:
					for id in Equipment.candidates(adventure, slot):
						adventure.equip(slot, id)
						menu._refresh()
						await wait_process_frames(1)
						_assert_fits(menu, "Root/Equipment/Info/Name", 1, locale + " " + String(id))
						_assert_fits(menu, "Root/Equipment/Info/Effect", 4, locale + " " + String(id))
					menu._group = HeroMenu.GROUPS.find(group)
					menu._slot_index = (group[1] as Array).find(slot)
					menu._confirm()
					for c in menu._choices.size():
						menu._choice = c
						menu._refresh()
						await wait_process_frames(1)
						for r in HeroMenu.LIST_ROWS:
							_assert_fits(menu, "Root/Equipment/List/Row%d/Label" % r, 1, locale + " list")
						for r in 5:
							_assert_fits(menu, "Root/Equipment/Summary/Line%d" % r, 1, locale + " compare")
					menu._choosing = false
			_assert_fits(menu, "Root/Hint", 1, locale + " equipment hint")
			menu.page = HeroMenu.Page.STATUS
			menu._refresh()
			await wait_process_frames(1)
			for p in 3:
				for r in 4:
					var name := menu.get_node("Root/Status/Panel%d/Name%d" % [p, r]) as Label
					var value := menu.get_node("Root/Status/Panel%d/Value%d" % [p, r]) as Label
					assert_lte(name.get_minimum_size().x + value.get_minimum_size().x + 4, name.size.x,
							"%s status %d/%d: %s %s" % [locale, p, r, name.text, value.text])
			menu.close()
	TranslationServer.set_locale("pt_BR")


func _assert_fits(menu: HeroMenu, path: String, lines: int, what: String) -> void:
	var label := menu.get_node(path) as Label
	if label.text.is_empty():
		return
	assert_lte(label.get_line_count(), lines, "%s: %s" % [what, label.text])
	if lines == 1:
		assert_lte(label.get_minimum_size().x, label.size.x + 1.0, "%s fits across: %s" % [what, label.text])


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()
