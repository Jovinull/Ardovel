class_name HeroGrowth
extends RefCounted
## How the hero grows: experience, levels, attribute points and the one-time rewards. The adventure
## keeps only the record (experience, points invested, rewards given); everything here is derived
## from it, so a level or a statistic can never disagree with what was earned.
##
## Experience comes from defeating creatures (every time one that came back is beaten again) and,
## once per adventure, from the deeds below, each proven by a flag the story already sets, and from
## arriving in each area for the first time. Each level from the second gives one attribute point.
## An attribute point is a StatModifier like a worn item's, so statistics stay one sum (HeroStats):
## the hero's own value + attribute points + equipment.

const MAX_LEVEL := 20
## Points one attribute can hold.
const ATTRIBUTE_CAP := 10
## Experience from one level to the next: FIRST_STEP, then STEP_GROWTH more each level.
const FIRST_STEP := 30
const STEP_GROWTH := 15

const VIGOR := &"vigor"
const STRENGTH := &"strength"
const ENDURANCE := &"endurance"
const BREATH := &"breath"
const ATTRIBUTES: Array[StringName] = [VIGOR, STRENGTH, ENDURANCE, BREATH]
## What one point of each attribute adds: statistic -> amount (HeroStats ADD).
const PER_POINT: Dictionary[StringName, Dictionary] = {
	VIGOR: {HeroStats.MAX_HEALTH: 1.0},
	STRENGTH: {HeroStats.POWER: 10.0},
	ENDURANCE: {HeroStats.DEFENSE: 3.0, HeroStats.POISE: 4.0},
	BREATH: {HeroStats.BREATH: 6.0, HeroStats.BREATH_REGEN: 5.0},
}

## Experience for defeating each kind of creature (by class name). The warden is a one-time deed.
const CREATURES: Dictionary[StringName, int] = {&"Musgorico": 4, &"Cardosa": 3}

## One-time deeds: reward id -> [flag that proves it, experience]. Ids are written in saves.
const DEEDS: Dictionary[StringName, Array] = {
	&"shrine_awakened": [&"forest_shrine_awakened", 10],
	&"hens_settled": [&"village_hens_settled", 15],
	&"echo_found": [&"forest_echo_found", 15],
	&"ruin_lights": [&"ruin_lights_solved", 15],
	&"ruin_roots": [&"ruin_roots_solved", 15],
	&"ruin_heart": [&"ruin_heart_awakened", 40],
	&"warden_defeated": [&"ruin_warden_defeated", 60],
	&"lookout_seen": [&"west_lookout_seen", 20],
	&"bridge_tied": [&"far_bank_bridge_tied", 35],
	&"ditch_cleared": [&"road_ditch_cleared", 30],
	&"stone_shifted": [&"spring_stone_shifted", 40],
	&"map_drawn": [&"blank_map_drawn", 30],
	&"notice_down": [&"town_notice_down", 50],
}
## Arriving in an area for the first time: area id -> experience (the village is home).
const ARRIVALS: Dictionary[StringName, int] = {
	&"forest": 5, &"ruin": 10, &"west": 10, &"far_bank": 10, &"road_slope": 10, &"road_west": 10,
	&"waystop": 10, &"pedrabranca": 15,
}
const ARRIVAL_PREFIX := "arrived_"


# ---------------------------------------------------------------- levels

## Experience from `level` to the next.
static func step(level: int) -> int:
	return FIRST_STEP + STEP_GROWTH * (level - 1)


## Total experience that reaches `level` (level 1: 0).
static func experience_for(level: int) -> int:
	var total := 0
	for l in range(1, clampi(level, 1, MAX_LEVEL)):
		total += step(l)
	return total


static func level_for(experience: int) -> int:
	var level := 1
	while level < MAX_LEVEL and experience >= experience_for(level + 1):
		level += 1
	return level


static func level(adventure: Adventure) -> int:
	return level_for(adventure.experience)


## How far into the current level (gained, needed); at the last level, (0, 0).
static func progress(adventure: Adventure) -> Vector2i:
	var current := level(adventure)
	if current >= MAX_LEVEL:
		return Vector2i.ZERO
	return Vector2i(adventure.experience - experience_for(current), step(current))


# ---------------------------------------------------------------- attribute points

static func points_earned(adventure: Adventure) -> int:
	return level(adventure) - 1


static func points_invested(adventure: Adventure) -> int:
	var total := 0
	for attribute in ATTRIBUTES:
		total += adventure.attribute(attribute)
	return total


static func points_free(adventure: Adventure) -> int:
	return maxi(points_earned(adventure) - points_invested(adventure), 0)


## Whether `plan` (attribute -> points to add) can be invested now: known attributes, no negative
## amounts, within each attribute's cap and the points free.
static func can_invest(adventure: Adventure, plan: Dictionary) -> bool:
	var total := 0
	for attribute: Variant in plan:
		if not attribute in ATTRIBUTES or not plan[attribute] is int or int(plan[attribute]) < 0:
			return false
		if adventure.attribute(attribute) + int(plan[attribute]) > ATTRIBUTE_CAP:
			return false
		total += int(plan[attribute])
	return total > 0 and total <= points_free(adventure)


## Invests `plan` at once (one change). False and nothing invested if it cannot be.
static func invest(adventure: Adventure, plan: Dictionary) -> bool:
	if not can_invest(adventure, plan):
		return false
	var next: Dictionary[StringName, int] = {}
	for attribute in ATTRIBUTES:
		next[attribute] = adventure.attribute(attribute) + int(plan.get(attribute, 0))
	adventure.set_attributes(next)
	return true


## The statistic modifiers of `points` (attribute -> points; default: what `adventure` invested).
static func modifiers(adventure: Adventure, points: Dictionary = {}) -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for attribute in ATTRIBUTES:
		var count: int = points.get(attribute, adventure.attribute(attribute))
		if count <= 0:
			continue
		for stat: StringName in PER_POINT[attribute]:
			var modifier := StatModifier.new()
			modifier.stat = stat
			modifier.kind = StatModifier.Kind.ADD
			modifier.value = PER_POINT[attribute][stat] * count
			result.append(modifier)
	return result


# ---------------------------------------------------------------- experience

## Experience for defeating a creature of class `kind` (0 for anything not listed).
static func for_creature(kind: StringName) -> int:
	return CREATURES.get(kind, 0)


## Gives every deed `adventure`'s flags prove and it has not been given yet, and returns the
## experience given. The same path serves a deed done now and one done before experience existed
## (an older save): each is given once, by its flag, and recorded.
static func settle_deeds(adventure: Adventure) -> int:
	var given := 0
	for id in DEEDS:
		var deed: Array = DEEDS[id]
		if adventure.has_flag(deed[0]) and not adventure.has_reward(id):
			if adventure.give_reward(id, deed[1]):
				given += deed[1]
	return given


## Gives the first arrival in `area` (once); returns the experience given.
static func arrive(adventure: Adventure, area: StringName) -> int:
	if not ARRIVALS.has(area):
		return 0
	var id := StringName(ARRIVAL_PREFIX + String(area))
	if adventure.has_reward(id) or not adventure.give_reward(id, ARRIVALS[area]):
		return 0
	return ARRIVALS[area]
