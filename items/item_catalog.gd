class_name ItemCatalog
extends RefCounted
## Every item the game knows, by stable id. The ids are written in saves: never rename or reuse
## one; retire it instead (a save that still names it keeps it, unused).

## The one equipment slot so far.
const ACCESSORY := &"accessory"
const SLOTS: Array[StringName] = [ACCESSORY]
const ITEMS: Dictionary[StringName, String] = {
	&"crew_gloves": "res://items/crew_gloves.tres",
}


static func knows(id: StringName) -> bool:
	return ITEMS.has(id)


## The item's definition, or null for an id the game does not know.
static func find(id: StringName) -> ItemDef:
	return load(ITEMS[id]) as ItemDef if ITEMS.has(id) else null


## Translation key of a slot's name.
static func slot_name_key(slot: StringName) -> String:
	return "SLOT_" + String(slot).to_upper()
