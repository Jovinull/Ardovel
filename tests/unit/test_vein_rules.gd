extends GutTest
## Milestone 7.6's rules, without the area: experience and drops of the vein's creatures and deeds,
## the moult ring in the hero's profile, the Old Gnawer's and the tatuira's shells, a paid line, and
## that the save format did not change.


func test_the_veins_creatures_deeds_and_arrival_give_experience() -> void:
	assert_eq(HeroGrowth.for_creature(&"Tatuira"), 5)
	assert_eq(HeroGrowth.for_creature(&"Mucum"), 6)
	assert_eq(HeroGrowth.for_creature(&"OldGnawer"), 0, "the boss is a one-time deed, not a creature")
	assert_eq(HeroGrowth.DEEDS[&"vein_gnawer"], [&"vein_gnawer_defeated", 60])
	assert_eq(HeroGrowth.DEEDS[&"vein_drain"], [&"vein_drain_open", 40])
	assert_eq(HeroGrowth.DEEDS[&"vein_cage"], [&"vein_cage_fixed", 20])
	assert_eq(HeroGrowth.ARRIVALS[&"hollow_vein"], 15)


func test_deeds_are_given_once_by_their_flags() -> void:
	var a := Adventure.new()
	a.set_flag(&"vein_gnawer_defeated")
	a.set_flag(&"vein_drain_open")
	assert_eq(HeroGrowth.settle_deeds(a), 100)
	assert_eq(HeroGrowth.settle_deeds(a), 0)


func test_a_tatuira_leaves_white_stone_chips_by_a_seeded_roll_and_an_eel_nothing() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 76
	var left := 0
	var chips := 0
	for i in 400:
		var drop := Spoils.roll(&"Tatuira", rng)
		if not drop.is_empty():
			left += 1
			chips += drop["count"]
			assert_eq(drop["item"], &"white_stone_chip")
	assert_between(left, 170, 230, "about half leave something")
	assert_between(chips, left, left * 2)
	assert_true(Spoils.roll(&"Mucum", rng).is_empty())


func test_the_moult_ring_is_known_a_keepsake_and_marks_the_profile_in_either_ring_slot() -> void:
	var ring := ItemCatalog.find(&"gnawer_ring")
	assert_not_null(ring)
	assert_eq(ring.slot, &"ring")
	assert_false(Commerce.SELL.has(&"gnawer_ring"), "a boss's reward is never sold")
	var a := Adventure.new()
	assert_false(HeroLoadout.profile(a, 12).moult)
	a.add_item(&"gnawer_ring")
	a.equip(ItemCatalog.RING_2, &"gnawer_ring")
	assert_true(HeroLoadout.profile(a, 12).moult)
	a.unequip(ItemCatalog.RING_2)
	a.equip(ItemCatalog.RING_1, &"gnawer_ring")
	assert_true(HeroLoadout.profile(a, 12).moult)


func test_the_moult_ring_adds_no_raw_damage() -> void:
	var a := Adventure.new()
	var plain := HeroLoadout.profile(a, 12)
	a.add_item(&"gnawer_ring")
	a.equip(ItemCatalog.RING_1, &"gnawer_ring")
	var ringed := HeroLoadout.profile(a, 12)
	assert_eq(ringed.attack.damage, plain.attack.damage)
	assert_almost_eq(ringed.attack.power, plain.attack.power, 0.001)


func _gnawer() -> OldGnawer:
	var g := OldGnawer.new()
	add_child_autofree(g)
	return g


func test_the_old_gnawers_shell() -> void:
	var g := _gnawer()
	g.state = OldGnawer.State.WALK
	var hit: Hit = g._screen_hit(Hit.new(1, 0.0, Vector2.ZERO))
	assert_true(hit.blocked)
	assert_almost_eq(hit.share, 1.0 / 3.0, 0.001, "a third through the crust")
	g._bare = true
	assert_almost_eq((g._screen_hit(Hit.new(1, 0.0, Vector2.ZERO)) as Hit).share, 0.5, 0.001, "half once bare")
	var breaking := Hit.new(1, 0.0, Vector2.ZERO)
	breaking.breaking = true
	assert_false((g._screen_hit(breaking) as Hit).blocked, "a guard-breaking blow goes through")
	g.state = OldGnawer.State.DAZED
	assert_false((g._screen_hit(Hit.new(1, 0.0, Vector2.ZERO)) as Hit).blocked, "dazed, everything lands")
	g.state = OldGnawer.State.ROLL
	assert_eq((g._screen_hit(Hit.new(1, 0.0, Vector2.ZERO)) as Hit).share, 0.0, "rolling, nothing")
	g.state = OldGnawer.State.UNDER
	assert_null(g._screen_hit(Hit.new(1, 0.0, Vector2.ZERO)), "under the floor, nothing reaches her")


func test_her_crust_comes_off_once_at_half() -> void:
	var g := _gnawer()
	g.state = OldGnawer.State.WALK
	g.health.current = g.health.max_health / 2 + 1
	assert_false(g._check_moult(), "not yet")
	g.health.current = g.health.max_health / 2
	assert_true(g._check_moult())
	g._shed()
	assert_true(g.is_bare())
	g.state = OldGnawer.State.WALK
	assert_false(g._check_moult(), "once")


func test_her_moves_come_in_a_cycle_that_burrows_only_when_bare() -> void:
	assert_false(OldGnawer.CRUSTED_CYCLE.has(OldGnawer.Move.BURROW))
	assert_true(OldGnawer.BARE_CYCLE.has(OldGnawer.Move.BURROW))
	for cycle in [OldGnawer.CRUSTED_CYCLE, OldGnawer.BARE_CYCLE]:
		assert_true(cycle.has(OldGnawer.Move.ROLL) and cycle.has(OldGnawer.Move.SLAM) and cycle.has(OldGnawer.Move.CLOSE))


func test_a_tatuiras_shell() -> void:
	var t := Tatuira.new()
	add_child_autofree(t)
	t.state = Tatuira.State.ROLL
	var hit: Hit = t._screen_hit(Hit.new(1, 0.0, Vector2.ZERO))
	assert_true(hit.blocked)
	assert_eq(hit.share, 0.0)
	t.state = Tatuira.State.FLIPPED
	assert_almost_eq((t._screen_hit(Hit.new(1, 0.0, Vector2.ZERO)) as Hit).power, 2.0, 0.001)
	t.state = Tatuira.State.WANDER
	var plain: Hit = t._screen_hit(Hit.new(1, 0.0, Vector2.ZERO))
	assert_false(plain.blocked)
	assert_almost_eq(plain.power, 1.0, 0.001)


func test_a_paid_line_is_not_a_story_line() -> void:
	var line := DialogueLine.new()
	assert_eq(line.gives_money, 0)
	line.gives_money = 40
	line.sets = &"vein_rufina_paid"
	assert_true(line.applies(Adventure.new()))


func test_the_save_format_is_still_8_and_the_veins_flags_round_trip() -> void:
	assert_eq(Adventure.FORMAT_VERSION, 8)
	var a := Adventure.new(&"hollow_vein", &"shelter")
	for flag: StringName in [&"vein_heard", &"vein_opened", &"vein_gate_wedged", &"vein_cart_sent", &"vein_lamp_lit",
			&"vein_cage_fixed", &"vein_ladder_down", &"vein_gnawer_defeated", &"vein_drain_open", &"vein_rufina_paid",
			&"found_vein_pay_box", &"found_vein_tools", &"claimed_vein_gnawer_ring"]:
		a.set_flag(flag)
	var b := Adventure.from_dict(JSON.parse_string(JSON.stringify(a.to_dict())))
	assert_eq(b.area, &"hollow_vein")
	assert_eq(b.entry, &"shelter")
	assert_eq(b.flags().size(), a.flags().size())
	assert_true(Game.AREAS.has(&"hollow_vein"))
