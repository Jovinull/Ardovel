extends "res://tests/integration/adventure_case.gd"
## Milestone 7.5, played on the real game scene. Where every item now comes from (and that none of
## the old pickups' flags is reused); trading with real key events (choose, amount, confirm, refuse,
## close; the area frozen and no swing behind it); Cida trading only once her stall is back; the
## villagers' gifts (once, waiting for room, never twice for a hero who took the old pickup); the
## crew's gear waiting for Rufina's word; coppers lying in the world; the warden's chest (hidden
## before the victory, claimed once, already open for a hero who took the ring from the forest,
## patient with a full bag, kept through Continue); the witch's charm left on the board; a Cardosa's
## seeds where it fell; and older saves meeting all of this.

const FIXTURES := "res://tests/fixtures/saves"
const CHEST := ^"Entities/Reward_RootRing"
## Flags of the pickups this milestone removed (their items are now sold, given or rewarded).
const REMOVED_FLAGS: Array[StringName] = [&"found_village_straw_hat", &"found_village_work_mitts",
		&"found_village_rope_sandals", &"found_village_barrel_lid_buckler", &"found_village_woodcutter_hatchet",
		&"found_halt_traveller_shield", &"found_halt_traveller_charm", &"found_halt_herb_tea",
		&"found_bank_traveller_boots", &"found_bank_carter_ring", &"found_bank_corn_bread", &"found_forest_root_ring",
		&"found_west_herb_tea", &"found_road_traveller_hood", &"found_road_traveller_bracers",
		&"found_town_quarry_helm", &"found_town_quarry_gauntlets", &"found_town_quarry_greaves",
		&"found_town_whitestone_ring"]


func before_each() -> void:
	gifts_already_given = false  # the gifts are what this script tests
	super.before_each()


func after_each() -> void:
	super.after_each()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"interact", &"attack"]:
		Input.action_release(action)


func _state(area: StringName, entry: StringName, flags: Array[StringName] = []) -> Adventure:
	var state := Adventure.new(area, entry)
	for flag in [&"forest_shrine_awakened", &"heard_of_shrine", &"equipment_seen"] + flags:
		state.set_flag(flag)
	state.checkpoint_area = &"forest"
	state.checkpoint_entry = &"shrine"
	return state


func _continue_with(state: Adventure) -> void:
	game.save_slot.save(state)
	assert_true(game.continue_saved())
	await _settle()


func _press(action: StringName) -> void:
	for pressed in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await wait_process_frames(2)
		await wait_physics_frames(1)


## Stands below `node`, faces it and interacts; returns what was said (the box is closed).
func _use(node: Node2D) -> String:
	_player().global_position = node.global_position + Vector2(0, 12)
	_player().face(Vector2.UP)
	await wait_physics_frames(4)
	_player().interactor.refresh_focus()
	var said := [""]
	var listen := func(_target: Interactable, message: String) -> void: said[0] = message
	_player().interactor.interacted.connect(listen)
	_player().interactor.interact(_player())
	_player().interactor.interacted.disconnect(listen)
	var hud: Hud = game.get_node(^"HUD")
	while hud.is_message_visible():
		hud.advance()
	await wait_physics_frames(3)
	return said[0]


func _fill_bag(adventure: Adventure) -> void:
	while Bag.free_spaces(adventure) > 0:
		adventure.add_item(&"pine_resin", 20)


func _trade_opens() -> bool:
	for i in 20:
		if game.is_trade_open():
			return true
		await wait_process_frames(1)
	return false


# ---------------------------------------------------------------- where things come from

## Every pickup and every gift line in every area, as the game loads them.
func _world() -> Dictionary:
	var pickups: Array[Dictionary] = []
	var gifts: Array[StringName] = []
	for area in Game.AREAS:
		var level: Node = (load(Game.AREAS[area]) as PackedScene).instantiate()
		for node in level.find_children("*", "", true, false):
			if node is ItemPickup:
				var pickup := node as ItemPickup
				pickups.append({"area": area, "item": pickup.item, "flag": pickup.flag, "money": pickup.money,
						"allowed_by": pickup.allowed_by, "legacy": pickup.legacy_flags})
			elif node is Npc:
				for line in (node as Npc).lines:
					if not line.gives.is_empty():
						gifts.append(line.gives)
		level.free()
	return {"pickups": pickups, "gifts": gifts}


func test_every_item_has_a_source_and_no_old_flag_is_reused() -> void:
	var world := _world()
	var sources := {Adventure.STARTING_WEAPON: ["start"]}
	var flags := {}
	for pickup: Dictionary in world["pickups"]:
		if not pickup["item"].is_empty():
			sources.get_or_add(pickup["item"], []).append("pickup in %s" % pickup["area"])
		assert_false(pickup["flag"].is_empty(), "every placed pickup has a flag")
		assert_false(flags.has(pickup["flag"]), "flag %s is used once" % pickup["flag"])
		flags[pickup["flag"]] = true
		assert_false(REMOVED_FLAGS.has(pickup["flag"]), "%s is never reused" % pickup["flag"])
	for id in world["gifts"]:
		sources.get_or_add(id, []).append("gift")
	for merchant in Commerce.MERCHANTS:
		for good: Dictionary in Commerce.MERCHANTS[merchant]["goods"]:
			sources.get_or_add(good["item"], []).append(merchant)
	for kind in Spoils.DROPS:
		sources.get_or_add(Spoils.DROPS[kind]["item"], []).append("drop")
	for id: StringName in ItemCatalog.ITEMS:
		assert_true(sources.has(id), "%s can be had" % id)
	assert_eq(ItemCatalog.ITEMS.size(), 41)
	assert_eq(world["pickups"].size(), 30, "the world's pickups after the move")
	# what moved is no longer lying around for free
	for pickup: Dictionary in world["pickups"]:
		if pickup["item"] == &"root_ring":
			assert_eq(pickup["area"], &"ruin", "the ring is the warden's reward")
		for id: StringName in [&"straw_hat", &"work_mitts", &"rope_sandals", &"traveller_shield", &"traveller_hood",
				&"traveller_bracers", &"traveller_boots", &"quarry_helm", &"quarry_gauntlets", &"quarry_greaves",
				&"herb_tea", &"woodcutter_hatchet", &"barrel_lid_buckler", &"carter_ring", &"whitestone_ring"]:
			assert_ne(pickup["item"], id, "%s is sold or given now" % id)
		if [&"crew_machete", &"crew_vest", &"crew_boots", &"crew_board_shield", &"quarry_maul",
				&"quarry_breastplate"].has(pickup["item"]):
			assert_eq(pickup["allowed_by"], &"town_crew_gear_given", "%s waits for Rufina" % pickup["item"])


# ---------------------------------------------------------------- trading

func test_trading_with_the_carter_with_real_keys() -> void:
	await _continue_with(_state(&"waystop", &"east"))
	assert_eq(await _talk("Carter"), "CARTER_MEET")
	assert_true(await _trade_opens(), "his goods open once what he said is read")
	var menu := game.trade_menu()
	await wait_physics_frames(2)
	assert_eq(game.level.process_mode, Node.PROCESS_MODE_DISABLED, "the area holds still")
	assert_eq(menu.selected(), &"herb_tea")
	await _press(&"attack")
	assert_ne(_player().state, Player.State.ATTACK, "no swing behind the merchant")
	await _press(&"interact")
	assert_eq(menu.step, TradeMenu.Step.AMOUNT, "two teas could be paid: how many?")
	await _press(&"move_right")
	assert_eq(menu.amount(), 2)
	await _press(&"move_right")
	assert_eq(menu.amount(), 2, "never more than the coppers pay for")
	await _press(&"move_left")
	await _press(&"interact")
	assert_eq(menu.step, TradeMenu.Step.CONFIRM, "a trade is always confirmed")
	assert_eq(game.adventure.money, Adventure.STARTING_MONEY, "nothing yet")
	await _press(&"interact")
	assert_eq(game.adventure.count(&"herb_tea"), 1)
	assert_eq(game.adventure.money, Adventure.STARTING_MONEY - 15)
	# a good too dear says so
	await _press(&"move_down")
	await _press(&"move_down")
	await _press(&"move_down")
	await _press(&"move_down")
	assert_eq(menu.selected(), &"traveller_boots")
	await _press(&"interact")
	assert_eq(menu.notice(), tr("TRADE_NO_MONEY"))
	assert_eq(menu.step, TradeMenu.Step.BROWSE)
	# sell the tea back: at a loss
	await _press(&"move_right")
	assert_eq(menu.column, TradeMenu.Column.OFFERS)
	assert_eq(menu.selected(), &"herb_tea")
	await _press(&"interact")
	await _press(&"ui_cancel")
	assert_eq(menu.step, TradeMenu.Step.BROWSE, "backing out changes nothing")
	assert_eq(game.adventure.count(&"herb_tea"), 1)
	await _press(&"interact")
	await _press(&"interact")
	assert_eq(game.adventure.count(&"herb_tea"), 0)
	assert_eq(game.adventure.money, Adventure.STARTING_MONEY - 15 + Commerce.sell_price(&"herb_tea"))
	await _press(&"ui_cancel")
	assert_false(game.is_trade_open())
	await wait_physics_frames(3)
	assert_ne(game.level.process_mode, Node.PROCESS_MODE_DISABLED, "the area moves again")
	# saved like any change
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	assert_eq(game.adventure.money, Adventure.STARTING_MONEY - 15 + Commerce.sell_price(&"herb_tea"))


func test_the_pause_key_closes_the_goods_without_pausing() -> void:
	await _continue_with(_state(&"waystop", &"east", [&"halt_carter_met"]))
	await _talk("Carter")
	assert_true(await _trade_opens())
	await _press(&"pause")
	assert_false(game.is_trade_open())
	assert_false(get_tree().paused, "no pause over the merchant")


func test_cida_trades_only_once_her_stall_is_back() -> void:
	var before := Adventure.new(&"village", &"north")
	before.set_flag(&"heard_of_shrine")
	await _continue_with(before)
	var stall: Node2D = game.level.get_node(^"Entities/CidaStall")
	assert_eq(await _use(stall), "CIDA_STALL_EMPTY")
	assert_false(await _trade_opens(), "an empty stall before the shrine")
	await _continue_with(_state(&"village", &"north"))
	await _talk("Cida")
	assert_false(await _trade_opens(), "talking to Cida stays talking")
	stall = game.level.get_node(^"Entities/CidaStall")
	assert_eq(await _use(stall), "CIDA_STALL")
	assert_true(await _trade_opens(), "her stall after it")
	assert_true(game.trade_menu().shown(TradeMenu.Column.GOODS).has(&"corn_bread"))
	assert_false(game.trade_menu().shown(TradeMenu.Column.GOODS).has(&"rope_sandals"), "sandals once the path is open")


# ---------------------------------------------------------------- gifts and the crew's gear

func test_anselmos_hatchet_is_given_once_and_waits_for_room() -> void:
	var state := _state(&"village", &"north", [&"elder_thanked"])
	_fill_bag(state)
	await _continue_with(state)
	var said := await _talk("Anselmo")
	assert_string_contains(said, tr("ITEM_WOODCUTTER_HATCHET"), "he means to give it")
	assert_eq(game.adventure.count(&"woodcutter_hatchet"), 0, "but the bag is full")
	assert_false(game.adventure.has_flag(&"gift_anselmo_hatchet"), "so it waits")
	game.adventure.remove_item(&"pine_resin", 20)
	said = await _talk("Anselmo")
	assert_eq(game.adventure.count(&"woodcutter_hatchet"), 1)
	assert_true(game.adventure.has_flag(&"gift_anselmo_hatchet"))
	assert_false((await _talk("Anselmo")).contains(tr("ITEM_WOODCUTTER_HATCHET")), "once")
	assert_eq(game.adventure.count(&"woodcutter_hatchet"), 1)


func test_a_hero_who_took_the_old_pickup_gets_no_second_gift() -> void:
	await _continue_with(_state(&"village", &"north", [&"elder_thanked", &"found_village_woodcutter_hatchet",
			&"village_hens_settled", &"found_village_barrel_lid_buckler"]))
	assert_false((await _talk("Anselmo")).contains(tr("ITEM_WOODCUTTER_HATCHET")))
	assert_false((await _talk("Cida")).contains(tr("ITEM_BARREL_LID_BUCKLER")))
	assert_eq(game.adventure.count(&"woodcutter_hatchet"), 0)
	assert_eq(game.adventure.count(&"barrel_lid_buckler"), 0)


func test_the_crews_gear_waits_for_rufinas_word() -> void:
	await _continue_with(_state(&"pedrabranca", &"east", [&"town_iara_met", &"town_rufina_heard",
			&"town_rufina_faced", &"town_notice_down"]))
	var maul: ItemPickup = game.level.get_node(^"Entities/Found_QuarryMaul")
	assert_eq(await _use(maul), "CREW_GEAR_REFUSED")
	assert_eq(game.adventure.count(&"quarry_maul"), 0)
	assert_eq(await _talk("Rufina"), "RUFINA_CREW_GEAR")
	assert_true(game.adventure.has_flag(&"town_crew_gear_given"))
	assert_string_contains(await _use(maul), tr("ITEM_QUARRY_MAUL"))
	assert_eq(game.adventure.count(&"quarry_maul"), 1)


func test_the_witch_leaves_her_charm_on_the_board_once_gone() -> void:
	await _continue_with(_state(&"waystop", &"east", [&"blank_witch_met", &"blank_view_seen", &"blank_map_drawn",
			&"blank_witch_gone"]))
	var charm: ItemPickup = game.level.get_node(^"Entities/Left_TravellerCharm")
	assert_true(charm.is_present(), "left for the hero who never heard her thanks")
	assert_string_contains(await _use(charm), tr("ITEM_TRAVELLER_CHARM"))
	assert_eq(game.adventure.count(&"traveller_charm"), 1)
	await _continue_with(_state(&"waystop", &"east", [&"blank_map_drawn", &"blank_witch_gone", &"gift_witch_charm"]))
	assert_null(game.level.get_node_or_null(^"Entities/Left_TravellerCharm"), "never twice")


func test_coppers_lie_in_the_world_once() -> void:
	await _continue_with(_state(&"forest", &"shrine"))
	var purse: ItemPickup = game.level.get_node(^"Entities/Found_Purse")
	assert_string_contains(await _use(purse), tr("MONEY_FOUND") % 12)
	assert_eq(game.adventure.money, Adventure.STARTING_MONEY + 12)
	assert_true(game.adventure.has_flag(&"found_forest_purse"))
	game.travel(&"forest", &"shrine")
	await _settle()
	assert_null(game.level.get_node_or_null(^"Entities/Found_Purse"))
	assert_eq(game.adventure.money, Adventure.STARTING_MONEY + 12)


# ---------------------------------------------------------------- the warden's chest

func test_the_warden_leaves_the_root_ring_in_his_hall() -> void:
	await _continue_with(_state(&"ruin", &"heart"))
	var chest: ItemPickup = game.level.get_node(CHEST)
	assert_false(chest.is_present(), "nothing before the victory")
	game.adventure.set_flag(&"ruin_warden_defeated")
	assert_true(chest.is_present(), "the roots part once he falls")
	var said := await _use(chest)
	assert_string_contains(said, tr("WARDEN_CHEST"))
	assert_string_contains(said, tr("ITEM_ROOT_RING"))
	assert_eq(game.adventure.count(&"root_ring"), 1)
	assert_true(game.adventure.has_flag(&"claimed_warden_root_ring"))
	assert_eq(await _use(chest), "", "an open chest has nothing more")
	assert_eq(game.adventure.count(&"root_ring"), 1)
	await _restart()
	assert_true(game.continue_saved())
	await _settle()
	game.travel(&"ruin", &"heart")
	await _settle()
	chest = game.level.get_node(CHEST)
	assert_true(chest.is_taken(), "claimed for good")
	assert_eq(game.adventure.count(&"root_ring"), 1, "and never doubled")


func test_a_full_bag_leaves_the_ring_in_the_chest() -> void:
	var state := _state(&"ruin", &"heart", [&"ruin_warden_defeated"])
	_fill_bag(state)
	await _continue_with(state)
	var chest: ItemPickup = game.level.get_node(CHEST)
	assert_eq(await _use(chest), "PICKUP_BAG_FULL")
	assert_false(chest.is_taken())
	assert_eq(game.adventure.count(&"root_ring"), 0)


func test_a_ring_taken_from_the_forest_is_the_wardens_reward() -> void:
	# the ring kept in the chest at home, the warden beaten: the hall's chest is already open
	var state := _state(&"ruin", &"heart", [&"ruin_warden_defeated", &"found_forest_root_ring"])
	state.add_item(&"root_ring")
	state.store(&"root_ring", 1)
	await _continue_with(state)
	var chest: ItemPickup = game.level.get_node(CHEST)
	assert_true(chest.visible)
	assert_true(chest.is_taken(), "what the hero has is not the question: it was found once")
	assert_eq(await _use(chest), "")
	assert_eq(game.adventure.count(&"root_ring") + game.adventure.stored(&"root_ring"), 1)
	# the ring taken in the forest, the warden not beaten yet: the chest waits, already open
	await _continue_with(_state(&"ruin", &"heart", [&"found_forest_root_ring"]))
	chest = game.level.get_node(CHEST)
	assert_false(chest.is_present())
	game.adventure.set_flag(&"ruin_warden_defeated")
	assert_true(chest.visible, "shown open")
	assert_true(chest.is_taken())


# ---------------------------------------------------------------- drops

func _drops() -> Array[ItemPickup]:
	var found: Array[ItemPickup] = []
	for node in game.level.find_children("Drop*", "", true, false):
		if node is ItemPickup and is_instance_valid(node):
			found.append(node as ItemPickup)
	return found


func test_a_cardosa_leaves_seeds_where_it_fell() -> void:
	await _continue_with(_state(&"west", &"east"))
	var plant: Cardosa = game.level.get_node(^"Entities/Cardosa1")
	var where := plant.global_position
	game.spoils_rng.seed = 3
	var probe := RandomNumberGenerator.new()
	probe.seed = 3
	var expected := Spoils.roll(&"Cardosa", probe)
	var seeds_before := game.adventure.count(&"cardosa_seed")
	var experience := game.adventure.experience
	plant.health.take_damage(999)
	await wait_physics_frames(4)
	assert_eq(game.adventure.experience, experience + HeroGrowth.for_creature(&"Cardosa"), "experience as before")
	var drops := _drops()
	if expected.is_empty():
		assert_eq(drops.size(), 0, "this seed leaves nothing")
		return
	assert_eq(drops.size(), 1, "one roll for one plant")
	assert_almost_eq(drops[0].global_position, where, Vector2.ONE, "where it fell")
	assert_true(drops[0].flag.is_empty(), "a drop is not saved")
	var said := await _use(drops[0])
	assert_string_contains(said, tr("ITEM_CARDOSA_SEED"))
	assert_eq(game.adventure.count(&"cardosa_seed"), seeds_before + int(expected["count"]))


func test_a_drop_waits_for_room_and_is_lost_only_if_left_behind() -> void:
	var state := _state(&"west", &"east")
	_fill_bag(state)
	await _continue_with(state)
	# find a seed that drops
	var chosen := -1
	for candidate in 50:
		var probe := RandomNumberGenerator.new()
		probe.seed = candidate
		if not Spoils.roll(&"Cardosa", probe).is_empty():
			chosen = candidate
			break
	game.spoils_rng.seed = chosen
	var plant: Cardosa = game.level.get_node(^"Entities/Cardosa2")
	plant.health.take_damage(999)
	await wait_physics_frames(4)
	var drops := _drops()
	assert_eq(drops.size(), 1)
	assert_eq(await _use(drops[0]), "PICKUP_BAG_FULL")
	assert_true(is_instance_valid(drops[0]) and drops[0].is_present(), "it stays on the ground")
	var saved := FileAccess.get_file_as_string(save_dir().path_join("save.json"))
	assert_false(saved.contains("Drop"), "and is never written down")


# ---------------------------------------------------------------- older saves

func test_a_74_save_meets_the_new_world() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES.path_join("v7_skilled.json")))
	var adventure := Adventure.from_dict(data)
	assert_not_null(adventure)
	assert_eq(adventure.money, Adventure.STARTING_MONEY, "the starting purse, once")
	assert_eq(adventure.skills().size(), 2, "skills kept")
	assert_eq(adventure.stored(&"root_ring"), 1, "the chest at home untouched")
	for id: StringName in [&"straw_hat", &"traveller_shield", &"traveller_charm", &"woodcutter_hatchet", &"crew_vest"]:
		assert_eq(adventure.count(id), 1, "%s kept" % id)
	assert_eq(Commerce.remaining(adventure, Commerce.CIDA, &"straw_hat"), 0, "her hat was the one taken")
	assert_eq(Commerce.remaining(adventure, Commerce.CARTER, &"traveller_shield"), 0)
	assert_eq(Commerce.remaining(adventure, Commerce.CARTER, &"traveller_boots"), 1, "never taken: still his")
	game.save_slot.save(adventure)
	assert_true(game.continue_saved())
	await _settle()
	game.travel(&"ruin", &"heart")
	await _settle()
	assert_true((game.level.get_node(CHEST) as ItemPickup).is_taken(), "the ring was found once already")
	game.travel(&"waystop", &"east")
	await _settle()
	assert_null(game.level.get_node_or_null(^"Entities/Left_TravellerCharm"), "the charm was found once already")
	game.travel(&"road_slope", &"trail")
	await _settle()
	assert_true((game.level.get_node(^"Entities/Found_CrewVest") as ItemPickup).is_taken(), "the vest too")
	assert_eq(game.adventure.money, Adventure.STARTING_MONEY, "travelling and continuing never pay again")


func test_a_71_save_with_the_forest_ring_and_no_victory() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES.path_join("v4_combat_reforged.json")))
	var adventure := Adventure.from_dict(data)
	assert_not_null(adventure)
	assert_eq(adventure.count(&"root_ring"), 1)
	assert_eq(adventure.equipped(ItemCatalog.RING_2), &"root_ring", "still worn")
	assert_eq(Commerce.remaining(adventure, Commerce.CARTER, &"traveller_boots"), 0, "the far bank's boots were his")
	adventure.area = &"waystop"
	game.save_slot.save(adventure)
	assert_true(game.continue_saved())
	await _settle()
	var said := await _talk("Carter")
	assert_eq(said, "CARTER_MEET", "no ring offered: it was found on the far bank, and the road is not drawn yet")
	assert_true(await _trade_opens())
	game.trade_menu().close()
	await wait_physics_frames(3)
	game.adventure.set_flag(&"blank_map_drawn")
	assert_false((await _talk("Carter")).contains(tr("ITEM_CARTER_RING")), "nor after: it was found once")
	assert_eq(game.adventure.count(&"carter_ring"), 1)
