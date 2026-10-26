class_name Adventure
extends RefCounted
## Everything one adventure remembers, as plain data: where the hero stands (the current area
## and the safe point they return to there), their health and the flags the world has earned.
## Flags are the whole progress model: the shrine, the first objective and small permanent
## changes are each one named flag, so new ones need no new fields.

## Emitted whenever something worth saving changes.
signal changed

const FORMAT_VERSION := 1
## Health value meaning "full", whatever the hero's maximum is.
const FULL_HEALTH := -1

## Area the hero is in, and the entry point they return to there (on death or when resuming).
var area: StringName
var entry: StringName
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


## Makes `entry_id` of the current area the safe return point (a checkpoint).
func set_return_point(entry_id: StringName) -> void:
	if entry == entry_id:
		return
	entry = entry_id
	changed.emit()


## Called once the hero has arrived through `entry_id` of `area_id`.
func enter(area_id: StringName, entry_id: StringName) -> void:
	area = area_id
	entry = entry_id
	changed.emit()


func to_dict() -> Dictionary:
	var flag_names: Array[String] = []
	for flag in _flags:
		flag_names.append(String(flag))
	flag_names.sort()
	return {
		"version": FORMAT_VERSION,
		"area": String(area),
		"entry": String(entry),
		"health": health,
		"flags": flag_names,
	}


## Rebuilds an adventure from `to_dict()` data, or returns null if the data is not a valid
## adventure of this format version. Unknown extra keys are ignored.
static func from_dict(data: Variant) -> Adventure:
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	if not _is_whole(d.get("version")) or int(d["version"]) != FORMAT_VERSION:
		return null
	if not d.get("area") is String or (d["area"] as String).is_empty():
		return null
	if not d.get("entry") is String or (d["entry"] as String).is_empty():
		return null
	if not _is_whole(d.get("health")) or int(d["health"]) < FULL_HEALTH:
		return null
	if not d.get("flags") is Array:
		return null
	var adventure := Adventure.new(StringName(d["area"]), StringName(d["entry"]))
	adventure.health = int(d["health"])
	for flag: Variant in d["flags"]:
		if not flag is String or (flag as String).is_empty():
			return null
		adventure._flags[StringName(flag)] = true
	return adventure


## JSON numbers arrive as floats; accept only whole values.
static func _is_whole(value: Variant) -> bool:
	return (value is int) or (value is float and is_finite(value) and value == floorf(value))
