extends GutTest
## Adventure state as plain data: flags, the resume point and the checkpoint, validated
## (de)serialisation and the upgrade of older saves.


func test_starts_in_the_village_with_full_health_no_flags_and_no_checkpoint() -> void:
	var adventure := Adventure.new()
	assert_eq(adventure.area, &"village")
	assert_eq(adventure.entry, &"start")
	assert_eq(adventure.health, Adventure.FULL_HEALTH)
	assert_eq(adventure.flags(), [])
	assert_false(adventure.has_checkpoint())


func test_flags_are_set_once_and_announce_the_change() -> void:
	var adventure := Adventure.new()
	watch_signals(adventure)
	adventure.set_flag(&"shrine_awakened")
	adventure.set_flag(&"shrine_awakened")
	assert_true(adventure.has_flag(&"shrine_awakened"))
	assert_signal_emit_count(adventure, "changed", 1)


func test_a_checkpoint_is_where_the_hero_stands_and_stays_through_travel() -> void:
	var adventure := Adventure.new(&"forest", &"south")
	watch_signals(adventure)
	adventure.activate_checkpoint(&"shrine")
	adventure.activate_checkpoint(&"shrine")
	assert_signal_emit_count(adventure, "changed", 1)
	assert_eq([adventure.checkpoint_area, adventure.checkpoint_entry], [&"forest", &"shrine"])
	assert_eq(adventure.entry, &"shrine", "the adventure resumes at the shrine too")
	adventure.enter(&"village", &"north")
	adventure.enter(&"ruin", &"gate")
	assert_eq([adventure.area, adventure.entry], [&"ruin", &"gate"])
	assert_eq([adventure.checkpoint_area, adventure.checkpoint_entry], [&"forest", &"shrine"], "travel keeps it")


func test_round_trip_through_a_dictionary() -> void:
	var adventure := Adventure.new(&"forest", &"south")
	adventure.activate_checkpoint(&"shrine")
	adventure.enter(&"village", &"north")
	adventure.health = 7
	adventure.set_flag(&"heard_of_shrine")
	var copy := Adventure.from_dict(JSON.parse_string(JSON.stringify(adventure.to_dict())))
	assert_not_null(copy)
	assert_eq([copy.area, copy.entry], [&"village", &"north"])
	assert_eq([copy.checkpoint_area, copy.checkpoint_entry], [&"forest", &"shrine"])
	assert_eq(copy.health, 7)
	assert_true(copy.has_flag(&"heard_of_shrine"))
	var without := Adventure.from_dict(JSON.parse_string(JSON.stringify(Adventure.new().to_dict())))
	assert_false(without.has_checkpoint(), "no checkpoint is written as null")


func test_rejects_data_that_is_not_an_adventure() -> void:
	var good := Adventure.new().to_dict()
	var broken: Array = [
		null, [], "save",
		_with(good, "version", 99), _with(good, "version", 0), _with(good, "version", "2"), _with(good, "version", 1.5),
		_with(good, "area", ""), _with(good, "area", 3), _with(good, "entry", null),
		_with(good, "checkpoint", "forest"), _with(good, "checkpoint", {"area": "forest"}),
		_with(good, "checkpoint", {"area": "forest", "entry": ""}), _with(good, "checkpoint", []),
		_with(good, "health", -2), _with(good, "health", 2.5), _with(good, "health", "full"),
		_with(good, "flags", "shrine"), _with(good, "flags", [1]), _with(good, "flags", [""]),
	]
	for data: Variant in broken:
		assert_null(Adventure.from_dict(data), str(data))
	for field in ["entry", "checkpoint"]:
		var missing := good.duplicate()
		missing.erase(field)
		assert_null(Adventure.from_dict(missing), "%s is missing" % field)


func test_ignores_unknown_keys() -> void:
	assert_not_null(Adventure.from_dict(_with(Adventure.new().to_dict(), "later_feature", true)))


func test_a_version_1_save_with_the_forest_shrine_gets_it_as_checkpoint() -> void:
	var v1 := {"version": 1, "area": "village", "entry": "north", "health": 7.0,
			"flags": ["forest_shrine_awakened", "heard_of_shrine"]}
	var adventure := Adventure.from_dict(v1)
	assert_not_null(adventure)
	assert_eq([adventure.area, adventure.entry], [&"village", &"north"], "resumes where it was saved")
	assert_eq([adventure.checkpoint_area, adventure.checkpoint_entry], [&"forest", &"shrine"])
	assert_eq(adventure.health, 7)
	assert_eq(adventure.flags().size(), 2)
	assert_eq(adventure.to_dict()["version"], Adventure.FORMAT_VERSION, "written back in the new format")


func test_a_version_1_save_before_the_shrine_has_no_checkpoint() -> void:
	var adventure := Adventure.from_dict({"version": 1, "area": "forest", "entry": "south", "health": -1,
			"flags": ["heard_of_shrine"]})
	assert_not_null(adventure)
	assert_false(adventure.has_checkpoint())


func test_an_invalid_version_1_save_is_still_rejected() -> void:
	var v1 := {"version": 1, "area": "forest", "entry": "south", "health": -1, "flags": []}
	for field in ["area", "entry", "health", "flags"]:
		var missing := v1.duplicate()
		missing.erase(field)
		assert_null(Adventure.from_dict(missing), "%s is missing" % field)
	assert_null(Adventure.from_dict(_with(v1, "flags", "forest_shrine_awakened")))


func test_only_known_versions_are_readable() -> void:
	assert_false(Adventure.reads_version(0))
	assert_true(Adventure.reads_version(1))
	assert_true(Adventure.reads_version(Adventure.FORMAT_VERSION))
	assert_false(Adventure.reads_version(Adventure.FORMAT_VERSION + 1))


func _with(data: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := data.duplicate()
	copy[key] = value
	return copy
