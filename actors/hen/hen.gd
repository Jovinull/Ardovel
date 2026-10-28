class_name Hen
extends CharacterBody2D
## One of Cida's hens. Loose, it pecks about, runs from the hero when they come close and walks
## to scattered grain when someone calls. Penned, it stays inside its yard whatever happens.

## How close the hero may come before the hen runs.
const FLEE_RADIUS := 40.0
## How close the hero may come to a hen that is going for grain.
const CLOSE_RADIUS := 14.0
## Slower than the hero (72), so the hero can steer it by walking behind it.
const FLEE_SPEED := 56.0
const WANDER_SPEED := 14.0
const LURE_SPEED := 30.0
## Wander steps: how far and how long to stand in between.
const WANDER_REACH := 14.0
const PAUSE_MIN := 0.8
const PAUSE_MAX := 2.2
const STEP_TIME := 0.16

## Pack chicken sheet (two 16x16 frames facing right: standing, stepping).
@export var sheet: Texture2D

## The one it runs from (the yard hands it the area's hero).
var hero: Node2D
var penned: bool = false
var _rng := RandomNumberGenerator.new()
var _target := Vector2.ZERO
var _pause := 0.0
var _step := 0.0
var _pen := Rect2()
## Where grain draws the hen, in order (the mouth of a gate, then the grain inside).
var _lure_path: Array[Vector2] = []
var _lure_radius := 0.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	if sheet != null:
		_sprite.texture = sheet
	# Each hen keeps its own, repeatable wandering.
	_rng.seed = hash(String(name))
	_target = global_position
	_pause = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)


## Keeps the hen inside `area` (global coordinates) from now on.
func pen(area: Rect2) -> void:
	penned = true
	_pen = area
	_lure_path.clear()
	_target = global_position.clamp(area.position, area.end)
	_pause = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)


## Places a penned hen without walking (for a yard loaded with its hens already in).
func settle_at(at: Vector2, area: Rect2) -> void:
	global_position = at
	reset_physics_interpolation()
	pen(area)


## Grain: a hen within `radius` of the first point walks through `path` when not frightened.
func lure(path: Array[Vector2], radius: float) -> void:
	_lure_path = path.duplicate()
	_lure_radius = radius


func _physics_process(delta: float) -> void:
	var direction := Vector2.ZERO
	var speed := WANDER_SPEED
	var lured := not penned and not _lure_path.is_empty() \
			and global_position.distance_to(_lure_path[0]) < _lure_radius
	# Near the grain a hen only minds the hero when they are right on top of it.
	var wary := CLOSE_RADIUS if lured else FLEE_RADIUS
	if not penned and is_instance_valid(hero) \
			and global_position.distance_to(hero.global_position) < wary:
		direction = (global_position - hero.global_position).normalized()
		speed = FLEE_SPEED
		_target = global_position
		_pause = _rng.randf_range(PAUSE_MIN, PAUSE_MAX) * 0.5
	elif lured:
		direction = global_position.direction_to(_lure_path[0])
		speed = LURE_SPEED
		if global_position.distance_to(_lure_path[0]) < 3.0 and _lure_path.size() > 1:
			_lure_path.pop_front()
	else:
		direction = _wander(delta)
	velocity = direction * speed
	move_and_slide()
	_animate(direction, delta)


func _wander(delta: float) -> Vector2:
	if global_position.distance_to(_target) > 1.0:
		var away := global_position.direction_to(_target)
		# Give up on a step that runs into something; peck where it stands instead.
		if get_slide_collision_count() > 0:
			_target = global_position
		return away
	_pause -= delta
	if _pause > 0.0:
		return Vector2.ZERO
	_pause = _rng.randf_range(PAUSE_MIN, PAUSE_MAX)
	var next := global_position + Vector2(_rng.randf_range(-1.0, 1.0),
			_rng.randf_range(-1.0, 1.0)).normalized() * WANDER_REACH
	_target = next.clamp(_pen.position, _pen.end) if penned else next
	return Vector2.ZERO


func _animate(direction: Vector2, delta: float) -> void:
	if direction.x != 0.0:
		_sprite.flip_h = direction.x < 0.0
	if direction == Vector2.ZERO:
		_sprite.frame = 0
		_step = 0.0
		return
	_step += delta
	if _step >= STEP_TIME:
		_step = 0.0
		_sprite.frame = 1 - _sprite.frame
