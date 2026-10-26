class_name Player
extends CharacterBody2D
## The protagonist: four-way movement, sword attack, taking damage and interacting.
## Combat and interaction live in child components; this script only coordinates them.

signal died

enum State { MOVE, ATTACK, HURT, DEAD }

const HURT_TIME := 0.18
const DEATH_SPIN_STEP := 0.09
const DEATH_SPIN := [Vector2.DOWN, Vector2.LEFT, Vector2.UP, Vector2.RIGHT]

@export var max_speed: float = 72.0
## px/s²: reaches full speed in about 0.06 s, which keeps the controls snappy but not twitchy.
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0

var state: State = State.MOVE
var facing: Vector2 = Vector2.DOWN
var _hurt_left: float = 0.0
var _attack_buffered: bool = false

@onready var health: Health = $Health
@onready var camera: Camera2D = $Camera
@onready var interactor: Interactor = $Interactor
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _attack: MeleeAttack = $MeleeAttack
@onready var _hit_flash: HitFlash = $HitFlash
@onready var _swing_sound: AudioStreamPlayer2D = $SwingSound
@onready var _hurt_sound: AudioStreamPlayer2D = $HurtSound


func _ready() -> void:
	_hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	_attack.phase_changed.connect(_on_attack_phase_changed)
	_attack.finished.connect(_on_attack_finished)
	_sprite.play(&"idle_down")


func _physics_process(delta: float) -> void:
	match state:
		State.MOVE:
			_process_move(delta)
		State.ATTACK:
			if Input.is_action_just_pressed(&"attack"):
				_attack_buffered = true
			_brake(delta)
		State.HURT:
			_hurt_left -= delta
			_brake(delta)
			if _hurt_left <= 0.0:
				state = State.MOVE
		State.DEAD:
			pass


func _process_move(delta: float) -> void:
	if Input.is_action_just_pressed(&"attack"):
		_start_attack()
		return
	if Input.is_action_just_pressed(&"interact"):
		interactor.interact(self)
	var input := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	velocity = PlayerMotion.next_velocity(velocity, input, max_speed, acceleration, friction, delta)
	move_and_slide()
	facing = PlayerMotion.next_facing(input, facing)
	var prefix := "walk_" if input != Vector2.ZERO else "idle_"
	_sprite.play(StringName(prefix + Facing.name_of(facing)))


func _brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


func _start_attack() -> void:
	_attack_buffered = false
	if _attack.start(facing):
		state = State.ATTACK
		velocity = Vector2.ZERO


func _on_attack_phase_changed(phase: AttackData.Phase) -> void:
	if phase == AttackData.Phase.IDLE:
		return
	# Attack sheet columns: wind-up, strike, follow-through.
	_sprite.stop()
	_sprite.animation = StringName("attack_" + Facing.name_of(_attack.direction))
	_sprite.frame = phase - AttackData.Phase.WINDUP
	if phase == AttackData.Phase.ACTIVE:
		_swing_sound.play()


func _on_attack_finished() -> void:
	if state != State.ATTACK:
		return
	state = State.MOVE
	if _attack_buffered:
		_start_attack()


func _on_hit_received(hit: Hit) -> void:
	_hurt_sound.play()
	_hit_flash.flash()
	if state == State.DEAD:
		return
	_attack.cancel()
	_attack_buffered = false
	state = State.HURT
	_hurt_left = HURT_TIME
	velocity = hit.knockback_velocity(global_position)
	_sprite.play(StringName("idle_" + Facing.name_of(facing)))
	_hit_flash.blink(health.invulnerability_time)


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_attack.cancel()
	_hurtbox.set_deferred(&"monitorable", false)
	# There is no death animation in the art yet: spin through the idle poses, then fade out.
	var tween := create_tween()
	for i in 8:
		tween.tween_callback(_show_idle.bind(DEATH_SPIN[i % DEATH_SPIN.size()]))
		tween.tween_interval(DEATH_SPIN_STEP)
	tween.tween_property(_sprite, ^"modulate:a", 0.0, 0.4)
	tween.tween_callback(died.emit)


func _show_idle(direction: Vector2) -> void:
	_sprite.play(StringName("idle_" + Facing.name_of(direction)))
