class_name Equipment
extends RefCounted
## Which piece goes where. A slot takes only items of its kind; equipping replaces what was there
## (the old piece goes back to the bag, into the space the new one leaves); taking a piece off needs
## a space in the bag; the main hand always holds a weapon.


## Ids the hero has that could go in `slot`, in the order found.
static func candidates(adventure: Adventure, slot: StringName) -> Array[StringName]:
	var found: Array[StringName] = []
	for id in adventure.items():
		if ItemCatalog.fits(ItemCatalog.find(id), slot):
			found.append(id)
	return found


## Whether `id` can be put in `slot` now (a copy not worn elsewhere).
static func can_equip(adventure: Adventure, slot: StringName, id: StringName) -> bool:
	if not ItemCatalog.fits(ItemCatalog.find(id), slot) or adventure.equipped(slot) == id:
		return false
	return adventure.count(id) > adventure.equipped_copies(id)


static func equip(adventure: Adventure, slot: StringName, id: StringName) -> bool:
	return can_equip(adventure, slot, id) and adventure.equip(slot, id)


## Whether the piece in `slot` can be taken off now.
static func can_unequip(adventure: Adventure, slot: StringName) -> bool:
	var id := adventure.equipped(slot)
	if id.is_empty() or slot == ItemCatalog.MAIN_HAND:
		return false
	return Bag.has_room_for(adventure, id)


static func unequip(adventure: Adventure, slot: StringName) -> bool:
	return can_unequip(adventure, slot) and adventure.unequip(slot)


## The first free slot `item` could go in (a second ring goes in the second ring slot), or the
## first slot of its kind when all are taken.
static func slot_for(adventure: Adventure, item: ItemDef) -> StringName:
	var first := &""
	for slot in ItemCatalog.SLOTS:
		if ItemCatalog.fits(item, slot):
			if adventure.equipped(slot).is_empty():
				return slot
			if first.is_empty():
				first = slot
	return first


## The known items worn, slot by slot (an unknown id, or an item in a slot it does not fit, is
## left out and changes nothing).
static func worn(adventure: Adventure) -> Array[ItemDef]:
	var items: Array[ItemDef] = []
	for slot in ItemCatalog.SLOTS:
		var item := ItemCatalog.find(adventure.equipped(slot))
		if ItemCatalog.fits(item, slot):
			items.append(item)
	return items


## The weapon in the main hand (the starting sword if the save names something unusable there).
static func weapon(adventure: Adventure) -> ItemDef:
	var item := ItemCatalog.find(adventure.equipped(ItemCatalog.MAIN_HAND))
	return item if ItemCatalog.fits(item, ItemCatalog.MAIN_HAND) else ItemCatalog.find(Adventure.STARTING_WEAPON)
