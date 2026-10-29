class_name Breu
extends Node2D
## Breu, the travelling witch's bat. A child of her scene (he never leaves her), but he flies on
## his own, over everything, between points set by hand:
## - at her shoulder, on the side she is not facing, bobbing;
## - once, when the hero first comes near, a circle round the hero's head and back;
## - once she has asked for the way up to the high stone, ahead of the hero: hovering over the
##   next tangle on the old path until it is cut, then perched on the high stone;
## - after the view has been seen, back at her shoulder.
## He moves only towards those points: no pathfinding, no combat.

enum State { SHOULDER, GREETING, LEADING, PERCHED }

const SPEED := 70.0
const SHOULDER := Vector2(12, -24)
const HOVER := Vector2(0, -16)
const GREET_REACH := 56.0
const CIRCLE_RADIUS := 14.0
const CIRCLE_TIME := 1.2
const BLINK_EVERY := 3.0

## The high stone, where he perches once the path is open.
@export var perch: Node2D

var state := State.SHOULDER
var _adventure: Adventure
var _greeted := false
var _circle := 0.0
var _time := 0.0

@onready var _fly: AnimatedSprite2D = $Fly
@onready var _rest: Sprite2D = $Rest


func _ready() -> void:
	add_to_group(&"adventure")
	top_level = true


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	global_position = _witch_shoulder()


func _witch() -> WitchTraveler:
	return get_parent() as WitchTraveler


func _hero() -> Node2D:
	var level := owner as Level
	return level.player if level != null else null


func _witch_shoulder() -> Vector2:
	var witch := _witch()
	if witch == null or not witch.is_node_ready():
		return global_position
	var side := -1.0 if witch.facing_direction() == Vector2.RIGHT else 1.0
	return witch.global_position + Vector2(SHOULDER.x * side, SHOULDER.y)


## The next tangle on the old path still standing, in order, or null.
func next_tangle() -> BrushTangle:
	var best: BrushTangle = null
	for node in get_tree().get_nodes_in_group(&"blank_tangle"):
		var tangle := node as BrushTangle
		if tangle != null and not tangle.is_cut() and (best == null or tangle.order < best.order):
			best = tangle
	return best


func _leading() -> bool:
	return _adventure != null and _adventure.has_flag(Blank.MET) and not _adventure.has_flag(Blank.VIEW_SEEN)


func _physics_process(delta: float) -> void:
	_time += delta
	var hero := _hero()
	if state == State.SHOULDER and not _greeted and hero != null and _witch() != null \
			and hero.global_position.distance_to(_witch().global_position) < GREET_REACH:
		_greeted = true
		_circle = 0.0
		state = State.GREETING
	if state != State.GREETING:
		state = State.LEADING if _leading() else State.SHOULDER
	var target := _witch_shoulder()
	match state:
		State.GREETING:
			_circle += delta / CIRCLE_TIME
			if _circle >= 1.0 or hero == null:
				state = State.SHOULDER
			else:
				target = hero.global_position + Vector2(0, -20) + Vector2.from_angle(_circle * TAU) * CIRCLE_RADIUS
		State.LEADING:
			var tangle := next_tangle()
			if tangle != null:
				target = tangle.global_position + HOVER
			elif perch != null:
				target = perch.global_position
	var bob := Vector2(0, 1.0 if fmod(_time, 0.5) < 0.25 else 0.0)
	global_position = global_position.move_toward(target + (bob if state != State.LEADING or next_tangle() != null else Vector2.ZERO), SPEED * delta)
	var resting := state == State.LEADING and next_tangle() == null and perch != null \
			and global_position.distance_to(perch.global_position) < 1.0
	_fly.visible = not resting
	_rest.visible = resting
	_rest.frame = 1 if fmod(_time, BLINK_EVERY) < 0.15 else 0
	if resting:
		state = State.PERCHED


func is_perched() -> bool:
	return _rest.visible
