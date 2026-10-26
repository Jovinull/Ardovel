class_name Projectile
extends Area2D
## Flies in a straight line and bursts on the first thing it meets: a hurtbox it damages, a solid
## body (except whoever fired it), a blade that cuts it (its own Health dies) or the end of its range.

signal burst

@export var speed: float = 70.0
@export var max_distance: float = 160.0
@export var burst_effect: PackedScene

var direction: Vector2 = Vector2.RIGHT
var shooter: Node
var _travelled: float = 0.0
var _done: bool = false

@onready var _hitbox: Hitbox = $Hitbox
@onready var _health: Health = $Health


func _ready() -> void:
	# Stays monitorable on purpose: in Godot 4.7 a non-monitorable Area2D stops detecting
	# StaticBody2D, so walls would be ignored. Its empty collision layer already keeps it
	# invisible to other areas.
	body_entered.connect(_on_body_entered)
	_hitbox.landed.connect(_on_landed)
	_health.died.connect(_burst)
	_hitbox.active = true


func launch(from: Vector2, toward: Vector2, source: Node) -> void:
	global_position = from
	direction = toward.normalized() if toward != Vector2.ZERO else Vector2.DOWN
	shooter = source


func _physics_process(delta: float) -> void:
	var step := direction * speed * delta
	position += step
	_travelled += step.length()
	if _travelled >= max_distance:
		_burst()


func _on_body_entered(body: Node2D) -> void:
	if body != shooter:
		_burst()


func _on_landed(_hurtbox: Hurtbox) -> void:
	_burst()


func _burst() -> void:
	if _done:
		return
	_done = true
	_hitbox.active = false
	set_physics_process(false)
	if burst_effect != null:
		var effect: Node2D = burst_effect.instantiate()
		effect.position = position
		get_parent().add_child.call_deferred(effect)
	burst.emit()
	queue_free()
