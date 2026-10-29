class_name Player
extends CharacterBody2D
## The protagonist: four-way movement, sword attack, taking damage and interacting.
## Combat and interaction live in child components; this script only coordinates them.

signal died
## A sword swing connected with a target.
signal hit_landed

enum State { MOVE, ATTACK, HURT, DEAD }

const HIT_SPARK := preload("res://fx/hit_spark.tscn")

@export var max_speed: float = 72.0
## px/s²: reaches full speed in about 0.06 s, which keeps the controls snappy but not twitchy.
@export var acceleration: float = 1200.0
@export var friction: float = 1600.0
## Seconds without control after being hit, while the knockback plays out.
@export var hurt_time: float = 0.2
## An attack pressed this close to the end of the current swing is queued instead of dropped.
@export var attack_buffer_time: float = 0.15
## Seconds the fallen pose is held before `died` is emitted.
@export var death_hold_time: float = 0.5

var state: State = State.MOVE
var facing: Vector2 = Vector2.DOWN
var _hurt_left: float = 0.0
var _attack_buffered: bool = false
## The sword as the scene defines it; what is equipped changes a copy of it (set_sword_power).
var _base_sword: AttackData

@onready var health: Health = $Health
@onready var camera: Camera2D = $Camera
@onready var interactor: Interactor = $Interactor
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _attack: MeleeAttack = $MeleeAttack
@onready var _sword: Hitbox = $AttackPivot/SwordHitbox
@onready var _hit_flash: HitFlash = $HitFlash
@onready var _swing_sound: AudioStreamPlayer2D = $SwingSound
@onready var _hurt_sound: AudioStreamPlayer2D = $HurtSound


func _ready() -> void:
	_hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	_attack.phase_changed.connect(_on_attack_phase_changed)
	_attack.finished.connect(_on_attack_finished)
	_sword.landed.connect(_on_sword_landed)
	_base_sword = _attack.data
	_sprite.play(&"idle_down")


func _physics_process(delta: float) -> void:
	match state:
		State.MOVE:
			_process_move(delta)
		State.ATTACK:
			if Input.is_action_just_pressed(&"attack") and _attack.remaining() <= attack_buffer_time:
				_attack_buffered = true
			_brake(delta)
		State.HURT:
			_hurt_left -= delta
			_brake(delta)
			if _hurt_left <= 0.0:
				state = State.MOVE
		State.DEAD:
			pass


## Turns the hero towards `direction` (snapped to a cardinal) in the idle pose.
func face(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return
	facing = Facing.cardinal(direction)
	_sprite.play(StringName("idle_" + Facing.name_of(facing)))


func _move_input() -> Vector2:
	return Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")


func _process_move(delta: float) -> void:
	var input := _move_input()
	if Input.is_action_just_pressed(&"attack"):
		_start_attack(input)
		return
	if Input.is_action_just_pressed(&"interact"):
		interactor.interact(self)
	velocity = PlayerMotion.next_velocity(velocity, input, max_speed, acceleration, friction, delta)
	move_and_slide()
	_lean_on_blocks(input, delta)
	facing = PlayerMotion.next_facing(input, facing)
	var prefix := "walk_" if input != Vector2.ZERO else "idle_"
	_sprite.play(StringName(prefix + Facing.name_of(facing)))


## Leans on any push block the hero is walking straight into; it slides after a moment.
func _lean_on_blocks(input: Vector2, delta: float) -> void:
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var block := collision.get_collider() as PushBlock
		if block != null and input.dot(-collision.get_normal()) > 0.7:
			block.lean(-collision.get_normal(), delta)


func _brake(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	move_and_slide()


## The direction held when a swing starts wins, so the hero can turn between swings.
func _start_attack(input: Vector2) -> void:
	_attack_buffered = false
	facing = PlayerMotion.next_facing(input, facing)
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
		_start_attack(_move_input())


func _on_sword_landed(target: Hurtbox) -> void:
	var spark: Node2D = HIT_SPARK.instantiate()
	spark.global_position = target.global_position.lerp(_sword.global_position, 0.5)
	get_parent().add_child(spark)
	hit_landed.emit()


func base_sword() -> AttackData:
	return _base_sword


## The sword's damage and knockback (derived from what is equipped); its timing and reach stay
## the scene's. A swing under way keeps the values it started with.
func set_sword_power(damage: int, knockback: float) -> void:
	var sword := _base_sword.duplicate() as AttackData
	sword.damage = damage
	sword.knockback = knockback
	_attack.data = sword


func sword_power() -> AttackData:
	return _attack.data


## A shove that costs no health (people carrying a load across a crowded yard): knocked back from
## `source_position` and briefly staggered, without the hurt sound, flash or blinking of a hit.
func bump(source_position: Vector2, strength: float) -> void:
	if state != State.DEAD:
		_stagger(Hit.new(0, strength, source_position))


func _on_hit_received(hit: Hit) -> void:
	_hurt_sound.play()
	_hit_flash.flash()
	if state == State.DEAD:
		return
	_stagger(hit)
	_hit_flash.blink(health.invulnerability_time)


func _stagger(hit: Hit) -> void:
	_attack.cancel()
	_attack_buffered = false
	state = State.HURT
	_hurt_left = hurt_time
	velocity = hit.knockback_velocity(global_position)
	# Face whoever hit us; the knockback carries the hero backwards, away from them.
	var toward_source := global_position.direction_to(hit.source_position)
	if toward_source != Vector2.ZERO:
		facing = Facing.cardinal(toward_source)
	_sprite.play(StringName("hurt_" + Facing.name_of(facing)))


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_attack.cancel()
	_hurtbox.set_deferred(&"monitorable", false)
	_hit_flash.stop_blinking()
	_sprite.play(&"death")
	await _sprite.animation_finished
	await get_tree().create_timer(death_hold_time).timeout
	died.emit()
