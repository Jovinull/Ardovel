class_name Commerce
extends RefCounted
## What each merchant sells and buys, and for how much, in coppers. A balance table: change prices
## and goods here only.
##
## Goods are repeatable (always there: food, drink) or limited (a few copies; the ones bought are
## counted in the adventure). A limited good that used to lie in the world before merchants existed
## names that old pickup's flag (`legacy`): a hero who took it then took that copy, so the merchant
## has one fewer (nothing is given twice, nothing is taken away). Some goods only appear after an
## event (`unlock`).
##
## Buying and selling happen whole or not at all (one change of the adventure). What the hero is
## paid is fixed per item (SELL), always below every price asked for it, so no round of buying and
## selling can make coppers. Only common goods and materials can be sold: the starting sword,
## unique finds, gifts and rewards cannot (one source each; selling them would lose them for good).
## Selling a merchant's limited good back to that merchant puts it back among their goods.

enum Result {
	DONE,
	## Nothing to trade (no such copies, an amount below one, or not among the goods now).
	NOTHING,
	## All the limited copies are bought.
	SOLD_OUT,
	## Too few coppers.
	MONEY,
	BAG_FULL,
	## This merchant does not buy this kind of thing.
	NOT_WANTED,
	## It is never sold (a unique find, a gift, a reward, the starting sword).
	KEEPSAKE,
	## The only copies are being worn.
	WORN,
	## The purse would pass Adventure.MAX_MONEY.
	PURSE_FULL,
}

const CIDA := &"cida_stall"
const CARTER := &"salt_carter"
const STOREROOM := &"crew_storeroom"
## The most traded at once.
const MOST_AT_ONCE := 99

## Merchant -> name (translation key), the categories they buy, and their goods in the order shown:
## item, price, stock (0: always there), the flag that brings it (empty: from the start), and the
## flag of the pickup that held it before merchants existed.
const MERCHANTS: Dictionary[StringName, Dictionary] = {
	CIDA: {
		"name": "NPC_CIDA",
		"buys": [ItemCatalog.CONSUMABLE, ItemCatalog.MATERIAL],
		"goods": [
			{"item": &"corn_bread", "price": 6, "stock": 0},
			{"item": &"wild_honey", "price": 4, "stock": 0},
			{"item": &"straw_hat", "price": 12, "stock": 1, "legacy": &"found_village_straw_hat"},
			{"item": &"work_mitts", "price": 10, "stock": 1, "legacy": &"found_village_work_mitts"},
			{"item": &"rope_sandals", "price": 20, "stock": 1, "legacy": &"found_village_rope_sandals",
				"unlock": &"cida_path_acknowledged"},
		],
	},
	CARTER: {
		"name": "NPC_CARTER",
		"buys": [ItemCatalog.SHIELD, ItemCatalog.ARMOR, ItemCatalog.CONSUMABLE, ItemCatalog.MATERIAL],
		"goods": [
			{"item": &"herb_tea", "price": 15, "stock": 0},
			{"item": &"corn_bread", "price": 7, "stock": 0},
			{"item": &"traveller_hood", "price": 25, "stock": 1, "legacy": &"found_road_traveller_hood"},
			{"item": &"traveller_bracers", "price": 30, "stock": 1, "legacy": &"found_road_traveller_bracers"},
			{"item": &"traveller_boots", "price": 35, "stock": 1, "legacy": &"found_bank_traveller_boots"},
			{"item": &"traveller_shield", "price": 60, "stock": 1, "legacy": &"found_halt_traveller_shield",
				"unlock": &"blank_map_drawn"},
		],
	},
	STOREROOM: {
		"name": "NPC_STOREKEEPER",
		"buys": [ItemCatalog.SHIELD, ItemCatalog.ARMOR, ItemCatalog.CONSUMABLE, ItemCatalog.MATERIAL],
		"goods": [
			{"item": &"corn_bread", "price": 7, "stock": 0},
			{"item": &"quarry_helm", "price": 55, "stock": 1, "legacy": &"found_town_quarry_helm"},
			{"item": &"quarry_gauntlets", "price": 60, "stock": 1, "legacy": &"found_town_quarry_gauntlets"},
			{"item": &"quarry_greaves", "price": 70, "stock": 1, "legacy": &"found_town_quarry_greaves",
				"unlock": &"town_notice_down"},
		],
	},
}

## What the hero is paid for one copy (items not listed are never sold). Below every price asked.
const SELL: Dictionary[StringName, int] = {
	&"corn_bread": 2,
	&"wild_honey": 1,
	&"herb_tea": 5,
	&"white_stone_chip": 2,
	&"pine_resin": 3,
	&"root_fiber": 2,
	&"cardosa_seed": 2,
	&"old_bronze": 12,
	&"straw_hat": 4,
	&"work_mitts": 4,
	&"rope_sandals": 8,
	&"traveller_hood": 10,
	&"traveller_bracers": 12,
	&"traveller_boots": 14,
	&"traveller_shield": 24,
	&"quarry_helm": 22,
	&"quarry_gauntlets": 24,
	&"quarry_greaves": 28,
}


static func knows(merchant: StringName) -> bool:
	return MERCHANTS.has(merchant)


## The merchant's name (a translation key).
static func name_of(merchant: StringName) -> String:
	return MERCHANTS[merchant]["name"] if knows(merchant) else ""


## The goods on offer now (unlocked), in the order shown, sold out or not.
static func goods(adventure: Adventure, merchant: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	if not knows(merchant):
		return ids
	for good: Dictionary in MERCHANTS[merchant]["goods"]:
		var unlock: StringName = good.get("unlock", &"")
		if unlock.is_empty() or adventure.has_flag(unlock):
			ids.append(good["item"])
	return ids


static func _good(merchant: StringName, id: StringName) -> Dictionary:
	if not knows(merchant):
		return {}
	for good: Dictionary in MERCHANTS[merchant]["goods"]:
		if good["item"] == id:
			return good
	return {}


## Price of one `id` at `merchant` (-1: not sold there).
static func price(merchant: StringName, id: StringName) -> int:
	var good := _good(merchant, id)
	return good["price"] if not good.is_empty() else -1


static func is_limited(merchant: StringName, id: StringName) -> bool:
	var good := _good(merchant, id)
	return not good.is_empty() and int(good["stock"]) > 0


## Copies of `id` `merchant` still has (-1: always there; 0: none, or not sold there).
static func remaining(adventure: Adventure, merchant: StringName, id: StringName) -> int:
	var good := _good(merchant, id)
	if good.is_empty():
		return 0
	var stock: int = good["stock"]
	if stock <= 0:
		return -1
	var taken := adventure.bought(merchant, id)
	var legacy: StringName = good.get("legacy", &"")
	if not legacy.is_empty() and adventure.has_flag(legacy):
		taken += 1
	return maxi(stock - taken, 0)


## Whether `amount` of `id` can be bought from `merchant` now.
static func check_buy(adventure: Adventure, merchant: StringName, id: StringName, amount: int) -> Result:
	if amount <= 0 or amount > MOST_AT_ONCE or not goods(adventure, merchant).has(id) or not ItemCatalog.knows(id):
		return Result.NOTHING
	var left := remaining(adventure, merchant, id)
	if left == 0 or (left > 0 and amount > left):
		return Result.SOLD_OUT
	if price(merchant, id) * amount > adventure.money:
		return Result.MONEY
	if not Bag.has_room_for(adventure, id, amount):
		return Result.BAG_FULL
	return Result.DONE


static func buy(adventure: Adventure, merchant: StringName, id: StringName, amount: int) -> Result:
	var result := check_buy(adventure, merchant, id, amount)
	if result == Result.DONE and not adventure.buy(merchant, id, amount, price(merchant, id) * amount,
			is_limited(merchant, id)):
		return Result.NOTHING
	return result


## What the hero is paid for one `id` (0: it is never sold).
static func sell_price(id: StringName) -> int:
	return SELL.get(id, 0)


## Whether `merchant` takes `id` at all (its kind, and whether it is ever sold).
static func wants(merchant: StringName, id: StringName) -> bool:
	var item := ItemCatalog.find(id)
	return knows(merchant) and item != null and sell_price(id) > 0 \
			and (MERCHANTS[merchant]["buys"] as Array).has(item.category)


## The things the hero carries that `merchant` would take (worn ones included: they are refused
## with a reason), in the order first found.
static func offers(adventure: Adventure, merchant: StringName) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in adventure.items():
		if wants(merchant, id):
			ids.append(id)
	return ids


## Whether `amount` of `id` can be sold to `merchant` now.
static func check_sell(adventure: Adventure, merchant: StringName, id: StringName, amount: int) -> Result:
	if amount <= 0 or amount > MOST_AT_ONCE or not adventure.has_item(id):
		return Result.NOTHING
	if sell_price(id) <= 0:
		return Result.KEEPSAKE
	if not wants(merchant, id):
		return Result.NOT_WANTED
	var loose := Storage.loose(adventure, id)
	if loose < amount:
		return Result.WORN if loose == 0 else Result.NOTHING
	if sell_price(id) * amount > Adventure.MAX_MONEY - adventure.money:
		return Result.PURSE_FULL
	return Result.DONE


static func sell(adventure: Adventure, merchant: StringName, id: StringName, amount: int) -> Result:
	var result := check_sell(adventure, merchant, id, amount)
	if result == Result.DONE and not adventure.sell(merchant, id, amount, sell_price(id) * amount,
			is_limited(merchant, id)):
		return Result.NOTHING
	return result


## The most of `id` that could be bought now (0: none).
static func most_to_buy(adventure: Adventure, merchant: StringName, id: StringName) -> int:
	var most := MOST_AT_ONCE
	var left := remaining(adventure, merchant, id)
	if left >= 0:
		most = mini(most, left)
	var each := price(merchant, id)
	if each > 0:
		most = mini(most, adventure.money / each)
	while most > 0 and check_buy(adventure, merchant, id, most) != Result.DONE:
		most -= 1
	return most


## The most of `id` that could be sold now (0: none).
static func most_to_sell(adventure: Adventure, merchant: StringName, id: StringName) -> int:
	var most := mini(Storage.loose(adventure, id), MOST_AT_ONCE)
	while most > 0 and check_sell(adventure, merchant, id, most) != Result.DONE:
		most -= 1
	return most
