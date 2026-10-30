extends "res://tests/integration/adventure_case.gd"
## Milestone 7.2, played on the real game scene. Appearance: what is worn shows on the hero in every
## state (standing, walking, swinging, guarding, hurt, fallen), changes as soon as the equipment
## does, stays through Continue, travel and a fall, never touches collision or reach, and the menu
## previews it with the same frames. The chest at home: emptied once, it opens as the hero's chest;
## things go in and out with real key events and gamepad buttons (whole, partial, refused); the area
## is frozen while it is open; what it holds survives saving, Continue and a version 4 save.

const FIXTURES := "res://tests/fixtures/saves"
const SWORD := &"wayfarer_sword"
const HOME_CHEST := ^"Entities/Found_PaddedDoublet"
const DOUBLET_FLAG := &"found_village_padded_doublet"
const HEAVY := {&"main_hand": &"quarry_maul", &"off_hand": &"crew_board_shield", &"head": &"quarry_helm",
		&"torso": &"quarry_breastplate", &"hands": &"quarry_gauntlets", &"legs": &"quarry_greaves"}
const DIRECTIONS: Array[String] = ["down", "up", "left", "right"]


func before_each() -> void:
	super.before_each()
	HeroLook.forget()


func after_each() -> void:
	super.after_each()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact"]:
		Input.action_release(action)


func _state(items: Dictionary = {}, worn: Dictionary = {}, flags: Array[StringName] = []) -> Adventure:
	var state := Adventure.new(&"village", &"north")
	for flag in [&"forest_shrine_awakened", &"heard_of_shrine", &"equipment_seen"] + flags:
		state.set_flag(flag)
	for id: StringName in items:
		state.add_item(id, items[id])
	for slot: StringName in worn:
		if state.count(worn[slot]) <= state.equipped_copies(worn[slot]):
			state.add_item(worn[slot])
		assert_true(state.equip(slot, worn[slot]), "%s in %s" % [worn[slot], slot])
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	return state


func _continue_with(state: Adventure) -> void:
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


func _sprite() -> AnimatedSprite2D:
	return _player().get_node(^"Sprite")


## The sheet the first frame of `animation` is cut from.
func _atlas(animation: StringName) -> Texture2D:
	return (_sprite().sprite_frames.get_frame_texture(animation, 0) as AtlasTexture).atlas


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


## Stands below the chest at home, facing it, and presses interact as a key.
func _use_home_chest() -> void:
	var chest: Node2D = game.level.get_node(HOME_CHEST)
	_player().global_position = chest.global_position + Vector2(0, 12)
	_player().face(Vector2.UP)
	await wait_physics_frames(4)
	_player().interactor.refresh_focus()
	Input.action_press(&"interact")
	await wait_physics_frames(2)
	Input.action_release(&"interact")
	await wait_physics_frames(2)


func _storage() -> StorageMenu:
	return game.storage_menu()


# ---------------------------------------------------------------- appearance

func test_what_is_worn_shows_in_every_state() -> void:
	await _continue_with(_state({}, HEAVY))
	var look := game.hero_profile().look()
	assert_ne(look.walk, HeroLook.WALK, "the heavy kit shows")
	for direction in DIRECTIONS:
		assert_eq(_atlas(StringName("idle_" + direction)), look.walk, "standing " + direction)
		assert_eq(_atlas(StringName("walk_" + direction)), look.walk, "walking (and dodging) " + direction)
		assert_eq(_atlas(StringName("attack_" + direction)), look.attack, "swinging " + direction)
		assert_eq(_atlas(StringName("guard_" + direction)), look.guard, "guarding " + direction)
		assert_eq(_atlas(StringName("hurt_" + direction)), look.hurt, "hurt " + direction)
	assert_eq(_atlas(&"death"), look.death, "falling")
	assert_ne(look.attack, ItemCatalog.find(&"quarry_maul").attack_sheet)
	Input.action_press(&"dodge")
	await wait_physics_frames(3)
	Input.action_release(&"dodge")
	var ghosts := 0
	for node in game.level.find_children("*", "Sprite2D", true, false):
		var frame := (node as Sprite2D).texture as AtlasTexture
		if frame != null and frame.atlas == look.walk:
			ghosts += 1
	assert_gt(ghosts, 0, "the dodge's afterimages wear the kit too")


func test_the_hero_changes_as_soon_as_the_equipment_does() -> void:
	await _continue_with(_state({&"straw_hat": 1, &"quarry_helm": 1}))
	assert_eq(_atlas(&"idle_down"), HeroLook.WALK, "nothing worn: the hero's own frames")
	assert_true(Equipment.equip(game.adventure, ItemCatalog.HEAD, &"straw_hat"))
	var hat := _atlas(&"idle_down")
	assert_ne(hat, HeroLook.WALK)
	assert_true(Equipment.equip(game.adventure, ItemCatalog.HEAD, &"quarry_helm"))
	assert_ne(_atlas(&"idle_down"), hat)
	assert_true(Equipment.unequip(game.adventure, ItemCatalog.HEAD))
	assert_eq(_atlas(&"idle_down"), HeroLook.WALK, "taken off, gone")
	assert_true(Equipment.equip(game.adventure, ItemCatalog.HEAD, &"straw_hat"))
	assert_eq(_atlas(&"idle_down"), hat, "put back on: the look kept, not put together again")


func test_the_look_stays_through_continue_travel_and_a_fall() -> void:
	await _continue_with(_state({}, HEAVY))
	var key := game.hero_profile().look().key
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.hero_profile().look().key, key, "after Continue")
	assert_eq(_atlas(&"idle_down"), game.hero_profile().look().walk)
	game.travel(&"forest", &"south")
	await _settle()
	assert_eq(_atlas(&"walk_left"), game.hero_profile().look().walk, "in another area")
	await _fall_and_retry()
	assert_eq(_atlas(&"idle_down"), game.hero_profile().look().walk, "after a fall")
	assert_eq(_atlas(&"death"), game.hero_profile().look().death)


func test_armour_never_changes_collision_reach_or_timing() -> void:
	await _continue_with(_state({&"quarry_maul": 1}, {&"main_hand": &"quarry_maul"}))
	var before := _shapes()
	var swing := _player().weapon_attack().duration()
	var reach := _player().weapon_attack().hitbox_size
	for slot: StringName in HEAVY:
		if slot != &"main_hand":
			game.adventure.add_item(HEAVY[slot])
			Equipment.equip(game.adventure, slot, HEAVY[slot])
	await wait_physics_frames(2)
	assert_ne(_atlas(&"idle_down"), HeroLook.WALK)
	assert_eq(_shapes(), before, "the body, the hurtbox and the weapon's box are as they were")
	assert_eq(_player().weapon_attack().hitbox_size, reach)
	assert_almost_eq(_player().weapon_attack().duration(), swing, 0.0001, "the look changes no timing")


func _shapes() -> Array:
	var sizes := []
	for path: NodePath in [^"Collision", ^"Hurtbox/Shape", ^"AttackPivot/SwordHitbox/Shape"]:
		var node := _player().get_node_or_null(path) as CollisionShape2D
		if node != null and node.shape is RectangleShape2D:
			sizes.append([path, (node.shape as RectangleShape2D).size, node.position])
	return sizes


func test_the_menu_previews_the_hero_with_the_same_frames() -> void:
	await _continue_with(_state({&"straw_hat": 1}, {&"head": &"quarry_helm"}))
	game.open_equipment()
	var menu := game.hero_menu()
	assert_eq(menu.preview_look(), game.hero_profile().look(), "the hero as they are")
	await _press(&"move_down")
	assert_eq(menu.selected_slot(), ItemCatalog.HEAD)
	await _press(&"interact")
	assert_true(menu.is_choosing())
	assert_eq(menu.selected_choice(), &"quarry_helm", "the list is take off, the hat, the helm")
	await _press(&"move_up")
	assert_eq(menu.selected_choice(), &"straw_hat")
	assert_true(menu.preview_look().key.contains("straw_hat"), "the hat under the cursor is tried on")
	assert_eq(game.adventure.equipped(ItemCatalog.HEAD), &"quarry_helm", "only tried on")
	await _press(&"ui_cancel")
	assert_eq(menu.preview_look(), game.hero_profile().look(), "back to what is worn")
	menu.close()


# ---------------------------------------------------------------- the chest at home

func test_the_chest_at_home_is_found_once_then_keeps_things() -> void:
	await _continue_with(_state({&"corn_bread": 3}))
	await _use_home_chest()
	assert_true(game.adventure.has_flag(DOUBLET_FLAG), "the doublet is taken first")
	assert_eq(game.adventure.count(&"padded_doublet"), 1)
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	assert_false(game.is_storage_open())
	await _use_home_chest()
	assert_true(game.is_storage_open(), "then it opens as the hero's chest")
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_DISABLED, "the area is frozen")
	var chest := _storage()
	assert_eq(chest.selected(), SWORD)
	await _press(&"interact")
	assert_eq(chest.notice(), tr("STORAGE_WORN"), "the sword in hand stays")
	assert_eq(game.adventure.equipped(ItemCatalog.MAIN_HAND), SWORD)
	await _press(&"move_down")
	assert_eq(chest.selected(), &"corn_bread")
	await _press(&"interact")
	assert_true(chest.is_choosing_amount(), "three of them: how many?")
	assert_eq(chest.amount(), 3, "all that fits, to start")
	await _press(&"move_left")
	assert_eq(chest.amount(), 2)
	await _press(&"interact")
	assert_eq(game.adventure.count(&"corn_bread"), 1)
	assert_eq(game.adventure.stored(&"corn_bread"), 2)
	assert_eq(chest.selected(), &"corn_bread", "the cursor stays on the bread")
	await _press(&"interact")
	assert_false(chest.is_choosing_amount(), "a single one goes at once")
	assert_eq(game.adventure.stored(&"corn_bread"), 3)
	assert_false(game.adventure.has_item(&"corn_bread"))
	assert_eq(chest.selected(), &"padded_doublet", "the next thing in the bag")
	await _press(&"move_right")
	assert_eq(chest.column, StorageMenu.Column.CHEST)
	assert_eq(chest.selected(), &"corn_bread")
	await _press(&"interact")
	await _press(&"move_down")
	assert_eq(chest.amount(), 1, "ten down from three is one")
	await _press(&"interact")
	assert_eq(game.adventure.count(&"corn_bread"), 1)
	assert_eq(game.adventure.stored(&"corn_bread"), 2)
	await _press(&"ui_cancel")
	assert_false(game.is_storage_open())
	assert_ne(game.level.process_mode, Node.PROCESS_MODE_DISABLED, "the area moves again")
	assert_eq(game.save_now(), OK)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.stored(&"corn_bread"), 2, "kept through Continue")
	assert_eq(game.adventure.count(&"corn_bread"), 1)


func test_the_chest_works_with_a_gamepad() -> void:
	await _continue_with(_state({&"pine_resin": 4, &"straw_hat": 1}, {}, [DOUBLET_FLAG]))
	await _use_home_chest()
	assert_true(game.is_storage_open())
	var chest := _storage()
	await _button(JOY_BUTTON_DPAD_DOWN)
	assert_eq(chest.selected(), &"pine_resin")
	await _button(JOY_BUTTON_A)
	await _button(JOY_BUTTON_A)
	assert_eq(game.adventure.stored(&"pine_resin"), 4)
	await _button(JOY_BUTTON_DPAD_RIGHT)
	await _button(JOY_BUTTON_A)
	await _button(JOY_BUTTON_DPAD_LEFT)
	await _button(JOY_BUTTON_A)
	assert_eq(game.adventure.count(&"pine_resin"), 3)
	await _button(JOY_BUTTON_B)
	assert_false(game.is_storage_open())


func test_a_full_bag_or_chest_says_so_and_loses_nothing() -> void:
	await _continue_with(_state({&"pine_resin": 20 * Bag.CAPACITY, &"corn_bread": 1}))
	assert_eq(Bag.free_spaces(game.adventure), -1)
	await _use_home_chest()
	assert_true(game.adventure.has_flag(DOUBLET_FLAG))
	assert_eq(game.adventure.stored(&"padded_doublet"), 1, "no room in the bag: the doublet stays in the chest")
	assert_false(game.adventure.has_item(&"padded_doublet"))
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	await _use_home_chest()
	var chest := _storage()
	await _press(&"move_right")
	assert_eq(chest.selected(), &"padded_doublet")
	await _press(&"interact")
	assert_eq(chest.notice(), tr("STORAGE_BAG_FULL"))
	assert_eq(game.adventure.stored(&"padded_doublet"), 1, "still in the chest")
	await _press(&"move_left")
	await _press(&"move_down")
	await _press(&"interact")
	assert_eq(chest.amount(), 20 * Bag.CAPACITY)
	await _press(&"interact")
	assert_eq(Storage.spaces_used(game.adventure), 41)
	await _press(&"move_right")
	await _press(&"interact")
	assert_eq(game.adventure.count(&"padded_doublet"), 1, "with room, it comes out")
	await _press(&"ui_cancel")


func test_a_version_4_save_continues_with_an_empty_chest_and_its_kit() -> void:
	var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join("v4_quarry_kit.json")))
	file.close()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.stored_items().size(), 0)
	assert_true(game.adventure.has_item(&"lantern_of_tomorrow"), "the unknown item is still carried")
	assert_true(game.hero_profile().look().key.contains("quarry_helm"))
	assert_eq(_atlas(&"idle_down"), game.hero_profile().look().walk, "the old save's kit shows")
	await _use_home_chest()
	assert_true(game.is_storage_open(), "its chest at home was already emptied: it keeps things now")
	await _press(&"ui_cancel")
	assert_eq(game.save_now(), OK)
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_slot.path))
	assert_eq(int(data["version"]), Adventure.FORMAT_VERSION)
	assert_eq(data["storage"], [])


func test_the_chest_opens_only_when_the_hero_is_free() -> void:
	await _continue_with(_state({}, {}, [DOUBLET_FLAG]))
	game.open_equipment()
	game.open_storage()
	assert_false(game.is_storage_open(), "not over the hero's menu")
	game.hero_menu().close()
	game.open_storage()
	assert_true(game.is_storage_open())
	game.open_equipment()
	assert_false(game.is_equipment_open(), "and the menu not over the chest")
	await _press(&"pause")
	assert_false(game.is_storage_open(), "the pause key closes it")
	assert_false(get_tree().paused, "without also pausing")


func test_the_chest_speaks_both_languages() -> void:
	var keys := ["STORAGE_TITLE", "STORAGE_BAG", "STORAGE_CHEST", "STORAGE_EMPTY", "STORAGE_AMOUNT",
			"STORAGE_PUT_AWAY", "STORAGE_TAKEN", "STORAGE_WORN", "STORAGE_CHEST_FULL", "STORAGE_BAG_FULL",
			"STORAGE_HINT_STORE", "STORAGE_HINT_TAKE", "STORAGE_HINT_SIDE", "STORAGE_HINT_AMOUNT", "PICKUP_KEPT_IN_CHEST"]
	var locale := TranslationServer.get_locale()
	for language in ["pt_BR", "en"]:
		TranslationServer.set_locale(language)
		for key: String in keys:
			assert_ne(tr(key), key, "%s in %s" % [key, language])
	TranslationServer.set_locale("pt_BR")
	var portuguese := tr("STORAGE_TITLE")
	TranslationServer.set_locale("en")
	assert_ne(tr("STORAGE_TITLE"), portuguese)
	TranslationServer.set_locale(locale)
