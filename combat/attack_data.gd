class_name AttackData
extends Resource
## Timing and impact of a melee attack. The phases drive both the hitbox and the sprite frames,
## which keeps what the player sees in lock-step with what can actually hit.

enum Phase { IDLE, WINDUP, ACTIVE, RECOVERY }

## Elapsed time is accumulated from physics deltas (six ticks of 1/60 s sum to 0.0999...),
## so phase boundaries are compared with a small tolerance to land on the expected tick.
const TIME_EPSILON := 1e-6

@export_range(0.0, 1.0, 0.005) var windup: float = 0.07
@export_range(0.01, 1.0, 0.005) var active: float = 0.12
@export_range(0.0, 1.0, 0.005) var recovery: float = 0.15
@export var damage: int = 1
@export var knockback: float = 140.0
## Distance from the attacker's origin to the hitbox centre, along the attack direction.
@export var reach: float = 12.0


func duration() -> float:
	return windup + active + recovery


## Phase at `elapsed` seconds since the attack started (IDLE once it is over).
func phase_at(elapsed: float) -> Phase:
	if elapsed < 0.0:
		return Phase.IDLE
	var t := elapsed + TIME_EPSILON
	if t < windup:
		return Phase.WINDUP
	if t < windup + active:
		return Phase.ACTIVE
	if t < duration():
		return Phase.RECOVERY
	return Phase.IDLE
