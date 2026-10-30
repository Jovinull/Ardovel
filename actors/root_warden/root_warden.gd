class_name RootWarden
extends CharacterBody2D
## The Root Warden, guardian of the first ruin: a stone sentinel taken over by roots. It drags
## itself after the hero; up close it raises its fists (the warning: light leaks from its
## chest) and slams them down all around it, then stays stuck with its core bare, the only time
## the sword can hurt it (and, caught as it is, touching it does no harm then). From afar, and
## once after every slam, it drives its fists into the ground and roots burst up under the
## hero. Below half health it gets quicker and the roots come in threes.

signal defeated
## Health left after a hit (for the boss bar).
signal health_changed(current: int, maximum: int)

enum State { DORMANT, IDLE, WINDUP, SLAM, STUCK, CAST, DEAD }

const SPIKE := preload("res://actors/root_warden/root_spike.tscn")
const DUST := preload("res://actors/root_warden/slam_dust.tscn")
## Where extra spikes land around the hero once it is enraged.
const SPIKE_SPREAD := 28.0

## How close the hero must be for a slam; also the slam's reach (SlamHitbox radius), so a slam
## the warden decides on can always land.
@export var slam_range: float = 40.0
@export var move_speed: float = 18.0
@export var idle_time: float = 0.9
@export var windup_time: float = 0.75
@export var slam_time: float = 0.15
@export var stuck_time: float = 1.5
@export var cast_time: float = 0.6
@export var spike_warning_time: float = 0.8
## Multiplier for every timing once the warden is down to half health.
@export var enraged_pace: float = 0.7

var state: State = State.DORMANT
var target: Node2D
var _state_left: float = 0.0
## Set after a slam: the next attack is the roots, wherever the hero stands.
var _owes_cast: bool = false

@onready var health: Health = $Health
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _contact: Hitbox = $ContactHitbox
@onready var _slam: Hitbox = $SlamHitbox
@onready var _fists: Marker2D = $Fists
@onready var _hit_flash: HitFlash = $HitFlash
@onready var _hit_sound: AudioStreamPlayer2D = $HitSound
@onready var _clank_sound: AudioStreamPlayer2D = $ClankSound
@onready var _slam_sound: AudioStreamPlayer2D = $SlamSound
@onready var _death_sound: AudioStreamPlayer2D = $DeathSound


func _ready() -> void:
	_hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	_sprite.play(&"idle")


## Starts the fight against `hero`.
func wake(hero: Node2D) -> void:
	if state != State.DORMANT:
		return
	target = hero
	_enter(State.IDLE)


func is_enraged() -> bool:
	return health.current * 2 <= health.max_health


func is_vulnerable() -> bool:
	return state == State.STUCK


func _physics_process(delta: float) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_state_left -= delta
	match state:
		State.IDLE:
			_chase(delta)
			if not _target_alive():
				return
			if _near_target() and not _owes_cast:
				_enter(State.WINDUP)
			elif _state_left <= 0.0:
				_enter(State.CAST)
		State.WINDUP:
			if _state_left <= 0.0:
				_enter(State.SLAM)
		State.SLAM:
			if _state_left <= 0.0:
				_enter(State.STUCK)
		State.STUCK, State.CAST:
			if _state_left <= 0.0:
				_enter(State.IDLE)


func _chase(delta: float) -> void:
	if not _target_alive() or _near_target():
		velocity = Vector2.ZERO
		return
	velocity = global_position.direction_to(target.global_position) * move_speed * _pace_speed()
	move_and_collide(velocity * delta)


func _target_alive() -> bool:
	if not is_instance_valid(target):
		return false
	var target_health := target.get(&"health") as Health
	return target_health == null or not target_health.is_dead()


func _near_target() -> bool:
	return global_position.distance_to(target.global_position) <= slam_range


## Timings shrink once enraged.
func _pace() -> float:
	return enraged_pace if is_enraged() else 1.0


func _pace_speed() -> float:
	return 1.0 / _pace()


func _enter(next: State) -> void:
	state = next
	_slam.active = false
	_contact.active = next != State.STUCK and next != State.DORMANT
	match next:
		State.IDLE:
			_state_left = idle_time * _pace()
			_sprite.play(&"idle")
		State.WINDUP:
			_state_left = windup_time * _pace()
			_sprite.play(&"windup")
			_sprite.speed_scale = 2.0 / _state_left
		State.SLAM:
			_state_left = slam_time
			_sprite.speed_scale = 1.0
			_sprite.play(&"slam")
			_slam.active = true
			_slam_sound.play()
			var dust: Node2D = DUST.instantiate()
			dust.global_position = _fists.global_position
			get_parent().add_child(dust)
		State.STUCK:
			_state_left = stuck_time * _pace()
			_owes_cast = true
			_sprite.play(&"stuck")
		State.CAST:
			_owes_cast = false
			_state_left = cast_time * _pace()
			_sprite.play(&"cast")
			_slam_sound.play()
			_raise_spikes()


func _raise_spikes() -> void:
	if not _target_alive():
		return
	var spots: Array[Vector2] = [target.global_position]
	if is_enraged():
		var away := global_position.direction_to(target.global_position).orthogonal() * SPIKE_SPREAD
		spots.append_array([target.global_position + away, target.global_position - away])
	for spot in spots:
		var spike: RootSpike = SPIKE.instantiate()
		spike.warning_time = spike_warning_time * _pace()
		spike.global_position = spot
		get_parent().add_child(spike)


func _on_hit_received(hit: Hit) -> void:
	if state == State.DEAD:
		return
	if not is_vulnerable():
		_clank_sound.play()
		return
	_hit_sound.play()
	_hit_flash.flash()
	health.take_hit(hit.damage * hit.power, 1)
	health_changed.emit(health.current, health.max_health)


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_slam.active = false
	_contact.active = false
	_hurtbox.set_deferred(&"monitorable", false)
	set_deferred(&"collision_layer", 0)
	_death_sound.play()
	_sprite.speed_scale = 1.0
	_sprite.play(&"death")
	await _sprite.animation_finished
	defeated.emit()
