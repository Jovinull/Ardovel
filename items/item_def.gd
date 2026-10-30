class_name ItemDef
extends Resource
## One kind of item as the game knows it: its stable id (written in saves), its category, its
## texts (translation keys), its icon, the slot it is worn in (empty: it is not equipment), its
## weight, how many share one space of the bag, and what it does: the statistics it changes while
## worn, the attack of a weapon (and the attack frames that show it), or the health a consumable
## gives back.

@export var id: StringName
## One of ItemCatalog.CATEGORIES.
@export var category: StringName
@export var name_key: String
@export var description_key: String
## 16x16, drawn for the item.
@export var icon: Texture2D
## The kind of slot it goes in (a value of ItemCatalog.SLOT_KINDS), or empty.
@export var slot: StringName
## Carried weight while worn (equipment only).
@export var weight: float = 0.0
## How many share one space of the bag (1 for equipment).
@export var stack_limit: int = 1
@export var modifiers: Array[StatModifier] = []
## Weapons: timing, damage, knockback and reach of the swing.
@export var attack: AttackData
## Weapons: the hero's 120x160 attack sheet drawn with this weapon in hand.
@export var attack_sheet: Texture2D
## Shields: how they guard when raised.
@export var guard: GuardData
## Shields: the hero holding this shield up, 96x24 (down, up, left, right).
@export var guard_sheet: Texture2D
## Consumables: quarters of a heart given back when used (before healing bonuses).
@export var heal: int = 0


func is_equippable() -> bool:
	return not slot.is_empty()


func is_usable() -> bool:
	return heal > 0
