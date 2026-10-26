class_name Hurtbox
extends Area2D
## Area that can be struck by a Hitbox. Applies the damage to `health` and reports the hit
## only when it actually landed, so owners never react to hits ignored by invulnerability.

signal hit_received(hit: Hit)

@export var health: Health


func _ready() -> void:
	monitoring = false


func receive_hit(hit: Hit) -> bool:
	if health != null and not health.take_damage(hit.damage):
		return false
	hit_received.emit(hit)
	return true
