class_name Hitbox
extends Area2D
## Deals damage to overlapping Hurtboxes while active.
##
## Overlaps are polled during the active window instead of relying on `area_entered`, so
## targets that are already inside the area when it activates are hit too. Monitoring stays on
## permanently: toggling it would make overlaps lag one physics step behind activation.

signal landed(hurtbox: Hurtbox)

## The physics layer of walls, trunks and everything solid (project setting "world").
const WORLD_LAYER := 1
## Where a striker's middle is above their feet (sight is taken from there, not from the ground).
const SIGHT_LIFT := Vector2(0, -8)

@export var damage: int = 1
## Multiplies `damage` where it lands (see AttackData.power).
@export var power: float = 1.0
@export var knockback: float = 100.0
## Whether a raised shield can stop this blow.
@export var blockable: bool = true
## Seconds the blow keeps a walking creature from acting.
@export var stagger: float = 0.0
## A swing hits each target once per activation; contact damage leaves this off and relies on
## the target's invulnerability window instead.
@export var hit_once_per_activation: bool = true
## Whether the blow gets through a creature bracing against blows.
@export var breaking: bool = false
## When set, a target is struck only if nothing solid (the world layer) lies between this node and
## it: a blow carried far from the hero (a technique) never lands through a wall.
var sight_from: Node2D
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
	if sight_from != null and not _in_sight(hurtbox):
		return false  # not counted as hit: it may come into sight later in the same blow
	if hit_once_per_activation:
		_already_hit[hurtbox] = true
	var hit := Hit.new(damage, knockback, global_position)
	hit.power = power
	hit.blockable = blockable
	hit.stagger = stagger
	hit.breaking = breaking
	if not hurtbox.receive_hit(hit):
		return false
	landed.emit(hurtbox)
	return true


## From the striker's middle to the middle of the target's hurtbox; the target's own body (a rooted
## creature is solid) never hides it from itself.
func _in_sight(hurtbox: Hurtbox) -> bool:
	var to := hurtbox.global_position
	for child in hurtbox.get_children():
		if child is CollisionShape2D:
			to = (child as CollisionShape2D).global_position
			break
	var query := PhysicsRayQueryParameters2D.create(sight_from.global_position + SIGHT_LIFT, to, WORLD_LAYER)
	var body := hurtbox.get_parent() as CollisionObject2D
	if body != null:
		query.exclude = [body.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()
