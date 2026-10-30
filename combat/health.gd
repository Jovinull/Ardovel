class_name Health
extends Node
## Hit points of an actor, with an optional invulnerability window after each hit.

signal changed(current: int, maximum: int)
signal died

@export_range(1, 999) var max_health: int = 3
## Seconds during which further damage is ignored after a hit lands.
@export_range(0.0, 5.0, 0.01) var invulnerability_time: float = 0.0

## Percent of each hit's damage taken away (the hero's armour). What a hit loses to it is kept
## as a remainder and added to the next, so a small defence still counts; a hit always takes at
## least one quarter.
var defense_percent: float = 0.0
var current: int = 0
var _invulnerable_left: float = 0.0
var _carried_damage: float = 0.0


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
	return take_hit(amount, 1)


## Takes `amount` quarters (a shield may have let only part through, hence a fraction), reduced by
## defence, at least `minimum`. True when something was taken.
func take_hit(amount: float, minimum: int) -> bool:
	if amount <= 0.0 or is_dead() or is_invulnerable():
		return false
	var taken := reduced(amount, minimum)
	if taken <= 0:
		return false
	current = maxi(current - taken, 0)
	changed.emit(current, max_health)
	if is_dead():
		died.emit()
	elif invulnerability_time > 0.0:
		_invulnerable_left = invulnerability_time
		set_physics_process(true)
	return true


## What a hit of `amount` takes after defence (and the remainder carried from earlier hits), at
## least `minimum`.
func reduced(amount: float, minimum: int = 1) -> int:
	if defense_percent <= 0.0 and is_equal_approx(amount, roundf(amount)) and _carried_damage == 0.0:
		return maxi(roundi(amount), minimum)
	var owed := amount * (1.0 - clampf(defense_percent, 0.0, 100.0) / 100.0) + _carried_damage
	var taken := maxi(floori(owed + 0.0001), minimum)
	_carried_damage = maxf(owed - taken, 0.0)
	return taken


## Ignores damage for `seconds` (after a blocked hit, so one blow is not blocked every frame).
func grant_invulnerability(seconds: float) -> void:
	if seconds > _invulnerable_left:
		_invulnerable_left = seconds
		set_physics_process(true)


func heal(amount: int) -> void:
	if amount <= 0 or is_dead():
		return
	var healed := mini(current + amount, max_health)
	if healed != current:
		current = healed
		changed.emit(current, max_health)


func restore_full() -> void:
	heal(max_health)


## Changes the maximum (a heart vessel, for example); current health never exceeds it.
func set_maximum(value: int) -> void:
	max_health = maxi(value, 1)
	current = mini(current, max_health)
	changed.emit(current, max_health)
