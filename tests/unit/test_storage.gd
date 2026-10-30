extends GutTest
## The chest at home as rules and record: what goes in and out (whole pieces, stacks, part of a
## stack), its capacity and the bag's, worn pieces and the main hand, unknown items, moves that
## happen whole or not at all (nothing doubled, nothing lost), and the save format (version 5: the
## chest's contents, upgrades from every older version with an empty chest).

const SWORD := &"wayfarer_sword"
const BREAD := &"corn_bread"
const RESIN := &"pine_resin"
const HELM := &"quarry_helm"
const FIXTURES := "res://tests/fixtures/saves"


func _with(items: Dictionary) -> Adventure:
	var adventure := Adventure.new()  # starts with the sword in hand
	assert_eq(adventure.equipped(ItemCatalog.MAIN_HAND), SWORD)
	for id: StringName in items:
		adventure.add_item(id, items[id])
	return adventure


func _round_trip(adventure: Adventure) -> Adventure:
	return Adventure.from_dict(JSON.parse_string(JSON.stringify(adventure.to_dict())))


## Every copy the hero has plus every copy in the chest.
func _total(adventure: Adventure, id: StringName) -> int:
	return adventure.count(id) + adventure.stored(id)


func test_capacities() -> void:
	assert_eq(Bag.CAPACITY, 40, "the bag stays as it was")
	assert_eq(Storage.CAPACITY, 80)


func test_a_piece_goes_in_and_comes_back() -> void:
	var adventure := _with({HELM: 1})
	assert_eq(Storage.store(adventure, HELM, 1), Storage.Result.MOVED)
	assert_eq(adventure.count(HELM), 0, "no longer carried")
	assert_false(adventure.has_item(HELM))
	assert_eq(adventure.stored(HELM), 1)
	assert_eq(adventure.stored_items(), [HELM] as Array[StringName])
	assert_eq(Storage.spaces_used(adventure), 1)
	assert_false(Equipment.can_equip(adventure, ItemCatalog.HEAD, HELM), "what is in the chest cannot be worn")
	assert_eq(Storage.retrieve(adventure, HELM, 1), Storage.Result.MOVED)
	assert_eq(adventure.count(HELM), 1)
	assert_eq(adventure.stored(HELM), 0)
	assert_eq(adventure.stored_items(), [] as Array[StringName], "an emptied stack leaves the chest")
	assert_true(Equipment.equip(adventure, ItemCatalog.HEAD, HELM))


func test_part_of_a_stack_moves_and_the_rest_stays() -> void:
	var adventure := _with({BREAD: 5, RESIN: 12})
	assert_eq(Storage.store(adventure, BREAD, 2), Storage.Result.MOVED)
	assert_eq(adventure.count(BREAD), 3)
	assert_eq(adventure.stored(BREAD), 2)
	assert_eq(Storage.store(adventure, BREAD, 3), Storage.Result.MOVED)
	assert_eq(adventure.stored(BREAD), 5, "stacks add up in the chest")
	assert_eq(Storage.retrieve(adventure, BREAD, 1), Storage.Result.MOVED)
	assert_eq(adventure.count(BREAD), 1)
	assert_eq(adventure.stored(BREAD), 4)
	assert_eq(Storage.store(adventure, RESIN, 13), Storage.Result.NOTHING, "never more than carried")
	assert_eq(Storage.retrieve(adventure, BREAD, 5), Storage.Result.NOTHING, "never more than kept")
	assert_eq(Storage.store(adventure, RESIN, 0), Storage.Result.NOTHING)
	assert_eq(Storage.store(adventure, RESIN, -2), Storage.Result.NOTHING)
	assert_eq(_total(adventure, BREAD), 5, "nothing doubled, nothing lost")
	assert_eq(_total(adventure, RESIN), 12)


func test_the_chest_counts_spaces_by_stack_limit() -> void:
	var adventure := _with({BREAD: 11, RESIN: 21})
	Storage.store(adventure, BREAD, 11)
	Storage.store(adventure, RESIN, 21)
	assert_eq(Storage.spaces_used(adventure), 3 + 2, "bread stacks by 5, resin by 20")
	assert_eq(Storage.free_spaces(adventure), Storage.CAPACITY - 5)


func test_a_full_chest_refuses_and_keeps_everything() -> void:
	var adventure := _with({RESIN: 20 * Storage.CAPACITY + 1, BREAD: 1})
	assert_eq(Storage.store(adventure, RESIN, 20 * Storage.CAPACITY), Storage.Result.MOVED)
	assert_eq(Storage.free_spaces(adventure), 0)
	assert_eq(Storage.store(adventure, BREAD, 1), Storage.Result.CHEST_FULL)
	assert_eq(adventure.count(BREAD), 1, "the refused bread is still carried")
	assert_eq(Storage.store(adventure, RESIN, 1), Storage.Result.CHEST_FULL, "a new stack needs a new space")
	assert_eq(_total(adventure, RESIN), 20 * Storage.CAPACITY + 1)
	assert_eq(Storage.most_to_store(adventure, RESIN), 0)


func test_a_full_bag_refuses_and_the_chest_keeps_it() -> void:
	var adventure := _with({BREAD: 1, RESIN: 20 * Bag.CAPACITY})
	assert_eq(Storage.store(adventure, BREAD, 1), Storage.Result.MOVED)
	assert_eq(Bag.free_spaces(adventure), 0)
	assert_eq(Storage.retrieve(adventure, BREAD, 1), Storage.Result.BAG_FULL)
	assert_eq(adventure.stored(BREAD), 1, "still in the chest")
	assert_eq(adventure.count(BREAD), 0)
	assert_eq(Storage.most_to_retrieve(adventure, BREAD), 0)


func test_the_most_that_fits_is_offered() -> void:
	var adventure := _with({RESIN: 20 * (Bag.CAPACITY - 1) + 15, BREAD: 9})
	Storage.store(adventure, BREAD, 9)
	assert_eq(Bag.free_spaces(adventure), 0, "39 full stacks and one of 15")
	assert_eq(Storage.most_to_retrieve(adventure, BREAD), 0)
	Storage.store(adventure, RESIN, 15)
	assert_eq(Storage.most_to_retrieve(adventure, BREAD), 5, "one stack of bread fits in the space freed")
	assert_eq(Storage.check_retrieve(adventure, BREAD, 9), Storage.Result.BAG_FULL)


func test_worn_pieces_stay_until_taken_off() -> void:
	var adventure := _with({HELM: 1})
	Equipment.equip(adventure, ItemCatalog.HEAD, HELM)
	assert_eq(Storage.store(adventure, HELM, 1), Storage.Result.WORN)
	assert_eq(adventure.equipped(ItemCatalog.HEAD), HELM, "still worn")
	assert_eq(Storage.store(adventure, SWORD, 1), Storage.Result.WORN, "the main hand is never emptied")
	assert_eq(adventure.equipped(ItemCatalog.MAIN_HAND), SWORD)
	assert_true(Equipment.unequip(adventure, ItemCatalog.HEAD))
	assert_eq(Storage.store(adventure, HELM, 1), Storage.Result.MOVED, "once taken off it goes")


func test_a_spare_copy_of_a_worn_item_can_go() -> void:
	var adventure := _with({&"whitestone_ring": 2})
	Equipment.equip(adventure, ItemCatalog.RING_1, &"whitestone_ring")
	assert_eq(Storage.loose(adventure, &"whitestone_ring"), 1)
	assert_eq(Storage.store(adventure, &"whitestone_ring", 2), Storage.Result.NOTHING, "not the worn one too")
	assert_eq(Storage.store(adventure, &"whitestone_ring", 1), Storage.Result.MOVED)
	assert_eq(adventure.equipped(ItemCatalog.RING_1), &"whitestone_ring", "the worn ring stays worn")
	assert_eq(adventure.count(&"whitestone_ring"), 1)


func test_unknown_items_go_in_and_out_and_are_never_dropped() -> void:
	var adventure := _with({})
	adventure.add_item(&"lantern_of_tomorrow", 2)
	assert_eq(Storage.store(adventure, &"lantern_of_tomorrow", 2), Storage.Result.MOVED)
	assert_eq(Storage.spaces_used(adventure), 2, "one space per copy")
	var back := _round_trip(adventure)
	assert_eq(back.stored(&"lantern_of_tomorrow"), 2, "kept through a save")
	assert_eq(Storage.retrieve(back, &"lantern_of_tomorrow", 1), Storage.Result.MOVED)
	assert_eq(_total(back, &"lantern_of_tomorrow"), 2)


func test_one_move_is_one_change() -> void:
	var adventure := _with({BREAD: 4})
	var changes := [0]
	adventure.changed.connect(func() -> void: changes[0] += 1)
	Storage.store(adventure, BREAD, 3)
	assert_eq(changes[0], 1, "one save, never half a move")
	Storage.store(adventure, BREAD, 9)
	assert_eq(changes[0], 1, "a refused move changes nothing")
	Storage.retrieve(adventure, BREAD, 3)
	assert_eq(changes[0], 2)


func test_many_moves_never_double_or_lose_anything() -> void:
	var adventure := _with({BREAD: 7, RESIN: 33, HELM: 1, &"wild_honey": 4})
	var ids: Array[StringName] = [BREAD, RESIN, HELM, &"wild_honey"]
	var totals := {}
	for id in ids:
		totals[id] = _total(adventure, id)
	var random := RandomNumberGenerator.new()
	random.seed = 72
	for i in 400:
		var id := ids[random.randi() % ids.size()]
		var amount := random.randi_range(-1, 9)
		if random.randf() < 0.5:
			Storage.store(adventure, id, amount)
		else:
			Storage.retrieve(adventure, id, amount)
		if i % 50 == 0:
			adventure = _round_trip(adventure)
	for id in ids:
		assert_eq(_total(adventure, id), totals[id], String(id))
	assert_lte(Storage.spaces_used(adventure), Storage.CAPACITY)
	assert_lte(Bag.spaces_used(adventure), Bag.CAPACITY)


func test_the_quick_item_falls_back_when_its_food_is_put_away() -> void:
	var adventure := _with({BREAD: 2, &"wild_honey": 1})
	adventure.set_quick_item(BREAD)
	Storage.store(adventure, BREAD, 2)
	assert_eq(adventure.quick_item, BREAD, "the choice is remembered")
	assert_false(adventure.has_item(BREAD), "but there is none to eat until it is taken back")


func test_format_5_round_trip() -> void:
	var adventure := _with({BREAD: 6, HELM: 1})
	Storage.store(adventure, BREAD, 4)
	Storage.store(adventure, HELM, 1)
	var data := adventure.to_dict()
	assert_eq(data["version"], 5)
	assert_eq(data["storage"], [{"id": "corn_bread", "count": 4}, {"id": "quarry_helm", "count": 1}])
	var back := _round_trip(adventure)
	assert_eq(back.stored_items(), adventure.stored_items())
	assert_eq(back.stored(BREAD), 4)
	assert_eq(back.count(BREAD), 2)
	assert_eq(back.stored(HELM), 1)
	assert_false(back.has_item(HELM))


func test_a_version_4_save_gets_an_empty_chest_and_keeps_the_rest() -> void:
	var text := FileAccess.get_file_as_string(FIXTURES.path_join("v4_quarry_kit.json"))
	var before: Dictionary = JSON.parse_string(text)
	var adventure := Adventure.from_dict(JSON.parse_string(text))
	assert_not_null(adventure)
	assert_eq(adventure.stored_items(), [] as Array[StringName], "nothing in the chest")
	assert_eq(adventure.area, &"village")
	assert_eq(adventure.health, 10)
	assert_eq(adventure.equipped(ItemCatalog.HEAD), HELM)
	assert_eq(adventure.equipped(ItemCatalog.MAIN_HAND), &"woodcutter_hatchet")
	assert_eq(adventure.count(BREAD), 3)
	assert_true(adventure.has_item(&"lantern_of_tomorrow"), "the unknown item is kept")
	assert_eq(adventure.quick_item, BREAD)
	for flag: String in before["flags"]:
		assert_true(adventure.has_flag(StringName(flag)), flag)
	var data := adventure.to_dict()
	assert_eq(data["version"], 5)
	assert_eq(data["storage"], [])
	var stacks: Array = data["inventory"]
	assert_eq(stacks.size(), (before["inventory"] as Array).size())
	for i in stacks.size():
		assert_eq(stacks[i]["id"], before["inventory"][i]["id"], "the stacks as they were, in order")
		assert_eq(int(stacks[i]["count"]), int(before["inventory"][i]["count"]))


func test_every_older_version_upgrades_to_5_with_an_empty_chest() -> void:
	for file_name in ["v1_back_in_village.json", "v2_stall_worked.json", "v3_gloves_worn.json", "v3_unknown_item.json",
			"v4_quarry_kit.json"]:
		var adventure := Adventure.from_dict(JSON.parse_string(FileAccess.get_file_as_string(FIXTURES.path_join(file_name))))
		assert_not_null(adventure, file_name)
		assert_eq(adventure.stored_items().size(), 0, file_name)
		assert_eq(adventure.to_dict()["version"], Adventure.FORMAT_VERSION, file_name)
		assert_eq(adventure.equipped(ItemCatalog.MAIN_HAND).is_empty(), false, "%s holds a weapon" % file_name)


func test_malformed_chests_are_unreadable() -> void:
	var base := _with({}).to_dict()
	assert_not_null(Adventure.from_dict(base))
	for bad: Variant in [[{"id": "corn_bread", "count": 0}], [{"id": "", "count": 1}], [{"id": "corn_bread", "count": 1.5}],
			["corn_bread"], {"corn_bread": 1}, null]:
		var data := base.duplicate(true)
		data["storage"] = bad
		assert_null(Adventure.from_dict(data), str(bad))
	var missing := base.duplicate(true)
	missing.erase("storage")
	assert_null(Adventure.from_dict(missing), "a version 5 save must say what the chest holds")


func test_repeated_stacks_in_the_chest_add_up() -> void:
	var data := _with({}).to_dict()
	data["storage"] = [{"id": "corn_bread", "count": 2}, {"id": "corn_bread", "count": 3}]
	assert_eq(Adventure.from_dict(data).stored(BREAD), 5)
