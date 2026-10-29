class_name HeroStats
extends RefCounted
## The hero's derived statistics: base values (from the hero's own scene) changed by what is
## equipped. Never saved: rebuilt from the saved equipment whenever it changes.
##
## value = max(minimum, (base + sum of ADD) * (1 + sum of PERCENT / 100))
## Adds come before percentages, and percentages are summed, not compounded, so the order items
## are equipped in never changes the result. Only statistics something uses exist; a new one is
## an id here and a minimum.

## Quarters of a heart the sword takes off (whole numbers; never below 1).
const SWORD_DAMAGE := &"sword_damage"
## Speed (px/s) the sword gives what it hits away from the hero.
const SWORD_KNOCKBACK := &"sword_knockback"
const MINIMUM: Dictionary[StringName, float] = {SWORD_DAMAGE: 1.0, SWORD_KNOCKBACK: 0.0}


## `base` changed by every modifier of `stat` in `modifiers`.
static func combine(base: float, stat: StringName, modifiers: Array[StatModifier]) -> float:
	var added := 0.0
	var percent := 0.0
	for modifier in modifiers:
		if modifier == null or modifier.stat != stat:
			continue
		if modifier.kind == StatModifier.Kind.ADD:
			added += modifier.value
		else:
			percent += modifier.value
	var value := (base + added) * (1.0 + percent / 100.0)
	return maxf(value, MINIMUM.get(stat, 0.0))


## Every known statistic in `base` (id -> value) changed by what `items` modify.
static func derive(base: Dictionary[StringName, float], items: Array[ItemDef]) -> Dictionary[StringName, float]:
	var modifiers: Array[StatModifier] = []
	for item in items:
		modifiers.append_array(item.modifiers)
	var derived: Dictionary[StringName, float] = {}
	for stat in base:
		derived[stat] = combine(base[stat], stat, modifiers)
	return derived
