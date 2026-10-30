extends GutTest
## The item catalog and its stable ids, the bag (quantities, stacks, capacity), the equipment rules
## (slots, compatibility, two rings, the main hand), the derived statistics (weight bands,
## defence, firmness, attack, healing) and the save format (version 4, upgrades from 1, 2 and 3).

const GLOVES := &"crew_gloves"
const SWORD := &"wayfarer_sword"
## The hero scene's own health (3 hearts).
const BASE_HEALTH := 12


func _with(ids: Array) -> Adventure:
	var adventure := Adventure.new()
	for id: StringName in ids:
		adventure.add_item(id)
	return adventure


func _v3(items: Array, equipment: Dictionary) -> Dictionary:
	return {"version": 3, "area": "forest", "entry": "shrine", "checkpoint": {"area": "forest", "entry": "shrine"},
			"health": 9, "flags": ["forest_shrine_awakened", "heart_vessel_ruin"], "items": items, "equipment": equipment}


func _round_trip(adventure: Adventure) -> Adventure:
	return Adventure.from_dict(JSON.parse_string(JSON.stringify(adventure.to_dict())))


func _profile(adventure: Adventure) -> HeroLoadout.Profile:
	return HeroLoadout.profile(adventure, BASE_HEALTH)


func test_the_catalog_holds_33_pieces_of_equipment_and_8_stackables() -> void:
	var equipment := 0
	var stackables := 0
	for id: StringName in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		assert_not_null(item, String(id))
		assert_eq(item.id, id, "the file's id is the catalog's")
		assert_true(ItemCatalog.CATEGORIES.has(item.category), "%s has a known category" % id)
		assert_eq(item.icon.get_size(), Vector2(16, 16), "%s has a 16x16 icon" % id)
		assert_ne(tr(item.name_key), item.name_key, "%s has a name" % id)
		assert_ne(tr(item.description_key), item.description_key, "%s has a description" % id)
		if item.is_equippable():
			equipment += 1
			assert_true(ItemCatalog.SLOT_KINDS.values().has(item.slot), "%s goes in a known slot" % id)
			assert_gt(item.weight, 0.0, "%s weighs something" % id)
			assert_eq(item.stack_limit, 1)
			assert_true(not item.modifiers.is_empty() or item.attack != null, "%s does something" % id)
			for modifier in item.modifiers:
				assert_true(HeroStats.MINIMUM.has(modifier.stat), "%s changes a known statistic" % id)
		else:
			stackables += 1
			assert_gt(item.stack_limit, 1, "%s stacks" % id)
			assert_eq(item.weight, 0.0)
	assert_eq(equipment, 33)
	assert_eq(stackables, 8)


func test_every_slot_has_items_and_every_weapon_its_own_swing_and_frames() -> void:
	var per_kind := {}
	for id: StringName in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		per_kind[item.slot] = per_kind.get(item.slot, 0) + 1
		if item.slot == &"main_hand":
			assert_not_null(item.attack, "%s swings" % id)
			assert_not_null(item.attack_sheet, "%s has attack frames" % id)
			assert_eq(item.attack_sheet.get_size(), Vector2(120, 160))
	assert_eq(per_kind, {&"main_hand": 6, &"off_hand": 4, &"head": 4, &"torso": 4, &"hands": 4, &"legs": 4,
			&"ring": 4, &"accessory": 3, &"": 8})


func test_the_ids_written_in_saves_stay_put() -> void:
	assert_true(ItemCatalog.knows(GLOVES))
	assert_eq(ItemCatalog.find(GLOVES).slot, &"accessory", "the gloves stay accessories (7.0 saves)")
	assert_eq(ItemCatalog.SLOTS, [&"main_hand", &"off_hand", &"head", &"torso", &"hands", &"legs", &"ring_1",
			&"ring_2", &"accessory"] as Array[StringName])
	assert_eq(Adventure.STARTING_WEAPON, SWORD)


func test_weapons_trade_speed_reach_and_force() -> void:
	var machete := ItemCatalog.find(&"crew_machete").attack
	var maul := ItemCatalog.find(&"quarry_maul").attack
	var staff := ItemCatalog.find(&"traveller_staff").attack
	var sword := ItemCatalog.find(SWORD).attack
	assert_lt(machete.duration(), sword.duration(), "the machete is quicker")
	assert_lt(machete.knockback, sword.knockback, "but pushes less")
	assert_gt(maul.damage, sword.damage, "the maul hits harder")
	assert_gt(maul.duration(), sword.duration() * 1.5, "and much slower")
	assert_gt(staff.reach, sword.reach, "the staff reaches further")
	for id: StringName in ItemCatalog.ITEMS:
		var attack := ItemCatalog.find(id).attack
		if attack != null:
			assert_gt(attack.recovery, 0.0, "%s always recovers" % id)
			assert_lte(attack.damage, 2, "%s never trivialises the old enemies" % id)


func test_a_new_adventure_holds_the_sword() -> void:
	var adventure := Adventure.new()
	assert_eq(adventure.items(), [SWORD] as Array[StringName])
	assert_eq(adventure.equipped(ItemCatalog.MAIN_HAND), SWORD)
	assert_eq(Bag.spaces_used(adventure), 0, "worn pieces take no space")


func test_quantities_add_and_take_away() -> void:
	var adventure := Adventure.new()
	assert_true(adventure.add_item(&"corn_bread", 3))
	assert_true(adventure.add_item(&"corn_bread", 2))
	assert_eq(adventure.count(&"corn_bread"), 5)
	assert_false(adventure.add_item(&"corn_bread", 0))
	assert_false(adventure.add_item(&"corn_bread", -2))
	assert_true(adventure.remove_item(&"corn_bread", 4))
	assert_false(adventure.remove_item(&"corn_bread", 2), "not more than there is")
	assert_true(adventure.remove_item(&"corn_bread"))
	assert_false(adventure.has_item(&"corn_bread"), "gone at zero")
	assert_false(adventure.remove_item(SWORD), "never a piece still worn")


func test_stacks_share_spaces_up_to_their_limit() -> void:
	var adventure := Adventure.new()
	adventure.add_item(&"pine_resin", 20)
	assert_eq(Bag.spaces_used(adventure), 1)
	adventure.add_item(&"pine_resin", 1)
	assert_eq(Bag.spaces_used(adventure), 2, "a 21st opens a second stack")
	adventure.add_item(&"herb_tea", 3)
	assert_eq(Bag.spaces_used(adventure), 3)
	adventure.add_item(&"bark_shield")
	adventure.add_item(&"bark_shield")
	assert_eq(Bag.spaces_used(adventure), 5, "each loose piece of equipment takes one")


func test_the_bag_refuses_what_does_not_fit_and_keeps_everything() -> void:
	var adventure := Adventure.new()
	for i in Bag.CAPACITY - 1:
		adventure.add_item(&"straw_hat")
	assert_true(Bag.try_add(adventure, &"wild_honey", 10), "the last space")
	assert_eq(Bag.free_spaces(adventure), 0)
	assert_false(Bag.try_add(adventure, &"bark_shield"), "no room for a piece")
	assert_false(Bag.try_add(adventure, &"herb_tea"), "nor a new stack")
	assert_false(Bag.try_add(adventure, &"wild_honey"), "nor past a full stack")
	assert_false(adventure.has_item(&"bark_shield"))
	assert_eq(adventure.count(&"wild_honey"), 10, "nothing lost")
	assert_true(Equipment.equip(adventure, ItemCatalog.HEAD, &"straw_hat"), "wearing one frees a space")
	assert_true(Bag.try_add(adventure, &"herb_tea"))
	assert_false(Equipment.can_unequip(adventure, ItemCatalog.HEAD), "and the bag is full again: it stays on")
	assert_false(Bag.try_add(adventure, &"lantern_of_tomorrow"), "unknown items are never added")


func test_slots_take_only_their_kind() -> void:
	var adventure := _with([&"bark_shield", &"straw_hat", &"root_ring", GLOVES, &"corn_bread"])
	assert_false(Equipment.equip(adventure, ItemCatalog.HEAD, &"bark_shield"))
	assert_false(Equipment.equip(adventure, ItemCatalog.MAIN_HAND, &"bark_shield"))
	assert_false(Equipment.equip(adventure, ItemCatalog.HANDS, GLOVES), "the crew gloves are an accessory")
	assert_false(Equipment.equip(adventure, ItemCatalog.ACCESSORY, &"corn_bread"))
	assert_false(Equipment.equip(adventure, &"tail", &"straw_hat"))
	assert_false(Equipment.equip(adventure, ItemCatalog.HEAD, &"crew_vest"), "nor what the hero lacks")
	assert_true(Equipment.equip(adventure, ItemCatalog.OFF_HAND, &"bark_shield"))
	assert_true(Equipment.equip(adventure, ItemCatalog.HEAD, &"straw_hat"))
	assert_true(Equipment.equip(adventure, ItemCatalog.RING_2, &"root_ring"))
	assert_true(Equipment.equip(adventure, ItemCatalog.ACCESSORY, GLOVES))
	assert_eq(Equipment.candidates(adventure, ItemCatalog.RING_1), [&"root_ring"] as Array[StringName])


func test_equipping_replaces_and_taking_off_keeps() -> void:
	var adventure := _with([&"straw_hat", &"quarry_helm"])
	Equipment.equip(adventure, ItemCatalog.HEAD, &"straw_hat")
	assert_true(Equipment.equip(adventure, ItemCatalog.HEAD, &"quarry_helm"))
	assert_eq(adventure.equipped(ItemCatalog.HEAD), &"quarry_helm")
	assert_true(adventure.has_item(&"straw_hat"), "the hat goes back to the bag")
	assert_true(Equipment.unequip(adventure, ItemCatalog.HEAD))
	assert_true(adventure.has_item(&"quarry_helm"), "and the helm too")
	assert_false(Equipment.unequip(adventure, ItemCatalog.HEAD), "nothing left to take off")


func test_the_main_hand_is_never_empty() -> void:
	var adventure := _with([&"crew_machete"])
	assert_false(Equipment.can_unequip(adventure, ItemCatalog.MAIN_HAND))
	assert_true(Equipment.equip(adventure, ItemCatalog.MAIN_HAND, &"crew_machete"))
	assert_eq(Bag.spaces_used(adventure), 1, "the sword is back in the bag")


func test_two_rings_alike_need_two_copies() -> void:
	var adventure := _with([&"whitestone_ring"])
	assert_true(Equipment.equip(adventure, ItemCatalog.RING_1, &"whitestone_ring"))
	assert_false(Equipment.equip(adventure, ItemCatalog.RING_2, &"whitestone_ring"), "one copy, one finger")
	assert_eq(Equipment.slot_for(adventure, ItemCatalog.find(&"root_ring")), ItemCatalog.RING_2, "the free ring slot")
	adventure.add_item(&"whitestone_ring")
	assert_true(Equipment.equip(adventure, ItemCatalog.RING_2, &"whitestone_ring"))
	assert_eq(adventure.equipped_copies(&"whitestone_ring"), 2)
	assert_eq(_profile(adventure).value(HeroStats.DEFENSE), 10.0, "both count")
	assert_false(adventure.remove_item(&"whitestone_ring"), "neither can be dropped while worn")


func test_stats_combine_adds_then_summed_percentages_in_any_order() -> void:
	var a := StatModifier.new()
	a.stat = HeroStats.KNOCKBACK
	a.kind = StatModifier.Kind.PERCENT
	a.value = 50.0
	var b := StatModifier.new()
	b.stat = HeroStats.KNOCKBACK
	b.value = 10.0
	var c := StatModifier.new()
	c.stat = HeroStats.KNOCKBACK
	c.kind = StatModifier.Kind.PERCENT
	c.value = 15.0
	assert_eq(HeroStats.combine(150.0, HeroStats.KNOCKBACK, [a, b, c] as Array[StatModifier]), 160.0 * 1.65)
	assert_eq(HeroStats.combine(150.0, HeroStats.KNOCKBACK, [c, b, a] as Array[StatModifier]), 160.0 * 1.65)
	assert_eq(HeroStats.combine(150.0, HeroStats.KNOCKBACK, [null] as Array[StatModifier]), 150.0)


func test_stats_stay_within_their_bounds() -> void:
	var huge := StatModifier.new()
	huge.stat = HeroStats.DEFENSE
	huge.value = 400.0
	assert_eq(HeroStats.combine(0.0, HeroStats.DEFENSE, [huge] as Array[StatModifier]), 50.0, "defence caps at half")
	var slow := StatModifier.new()
	slow.stat = HeroStats.SPEED
	slow.value = -400.0
	assert_eq(HeroStats.combine(0.0, HeroStats.SPEED, [slow] as Array[StatModifier]), -30.0, "never stopped dead")
	var quick := StatModifier.new()
	quick.stat = HeroStats.SWING
	quick.value = -400.0
	assert_eq(HeroStats.combine(100.0, HeroStats.SWING, [quick] as Array[StatModifier]), 50.0, "swings always recover")


func test_the_starting_kit_changes_nothing() -> void:
	var profile := _profile(Adventure.new())
	var sword := ItemCatalog.find(SWORD).attack
	assert_eq(profile.max_health(), BASE_HEALTH)
	assert_eq(profile.attack.damage, sword.damage)
	assert_eq(profile.attack.knockback, sword.knockback)
	assert_eq(profile.attack.duration(), sword.duration())
	assert_eq(profile.band, HeroStats.LIGHT)
	assert_eq(profile.speed_factor(), 1.0, "the hero moves as before")
	assert_eq(profile.value(HeroStats.DEFENSE), 0.0)


func test_light_balanced_and_heavy_kits() -> void:
	var light := _with([&"crew_machete", &"bark_shield", &"straw_hat", &"padded_doublet", &"moss_wraps", &"rope_sandals"])
	var balanced := _with([&"traveller_shield", &"traveller_hood", &"traveller_coat", &"traveller_bracers", &"traveller_boots"])
	var heavy := _with([&"quarry_maul", &"crew_board_shield", &"quarry_helm", &"quarry_breastplate", &"quarry_gauntlets",
			&"quarry_greaves"])
	for kit: Adventure in [light, balanced, heavy]:
		for id in kit.items():
			var item := ItemCatalog.find(id)
			if item.is_equippable():
				Equipment.equip(kit, Equipment.slot_for(kit, item), id)
	var l := _profile(light)
	var b := _profile(balanced)
	var h := _profile(heavy)
	assert_eq(l.band, HeroStats.LIGHT)
	assert_eq(b.band, HeroStats.NORMAL)
	assert_eq(h.band, HeroStats.OVERLOADED)
	assert_gt(l.speed_factor(), b.speed_factor())
	assert_gt(b.speed_factor(), h.speed_factor())
	assert_gte(h.speed_factor(), 0.6, "heavy is slow, never stuck")
	assert_lt(l.value(HeroStats.DEFENSE), b.value(HeroStats.DEFENSE))
	assert_lt(b.value(HeroStats.DEFENSE), h.value(HeroStats.DEFENSE))
	assert_lte(h.value(HeroStats.DEFENSE), 50.0)
	assert_gt(h.value(HeroStats.POISE), b.value(HeroStats.POISE))
	assert_lt(l.swing_seconds(), h.swing_seconds(), "the machete swings quicker than the maul")
	assert_eq(h.attack.damage, 2)
	assert_almost_eq(h.attack.knockback, 240.0 * 1.15, 0.01, "the gauntlets add to the maul's push")


func test_every_defence_piece_at_once_stays_under_the_cap() -> void:
	var adventure := Adventure.new()
	for id: StringName in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		if item.is_equippable():
			adventure.add_item(id)
	adventure.add_item(&"whitestone_ring")
	for pair: Array in [[ItemCatalog.OFF_HAND, &"crew_board_shield"], [ItemCatalog.HEAD, &"quarry_helm"],
			[ItemCatalog.TORSO, &"quarry_breastplate"], [ItemCatalog.HANDS, &"quarry_gauntlets"],
			[ItemCatalog.LEGS, &"quarry_greaves"], [ItemCatalog.RING_1, &"whitestone_ring"],
			[ItemCatalog.RING_2, &"whitestone_ring"]]:
		assert_true(Equipment.equip(adventure, pair[0], pair[1]), str(pair))
	assert_eq(_profile(adventure).value(HeroStats.DEFENSE), 41.0)


func test_defence_takes_part_of_each_hit_and_carries_the_rest() -> void:
	var health := Health.new()
	add_child_autofree(health)
	health.max_health = 40
	health.restore_full()
	health.defense_percent = 25.0
	var taken: Array[int] = []
	for i in 4:
		var before := health.current
		health.take_damage(2)
		taken.append(before - health.current)
	assert_eq(taken, [1, 2, 1, 2] as Array[int], "a quarter of 2, carried over")
	health.defense_percent = 50.0
	var before := health.current
	health.take_damage(1)
	assert_eq(before - health.current, 1, "a hit always takes at least a quarter")
	health.defense_percent = 0.0
	before = health.current
	health.take_damage(2)
	assert_eq(before - health.current, 2, "no defence, no change")


func test_health_rings_and_the_circlet_add_hearts() -> void:
	var adventure := _with([&"root_ring", &"ruin_circlet"])
	Equipment.equip(adventure, ItemCatalog.RING_1, &"root_ring")
	Equipment.equip(adventure, ItemCatalog.HEAD, &"ruin_circlet")
	assert_eq(_profile(adventure).max_health(), BASE_HEALTH + 8)


func test_the_herb_pouch_makes_food_heal_more() -> void:
	var adventure := _with([&"herb_pouch"])
	var bread := ItemCatalog.find(&"corn_bread")
	assert_eq(HeroLoadout.heal_amount(_profile(adventure), bread), 4)
	Equipment.equip(adventure, ItemCatalog.ACCESSORY, &"herb_pouch")
	assert_eq(HeroLoadout.heal_amount(_profile(adventure), bread), 6)


func test_using_food_heals_and_spends_one_only_when_needed() -> void:
	var adventure := Adventure.new()
	adventure.add_item(&"corn_bread", 2)
	var health := Health.new()
	add_child_autofree(health)
	health.max_health = 12
	health.restore_full()
	var profile := _profile(adventure)
	assert_false(HeroLoadout.use(adventure, profile, health, &"corn_bread"), "not at full health")
	assert_eq(adventure.count(&"corn_bread"), 2, "nothing spent")
	health.take_damage(6)
	assert_true(HeroLoadout.use(adventure, profile, health, &"corn_bread"))
	assert_eq(health.current, 10)
	assert_eq(adventure.count(&"corn_bread"), 1)
	assert_false(HeroLoadout.use(adventure, profile, health, &"pine_resin"), "materials are not eaten")
	assert_false(HeroLoadout.use(adventure, profile, health, &"herb_tea"), "nor what the hero has not")


func test_comparing_shows_the_change_without_making_it() -> void:
	var adventure := _with([&"quarry_helm"])
	var now := _profile(adventure)
	var then := HeroLoadout.profile_if(adventure, BASE_HEALTH, ItemCatalog.HEAD, &"quarry_helm")
	assert_eq(now.value(HeroStats.DEFENSE), 0.0)
	assert_eq(then.value(HeroStats.DEFENSE), 5.0)
	assert_gt(then.carried, now.carried)
	assert_eq(adventure.equipped(ItemCatalog.HEAD), &"", "nothing was put on")


func test_format_4_round_trip() -> void:
	var adventure := _with([&"whitestone_ring", &"whitestone_ring", GLOVES])
	adventure.add_item(&"pine_resin", 7)
	Equipment.equip(adventure, ItemCatalog.RING_1, &"whitestone_ring")
	Equipment.equip(adventure, ItemCatalog.RING_2, &"whitestone_ring")
	Equipment.equip(adventure, ItemCatalog.ACCESSORY, GLOVES)
	var data := adventure.to_dict()
	assert_eq(data["version"], 4)
	assert_false(data.has("items"), "the old list is gone")
	var back := _round_trip(adventure)
	assert_eq(back.items(), adventure.items())
	assert_eq(back.count(&"whitestone_ring"), 2)
	assert_eq(back.count(&"pine_resin"), 7)
	assert_eq(back.equipment(), adventure.equipment())


func test_a_version_3_save_gains_the_sword_and_keeps_its_gloves() -> void:
	var adventure := Adventure.from_dict(JSON.parse_string(JSON.stringify(_v3(["crew_gloves"], {"accessory": "crew_gloves"}))))
	assert_not_null(adventure)
	assert_eq(adventure.count(GLOVES), 1, "never doubled")
	assert_eq(adventure.equipped(ItemCatalog.ACCESSORY), GLOVES, "still worn, still an accessory")
	assert_eq(adventure.equipped(ItemCatalog.MAIN_HAND), SWORD, "the sword the hero always held")
	assert_eq(adventure.count(SWORD), 1)
	assert_true(adventure.has_flag(&"found_slope_crew_gloves"), "their pickup was taken")
	assert_eq(adventure.health, 9)
	assert_true(adventure.has_flag(&"heart_vessel_ruin"))
	assert_eq(adventure.to_dict()["version"], 4)


func test_versions_1_and_2_upgrade_through_3() -> void:
	var v1 := {"version": 1, "area": "village", "entry": "north", "health": -1, "flags": ["forest_shrine_awakened"]}
	var v2 := {"version": 2, "area": "forest", "entry": "shrine", "checkpoint": null, "health": 7, "flags": []}
	for data: Dictionary in [v1, v2]:
		var adventure := Adventure.from_dict(JSON.parse_string(JSON.stringify(data)))
		assert_not_null(adventure, str(data["version"]))
		assert_eq(adventure.items(), [SWORD] as Array[StringName])
		assert_eq(adventure.equipped(ItemCatalog.MAIN_HAND), SWORD)
		assert_false(adventure.has_flag(&"found_slope_crew_gloves"))


func test_unknown_items_are_kept_and_do_nothing() -> void:
	var adventure := Adventure.from_dict(_v3(["crew_gloves", "lantern_of_tomorrow"], {"accessory": "lantern_of_tomorrow"}))
	assert_true(adventure.has_item(&"lantern_of_tomorrow"))
	assert_eq(_profile(adventure).value(HeroStats.KNOCKBACK), 150.0, "worn by nobody")
	assert_eq(Bag.spaces_used(adventure), 1, "the loose gloves take a space; the worn unknown one none")
	var data := adventure.to_dict()
	assert_true((data["inventory"] as Array).has({"id": "lantern_of_tomorrow", "count": 1}))
	var odd := Adventure.from_dict({"version": 4, "area": "forest", "entry": "shrine", "checkpoint": null, "health": -1,
			"flags": [], "inventory": [{"id": "wayfarer_sword", "count": 1}], "equipment": {"main_hand": "crew_gloves"}})
	assert_not_null(odd)
	assert_push_warning("without a copy to spare")
	assert_eq(Equipment.weapon(odd).id, SWORD, "an unusable main hand falls back to the sword")


func test_malformed_saves_are_unreadable() -> void:
	var base := {"version": 4, "area": "forest", "entry": "shrine", "checkpoint": null, "health": -1, "flags": [],
			"inventory": [{"id": "wayfarer_sword", "count": 1}], "equipment": {"main_hand": "wayfarer_sword"}}
	assert_not_null(Adventure.from_dict(base))
	for bad: Array in [["inventory", [{"id": "corn_bread", "count": 0}]], ["inventory", [{"id": "", "count": 1}]],
			["inventory", [{"id": "corn_bread", "count": 1.5}]], ["inventory", ["corn_bread"]],
			["inventory", {"corn_bread": 1}], ["equipment", {"head": 3}], ["equipment", ["straw_hat"]]]:
		var data := base.duplicate(true)
		data[bad[0]] = bad[1]
		assert_null(Adventure.from_dict(data), str(bad))
	assert_null(Adventure.from_dict(_v3([7], {})), "a broken version 3 item list")
	assert_null(Adventure.from_dict(_v3([""], {})))
	var missing := _v3([], {})
	missing.erase("items")
	assert_null(Adventure.from_dict(missing))


func test_repeated_stacks_in_a_save_add_up() -> void:
	var data := {"version": 4, "area": "forest", "entry": "shrine", "checkpoint": null, "health": -1, "flags": [],
			"inventory": [{"id": "corn_bread", "count": 2}, {"id": "corn_bread", "count": 1}], "equipment": {}}
	assert_eq(Adventure.from_dict(data).count(&"corn_bread"), 3)
