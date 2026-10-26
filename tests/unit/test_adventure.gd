extends GutTest
## Adventure state as plain data: flags, return points and validated (de)serialisation.


func test_starts_in_the_village_with_full_health_and_no_flags() -> void:
	var adventure := Adventure.new()
	assert_eq(adventure.area, &"village")
	assert_eq(adventure.entry, &"start")
	assert_eq(adventure.health, Adventure.FULL_HEALTH)
	assert_eq(adventure.flags(), [])


func test_flags_are_set_once_and_announce_the_change() -> void:
	var adventure := Adventure.new()
	watch_signals(adventure)
	adventure.set_flag(&"shrine_awakened")
	adventure.set_flag(&"shrine_awakened")
	assert_true(adventure.has_flag(&"shrine_awakened"))
	assert_signal_emit_count(adventure, "changed", 1)


func test_round_trip_through_a_dictionary() -> void:
	var adventure := Adventure.new(&"forest", &"shrine")
	adventure.health = 7
	adventure.set_flag(&"heard_of_shrine")
	adventure.set_flag(&"shrine_awakened")
	var copy := Adventure.from_dict(JSON.parse_string(JSON.stringify(adventure.to_dict())))
	assert_not_null(copy)
	assert_eq(copy.area, &"forest")
	assert_eq(copy.entry, &"shrine")
	assert_eq(copy.health, 7)
	assert_true(copy.has_flag(&"heard_of_shrine") and copy.has_flag(&"shrine_awakened"))


func test_rejects_data_that_is_not_an_adventure() -> void:
	var good := Adventure.new().to_dict()
	var broken: Array = [
		null, [], "save",
		_with(good, "version", 99), _with(good, "version", "1"), _with(good, "version", 1.5),
		_with(good, "area", ""), _with(good, "area", 3), _with(good, "entry", null),
		_with(good, "health", -2), _with(good, "health", 2.5), _with(good, "health", "full"),
		_with(good, "flags", "shrine"), _with(good, "flags", [1]), _with(good, "flags", [""]),
	]
	for data: Variant in broken:
		assert_null(Adventure.from_dict(data), str(data))
	var missing := good.duplicate()
	missing.erase("entry")
	assert_null(Adventure.from_dict(missing), "a field is missing")


func test_ignores_unknown_keys() -> void:
	assert_not_null(Adventure.from_dict(_with(Adventure.new().to_dict(), "later_feature", true)))


func _with(data: Dictionary, key: String, value: Variant) -> Dictionary:
	var copy := data.duplicate()
	copy[key] = value
	return copy
