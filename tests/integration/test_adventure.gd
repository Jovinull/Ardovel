extends GutTest
## The first adventure end to end on the real game scene: travelling between the village and the
## forest, the shrine as checkpoint, falling and coming back, villagers reacting to progress,
## and everything surviving a save and a fresh start of the game.

const GameScene := preload("res://game/game.tscn")
const DIR := "user://test_saves/adventure"

var game: Game


func before_each() -> void:
	var dir := ProjectSettings.globalize_path(DIR)
	DirAccess.make_dir_recursive_absolute(dir)
	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir.path_join(file))
	game = _launch()


func after_each() -> void:
	Input.action_release(&"attack")


## A game process, as far as the scene goes: same save file, no title.
func _launch() -> Game:
	var launched: Game = GameScene.instantiate()
	launched.save_path = DIR.path_join("save.json")
	launched.show_title = false
	add_child_autofree(launched)
	return launched


func _player() -> Player:
	return game.level.player


func _settle() -> void:
	for i in 180:
		if not game.is_travelling():
			break
		await wait_physics_frames(1)
	await wait_physics_frames(3)


## Walks the hero into the area's passage and waits for the trip to finish.
func _take_exit(exit_name: String) -> void:
	var exit: AreaExit = game.level.get_node(exit_name)
	_player().global_position = exit.global_position + Vector2(0, 4)
	await wait_physics_frames(3)
	await _settle()


func _awaken_shrine() -> Shrine:
	var shrine: Shrine = game.level.get_node(^"Entities/Shrine")
	_player().global_position = shrine.global_position + Vector2(0, 14)
	await wait_physics_frames(3)
	assert_true(_player().interactor.interact(_player()), "the shrine is within reach")
	game.get_node(^"HUD").call(&"_close_box")
	game.get_node(^"HUD").emit_signal(&"dialogue_finished")
	await wait_physics_frames(3)
	return shrine


func _talk(npc_name: String) -> String:
	var npc: Npc = game.level.get_node("Entities/" + npc_name)
	var said := [""]
	var listen := func(_target: Interactable, message: String) -> void: said[0] = message
	_player().interactor.interacted.connect(listen)
	_player().global_position = npc.global_position + Vector2(0, 14)
	await wait_physics_frames(3)
	_player().interactor.interact(_player())
	_player().interactor.interacted.disconnect(listen)
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	return said[0]


func _players_in_tree() -> int:
	return get_tree().root.find_children("*", "Player", true, false).size()


func test_a_new_adventure_starts_at_home_and_is_saved_at_once() -> void:
	game.start_new()
	await _settle()
	assert_eq(game.level.area_id, &"village")
	assert_almost_eq(_player().global_position, game.level.entry(&"start").global_position, Vector2.ONE)
	assert_true(game.save_slot.exists())
	assert_eq(game.save_slot.load_adventure().area, &"village")


func test_walking_through_the_arch_reaches_the_forest_and_back() -> void:
	game.start_new()
	await _settle()
	await _take_exit("ToForest")
	assert_eq(game.level.area_id, &"forest")
	assert_almost_eq(_player().global_position, game.level.entry(&"south").global_position, Vector2.ONE)
	assert_eq(game.save_slot.load_adventure().area, &"forest", "arriving saves the new area")
	await _take_exit("ToVillage")
	assert_eq(game.level.area_id, &"village")
	assert_almost_eq(_player().global_position, game.level.entry(&"north").global_position, Vector2.ONE)


func test_repeated_crossings_leave_one_hero_and_one_area() -> void:
	game.start_new()
	await _settle()
	var first_area := game.level
	for i in 3:
		await _take_exit("ToForest")
		await _take_exit("ToVillage")
	assert_eq(_players_in_tree(), 1)
	assert_false(is_instance_valid(first_area), "areas left behind are freed")
	assert_eq(game.get_children().filter(func(n: Node) -> bool: return n is Level).size(), 1)


func test_health_carries_over_between_areas() -> void:
	game.start_new()
	await _settle()
	_player().health.invulnerability_time = 0.0
	_player().health.take_damage(5)
	await _take_exit("ToForest")
	assert_eq(_player().health.current, _player().health.max_health - 5)


func test_travel_requests_during_a_trip_or_after_a_fall_are_ignored() -> void:
	game.start_new()
	await _settle()
	game.travel(&"forest", &"south")
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(game.level.area_id, &"forest", "the second request was ignored")
	_player().health.take_damage(999)
	game.travel(&"village", &"north")
	await _settle()
	assert_eq(game.level.area_id, &"forest", "a fallen hero cannot leave")


func test_the_shrine_becomes_the_return_point_and_survives_a_restart() -> void:
	game.start_new()
	await _settle()
	await _take_exit("ToForest")
	await _awaken_shrine()
	var saved := game.save_slot.load_adventure()
	assert_true(saved.has_flag(&"forest_shrine_awakened"))
	assert_eq(saved.entry, &"shrine")
	game.queue_free()
	await wait_physics_frames(2)
	game = _launch()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.level.area_id, &"forest")
	assert_eq((game.level.get_node(^"Entities/Shrine") as Shrine).state, Shrine.State.AWAKENED)
	assert_almost_eq(_player().global_position, game.level.entry(&"shrine").global_position, Vector2.ONE)


func test_a_fall_before_the_shrine_returns_to_the_forest_entrance() -> void:
	game.start_new()
	await _settle()
	await _take_exit("ToForest")
	_player().health.take_damage(999)
	await wait_for_signal(_player().died, 4.0)
	game.respawn()
	await _settle()
	assert_eq(game.level.area_id, &"forest")
	assert_almost_eq(_player().global_position, game.level.entry(&"south").global_position, Vector2.ONE)
	assert_eq(_player().health.current, _player().health.max_health)
	assert_false(game.get_node(^"DeathScreen").call(&"is_open"))


func test_a_fall_after_the_shrine_returns_to_it_and_keeps_progress() -> void:
	game.start_new()
	await _settle()
	await _take_exit("ToForest")
	await _awaken_shrine()
	_player().global_position = Vector2(530, 290)
	_player().health.take_damage(999)
	await wait_for_signal(_player().died, 4.0)
	game.respawn()
	await _settle()
	assert_almost_eq(_player().global_position, game.level.entry(&"shrine").global_position, Vector2.ONE)
	assert_true(game.adventure.has_flag(&"forest_shrine_awakened"))
	assert_eq((game.level.get_node(^"Entities/Shrine") as Shrine).state, Shrine.State.AWAKENED)


func test_continuing_restores_area_return_point_and_health() -> void:
	var adventure := Adventure.new(&"forest", &"south")
	adventure.health = 5
	game.save_slot.save(adventure)
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.level.area_id, &"forest")
	assert_eq(_player().health.current, 5)


func test_nothing_to_continue_without_a_usable_save() -> void:
	assert_false(game.continue_saved())
	var unknown_area := Adventure.new(&"mountains", &"gate")
	game.save_slot.save(unknown_area)
	assert_false(game.continue_saved(), "an area this build does not know")


func test_the_first_objective_from_rumour_to_thanks() -> void:
	game.start_new()
	await _settle()
	var statue: GuardianStatue = game.level.get_node(^"Entities/GuardianStatue")
	assert_false(statue.restored)
	var first := await _talk("Anselmo")
	assert_eq(first, "ANSELMO_RUMOR")
	assert_true(game.adventure.has_flag(&"heard_of_shrine"))
	assert_ne(await _talk("Anselmo"), first, "a reminder instead of the whole story")
	await _take_exit("ToForest")
	await _awaken_shrine()
	game.travel(&"village", &"north")
	await _settle()
	statue = game.level.get_node(^"Entities/GuardianStatue")
	assert_true(statue.restored, "the village shows the consequence")
	assert_true(statue.is_waiting_to_be_seen(), "out of view from the arch: not celebrated yet")
	_player().global_position = statue.global_position + Vector2(0, 30)
	await wait_physics_frames(5)
	assert_false(statue.is_waiting_to_be_seen())
	assert_true(game.adventure.has_flag(&"village_statue_seen_restored"), "celebrated once seen")
	assert_eq(await _talk("Anselmo"), "ANSELMO_THANKS")
	assert_true(game.adventure.has_flag(&"elder_thanked"))
	assert_true(game.save_slot.load_adventure().has_flag(&"elder_thanked"), "saved")


func test_other_villagers_notice_the_awakened_shrine() -> void:
	game.start_new()
	await _settle()
	var before := [await _talk("Lia"), await _talk("Cida")]
	game.adventure.set_flag(&"forest_shrine_awakened")
	game.travel(&"forest", &"south")
	await _settle()
	game.travel(&"village", &"north")
	await _settle()
	assert_ne(await _talk("Lia"), before[0])
	assert_ne(await _talk("Cida"), before[1])


func test_dialogue_freezes_the_area_and_ignores_the_sword() -> void:
	game.start_new()
	await _settle()
	var npc: Npc = game.level.get_node(^"Entities/Anselmo")
	_player().global_position = npc.global_position + Vector2(0, 14)
	await wait_physics_frames(3)
	_player().interactor.interact(_player())
	await wait_physics_frames(2)
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_DISABLED)
	Input.action_press(&"attack")
	await wait_physics_frames(2)
	assert_eq(_player().state, Player.State.MOVE, "no swing while reading")
	Input.action_release(&"attack")
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(2)
	assert_ne(game.level.process_mode, Node.PROCESS_MODE_DISABLED)
