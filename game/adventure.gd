class_name Adventure
extends RefCounted
## Everything one adventure remembers, as plain data: where the hero stands, the shrine they
## return to after a fall, their health, the flags the world has earned, the items they have and
## what they have equipped. Flags are the story's progress: the shrine, the objectives and small
## permanent changes are each one named flag. Items are kept by their stable ids (ItemCatalog);
## nothing derived from them (the hero's statistics) is saved.
##
## Two places are kept apart. The resume point (`area`, `entry`) follows the hero: it is the
## entry they last arrived through, or the shrine they last touched, and it is where Continue
## starts. The checkpoint (`checkpoint_area`, `checkpoint_entry`) is the last shrine awakened
## and only changes when another shrine takes over; a fall leads back there. Before any shrine
## there is no checkpoint and a fall leads back to the resume point.

## Emitted whenever something worth saving changes.
signal changed

const FORMAT_VERSION := 3
## Health value meaning "full", whatever the hero's maximum is.
const FULL_HEALTH := -1
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
## Ids of the items the hero has, in the order found, each once.
var _items: Array[StringName] = []
## Slot -> id of the item equipped there (always one the hero has).
var _equipment: Dictionary[StringName, StringName] = {}


func _init(start_area: StringName = &"village", start_entry: StringName = &"start") -> void:
	area = start_area
	entry = start_entry


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
	return _items.has(id)


func items() -> Array[StringName]:
	return _items.duplicate()


## Adds `id` to what the hero has. False if it was already there (items are never doubled).
func add_item(id: StringName) -> bool:
	if id.is_empty() or _items.has(id):
		return false
	_items.append(id)
	changed.emit()
	return true


## The id equipped in `slot`, or empty.
func equipped(slot: StringName) -> StringName:
	return _equipment.get(slot, &"")


## Equips `id` (an item the hero has) in `slot`, replacing what was there. Which slot an item
## goes in is the catalog's to say; the caller asks it.
func equip(slot: StringName, id: StringName) -> bool:
	if slot.is_empty() or not _items.has(id) or equipped(slot) == id:
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
	var item_ids: Array[String] = []
	for id in _items:
		item_ids.append(String(id))
	var equipment := {}
	for slot in _equipment:
		equipment[String(slot)] = String(_equipment[slot])
	return {
		"version": FORMAT_VERSION,
		"area": String(area),
		"entry": String(entry),
		"checkpoint": {"area": String(checkpoint_area), "entry": String(checkpoint_entry)}
				if has_checkpoint() else null,
		"health": health,
		"flags": flag_names,
		"items": item_ids,
		"equipment": equipment,
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
	if not d.get("flags") is Array or not d.get("items") is Array or not d.get("equipment") is Dictionary:
		return null
	var adventure := Adventure.new(StringName(d["area"]), StringName(d["entry"]))
	if checkpoint != null:
		adventure.checkpoint_area = StringName(checkpoint["area"])
		adventure.checkpoint_entry = StringName(checkpoint["entry"])
	adventure.health = int(d["health"])
	for flag: Variant in d["flags"]:
		if not _is_name(flag):
			return null
		adventure._flags[StringName(flag)] = true
	for id: Variant in d["items"]:
		if not _is_name(id):
			return null
		if not adventure._items.has(StringName(id)):
			adventure._items.append(StringName(id))
	var equipment: Dictionary = d["equipment"]
	for slot: Variant in equipment:
		var id: Variant = equipment[slot]
		if not _is_name(slot) or not _is_name(id):
			return null
		if not adventure._items.has(StringName(id)):
			push_warning("Save equips %s in %s without having it; left unequipped." % [id, slot])
			continue
		adventure._equipment[StringName(slot)] = StringName(id)
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


## JSON numbers arrive as floats; accept only whole values.
static func _is_whole(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floorf(value))


static func _is_name(value: Variant) -> bool:
	return value is String and not (value as String).is_empty()
