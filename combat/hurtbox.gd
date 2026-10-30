class_name Hurtbox
extends Area2D
## Area that can be struck by a Hitbox. Applies the damage to `health` and reports the hit
## only when it actually landed, so owners never react to hits ignored by invulnerability.

signal hit_received(hit: Hit)

@export var health: Health
## Optional: looks at a hit before it lands and returns it (changed: blocked, softened) or null
## (it misses: a dodge). The hero's guard and dodge live here.
var guard: Callable


func _ready() -> void:
	monitoring = false


## Order: still invulnerable from the last hit -> the guard (dodge, block) -> what passes the shield
## is reduced by armour and taken (see Health). A hit fully stopped by a shield takes nothing but
## still lands (the hero reacts to it).
func receive_hit(hit: Hit) -> bool:
	if health != null and health.is_invulnerable():
		return false
	if guard.is_valid():
		hit = guard.call(hit)
		if hit == null:
			return false
	if health != null and not health.take_hit(hit.damage * hit.power * hit.share, 0 if hit.blocked else 1) and not hit.blocked:
		return false
	hit_received.emit(hit)
	return true
