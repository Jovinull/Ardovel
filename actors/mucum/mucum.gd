class_name Mucum
extends Node2D
## A blind cave eel of the Hollow Vein. It lives in one channel (or the pool) and never leaves it;
## under water only its rings show where it is, and nothing can touch it. It follows the hero along
## the channel; when the hero walks along its bank it surfaces at the nearest point (the tell:
## bubbles, the head rising), snaps across the bank (a bite a shield can stop), stays up a moment
## (the opening) and dives. If its channel runs dry it is stranded: it flops on the mud, bites only
## what touches it, and cannot hide. If its water is drained for good (the pool after the drain) it
## slips away down the drain and is gone. Assembles its own parts (CreatureParts).

signal defeated

enum State { UNDER, RISE, BITE, UP, DIVE, STRANDED, DEAD }

const SHEET := preload("res://assets/ardovel/monsters/mucum.png")
const POOF := preload("res://fx/smoke_puff.tscn")

@export var channel: WaterChannel
@export var swim_speed: float = 36.0
## How close the hero must be to surface at them.
@export var strike_range: float = 40.0
@export var rise_time: float = 0.5
@export var bite_time: float = 0.2
@export var up_time: float = 0.7
@export var dive_time: float = 0.3
@export var rest_time: float = 0.9
## How far from the eel the bite lands (across the bank).
@export var bite_reach: float = 22.0

var state: State = State.UNDER
var facing := Vector2.DOWN
var target: Node2D
var _left := 0.0
var _rest := 0.0

var health: Health
var _sprite: AnimatedSprite2D
var _hurtbox: Hurtbox
var _bite: Hitbox
var _touch: Hitbox
var _flash: HitFlash
var _splash: AudioStreamPlayer2D
var _hit_sound: AudioStreamPlayer2D


func _init() -> void:
	_sprite = AnimatedSprite2D.new()
	_sprite.name = "Sprite"
	_sprite.offset = Vector2(0, -5)
	_sprite.sprite_frames = CreatureParts.frames(SHEET, Vector2i(16, 16), {
		&"under": [[0, 1], 3.0, true], &"rise_down": [[2], 1.0, false], &"bite_down": [[3], 1.0, false],
		&"rise_side": [[4], 1.0, false], &"bite_side": [[5], 1.0, false], &"rise_up": [[6], 1.0, false],
		&"bite_up": [[7], 1.0, false], &"flop": [[8, 9], 5.0, true], &"dead": [[10], 1.0, false]})
	add_child(_sprite)
	health = CreatureParts.health(self, 3, 0.25)
	_hurtbox = CreatureParts.hurtbox(self, health, CreatureParts.circle(6.0, Vector2(0, -6)))
	_bite = CreatureParts.hitbox(self, "BiteHitbox", 2, 140.0, true, false, CreatureParts.circle(9.0, Vector2.ZERO))
	_touch = CreatureParts.hitbox(self, "TouchHitbox", 1, 90.0, true, true, CreatureParts.circle(6.0, Vector2(0, -3)))
	_flash = CreatureParts.flash(self, _sprite)
	_splash = CreatureParts.sound(self, "Splash", "Elemental/Bubble.wav", -6.0)
	_hit_sound = CreatureParts.sound(self, "HitSound", "Hit & Impact/Hit2.wav")


func _ready() -> void:
	add_to_group(&"adventure")
	_hurtbox.hit_received.connect(_on_hit_received)
	health.died.connect(_on_died)
	if channel != null:
		channel.wetness_changed.connect(_on_water_changed)
	_set_exposed(false)
	_sprite.play(&"under")


func bind_adventure(adventure: Adventure) -> void:
	if channel != null and not channel.dries_with.is_empty() and adventure.has_flag(channel.dries_with):
		queue_free()  # its water drained for good: it went down the drain


func is_exposed() -> bool:
	return state in [State.RISE, State.BITE, State.UP, State.STRANDED]


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if channel != null and state != State.STRANDED and not channel.is_wet():
		_strand()
		return
	_left -= delta
	_rest -= delta
	match state:
		State.UNDER:
			_find_target()
			if target == null:
				return
			var spot := channel.nearest_on_line(target.global_position) if channel != null else global_position
			global_position = global_position.move_toward(spot, swim_speed * delta)
			if _rest <= 0.0 and global_position.distance_to(target.global_position) <= strike_range \
					and global_position.distance_to(spot) < 3.0:
				_enter(State.RISE)
		State.RISE:
			if _left <= 0.0:
				_enter(State.BITE)
		State.BITE:
			if _left <= 0.0:
				_enter(State.UP)
		State.UP:
			if _left <= 0.0:
				_enter(State.DIVE)
		State.DIVE:
			if _left <= 0.0:
				_enter(State.UNDER)


func _find_target() -> void:
	if is_instance_valid(target):
		var h := target.get(&"health") as Health
		if h == null or not h.is_dead():
			return
		target = null
		return
	var level := Level.containing(self)
	if level != null and level.player != null and not level.player.health.is_dead():
		target = level.player


func _enter(next: State) -> void:
	state = next
	_bite.active = next == State.BITE
	match next:
		State.UNDER:
			_set_exposed(false)
			_sprite.play(&"under")
		State.RISE:
			_left = rise_time
			facing = Facing.cardinal(target.global_position - global_position)
			_set_exposed(true)
			_play(&"rise_")
			_splash.play()
		State.BITE:
			_left = bite_time
			_bite.position = facing * bite_reach + Vector2(0, -4)
			_play(&"bite_")
		State.UP:
			_left = up_time
			_play(&"rise_")
		State.DIVE:
			_left = dive_time
			_rest = rest_time
			_set_exposed(false)
			_sprite.play(&"under")
			_splash.play()


## Rising, it is always drawn in profile, its hooked head turned to the hero's side (seen from the
## front or behind, a rising eel read as a mushroom or a finger); it bites from the front only when
## the hero is below it.
func _play(prefix: StringName) -> void:
	var toward := target.global_position.x - global_position.x if is_instance_valid(target) else 1.0
	_sprite.flip_h = toward < 0.0
	if prefix == &"bite_" and facing == Vector2.DOWN:
		_sprite.flip_h = false
		_sprite.play(&"bite_down")
		return
	_sprite.play(StringName(String(prefix) + "side"))


func _set_exposed(exposed: bool) -> void:
	_hurtbox.set_deferred(&"monitorable", exposed)


func _strand() -> void:
	state = State.STRANDED
	_bite.active = false
	_touch.active = true
	_set_exposed(true)
	_sprite.flip_h = false
	_sprite.play(&"flop")


func _on_water_changed(wet: bool) -> void:
	if state == State.DEAD:
		return
	if wet and state == State.STRANDED:
		_touch.active = false
		_enter(State.UNDER)
	elif not wet and not channel.dries_with.is_empty():
		queue_free.call_deferred()  # drained for good: down the drain with the water


func _on_hit_received(_hit: Hit) -> void:
	if state == State.DEAD:
		return
	_hit_sound.play()
	_flash.flash()
	if state == State.RISE or state == State.BITE:
		_enter(State.UP)  # struck before it bites: it stays up, stunned, a moment


func _on_died() -> void:
	state = State.DEAD
	_bite.active = false
	_touch.active = false
	for area: Area2D in [_hurtbox, _bite, _touch]:
		area.set_deferred(&"monitorable", false)
		area.set_deferred(&"monitoring", false)
	defeated.emit()
	_sprite.flip_h = false
	_sprite.play(&"dead")
	await get_tree().create_timer(0.6, false).timeout
	var poof: Node2D = POOF.instantiate()
	poof.position = position
	get_parent().add_child(poof)
	queue_free()
