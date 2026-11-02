class_name SkillCatalog
extends RefCounted
## Every skill the game has, by stable id (the ids are written in saves: never rename one).

const PIERCING_STEP := &"piercing_step"
const BREAKING_BLOW := &"breaking_blow"
const STAFF_SWEEP := &"staff_sweep"
const GUARD_RESPONSE := &"guard_response"
const TRAINED_STEPS := &"trained_steps"
const FIRM_STANCE := &"firm_stance"

## Id -> resource, in the order the menu shows them (actives, then passives).
const SKILLS: Dictionary[StringName, String] = {
	PIERCING_STEP: "res://skills/piercing_step.tres",
	BREAKING_BLOW: "res://skills/breaking_blow.tres",
	STAFF_SWEEP: "res://skills/staff_sweep.tres",
	GUARD_RESPONSE: "res://skills/guard_response.tres",
	TRAINED_STEPS: "res://skills/trained_steps.tres",
	FIRM_STANCE: "res://skills/firm_stance.tres",
}


static func knows(id: StringName) -> bool:
	return SKILLS.has(id)


## The skill with `id`, or null for an unknown id (a save from a newer game).
static func find(id: StringName) -> SkillDef:
	if not SKILLS.has(id):
		return null
	return load(SKILLS[id]) as SkillDef


static func ids() -> Array[StringName]:
	return SKILLS.keys()
