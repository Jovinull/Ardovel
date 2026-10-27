class_name Adventure
extends RefCounted
## Everything one adventure remembers, as plain data: where the hero stands, the shrine they
## return to after a fall, their health and the flags the world has earned. Flags are the
## whole progress model: the shrine, the objectives and small permanent changes are each one
## named flag, so new ones need no new fields.
##
## Two places are kept apart. The resume point (`area`, `entry`) follows the hero: it is the
## entry they last arrived through, or the shrine they last touched, and it is where Continue
## starts. The checkpoint (`checkpoint_area`, `checkpoint_entry`) is the last shrine awakened
## and only changes when another shrine takes over; a fall leads back there. Before any shrine
## there is no checkpoint and a fall leads back to the resume point.

## Emitted whenever something worth saving changes.
signal changed

const FORMAT_VERSION := 2
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
	return {
		"version": FORMAT_VERSION,
		"area": String(area),
		"entry": String(entry),
		"checkpoint": {"area": String(checkpoint_area), "entry": String(checkpoint_entry)}
				if has_checkpoint() else null,
		"health": health,
		"flags": flag_names,
	}


## Rebuilds an adventure from `to_dict()` data of this or an older format version, or returns
## null if the data is not a valid adventure. Unknown extra keys are ignored.
static func from_dict(data: Variant) -> Adventure:
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	if _is_whole(d.get("version")) and int(d["version"]) == 1:
		d = _upgraded_from_v1(d)
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
	if not d.get("flags") is Array:
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


## JSON numbers arrive as floats; accept only whole values.
static func _is_whole(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floorf(value))


static func _is_name(value: Variant) -> bool:
	return value is String and not (value as String).is_empty()
