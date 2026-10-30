class_name HeroStats
extends RefCounted
## The hero's derived statistics: base values (the hero's own scene, the weapon in hand, the heart
## vessels found) changed by the attribute points invested (HeroGrowth) and what is worn. Never saved: rebuilt from the saved equipment whenever
## it changes.
##
## value = clamp((base + sum of ADD) * (1 + sum of PERCENT / 100), MINIMUM, MAXIMUM)
## Adds come before percentages, and percentages are summed, not compounded, so the order items
## are worn in never changes the result. Only statistics something uses exist.

## Quarters of a heart the hero can have.
const MAX_HEALTH := &"max_health"
## Quarters of a heart the weapon takes off (whole numbers).
const ATTACK := &"attack"
## Speed (px/s) the weapon gives what it hits away from the hero.
const KNOCKBACK := &"knockback"
## How far from the hero the weapon's blow lands (px).
const REACH := &"reach"
## Percent of the weapon's windup and recovery the swing takes (100: as made).
const SWING := &"swing"
## Percent of each hit's damage taken away (see Health).
const DEFENSE := &"defense"
## Percent of the knockback the hero takes away (firmness).
const POISE := &"poise"
## Weight the hero can carry; the bands below are fractions of it.
const LOAD := &"load"
## Percent added to the hero's top speed, after the weight band.
const SPEED := &"speed"
## Percent added to the health consumables give back.
const HEALING := &"healing"
## Percent of the weapon's damage each blow lands with (100: as made; the hero's strength).
const POWER := &"power"
## Breath the hero can hold (Stamina.maximum).
const BREATH := &"breath"
## Percent of the breath that comes back each second (100: the hero's own pace).
const BREATH_REGEN := &"breath_regen"

const MINIMUM: Dictionary[StringName, float] = {
	MAX_HEALTH: 4.0, ATTACK: 1.0, KNOCKBACK: 0.0, REACH: 6.0, SWING: 50.0, DEFENSE: 0.0, POISE: 0.0,
	LOAD: 10.0, SPEED: -30.0, HEALING: 0.0, POWER: 50.0, BREATH: 50.0, BREATH_REGEN: 50.0,
}
const MAXIMUM: Dictionary[StringName, float] = {
	MAX_HEALTH: 80.0, ATTACK: 8.0, KNOCKBACK: 600.0, REACH: 24.0, SWING: 150.0, DEFENSE: 50.0,
	POISE: 75.0, LOAD: 120.0, SPEED: 15.0, HEALING: 200.0, POWER: 200.0, BREATH: 200.0, BREATH_REGEN: 200.0,
}
## What the hero carries with nothing but the starting kit.
const BASE_LOAD := 30.0
## Breath the hero holds with no point in breath (Stamina's own maximum).
const BASE_BREATH := 100.0

## Weight bands, by worn weight over load (upper bound inclusive).
const LIGHT := &"light"
const NORMAL := &"normal"
const HEAVY := &"heavy"
const OVERLOADED := &"overloaded"
const BANDS: Array[StringName] = [LIGHT, NORMAL, HEAVY, OVERLOADED]
const BAND_LIMIT: Dictionary[StringName, float] = {LIGHT: 0.30, NORMAL: 0.60, HEAVY: 1.00, OVERLOADED: INF}
## Top speed and acceleration in each band, as fractions of the hero's own.
const BAND_SPEED: Dictionary[StringName, float] = {LIGHT: 1.0, NORMAL: 0.94, HEAVY: 0.85, OVERLOADED: 0.70}
const BAND_ACCELERATION: Dictionary[StringName, float] = {LIGHT: 1.0, NORMAL: 1.0, HEAVY: 0.8, OVERLOADED: 0.6}
## The dodge in each band: distance (px), untouchable moment and recovery (s). The step itself always
## takes DODGE_TIME; heavier loads go less far, stay touchable sooner and recover later.
const DODGE_TIME := 0.18
const DODGE_DISTANCE: Dictionary[StringName, float] = {LIGHT: 44.0, NORMAL: 40.0, HEAVY: 32.0, OVERLOADED: 24.0}
const DODGE_UNTOUCHABLE: Dictionary[StringName, float] = {LIGHT: 0.14, NORMAL: 0.12, HEAVY: 0.10, OVERLOADED: 0.07}
const DODGE_RECOVERY: Dictionary[StringName, float] = {LIGHT: 0.10, NORMAL: 0.14, HEAVY: 0.20, OVERLOADED: 0.30}
## How fast breath comes back in each band, as a fraction of the hero's own.
const BAND_BREATH: Dictionary[StringName, float] = {LIGHT: 1.0, NORMAL: 1.0, HEAVY: 0.85, OVERLOADED: 0.65}


## `base` changed by every modifier of `stat` in `modifiers`, within the stat's bounds.
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
	return clampf(value, MINIMUM.get(stat, -INF), MAXIMUM.get(stat, INF))


## Every statistic in `base` (id -> value) changed by what `items` modify and by `extra` modifiers (the
## attribute points), all in the one sum above.
static func derive(base: Dictionary[StringName, float], items: Array[ItemDef],
		extra: Array[StatModifier] = []) -> Dictionary[StringName, float]:
	var modifiers: Array[StatModifier] = extra.duplicate()
	for item in items:
		modifiers.append_array(item.modifiers)
	var derived: Dictionary[StringName, float] = {}
	for stat in base:
		derived[stat] = combine(base[stat], stat, modifiers)
	return derived


## Total weight of `items`.
static func weight(items: Array[ItemDef]) -> float:
	var total := 0.0
	for item in items:
		total += item.weight
	return total


## The band for carrying `carried` with a load of `load`.
static func band(carried: float, load: float) -> StringName:
	var ratio := carried / maxf(load, 0.001)
	for name in BANDS:
		if ratio <= BAND_LIMIT[name] + 0.0001:
			return name
	return OVERLOADED
