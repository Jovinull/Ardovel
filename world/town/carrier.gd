class_name Carrier
extends AnimatableBody2D
## Two quarry hands walking a cut block, slung from a pole between them, back and forth along their
## lane in the works yard at their own steady pace. They are solid: nobody walks through them, and
## whoever steps into their way is shoved back out of the lane (a bump, no harm). While Mestra
## Rufina has called a halt (from her hearing who lives past the Laje until the notice is down) they
## set the block down at the nearer end of their lane and wait.

const BUMP_STRENGTH := 220.0
## The pole's height above the carriers' feet: the line of the lane.
const POLE_Y := -4.0
const BUMP_EVERY := 0.6
const STEP_EVERY := 0.14

@export var from_x: float
@export var to_x: float
@export var speed: float = 40.0

var _adventure: Adventure
var _direction := 1.0
var _bump_cooldown := 0.0
var _walked := 0.0

@onready var _front: Sprite2D = $Front
@onready var _back: Sprite2D = $Back
@onready var _bump: Area2D = $Bump
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	sync_to_physics = false


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if is_halted():
		position.x = _nearer_end()


func is_halted() -> bool:
	return _adventure != null and _adventure.has_flag(Town.HEARD) and not _adventure.has_flag(Town.NOTICE_DOWN)


## +1 walking east, -1 walking west, 0 standing.
func heading() -> float:
	return 0.0 if is_resting() else _direction


func is_resting() -> bool:
	return is_halted() and is_equal_approx(position.x, _nearer_end())


func _nearer_end() -> float:
	return from_x if position.x - from_x < to_x - position.x else to_x


func _physics_process(delta: float) -> void:
	_bump_cooldown -= delta
	var before := position.x
	if is_halted():
		position.x = move_toward(position.x, _nearer_end(), speed * delta)
	else:
		position.x += _direction * speed * delta
		if position.x >= to_x:
			position.x = to_x
			_direction = -1.0
		elif position.x <= from_x:
			position.x = from_x
			_direction = 1.0
	var moving := not is_equal_approx(before, position.x)
	_walked += delta if moving else 0.0
	var column := (3 if position.x > before else 2) if moving else 0
	var step := 4 if moving and fmod(_walked, STEP_EVERY * 2.0) >= STEP_EVERY else 0
	_front.frame = column + step
	_back.frame = column + (4 - step if moving else 0)
	_push_out_whoever_is_in_the_way()


func _push_out_whoever_is_in_the_way() -> void:
	if _bump_cooldown > 0.0:
		return
	for body in _bump.get_overlapping_bodies():
		var player := body as Player
		if player != null and not player.health.is_dead():
			# Out of the lane, to whichever side the hero is on (towards the street if dead on it),
			# never ahead of the load and along it.
			var side := signf(player.global_position.y - (global_position.y + POLE_Y))
			var from := Vector2(player.global_position.x, player.global_position.y - (side if side != 0.0 else 1.0) * 10.0)
			player.bump(from, BUMP_STRENGTH)
			_sound.play()
			_bump_cooldown = BUMP_EVERY
			return
