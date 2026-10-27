class_name PushBlock
extends AnimatableBody2D
## A heavy stone block that slides one tile when the hero keeps leaning on it for a moment.
## It only moves into free space (no walls, actors or other blocks).

signal moved

const TILE := 16.0
## Seconds of leaning before the block gives way.
const LEAN_TIME := 0.35
const SLIDE_TIME := 0.22
## What a block cannot slide into: the world, the hero and enemies.
const BLOCKING_LAYERS := 1 | 2 | 4

var locked: bool = false
var _home: Vector2
var _lean_direction := Vector2.ZERO
var _lean_time: float = 0.0
var _leaned_this_frame: bool = false
var _sliding: bool = false

@onready var _shape: CollisionShape2D = $Collision
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	_home = position


func _physics_process(_delta: float) -> void:
	if not _leaned_this_frame:
		_lean_time = 0.0
	_leaned_this_frame = false


## Called every physics frame the hero walks into the block while holding `direction`.
func lean(direction: Vector2, delta: float) -> void:
	if locked or _sliding or direction == Vector2.ZERO:
		return
	var cardinal := Facing.cardinal(direction)
	if cardinal != _lean_direction:
		_lean_direction = cardinal
		_lean_time = 0.0
	_leaned_this_frame = true
	_lean_time += delta
	if _lean_time >= LEAN_TIME:
		_lean_time = 0.0
		try_slide(cardinal)


## Slides one tile towards `direction` if that space is free; returns whether it moved.
func try_slide(direction: Vector2) -> bool:
	if locked or _sliding or not _is_free(position + direction * TILE):
		return false
	_sliding = true
	_sound.play()
	var tween := create_tween()
	tween.tween_property(self, ^"position", position + direction * TILE, SLIDE_TIME)
	await tween.finished
	_sliding = false
	moved.emit()
	return true


## Back to where the block started (a puzzle that must never get stuck).
func reset() -> void:
	if locked or position == _home:
		return
	position = _home
	reset_physics_interpolation()


func place(at: Vector2) -> void:
	position = at
	reset_physics_interpolation()


func _is_free(target: Vector2) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _shape.shape
	query.transform = Transform2D(0.0, get_parent().to_global(target) + _shape.position)
	query.collision_mask = BLOCKING_LAYERS
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
