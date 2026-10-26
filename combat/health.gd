class_name Health
extends Node
## Hit points of an actor, with an optional invulnerability window after each hit.

signal changed(current: int, maximum: int)
signal died

@export_range(1, 999) var max_health: int = 3
## Seconds during which further damage is ignored after a hit lands.
@export_range(0.0, 5.0, 0.01) var invulnerability_time: float = 0.0

var current: int = 0
var _invulnerable_left: float = 0.0


func _ready() -> void:
	current = max_health
	# Only ticks while an invulnerability window is running.
	set_physics_process(false)


func _physics_process(delta: float) -> void:
	_invulnerable_left = maxf(_invulnerable_left - delta, 0.0)
	if _invulnerable_left == 0.0:
		set_physics_process(false)


func is_dead() -> bool:
	return current <= 0


func is_invulnerable() -> bool:
	return _invulnerable_left > 0.0


## Returns true when the damage was applied (not ignored by death or invulnerability).
func take_damage(amount: int) -> bool:
	if amount <= 0 or is_dead() or is_invulnerable():
		return false
	current = maxi(current - amount, 0)
	changed.emit(current, max_health)
	if is_dead():
		died.emit()
	elif invulnerability_time > 0.0:
		_invulnerable_left = invulnerability_time
		set_physics_process(true)
	return true


func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	var healed := mini(current + amount, max_health)
	if healed != current:
		current = healed
		changed.emit(current, max_health)


func restore_full() -> void:
	heal(max_health)
