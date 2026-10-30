class_name Cardosa
extends StaticBody2D
## Rooted thistle bud, the ranged forest enemy. When someone comes within reach it opens its
## petals (the warning), spits a slow seed at them and then needs a while to close again.
## Striking it during the wind-up makes it clamp shut and lose the shot.

signal defeated

enum State { IDLE, WINDUP, SHOOT, COOLDOWN, HURT, DEAD }

const SEED := preload("res://actors/cardosa/seed.tscn")
## Seeds aim at the target's body rather than its feet.
const AIM_OFFSET := Vector2(0, -6)

@export var windup_time: float = 0.7
@export var shoot_time: float = 0.3
@export var cooldown_time: float = 1.4
@export var hurt_time: float = 0.35
@export var seed_speed: float = 65.0
@export var seed_range: float = 150.0

var state: State = State.IDLE
var target: Node2D
var _state_left: float = 0.0

@onready var health: Health = $Health
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _detection: Area2D = $Detection
@onready var _muzzle: Marker2D = $Muzzle
@onready var _hit_flash: HitFlash = $HitFlash
@onready var _death: DeathSequence = $DeathSequence
@onready var _shoot_sound: AudioStreamPlayer2D = $ShootSound
@onready var _hit_sound: AudioStreamPlayer2D = $HitSound


func _ready() -> void:
	_detection.body_entered.connect(_on_body_entered)
	_detection.body_exited.connect(_on_body_exited)
	_hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	_enter(State.IDLE)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_state_left -= delta
	match state:
		State.IDLE:
			if _has_target():
				_enter(State.WINDUP)
		State.WINDUP:
			if _state_left <= 0.0:
				if _has_target():
					_fire()
					_enter(State.SHOOT)
				else:
					_enter(State.IDLE)
		State.SHOOT:
			if _state_left <= 0.0:
				_enter(State.COOLDOWN)
		State.COOLDOWN, State.HURT:
			if _state_left <= 0.0:
				_enter(State.IDLE)


func _has_target() -> bool:
	if not is_instance_valid(target):
		return false
	var target_health := target.get(&"health") as Health
	return target_health == null or not target_health.is_dead()


func _fire() -> void:
	var seed: Projectile = SEED.instantiate()
	seed.speed = seed_speed
	seed.max_distance = seed_range
	get_parent().add_child(seed)
	var from := _muzzle.global_position
	seed.launch(from, target.global_position + AIM_OFFSET - from, self)
	_shoot_sound.play()


func _enter(next: State) -> void:
	state = next
	match next:
		State.IDLE:
			_sprite.play(&"idle")
		State.WINDUP:
			_state_left = windup_time
			_sprite.play(&"windup")
		State.SHOOT:
			_state_left = shoot_time
			_sprite.play(&"shoot")
		State.COOLDOWN:
			_state_left = cooldown_time
			_sprite.play(&"idle")
		State.HURT:
			_state_left = hurt_time
			_sprite.play(&"hurt")


func _on_body_entered(body: Node2D) -> void:
	target = body


func _on_body_exited(body: Node2D) -> void:
	if body == target:
		target = null


## Rooted, it is never pushed: a blow makes it shut and stop shooting, longer for a heavy weapon.
func _on_hit_received(hit: Hit) -> void:
	_hit_sound.play()
	_hit_flash.flash()
	if state != State.DEAD:
		_enter(State.HURT)
		_state_left = maxf(hurt_time, hit.stagger * 1.5)


func _on_died() -> void:
	state = State.DEAD
	defeated.emit()
	_death.start()
