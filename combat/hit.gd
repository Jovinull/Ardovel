class_name Hit
extends RefCounted
## One landed attack, as seen by the receiver.

var damage: int
## Multiplies `damage` (the attacker's strength); what is taken is damage x power x share.
var power: float = 1.0
var knockback: float
var source_position: Vector2
## Whether a raised shield can stop it (a slam from above or roots from the ground cannot).
var blockable: bool = true
## Seconds the blow keeps a walking creature from acting (heavier weapons hold longer).
var stagger: float = 0.0
## Fraction of `damage` that reaches the receiver's armour (a shield stops the rest).
var share: float = 1.0
## Set when a shield took it.
var blocked: bool = false
## Set when a shield was raised but the breath to hold it ran out.
var guard_broken: bool = false


func _init(p_damage: int, p_knockback: float, p_source_position: Vector2) -> void:
	damage = p_damage
	knockback = p_knockback
	source_position = p_source_position


## Knockback velocity for a receiver at `target_position`.
func knockback_velocity(target_position: Vector2) -> Vector2:
	var away := source_position.direction_to(target_position)
	if away == Vector2.ZERO:
		away = Vector2.DOWN
	return away * knockback
