class_name ItemPickup
extends Node2D
## Something to take: an item lying in the world, or kept in a small chest. Taking it puts `count`
## of `item` in the bag and sets `flag` (each pickup has its own, so the same item can be found in
## two places, and nothing is taken twice). When the bag has no room it stays where it is and says
## so; nothing is ever lost for want of space. A chest stays, open, once emptied.

## An ItemCatalog id.
@export var item: StringName
@export var count: int = 1
## Adventure flag recording that this pickup was taken.
@export var flag: StringName
## What the hero notices before taking it (a translation key; empty: only what was taken).
@export var message: String
## How it looks lying there (16x16; empty: the item's icon).
@export var ground: Texture2D
## A two-frame chest (closed, open) to keep it in, instead of lying on the ground.
@export var chest: Texture2D

var _adventure: Adventure

@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer = $Sound
@onready var _sprite: Sprite2D = $Sprite
@onready var _shadow: Sprite2D = $Shadow


func _ready() -> void:
	add_to_group(&"adventure")
	var definition := ItemCatalog.find(item)
	if chest != null:
		_sprite.texture = chest
		_sprite.hframes = 2
		_shadow.visible = false
	else:
		_sprite.texture = ground if ground != null else (definition.icon if definition != null else null)
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if is_taken():
		_show_taken()


func is_taken() -> bool:
	return _adventure != null and _adventure.has_flag(flag)


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null or is_taken():
		return ""
	if not Bag.try_add(_adventure, item, count):
		return "PICKUP_BAG_FULL"
	_adventure.set_flag(flag)
	_sound.play()
	var definition := ItemCatalog.find(item)
	var name := tr(definition.name_key) if definition != null else String(item)
	var took := tr("ITEM_FOUND") % name if count == 1 else tr("ITEM_FOUND_MANY") % [name, count]
	_show_taken()
	return tr(message) + "\n\n" + took if not message.is_empty() else took


func _show_taken() -> void:
	if chest != null:
		_sprite.frame = 1
		_interactable.enabled = false
		return
	_interactable.enabled = false
	visible = false
	if _sound.playing:
		_sound.finished.connect(queue_free)
	else:
		queue_free()
