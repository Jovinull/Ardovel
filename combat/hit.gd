class_name Hit
extends RefCounted
## One landed attack, as seen by the receiver.

var damage: int
var knockback: float
var source_position: Vector2


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
