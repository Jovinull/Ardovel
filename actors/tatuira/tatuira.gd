class_name Tatuira
extends CharacterBody2D
## A stone-gnawing pill bug of the Hollow Vein, as big as a cat. It crawls about its spot, harmless
## to touch. When the hero stands in line with it (the same row or column, in sight, within reach)
## it curls up (the tell: it pulls in and rocks), then rolls straight and fast; a wall bounces it
## back once, a second wall (or the hero, or a shield) stops it, and it lies on its back with its
## legs kicking: the opening, when blows land double. Curled or rolling it shrugs blows off (clank)
## unless a blow breaks guards, which flips it over at once. Assembles its own parts (CreatureParts).

signal defeated

enum State { IDLE, WANDER, CURL, ROLL, FLIPPED, UNCURL, HURT, DEAD }

const SHEET := preload("res://assets/ardovel/monsters/tatuira.png")
const ACTS := preload("res://assets/ardovel/monsters/tatuira_acts.png")
const POOF := preload("res://fx/smoke_puff.tscn")
const WORLD_LAYER := 1

@export var wander_speed: float = 16.0
@export var wander_radius: float = 28.0
@export var roll_speed: float = 150.0
@export var curl_time: float = 0.55
@export var roll_time: float = 1.4
@export var flipped_time: float = 1.3
@export var uncurl_time: float = 0.3
@export var hurt_time: float = 0.3
## How far off a straight line the hero may stand and still be rolled at.
@export var align_tolerance: float = 7.0
@export var notice_range: float = 128.0
## Fixed seed for reproducible wandering (0 = random).
@export var rng_seed: int = 0

var state: State = State.IDLE
var facing: Vector2 = Vector2.DOWN
var target: Node2D
var home: Vector2
var _left := 0.0
var _bounces := 0
var _goal := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

var health: Health
var _sprite: AnimatedSprite2D
var _hurtbox: Hurtbox
var _roll_hitbox: Hitbox
var _detection: Area2D
var _flash: HitFlash
var _hit_sound: AudioStreamPlayer2D
var _clank_sound: AudioStreamPlayer2D
var _roll_sound: AudioStreamPlayer2D


func _init() -> void:
	collision_layer = 4
	collision_mask = 7
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.offset = Vector2(0, -8)
	var walk := {}
	var columns := {"down": 0, "up": 1, "left": 2, "right": 3}
	for dir: String in columns:
		var c: int = columns[dir]
		walk[StringName("walk_" + dir)] = [[c, c + 4, c + 8, c + 12], 8.0, true]
		walk[StringName("idle_" + dir)] = [[c], 1.0, false]
	_sprite.sprite_frames = CreatureParts.frames(SHEET, Vector2i(16, 16), walk)
	var acts := CreatureParts.frames(ACTS, Vector2i(16, 16), {
		&"curl": [[0, 1], 4.0, false], &"roll": [[2, 3], 12.0, true], &"flipped": [[4, 5], 8.0, true],
		&"death": [[6, 7], 6.0, false]})
	for anim in acts.get_animation_names():
		_sprite.sprite_frames.add_animation(anim)
		_sprite.sprite_frames.set_animation_speed(anim, acts.get_animation_speed(anim))
		_sprite.sprite_frames.set_animation_loop(anim, acts.get_animation_loop(anim))
		for i in acts.get_frame_count(anim):
			_sprite.sprite_frames.add_frame(anim, acts.get_frame_texture(anim, i))
	add_child(_sprite)
	var body := CreatureParts.circle(5.0, Vector2(0, -4))
	body.name = "Collision"
	add_child(body)
	health = CreatureParts.health(self, 3, 0.25)
	_hurtbox = CreatureParts.hurtbox(self, health, CreatureParts.circle(7.0, Vector2(0, -6)))
	_roll_hitbox = CreatureParts.hitbox(self, "RollHitbox", 2, 170.0, true, false,
			CreatureParts.circle(7.0, Vector2(0, -6)))
	_detection = CreatureParts.detection(self, notice_range)
	_flash = CreatureParts.flash(self, _sprite)
	_hit_sound = CreatureParts.sound(self, "HitSound", "Hit & Impact/Hit2.wav")
	_clank_sound = CreatureParts.sound(self, "ClankSound", "Hit & Impact/Impact4.wav", -6.0)
	_roll_sound = CreatureParts.sound(self, "RollSound", "Whoosh & Slash/Whoosh2.wav", -8.0)


func _ready() -> void:
	add_to_group(&"vein_walkers")
	home = global_position
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_hurtbox.guard = _screen_hit
	_hurtbox.hit_received.connect(_on_hit_received)
	_roll_hitbox.landed.connect(_on_roll_landed)
	_detection.body_entered.connect(_on_noticed)
	health.died.connect(_on_died)
	_enter(State.IDLE)


func _on_noticed(body: Node2D) -> void:
	if target == null:
		target = body


func is_shelled() -> bool:
	return state == State.CURL or state == State.ROLL


func is_flipped() -> bool:
	return state == State.FLIPPED


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_left -= delta
	match state:
		State.IDLE, State.WANDER:
			if _should_roll():
				_enter(State.CURL)
				return
			if state == State.IDLE:
				velocity = Vector2.ZERO
				if _left <= 0.0:
					_enter(State.WANDER)
			else:
				var to := _goal - global_position
				if to.length() < 2.0 or _left <= 0.0:
					_enter(State.IDLE)
				else:
					velocity = to.normalized() * wander_speed
					facing = Facing.cardinal(velocity)
					move_and_slide()
					_sprite.play(StringName("walk_" + Facing.name_of(facing)))
		State.CURL:
			if _left <= 0.0:
				_enter(State.ROLL)
		State.ROLL:
			var collision := move_and_collide(velocity * delta)
			if collision != null:
				if collision.get_collider() is Player or _bounces >= 1:
					_enter(State.FLIPPED)
				else:
					_bounces += 1
					velocity = velocity.bounce(collision.get_normal())
					_clank_sound.play()
			elif _left <= 0.0:
				_enter(State.FLIPPED)
		State.FLIPPED:
			if _left <= 0.0:
				_enter(State.UNCURL)
		State.UNCURL, State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			move_and_slide()
			if _left <= 0.0:
				_enter(State.IDLE)


## In line with the hero, in reach, in sight.
func _should_roll() -> bool:
	if not is_instance_valid(target):
		return false
	var target_health := target.get(&"health") as Health
	if target_health != null and target_health.is_dead():
		return false
	var to := target.global_position - global_position
	if to.length() > notice_range:
		return false
	if absf(to.x) > align_tolerance and absf(to.y) > align_tolerance:
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position + Vector2(0, -4),
			target.global_position + Vector2(0, -4), WORLD_LAYER)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _enter(next: State) -> void:
	state = next
	_roll_hitbox.active = next == State.ROLL
	match next:
		State.IDLE:
			_left = _rng.randf_range(0.6, 1.6)
			_sprite.play(StringName("idle_" + Facing.name_of(facing)))
		State.WANDER:
			_left = 3.0
			_goal = home + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(8.0, wander_radius)
		State.CURL:
			velocity = Vector2.ZERO
			facing = Facing.cardinal(target.global_position - global_position)
			_left = curl_time
			_sprite.play(&"curl")
		State.ROLL:
			_bounces = 0
			_left = roll_time
			velocity = facing * roll_speed
			_sprite.play(&"roll")
			_roll_sound.play()
		State.FLIPPED:
			velocity = Vector2.ZERO
			_left = flipped_time
			_sprite.play(&"flipped")
		State.UNCURL:
			_left = uncurl_time
			_sprite.play(&"curl")
		State.HURT:
			_left = hurt_time


## Its shell: curled or rolling, a blow does nothing (it still lands: the hero feels the clank)
## unless it breaks guards, which flips it; on its back, blows land double.
func _screen_hit(hit: Hit) -> Hit:
	if is_shelled():
		if hit.breaking:
			_enter.call_deferred(State.FLIPPED)
			return hit
		hit.blocked = true
		hit.share = 0.0
		return hit
	if is_flipped():
		hit.power *= 2.0
	return hit


func _on_hit_received(hit: Hit) -> void:
	if state == State.DEAD:
		return
	if hit.blocked:
		_clank_sound.play()
		return
	_hit_sound.play()
	_flash.flash()
	if state == State.IDLE or state == State.WANDER:
		velocity = hit.knockback_velocity(global_position) * 0.6
		_enter(State.HURT)


func _on_roll_landed(_hurtbox_hit: Hurtbox) -> void:
	if state == State.ROLL:
		_enter.call_deferred(State.FLIPPED)


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	_roll_hitbox.active = false
	for area: Area2D in [_hurtbox, _roll_hitbox, _detection]:
		area.set_deferred(&"monitorable", false)
		area.set_deferred(&"monitoring", false)
	set_deferred(&"collision_layer", 0)
	defeated.emit()
	_sprite.play(&"death")
	await _sprite.animation_finished
	var poof: Node2D = POOF.instantiate()
	poof.position = position
	get_parent().add_child(poof)
	queue_free()
