class_name Bag
extends RefCounted
## What fits in the hero's bag. Worn pieces take no space; every other copy of a piece of
## equipment takes one, and a stack takes one space per `stack_limit` (or part of it). A pickup
## that does not fit stays where it is: nothing is ever destroyed for want of room.

## Spaces in the bag (a balance parameter: change it here only).
const CAPACITY := 40


## Spaces `count` loose copies of `item` take.
static func spaces_for(item: ItemDef, count: int) -> int:
	if count <= 0:
		return 0
	var limit := maxi(item.stack_limit if item != null else 1, 1)
	return ceili(float(count) / limit)


## Spaces in use: the loose (not worn) copies of everything the hero has. An unknown item takes one
## space per copy.
static func spaces_used(adventure: Adventure) -> int:
	var used := 0
	for id in adventure.items():
		used += spaces_for(ItemCatalog.find(id), adventure.count(id) - adventure.equipped_copies(id))
	return used


static func free_spaces(adventure: Adventure) -> int:
	return CAPACITY - spaces_used(adventure)


## Whether `amount` more loose copies of `id` fit.
static func has_room_for(adventure: Adventure, id: StringName, amount: int = 1) -> bool:
	var item := ItemCatalog.find(id)
	var loose := adventure.count(id) - adventure.equipped_copies(id)
	var extra := spaces_for(item, loose + amount) - spaces_for(item, loose)
	return extra <= free_spaces(adventure)


## Adds `amount` of a known item if it all fits; false (and nothing added) otherwise.
static func try_add(adventure: Adventure, id: StringName, amount: int = 1) -> bool:
	if not ItemCatalog.knows(id) or amount <= 0 or not has_room_for(adventure, id, amount):
		return false
	return adventure.add_item(id, amount)
