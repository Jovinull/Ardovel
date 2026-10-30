class_name Player
extends CharacterBody2D
## The protagonist: four-way movement, the weapon in hand, the shield raised, a quick dodge, eating
## from the quick slot, taking damage and interacting. Combat and interaction live in child
## components (MeleeAttack, Hurtbox, Health, Stamina); this script only coordinates them.
##
## What may cut into what (anything else waits for the action to end):
## - a swing's windup, or the last half of its recovery, can turn into a dodge;
## - a quick weapon may swing again in the last part of its recovery (AttackData.chain);
## - a raised shield can be lowered into a swing or a dodge at once;
## - a dodge cannot be interrupted, and an attack pressed during it is kept for when it ends;
## - eating is interrupted by any hit (nothing is eaten);
## - a hit interrupts everything but a dodge's untouchable moment.

signal died
## A swing connected with a target.
signal hit_landed
## The hero finished eating from the quick slot (the game takes the item and heals).
signal quick_use_finished

enum State { MOVE, ATTACK, HURT, DEAD, GUARD, DODGE, USE }

const HIT_SPARK := preload("res://fx/hit_spark.tscn")
const AFTERIMAGE_EVERY := 0.05
## Breath one dodge costs.
const DODGE_BREATH := 25.0
## Seconds the hero is held after a blocked hit, and after the guard breaks.
const BLOCK_RECOIL := 0.18
const GUARD_BREAK_TIME := 0.55
## A blocked hit leaves this long before another can land.
const BLOCK_IMMUNITY := 0.3

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
## Seconds eating from the quick slot takes, standing still.
@export var use_time: float = 0.9

var state: State = State.MOVE
var facing: Vector2 = Vector2.DOWN
## Percent of the knockback taken that the hero's footing absorbs (from what is worn).
var poise_percent: float = 0.0
## Whether eating is possible now (the game knows the quick slot and the hero's health).
var can_quick_use: Callable
var _hurt_left: float = 0.0
var _attack_buffered: bool = false
## Top speed and acceleration as fractions of the scene's (from the weight carried).
var _speed_factor: float = 1.0
var _acceleration_factor: float = 1.0
var _attack_sheet: Texture2D
var _guard: GuardData
var _guard_sheet: Texture2D
var _guard_up := 0.0
var _dodge := HeroLoadout.Dodge.new()
var _dodge_direction := Vector2.DOWN
var _dodge_elapsed := 0.0
var _afterimage_left := 0.0
var _use_left := 0.0

@onready var health: Health = $Health
@onready var stamina: Stamina = $Stamina
@onready var camera: Camera2D = $Camera
@onready var interactor: Interactor = $Interactor
@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _attack: MeleeAttack = $MeleeAttack
@onready var _sword: Hitbox = $AttackPivot/SwordHitbox
@onready var _hit_flash: HitFlash = $HitFlash
@onready var _swing_sound: AudioStreamPlayer2D = $SwingSound
@onready var _hurt_sound: AudioStreamPlayer2D = $HurtSound
@onready var _block_sound: AudioStreamPlayer2D = $BlockSound
@onready var _break_sound: AudioStreamPlayer2D = $GuardBreakSound
@onready var _dodge_sound: AudioStreamPlayer2D = $DodgeSound
@onready var _eat_sound: AudioStreamPlayer2D = $EatSound
@onready var _held_item: Sprite2D = $HeldItem


func _ready() -> void:
	_hurtbox.hit_received.connect(_on_hit_received)
	_hurtbox.guard = _screen_hit
	health.died.connect(_on_died)
	_attack.phase_changed.connect(_on_attack_phase_changed)
	_attack.finished.connect(_on_attack_finished)
	_sword.landed.connect(_on_sword_landed)
	# Each hero swaps the attack and guard frames to what is in hand; never the shared resource.
	_sprite.sprite_frames = _sprite.sprite_frames.duplicate(true)
	_held_item.visible = false
	_sprite.play(&"idle_down")


func _physics_process(delta: float) -> void:
	match state:
		State.MOVE:
			_process_move(delta)
		State.ATTACK:
			_process_attack(delta)
		State.GUARD:
			_process_guard(delta)
		State.DODGE:
			_process_dodge(delta)
		State.USE:
			_process_use(delta)
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
	if Input.is_action_just_pressed(&"dodge") and _start_dodge(input):
		return
	if Input.is_action_pressed(&"block") and _guard != null:
		_start_guard()
		return
	if Input.is_action_just_pressed(&"quick_item") and _start_use():
		return
	if Input.is_action_just_pressed(&"interact"):
		interactor.interact(self)
	_walk(input, 1.0, delta)
	facing = PlayerMotion.next_facing(input, facing)
	var prefix := "walk_" if input != Vector2.ZERO else "idle_"
	_sprite.play(StringName(prefix + Facing.name_of(facing)))


func _walk(input: Vector2, factor: float, delta: float) -> void:
	velocity = PlayerMotion.next_velocity(velocity, input, max_speed * _speed_factor * factor,
			acceleration * _acceleration_factor, friction, delta)
	move_and_slide()
	_lean_on_blocks(input, delta)


func _process_attack(delta: float) -> void:
	if Input.is_action_just_pressed(&"dodge") and _dodge_allowed_in_swing():
		_attack.cancel()
		if _start_dodge(_move_input()):
			return
		state = State.MOVE
	if Input.is_action_just_pressed(&"attack"):
		if _attack.can_chain():
			_attack.cancel()
			_start_attack(_move_input())
			return
		if _attack.remaining() <= attack_buffer_time:
			_attack_buffered = true
	_brake(delta)


## A dodge may cut a swing short only before it lands, or once most of its recovery is spent.
func _dodge_allowed_in_swing() -> bool:
	if _attack.phase == AttackData.Phase.WINDUP:
		return true
	return _attack.phase == AttackData.Phase.RECOVERY and _attack.remaining() <= _attack.data.recovery * 0.5


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


# ---------------------------------------------------------------- guard

func _start_guard() -> void:
	state = State.GUARD
	_guard_up = 0.0
	velocity = Vector2.ZERO
	_show_guard()


func _process_guard(delta: float) -> void:
	if _guard == null or not Input.is_action_pressed(&"block"):
		state = State.MOVE
		return
	if Input.is_action_just_pressed(&"attack"):
		_start_attack(_move_input())
		return
	if Input.is_action_just_pressed(&"dodge") and _start_dodge(_move_input()):
		return
	_guard_up += delta
	# The shield faces where it was raised; the hero edges along behind it.
	_walk(_move_input(), _guard.move_factor, delta)
	_show_guard()


## Whether a raised shield is up and covering now.
func is_guarding() -> bool:
	return state == State.GUARD and _guard != null and _guard_up >= _guard.raise_time


func _show_guard() -> void:
	var animation := StringName("guard_" + Facing.name_of(facing))
	if _sprite.sprite_frames.has_animation(animation):
		_sprite.play(animation)


## Whether `from` (a blow's origin) lies within the arc the shield covers.
func covers(from: Vector2) -> bool:
	var toward := global_position.direction_to(from)
	if toward == Vector2.ZERO:
		return true
	return rad_to_deg(absf(facing.angle_to(toward))) <= _guard.arc / 2.0


# ---------------------------------------------------------------- dodge

## A quick step: along the direction held, or back from where the hero faces. Untouchable for its
## first moment (shorter when heavily loaded), then a short recovery.
func _start_dodge(input: Vector2) -> bool:
	if not stamina.spend(DODGE_BREATH):
		return false
	_dodge_direction = input.normalized() if input != Vector2.ZERO else -facing
	if input != Vector2.ZERO:
		facing = PlayerMotion.next_facing(input, facing)
	_dodge_elapsed = 0.0
	_afterimage_left = 0.0
	_attack_buffered = false
	state = State.DODGE
	_dodge_sound.play()
	_sprite.play(StringName("walk_" + Facing.name_of(facing)))
	return true


func _process_dodge(delta: float) -> void:
	_dodge_elapsed += delta
	if Input.is_action_just_pressed(&"attack"):
		_attack_buffered = true
	if _dodge_elapsed < _dodge.duration:
		var distance := _dodge.distance * (0.6 if _is_backstep() else 1.0)
		velocity = _dodge_direction * distance / _dodge.duration
		move_and_slide()
		_afterimage_left -= delta
		if _afterimage_left <= 0.0:
			_afterimage_left = AFTERIMAGE_EVERY
			_leave_afterimage()
		return
	velocity = Vector2.ZERO  # the step ends where it ends: no sliding on
	if _dodge_elapsed >= _dodge.duration + _dodge.recovery:
		state = State.MOVE
		if _attack_buffered:
			_start_attack(_move_input())


func _is_backstep() -> bool:
	return _dodge_direction.dot(facing) < -0.7


## Whether the dodge's untouchable moment is running.
func is_untouchable() -> bool:
	return state == State.DODGE and _dodge_elapsed < _dodge.untouchable


func _leave_afterimage() -> void:
	var ghost := Sprite2D.new()
	ghost.texture = _sprite.sprite_frames.get_frame_texture(_sprite.animation, _sprite.frame)
	ghost.global_position = _sprite.global_position
	ghost.offset = _sprite.offset
	ghost.modulate = Color(1, 1, 1, 0.45)
	ghost.z_index = -1
	get_parent().add_child(ghost)
	var tween := ghost.create_tween()
	tween.tween_property(ghost, ^"modulate:a", 0.0, 0.16)
	tween.tween_callback(ghost.queue_free)


# ---------------------------------------------------------------- eating

func _start_use() -> bool:
	if not can_quick_use.is_valid() or not can_quick_use.call():
		return false
	state = State.USE
	_use_left = use_time
	velocity = Vector2.ZERO
	_sprite.play(&"idle_down")
	_held_item.visible = true
	_eat_sound.play()
	return true


func _process_use(delta: float) -> void:
	_brake(delta)
	_use_left -= delta
	if _use_left <= 0.0:
		_held_item.visible = false
		state = State.MOVE
		quick_use_finished.emit()


## What the hero holds up while eating (the quick slot's icon).
func set_held_item(icon: Texture2D) -> void:
	_held_item.texture = icon


func is_eating() -> bool:
	return state == State.USE


# ---------------------------------------------------------------- what is worn

## The weapon in hand: its swing (derived from what is worn) and the attack frames drawn with it.
## A swing under way keeps the damage and knockback it started with.
func set_weapon(attack: AttackData, sheet: Texture2D) -> void:
	_attack.data = attack
	if sheet == null or sheet == _attack_sheet:
		return
	_attack_sheet = sheet
	_set_atlas("attack_", sheet)


## The shield on the off hand (null: none) and the frames of the hero holding it up.
func set_guard(guard: GuardData, sheet: Texture2D) -> void:
	_guard = guard
	if state == State.GUARD and guard == null:
		state = State.MOVE
	if sheet == null or sheet == _guard_sheet:
		return
	_guard_sheet = sheet
	var frames := _sprite.sprite_frames
	var directions := ["down", "up", "left", "right"]
	for i in directions.size():
		var animation := StringName("guard_" + directions[i])
		if frames.has_animation(animation):
			continue
		var frame := AtlasTexture.new()
		frame.region = Rect2(i * 24, 0, 24, 24)
		frames.add_animation(animation)
		frames.set_animation_loop(animation, false)
		frames.add_frame(animation, frame)
	_set_atlas("guard_", sheet)


func guard() -> GuardData:
	return _guard


## Distance, untouchable moment and recovery of a dodge (from the weight carried).
func set_dodge(dodge: HeroLoadout.Dodge) -> void:
	_dodge = dodge


func dodge_profile() -> HeroLoadout.Dodge:
	return _dodge


func _set_atlas(prefix: String, sheet: Texture2D) -> void:
	for direction in ["down", "up", "left", "right"]:
		var animation := StringName(prefix + direction)
		if not _sprite.sprite_frames.has_animation(animation):
			continue
		for i in _sprite.sprite_frames.get_frame_count(animation):
			var frame := _sprite.sprite_frames.get_frame_texture(animation, i) as AtlasTexture
			if frame != null:
				frame.atlas = sheet


func weapon_attack() -> AttackData:
	return _attack.data


func weapon_sheet() -> Texture2D:
	return _attack_sheet


## Top speed and acceleration as fractions of the scene's.
func set_mobility(speed_factor: float, acceleration_factor: float) -> void:
	_speed_factor = speed_factor
	_acceleration_factor = acceleration_factor


func top_speed() -> float:
	return max_speed * _speed_factor


# ---------------------------------------------------------------- being hit

## A shove that costs no health (people carrying a load across a crowded yard): knocked back from
## `source_position` and briefly staggered, without the hurt sound, flash or blinking of a hit.
func bump(source_position: Vector2, strength: float) -> void:
	if state != State.DEAD and not is_untouchable():
		_stagger(Hit.new(0, strength, source_position), hurt_time)


## The hurtbox's guard: a dodge's untouchable moment lets the blow pass; a raised shield facing it
## takes a blockable blow, paying breath, or breaks when the breath runs out.
func _screen_hit(hit: Hit) -> Hit:
	if is_untouchable():
		return null
	if not is_guarding() or not hit.blockable or not covers(hit.source_position):
		return hit
	if stamina.spend(hit.damage * _guard.breath_per_quarter):
		hit.blocked = true
		hit.share = 1.0 - _guard.absorb
		hit.knockback *= 1.0 - _guard.stability
	else:
		hit.guard_broken = true
		stamina.drain()
	return hit


func _on_hit_received(hit: Hit) -> void:
	if state == State.DEAD:
		return
	if hit.blocked:
		_block_sound.play()
		health.grant_invulnerability(BLOCK_IMMUNITY)
		velocity = hit.knockback_velocity(global_position) * (1.0 - clampf(poise_percent, 0.0, 100.0) / 100.0)
		_guard_up = maxf(_guard_up, _guard.raise_time) - BLOCK_RECOIL
		return
	if hit.guard_broken:
		_break_sound.play()
	_hurt_sound.play()
	_hit_flash.flash()
	_held_item.visible = false
	_stagger(hit, GUARD_BREAK_TIME if hit.guard_broken else hurt_time)
	_hit_flash.blink(health.invulnerability_time)


func _stagger(hit: Hit, seconds: float) -> void:
	_attack.cancel()
	_attack_buffered = false
	state = State.HURT
	_hurt_left = seconds
	velocity = hit.knockback_velocity(global_position) * (1.0 - clampf(poise_percent, 0.0, 100.0) / 100.0)
	# Face whoever hit us; the knockback carries the hero backwards, away from them.
	var toward_source := global_position.direction_to(hit.source_position)
	if toward_source != Vector2.ZERO:
		facing = Facing.cardinal(toward_source)
	_sprite.play(StringName("hurt_" + Facing.name_of(facing)))


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_attack.cancel()
	_held_item.visible = false
	_hurtbox.set_deferred(&"monitorable", false)
	_hit_flash.stop_blinking()
	_sprite.play(&"death")
	await _sprite.animation_finished
	await get_tree().create_timer(death_hold_time).timeout
	died.emit()
