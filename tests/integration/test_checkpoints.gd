extends "res://tests/integration/adventure_case.gd"
## Where a fall leads: the last shrine awakened, whatever area the hero fell in and however
## often they travelled; before any shrine, the entry they last arrived through. Also saves
## from the first format (fixtures written by that version of the game) and broken checkpoints.

const FIXTURES := "res://tests/fixtures/saves"


## Puts a save written by an earlier version of the game in place of this test's slot.
func _install_fixture(file_name: String, slot_path: String = "") -> void:
	var target := slot_path if not slot_path.is_empty() else game.save_slot.path
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_buffer(FileAccess.get_file_as_bytes(FIXTURES.path_join(file_name)))
	file.close()


func _shrine_then_village() -> void:
	game.start_new()
	await _settle()
	await _take_exit("ToForest")
	await _awaken_shrine()
	await _take_exit("ToVillage")


func test_before_any_shrine_a_fall_returns_to_the_last_arrival() -> void:
	game.start_new()
	await _settle()
	await _fall_and_retry()
	_assert_at_entry(&"village", &"start")
	await _take_exit("ToForest")
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"south")
	assert_eq(_player().health.current, _player().health.max_health)
	assert_false(game.get_node(^"DeathScreen").call(&"is_open"))


func test_a_fall_near_the_awakened_shrine_returns_to_it_and_keeps_progress() -> void:
	game.start_new()
	await _settle()
	await _take_exit("ToForest")
	await _awaken_shrine()
	_player().global_position = Vector2(530, 290)
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")
	assert_true(game.adventure.has_flag(&"forest_shrine_awakened"))
	assert_eq((game.level.get_node(^"Entities/Shrine") as Shrine).state, Shrine.State.AWAKENED)


func test_a_fall_in_another_area_returns_to_the_shrine() -> void:
	await _shrine_then_village()
	assert_eq(game.save_slot.load_adventure().area, &"village", "resumes in the village...")
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")
	var saved := game.save_slot.load_adventure()
	assert_eq([saved.area, saved.entry], [&"forest", &"shrine"], "...until the fall brings the hero back")


func test_coming_back_to_the_forest_keeps_the_shrine_as_checkpoint() -> void:
	await _shrine_then_village()
	await _take_exit("ToForest")
	assert_eq(game.adventure.entry, &"south", "arrived through the south entry")
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")


func test_many_trips_never_move_the_checkpoint() -> void:
	await _shrine_then_village()
	for i in 3:
		await _take_exit("ToForest")
		await _take_exit("ToVillage")
	var saved := game.save_slot.load_adventure()
	assert_eq([saved.checkpoint_area, saved.checkpoint_entry], [&"forest", &"shrine"])
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")


func test_continue_resumes_away_from_the_checkpoint_and_a_fall_still_finds_it() -> void:
	await _shrine_then_village()
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	_assert_at_entry(&"village", &"north")
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")


func test_a_checkpoint_in_an_unknown_area_falls_back_to_the_last_arrival() -> void:
	var adventure := Adventure.new(&"village", &"north")
	adventure.checkpoint_area = &"mountains"
	adventure.checkpoint_entry = &"peak"
	game.save_slot.save(adventure)
	assert_true(game.continue_saved())
	await _settle()
	await _fall_and_retry()
	_assert_at_entry(&"village", &"north")
	assert_true(_player().health.current > 0)


func test_a_checkpoint_entry_missing_from_its_area_still_brings_the_hero_back_alive() -> void:
	var adventure := Adventure.new(&"village", &"north")
	adventure.checkpoint_area = &"forest"
	adventure.checkpoint_entry = &"removed_entry"
	game.save_slot.save(adventure)
	assert_true(game.continue_saved())
	await _settle()
	await _fall_and_retry()
	assert_eq(game.level.area_id, &"forest")
	assert_eq(_player().health.current, _player().health.max_health)
	assert_false(_player().health.is_dead())


func test_every_first_format_save_can_be_continued() -> void:
	var expected := {
		"v1_fresh.json": [&"village", &"start", false],
		"v1_before_shrine.json": [&"forest", &"south", false],
		"v1_shrine_awakened.json": [&"forest", &"shrine", true],
		"v1_back_in_village.json": [&"village", &"north", true],
	}
	for fixture: String in expected:
		_install_fixture(fixture)
		var loaded := game.save_slot.load_adventure()
		assert_eq(game.save_slot.status, SaveFile.Status.LOADED, fixture)
		assert_eq([loaded.area, loaded.entry], expected[fixture].slice(0, 2), fixture)
		assert_eq(loaded.has_checkpoint(), expected[fixture][2], fixture)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_slot.path))


func test_a_first_format_save_is_upgraded_without_losing_anything() -> void:
	_install_fixture("v1_back_in_village.json")
	var original := FileAccess.get_file_as_string(game.save_slot.path)
	assert_true(game.continue_saved())
	await _settle()
	_assert_at_entry(&"village", &"north")
	assert_eq(_player().health.current, 7)
	assert_eq((game.level.get_node(^"Entities/GuardianStatue") as GuardianStatue).restored, true)
	assert_eq(FileAccess.get_file_as_string(game.save_slot.path), original, "loading alone rewrites nothing")
	await _fall_and_retry()
	_assert_at_entry(&"forest", &"shrine")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(game.save_slot.path))
	assert_eq(data["version"], float(Adventure.FORMAT_VERSION), "written in the new format")
	assert_eq(data["checkpoint"], {"area": "forest", "entry": "shrine"})
	assert_eq(data["flags"].size(), 4, "every flag kept")
	assert_eq(FileAccess.get_file_as_string(game.save_slot.backup_path()), original,
			"the old save is the backup, byte for byte")
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	_assert_at_entry(&"forest", &"shrine")


func test_a_broken_save_falls_back_to_a_first_format_backup() -> void:
	_install_fixture("v1_shrine_awakened.json", game.save_slot.backup_path())
	var file := FileAccess.open(game.save_slot.path, FileAccess.WRITE)
	file.store_string("{ \"version\": 2, \"area\": ")
	file.close()
	assert_true(game.continue_saved())
	assert_eq(game.save_slot.status, SaveFile.Status.RECOVERED)
	await _settle()
	_assert_at_entry(&"forest", &"shrine")
	assert_true(game.adventure.has_checkpoint())
