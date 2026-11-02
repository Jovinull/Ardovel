class_name VeinPassage
extends StaticBody2D
## One end of a way between two spots of the vein that is not walked (the lift, the cage, the
## ledge's ladder): interacting rides or climbs to `target_entry` behind a fade (Level's passage).
## It may need a flag (the cage's chain hooked, the ladder lowered); the end that can do it
## (`can_set`) sets that flag instead the first time. It may need water in a bucket to go this way
## (the lift rises only on a full counterweight). Its sprite shows frame 0 without the flag, 1 with.

@export var target_entry: StringName
@export var needs_flag: StringName
@export var can_set: bool = false
@export var needs_water: WaterNode
## Translation keys: said when the flag is missing here, when this end sets it, when the bucket is dry.
@export var locked_message: String
@export var set_message: String
@export var dry_message: String

var _adventure: Adventure

@onready var _interactable: Interactable = $Interactable
@onready var _sprite: Sprite2D = get_node_or_null(^"Sprite")
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_show_state)
	_show_state()


func is_usable() -> bool:
	if not needs_flag.is_empty() and (_adventure == null or not _adventure.has_flag(needs_flag)):
		return false
	return needs_water == null or needs_water.is_wet()


func _show_state() -> void:
	if _sprite != null and _sprite.hframes > 1:
		_sprite.frame = 1 if needs_flag.is_empty() or _adventure.has_flag(needs_flag) else 0


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	if not needs_flag.is_empty() and not _adventure.has_flag(needs_flag):
		if can_set:
			_adventure.set_flag(needs_flag)
			_sound.play()
			return set_message
		return locked_message
	if needs_water != null and not needs_water.is_wet():
		return dry_message
	_sound.play()
	var level := Level.containing(self)
	if level != null:
		# Deferred: the passage disables the area, which is not allowed inside a physics step.
		level.passage_requested.emit.call_deferred(target_entry)
	return ""
