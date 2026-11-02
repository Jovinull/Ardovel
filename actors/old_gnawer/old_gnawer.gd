class_name OldGnawer
extends CharacterBody2D
## The Old Gnawer (a Velha Roedeira), the Hollow Vein's boss: a stone-gnawing isopod as big as a
## cart, her back crusted with white stone. She has dug her den into the drain's mouth.
##
## Her shell takes a third of a blow (half once the crust is gone; a blow that breaks guards goes
## through): she is beaten by catching her dazed, when everything lands. She is dazed when a charge
## ends against a wall or a pillar, when a roll ends, and when she bursts out of the floor. Her
## moves, in a cycle the hero can learn:
## - charge (investida): rears up (mandibles wide, a scrape), then runs at where the hero stood; a
##   shield stops it (a heavy push); a miss ends against the wall, dazed;
## - snap (mordida), when the hero is close: a short tell, then a bite in front; a shield stops it;
## - roll (rolagem): curls up (her plates clatter), rolls at the hero bouncing off the walls, then
##   uncurls dizzy; no shield stops it;
## - tremor: rears and slams the floor; shadows grow on the floor (one under the hero), then stones
##   fall from the roof; no shield stops them;
## - burrow (escavação), only without her crust: digs in, a mound runs at the hero, cracks open under
##   them, she bursts out (no shield stops it) and stays half out, exposed.
## At half health she shakes her crust off (a cry, the crust breaking): faster, burrowing, more
## stones. The old hoist's counterweight dropped on her (`crush`) goes through everything.

signal defeated

enum State { DORMANT, WALK, REAR, CHARGE, SNAP_TELL, SNAP, DAZED, CURL, ROLL, SLAM_TELL, DIG, UNDER,
	ERUPT_TELL, ERUPT, EXPOSED, MOULT, DEAD }
enum Move { CLOSE, ROLL, SLAM, BURROW }

const SHEET := preload("res://assets/ardovel/monsters/old_gnawer.png")
const BARE := preload("res://assets/ardovel/monsters/old_gnawer_bare.png")
const FX := preload("res://assets/ardovel/monsters/gnawer_fx.png")
const FRAME := Vector2i(48, 40)
const CRUSTED_CYCLE: Array[Move] = [Move.CLOSE, Move.CLOSE, Move.ROLL, Move.CLOSE, Move.SLAM]
const BARE_CYCLE: Array[Move] = [Move.CLOSE, Move.BURROW, Move.ROLL, Move.CLOSE, Move.SLAM]
const SHELL_SHARE := 1.0 / 3.0
const BARE_SHARE := 0.5
const WORLD_LAYER := 1

@export var walk_speed: float = 22.0
@export var walk_time: float = 1.0
@export var rear_time: float = 0.7
@export var charge_speed: float = 170.0
@export var charge_time: float = 1.3
@export var snap_range: float = 40.0
@export var snap_tell: float = 0.35
@export var snap_time: float = 0.18
@export var dazed_time: float = 1.8
@export var curl_time: float = 0.8
@export var roll_speed: float = 140.0
@export var roll_bounces: int = 3
@export var roll_dazed_time: float = 1.0
@export var slam_tell: float = 0.6
@export var stones: int = 4
@export var dig_time: float = 0.6
@export var under_speed: float = 70.0
@export var under_time: float = 2.0
@export var erupt_tell: float = 0.6
@export var exposed_time: float = 1.2
@export var moult_time: float = 1.2
## Every timing once the crust is off.
@export var bare_pace: float = 0.75
## The chamber's floor in global coordinates: stones fall and the mound runs only inside it.
@export var arena: Rect2 = Rect2(0, 0, 320, 192)
## Fixed seed for reproducible stones (0 = random).
@export var rng_seed: int = 0

var state: State = State.DORMANT
var target: Node2D
var health: Health
var _left := 0.0
var _turn := 0
var _bounces := 0
var _bare := false
var _spot := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

var _sprite: AnimatedSprite2D
var _body_shape: CollisionShape2D
var _hurtbox: Hurtbox
var _contact: Hitbox
var _charge: Hitbox
var _bite: Hitbox
var _roll: Hitbox
var _erupt: Hitbox
var _flash: HitFlash
var _mound: Sprite2D
var _cracks: Sprite2D
var _sounds := {}


func _init() -> void:
	collision_layer = 4
	collision_mask = 1
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.offset = Vector2(0, -19)
	_sprite.sprite_frames = _frames(SHEET)
	add_child(_sprite)
	_body_shape = CreatureParts.box(Vector2(34, 12), Vector2(0, -6))
	_body_shape.name = "Collision"
	add_child(_body_shape)
	health = CreatureParts.health(self, 18, 0.25)
	_hurtbox = CreatureParts.hurtbox(self, health, CreatureParts.box(Vector2(40, 26), Vector2(0, -14)))
	_contact = CreatureParts.hitbox(self, "ContactHitbox", 1, 150.0, true, true, CreatureParts.box(Vector2(34, 16), Vector2(0, -8)))
	_charge = CreatureParts.hitbox(self, "ChargeHitbox", 3, 240.0, true, false, CreatureParts.box(Vector2(38, 20), Vector2(0, -9)))
	_bite = CreatureParts.hitbox(self, "BiteHitbox", 2, 180.0, true, false, CreatureParts.circle(10.0, Vector2.ZERO))
	_roll = CreatureParts.hitbox(self, "RollHitbox", 3, 220.0, false, false, CreatureParts.circle(14.0, Vector2(0, -10)))
	_erupt = CreatureParts.hitbox(self, "EruptHitbox", 3, 220.0, false, false, CreatureParts.circle(20.0, Vector2(0, -8)))
	_flash = CreatureParts.flash(self, _sprite)
	_mound = _fx_sprite("Mound", 3)
	_cracks = _fx_sprite("Cracks", 5)
	for spec in [["scrape", "Hit & Impact/Impact5.wav"], ["slam", "Elemental/Explosion3.wav"],
			["crash", "Elemental/Explosion4.wav"], ["cry", "Magic & Skill/Strange.wav"],
			["roll", "Whoosh & Slash/Whoosh2.wav"], ["hit", "Hit & Impact/Hit2.wav"],
			["clank", "Hit & Impact/Impact4.wav"], ["dig", "Elemental/Grass2.wav"]]:
		_sounds[spec[0]] = CreatureParts.sound(self, String(spec[0]).capitalize() + "Sound", spec[1], -3.0)


func _ready() -> void:
	add_to_group(&"old_gnawer")
	if rng_seed != 0:
		_rng.seed = rng_seed
	else:
		_rng.randomize()
	_hurtbox.guard = _screen_hit
	_hurtbox.hit_received.connect(_on_hit_received)
	_charge.landed.connect(_on_charge_landed)
	health.died.connect(_on_died)
	_enter(State.DORMANT)


## A charge that met the hero (blocked or not) stops there; only a miss ends against a wall.
func _on_charge_landed(_hurtbox_hit: Hurtbox) -> void:
	if state == State.CHARGE:
		_enter.call_deferred(State.WALK)


## Starts the fight against `hero`.
func wake(hero: Node2D) -> void:
	if state != State.DORMANT:
		return
	target = hero
	_sounds["cry"].play()
	_enter(State.WALK)


func is_bare() -> bool:
	return _bare


func is_dazed() -> bool:
	return state == State.DAZED or state == State.EXPOSED


func is_hidden() -> bool:
	return state == State.UNDER


func _pace() -> float:
	return bare_pace if _bare else 1.0


func _physics_process(delta: float) -> void:
	if state == State.DORMANT or state == State.DEAD:
		return
	_left -= delta
	match state:
		State.WALK:
			if _target_alive():
				var to := target.global_position - global_position
				if to.length() > snap_range * 0.6:
					velocity = to.normalized() * walk_speed / _pace()
					move_and_slide()
			if _left <= 0.0 and _target_alive():
				_next_move()
		State.REAR:
			if _left <= 0.0:
				_enter(State.CHARGE)
		State.CHARGE:
			var hit := move_and_collide(velocity * delta)
			if hit != null:
				if hit.get_collider() is Player:
					_enter(State.WALK)
				else:
					_sounds["crash"].play()
					_enter(State.DAZED)
			elif _left <= 0.0:
				_enter(State.WALK)
		State.SNAP_TELL:
			if _left <= 0.0:
				_enter(State.SNAP)
		State.SNAP:
			if _left <= 0.0:
				_enter(State.WALK)
		State.DAZED, State.EXPOSED, State.MOULT:
			if state == State.MOULT:
				_sprite.offset.x = 1.0 if int(_left * 30.0) % 2 == 0 else -1.0
			if _left <= 0.0:
				if state == State.MOULT:
					_shed()
				_enter(State.WALK)
		State.CURL:
			if _left <= 0.0:
				_enter(State.ROLL)
		State.ROLL:
			var hit := move_and_collide(velocity * delta)
			if hit != null:
				_bounces += 1
				_sounds["clank"].play()
				if _bounces > roll_bounces:
					_enter(State.DAZED)
					_left = roll_dazed_time * _pace()
				else:
					velocity = velocity.bounce(hit.get_normal())
					if _target_alive():
						var aim := global_position.direction_to(target.global_position)
						if aim.dot(hit.get_normal()) > 0.2:
							velocity = aim * roll_speed / _pace()
		State.SLAM_TELL:
			if _left <= 0.0:
				_slam()
				_enter(State.WALK)
		State.DIG:
			if _left <= 0.0:
				_enter(State.UNDER)
		State.UNDER:
			if _target_alive():
				_spot = _spot.move_toward(_clamp_to_arena(target.global_position), under_speed / _pace() * delta)
				_mound.global_position = _spot
				_mound.frame = 3 + int(_left * 8.0) % 2
			if _left <= 0.0 or (_target_alive() and _spot.distance_to(target.global_position) < 6.0):
				_enter(State.ERUPT_TELL)
		State.ERUPT_TELL:
			if _left <= 0.0:
				_enter(State.ERUPT)
		State.ERUPT:
			if _left <= 0.0:
				_enter(State.EXPOSED)


func _next_move() -> void:
	var cycle := BARE_CYCLE if _bare else CRUSTED_CYCLE
	var move: Move = cycle[_turn % cycle.size()]
	_turn += 1
	match move:
		Move.CLOSE:
			if global_position.distance_to(target.global_position) <= snap_range:
				_enter(State.SNAP_TELL)
			else:
				_enter(State.REAR)
		Move.ROLL:
			_enter(State.CURL)
		Move.SLAM:
			_enter(State.SLAM_TELL)
		Move.BURROW:
			_enter(State.DIG)


func _enter(next: State) -> void:
	state = next
	_sprite.offset.x = 0.0
	_contact.active = next in [State.WALK, State.REAR, State.SNAP_TELL, State.SNAP, State.SLAM_TELL, State.CURL]
	_charge.active = next == State.CHARGE
	_bite.active = next == State.SNAP
	_roll.active = next == State.ROLL
	_erupt.active = next == State.ERUPT
	_mound.visible = next == State.UNDER
	_cracks.visible = next == State.ERUPT_TELL
	_sprite.visible = next != State.UNDER and next != State.ERUPT_TELL
	_body_shape.set_deferred(&"disabled", next == State.UNDER or next == State.ERUPT_TELL)
	velocity = Vector2.ZERO
	match next:
		State.DORMANT:
			_sprite.play(&"idle")
		State.WALK:
			_left = walk_time * _pace()
			_sprite.play(&"walk")
		State.REAR:
			_left = rear_time * _pace()
			_sprite.play(&"rear")
			_sounds["scrape"].play()
		State.CHARGE:
			_left = charge_time
			_sprite.play(&"charge")
			if _target_alive():
				velocity = global_position.direction_to(target.global_position) * charge_speed / _pace()
		State.SNAP_TELL:
			_left = snap_tell * _pace()
			_sprite.play(&"rear")
			_aim_bite()
		State.SNAP:
			_left = snap_time
			_sprite.play(&"snap")
			_sounds["scrape"].play()
		State.DAZED:
			_left = dazed_time * _pace()
			_sprite.play(&"dazed")
		State.CURL:
			_left = curl_time * _pace()
			_sprite.play(&"curl")
			_sounds["clank"].play()
		State.ROLL:
			_bounces = 0
			_sprite.play(&"ball")
			_sounds["roll"].play()
			if _target_alive():
				velocity = global_position.direction_to(target.global_position) * roll_speed / _pace()
		State.SLAM_TELL:
			_left = slam_tell * _pace()
			_sprite.play(&"slam")
		State.DIG:
			_left = dig_time * _pace()
			_sprite.play(&"dig")
			_sounds["dig"].play()
		State.UNDER:
			_left = under_time
			_spot = global_position
			_mound.global_position = _spot
		State.ERUPT_TELL:
			_left = erupt_tell * _pace()
			_spot = _free_spot(_spot)
			_cracks.global_position = _spot
			_sounds["dig"].play()
		State.ERUPT:
			_left = 0.15
			global_position = _spot
			_sprite.play(&"emerge")
			_sounds["crash"].play()
		State.EXPOSED:
			_left = exposed_time
			_sprite.play(&"dazed")
		State.MOULT:
			_left = moult_time
			_sprite.play(&"dazed")
			_sounds["cry"].play()


func _aim_bite() -> void:
	var dir := Vector2.DOWN
	if _target_alive():
		dir = global_position.direction_to(target.global_position)
	_bite.position = dir * 22.0 + Vector2(0, -6)


## The tremor: stones fall where the hero stands and, apart from it and each other, about the chamber.
func _slam() -> void:
	_sounds["slam"].play()
	var spots: Array[Vector2] = []
	if _target_alive():
		spots.append(_clamp_to_arena(target.global_position))
	var wanted := stones + (2 if _bare else 0)
	var tries := 0
	while spots.size() < wanted and tries < 60:
		tries += 1
		var p := Vector2(_rng.randf_range(arena.position.x + 12, arena.end.x - 12),
				_rng.randf_range(arena.position.y + 16, arena.end.y - 8))
		if spots.all(func(s: Vector2) -> bool: return s.distance_to(p) >= 28.0) and _is_floor(p):
			spots.append(p)
	for p in spots:
		var stone := FallingStone.new()
		stone.position = p
		get_parent().add_child(stone)


func _clamp_to_arena(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, arena.position.x + 12, arena.end.x - 12),
			clampf(p.y, arena.position.y + 16, arena.end.y - 6))


func _is_floor(p: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = p
	query.collision_mask = WORLD_LAYER
	return get_world_2d().direct_space_state.intersect_point(query, 1).is_empty()


## Where she can burst out: `p`, or the nearest spot towards the chamber's middle with room for her.
func _free_spot(p: Vector2) -> Vector2:
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = _body_shape.shape
	query.collision_mask = WORLD_LAYER
	query.exclude = [get_rid()]
	var at := _clamp_to_arena(p)
	for i in 12:
		query.transform = Transform2D(0.0, at + _body_shape.position)
		if get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
			return at
		at = at.move_toward(arena.get_center(), 10.0)
	return arena.get_center()


func _target_alive() -> bool:
	if not is_instance_valid(target):
		return false
	var h := target.get(&"health") as Health
	return h == null or not h.is_dead()


## Her shell: nothing gets through while she is curled, rolling, shaking her crust off or under the
## floor; everything while she is dazed; otherwise a third (half once bare), unless it breaks guards.
func _screen_hit(hit: Hit) -> Hit:
	match state:
		State.DORMANT, State.UNDER, State.ERUPT_TELL, State.DEAD:
			return null
		State.CURL, State.ROLL, State.MOULT:
			hit.blocked = true
			hit.share = 0.0
			return hit
		State.DAZED, State.EXPOSED:
			return hit
	if hit.breaking:
		return hit
	hit.blocked = true
	hit.share = BARE_SHARE if _bare else SHELL_SHARE
	return hit


func _on_hit_received(hit: Hit) -> void:
	if state == State.DEAD:
		return
	if hit.blocked:
		_sounds["clank"].play()
		if hit.share > 0.0:
			_flash.flash()
	else:
		_sounds["hit"].play()
		_flash.flash()
	_check_moult()


## The hoist's counterweight dropped on her: a blow through everything, and she is dazed.
func crush(amount: int) -> void:
	if state in [State.DORMANT, State.UNDER, State.ERUPT_TELL, State.DEAD]:
		return
	_sounds["crash"].play()
	_flash.flash()
	health.take_hit(amount, 1)
	if health.is_dead():
		return
	if not _check_moult():
		_enter(State.DAZED)
		_left = dazed_time * 1.2


func _check_moult() -> bool:
	if _bare or health.is_dead() or health.current * 2 > health.max_health or state == State.MOULT:
		return false
	_enter(State.MOULT)
	return true


func _shed() -> void:
	_bare = true
	var anim := _sprite.animation
	_sprite.sprite_frames = _frames(BARE)
	_sprite.play(anim)
	for i in 4:
		var dust := _fx_sprite("Crust%d" % i, 6 + i % 2)
		remove_child(dust)
		dust.visible = true
		dust.global_position = global_position + Vector2(-18 + i * 12, -10 - (i % 2) * 8)
		get_parent().add_child(dust)
		get_tree().create_timer(0.6, false).timeout.connect(dust.queue_free)


func _on_died() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	for hitbox: Hitbox in [_contact, _charge, _bite, _roll, _erupt]:
		hitbox.active = false
	_hurtbox.set_deferred(&"monitorable", false)
	set_deferred(&"collision_layer", 0)
	_mound.visible = false
	_cracks.visible = false
	_sprite.visible = true
	_sounds["cry"].play()
	_sprite.play(&"death")
	await _sprite.animation_finished
	await get_tree().create_timer(0.5, false).timeout
	defeated.emit()


func _fx_sprite(node_name: String, frame: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = FX
	s.hframes = FX.get_width() / 16
	s.frame = frame
	s.offset = Vector2(0, -6)
	s.visible = false
	s.top_level = true
	add_child(s)
	return s


static func _frames(sheet: Texture2D) -> SpriteFrames:
	return CreatureParts.frames(sheet, FRAME, {
		&"idle": [[0, 1], 2.0, true], &"walk": [[2, 3], 5.0, true], &"rear": [[4], 1.0, false],
		&"charge": [[5, 6], 10.0, true], &"snap": [[7], 1.0, false], &"dazed": [[8, 9], 3.0, true],
		&"curl": [[10], 1.0, false], &"ball": [[11, 12], 10.0, true], &"slam": [[13], 1.0, false],
		&"dig": [[14, 15], 4.0, false], &"emerge": [[16], 1.0, false],
		&"death": [[17, 18, 19, 20], 4.0, false]})
