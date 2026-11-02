class_name Spoils
extends RefCounted
## What a creature leaves when defeated (a balance table: change drops here only). One roll per
## creature really defeated: the item lies where it fell, to be picked up like any other (a full
## bag leaves it there), and lasts only while the area is loaded (it is not saved: leaving, a fall
## or closing the game loses only what was never picked up). Creatures come back when their area
## is entered again, so drops can be gathered again the same way; the warden never comes back.
## Musgoricos leave nothing: moss gives no seed and no coin.

## Creature class -> the item, the chance of leaving any, and the chance that it is two instead of one.
const DROPS: Dictionary[StringName, Dictionary] = {
	&"Cardosa": {"item": &"cardosa_seed", "chance": 0.5, "pair": 0.25},
}


## What a `kind` creature leaves this time: {"item", "count"}, or empty for nothing. `rng` decides
## (seeded in tests).
static func roll(kind: StringName, rng: RandomNumberGenerator) -> Dictionary:
	if not DROPS.has(kind):
		return {}
	var drop: Dictionary = DROPS[kind]
	if rng.randf() >= float(drop["chance"]):
		return {}
	var count := 2 if rng.randf() < float(drop["pair"]) else 1
	return {"item": drop["item"], "count": count}
