class_name Hitbox
extends Area2D
## Deals damage to overlapping Hurtboxes while active.
##
## Overlaps are polled during the active window instead of relying on `area_entered`, so
## targets that are already inside the area when it activates are hit too. Monitoring stays on
## permanently: toggling it would make overlaps lag one physics step behind activation.

signal landed(hurtbox: Hurtbox)

@export var damage: int = 1
@export var knockback: float = 100.0
## A swing hits each target once per activation; contact damage leaves this off and relies on
## the target's invulnerability window instead.
@export var hit_once_per_activation: bool = true
@export var active: bool = false:
	set(value):
		active = value
		_already_hit.clear()
		set_physics_process(value)

var _already_hit: Dictionary[Hurtbox, bool] = {}


func _ready() -> void:
	monitorable = false
	set_physics_process(active)


func _physics_process(_delta: float) -> void:
	for area in get_overlapping_areas():
		var hurtbox := area as Hurtbox
		if hurtbox != null:
			strike(hurtbox)


## Applies this hitbox to `hurtbox` once, respecting per-activation deduplication.
func strike(hurtbox: Hurtbox) -> bool:
	if not active or _already_hit.has(hurtbox):
		return false
	if hit_once_per_activation:
		_already_hit[hurtbox] = true
	if hurtbox.receive_hit(Hit.new(damage, knockback, global_position)):
		landed.emit(hurtbox)
		return true
	return false
