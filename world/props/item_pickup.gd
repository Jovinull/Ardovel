class_name ItemPickup
extends Node2D
## Something to take: an item lying in the world, kept in a small chest, or a few coppers. Taking it
## puts `count` of `item` in the bag (or `money` coppers in the purse) and sets `flag` (each pickup
## has its own, so the same item can be found in two places, and nothing is taken twice). When the
## bag (or purse) has no room it stays where it is and says so; nothing is ever lost for want of
## space. A chest stays, open, once emptied.
##
## A pickup can also count as taken by older flags (`legacy_flags`: what an earlier version of the
## world gave in its place), wait unseen until an event (`appears_with`), or stay where it is,
## refused, until someone allows it (`allowed_by`, saying `refused` meanwhile). One with no flag is
## a creature's drop: it lives only while the area is loaded and pops out when it is placed.
##
## The chest at home (`keeps_storage`) stays the hero's to keep things in once emptied: interacting
## then asks for it (`storage_requested`). If the bag has no room for what it held at first, that
## stays in it, kept in the chest (Storage), instead of waiting for room.

signal storage_requested

const POP_HEIGHT := 10.0
const POP_TIME := 0.3
const DROP_SOUND := preload("res://assets/ninja_adventure/Audio/Sounds/Jump & Bounce/Bounce.wav")

## An ItemCatalog id (empty for coppers alone).
@export var item: StringName
@export var count: int = 1
## Coppers it holds (with no `item`).
@export var money: int = 0
## Adventure flag recording that this pickup was taken.
@export var flag: StringName
## Flags that also mean it was taken (or its content given otherwise) before this pickup existed.
@export var legacy_flags: Array[StringName] = []
## Unseen until this flag is set (empty: always there).
@export var appears_with: StringName
## Refused until this flag is set (empty: free to take); `refused` says why meanwhile.
@export var allowed_by: StringName
@export var refused: String
## What the hero notices before taking it (a translation key; empty: only what was taken).
@export var message: String
## How it looks lying there (16x16; empty: the item's icon).
@export var ground: Texture2D
## A two-frame chest (closed, open) to keep it in, instead of lying on the ground.
@export var chest: Texture2D
## This chest is the one at home, where the hero keeps what they do not carry.
@export var keeps_storage: bool = false

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
	if not appears_with.is_empty() and not adventure.has_flag(appears_with):
		_set_present(false)
		adventure.changed.connect(_on_changed)
		return
	if is_taken():
		_show_taken()


func is_taken() -> bool:
	if _adventure == null:
		return false
	if _adventure.has_flag(flag):
		return true
	for old in legacy_flags:
		if _adventure.has_flag(old):
			return true
	return false


## Whether it can be seen (and taken) now.
func is_present() -> bool:
	return visible and _interactable.enabled


## Pops out of a creature: up and back down where it was placed, with a soft thud.
func pop() -> void:
	var thud := AudioStreamPlayer.new()
	thud.stream = DROP_SOUND
	thud.volume_db = -10.0
	add_child(thud)
	thud.play()
	var rest := _sprite.position
	var tween := create_tween()
	tween.tween_property(_sprite, ^"position:y", rest.y - POP_HEIGHT, POP_TIME * 0.5) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_sprite, ^"position:y", rest.y, POP_TIME * 0.5) \
			.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)


func _on_changed() -> void:
	if visible or not _adventure.has_flag(appears_with):
		return
	_adventure.changed.disconnect(_on_changed)
	_set_present(true)
	if is_taken():
		_show_taken()


func _set_present(present: bool) -> void:
	visible = present
	_interactable.enabled = present


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	if is_taken():
		if keeps_storage:
			storage_requested.emit()
		return ""
	if not allowed_by.is_empty() and not _adventure.has_flag(allowed_by):
		return refused
	var took := ""
	if item.is_empty():
		if not _adventure.earn(money):
			return "PICKUP_PURSE_FULL"
		took = tr("MONEY_FOUND") % money
	else:
		var definition := ItemCatalog.find(item)
		var name := tr(definition.name_key) if definition != null else String(item)
		took = tr("ITEM_FOUND") % name if count == 1 else tr("ITEM_FOUND_MANY") % [name, count]
		if not Bag.try_add(_adventure, item, count):
			if not keeps_storage or not ItemCatalog.knows(item) or not Storage.has_room_for(_adventure, item, count):
				return "PICKUP_BAG_FULL"
			_adventure.add_item(item, count)
			_adventure.store(item, count)
			took = tr("PICKUP_KEPT_IN_CHEST") % name
	_adventure.set_flag(flag)
	_sound.play()
	_show_taken()
	return tr(message) + "\n\n" + took if not message.is_empty() else took


func _show_taken() -> void:
	if chest != null:
		_sprite.frame = 1
		_interactable.enabled = keeps_storage
		return
	_interactable.enabled = false
	visible = false
	if _sound.playing:
		_sound.finished.connect(queue_free)
	else:
		queue_free()
