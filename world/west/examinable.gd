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

var _adventure: Adventure

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure


func _on_interact(_actor: Node2D) -> String:
	if _adventure != null and not latest_flag.is_empty() and _adventure.has_flag(latest_flag):
		return latest_text
	if _adventure != null and not after_flag.is_empty() and _adventure.has_flag(after_flag):
		return text_after
	return text
