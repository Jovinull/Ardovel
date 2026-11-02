class_name SkillDef
extends Resource
## One skill as the game knows it: its stable id (written in saves), whether it is a technique the
## hero performs (active) or a way the hero moves and stands (passive), its texts and icon, what
## learning it asks (a level and skill points), and what using it asks (compatible weapons, a
## shield, breath). What an active one does is its `technique`; what a passive one does is read by
## HeroLoadout by its id (each is one specific rule, not a general effect).

enum Kind { ACTIVE, PASSIVE }

@export var id: StringName
@export var kind: Kind = Kind.ACTIVE
@export var name_key: String
@export var description_key: String
## What it does, in one line (a translation key).
@export var effect_key: String
## 16x16, drawn for the skill (a round medallion, never an item's shape).
@export var icon: Texture2D
## The level the hero must have reached to learn it.
@export var level: int = 2
## Skill points it takes to learn.
@export var cost: int = 1
## Weapon ids it can be used with (empty: any weapon).
@export var weapons: Array[StringName] = []
## Whether a shield must be in the off hand.
@export var needs_shield: bool = false
## Actives: breath spent on starting it.
@export var breath: float = 0.0
## Actives: how it is performed.
@export var technique: TechniqueData


func is_active() -> bool:
	return kind == Kind.ACTIVE


## Whether `weapon` (an ItemDef id) and `has_shield` allow using it now.
func fits(weapon: StringName, has_shield: bool) -> bool:
	if needs_shield and not has_shield:
		return false
	return weapons.is_empty() or weapons.has(weapon)
