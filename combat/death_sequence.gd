class_name DeathSequence
extends Node
## Defeat of an enemy: switches off its combat areas and body collision, plays its death
## animation, leaves an effect behind and frees the owner. Shared by enemies of any body type.

signal finished

@export var sprite: AnimatedSprite2D
@export var animation: StringName = &"death"
@export var effect: PackedScene
## Combat areas (hitboxes and hurtboxes) that must stop working at once.
@export var areas: Array[Area2D] = []

var running: bool = false


func start() -> void:
	if running:
		return
	running = true
	for area in areas:
		if area is Hitbox:
			(area as Hitbox).active = false
		area.set_deferred(&"monitorable", false)
		area.set_deferred(&"monitoring", false)
	var body := owner as CollisionObject2D
	if body != null:
		body.set_deferred(&"collision_layer", 0)
	sprite.play(animation)
	await sprite.animation_finished
	if effect != null:
		var fx: Node2D = effect.instantiate()
		fx.position = (owner as Node2D).position
		owner.get_parent().add_child(fx)
	finished.emit()
	owner.queue_free()
