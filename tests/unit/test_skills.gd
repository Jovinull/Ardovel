extends GutTest
## Skills as rules and record: the catalog and its stable ids, technique points (apart from attribute
## points, derived from the level), learning (requirements, points, never twice), the slots (two for
## techniques, one for a passive skill, no wrong kind, no skill not learned), what suits a weapon or
## a shield, a technique's blow built on the weapon's (strength kept), the passive skills' effects on
## the hero's profile, and the save format (version 7, upgrades from every version).

const FIXTURES := "res://tests/fixtures/saves"
const IDS: Array[StringName] = [&"piercing_step", &"breaking_blow", &"staff_sweep", &"guard_response",
		&"trained_steps", &"firm_stance"]


func _at_level(level: int) -> Adventure:
	var adventure := Adventure.new()
	adventure.experience = HeroGrowth.experience_for(level)
	return adventure


func _round_trip(adventure: Adventure) -> Adventure:
	return Adventure.from_dict(JSON.parse_string(JSON.stringify(adventure.to_dict())))


func _fixture(file_name: String) -> Adventure:
	return Adventure.from_dict(JSON.parse_string(FileAccess.get_file_as_string(FIXTURES.path_join(file_name))))


# ---------------------------------------------------------------- catalog

func test_six_skills_with_stable_ids() -> void:
	assert_eq(SkillCatalog.ids(), IDS, "ids are written in saves: never renamed or reordered")
	var actives := 0
	var motions := {}
	for id in IDS:
		var skill := SkillCatalog.find(id)
		assert_not_null(skill, String(id))
		assert_eq(skill.id, id)
		for key in [skill.name_key, skill.description_key, skill.effect_key]:
			assert_false(key.is_empty(), String(id))
		assert_not_null(skill.icon, String(id))
		assert_eq(skill.icon.get_size(), Vector2(16, 16))
		assert_between(skill.level, 2, 8, String(id))
		assert_between(skill.cost, 1, 2, String(id))
		if skill.is_active():
			actives += 1
			assert_not_null(skill.technique, String(id))
			assert_gt(skill.breath, 0.0, String(id) + " costs breath")
			assert_lt(skill.breath, 50.0, String(id) + " never more than half the breath")
			motions[skill.technique.motion] = true
		else:
			assert_null(skill.technique, String(id))
	assert_eq(actives, 4)
	assert_eq(motions.size(), 4, "each technique does something of its own")
	assert_null(SkillCatalog.find(&"fireball"))


# ---------------------------------------------------------------- points

func test_technique_points_come_every_second_level_apart_from_attribute_points() -> void:
	var expected := {1: 0, 2: 1, 3: 1, 4: 2, 7: 3, 9: 4, 20: 10}
	for level: int in expected:
		assert_eq(Skills.points_earned(_at_level(level)), expected[level], "level %d" % level)
	var adventure := _at_level(6)
	assert_eq(HeroGrowth.points_free(adventure), 5, "attribute points untouched")
	assert_true(Skills.learn(adventure, &"piercing_step"))
	assert_eq(HeroGrowth.points_free(adventure), 5, "learning never spends attribute points")
	assert_eq(Skills.points_free(adventure), 2)


func test_all_six_can_be_learned_before_the_top_level() -> void:
	var total := 0
	for id in IDS:
		total += SkillCatalog.find(id).cost
	assert_eq(total, 7)
	var adventure := _at_level(14)
	for id in IDS:
		assert_true(Skills.learn(adventure, id), String(id))
	assert_eq(Skills.points_free(adventure), 0, "level 14 is enough for all of them")


# ---------------------------------------------------------------- learning

func test_learning_asks_its_level_and_points_and_happens_once() -> void:
	var adventure := _at_level(2)
	assert_eq(Skills.why_not_learn(adventure, &"breaking_blow"), Skills.Refusal.LEVEL)
	assert_eq(Skills.why_not_learn(adventure, &"nonsense"), Skills.Refusal.UNKNOWN)
	var changes := [0]
	adventure.changed.connect(func() -> void: changes[0] += 1)
	assert_true(Skills.learn(adventure, &"trained_steps"))
	assert_eq(changes[0], 1, "one change, one save")
	assert_eq(Skills.why_not_learn(adventure, &"trained_steps"), Skills.Refusal.LEARNED)
	assert_eq(Skills.why_not_learn(adventure, &"piercing_step"), Skills.Refusal.POINTS)
	assert_false(Skills.learn(adventure, &"piercing_step"), "the one point is spent")
	assert_eq(changes[0], 1, "a refusal changes nothing")
	var guard := _at_level(7)
	assert_true(Skills.learn(guard, &"piercing_step"))
	assert_eq(Skills.points_free(guard), 2)
	assert_eq(Skills.why_not_learn(guard, &"guard_response"), Skills.Refusal.NONE, "two points: the response fits")
	assert_true(Skills.learn(guard, &"breaking_blow"))
	assert_eq(Skills.why_not_learn(guard, &"guard_response"), Skills.Refusal.POINTS, "one point left: it does not")


func test_a_learned_skill_is_kept_through_a_save_and_not_charged_twice() -> void:
	var adventure := _at_level(4)
	Skills.learn(adventure, &"piercing_step")
	var back := _round_trip(adventure)
	assert_true(back.has_skill(&"piercing_step"))
	assert_eq(Skills.points_free(back), 1)


# ---------------------------------------------------------------- slots

func test_slots_take_only_learned_skills_of_their_kind() -> void:
	var adventure := _at_level(10)
	for id in [&"piercing_step", &"staff_sweep", &"trained_steps"]:
		Skills.learn(adventure, id)
	assert_eq(Skills.why_not_equip(adventure, &"breaking_blow", 0), Skills.Refusal.NOT_LEARNED)
	assert_eq(Skills.why_not_equip(adventure, &"trained_steps", 0), Skills.Refusal.WRONG_KIND, "a passive in a technique slot")
	assert_eq(Skills.why_not_equip(adventure, &"piercing_step", -1), Skills.Refusal.WRONG_KIND, "a technique as the passive")
	assert_eq(Skills.why_not_equip(adventure, &"piercing_step", 2), Skills.Refusal.WRONG_KIND, "there are two slots")
	assert_true(Skills.equip(adventure, &"piercing_step", 0))
	assert_true(Skills.equip(adventure, &"staff_sweep", 1))
	assert_true(Skills.equip(adventure, &"trained_steps", -1))
	assert_eq(adventure.skill_slots(), [&"piercing_step", &"staff_sweep"] as Array[StringName])
	assert_true(Skills.equip(adventure, &"piercing_step", 1), "moved, never in both")
	assert_eq(adventure.skill_slots(), [&"", &"piercing_step"] as Array[StringName])
	assert_true(Skills.unequip(adventure, 1))
	assert_eq(adventure.skill_slots(), [&"", &""] as Array[StringName])
	assert_false(adventure.set_skill_slots([&"breaking_blow", &""] as Array[StringName]), "the record refuses one not learned")
	assert_eq(Skills.passive(adventure).id, &"trained_steps")


func test_what_suits_a_weapon_or_a_shield() -> void:
	var pierce := SkillCatalog.find(&"piercing_step")
	assert_true(pierce.fits(&"wayfarer_sword", false))
	assert_true(pierce.fits(&"ruin_blade", false))
	assert_false(pierce.fits(&"quarry_maul", false))
	assert_true(SkillCatalog.find(&"breaking_blow").fits(&"woodcutter_hatchet", true))
	assert_false(SkillCatalog.find(&"breaking_blow").fits(&"wayfarer_sword", true))
	assert_true(SkillCatalog.find(&"staff_sweep").fits(&"traveller_staff", false))
	var answer := SkillCatalog.find(&"guard_response")
	assert_false(answer.fits(&"wayfarer_sword", false), "no shield, no answer")
	assert_true(answer.fits(&"quarry_maul", true), "any weapon, with a shield")
	for weapon: StringName in [&"wayfarer_sword", &"crew_machete", &"woodcutter_hatchet", &"traveller_staff",
			&"ruin_blade", &"quarry_maul"]:
		var suited := 0
		for id in [&"piercing_step", &"breaking_blow", &"staff_sweep"]:
			if SkillCatalog.find(id).fits(weapon, false):
				suited += 1
		assert_eq(suited, 1, "%s has a technique of its own" % weapon)


func test_a_technique_blow_keeps_the_weapon_and_the_strength() -> void:
	var adventure := _at_level(20)
	HeroGrowth.invest(adventure, {HeroGrowth.STRENGTH: 5})
	var swing := HeroLoadout.profile(adventure, 12).attack
	assert_almost_eq(swing.power, 1.5, 0.0001)
	var pierce := SkillCatalog.find(&"piercing_step").technique.attack_for(swing)
	assert_almost_eq(pierce.power, 2.25, 0.0001, "the technique's x1.5 on top of strength, once")
	assert_eq(pierce.damage, swing.damage, "the weapon's damage stays whole")
	assert_eq(pierce.hitbox_size, Vector2(10, 22))
	var answer := SkillCatalog.find(&"guard_response").technique.attack_for(swing)
	assert_eq(answer.hitbox_size, swing.hitbox_size, "the answer keeps the weapon's blow")
	assert_eq(answer.reach, swing.reach)
	assert_eq(swing.power, 1.5, "the weapon's own swing is never changed")
	var breaking := SkillCatalog.find(&"breaking_blow").technique.attack_for(swing)
	assert_true(breaking.breaking)
	assert_false(swing.breaking)
	assert_eq(breaking.chain, 0.0, "a technique never chains")


# ---------------------------------------------------------------- passives

func test_trained_steps_lowers_a_dodge_and_nothing_else() -> void:
	var adventure := _at_level(2)
	var before := HeroLoadout.profile(adventure, 12)
	Skills.learn(adventure, &"trained_steps")
	assert_eq(HeroLoadout.profile(adventure, 12).dodge.breath, before.dodge.breath, "learned but not selected")
	Skills.equip(adventure, &"trained_steps", -1)
	var after := HeroLoadout.profile(adventure, 12)
	assert_almost_eq(after.dodge.breath, HeroStats.DODGE_BREATH * 0.7, 0.0001)
	assert_eq(after.dodge.untouchable, before.dodge.untouchable, "the untouchable moment is as before")
	assert_eq(after.dodge.distance, before.dodge.distance)
	assert_eq(after.value(HeroStats.BREATH), before.value(HeroStats.BREATH), "not breath by another name")


func test_firm_stance_is_selected_by_the_profile() -> void:
	var adventure := _at_level(6)
	Skills.learn(adventure, &"firm_stance")
	assert_false(HeroLoadout.profile(adventure, 12).has_passive(&"firm_stance"))
	Skills.equip(adventure, &"firm_stance", -1)
	var profile := HeroLoadout.profile(adventure, 12)
	assert_true(profile.has_passive(&"firm_stance"))
	assert_eq(profile.value(HeroStats.DEFENSE), 0.0, "not endurance by another name")


# ---------------------------------------------------------------- saves

func test_format_7_round_trip() -> void:
	var adventure := _at_level(10)
	for id in [&"piercing_step", &"guard_response", &"firm_stance"]:
		Skills.learn(adventure, id)
	Skills.equip(adventure, &"guard_response", 0)
	Skills.equip(adventure, &"piercing_step", 1)
	Skills.equip(adventure, &"firm_stance", -1)
	var data := adventure.to_dict()
	assert_eq(data["version"], 7)
	assert_eq(data["skills"], ["piercing_step", "guard_response", "firm_stance"])
	assert_eq(data["skill_slots"], ["guard_response", "piercing_step"])
	assert_eq(data["passive_skill"], "firm_stance")
	assert_false(data.has("skill_points"), "points are derived, never saved")
	var back := _round_trip(adventure)
	assert_eq(back.skills(), adventure.skills())
	assert_eq(back.skill_slots(), adventure.skill_slots())
	assert_eq(back.passive_skill, &"firm_stance")
	assert_eq(Skills.points_free(back), Skills.points_free(adventure))


func test_malformed_skills_are_unreadable_or_left_out() -> void:
	var base := _at_level(1).to_dict()
	assert_not_null(Adventure.from_dict(base))
	for bad: Array in [["skills", {}], ["skills", [3]], ["skills", [""]], ["skill_slots", ["a"]], ["skill_slots", {}],
			["skill_slots", ["", 4]], ["passive_skill", 1], ["passive_skill", null]]:
		var data := base.duplicate(true)
		data[bad[0]] = bad[1]
		assert_null(Adventure.from_dict(data), str(bad))
	var odd := base.duplicate(true)
	odd["skills"] = ["piercing_step", "a_skill_from_tomorrow"]
	odd["skill_slots"] = ["breaking_blow", "piercing_step"]
	odd["passive_skill"] = "trained_steps"
	var adventure := Adventure.from_dict(odd)
	assert_not_null(adventure)
	assert_push_warning("without having learned it")
	assert_eq(adventure.skill_slots(), [&"", &"piercing_step"] as Array[StringName], "a slot never holds what was not learned")
	assert_eq(adventure.passive_skill, &"")
	assert_true(adventure.has_skill(&"a_skill_from_tomorrow"), "an unknown skill is kept")
	assert_eq(Skills.points_spent(adventure), 1, "and costs nothing")


func test_a_version_6_save_keeps_its_growth_and_gets_its_technique_points() -> void:
	var adventure := _fixture("v6_grown.json")
	assert_not_null(adventure)
	assert_eq(adventure.experience, 420)
	assert_eq(HeroGrowth.level(adventure), 7)
	assert_eq(adventure.attribute(HeroGrowth.VIGOR), 2, "attribute points kept")
	assert_eq(adventure.attribute(HeroGrowth.STRENGTH), 3)
	assert_true(adventure.has_reward(&"warden_defeated"), "rewards kept")
	assert_eq(adventure.skills().size(), 0)
	assert_eq(Skills.points_free(adventure), 3, "level 7: three technique points free at once")
	assert_eq(adventure.stored(&"corn_bread"), 3, "the chest kept")
	assert_eq(adventure.to_dict()["version"], 7)
	var back := _round_trip(adventure)
	assert_eq(Skills.points_free(back), 3, "never given twice")


func test_every_older_format_upgrades_to_7() -> void:
	for file_name in ["v1_back_in_village.json", "v2_after_pedrabranca.json", "v3_gloves_worn.json", "v4_quarry_kit.json",
			"v5_chest_kept.json", "v6_grown.json"]:
		var adventure := _fixture(file_name)
		assert_not_null(adventure, file_name)
		assert_eq(adventure.skills().size(), 0, file_name)
		assert_eq(adventure.skill_slots(), [&"", &""] as Array[StringName], file_name)
		assert_eq(adventure.passive_skill, &"", file_name)
		assert_eq(adventure.to_dict()["version"], Adventure.FORMAT_VERSION, file_name)
