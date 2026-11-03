extends "res://tests/integration/adventure_case.gd"
## Milestone 7.6, the Hollow Vein, played on the real game scene with real input where it matters:
## the way in from Pedrabranca (boarded until Rufina speaks); the water (one stream: a sluice turned
## fills one way and empties the other; a wet channel blocks, a dry one is walked; a bucket raises its
## gate); the cart holding the hall's gate for good; the lift that rises only on water; the ladder
## and the office's gate; the cage as a shortcut; the shelter's lamp as the vein's way back; the
## tatuiras and the eels; the Old Gnawer (her shell, her daze, her moult, a fall in the fight, her
## defeat and reward, once); the master sluice and the pool; Rufina's pay; and saves meeting it all.

const VEIN := &"hollow_vein"
const FIXTURES := "res://tests/fixtures/saves"


func after_each() -> void:
	super.after_each()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"attack", &"dodge"]:
		Input.action_release(action)


func _state(area: StringName, entry: StringName, flags: Array[StringName] = []) -> Adventure:
	var state := Adventure.new(area, entry)
	for flag in [&"forest_shrine_awakened", &"heard_of_shrine", &"equipment_seen", &"town_store_met",
			&"town_store_notice_heard"]:
		state.set_flag(flag)
	for flag in flags:
		state.set_flag(flag)
	state.checkpoint_area = &"ruin"
	state.checkpoint_entry = &"heart"
	return state


func _enter_vein(flags: Array[StringName] = [], entry: StringName = &"mouth") -> void:
	var all: Array[StringName] = [&"vein_heard", &"vein_opened"]
	all.append_array(flags)
	game._begin(_state(VEIN, entry, all))
	await _settle()


## Talks to a merchant and closes the goods they open after speaking.
func _talk_to_merchant(npc_name: String) -> String:
	var said := await _talk(npc_name)
	await wait_physics_frames(4)
	if game.is_trade_open():
		game.trade_menu().close()
	await wait_physics_frames(3)
	return said


func _node(path: String) -> Node:
	return game.level.get_node(path)


func _steer(direction: Vector2) -> void:
	var keys := {&"move_left": direction.x < -0.3, &"move_right": direction.x > 0.3,
			&"move_up": direction.y < -0.3, &"move_down": direction.y > 0.3}
	for action: StringName in keys:
		if keys[action]:
			Input.action_press(action)
		else:
			Input.action_release(action)


func _walk_through(points: Array[Vector2], seconds_each: float = 6.0) -> bool:
	for point in points:
		var left := seconds_each
		while _player().global_position.distance_to(point) > 4.0 and left > 0.0:
			_steer((point - _player().global_position).normalized())
			await wait_physics_frames(1)
			left -= get_physics_process_delta_time()
		if left <= 0.0:
			_steer(Vector2.ZERO)
			gut.p("stuck at %s on the way to %s" % [_player().global_position, point])
			return false
	_steer(Vector2.ZERO)
	await wait_physics_frames(2)
	return true


func _walk_until_travelling(direction: Vector2, seconds: float) -> bool:
	var left := seconds
	while not game.is_travelling() and left > 0.0:
		_steer(direction)
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	_steer(Vector2.ZERO)
	return game.is_travelling()


func _press_interact() -> String:
	var said := [""]
	var listen := func(_target: Interactable, message: String) -> void: said[0] = message
	_player().interactor.interacted.connect(listen)
	Input.action_press(&"interact")
	await wait_physics_frames(2)
	Input.action_release(&"interact")
	await wait_physics_frames(2)
	_player().interactor.interacted.disconnect(listen)
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	return said[0]


## Stands the hero at `at` (staging) and interacts with a real key press.
func _use_at(at: Vector2) -> String:
	_player().global_position = at
	_player().reset_physics_interpolation()
	await wait_physics_frames(3)
	return await _press_interact()


func _wait_until(condition: Callable, seconds: float) -> bool:
	var left := seconds
	while not condition.call() and left > 0.0:
		await wait_physics_frames(1)
		left -= get_physics_process_delta_time()
	return condition.call()


func _sluice(name: String) -> Sluice:
	return _node("Entities/" + name)


func _channel(name: String) -> WaterChannel:
	return _node("Water/" + name)


func _gate(name: String) -> BucketGate:
	return _node("Entities/" + name)


# ---------------------------------------------------------------- the way in

func test_the_old_adit_is_boarded_until_rufina_speaks_of_the_water() -> void:
	game._begin(_state(&"pedrabranca", &"east", [&"town_iara_met", &"town_rufina_heard", &"town_rufina_faced",
			&"town_iara_dealt", &"town_notice_down"]))
	await _settle()
	var adit: BoardedAdit = _node("Entities/Adit")
	assert_false(adit.is_open())
	assert_eq(await _use_at(adit.global_position + Vector2(0, 10)), "VEIN_ADIT_SEALED")
	assert_eq(await _talk("Rufina"), "RUFINA_CREW_GEAR", "the crew's gear comes first")
	assert_eq(await _talk("Rufina"), "RUFINA_VEIN_WATER")
	assert_true(game.adventure.has_flag(&"vein_heard"))
	assert_eq(await _talk("Rufina"), "RUFINA_VEIN_WAIT")
	assert_eq(await _talk_to_merchant("Storekeeper"), "STORE_VEIN", "Joaquim explains the sluices")
	assert_eq(await _use_at(adit.global_position + Vector2(0, 10)), "VEIN_ADIT_OPENED")
	assert_true(adit.is_open())
	var before := game.adventure.experience
	_player().global_position = adit.global_position + Vector2(0, 20)
	await wait_physics_frames(3)
	assert_true(await _walk_until_travelling(Vector2.UP, 3.0), "the hero walks into the adit")
	await _settle()
	_assert_at_entry(VEIN, &"mouth")
	assert_eq(game.adventure.experience - before, HeroGrowth.ARRIVALS[VEIN], "a first arrival")
	await _take_exit("ToPedrabranca")
	_assert_at_entry(&"pedrabranca", &"adit")
	var back := game.adventure.experience
	await _take_exit("ToVein")
	assert_eq(game.adventure.experience, back, "the vein's arrival is given once")


func test_the_council_is_untouched_and_iara_still_waits() -> void:
	game._begin(_state(&"pedrabranca", &"east", [&"town_iara_met", &"town_rufina_heard", &"town_rufina_faced",
			&"town_iara_dealt", &"town_notice_down", &"town_crew_gear_given", &"vein_heard", &"vein_drain_open",
			&"vein_gnawer_defeated"]))
	await _settle()
	assert_eq(await _talk("Iara"), "IARA_TOWN_STAY", "Iara's answer from the council is still pending")
	assert_false(game.adventure.has_flag(&"town_council_answered"))


# ---------------------------------------------------------------- water

func test_the_spring_sluice_sends_the_water_to_the_mouths_bucket_and_raises_the_gate() -> void:
	await _enter_vein()
	var s1 := _sluice("SluiceSpring")
	var gate := _gate("GateMouth")
	assert_eq(s1.way, Sluice.WEST, "found sending the water south, down the cut face to the ledge")
	assert_true(_channel("ToSinkhole").is_wet())
	assert_false(_channel("ToMouth").is_wet())
	assert_false(gate.is_open())
	# Walk from the mouth to the spring's sluice and turn it, with real input.
	assert_true(await _walk_through([Vector2(470, 136), Vector2(330, 136), Vector2(250, 166), Vector2(152, 164)]),
			"the way from the mouth to the spring's sluice is open")
	assert_eq(await _press_interact(), "")
	assert_eq(s1.way, Sluice.EAST)
	assert_false(_channel("ToSinkhole").is_wet())
	assert_true(_channel("ToMouth").is_wet())
	assert_true((_node("Entities/BucketMouth") as WaterNode).is_wet())
	assert_true(gate.is_open(), "the full bucket raises the grate")
	assert_true(_channel("CanalGrande").is_wet(), "the overflow runs down to the rails gallery's canal")
	# Down the steps: the hero wedges the grate open for good.
	# Back over the footbridge, along the passage to the mouth and down the steps.
	assert_true(await _walk_through([Vector2(150, 170), Vector2(184, 170), Vector2(184, 100), Vector2(300, 104), Vector2(330, 128),
			Vector2(392, 140), Vector2(400, 180), Vector2(400, 236)]))
	assert_true(game.adventure.has_flag(&"vein_gate_wedged"))
	s1.turn()
	await wait_physics_frames(3)
	assert_true(gate.is_open(), "wedged: it stays up whatever the water does")


func test_a_wet_channel_blocks_and_a_dry_one_is_walked() -> void:
	await _enter_vein([&"vein_gate_wedged"])
	_sluice("SluiceSpring").turn()
	await wait_physics_frames(3)
	var canal := _channel("CanalGrande")
	assert_true(canal.is_wet())
	_player().global_position = Vector2(480, 304)
	await wait_physics_frames(3)
	assert_false(await _walk_through([Vector2(480, 380)], 2.0), "the running canal cannot be crossed")
	assert_lt(_player().global_position.y, canal.rect().position.y + 2.0)
	var s2 := _sluice("SluiceRails")
	assert_eq(await _use_at(s2.global_position + Vector2(10, -16)), "")
	assert_eq(s2.way, Sluice.WEST)
	assert_false(canal.is_wet(), "the canal runs dry")
	assert_true((_node("Entities/BucketLift") as WaterNode).is_wet(), "the lift's bucket fills")
	_player().global_position = Vector2(480, 304)
	await wait_physics_frames(3)
	assert_true(await _walk_through([Vector2(480, 380)], 3.0), "the dry canal is walked across")


func test_water_coming_back_pushes_the_hero_to_the_bank() -> void:
	await _enter_vein([&"vein_gate_wedged"])
	_sluice("SluiceSpring").turn()
	_sluice("SluiceRails").turn()
	await wait_physics_frames(3)
	var canal := _channel("CanalGrande")
	_player().global_position = Vector2(500, 338)
	await wait_physics_frames(3)
	assert_true(canal.rect().has_point(_player().global_position))
	_sluice("SluiceRails").turn()
	await wait_physics_frames(4)
	assert_true(canal.is_wet())
	assert_false(canal.rect().has_point(_player().global_position), "never caught inside the water")


# ---------------------------------------------------------------- the cart, the lift, the ladder, the cage

func test_the_cart_runs_to_the_plate_and_holds_the_halls_gate_for_good() -> void:
	await _enter_vein([&"vein_gate_wedged"])
	var gate := _gate("GateHall")
	var cart: MineCart = _node("Entities/Cart")
	assert_false(gate.is_open())
	assert_eq(await _use_at(cart.global_position + Vector2(0, -14)), "VEIN_CART_PUSHED")
	assert_true(await _wait_until(func() -> bool: return cart.is_at_end(), 20.0), "it runs the rails, over the trestle")
	assert_true(game.adventure.has_flag(&"vein_cart_sent"))
	assert_true(gate.is_open(), "the cart's weight holds the grate up")
	game._begin(Adventure.from_dict(game.adventure.to_dict()))
	await _settle()
	assert_true((_node("Entities/Cart") as MineCart).is_at_end(), "still on the plate next time")
	assert_true(_gate("GateHall").is_open())


func test_the_hall_gate_also_rises_on_the_canals_water() -> void:
	await _enter_vein([&"vein_gate_wedged"])
	_sluice("SluiceSpring").turn()
	await wait_physics_frames(3)
	assert_true(_channel("CanalGrande").is_wet())
	assert_true(_gate("GateHall").is_open(), "water is weight too: one stream, two needs")


func test_the_lift_rises_only_with_water_in_its_bucket_and_always_comes_down() -> void:
	await _enter_vein([&"vein_gate_wedged"])
	var bottom: VeinPassage = _node("Entities/LiftBottom")
	assert_eq(await _use_at(bottom.global_position + Vector2(0, 12)), "VEIN_LIFT_DRY")
	_sluice("SluiceSpring").turn()
	_sluice("SluiceRails").turn()
	await wait_physics_frames(3)
	assert_eq(await _use_at(bottom.global_position + Vector2(0, 12)), "")
	await _settle()
	_assert_at_entry(VEIN, &"lift_top")
	_sluice("SluiceSpring").turn()
	await wait_physics_frames(3)
	var top: VeinPassage = _node("Entities/LiftTop")
	assert_eq(await _use_at(top.global_position + Vector2(-10, -6)), "")
	await _settle()
	_assert_at_entry(VEIN, &"lift_bottom")


func test_the_ladder_is_lowered_from_the_ledge_and_the_office_opens_on_the_ledges_water() -> void:
	await _enter_vein([&"vein_gate_wedged"])
	var top: VeinPassage = _node("Entities/LadderTop")
	assert_eq(await _use_at(top.global_position + Vector2(0, -12)), "VEIN_LADDER_UP")
	_player().global_position = Vector2(232, 260)
	await wait_physics_frames(3)
	var bottom: VeinPassage = _node("Entities/LadderBottom")
	assert_eq(await _use_at(bottom.global_position + Vector2(0, 12)), "VEIN_LADDER_LOWERED")
	assert_true(game.adventure.has_flag(&"vein_ladder_down"))
	var office := _gate("GateOffice")
	assert_true(office.is_open(), "the spring found running south fills the office's bucket")
	_sluice("SluiceSpring").turn()
	await wait_physics_frames(3)
	assert_false(office.is_open(), "turned to the mouth, the ledge's channel runs dry")
	assert_eq(await _use_at(bottom.global_position + Vector2(0, 12)), "")
	await _settle()
	_assert_at_entry(VEIN, &"ladder_top")


func test_the_pay_box_is_found_once() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_ladder_down"])
	var box: ItemPickup = _node("Entities/PayBox")
	var before := game.adventure.money
	_player().global_position = Vector2(64, 300)
	await wait_physics_frames(3)
	await _use_at(box.global_position + Vector2(0, 12))
	assert_eq(game.adventure.money - before, 80)
	await _use_at(box.global_position + Vector2(0, 12))
	assert_eq(game.adventure.money - before, 80, "an empty box stays empty")


func test_the_cage_is_hooked_from_below_and_rides_both_ways() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent"])
	var top: VeinPassage = _node("Entities/CageTop")
	assert_eq(await _use_at(top.global_position + Vector2(-12, 0)), "VEIN_CAGE_SLACK")
	var bottom: VeinPassage = _node("Entities/CageBottom")
	var before := game.adventure.experience
	assert_eq(await _use_at(bottom.global_position + Vector2(-14, 4)), "VEIN_CAGE_HOOKED")
	assert_eq(game.adventure.experience - before, HeroGrowth.DEEDS[&"vein_cage"][1], "the shortcut's deed")
	assert_eq(await _use_at(bottom.global_position + Vector2(-14, 4)), "")
	await _settle()
	_assert_at_entry(VEIN, &"cage_top")
	assert_eq(await _use_at(top.global_position + Vector2(-12, 0)), "")
	await _settle()
	_assert_at_entry(VEIN, &"cage_bottom")


# ---------------------------------------------------------------- the way back

func test_a_fall_in_the_vein_leads_to_the_mouth_then_to_the_lit_lamp_and_continue_starts_there() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent"])
	_player().global_position = Vector2(700, 420)
	await _fall_and_retry()
	_assert_at_entry(VEIN, &"mouth")
	var lamp: VeinLamp = _node("Entities/Lamp")
	_player().health.take_damage(4)
	assert_eq(await _use_at(lamp.global_position + Vector2(0, 14)), "VEIN_LAMP_LIT")
	assert_eq(_player().health.current, _player().health.max_health, "resting by the lamp heals")
	assert_eq(game.adventure.entry, &"shelter", "the resume point")
	assert_eq(game.adventure.checkpoint_area, &"ruin", "the shrines' checkpoint is untouched")
	_player().global_position = Vector2(700, 420)
	await _fall_and_retry()
	_assert_at_entry(VEIN, &"shelter")
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	_assert_at_entry(VEIN, &"shelter")
	assert_eq(await _use_at((_node("Entities/Lamp") as Node2D).global_position + Vector2(0, 14)), "VEIN_LAMP_REST")


func test_a_fall_elsewhere_still_leads_to_the_shrine() -> void:
	game._begin(_state(&"pedrabranca", &"east", [&"vein_lamp_lit"]))
	await _settle()
	await _fall_and_retry()
	_assert_at_entry(&"ruin", &"heart")


# ---------------------------------------------------------------- creatures

func test_a_tatuira_rolls_when_in_line_shrugs_blows_curled_and_takes_double_on_its_back() -> void:
	await _enter_vein()
	var t: Tatuira = _node("Entities/Tatuira4")
	_player().global_position = t.global_position + Vector2(40, 30)
	await wait_physics_frames(10)
	assert_false(t.is_shelled(), "out of line: it keeps crawling")
	_player().global_position = Vector2(t.global_position.x + 60, t.global_position.y)
	assert_true(await _wait_until(func() -> bool: return t.is_shelled(), 3.0), "in line: it curls up")
	var hit := Hit.new(1, 0.0, _player().global_position)
	assert_true((t.get_node(^"Hurtbox") as Hurtbox).receive_hit(hit))
	assert_eq(t.health.current, t.health.max_health, "the shell takes nothing")
	assert_true(await _wait_until(func() -> bool: return t.is_flipped(), 4.0), "after the roll it lies on its back")
	await wait_physics_frames(20)
	var before := t.health.current
	var blow := Hit.new(1, 0.0, t.global_position + Vector2(10, 0))
	(t.get_node(^"Hurtbox") as Hurtbox).receive_hit(blow)
	assert_eq(before - t.health.current, 2, "on its back a blow lands double")


func test_a_breaking_blow_flips_a_curled_tatuira() -> void:
	await _enter_vein()
	var t: Tatuira = _node("Entities/Tatuira4")
	_player().global_position = Vector2(t.global_position.x + 60, t.global_position.y)
	assert_true(await _wait_until(func() -> bool: return t.state == Tatuira.State.CURL, 3.0))
	var hit := Hit.new(1, 0.0, _player().global_position)
	hit.breaking = true
	(t.get_node(^"Hurtbox") as Hurtbox).receive_hit(hit)
	await wait_physics_frames(2)
	assert_true(t.is_flipped())


func test_a_tatuira_defeated_gives_experience_once_and_may_leave_chips() -> void:
	await _enter_vein()
	game.spoils_rng.seed = 3
	var t: Tatuira = _node("Entities/Tatuira4")
	_player().global_position = t.global_position + Vector2(40, 30)
	var before := game.adventure.experience
	for i in 6:
		if not is_instance_valid(t) or t.state == Tatuira.State.DEAD:
			break
		t.health.take_damage(1)
		await wait_physics_frames(20)
	assert_eq(game.adventure.experience - before, HeroGrowth.CREATURES[&"Tatuira"])
	await wait_physics_frames(60)
	assert_eq(game.adventure.experience - before, HeroGrowth.CREATURES[&"Tatuira"], "once")


func test_an_eel_is_untouchable_under_water_bites_from_the_bank_and_is_stranded_when_its_canal_dries() -> void:
	await _enter_vein([&"vein_gate_wedged"])
	_sluice("SluiceSpring").turn()
	await wait_physics_frames(3)
	var eel: Mucum = _node("Entities/MucumCanal1")
	assert_eq(eel.state, Mucum.State.UNDER)
	assert_false(eel.is_exposed())
	_player().global_position = Vector2(eel.global_position.x, 312)
	assert_true(await _wait_until(func() -> bool: return eel.state == Mucum.State.RISE, 5.0), "it surfaces at the bank")
	var health := _player().health.current
	assert_true(await _wait_until(func() -> bool: return _player().health.current < health, 2.0), "and bites across it")
	_sluice("SluiceRails").turn()
	await wait_physics_frames(4)
	assert_eq(eel.state, Mucum.State.STRANDED, "its canal ran dry")
	assert_true(eel.is_exposed())


# ---------------------------------------------------------------- the Old Gnawer

func _to_the_chamber() -> OldGnawer:
	_player().global_position = Vector2(440, 650)
	await wait_physics_frames(3)
	assert_true(await _walk_through([Vector2(330, 650)], 4.0))
	await wait_physics_frames(5)
	return _node("Entities/OldGnawer") as OldGnawer


func test_the_fight_starts_with_the_grate_shut_and_her_shell_takes_a_third() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent", &"vein_lamp_lit"], &"shelter")
	var boss := await _to_the_chamber()
	var arena: BossArena = _node("BossArena")
	assert_true(arena.is_fighting())
	assert_false((_node("Entities/Grate") as VeinDoor).is_open(), "the way back shuts")
	assert_true((game.get_node(^"HUD") as Hud).is_boss_bar_visible())
	assert_true(arena.is_framing(), "the camera keeps the whole hall in view")
	assert_true(await _wait_until(func() -> bool: return _player().camera.limit_top == 512, 2.0),
			"after gliding there")
	var hurt := boss.get_node(^"Hurtbox") as Hurtbox
	var full := boss.health.current
	boss.state = OldGnawer.State.WALK
	for i in 3:
		hurt.receive_hit(Hit.new(1, 0.0, boss.global_position + Vector2(0, 20)))
		boss.health.grant_invulnerability(0.0)
		await wait_physics_frames(16)
	assert_eq(full - boss.health.current, 1, "three blows on the shell take one")
	boss._enter(OldGnawer.State.DAZED)
	hurt.receive_hit(Hit.new(1, 0.0, boss.global_position + Vector2(0, 20)))
	assert_eq(full - boss.health.current, 2, "dazed, a blow lands whole")


func test_her_charge_ends_dazed_against_a_wall_and_she_moults_at_half() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent", &"vein_lamp_lit"], &"shelter")
	var boss := await _to_the_chamber()
	_player().global_position = Vector2(boss.global_position.x, boss.global_position.y + 90)
	boss._enter(OldGnawer.State.REAR)
	assert_true(await _wait_until(func() -> bool: return boss.state == OldGnawer.State.CHARGE, 2.0))
	_player().global_position = Vector2(boss.global_position.x + 100, boss.global_position.y - 10)
	assert_true(await _wait_until(func() -> bool: return boss.state == OldGnawer.State.DAZED, 3.0), "a miss ends against the wall")
	boss.health.take_hit(boss.health.current - boss.health.max_health / 2, 1)
	boss._check_moult()
	assert_eq(boss.state, OldGnawer.State.MOULT)
	assert_true(await _wait_until(func() -> bool: return boss.is_bare(), 3.0), "the crust comes off")


func test_her_roll_and_stones_cannot_be_blocked() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent", &"vein_lamp_lit"], &"shelter")
	var boss := await _to_the_chamber()
	assert_false((boss.get_node(^"RollHitbox") as Hitbox).blockable)
	assert_false((boss.get_node(^"EruptHitbox") as Hitbox).blockable)
	assert_true((boss.get_node(^"ChargeHitbox") as Hitbox).blockable)
	assert_true((boss.get_node(^"BiteHitbox") as Hitbox).blockable)
	boss._enter(OldGnawer.State.SLAM_TELL)
	assert_true(await _wait_until(func() -> bool:
		return game.level.get_node(^"Entities").get_children().any(func(n: Node) -> bool: return n is FallingStone), 2.0),
		"the tremor brings stones down")
	var stone: FallingStone = game.level.get_node(^"Entities").get_children().filter(
			func(n: Node) -> bool: return n is FallingStone)[0]
	assert_false((stone.get_node(^"Hitbox") as Hitbox).blockable)


func test_the_hoist_weight_crushes_her_through_her_shell() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent", &"vein_lamp_lit"], &"shelter")
	var boss := await _to_the_chamber()
	var hoist: HoistWeight = _node("Entities/Hoist")
	boss.global_position = hoist.global_position
	boss._enter(OldGnawer.State.DAZED)
	_player().global_position = Vector2(150, 660)
	var full := boss.health.current
	assert_true(hoist.release())
	assert_true(await _wait_until(func() -> bool: return not hoist.is_hanging() and boss.health.current < full, 3.0))
	assert_eq(full - boss.health.current, HoistWeight.BOSS_DAMAGE)
	assert_false(hoist.release(), "it falls once")


func test_a_fall_in_the_fight_leaves_her_whole_and_the_way_open() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent", &"vein_lamp_lit"], &"shelter")
	var boss := await _to_the_chamber()
	boss.health.take_hit(5, 1)
	await _fall_and_retry()
	_assert_at_entry(VEIN, &"shelter")
	assert_false(game.adventure.has_flag(&"vein_gnawer_defeated"))
	var again: OldGnawer = _node("Entities/OldGnawer")
	assert_eq(again.health.current, again.health.max_health)
	assert_true((_node("Entities/Grate") as VeinDoor).is_open())
	assert_false((game.get_node(^"HUD") as Hud).is_boss_bar_visible())


func test_the_camera_glides_into_her_hall_and_back_out_without_a_jump() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent", &"vein_lamp_lit"], &"shelter")
	var camera := _player().camera
	_player().global_position = Vector2(440, 650)
	await wait_physics_frames(3)
	var start := camera.get_screen_center_position()
	var track := _track_camera(camera)
	assert_true(await _walk_through([Vector2(330, 650)], 4.0))
	await wait_seconds(1.2)
	get_tree().process_frame.disconnect(track[0])
	var arena: BossArena = _node("BossArena")
	assert_true(arena.is_fighting())
	var moved := camera.get_screen_center_position().distance_to(start)
	assert_gt(moved, 40.0, "the view moved to frame the hall")
	assert_lt(track[1].max(), moved * 0.35, "sliding there over several frames, never in one jump")
	# The hero waits in the hall's west corner: following him there frames less of the hall.
	_player().global_position = Vector2(150, 660)
	var boss: OldGnawer = _node("Entities/OldGnawer")
	boss._enter(OldGnawer.State.DAZED)
	boss.health.take_hit(99, 1)
	assert_true(await _wait_until(func() -> bool: return game.adventure.has_flag(&"vein_gnawer_defeated"), 6.0))
	start = camera.get_screen_center_position()
	track = _track_camera(camera)
	await wait_seconds(1.2)
	get_tree().process_frame.disconnect(track[0])
	assert_false(arena.is_framing(), "following the hero again")
	moved = camera.get_screen_center_position().distance_to(start)
	assert_gt(moved, 20.0, "the view went back to the hero")
	assert_lt(track[1].max(), moved * 0.35, "gliding back, never in one jump")


## Records how far the camera's view moves each frame: [the connected callable, the steps].
func _track_camera(camera: Camera2D) -> Array:
	var steps: Array[float] = [0.0]
	var last := [camera.get_screen_center_position()]
	var record := func() -> void:
		var now := camera.get_screen_center_position()
		steps.append(now.distance_to(last[0]))
		last[0] = now
	get_tree().process_frame.connect(record)
	return [record, steps]


func test_her_defeat_is_kept_rewarded_once_and_the_drain_runs() -> void:
	await _enter_vein([&"vein_gate_wedged", &"vein_cart_sent", &"vein_lamp_lit"], &"shelter")
	var boss := await _to_the_chamber()
	var master: MasterSluice = _node("Entities/MasterSluice")
	assert_eq(await _use_at(master.global_position + Vector2(0, 14)), "VEIN_MASTER_STUCK")
	var before := game.adventure.experience
	boss._enter(OldGnawer.State.DAZED)
	boss.health.take_hit(99, 1)
	assert_true(await _wait_until(func() -> bool: return game.adventure.has_flag(&"vein_gnawer_defeated"), 6.0))
	assert_eq(game.adventure.experience - before, HeroGrowth.DEEDS[&"vein_gnawer"][1])
	assert_true((_node("Entities/Grate") as VeinDoor).is_open())
	assert_true(await _wait_until(func() -> bool: return not (_node("BossArena") as BossArena).is_framing(), 2.0),
			"the camera glides back and follows again")
	var reward: ItemPickup = _node("Entities/Reward_GnawerRing")
	assert_true(reward.is_present(), "her ring lies in the den")
	await _use_at(reward.global_position + Vector2(0, 12))
	assert_eq(game.adventure.count(&"gnawer_ring"), 1)
	assert_eq(await _use_at(master.global_position + Vector2(0, 14)), "VEIN_MASTER_TURNED")
	assert_true(game.adventure.has_flag(&"vein_drain_open"))
	assert_true(await _wait_until(func() -> bool: return not _channel("Pool").is_wet(), 1.0), "the pool drains")
	await wait_physics_frames(3)
	assert_false(game.level.has_node(^"Entities/MucumPool1"), "the pool's eels went down the drain")
	var xp := game.adventure.experience
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_false(game.level.has_node(^"Entities/OldGnawer"), "she never comes back")
	assert_false(_channel("Pool").is_wet(), "the pool stays dry")
	assert_false(game.level.has_node(^"Entities/Reward_GnawerRing"), "claimed: the ring is not there again")
	assert_eq(game.adventure.count(&"gnawer_ring"), 1, "never twice")
	assert_eq(game.adventure.experience, xp, "no deed twice")
	assert_false(game.level.has_node(^"Entities/MucumPool2"))


func test_rufina_pays_for_the_drain_once() -> void:
	game._begin(_state(&"pedrabranca", &"east", [&"town_iara_met", &"town_rufina_heard", &"town_rufina_faced",
			&"town_iara_dealt", &"town_notice_down", &"town_crew_gear_given", &"vein_heard", &"vein_drain_open"]))
	await _settle()
	var before := game.adventure.money
	assert_true((await _talk("Rufina")).begins_with(tr("RUFINA_VEIN_PAY")), "her pay, with the line")
	assert_eq(game.adventure.money - before, 40)
	assert_eq(await _talk("Rufina"), "RUFINA_VEIN_PAID")
	assert_eq(game.adventure.money - before, 40, "once")
	assert_eq(await _talk_to_merchant("Storekeeper"), "STORE_VEIN_AFTER")
	assert_eq(await _talk("Teodoro"), "TEODORO_VEIN_AFTER")


# ---------------------------------------------------------------- the moult ring

func test_the_moult_ring_charges_on_a_slipped_blow_and_empowers_the_next_swing() -> void:
	await _enter_vein()
	game.adventure.add_item(&"gnawer_ring")
	game.adventure.equip(ItemCatalog.RING_1, &"gnawer_ring")
	await wait_physics_frames(2)
	assert_true(_player().moult_ring)
	_player().global_position = Vector2(470, 120)
	await wait_physics_frames(3)
	Input.action_press(&"dodge")
	await wait_physics_frames(2)
	Input.action_release(&"dodge")
	assert_true(_player().is_untouchable())
	var hurt := _player().get_node(^"Hurtbox") as Hurtbox
	assert_false(hurt.receive_hit(Hit.new(2, 100.0, _player().global_position + Vector2(10, 0))), "the blow passes")
	assert_true(_player().is_moult_charged())
	await wait_physics_frames(20)
	Input.action_press(&"attack")
	await wait_physics_frames(2)
	Input.action_release(&"attack")
	var sword := _player().get_node(^"AttackPivot/SwordHitbox") as Hitbox
	assert_almost_eq(sword.power, _player().weapon_attack().power * Player.MOULT_POWER, 0.01)
	assert_true(sword.breaking)
	assert_false(_player().is_moult_charged(), "spent")


func test_without_the_ring_a_dodge_charges_nothing() -> void:
	await _enter_vein()
	_player().global_position = Vector2(470, 120)
	await wait_physics_frames(3)
	Input.action_press(&"dodge")
	await wait_physics_frames(2)
	Input.action_release(&"dodge")
	(_player().get_node(^"Hurtbox") as Hurtbox).receive_hit(Hit.new(2, 100.0, _player().global_position))
	assert_false(_player().is_moult_charged())


# ---------------------------------------------------------------- saves

func test_a_format_8_save_from_7_5_meets_the_vein_boarded() -> void:
	var file := FileAccess.open(save_dir().path_join("save.json"), FileAccess.WRITE)
	file.store_string(FileAccess.get_file_as_string(FIXTURES.path_join("v8_town_traded.json")))
	file.close()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.money, 64)
	assert_false((_node("Entities/Adit") as BoardedAdit).is_open())
	assert_eq(Adventure.FORMAT_VERSION, 8, "the vein needs no new save format")
	var data: Dictionary = game.adventure.to_dict()
	assert_eq(int(data["version"]), 8)
