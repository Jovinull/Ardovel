extends GutTest
## Items by stable id, the hero's derived statistics, and items and equipment in the adventure and
## its save format (version 3, and the upgrades from versions 1 and 2).

const GLOVES := &"crew_gloves"


func _knockback(value: float, kind: StatModifier.Kind = StatModifier.Kind.PERCENT) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat = HeroStats.SWORD_KNOCKBACK
	modifier.kind = kind
	modifier.value = value
	return modifier


func _stats(modifiers: Array[StatModifier]) -> ItemDef:
	var item := ItemDef.new()
	item.modifiers = modifiers
	return item


func _v2() -> Dictionary:
	return {"version": 2, "area": "forest", "entry": "shrine", "checkpoint": {"area": "forest", "entry": "shrine"},
			"health": 9, "flags": ["forest_shrine_awakened", "heart_vessel_ruin"]}


func _v3(items: Array, equipment: Dictionary) -> Dictionary:
	var data := _v2()
	data["version"] = 3
	data["items"] = items
	data["equipment"] = equipment
	return data


func test_every_catalog_id_matches_its_definition() -> void:
	assert_false(ItemCatalog.ITEMS.is_empty())
	for id: StringName in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		assert_not_null(item, String(id))
		assert_eq(item.id, id, "the file's id is the catalog's")
		assert_true(item.slot.is_empty() or ItemCatalog.SLOTS.has(item.slot), "%s goes in a known slot" % id)
		assert_eq(item.icon.get_size(), Vector2(16, 16), "%s has a 16x16 icon" % id)
		for modifier in item.modifiers:
			assert_true(HeroStats.MINIMUM.has(modifier.stat), "%s changes a known statistic" % id)


func test_the_ids_written_in_saves_stay_put() -> void:
	# Saves name items by these ids: renaming one would lose it from every save.
	assert_eq(ItemCatalog.ITEMS.keys(), [GLOVES])
	assert_eq(ItemCatalog.ACCESSORY, &"accessory")
	assert_eq(ItemCatalog.SLOTS, [&"accessory"] as Array[StringName])


func test_the_crew_gloves() -> void:
	var gloves := ItemCatalog.find(GLOVES)
	assert_eq(gloves.slot, ItemCatalog.ACCESSORY)
	assert_true(gloves.is_equippable())
	assert_eq(gloves.modifiers.size(), 1)
	assert_eq(gloves.modifiers[0].stat, HeroStats.SWORD_KNOCKBACK)
	assert_eq(gloves.modifiers[0].kind, StatModifier.Kind.PERCENT)
	assert_eq(gloves.modifiers[0].value, 50.0)


func test_an_unknown_id_finds_nothing() -> void:
	assert_false(ItemCatalog.knows(&"lantern_of_tomorrow"))
	assert_null(ItemCatalog.find(&"lantern_of_tomorrow"))
	assert_null(ItemCatalog.find(&""))


func test_without_modifiers_a_statistic_is_its_base() -> void:
	var none: Array[StatModifier] = []
	assert_eq(HeroStats.combine(150.0, HeroStats.SWORD_KNOCKBACK, none), 150.0)
	assert_eq(HeroStats.combine(1.0, HeroStats.SWORD_DAMAGE, none), 1.0)


func test_adds_come_before_percentages_and_percentages_are_summed() -> void:
	var mods: Array[StatModifier] = [_knockback(50.0), _knockback(10.0, StatModifier.Kind.ADD), _knockback(50.0)]
	assert_eq(HeroStats.combine(150.0, HeroStats.SWORD_KNOCKBACK, mods), (150.0 + 10.0) * 2.0)
	var reversed: Array[StatModifier] = mods.duplicate()
	reversed.reverse()
	assert_eq(HeroStats.combine(150.0, HeroStats.SWORD_KNOCKBACK, reversed), 320.0, "order does not matter")


func test_a_statistic_never_falls_below_its_minimum() -> void:
	assert_eq(HeroStats.combine(150.0, HeroStats.SWORD_KNOCKBACK, [_knockback(-300.0)] as Array[StatModifier]), 0.0)
	var weaker := StatModifier.new()
	weaker.stat = HeroStats.SWORD_DAMAGE
	weaker.kind = StatModifier.Kind.ADD
	weaker.value = -5.0
	assert_eq(HeroStats.combine(1.0, HeroStats.SWORD_DAMAGE, [weaker] as Array[StatModifier]), 1.0)


func test_modifiers_of_other_or_unknown_statistics_change_nothing() -> void:
	var odd := StatModifier.new()
	odd.stat = &"luck"
	odd.value = 99.0
	var mods: Array[StatModifier] = [odd, _knockback(50.0), null]
	assert_eq(HeroStats.combine(1.0, HeroStats.SWORD_DAMAGE, mods), 1.0)


func test_derive_changes_every_base_statistic_by_the_items() -> void:
	var base: Dictionary[StringName, float] = {HeroStats.SWORD_DAMAGE: 1.0, HeroStats.SWORD_KNOCKBACK: 150.0}
	var none: Array[ItemDef] = []
	assert_eq(HeroStats.derive(base, none), base)
	var derived := HeroStats.derive(base, [ItemCatalog.find(GLOVES)] as Array[ItemDef])
	assert_eq(derived[HeroStats.SWORD_DAMAGE], 1.0, "the gloves leave the damage alone")
	assert_eq(derived[HeroStats.SWORD_KNOCKBACK], 225.0)
	var twice := HeroStats.derive(base, [_stats([_knockback(50.0)]), _stats([_knockback(50.0)])] as Array[ItemDef])
	assert_eq(twice[HeroStats.SWORD_KNOCKBACK], 300.0)


func test_an_item_is_added_once_and_announces_it() -> void:
	var adventure := Adventure.new()
	watch_signals(adventure)
	assert_true(adventure.add_item(GLOVES))
	assert_false(adventure.add_item(GLOVES), "never twice")
	assert_false(adventure.add_item(&""))
	assert_eq(adventure.items(), [GLOVES] as Array[StringName])
	assert_signal_emit_count(adventure, "changed", 1)


func test_only_items_the_hero_has_can_be_equipped() -> void:
	var adventure := Adventure.new()
	assert_false(adventure.equip(ItemCatalog.ACCESSORY, GLOVES))
	adventure.add_item(GLOVES)
	watch_signals(adventure)
	assert_true(adventure.equip(ItemCatalog.ACCESSORY, GLOVES))
	assert_false(adventure.equip(ItemCatalog.ACCESSORY, GLOVES), "already worn")
	assert_eq(adventure.equipped(ItemCatalog.ACCESSORY), GLOVES)
	assert_true(adventure.unequip(ItemCatalog.ACCESSORY))
	assert_false(adventure.unequip(ItemCatalog.ACCESSORY), "nothing left to take off")
	assert_eq(adventure.equipped(ItemCatalog.ACCESSORY), &"")
	assert_signal_emit_count(adventure, "changed", 2)


func test_equipping_another_item_replaces_the_one_in_the_slot() -> void:
	var adventure := Adventure.new()
	adventure.add_item(GLOVES)
	adventure.add_item(&"spare_gloves")
	adventure.equip(ItemCatalog.ACCESSORY, GLOVES)
	assert_true(adventure.equip(ItemCatalog.ACCESSORY, &"spare_gloves"))
	assert_eq(adventure.equipped(ItemCatalog.ACCESSORY), &"spare_gloves")
	assert_true(adventure.has_item(GLOVES), "the other stays in the bag")


func test_items_and_equipment_survive_a_round_trip() -> void:
	var adventure := Adventure.new(&"road_slope", &"trail")
	adventure.set_flag(&"road_work_started")
	adventure.add_item(GLOVES)
	adventure.equip(ItemCatalog.ACCESSORY, GLOVES)
	var data := adventure.to_dict()
	assert_eq(data["version"], 3)
	assert_eq(data["items"], ["crew_gloves"] as Array[String])
	assert_eq(data["equipment"], {"accessory": "crew_gloves"})
	var json: Variant = JSON.parse_string(JSON.stringify(data))
	var back := Adventure.from_dict(json)
	assert_eq(back.items(), [GLOVES] as Array[StringName])
	assert_eq(back.equipped(ItemCatalog.ACCESSORY), GLOVES)
	assert_true(back.has_flag(&"road_work_started"))


func test_a_version_2_save_is_upgraded_with_nothing_in_the_bag() -> void:
	var adventure := Adventure.from_dict(JSON.parse_string(JSON.stringify(_v2())))
	assert_not_null(adventure)
	assert_true(adventure.items().is_empty())
	assert_eq(adventure.equipped(ItemCatalog.ACCESSORY), &"")
	assert_eq(adventure.health, 9, "health kept")
	assert_true(adventure.has_flag(&"heart_vessel_ruin"), "hearts kept")
	assert_eq(adventure.checkpoint_entry, &"shrine", "checkpoint kept")
	assert_eq(adventure.to_dict()["version"], Adventure.FORMAT_VERSION)


func test_a_version_1_save_is_upgraded_through_version_2() -> void:
	var v1 := {"version": 1, "area": "village", "entry": "north", "health": -1,
			"flags": ["forest_shrine_awakened", "heard_of_shrine"]}
	var adventure := Adventure.from_dict(JSON.parse_string(JSON.stringify(v1)))
	assert_not_null(adventure)
	assert_eq(adventure.checkpoint_area, &"forest")
	assert_true(adventure.items().is_empty())
	assert_eq(adventure.to_dict()["equipment"], {})


func test_repeated_ids_in_a_save_are_kept_once() -> void:
	var adventure := Adventure.from_dict(_v3(["crew_gloves", "crew_gloves"], {}))
	assert_eq(adventure.items(), [GLOVES] as Array[StringName])


func test_an_unknown_item_is_kept_but_changes_nothing() -> void:
	var adventure := Adventure.from_dict(_v3(["crew_gloves", "lantern_of_tomorrow"], {"accessory": "lantern_of_tomorrow"}))
	assert_not_null(adventure, "a well-formed save is read")
	assert_true(adventure.has_item(&"lantern_of_tomorrow"), "and nothing it holds is thrown away")
	assert_eq(adventure.to_dict()["items"], ["crew_gloves", "lantern_of_tomorrow"] as Array[String])
	assert_true(HeroLoadout.worn(adventure).is_empty(), "but an unknown item is worn by nobody")
	var sword := load("res://actors/player/sword_attack.tres") as AttackData
	assert_eq(HeroLoadout.stats(adventure, sword)[HeroStats.SWORD_KNOCKBACK], sword.knockback)


func test_equipment_naming_an_item_not_owned_is_dropped() -> void:
	var adventure := Adventure.from_dict(_v3([], {"accessory": "crew_gloves"}))
	assert_not_null(adventure)
	assert_eq(adventure.equipped(ItemCatalog.ACCESSORY), &"")
	assert_push_warning("without having it")


func test_an_item_in_a_slot_it_does_not_go_in_is_worn_by_nobody() -> void:
	var adventure := Adventure.from_dict(_v3(["crew_gloves"], {"head": "crew_gloves"}))
	assert_eq(adventure.equipped(&"head"), GLOVES, "the save's word is kept")
	assert_true(HeroLoadout.worn(adventure).is_empty(), "but the gloves do nothing on the head")


func test_malformed_items_or_equipment_make_the_save_unreadable() -> void:
	for bad: Dictionary in [_v3(["crew_gloves", 3], {}), _v3([""], {}), _v3(["crew_gloves"], {"accessory": 5}),
			_v3(["crew_gloves"], {"": "crew_gloves"})]:
		assert_null(Adventure.from_dict(bad), str(bad))
	var no_items := _v3([], {})
	no_items.erase("items")
	assert_null(Adventure.from_dict(no_items), "version 3 must have its items")
	var bad_equipment := _v3([], {})
	bad_equipment["equipment"] = ["crew_gloves"]
	assert_null(Adventure.from_dict(bad_equipment))


func test_the_loadout_gives_the_sword_the_gloves_knockback() -> void:
	var sword := load("res://actors/player/sword_attack.tres") as AttackData
	var adventure := Adventure.new()
	assert_eq(HeroLoadout.stats(adventure, sword)[HeroStats.SWORD_KNOCKBACK], sword.knockback, "nothing worn")
	adventure.add_item(GLOVES)
	assert_eq(HeroLoadout.stats(adventure, sword)[HeroStats.SWORD_KNOCKBACK], sword.knockback, "carried, not worn")
	adventure.equip(ItemCatalog.ACCESSORY, GLOVES)
	var worn := HeroLoadout.stats(adventure, sword)
	assert_eq(worn[HeroStats.SWORD_KNOCKBACK], sword.knockback * 1.5)
	assert_eq(worn[HeroStats.SWORD_DAMAGE], float(sword.damage), "the damage is the sword's own")
