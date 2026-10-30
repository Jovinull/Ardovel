class_name Storage
extends RefCounted
## What may go between the bag and the chest at home. The chest counts spaces as the bag does (a
## stack takes one space per `stack_limit`, an unknown item one per copy) and has its own capacity.
## Only loose copies go into the chest: a piece being worn is taken off in the hero's menu first, so
## the main hand is never emptied this way. A move happens whole or not at all, and says why not.

## Spaces in the chest (a balance parameter: change it here only). Twice the bag: everything the
## world holds today fits in it with room to spare, without making it bottomless.
const CAPACITY := 80

enum Result {
	MOVED,
	## Nothing to move (no such copies, or a count below one).
	NOTHING,
	## The only copies are being worn.
	WORN,
	CHEST_FULL,
	BAG_FULL,
}


## Copies of `id` the hero has that are not worn.
static func loose(adventure: Adventure, id: StringName) -> int:
	return adventure.count(id) - adventure.equipped_copies(id)


static func spaces_used(adventure: Adventure) -> int:
	var used := 0
	for id in adventure.stored_items():
		used += Bag.spaces_for(ItemCatalog.find(id), adventure.stored(id))
	return used


static func free_spaces(adventure: Adventure) -> int:
	return CAPACITY - spaces_used(adventure)


## Whether `amount` more of `id` fit in the chest.
static func has_room_for(adventure: Adventure, id: StringName, amount: int) -> bool:
	var item := ItemCatalog.find(id)
	var kept := adventure.stored(id)
	return Bag.spaces_for(item, kept + amount) - Bag.spaces_for(item, kept) <= free_spaces(adventure)


## Whether `amount` of `id` can go from the bag into the chest now.
static func check_store(adventure: Adventure, id: StringName, amount: int) -> Result:
	if amount <= 0 or not adventure.has_item(id):
		return Result.NOTHING
	if loose(adventure, id) < amount:
		return Result.WORN if loose(adventure, id) == 0 else Result.NOTHING
	if not has_room_for(adventure, id, amount):
		return Result.CHEST_FULL
	return Result.MOVED


## Whether `amount` of `id` can come out of the chest into the bag now.
static func check_retrieve(adventure: Adventure, id: StringName, amount: int) -> Result:
	if amount <= 0 or adventure.stored(id) < amount:
		return Result.NOTHING
	if not Bag.has_room_for(adventure, id, amount):
		return Result.BAG_FULL
	return Result.MOVED


static func store(adventure: Adventure, id: StringName, amount: int) -> Result:
	var result := check_store(adventure, id, amount)
	if result == Result.MOVED and not adventure.store(id, amount):
		return Result.NOTHING
	return result


static func retrieve(adventure: Adventure, id: StringName, amount: int) -> Result:
	var result := check_retrieve(adventure, id, amount)
	if result == Result.MOVED and not adventure.retrieve(id, amount):
		return Result.NOTHING
	return result


## The most of `id` that could go into the chest now (0: none).
static func most_to_store(adventure: Adventure, id: StringName) -> int:
	var most := loose(adventure, id)
	while most > 0 and not has_room_for(adventure, id, most):
		most -= 1
	return most


## The most of `id` that could come back to the bag now (0: none).
static func most_to_retrieve(adventure: Adventure, id: StringName) -> int:
	var most := adventure.stored(id)
	while most > 0 and not Bag.has_room_for(adventure, id, most):
		most -= 1
	return most
