extends GutTest
## Coppers and merchants as rules and record: the purse (never below nothing, never past its
## limit), buying and selling whole or not at all, limited and repeatable goods, goods that were
## once lying in the world, goods that arrive with an event, what is never sold, prices that leave
## no profit in any round of trades, drops, and the save format (version 8: the purse and what was
## bought; upgrades from every older version with the starting purse).

const FIXTURES := "res://tests/fixtures/saves"
const BREAD := &"corn_bread"
const HAT := &"straw_hat"
const TEA := &"herb_tea"
const CIDA := Commerce.CIDA
const CARTER := Commerce.CARTER
const STOREROOM := Commerce.STOREROOM


func _round_trip(adventure: Adventure) -> Adventure:
	return Adventure.from_dict(JSON.parse_string(JSON.stringify(adventure.to_dict())))


## Fills the bag to the brim with stacks of resin (none of them breakable into the goods tested).
func _fill_bag(adventure: Adventure) -> void:
	while Bag.free_spaces(adventure) > 0:
		adventure.add_item(&"pine_resin", 20)


func test_a_new_hero_starts_with_a_small_purse() -> void:
	var adventure := Adventure.new()
	assert_eq(adventure.money, Adventure.STARTING_MONEY)
	assert_between(Adventure.STARTING_MONEY, 1, 60, "enough for bread, not for the road's gear")
	assert_eq(adventure.purchases(), {} as Dictionary[StringName, int])


func test_earning_never_overflows_and_refuses_whole() -> void:
	var adventure := Adventure.new()
	assert_false(adventure.earn(0))
	assert_false(adventure.earn(-5), "nothing negative")
	assert_true(adventure.earn(Adventure.MAX_MONEY - adventure.money))
	assert_eq(adventure.money, Adventure.MAX_MONEY)
	assert_false(adventure.earn(1), "a full purse refuses")
	assert_eq(adventure.money, Adventure.MAX_MONEY, "and keeps what it had")


func test_buying_pays_and_takes_in_one_change() -> void:
	var adventure := Adventure.new()
	var changes := [0]
	adventure.changed.connect(func() -> void: changes[0] += 1)
	assert_eq(Commerce.buy(adventure, CIDA, BREAD, 2), Commerce.Result.DONE)
	assert_eq(adventure.money, Adventure.STARTING_MONEY - 2 * Commerce.price(CIDA, BREAD))
	assert_eq(adventure.count(BREAD), 2)
	assert_eq(changes[0], 1, "one save, never half a trade")
	assert_eq(adventure.bought(CIDA, BREAD), 0, "bread is always there: nothing is counted")


func test_too_few_coppers_changes_nothing() -> void:
	var adventure := Adventure.new()
	adventure.money = 5
	var before := adventure.to_dict()
	assert_eq(Commerce.check_buy(adventure, CIDA, BREAD, 1), Commerce.Result.MONEY)
	assert_eq(Commerce.buy(adventure, CIDA, BREAD, 1), Commerce.Result.MONEY)
	assert_eq(adventure.to_dict(), before)
	assert_eq(Commerce.most_to_buy(adventure, CIDA, BREAD), 0)
	adventure.money = 18
	assert_eq(Commerce.most_to_buy(adventure, CIDA, BREAD), 3, "as many as the coppers pay for")


func test_a_full_bag_refuses_and_keeps_the_coppers() -> void:
	var adventure := Adventure.new()
	_fill_bag(adventure)
	var money := adventure.money
	assert_eq(Commerce.buy(adventure, CIDA, HAT, 1), Commerce.Result.BAG_FULL)
	assert_eq(adventure.money, money)
	assert_eq(adventure.count(HAT), 0)


func test_limited_goods_run_out_and_come_back_when_sold_back() -> void:
	var adventure := Adventure.new()
	assert_eq(Commerce.remaining(adventure, CIDA, HAT), 1)
	assert_eq(Commerce.buy(adventure, CIDA, HAT, 2), Commerce.Result.SOLD_OUT, "never more than there are")
	assert_eq(Commerce.buy(adventure, CIDA, HAT, 1), Commerce.Result.DONE)
	assert_eq(Commerce.remaining(adventure, CIDA, HAT), 0)
	assert_eq(Commerce.buy(adventure, CIDA, HAT, 1), Commerce.Result.SOLD_OUT)
	assert_eq(_round_trip(adventure).bought(CIDA, HAT), 1, "what was bought is saved")
	# Cida does not take hats; the carter does, but they are not his goods
	assert_eq(Commerce.sell(adventure, CIDA, HAT, 1), Commerce.Result.NOT_WANTED)
	adventure.add_item(HAT)  # a second hat, whatever its origin
	assert_eq(Commerce.sell(adventure, CARTER, HAT, 1), Commerce.Result.DONE)
	assert_eq(Commerce.remaining(adventure, CIDA, HAT), 0, "sold elsewhere: Cida's shelf stays as it was")


func test_a_good_sold_back_returns_to_its_merchant() -> void:
	var adventure := Adventure.new()
	adventure.money = 200
	assert_eq(Commerce.buy(adventure, CARTER, &"traveller_hood", 1), Commerce.Result.DONE)
	assert_eq(Commerce.remaining(adventure, CARTER, &"traveller_hood"), 0)
	assert_eq(Commerce.sell(adventure, CARTER, &"traveller_hood", 1), Commerce.Result.DONE)
	assert_eq(Commerce.remaining(adventure, CARTER, &"traveller_hood"), 1, "back on his cart")
	assert_eq(adventure.purchases(), {} as Dictionary[StringName, int])
	assert_eq(adventure.money, 200 - 25 + 10, "at a loss")


func test_a_good_once_lying_in_the_world_was_that_copy() -> void:
	var adventure := Adventure.new()
	adventure.set_flag(&"found_village_straw_hat")
	assert_eq(Commerce.remaining(adventure, CIDA, HAT), 0, "the hat taken from the old pickup was Cida's")
	assert_eq(Commerce.buy(adventure, CIDA, HAT, 1), Commerce.Result.SOLD_OUT, "never given twice")
	assert_eq(Commerce.remaining(adventure, CIDA, BREAD), -1, "repeatable goods are not affected")


func test_some_goods_arrive_with_an_event() -> void:
	var adventure := Adventure.new()
	assert_false(Commerce.goods(adventure, STOREROOM).has(&"quarry_greaves"))
	assert_eq(Commerce.buy(adventure, STOREROOM, &"quarry_greaves", 1), Commerce.Result.NOTHING)
	assert_false(Commerce.goods(adventure, CARTER).has(&"traveller_shield"))
	assert_false(Commerce.goods(adventure, CIDA).has(&"rope_sandals"))
	adventure.set_flag(&"town_notice_down")
	adventure.set_flag(&"blank_map_drawn")
	adventure.set_flag(&"cida_path_acknowledged")
	assert_true(Commerce.goods(adventure, STOREROOM).has(&"quarry_greaves"))
	assert_true(Commerce.goods(adventure, CARTER).has(&"traveller_shield"))
	assert_true(Commerce.goods(adventure, CIDA).has(&"rope_sandals"))


func test_keepsakes_and_worn_pieces_are_never_sold() -> void:
	var adventure := Adventure.new()
	assert_eq(Commerce.check_sell(adventure, CARTER, Adventure.STARTING_WEAPON, 1), Commerce.Result.KEEPSAKE,
			"the starting sword is never sold")
	for id: StringName in [&"root_ring", &"ruin_blade", &"quill_ring", &"crew_gloves", &"padded_doublet",
			&"woodcutter_hatchet", &"carter_ring", &"traveller_charm", &"quarry_maul", &"herb_pouch"]:
		adventure.add_item(id)
		assert_eq(Commerce.check_sell(adventure, CARTER, id, 1), Commerce.Result.KEEPSAKE, String(id))
	adventure.money = 100
	Commerce.buy(adventure, CARTER, &"traveller_boots", 1)
	Equipment.equip(adventure, ItemCatalog.LEGS, &"traveller_boots")
	assert_eq(Commerce.check_sell(adventure, CARTER, &"traveller_boots", 1), Commerce.Result.WORN)
	assert_false(Commerce.offers(adventure, CARTER).has(Adventure.STARTING_WEAPON), "not even offered")


func test_selling_pays_in_one_change_and_respects_the_purse() -> void:
	var adventure := Adventure.new()
	adventure.add_item(&"old_bronze", 2)
	var changes := [0]
	adventure.changed.connect(func() -> void: changes[0] += 1)
	assert_eq(Commerce.sell(adventure, STOREROOM, &"old_bronze", 2), Commerce.Result.DONE)
	assert_eq(changes[0], 1)
	assert_eq(adventure.money, Adventure.STARTING_MONEY + 24)
	assert_eq(adventure.count(&"old_bronze"), 0)
	adventure.add_item(&"old_bronze", 1)
	adventure.money = Adventure.MAX_MONEY - 5
	assert_eq(Commerce.sell(adventure, STOREROOM, &"old_bronze", 1), Commerce.Result.PURSE_FULL)
	assert_eq(adventure.count(&"old_bronze"), 1, "nothing taken for a sale that cannot be paid")


func test_no_price_leaves_a_profit() -> void:
	for merchant in Commerce.MERCHANTS:
		for good: Dictionary in Commerce.MERCHANTS[merchant]["goods"]:
			var id: StringName = good["item"]
			assert_true(ItemCatalog.knows(id), String(id))
			assert_gt(int(good["price"]), 0, String(id))
			assert_lt(Commerce.sell_price(id), int(good["price"]), "%s at %s" % [id, merchant])
	for id in Commerce.SELL:
		assert_true(ItemCatalog.knows(id), String(id))
		assert_gt(Commerce.sell_price(id), 0)


func test_every_merchant_good_of_the_plan_is_sold_somewhere() -> void:
	var sold := {}
	for merchant in Commerce.MERCHANTS:
		for good: Dictionary in Commerce.MERCHANTS[merchant]["goods"]:
			sold[good["item"]] = true
	for id: StringName in [&"traveller_shield", &"straw_hat", &"traveller_hood", &"quarry_helm", &"work_mitts",
			&"traveller_bracers", &"quarry_gauntlets", &"rope_sandals", &"traveller_boots", &"quarry_greaves", BREAD,
			TEA, &"wild_honey"]:
		assert_true(sold.has(id), String(id))


func test_no_round_of_trades_makes_coppers_and_nothing_is_doubled() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 75
	var adventure := Adventure.new()
	for flag: StringName in [&"town_notice_down", &"blank_map_drawn", &"cida_path_acknowledged"]:
		adventure.set_flag(flag)
	adventure.money = 500
	var merchants: Array[StringName] = [CIDA, CARTER, STOREROOM]
	for i in 600:
		var merchant := merchants[random.randi() % merchants.size()]
		var goods := Commerce.goods(adventure, merchant)
		var amount := random.randi_range(-1, 4)
		if random.randf() < 0.5 and not goods.is_empty():
			Commerce.buy(adventure, merchant, goods[random.randi() % goods.size()], amount)
		else:
			var offers := Commerce.offers(adventure, merchant)
			if not offers.is_empty():
				Commerce.sell(adventure, merchant, offers[random.randi() % offers.size()], amount)
		assert_between(adventure.money, 0, Adventure.MAX_MONEY)
		assert_lte(Bag.spaces_used(adventure), Bag.CAPACITY)
		for merchant_id in merchants:
			for id in Commerce.goods(adventure, merchant_id):
				var left := Commerce.remaining(adventure, merchant_id, id)
				assert_true(left == -1 or left >= 0)
		if i % 100 == 0:
			adventure = _round_trip(adventure)
	# sell everything back: never more than the 500 coppers the hero began with
	for merchant in merchants:
		for id in Commerce.offers(adventure, merchant):
			Commerce.sell(adventure, merchant, id, Commerce.most_to_sell(adventure, merchant, id))
	assert_lte(adventure.money, 500, "buying and selling only ever costs")


func test_drops_follow_their_table_and_their_seed() -> void:
	var first := RandomNumberGenerator.new()
	first.seed = 7
	var second := RandomNumberGenerator.new()
	second.seed = 7
	var rolls: Array = []
	for i in 40:
		var a := Spoils.roll(&"Cardosa", first)
		assert_eq(a, Spoils.roll(&"Cardosa", second), "the same seed, the same drops")
		rolls.append(a)
	var any := 0
	for roll: Dictionary in rolls:
		if not roll.is_empty():
			any += 1
			assert_eq(roll["item"], &"cardosa_seed")
			assert_between(int(roll["count"]), 1, 2)
	assert_between(any, 10, 30, "about half")
	assert_eq(Spoils.roll(&"Musgorico", first), {}, "moss leaves nothing")
	assert_eq(Spoils.roll(&"RootWarden", first), {})


func test_format_8_round_trip() -> void:
	var adventure := Adventure.new()
	adventure.money = 120
	Commerce.buy(adventure, CIDA, HAT, 1)
	var data := JSON.parse_string(JSON.stringify(adventure.to_dict())) as Dictionary
	assert_eq(int(data["version"]), Adventure.FORMAT_VERSION)
	assert_eq(int(data["money"]), 108)
	assert_eq(data["purchases"], {"cida_stall/straw_hat": 1.0})
	var back := Adventure.from_dict(data)
	assert_eq(back.money, 108)
	assert_eq(back.bought(CIDA, HAT), 1)
	assert_eq(back.to_dict(), adventure.to_dict())


func test_malformed_purses_are_unreadable() -> void:
	var base := Adventure.new().to_dict()
	assert_not_null(Adventure.from_dict(base))
	for bad: Variant in [-1, Adventure.MAX_MONEY + 1, 1.5, "30", null]:
		var data := base.duplicate(true)
		data["money"] = bad
		assert_null(Adventure.from_dict(data), "money %s" % [bad])
	for bad: Variant in [[], {"straw_hat": 1}, {"cida_stall/straw_hat": -1}, {"cida_stall/straw_hat": 0.5}, null]:
		var data := base.duplicate(true)
		data["purchases"] = bad
		assert_null(Adventure.from_dict(data), "purchases %s" % [bad])


func test_every_older_version_gets_the_starting_purse_once() -> void:
	for file_name in ["v1_back_in_village.json", "v2_second_spring.json", "v2_blank_paths.json",
			"v2_after_pedrabranca.json", "v3_gloves_worn.json", "v4_combat_reforged.json", "v4_quarry_kit.json",
			"v5_chest_kept.json", "v6_grown.json", "v7_skilled.json"]:
		var text := FileAccess.get_file_as_string(FIXTURES.path_join(file_name))
		var adventure := Adventure.from_dict(JSON.parse_string(text))
		assert_not_null(adventure, file_name)
		assert_eq(adventure.money, Adventure.STARTING_MONEY, file_name)
		assert_eq(adventure.purchases(), {} as Dictionary[StringName, int], file_name)
		var again := _round_trip(adventure)
		assert_eq(again.money, Adventure.STARTING_MONEY, "%s: upgraded once, not again" % file_name)
		assert_eq(again.to_dict(), adventure.to_dict(), file_name)
		assert_eq(Adventure.from_dict(JSON.parse_string(text)).to_dict(), adventure.to_dict(),
				"%s: loading twice gives the same" % file_name)
