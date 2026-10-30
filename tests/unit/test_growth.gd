extends GutTest
## How the hero grows, as rules and record: the experience curve (levels, the last level, experience
## kept past a level), experience that cannot be given (nothing, less than nothing), one-time
## rewards (given once, one change each), deeds proven by flags (and only those), first arrivals,
## attribute points (earned, invested, refused), what each attribute does to the statistics the game
## uses, points and equipment in one sum, the preview, and the save format (version 6, upgrades from
## every version, older saves credited once for the deeds their flags prove).

const FIXTURES := "res://tests/fixtures/saves"
const BASE_HEALTH := 12
## Saves from each milestone since the last one played by the owner.
const MILESTONE_SAVES := {
	"6.7": "v2_second_spring.json", "6.8": "v2_blank_paths.json", "6.9": "v2_after_pedrabranca.json",
	"7.0": "v3_gloves_worn.json", "7.1": "v4_quarry_kit.json", "7.2": "v5_chest_kept.json",
}


func _at_level(level: int) -> Adventure:
	var adventure := Adventure.new()
	adventure.experience = HeroGrowth.experience_for(level)
	return adventure


func _round_trip(adventure: Adventure) -> Adventure:
	return Adventure.from_dict(JSON.parse_string(JSON.stringify(adventure.to_dict())))


func _fixture(file_name: String) -> Adventure:
	return Adventure.from_dict(JSON.parse_string(FileAccess.get_file_as_string(FIXTURES.path_join(file_name))))


func _profile(adventure: Adventure) -> HeroLoadout.Profile:
	return HeroLoadout.profile(adventure, BASE_HEALTH)


# ---------------------------------------------------------------- curve

func test_a_new_adventure_starts_at_level_1_with_nothing() -> void:
	var adventure := Adventure.new()
	assert_eq(adventure.experience, 0)
	assert_eq(HeroGrowth.level(adventure), 1)
	assert_eq(HeroGrowth.points_free(adventure), 0)
	assert_eq(adventure.rewards(), [] as Array[StringName])
	assert_eq(HeroGrowth.progress(adventure), Vector2i(0, HeroGrowth.FIRST_STEP))


func test_the_curve_grows_moderately() -> void:
	assert_eq(HeroGrowth.step(1), 30)
	assert_eq(HeroGrowth.step(2), 45)
	assert_eq(HeroGrowth.step(6), 105)
	assert_eq(HeroGrowth.experience_for(1), 0)
	assert_eq(HeroGrowth.experience_for(2), 30)
	assert_eq(HeroGrowth.experience_for(5), 210)
	assert_eq(HeroGrowth.experience_for(10), 810)
	for level in range(2, HeroGrowth.MAX_LEVEL):
		assert_gt(HeroGrowth.step(level), HeroGrowth.step(level - 1), "each level asks a little more")
		assert_lt(HeroGrowth.step(level), HeroGrowth.step(level - 1) * 2, "never doubling")


func test_levels_from_experience_at_the_edges() -> void:
	assert_eq(HeroGrowth.level_for(29), 1)
	assert_eq(HeroGrowth.level_for(30), 2)
	assert_eq(HeroGrowth.level_for(74), 2)
	assert_eq(HeroGrowth.level_for(75), 3)
	assert_eq(HeroGrowth.level_for(HeroGrowth.experience_for(HeroGrowth.MAX_LEVEL) - 1), HeroGrowth.MAX_LEVEL - 1)
	assert_eq(HeroGrowth.level_for(HeroGrowth.experience_for(HeroGrowth.MAX_LEVEL)), HeroGrowth.MAX_LEVEL)
	assert_eq(HeroGrowth.level_for(999999), HeroGrowth.MAX_LEVEL, "the last level holds")
	var top := Adventure.new()
	top.experience = 999999
	assert_eq(HeroGrowth.progress(top), Vector2i.ZERO)


func test_several_levels_at_once_keep_what_is_left_over() -> void:
	var adventure := Adventure.new()
	assert_true(adventure.add_experience(140))
	assert_eq(HeroGrowth.level(adventure), 4, "30 + 45 + 60 = 135: three levels in one go")
	assert_eq(HeroGrowth.progress(adventure), Vector2i(5, 75), "the 5 left over count toward level 5")
	assert_eq(HeroGrowth.points_free(adventure), 3, "a point for each level reached")


func test_experience_that_cannot_be_given() -> void:
	var adventure := Adventure.new()
	var changes := [0]
	adventure.changed.connect(func() -> void: changes[0] += 1)
	assert_false(adventure.add_experience(0))
	assert_false(adventure.add_experience(-5))
	assert_eq(adventure.experience, 0)
	assert_eq(changes[0], 0)
	assert_true(adventure.add_experience(4))
	assert_eq(changes[0], 1, "one change, one save")


# ---------------------------------------------------------------- rewards

func test_a_reward_is_given_once() -> void:
	var adventure := Adventure.new()
	var changes := [0]
	adventure.changed.connect(func() -> void: changes[0] += 1)
	assert_true(adventure.give_reward(&"warden_defeated", 60))
	assert_false(adventure.give_reward(&"warden_defeated", 60), "never twice")
	assert_false(adventure.give_reward(&"", 10))
	assert_false(adventure.give_reward(&"odd", -1))
	assert_eq(adventure.experience, 60)
	assert_eq(changes[0], 1, "the reward and its experience in one change")
	assert_true(adventure.has_reward(&"warden_defeated"))


func test_deeds_are_given_by_their_flags_once() -> void:
	var adventure := Adventure.new()
	assert_eq(HeroGrowth.settle_deeds(adventure), 0, "nothing done, nothing given")
	adventure.set_flag(&"ruin_warden_defeated")
	adventure.set_flag(&"found_village_straw_hat")
	adventure.set_flag(&"elder_thanked")
	assert_eq(HeroGrowth.settle_deeds(adventure), 60, "the warden; pickups and small talk give nothing")
	assert_eq(HeroGrowth.settle_deeds(adventure), 0, "and only once")
	assert_eq(adventure.rewards(), [&"warden_defeated"] as Array[StringName])


func test_every_deed_has_a_flag_the_story_sets_and_fair_experience() -> void:
	var total := 0
	for id in HeroGrowth.DEEDS:
		var deed: Array = HeroGrowth.DEEDS[id]
		assert_true(deed[0] is StringName and not String(deed[0]).is_empty(), String(id))
		assert_between(int(deed[1]), 10, 60, String(id))
		total += deed[1]
	for area in HeroGrowth.ARRIVALS:
		total += HeroGrowth.ARRIVALS[area]
	assert_eq(HeroGrowth.level_for(total), 7, "every deed and arrival: level 7, without fighting at all")


func test_first_arrivals_count_once_and_home_not_at_all() -> void:
	var adventure := Adventure.new()
	assert_eq(HeroGrowth.arrive(adventure, &"village"), 0)
	assert_eq(HeroGrowth.arrive(adventure, &"ruin"), 10)
	assert_eq(HeroGrowth.arrive(adventure, &"ruin"), 0)
	assert_eq(HeroGrowth.arrive(adventure, &"nowhere"), 0)
	assert_eq(adventure.experience, 10)


func test_creatures_give_their_experience_and_nothing_else_does() -> void:
	assert_eq(HeroGrowth.for_creature(&"Musgorico"), 4)
	assert_eq(HeroGrowth.for_creature(&"Cardosa"), 3)
	assert_eq(HeroGrowth.for_creature(&"RootWarden"), 0, "the warden is a deed, given once")
	assert_eq(HeroGrowth.for_creature(&"Hen"), 0)
	assert_eq(HeroGrowth.for_creature(&""), 0)


# ---------------------------------------------------------------- points

func test_points_are_earned_by_level_and_spent_once() -> void:
	var adventure := _at_level(4)
	assert_eq(HeroGrowth.points_earned(adventure), 3)
	assert_true(HeroGrowth.invest(adventure, {HeroGrowth.VIGOR: 2}))
	assert_eq(adventure.attribute(HeroGrowth.VIGOR), 2)
	assert_eq(HeroGrowth.points_free(adventure), 1)
	assert_true(HeroGrowth.invest(adventure, {HeroGrowth.STRENGTH: 1}))
	assert_eq(HeroGrowth.points_free(adventure), 0)
	assert_false(HeroGrowth.invest(adventure, {HeroGrowth.STRENGTH: 1}), "no point left")
	var back := _round_trip(adventure)
	assert_eq(HeroGrowth.points_free(back), 0, "not earned again after a save")
	assert_eq(back.attribute(HeroGrowth.VIGOR), 2)


func test_investments_that_are_refused_change_nothing() -> void:
	var adventure := _at_level(HeroGrowth.MAX_LEVEL)
	var changes := [0]
	adventure.changed.connect(func() -> void: changes[0] += 1)
	for plan: Dictionary in [{}, {HeroGrowth.VIGOR: 0}, {HeroGrowth.VIGOR: -1}, {&"luck": 1}, {HeroGrowth.VIGOR: 1.5},
			{HeroGrowth.VIGOR: HeroGrowth.ATTRIBUTE_CAP + 1}, {HeroGrowth.VIGOR: 10, HeroGrowth.STRENGTH: 10}]:
		assert_false(HeroGrowth.invest(adventure, plan), str(plan))
	assert_eq(changes[0], 0)
	assert_eq(HeroGrowth.points_invested(adventure), 0)
	assert_true(HeroGrowth.invest(adventure, {HeroGrowth.VIGOR: 10, HeroGrowth.STRENGTH: 9}), "all 19, within the caps")
	assert_eq(changes[0], 1, "one change for the whole plan")
	assert_false(adventure.set_attributes({HeroGrowth.VIGOR: -2}), "never negative")


func test_what_each_attribute_does() -> void:
	var bare := _profile(_at_level(1))
	var adventure := _at_level(HeroGrowth.MAX_LEVEL)
	HeroGrowth.invest(adventure, {HeroGrowth.VIGOR: 4, HeroGrowth.STRENGTH: 5, HeroGrowth.ENDURANCE: 5, HeroGrowth.BREATH: 5})
	var grown := _profile(adventure)
	assert_eq(grown.max_health(), bare.max_health() + 4, "a quarter of a heart a point: four points, one heart")
	assert_almost_eq(grown.blow(), 1.5, 0.0001, "the sword's 1 lands as 1.5")
	assert_eq(grown.attack.damage, 1, "the weapon's own damage stays whole")
	assert_eq(grown.value(HeroStats.DEFENSE), 15.0)
	assert_eq(grown.value(HeroStats.POISE), 20.0)
	assert_eq(grown.value(HeroStats.BREATH), 130.0)
	assert_eq(grown.value(HeroStats.BREATH_REGEN), 125.0)
	assert_eq(grown.attack.knockback, bare.attack.knockback, "strength does not push farther")
	assert_eq(grown.swing_seconds(), bare.swing_seconds(), "nor swing faster")
	assert_eq(grown.carried, bare.carried)


func test_points_and_equipment_make_one_sum_within_the_caps() -> void:
	var adventure := _at_level(HeroGrowth.MAX_LEVEL)
	for id: StringName in [&"quarry_helm", &"quarry_breastplate", &"quarry_gauntlets", &"quarry_greaves", &"quarry_maul"]:
		adventure.add_item(id)
		Equipment.equip(adventure, Equipment.slot_for(adventure, ItemCatalog.find(id)), id)
	var kit := _profile(adventure)
	HeroGrowth.invest(adventure, {HeroGrowth.ENDURANCE: 10, HeroGrowth.STRENGTH: 9})
	var both := _profile(adventure)
	assert_eq(both.value(HeroStats.DEFENSE), HeroStats.MAXIMUM[HeroStats.DEFENSE], "defence never past its cap (50%)")
	assert_lte(both.value(HeroStats.POISE), HeroStats.MAXIMUM[HeroStats.POISE])
	assert_almost_eq(both.blow(), 2.0 * 1.9, 0.0001, "the maul's 2 with strength 9")
	assert_eq(both.band, kit.band, "points never change the weight carried")
	var sword := _at_level(HeroGrowth.MAX_LEVEL)
	HeroGrowth.invest(sword, {HeroGrowth.STRENGTH: 9})
	assert_almost_eq(_profile(sword).blow(), 1.9, 0.0001, "the weapons stay apart: the sword's 1 with the same strength")


func test_the_preview_changes_nothing() -> void:
	var adventure := _at_level(3)
	var before := adventure.to_dict()
	var preview := HeroLoadout.profile(adventure, BASE_HEALTH, {HeroGrowth.VIGOR: 2})
	assert_eq(preview.max_health(), BASE_HEALTH + 2)
	assert_eq(adventure.to_dict(), before, "only a preview")
	assert_eq(_profile(adventure).max_health(), BASE_HEALTH)


func test_the_attribute_cap_is_reachable_but_not_passable() -> void:
	var adventure := _at_level(HeroGrowth.MAX_LEVEL)
	assert_true(HeroGrowth.can_invest(adventure, {HeroGrowth.BREATH: HeroGrowth.ATTRIBUTE_CAP}))
	assert_false(HeroGrowth.can_invest(adventure, {HeroGrowth.BREATH: HeroGrowth.ATTRIBUTE_CAP + 1}))
	var top := _profile(adventure)
	HeroGrowth.invest(adventure, {HeroGrowth.BREATH: HeroGrowth.ATTRIBUTE_CAP})
	assert_lte(_profile(adventure).value(HeroStats.BREATH), HeroStats.MAXIMUM[HeroStats.BREATH])
	assert_gt(_profile(adventure).value(HeroStats.BREATH), top.value(HeroStats.BREATH))


# ---------------------------------------------------------------- saves

func test_format_6_round_trip() -> void:
	var adventure := _at_level(5)
	adventure.add_experience(7)
	HeroGrowth.invest(adventure, {HeroGrowth.VIGOR: 1, HeroGrowth.BREATH: 2})
	adventure.give_reward(&"bridge_tied", 35)
	var data := adventure.to_dict()
	assert_eq(data["version"], 6)
	assert_false(data.has("level"), "the level is derived, not saved")
	assert_false(data.has("max_health"), "nor any statistic")
	assert_eq(data["attributes"], {"vigor": 1, "breath": 2})
	assert_eq(data["rewards"], ["bridge_tied"])
	var back := _round_trip(adventure)
	assert_eq(back.experience, adventure.experience)
	assert_eq(HeroGrowth.level(back), HeroGrowth.level(adventure))
	assert_eq(back.attribute(HeroGrowth.BREATH), 2)
	assert_true(back.has_reward(&"bridge_tied"))


func test_malformed_growth_is_unreadable() -> void:
	var base := Adventure.new().to_dict()
	assert_not_null(Adventure.from_dict(base))
	for bad: Array in [["experience", -1], ["experience", 1.5], ["experience", "10"], ["attributes", []],
			["attributes", {"vigor": -1}], ["attributes", {"vigor": 1.5}], ["attributes", {"": 1}], ["rewards", {}],
			["rewards", [3]], ["rewards", [""]]]:
		var data := base.duplicate(true)
		data[bad[0]] = bad[1]
		assert_null(Adventure.from_dict(data), str(bad))
	for key in ["experience", "attributes", "rewards"]:
		var missing := base.duplicate(true)
		missing.erase(key)
		assert_null(Adventure.from_dict(missing), "a version 6 save without " + key)


func test_every_older_format_upgrades_to_6_with_nothing_lost() -> void:
	for file_name in ["v1_back_in_village.json", "v2_stall_worked.json", "v3_gloves_worn.json", "v3_unknown_item.json",
			"v4_quarry_kit.json", "v5_chest_kept.json"]:
		var before: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES.path_join(file_name)))
		var adventure := _fixture(file_name)
		assert_not_null(adventure, file_name)
		assert_eq(adventure.experience, 0, file_name + ": experience starts at nothing")
		assert_eq(HeroGrowth.points_invested(adventure), 0, file_name)
		assert_eq(adventure.rewards().size(), 0, file_name + ": no reward given yet")
		for flag: String in before["flags"]:
			assert_true(adventure.has_flag(StringName(flag)), "%s keeps %s" % [file_name, flag])
		assert_eq(adventure.to_dict()["version"], Adventure.FORMAT_VERSION, file_name)
	var chest := _fixture("v5_chest_kept.json")
	assert_eq(chest.stored(&"corn_bread"), 3, "the chest is kept")
	assert_eq(chest.stored(&"lantern_of_tomorrow"), 1, "with its unknown item")
	assert_eq(chest.equipped(ItemCatalog.MAIN_HAND), &"quarry_maul")
	assert_eq(chest.quick_item, &"corn_bread")
	assert_eq(chest.health, 15)


func test_older_saves_are_credited_once_for_what_their_flags_prove() -> void:
	for milestone: String in MILESTONE_SAVES:
		var adventure := _fixture(MILESTONE_SAVES[milestone])
		assert_not_null(adventure, milestone)
		var expected := 0
		var proven: Array[StringName] = []
		for id in HeroGrowth.DEEDS:
			if adventure.has_flag(HeroGrowth.DEEDS[id][0]):
				expected += HeroGrowth.DEEDS[id][1]
				proven.append(id)
		proven.sort()
		var given := HeroGrowth.settle_deeds(adventure)
		assert_eq(given, expected, milestone + ": every proven deed, nothing guessed")
		assert_eq(adventure.experience, expected, milestone + ": no creature counted (nothing proves them)")
		assert_eq(adventure.rewards(), proven, milestone + ": recorded as given")
		assert_lte(HeroGrowth.level(adventure), 7, milestone + ": never past what playing it would give")
		assert_eq(HeroGrowth.settle_deeds(adventure), 0, milestone + ": once")
		var back := _round_trip(adventure)
		assert_eq(HeroGrowth.settle_deeds(back), 0, milestone + ": not again after saving and loading")
		assert_eq(back.experience, expected, milestone)
	var spring := _fixture("v2_second_spring.json")
	HeroGrowth.settle_deeds(spring)
	assert_true(spring.has_reward(&"warden_defeated"), "6.7: the warden beaten long ago counts")
	assert_true(spring.has_reward(&"stone_shifted"))
	assert_false(spring.has_reward(&"map_drawn"), "6.7: the witch's map came later")
