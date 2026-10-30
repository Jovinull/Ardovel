extends GutTest
## Combat 2.0's pure rules: breath, how a shield and armour share a blow, the dodge by weight band,
## the shields' and weapons' data, and the quick food in the save.


func _health(max_health: int = 40) -> Health:
	var health := Health.new()
	health.max_health = max_health
	add_child_autofree(health)
	health.restore_full()
	return health


func test_breath_is_spent_only_when_there_is_enough_and_comes_back_after_a_pause() -> void:
	var breath := Stamina.new()
	add_child_autofree(breath)
	assert_eq(breath.current, 100.0)
	assert_true(breath.spend(60.0))
	assert_false(breath.spend(60.0), "not more than is left")
	assert_eq(breath.current, 40.0, "and nothing taken")
	await wait_physics_frames(10)
	assert_eq(breath.current, 40.0, "it waits a moment")
	await wait_seconds(1.0)
	assert_gt(breath.current, 40.0, "then comes back")
	breath.drain()
	assert_eq(breath.current, 0.0)
	breath.refill()
	assert_true(breath.is_full())


func test_a_shield_then_armour_never_below_zero_and_unblocked_at_least_one() -> void:
	var health := _health()
	assert_true(health.take_hit(2.0, 1))
	assert_eq(health.current, 38, "an unblocked 2")
	assert_false(health.take_hit(0.4, 0), "a blocked 0.4 takes nothing yet")
	assert_eq(health.current, 38)
	assert_true(health.take_hit(0.8, 0), "the remainder carries: 0.4 + 0.8")
	assert_eq(health.current, 37)
	health.defense_percent = 50.0
	assert_true(health.take_hit(1.0, 1), "an unblocked blow always takes a quarter")
	assert_eq(health.current, 36)
	assert_false(health.take_hit(0.0, 0), "nothing is nothing")
	assert_false(health.take_hit(-3.0, 1), "and no healing by negative damage")
	assert_eq(health.current, 36)


func test_a_blocked_blow_leaves_a_short_immunity() -> void:
	var health := _health()
	health.grant_invulnerability(0.3)
	assert_true(health.is_invulnerable())
	assert_false(health.take_damage(2))
	await wait_seconds(0.35)
	assert_false(health.is_invulnerable())


func test_the_dodge_shortens_and_slows_with_weight() -> void:
	var previous := INF
	for band in HeroStats.BANDS:
		assert_lt(HeroStats.DODGE_DISTANCE[band], previous, "%s goes less far" % band)
		previous = HeroStats.DODGE_DISTANCE[band]
		assert_gt(HeroStats.DODGE_UNTOUCHABLE[band], 0.0, "%s still has an untouchable moment" % band)
		assert_lt(HeroStats.DODGE_UNTOUCHABLE[band], HeroStats.DODGE_TIME, "never the whole step")
	assert_gt(HeroStats.DODGE_RECOVERY[HeroStats.OVERLOADED], HeroStats.DODGE_RECOVERY[HeroStats.LIGHT] * 2.0)
	assert_gte(HeroStats.DODGE_DISTANCE[HeroStats.OVERLOADED], 20.0, "overloaded still steps out of a lunge")


func test_the_profile_carries_the_shield_and_the_band_dodge() -> void:
	var adventure := Adventure.new()
	assert_null(HeroLoadout.profile(adventure, 12).guard, "no shield, no guard")
	adventure.add_item(&"crew_board_shield")
	adventure.equip(ItemCatalog.OFF_HAND, &"crew_board_shield")
	var profile := HeroLoadout.profile(adventure, 12)
	assert_not_null(profile.guard)
	assert_eq(profile.guard.absorb, 1.0)
	assert_not_null(profile.guard_sheet)
	assert_eq(profile.dodge.distance, HeroStats.DODGE_DISTANCE[profile.band])


func test_shields_go_from_light_and_quick_to_heavy_and_steady() -> void:
	var ids := [&"barrel_lid_buckler", &"bark_shield", &"traveller_shield", &"crew_board_shield"]
	for i in ids.size() - 1:
		var a := (ItemCatalog.find(ids[i]) as ItemDef).guard
		var b := (ItemCatalog.find(ids[i + 1]) as ItemDef).guard
		assert_lte(a.absorb, b.absorb, "%s stops no more than %s" % [ids[i], ids[i + 1]])
		assert_lte(a.raise_time, b.raise_time, "but comes up no slower")
		assert_gte(a.move_factor, b.move_factor, "and lets the hero move no slower")
	for id: StringName in ItemCatalog.ITEMS:
		var item := ItemCatalog.find(id)
		assert_eq(item.guard != null, item.slot == &"off_hand", "%s guards only if it is a shield" % id)


func test_every_weapon_has_its_own_blow() -> void:
	var seen := {}
	for id: StringName in ItemCatalog.ITEMS:
		var attack := ItemCatalog.find(id).attack
		if attack == null:
			continue
		assert_gt(attack.hitbox_size.x * attack.hitbox_size.y, 0.0, "%s strikes an area" % id)
		assert_gt(attack.stagger, 0.0)
		assert_gt(attack.hit_stop, 0.0)
		assert_lt(attack.chain, attack.recovery, "%s never swings with no recovery" % id)
		seen[[attack.hitbox_size, attack.stagger]] = true
	assert_eq(seen.size(), 6, "six different blows")
	assert_gt(ItemCatalog.find(&"crew_machete").attack.chain, 0.0, "the machete chains")
	assert_gt(ItemCatalog.find(&"traveller_staff").attack.hitbox_size.y, 20.0, "the staff stabs long")
	assert_lt(ItemCatalog.find(&"traveller_staff").attack.hitbox_size.x, 10.0, "and narrow")


func test_the_quick_food_is_an_optional_save_key() -> void:
	var adventure := Adventure.new()
	adventure.add_item(&"herb_tea")
	adventure.set_quick_item(&"herb_tea")
	var back := Adventure.from_dict(JSON.parse_string(JSON.stringify(adventure.to_dict())))
	assert_eq(back.quick_item, &"herb_tea")
	var data := adventure.to_dict()
	data.erase("quick_item")
	assert_eq(Adventure.from_dict(data).quick_item, &"", "a save without it reads as before")
	data["quick_item"] = 7
	assert_not_null(Adventure.from_dict(data), "a broken quick food does not lose the save")
	assert_push_warning("quick item is not a name")
