class_name Adventure
extends RefCounted
## Everything one adventure remembers, as plain data: where the hero stands, the shrine they
## return to after a fall, their health, the flags the world has earned, the items they have (how
## many of each), what they have equipped, what they keep in the chest at home, and how they have
## grown (experience, attribute points invested, one-time rewards given). Flags are the
## story's progress: the shrine, the objectives and small permanent changes are each one named
## flag. Items are kept by their stable ids (ItemCatalog); nothing derived from them (the hero's
## statistics) is saved. The rules for what fits in the bag, in the chest and what goes in which
## slot live with the catalog (Bag, Storage, Equipment): this is only the record. What is in the
## chest is apart from what the hero has (`count` never includes it), so it can be neither worn
## nor used until taken back. Levels and statistics are never saved: HeroGrowth and HeroLoadout
## derive them from this record.
##
## Two places are kept apart. The resume point (`area`, `entry`) follows the hero: it is the
## entry they last arrived through, or the shrine they last touched, and it is where Continue
## starts. The checkpoint (`checkpoint_area`, `checkpoint_entry`) is the last shrine awakened
## and only changes when another shrine takes over; a fall leads back there. Before any shrine
## there is no checkpoint and a fall leads back to the resume point.

## Emitted whenever something worth saving changes.
signal changed

const FORMAT_VERSION := 6
## Health value meaning "full", whatever the hero's maximum is.
const FULL_HEALTH := -1
## The sword every hero carries from the start (format 3 saves gain it on upgrade).
const STARTING_WEAPON := &"wayfarer_sword"
const MAIN_HAND := &"main_hand"
## Format 3 saves that had the crew gloves took them from this pickup.
const V3_GLOVES_PICKUP_FLAG := "found_slope_crew_gloves"
## Version 1 saves had a single return point; their only shrine was the forest's.
const V1_SHRINE_FLAG := "forest_shrine_awakened"
const V1_SHRINE_CHECKPOINT := {"area": "forest", "entry": "shrine"}

var area: StringName
var entry: StringName
## Empty while no shrine has been awakened.
var checkpoint_area: StringName = &""
var checkpoint_entry: StringName = &""
var health: int = FULL_HEALTH
var _flags: Dictionary[StringName, bool] = {}
## Ids of the items the hero has, in the order first found, each once.
var _items: Array[StringName] = []
## How many of each item the hero has (always at least 1 for an id in `_items`).
var _counts: Dictionary[StringName, int] = {}
## Slot -> id of the item equipped there (always one of the copies the hero has).
var _equipment: Dictionary[StringName, StringName] = {}
## The food the quick-use key eats (empty: the first food the hero has). Saved as an optional key
## of format 4, so saves without it read as before.
var quick_item: StringName = &""
## The chest at home: ids in the order first put there, and how many of each.
var _stored_items: Array[StringName] = []
var _stored: Dictionary[StringName, int] = {}
## Experience earned in all (never lost).
var experience: int = 0
## Attribute -> points invested (HeroGrowth.ATTRIBUTES).
var _attributes: Dictionary[StringName, int] = {}
## One-time rewards already given (HeroGrowth's deed and arrival ids).
var _rewards: Dictionary[StringName, bool] = {}


func _init(start_area: StringName = &"village", start_entry: StringName = &"start") -> void:
	area = start_area
	entry = start_entry
	_items.append(STARTING_WEAPON)
	_counts[STARTING_WEAPON] = 1
	_equipment[MAIN_HAND] = STARTING_WEAPON


func has_flag(flag: StringName) -> bool:
	return _flags.has(flag)


func set_flag(flag: StringName) -> void:
	if flag.is_empty() or _flags.has(flag):
		return
	_flags[flag] = true
	changed.emit()


func flags() -> Array[StringName]:
	return _flags.keys()


func has_item(id: StringName) -> bool:
	return _counts.has(id)


## Ids the hero has, in the order first found.
func items() -> Array[StringName]:
	return _items.duplicate()


func count(id: StringName) -> int:
	return _counts.get(id, 0)


## Adds `amount` of `id` to what the hero has. Whether it fits in the bag is Bag's to say.
func add_item(id: StringName, amount: int = 1) -> bool:
	if id.is_empty() or amount <= 0:
		return false
	if not _counts.has(id):
		_items.append(id)
	_counts[id] = count(id) + amount
	changed.emit()
	return true


## Takes away `amount` of `id`; never the copies still equipped. False if there are not enough.
func remove_item(id: StringName, amount: int = 1) -> bool:
	if amount <= 0 or count(id) - amount < equipped_copies(id):
		return false
	_counts[id] = count(id) - amount
	if _counts[id] == 0:
		_counts.erase(id)
		_items.erase(id)
	changed.emit()
	return true


## Adds `amount` of experience (a creature defeated). False for nothing or less.
func add_experience(amount: int) -> bool:
	if amount <= 0:
		return false
	experience += amount
	changed.emit()
	return true


func has_reward(id: StringName) -> bool:
	return _rewards.has(id)


## Rewards given, sorted.
func rewards() -> Array[StringName]:
	var ids: Array[StringName] = _rewards.keys()
	ids.sort()
	return ids


## Records the one-time reward `id` and its `amount` of experience together (one change). False
## if it was already given or the amount is negative.
func give_reward(id: StringName, amount: int) -> bool:
	if id.is_empty() or amount < 0 or _rewards.has(id):
		return false
	_rewards[id] = true
	experience += amount
	changed.emit()
	return true


## Points invested in `attribute`.
func attribute(id: StringName) -> int:
	return _attributes.get(id, 0)


## Replaces the points invested (HeroGrowth.invest says what is allowed). Negative counts are refused.
func set_attributes(points: Dictionary[StringName, int]) -> bool:
	for id in points:
		if points[id] < 0:
			return false
	_attributes.clear()
	for id in points:
		if points[id] > 0:
			_attributes[id] = points[id]
	changed.emit()
	return true


## How many of `id` are in the chest.
func stored(id: StringName) -> int:
	return _stored.get(id, 0)


## Ids in the chest, in the order first put there.
func stored_items() -> Array[StringName]:
	return _stored_items.duplicate()


## Moves `amount` of `id` from what the hero has into the chest, in one change; never the copies
## equipped. Whether the chest has room is Storage's to say. False (and nothing moved) otherwise.
func store(id: StringName, amount: int) -> bool:
	if id.is_empty() or amount <= 0 or count(id) - amount < equipped_copies(id):
		return false
	_counts[id] = count(id) - amount
	if _counts[id] == 0:
		_counts.erase(id)
		_items.erase(id)
	if not _stored.has(id):
		_stored_items.append(id)
	_stored[id] = stored(id) + amount
	changed.emit()
	return true


## Moves `amount` of `id` from the chest back to the hero, in one change. Whether the bag has room
## is Storage's to say. False (and nothing moved) if the chest has fewer.
func retrieve(id: StringName, amount: int) -> bool:
	if id.is_empty() or amount <= 0 or stored(id) < amount:
		return false
	_stored[id] = stored(id) - amount
	if _stored[id] == 0:
		_stored.erase(id)
		_stored_items.erase(id)
	if not _counts.has(id):
		_items.append(id)
	_counts[id] = count(id) + amount
	changed.emit()
	return true


## The id equipped in `slot`, or empty.
func equipped(slot: StringName) -> StringName:
	return _equipment.get(slot, &"")


## Slot -> id of everything equipped.
func equipment() -> Dictionary[StringName, StringName]:
	return _equipment.duplicate()


## Chooses the food the quick-use key eats.
func set_quick_item(id: StringName) -> void:
	if quick_item == id:
		return
	quick_item = id
	changed.emit()


## How many slots hold `id`.
func equipped_copies(id: StringName) -> int:
	return _equipment.values().count(id)


## Equips `id` in `slot`, replacing what was there (which stays the hero's). Needs a copy not
## already equipped in another slot. Which slot an item goes in is the catalog's to say (Equipment).
func equip(slot: StringName, id: StringName) -> bool:
	if slot.is_empty() or equipped(slot) == id:
		return false
	var other_slots := equipped_copies(id)
	if count(id) <= other_slots:
		return false
	_equipment[slot] = id
	changed.emit()
	return true


func unequip(slot: StringName) -> bool:
	if not _equipment.has(slot):
		return false
	_equipment.erase(slot)
	changed.emit()
	return true


func has_checkpoint() -> bool:
	return not checkpoint_area.is_empty()


## Makes `entry_id` of the current area the checkpoint (a shrine was awakened there). The
## hero stands there, so it is also where the adventure resumes.
func activate_checkpoint(entry_id: StringName) -> void:
	if checkpoint_area == area and checkpoint_entry == entry_id and entry == entry_id:
		return
	checkpoint_area = area
	checkpoint_entry = entry_id
	entry = entry_id
	changed.emit()


## Called once the hero has arrived through `entry_id` of `area_id`. The checkpoint stays.
func enter(area_id: StringName, entry_id: StringName) -> void:
	area = area_id
	entry = entry_id
	changed.emit()


## Whether version `version` of the save format can be read (older ones are upgraded).
static func reads_version(version: int) -> bool:
	return version >= 1 and version <= FORMAT_VERSION


func to_dict() -> Dictionary:
	var flag_names: Array[String] = []
	for flag in _flags:
		flag_names.append(String(flag))
	flag_names.sort()
	var stacks: Array[Dictionary] = []
	for id in _items:
		stacks.append({"id": String(id), "count": _counts[id]})
	var equipment := {}
	for slot in _equipment:
		equipment[String(slot)] = String(_equipment[slot])
	var storage: Array[Dictionary] = []
	for id in _stored_items:
		storage.append({"id": String(id), "count": _stored[id]})
	var attributes := {}
	for id in _attributes:
		attributes[String(id)] = _attributes[id]
	var given: Array[String] = []
	for id in rewards():
		given.append(String(id))
	return {
		"version": FORMAT_VERSION,
		"area": String(area),
		"entry": String(entry),
		"checkpoint": {"area": String(checkpoint_area), "entry": String(checkpoint_entry)}
				if has_checkpoint() else null,
		"health": health,
		"flags": flag_names,
		"inventory": stacks,
		"equipment": equipment,
		"quick_item": String(quick_item),
		"storage": storage,
		"experience": experience,
		"attributes": attributes,
		"rewards": given,
	}


## Rebuilds an adventure from `to_dict()` data of this or an older format version, or returns
## null if the data is not a valid adventure. Unknown extra keys are ignored.
static func from_dict(data: Variant) -> Adventure:
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	if _is_whole(d.get("version")) and int(d["version"]) == 1:
		d = _upgraded_from_v1(d)
	if _is_whole(d.get("version")) and int(d["version"]) == 2:
		d = _upgraded_from_v2(d)
	if _is_whole(d.get("version")) and int(d["version"]) == 3:
		d = _upgraded_from_v3(d)
		if d.is_empty():
			return null
	if _is_whole(d.get("version")) and int(d["version"]) == 4:
		d = _upgraded_from_v4(d)
	if _is_whole(d.get("version")) and int(d["version"]) == 5:
		d = _upgraded_from_v5(d)
	if not _is_whole(d.get("version")) or int(d["version"]) != FORMAT_VERSION:
		return null
	if not _is_name(d.get("area")) or not _is_name(d.get("entry")):
		return null
	var checkpoint: Variant = d.get("checkpoint", 0)
	if checkpoint != null and not (checkpoint is Dictionary and _is_name(checkpoint.get("area"))
			and _is_name(checkpoint.get("entry"))):
		return null
	if not _is_whole(d.get("health")) or int(d["health"]) < FULL_HEALTH:
		return null
	if not d.get("flags") is Array or not d.get("inventory") is Array or not d.get("equipment") is Dictionary \
			or not d.get("storage") is Array or not d.get("attributes") is Dictionary or not d.get("rewards") is Array:
		return null
	if not _is_whole(d.get("experience")) or int(d["experience"]) < 0:
		return null
	var adventure := Adventure.new(StringName(d["area"]), StringName(d["entry"]))
	adventure._items.clear()
	adventure._counts.clear()
	adventure._equipment.clear()
	if checkpoint != null:
		adventure.checkpoint_area = StringName(checkpoint["area"])
		adventure.checkpoint_entry = StringName(checkpoint["entry"])
	adventure.health = int(d["health"])
	for flag: Variant in d["flags"]:
		if not _is_name(flag):
			return null
		adventure._flags[StringName(flag)] = true
	for stack: Variant in d["inventory"]:
		if not _is_stack(stack):
			return null
		var id := StringName(stack["id"])
		if not adventure._counts.has(id):
			adventure._items.append(id)
		adventure._counts[id] = adventure.count(id) + int(stack["count"])
	for stack: Variant in d["storage"]:
		if not _is_stack(stack):
			return null
		var id := StringName(stack["id"])
		if not adventure._stored.has(id):
			adventure._stored_items.append(id)
		adventure._stored[id] = adventure.stored(id) + int(stack["count"])
	adventure.experience = int(d["experience"])
	for id: Variant in d["attributes"]:
		var points: Variant = d["attributes"][id]
		if not _is_name(id) or not _is_whole(points) or int(points) < 0:
			return null
		if int(points) > 0:
			adventure._attributes[StringName(id)] = int(points)
	for id: Variant in d["rewards"]:
		if not _is_name(id):
			return null
		adventure._rewards[StringName(id)] = true
	var equipment: Dictionary = d["equipment"]
	var slots: Array = equipment.keys()
	slots.sort()
	for slot: Variant in slots:
		var id: Variant = equipment[slot]
		if not _is_name(slot) or not _is_name(id):
			return null
		if adventure.count(StringName(id)) <= adventure.equipped_copies(StringName(id)):
			push_warning("Save equips %s in %s without a copy to spare; left unequipped." % [id, slot])
			continue
		adventure._equipment[StringName(slot)] = StringName(id)
	var quick: Variant = d.get("quick_item", "")
	if quick is String:
		adventure.quick_item = StringName(quick)
	else:
		push_warning("Save's quick item is not a name; the first food will be used.")
	return adventure


## Version 1 had no checkpoint: its return point was the resume point. An awakened forest
## shrine was the only checkpoint the game had, so it becomes the checkpoint.
static func _upgraded_from_v1(v1: Dictionary) -> Dictionary:
	var v2 := v1.duplicate()
	v2["version"] = 2
	var flags: Variant = v1.get("flags")
	v2["checkpoint"] = V1_SHRINE_CHECKPOINT.duplicate() \
			if flags is Array and (flags as Array).has(V1_SHRINE_FLAG) else null
	return v2


## Version 2 had no items: an adventure from then has none and wears nothing.
static func _upgraded_from_v2(v2: Dictionary) -> Dictionary:
	var v3 := v2.duplicate()
	v3["version"] = 3
	v3["items"] = []
	v3["equipment"] = {}
	return v3


## Version 3 kept each item once and had no weapon slot: every item becomes a stack of one, the
## sword the hero always carried is added and held in the main hand (unless the save already put
## something there), and owning the crew gloves means their pickup on the slope was taken. An
## empty dictionary means the version 3 data was malformed.
static func _upgraded_from_v3(v3: Dictionary) -> Dictionary:
	var items: Variant = v3.get("items")
	var equipment: Variant = v3.get("equipment")
	var flags: Variant = v3.get("flags")
	if not items is Array or not equipment is Dictionary or not flags is Array:
		return {}
	var v4 := v3.duplicate(true)
	v4.erase("items")
	v4["version"] = 4
	var stacks: Array = []
	var seen := {}
	for id: Variant in items:
		if not _is_name(id):
			return {}
		if not seen.has(id):
			seen[id] = true
			stacks.append({"id": id, "count": 1})
	if not seen.has(String(STARTING_WEAPON)):
		stacks.push_front({"id": String(STARTING_WEAPON), "count": 1})
	if not (v4["equipment"] as Dictionary).has(String(MAIN_HAND)):
		v4["equipment"][String(MAIN_HAND)] = String(STARTING_WEAPON)
	if seen.has("crew_gloves") and not (v4["flags"] as Array).has(V3_GLOVES_PICKUP_FLAG):
		(v4["flags"] as Array).append(V3_GLOVES_PICKUP_FLAG)
	v4["inventory"] = stacks
	return v4


## Version 4 had no chest at home: an adventure from then keeps nothing there.
static func _upgraded_from_v4(v4: Dictionary) -> Dictionary:
	var v5 := v4.duplicate()
	v5["version"] = 5
	v5["storage"] = []
	return v5


## Version 5 had no growth: an adventure from then starts at no experience, no points and no
## reward given. Its deeds are given once, by their flags, the first time it is played
## (HeroGrowth.settle_deeds); creatures beaten then are not counted (nothing proves them).
static func _upgraded_from_v5(v5: Dictionary) -> Dictionary:
	var v6 := v5.duplicate()
	v6["version"] = 6
	v6["experience"] = 0
	v6["attributes"] = {}
	v6["rewards"] = []
	return v6


## {"id": a name, "count": a whole number from 1}.
static func _is_stack(stack: Variant) -> bool:
	return stack is Dictionary and _is_name(stack.get("id")) and _is_whole(stack.get("count")) \
			and int(stack["count"]) >= 1


## JSON numbers arrive as floats; accept only whole values.
static func _is_whole(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floorf(value))


static func _is_name(value: Variant) -> bool:
	return value is String and not (value as String).is_empty()
