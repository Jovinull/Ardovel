class_name FlagShown
extends Node2D
## Shows its children only while `flag` is (or, with `when_set` off, is not) on the adventure.
## Things that stand in the way (with collision) are taken out instead of hidden, and only when
## the area is entered, so nothing vanishes in front of the hero.

@export var flag: StringName
@export var when_set: bool = true
## Take the children out on entering the area instead of hiding them as the flag changes.
@export var remove: bool = false

var _adventure: Adventure


func _ready() -> void:
	add_to_group(&"adventure")


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if remove:
		if not _shown():
			queue_free()
		return
	adventure.changed.connect(_refresh)
	_refresh()


func _shown() -> bool:
	return _adventure.has_flag(flag) == when_set


func _refresh() -> void:
	visible = _shown()
