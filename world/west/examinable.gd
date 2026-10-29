class_name Examinable
extends Node2D
## Something in the world worth a closer look: a short description, which reads differently
## once a later event has happened (an empty `after_flag` keeps one text).

## Translation keys of what the hero notices, before and after `after_flag`.
@export var text: String
@export var text_after: String
@export var after_flag: StringName
## What it reads once a still later event (`latest_flag`) has happened; empty keeps the others.
@export var latest_text: String
@export var latest_flag: StringName
## And once a fourth event (`final_flag`) has happened; empty keeps the others.
@export var final_text: String
@export var final_flag: StringName
## A flag to set once it has been looked at (empty: none).
@export var sets: StringName

var _adventure: Adventure

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure


func _on_interact(_actor: Node2D) -> String:
	var said := _text()
	if _adventure != null and not sets.is_empty():
		_adventure.set_flag(sets)
	return said


func _text() -> String:
	if _adventure != null and not final_flag.is_empty() and _adventure.has_flag(final_flag):
		return final_text
	if _adventure != null and not latest_flag.is_empty() and _adventure.has_flag(latest_flag):
		return latest_text
	if _adventure != null and not after_flag.is_empty() and _adventure.has_flag(after_flag):
		return text_after
	return text
