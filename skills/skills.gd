class_name Skills
extends RefCounted
## What may be learned, equipped and used. Skill points are apart from attribute points: one every
## second level reached (levels 2, 4, 6, ...: ten at level 20), derived from the level like those;
## the points spent are the costs of what was learned, so only what was learned is saved. Two slots
## hold active techniques and one a passive skill; a learned skill stays learned whatever is worn,
## and a technique whose weapon or shield is not in hand waits, unusable, in its slot.

const ACTIVE_SLOTS := 2
## Every so many levels a skill point.
const LEVELS_PER_POINT := 2

enum Refusal {
	NONE,
	UNKNOWN,
	LEARNED,
	LEVEL,
	POINTS,
	NOT_LEARNED,
	WRONG_KIND,
}


static func points_earned(adventure: Adventure) -> int:
	return HeroGrowth.level(adventure) / LEVELS_PER_POINT


static func points_spent(adventure: Adventure) -> int:
	var spent := 0
	for id in adventure.skills():
		var skill := SkillCatalog.find(id)
		if skill != null:
			spent += skill.cost
	return spent


static func points_free(adventure: Adventure) -> int:
	return maxi(points_earned(adventure) - points_spent(adventure), 0)


## Why `id` cannot be learned now (NONE: it can).
static func why_not_learn(adventure: Adventure, id: StringName) -> Refusal:
	var skill := SkillCatalog.find(id)
	if skill == null:
		return Refusal.UNKNOWN
	if adventure.has_skill(id):
		return Refusal.LEARNED
	if HeroGrowth.level(adventure) < skill.level:
		return Refusal.LEVEL
	if skill.cost <= 0 or skill.cost > points_free(adventure):
		return Refusal.POINTS
	return Refusal.NONE


## Learns `id` (one change). False and nothing spent if it cannot be learned.
static func learn(adventure: Adventure, id: StringName) -> bool:
	return why_not_learn(adventure, id) == Refusal.NONE and adventure.learn_skill(id)


## Why `id` cannot go in active slot `slot` (0 or 1), or in the passive slot (`slot` -1).
static func why_not_equip(adventure: Adventure, id: StringName, slot: int) -> Refusal:
	var skill := SkillCatalog.find(id)
	if skill == null:
		return Refusal.UNKNOWN
	if not adventure.has_skill(id):
		return Refusal.NOT_LEARNED
	if (slot < 0) == skill.is_active() or slot >= ACTIVE_SLOTS:
		return Refusal.WRONG_KIND
	return Refusal.NONE


## Puts `id` in active slot `slot` (moving it from the other slot if it was there), or in the
## passive slot (`slot` -1). One change. False if it cannot go there.
static func equip(adventure: Adventure, id: StringName, slot: int) -> bool:
	if why_not_equip(adventure, id, slot) != Refusal.NONE:
		return false
	if slot < 0:
		return adventure.set_passive_skill(id)
	var slots := adventure.skill_slots()
	for i in slots.size():
		if slots[i] == id:
			slots[i] = &""
	slots[slot] = id
	return adventure.set_skill_slots(slots)


## Empties active slot `slot`, or the passive slot (-1).
static func unequip(adventure: Adventure, slot: int) -> bool:
	if slot < 0:
		return adventure.set_passive_skill(&"")
	var slots := adventure.skill_slots()
	if slot >= slots.size() or slots[slot].is_empty():
		return false
	slots[slot] = &""
	return adventure.set_skill_slots(slots)


## The techniques in the two slots (null where empty or unknown).
static func equipped(adventure: Adventure) -> Array[SkillDef]:
	var result: Array[SkillDef] = []
	for id in adventure.skill_slots():
		result.append(SkillCatalog.find(id))
	return result


## The passive skill selected, or null.
static func passive(adventure: Adventure) -> SkillDef:
	return SkillCatalog.find(adventure.passive_skill)
