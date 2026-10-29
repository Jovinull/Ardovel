class_name ItemPickup
extends Node2D
## An item lying in the world. Taking it adds it to what the hero has (once: the item's id is the
## record, so nothing else needs saving) and says what was found.

## An ItemCatalog id.
@export var item: StringName
## What the hero notices on taking it (a translation key).
@export var message: String
## How it looks lying there (16x16, drawn for the item).
@export var ground: Texture2D

var _adventure: Adventure

@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	($Sprite as Sprite2D).texture = ground
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if adventure.has_item(item):
		queue_free()


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null or not _adventure.add_item(item):
		return ""
	_sound.play()
	_interactable.enabled = false
	visible = false
	_sound.finished.connect(queue_free)
	return message
