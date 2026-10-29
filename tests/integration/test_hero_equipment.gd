extends "res://tests/integration/adventure_case.gd"
## The first equipment, played: the crew's gloves found at their shelter on the road slope (real
## input), the equipment screen opened, read and used with real key events, the gloves' heavier
## knockback on a Musgorico against the bare sword, a swing under way keeping its values, what
## stays through Continue, a fall and travel, saves from before items, unknown items, the backup,
## the screen never opening over something else and never letting the pause menu open as it
## closes, and its texts in both languages.

const FIXTURES := "res://tests/fixtures/saves"
const MusgoricoScene := preload("res://actors/musgorico/musgorico.tscn")
const ScreenScene := preload("res://ui/equipment/equipment_screen.tscn")
const HudScene := preload("res://ui/hud/hud.tscn")
const GLOVES := &"crew_gloves"
## Everything up to the notice coming down at Pedrabranca (milestone 6.9).
const AFTER_TOWN: Array[StringName] = [&"forest_shrine_awakened", &"far_bank_bridge_tied", &"far_bank_iara_met",
		&"road_work_started", &"road_bar_lent", &"road_trunk_loosened", &"road_ditch_cleared",
		&"road_iara_heard_cleared", &"road_clearing_progressed", &"spring_iara_ready", &"spring_plan_heard",
		&"spring_stone_shifted", &"spring_iara_ahead", &"spring_iara_left", &"blank_witch_met",
		&"blank_view_seen", &"blank_map_drawn", &"blank_witch_gone", &"town_iara_met", &"town_rufina_heard",
		&"town_rufina_faced", &"town_iara_dealt", &"town_notice_down"]
## Where the hero stands to take the gloves (they lie just east, in front of the shelter).
const BY_THE_GLOVES := Vector2(306, 196)
const SLOPE_BOUNDS := Rect2i(0, 0, 416, 224)
## Open ground on the slope, room to be pushed east.
const OPEN_GROUND := Vector2(280, 128)


func after_each() -> void:
	super.after_each()
	_steer(Vector2.ZERO)


func _continue_in(area: StringName, entry: StringName, items: Array[StringName] = [], worn: StringName = &"") -> void:
	var state := Adventure.new(area, entry)
	for flag in AFTER_TOWN:
		state.set_flag(flag)
	for id in items:
		state.add_item(id)
	if not worn.is_empty():
		state.equip(ItemCatalog.ACCESSORY, worn)
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


func _continue_from_fixture(file_name: String) -> void:
	var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
	file.close()
	assert_true(game.continue_saved(), file_name)
	await _settle()


func _screen() -> EquipmentScreen:
	return game.get_node(^"EquipmentScreen") as EquipmentScreen


func _knockback() -> float:
	return _player().sword_power().knockback


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


## A key press as the keyboard sends it (an input event, which the screens listen for). Parsed
## events are delivered on the next pass of the main loop, so this waits for process frames, not
## only physics ones.
func _press_key_event(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_process_frames(2)
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


## The way the hero's body can walk from `from` to `to` (a breadth-first search on a 4 px grid),
## as the points where it turns.
func _path(from: Vector2i, to: Vector2i, bounds: Rect2i) -> Array[Vector2]:
	var body: CollisionShape2D = _player().get_node(^"Collision")
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.collision_mask = 1
	query.exclude = [_player().get_rid()]
	var space := _player().get_world_2d().direct_space_state
	var came_from := {from: from}
	var frontier: Array[Vector2i] = [from]
	var index := 0
	var reached := Vector2i(-1, -1)
	while index < frontier.size():
		var at := frontier[index]
		index += 1
		if at.distance_to(to) <= 4.0:
			reached = at
			break
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = at + offset * 4
			if not bounds.has_point(next) or came_from.has(next):
				continue
			query.transform = Transform2D(0.0, Vector2(next) + body.position)
			if space.intersect_shape(query, 1).is_empty():
				came_from[next] = at
				frontier.append(next)
	var points: Array[Vector2] = []
	if reached == Vector2i(-1, -1):
		return points
	var at := reached
	while at != from:
		points.push_front(Vector2(at))
		at = came_from[at]
	var turns: Array[Vector2] = []
	for i in points.size():
		var last := i == points.size() - 1
		if last or (i > 0 and (points[i] - points[i - 1]) != (points[i + 1] - points[i])):
			turns.append(points[i])
	turns.append(Vector2(to))
	return turns


func _walk_to(target: Vector2, bounds: Rect2i) -> bool:
	var points := _path(Vector2i(_player().global_position.round()), Vector2i(target), bounds)
	if points.is_empty():
		gut.p("no way from %s to %s" % [_player().global_position, target])
		return false
	for point in points:
		var left := 6.0
		while _player().global_position.distance_to(point) > 2.0 and left > 0.0:
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


## A Musgorico just right of the hero, facing them, minding its own business (no target).
func _musgorico_beside_the_hero() -> Musgorico:
	var musgo: Musgorico = MusgoricoScene.instantiate()
	musgo.rng_seed = 3
	musgo.position = _player().global_position + Vector2(18, 0)
	game.level.get_node(^"Entities").add_child(musgo)
	await wait_physics_frames(2)
	return musgo


## Swings right at `musgo` with the real attack key; returns [the knockback the hit carried, how
## far the Musgorico slid while staggered].
func _strike(musgo: Musgorico) -> Array:
	var carried := [0.0]
	var hurtbox: Hurtbox = musgo.get_node(^"Hurtbox")
	var listen := func(hit: Hit) -> void: carried[0] = hit.knockback
	hurtbox.hit_received.connect(listen)
	musgo.position = _player().global_position + Vector2(18, 0)
	_player().facing = Vector2.RIGHT
	await _tap(&"attack")
	var landed_at := Vector2.INF
	for i in 30:
		if carried[0] > 0.0:
			landed_at = musgo.global_position
			break
		await wait_physics_frames(1)
	assert_ne(landed_at, Vector2.INF, "the swing lands")
	var start := landed_at
	await _wait_until(func() -> bool: return musgo.state != Musgorico.State.HURT, 1.0)
	hurtbox.hit_received.disconnect(listen)
	return [carried[0], musgo.global_position.distance_to(start)]


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


func test_the_gloves_are_found_at_the_crews_shelter() -> void:
	await _continue_in(&"road_slope", &"trail")
	var hud: Hud = game.get_node(^"HUD")
	assert_false(hud.is_guidance_visible(), "no hint before there is anything to equip")
	assert_true(await _walk_to(BY_THE_GLOVES, SLOPE_BOUNDS), "to the gloves on foot")
	await _tap(&"move_right")
	assert_eq(await _press_interact(), "ITEM_CREW_GLOVES_FOUND")
	assert_true(game.adventure.has_item(GLOVES))
	assert_eq(game.adventure.equipped(ItemCatalog.ACCESSORY), &"", "found, not yet worn")
	assert_eq(_knockback(), 150.0, "carried gloves change nothing")
	assert_true(hud.is_guidance_visible(), "a hint says how to open the equipment")
	assert_string_contains((hud.get_node(^"%Guidance") as Label).text, "I")
	await wait_physics_frames(60)
	assert_eq(await _press_interact(), "", "there is nothing more to take")
	assert_eq(game.adventure.items(), [GLOVES] as Array[StringName], "taken once")
	game.travel(&"road_slope", &"trail")
	await _settle()
	assert_null(game.level.get_node_or_null(^"Entities/CrewGloves"), "and gone from the shelter for good")


func test_the_screen_shows_the_gloves_and_equips_them_with_the_keyboard() -> void:
	await _continue_in(&"road_slope", &"trail", [GLOVES])
	await _press_key_event(&"equipment")
	var screen := _screen()
	assert_true(screen.is_open(), "the equipment key opens it")
	await wait_physics_frames(2)
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_DISABLED, "the area holds still")
	assert_eq((screen.get_node(^"%ItemName") as Label).text, tr("ITEM_CREW_GLOVES"))
	assert_eq((screen.get_node(^"%Description") as Label).text, tr("ITEM_CREW_GLOVES_DESC"))
	assert_eq((screen.get_node(^"%Effect") as Label).text, tr("ITEM_CREW_GLOVES_EFFECT"))
	assert_eq((screen.get_node(^"%State") as Label).text, tr("EQUIPMENT_NOT_WORN"))
	assert_eq((screen.get_node(^"Root/Cells/Cell0/Icon") as TextureRect).texture, ItemCatalog.find(GLOVES).icon)
	assert_true((screen.get_node(^"%SlotEmpty") as CanvasItem).visible, "the slot is empty")
	await _press_key_event(&"interact")
	assert_eq(game.adventure.equipped(ItemCatalog.ACCESSORY), GLOVES, "the interact key puts them on")
	assert_eq((screen.get_node(^"%State") as Label).text, tr("EQUIPMENT_WORN"))
	assert_eq((screen.get_node(^"%SlotIcon") as TextureRect).texture, ItemCatalog.find(GLOVES).icon)
	assert_eq(_knockback(), 225.0, "the sword pushes harder at once")
	await _press_key_event(&"interact")
	assert_eq(game.adventure.equipped(ItemCatalog.ACCESSORY), &"", "and takes them off")
	assert_eq(_knockback(), 150.0, "the bare sword again")
	await _press_key_event(&"attack")
	assert_true(screen.is_open(), "the sword key does nothing here")
	await _press_key_event(&"interact")
	await _press_key_event(&"equipment")
	assert_false(screen.is_open(), "the equipment key closes it")
	await wait_physics_frames(2)
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_INHERIT, "the area runs again")
	assert_eq(_player().state, Player.State.MOVE, "and the hero did not swing")
	assert_eq(_knockback(), 225.0, "still worn after closing")
	assert_true(game.adventure.has_flag(Game.EQUIPMENT_SEEN_FLAG))


func test_esc_closes_the_screen_without_opening_the_pause_menu() -> void:
	await _continue_in(&"road_slope", &"trail", [GLOVES])
	for closing: StringName in [&"pause", &"ui_cancel"]:
		await _press_key_event(&"equipment")
		assert_true(_screen().is_open())
		await _press_key_event(closing)
		assert_false(_screen().is_open(), "%s closes it" % closing)
		assert_false(get_tree().paused, "and the pause menu does not open (%s)" % closing)
	await _press_key_event(&"pause")
	assert_true(get_tree().paused, "the pause key works as usual once it is shut")
	await _press_key_event(&"equipment")
	assert_false(_screen().is_open(), "and the screen does not open over the pause")
	await _press_key_event(&"pause")
	assert_false(get_tree().paused)


func test_the_screen_does_not_open_over_a_dialogue_a_swing_the_map_or_a_fall() -> void:
	await _continue_in(&"road_slope", &"trail", [GLOVES])
	var hud: Hud = game.get_node(^"HUD")
	hud.show_message("ROAD_SHELTER")
	await _press_key_event(&"equipment")
	assert_false(_screen().is_open(), "not over a dialogue")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	Input.action_press(&"attack")
	await wait_physics_frames(2)
	assert_eq(_player().state, Player.State.ATTACK)
	await _press_key_event(&"equipment")
	Input.action_release(&"attack")
	assert_false(_screen().is_open(), "not in the middle of a swing")
	await wait_physics_frames(30)
	_player().health.take_damage(999)
	await wait_physics_frames(3)
	await _press_key_event(&"equipment")
	assert_false(_screen().is_open(), "not after a fall")
	await _restart()
	var state := Adventure.new(&"waystop", &"east")
	state.set_flag(&"spring_iara_left")
	state.set_flag(&"blank_witch_met")
	state.add_item(GLOVES)
	game.save_slot.save(state)
	game.continue_saved()
	await _settle()
	var map := game.level.get_node(^"Entities/WitchMap") as MapSheet
	_player().global_position = Vector2(198, 198)
	await wait_physics_frames(3)
	await _tap(&"interact")
	assert_true(map.is_open())
	await wait_physics_frames(20)
	await _press_key_event(&"equipment")
	assert_false(_screen().is_open(), "not over the witch's map")
	await _press_key_event(&"pause")
	assert_false(map.is_open())


func test_the_gloves_push_a_musgorico_about_twice_as_far() -> void:
	await _continue_in(&"road_slope", &"trail", [GLOVES])
	_player().global_position = OPEN_GROUND
	await wait_physics_frames(3)
	var first := await _musgorico_beside_the_hero()
	var bare := await _strike(first)
	assert_eq(bare[0], 150.0, "the bare sword")
	first.queue_free()
	await wait_physics_frames(30)
	_player().global_position = OPEN_GROUND
	await wait_physics_frames(3)
	await _press_key_event(&"equipment")
	await _press_key_event(&"interact")
	await _press_key_event(&"equipment")
	await wait_physics_frames(3)
	var musgo := await _musgorico_beside_the_hero()
	var gloved := await _strike(musgo)
	assert_eq(gloved[0], 225.0, "with the gloves")
	gut.p("Musgorico slid %.1f px from the bare sword, %.1f px with the gloves" % [bare[1], gloved[1]])
	assert_gt(gloved[1], bare[1] * 1.6, "it is pushed clearly further")
	assert_eq(musgo.get_node(^"Health").get("current"), 2, "but takes the same one quarter of damage")


func test_a_swing_under_way_keeps_its_knockback() -> void:
	await _continue_in(&"road_slope", &"trail", [GLOVES])
	var sword: Hitbox = _player().get_node(^"AttackPivot/SwordHitbox")
	Input.action_press(&"attack")
	await wait_physics_frames(2)
	Input.action_release(&"attack")
	assert_eq(_player().state, Player.State.ATTACK)
	game.adventure.equip(ItemCatalog.ACCESSORY, GLOVES)
	assert_eq(_knockback(), 225.0, "the next swing will push harder")
	assert_eq(sword.knockback, 150.0, "the one under way keeps what it started with")
	await _wait_until(func() -> bool: return _player().state == Player.State.MOVE, 1.0)
	await _tap(&"attack")
	assert_eq(sword.knockback, 225.0)
	await _wait_until(func() -> bool: return _player().state == Player.State.MOVE, 1.0)
	game.adventure.unequip(ItemCatalog.ACCESSORY)
	await _tap(&"attack")
	assert_eq(sword.knockback, 150.0, "and taking them off restores it")


func test_worn_gloves_stay_through_continue_a_fall_and_travel() -> void:
	await _continue_in(&"road_slope", &"trail", [GLOVES], GLOVES)
	assert_eq(_knockback(), 225.0)
	assert_eq(game.save_now(), OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_slot.path))
	assert_eq(data["version"], 3.0)
	assert_eq(data["equipment"], {"accessory": "crew_gloves"})
	assert_false(data.has("sword_knockback"), "nothing derived is saved")
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.equipped(ItemCatalog.ACCESSORY), GLOVES, "after Continue")
	assert_eq(_knockback(), 225.0)
	await _fall_and_retry()
	assert_eq(game.level.area_id, &"forest")
	assert_eq(_knockback(), 225.0, "after a fall")
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(_knockback(), 225.0, "in another area")
	assert_eq(game.adventure.items(), [GLOVES] as Array[StringName], "and never doubled")


func test_saves_from_before_items_start_with_an_empty_bag() -> void:
	for file_name: String in ["v1_back_in_village.json", "v2_stall_worked.json", "v2_after_pedrabranca.json"]:
		var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES.path_join(file_name)))
		await _continue_from_fixture(file_name)
		assert_true(game.adventure.items().is_empty(), file_name)
		assert_eq(_knockback(), 150.0, "%s: the bare sword" % file_name)
		for flag: String in before["flags"]:
			assert_true(game.adventure.has_flag(StringName(flag)), "%s keeps %s" % [file_name, flag])
		if int(before["health"]) > 0:
			assert_eq(_player().health.current, int(before["health"]), "%s keeps its health" % file_name)
		assert_eq(game.save_now(), OK)
		var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_slot.path))
		assert_eq(int(after["version"]), 3, "%s is written back in format 3" % file_name)
		assert_eq(after["items"], [], file_name)
		await _restart()


func test_a_save_from_milestone_6_9_can_still_find_the_gloves() -> void:
	await _continue_from_fixture("v2_after_pedrabranca.json")
	assert_eq(game.level.area_id, &"pedrabranca")
	assert_eq(_player().health.max_health, 16, "the ruin's heart is kept")
	game.travel(&"road_slope", &"trail")
	await _settle()
	assert_not_null(game.level.get_node_or_null(^"Entities/CrewGloves"), "the gloves wait at the shelter")


func test_saves_with_the_gloves_worn_and_with_an_unknown_item() -> void:
	await _continue_from_fixture("v3_gloves_worn.json")
	assert_eq(_knockback(), 225.0, "worn as saved")
	assert_null(game.level.get_node_or_null(^"Entities/CrewGloves"), "and not lying at the shelter too")
	await _restart()
	await _continue_from_fixture("v3_unknown_item.json")
	assert_push_warning("does not know (lantern_of_tomorrow)")
	assert_true(game.adventure.has_item(&"lantern_of_tomorrow"), "an unknown item is kept")
	assert_eq(_knockback(), 150.0, "but does nothing")
	await _press_key_event(&"equipment")
	assert_eq((_screen().get_node(^"%ItemName") as Label).text, tr("ITEM_CREW_GLOVES"), "only known items are listed")
	assert_null((_screen().get_node(^"Root/Cells/Cell1/Icon") as TextureRect).texture)
	await _press_key_event(&"interact")
	assert_eq(game.adventure.equipped(ItemCatalog.ACCESSORY), GLOVES, "the gloves can take the slot")
	await _press_key_event(&"equipment")
	assert_eq(game.save_now(), OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_slot.path))
	assert_eq(data["items"], ["crew_gloves", "lantern_of_tomorrow"], "the unknown one is written back")


func test_a_broken_save_falls_back_to_its_backup_with_the_gloves() -> void:
	await _continue_in(&"road_slope", &"trail", [GLOVES], GLOVES)
	assert_eq(game.save_now(), OK)
	assert_eq(game.save_now(), OK, "a second write keeps the first as the backup")
	var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	file.store_string("{ \"version\": 3, \"items\": [")
	file.close()
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.save_slot.status, SaveFile.Status.RECOVERED)
	assert_eq(game.adventure.equipped(ItemCatalog.ACCESSORY), GLOVES, "the backup still wears them")
	assert_eq(_knockback(), 225.0)
	var malformed := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	malformed.store_string(JSON.stringify({"version": 3, "area": "forest", "entry": "shrine", "checkpoint": null,
			"health": -1, "flags": [], "items": [7], "equipment": {}}))
	malformed.close()
	assert_not_null(game.save_slot.load_adventure())
	assert_eq(game.save_slot.status, SaveFile.Status.RECOVERED, "a malformed item list is not read as an empty bag")


func test_the_screen_texts_fit_in_both_languages() -> void:
	var screen: EquipmentScreen = ScreenScene.instantiate()
	add_child_autofree(screen)
	var hud: Hud = HudScene.instantiate()
	add_child_autofree(hud)
	var adventure := Adventure.new()
	adventure.add_item(GLOVES)
	var guidance: Label = hud.get_node(^"%Guidance")
	for locale in Settings.LOCALES:
		TranslationServer.set_locale(locale)
		for worn in [false, true]:
			if worn:
				adventure.equip(ItemCatalog.ACCESSORY, GLOVES)
			else:
				adventure.unequip(ItemCatalog.ACCESSORY)
			screen.open(adventure)
			for gamepad in [false, true]:
				screen.set_input_mode(gamepad, "")
				await wait_process_frames(1)
				for label_name in ["SlotLabel", "ItemName", "Description", "Effect", "State", "Hint"]:
					var label: Label = screen.get_node("%" + label_name)
					var height := label.get_line_count() * (label.get_line_height() + 1)
					assert_lte(height, int(label.size.y) + 1, "%s %s fits (%s)" % [locale, label_name, label.text])
					assert_lte(label.get_line_count(), 1 if label_name in ["SlotLabel", "ItemName", "State", "Hint"] else 5,
							"%s %s" % [locale, label_name])
			var title: Label = screen.get_node(^"%Title")
			var top := title.get_global_transform_with_canvas() * Vector2(0, title.size.y / 2.0 - title.get_line_height())
			assert_gte(top.y, 0.0, "%s title on screen" % locale)
			screen.close()
		hud.set_guidance("EQUIPMENT_GUIDANCE", [&"equipment", &"interact"])
		await wait_process_frames(1)
		assert_lte(guidance.get_line_count(), 2, "%s hint: %s" % [locale, guidance.text])
	TranslationServer.set_locale("pt_BR")
