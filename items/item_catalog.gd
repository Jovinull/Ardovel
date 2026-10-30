class_name ItemCatalog
extends RefCounted
## Every item the game knows, by stable id. The ids are written in saves: never rename or reuse
## one; retire it instead (a save that still names it keeps it, unused). Also the slots and the
## categories.

const MAIN_HAND := &"main_hand"
const OFF_HAND := &"off_hand"
const HEAD := &"head"
const TORSO := &"torso"
const HANDS := &"hands"
const LEGS := &"legs"
const RING_1 := &"ring_1"
const RING_2 := &"ring_2"
const ACCESSORY := &"accessory"
## Every slot, in the order the equipment page reads them.
const SLOTS: Array[StringName] = [MAIN_HAND, OFF_HAND, HEAD, TORSO, HANDS, LEGS, RING_1, RING_2, ACCESSORY]
## The kind of item each slot takes (an ItemDef's `slot`): both ring slots take rings.
const SLOT_KINDS: Dictionary[StringName, StringName] = {
	MAIN_HAND: &"main_hand", OFF_HAND: &"off_hand", HEAD: &"head", TORSO: &"torso", HANDS: &"hands",
	LEGS: &"legs", RING_1: &"ring", RING_2: &"ring", ACCESSORY: &"accessory",
}

const WEAPON := &"weapon"
const SHIELD := &"shield"
const ARMOR := &"armor"
const RING := &"ring"
const TRINKET := &"accessory"
const CONSUMABLE := &"consumable"
const MATERIAL := &"material"
## Categories in the order the inventory sorts them.
const CATEGORIES: Array[StringName] = [WEAPON, SHIELD, ARMOR, RING, TRINKET, CONSUMABLE, MATERIAL]

const ITEMS: Dictionary[StringName, String] = {
	&"wayfarer_sword": "res://items/weapons/wayfarer_sword.tres",
	&"crew_machete": "res://items/weapons/crew_machete.tres",
	&"woodcutter_hatchet": "res://items/weapons/woodcutter_hatchet.tres",
	&"traveller_staff": "res://items/weapons/traveller_staff.tres",
	&"ruin_blade": "res://items/weapons/ruin_blade.tres",
	&"quarry_maul": "res://items/weapons/quarry_maul.tres",
	&"barrel_lid_buckler": "res://items/shields/barrel_lid_buckler.tres",
	&"bark_shield": "res://items/shields/bark_shield.tres",
	&"traveller_shield": "res://items/shields/traveller_shield.tres",
	&"crew_board_shield": "res://items/shields/crew_board_shield.tres",
	&"straw_hat": "res://items/armor/straw_hat.tres",
	&"traveller_hood": "res://items/armor/traveller_hood.tres",
	&"ruin_circlet": "res://items/armor/ruin_circlet.tres",
	&"quarry_helm": "res://items/armor/quarry_helm.tres",
	&"padded_doublet": "res://items/armor/padded_doublet.tres",
	&"traveller_coat": "res://items/armor/traveller_coat.tres",
	&"crew_vest": "res://items/armor/crew_vest.tres",
	&"quarry_breastplate": "res://items/armor/quarry_breastplate.tres",
	&"work_mitts": "res://items/armor/work_mitts.tres",
	&"moss_wraps": "res://items/armor/moss_wraps.tres",
	&"traveller_bracers": "res://items/armor/traveller_bracers.tres",
	&"quarry_gauntlets": "res://items/armor/quarry_gauntlets.tres",
	&"rope_sandals": "res://items/armor/rope_sandals.tres",
	&"traveller_boots": "res://items/armor/traveller_boots.tres",
	&"crew_boots": "res://items/armor/crew_boots.tres",
	&"quarry_greaves": "res://items/armor/quarry_greaves.tres",
	&"root_ring": "res://items/rings/root_ring.tres",
	&"quill_ring": "res://items/rings/quill_ring.tres",
	&"whitestone_ring": "res://items/rings/whitestone_ring.tres",
	&"carter_ring": "res://items/rings/carter_ring.tres",
	&"crew_gloves": "res://items/crew_gloves.tres",
	&"herb_pouch": "res://items/accessories/herb_pouch.tres",
	&"traveller_charm": "res://items/accessories/traveller_charm.tres",
	&"corn_bread": "res://items/consumables/corn_bread.tres",
	&"wild_honey": "res://items/consumables/wild_honey.tres",
	&"herb_tea": "res://items/consumables/herb_tea.tres",
	&"white_stone_chip": "res://items/materials/white_stone_chip.tres",
	&"pine_resin": "res://items/materials/pine_resin.tres",
	&"root_fiber": "res://items/materials/root_fiber.tres",
	&"cardosa_seed": "res://items/materials/cardosa_seed.tres",
	&"old_bronze": "res://items/materials/old_bronze.tres",
}

static var _cache: Dictionary[StringName, ItemDef] = {}


static func knows(id: StringName) -> bool:
	return ITEMS.has(id)


## The item's definition, or null for an id the game does not know. Loaded once.
static func find(id: StringName) -> ItemDef:
	if not ITEMS.has(id):
		return null
	if not _cache.has(id):
		_cache[id] = load(ITEMS[id]) as ItemDef
	return _cache[id]


## Whether `item` can be worn in `slot`.
static func fits(item: ItemDef, slot: StringName) -> bool:
	return item != null and SLOT_KINDS.has(slot) and item.slot == SLOT_KINDS[slot]

