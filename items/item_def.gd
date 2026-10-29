class_name ItemDef
extends Resource
## One kind of item as the game knows it: its stable id (written in saves), its texts
## (translation keys), its icon, the equipment slot it goes in (empty: it cannot be equipped) and
## what it changes while equipped.

@export var id: StringName
@export var name_key: String
@export var description_key: String
## One short line saying what it does in play.
@export var effect_key: String
## 16x16, drawn for the item.
@export var icon: Texture2D
## One of ItemCatalog.SLOTS, or empty.
@export var slot: StringName
@export var modifiers: Array[StatModifier] = []


func is_equippable() -> bool:
	return not slot.is_empty()
