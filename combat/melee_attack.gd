class_name MeleeAttack
extends Node
## Runs one melee attack at a time: places and aims the hitbox, then steps through the
## AttackData phases on the physics clock. Owners map phases to animation frames.

signal phase_changed(phase: AttackData.Phase)
signal finished

@export var data: AttackData
@export var hitbox: Hitbox

var phase: AttackData.Phase = AttackData.Phase.IDLE
var direction: Vector2 = Vector2.DOWN
var _elapsed: float = 0.0


func _ready() -> void:
	set_physics_process(false)
	# Each attacker sizes its own blow; never the scene's shared shape.
	var shape := hitbox.get_node_or_null(^"Shape") as CollisionShape2D
	if shape != null and shape.shape != null:
		shape.shape = shape.shape.duplicate()


func _physics_process(delta: float) -> void:
	advance(delta)


func is_attacking() -> bool:
	return phase != AttackData.Phase.IDLE


## Seconds until the current attack ends (0 when idle).
func remaining() -> float:
	return maxf(data.duration() - _elapsed, 0.0) if is_attacking() else 0.0


## Starts an attack towards `toward` (any non-zero vector). Returns false if one is running.
func start(toward: Vector2) -> bool:
	if is_attacking() or toward == Vector2.ZERO:
		return false
	direction = toward.normalized()
	_elapsed = 0.0
	hitbox.damage = data.damage
	hitbox.power = data.power
	hitbox.knockback = data.knockback
	hitbox.stagger = data.stagger
	var shape := hitbox.get_node_or_null(^"Shape") as CollisionShape2D
	if shape != null and shape.shape is RectangleShape2D:
		(shape.shape as RectangleShape2D).size = data.hitbox_size
	# Aim during wind-up so overlaps are up to date by the time the hitbox becomes active.
	# The hitbox shape is authored for a downward swing.
	hitbox.position = direction * data.reach
	hitbox.rotation = direction.angle() - Vector2.DOWN.angle()
	set_physics_process(true)
	_set_phase(AttackData.Phase.WINDUP)
	return true


## True in the last `data.chain` seconds of the recovery: a quick weapon may swing again.
func can_chain() -> bool:
	return phase == AttackData.Phase.RECOVERY and data.chain > 0.0 and remaining() <= data.chain


func cancel() -> void:
	if is_attacking():
		set_physics_process(false)
		_set_phase(AttackData.Phase.IDLE)


func advance(delta: float) -> void:
	if not is_attacking():
		return
	_elapsed += delta
	var next := data.phase_at(_elapsed)
	# Never skip the active window, even on a long frame: it must get at least one tick.
	if phase == AttackData.Phase.WINDUP and next != AttackData.Phase.WINDUP and next != AttackData.Phase.ACTIVE:
		next = AttackData.Phase.ACTIVE
		_elapsed = data.windup
	if next == phase:
		return
	_set_phase(next)
	if next == AttackData.Phase.IDLE:
		set_physics_process(false)
		finished.emit()


func _set_phase(next: AttackData.Phase) -> void:
	phase = next
	hitbox.active = next == AttackData.Phase.ACTIVE
	phase_changed.emit(next)
