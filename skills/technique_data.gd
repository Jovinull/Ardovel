class_name TechniqueData
extends Resource
## How an active skill is performed: its own timing and blow, built on the weapon in hand (the blow
## keeps the weapon's damage and the hero's power, multiplied by `damage_scale`, so strength's
## carried fraction works as with any swing), and what the hero does while it runs: a step forward
## (`lunge`), a blow carried across an arc (`sweep`), or an answer only right after a clean block
## (`counter`). The game's MeleeAttack runs the blow; TechniqueRunner moves the hero and aims it.

enum Motion { STRIKE, LUNGE, SWEEP, COUNTER }
## Which frames show it: the weapon's own swing, or its second motion (ItemDef.technique_sheet).
enum Frames { OWN, SECOND }

@export var motion: Motion = Motion.STRIKE
@export var frames: Frames = Frames.OWN
@export var windup: float = 0.1
@export var active: float = 0.1
@export var recovery: float = 0.2
## Multiplies the weapon's blow (damage x power).
@export var damage_scale: float = 1.0
@export var knockback_scale: float = 1.0
## Seconds a walking creature struck is kept from acting.
@export var stagger: float = 0.3
## Whether the blow gets through a creature bracing against blows (a Musgorico bristling).
@export var breaking: bool = false
## Size of the blow's area, authored for a downward blow (across, along); zero keeps the weapon's.
@export var hitbox_size: Vector2 = Vector2.ZERO
## Distance from the hero to the blow's centre; zero keeps the weapon's.
@export var reach: float = 0.0
## LUNGE: pixels covered during the active phase (stopped by anything solid).
@export var lunge: float = 0.0
## SWEEP: degrees the blow travels across, centred on where the hero faces.
@export var sweep: float = 0.0
## COUNTER: seconds after a clean block in which it can be started.
@export var window: float = 0.0
## Seconds the world freezes when it connects.
@export var hit_stop: float = 0.06


func duration() -> float:
	return windup + active + recovery


## The blow of this technique made with `weapon_attack` (the weapon's swing as worn).
func attack_for(weapon_attack: AttackData) -> AttackData:
	var blow := weapon_attack.duplicate() as AttackData
	blow.windup = windup
	blow.active = active
	blow.recovery = recovery
	blow.power = weapon_attack.power * damage_scale
	blow.knockback = weapon_attack.knockback * knockback_scale
	blow.stagger = stagger
	blow.breaking = breaking
	if hitbox_size != Vector2.ZERO:
		blow.hitbox_size = hitbox_size
	if reach > 0.0:
		blow.reach = reach
	blow.hit_stop = hit_stop
	blow.chain = 0.0
	return blow
