class_name Musgorico
extends CharacterBody2D
## Mossy hedgehog, the first hostile creature. Wanders near its home, chases a target it
## notices, then telegraphs and lunges. Touching its quills always hurts, and it bounces off
## whatever it pricks instead of sitting on top of it.

signal defeated

enum State { IDLE, WANDER, CHASE, WINDUP, LUNGE, RECOVER, RETURN, HURT, DEAD }

const ARRIVE_DISTANCE := 3.0

@export var wander_speed: float = 22.0
@export var chase_speed: float = 42.0
@export var lunge_speed: float = 150.0
@export var wander_radius: float = 40.0
## Gives up the chase when the target gets further than this.
@export var lose_radius: float = 120.0
## Never strays further than this from home while chasing.
@export var leash_radius: float = 170.0
## Starts the wind-up when the target is this close.
@export var lunge_range: float = 30.0
@export var windup_time: float = 0.45
@export var lunge_time: float = 0.22
@export var recover_time: float = 0.6
@export var hurt_time: float = 0.25
## Speed of the hop backwards after its quills prick something.
@export var recoil_speed: float = 90.0
@export var friction: float = 600.0
## Fixed seed for reproducible wandering (0 = random).
@export var rng_seed: int = 0

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN
var home: Vector2
var target: Node2D
var _state_left: float = 0.0
var _wander_goal: Vector2
var _lunge_direction: Vector2
var _rng := RandomNumberGenerator.new()

@onready var health: Health = $Health
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _contact: Hitbox = $ContactHitbox
@onready var _detection: Area2D = $Detection
@onready var _hit_flash: HitFlash = $HitFlash
@onready var _death: DeathSequence = $DeathSequence
@onready var _hit_sound: AudioStreamPlayer2D = $HitSound


func _ready() -> void:
	home = global_position
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_detection.body_entered.connect(_on_body_detected)
	_hurtbox.hit_received.connect(_on_hit_received)
	_contact.landed.connect(_on_contact_landed)
	health.died.connect(_on_died)
	_contact.active = true
	_enter(State.IDLE)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_left -= delta
	match state:
		State.IDLE:
			velocity = Vector2.ZERO
			if _can_chase():
				_enter(State.CHASE)
			elif _state_left <= 0.0:
				_enter(State.WANDER)
		State.WANDER:
			if _can_chase():
				_enter(State.CHASE)
			elif _state_left <= 0.0 or _move_towards(_wander_goal, wander_speed):
				_enter(State.IDLE)
		State.CHASE:
			if not _can_chase() or global_position.distance_to(home) > leash_radius:
				_enter(State.RETURN)
			elif global_position.distance_to(target.global_position) <= lunge_range:
				_enter(State.WINDUP)
			else:
				_move_towards(target.global_position, chase_speed)
		State.WINDUP:
			velocity = Vector2.ZERO
			# Telegraph: shiver in place, quills bristling, before the lunge.
			_sprite.offset.x = 1.0 if int(_state_left * 30.0) % 2 == 0 else -1.0
			if _state_left <= 0.0:
				_enter(State.LUNGE)
		State.LUNGE:
			velocity = _lunge_direction * lunge_speed
			if _state_left <= 0.0:
				_enter(State.RECOVER)
		State.RECOVER, State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
			if _state_left <= 0.0:
				_enter(State.CHASE if _can_chase() else State.RETURN)
		State.RETURN:
			if _move_towards(home, wander_speed):
				_enter(State.IDLE)
	move_and_slide()
	_update_animation()


## Starts pursuing `node` (normally assigned by the detection area).
func set_target(node: Node2D) -> void:
	target = node


func _can_chase() -> bool:
	if not is_instance_valid(target):
		return false
	var target_health := target.get(&"health") as Health
	if target_health != null and target_health.is_dead():
		return false
	return global_position.distance_to(target.global_position) <= lose_radius


## Steers towards `point`; returns true once it has arrived.
func _move_towards(point: Vector2, speed: float) -> bool:
	var to_point := point - global_position
	if to_point.length() <= ARRIVE_DISTANCE:
		velocity = Vector2.ZERO
		return true
	velocity = to_point.normalized() * speed
	return false


func _enter(next: State) -> void:
	state = next
	_sprite.offset.x = 0.0
	match next:
		State.IDLE:
			_state_left = _rng.randf_range(0.8, 2.0)
		State.WANDER:
			_state_left = 3.0
			var offset := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(10.0, wander_radius)
			_wander_goal = home + offset
		State.WINDUP:
			_state_left = windup_time
			_lunge_direction = global_position.direction_to(target.global_position)
			if _lunge_direction != Vector2.ZERO:
				facing = Facing.cardinal(_lunge_direction)
			_hit_flash.flash()
		State.LUNGE:
			_state_left = lunge_time
		State.RECOVER:
			_state_left = recover_time
		State.HURT:
			_state_left = hurt_time


func _update_animation() -> void:
	var moving := velocity.length() > 1.0
	if moving and state in [State.WANDER, State.CHASE, State.RETURN]:
		facing = Facing.cardinal(velocity)
	var dir := Facing.name_of(facing)
	match state:
		State.WINDUP:
			_sprite.play(StringName("windup_" + dir))
		State.LUNGE:
			_sprite.play(StringName("lunge_" + dir))
		State.HURT:
			_sprite.play(StringName("hurt_" + dir))
		_:
			_sprite.play(StringName(("walk_" if moving else "idle_") + dir))


func _on_body_detected(body: Node2D) -> void:
	if target == null:
		set_target(body)


func _on_contact_landed(hurtbox: Hurtbox) -> void:
	if state == State.DEAD:
		return
	var away := hurtbox.global_position.direction_to(global_position)
	velocity = (away if away != Vector2.ZERO else -facing) * recoil_speed
	_enter(State.RECOVER)


func _on_hit_received(hit: Hit) -> void:
	_hit_sound.play()
	_hit_flash.flash()
	if state == State.DEAD:
		return
	velocity = hit.knockback_velocity(global_position)
	_enter(State.HURT)


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	defeated.emit()
	_death.start()
