class_name FallingStone
extends Node2D
## A stone shaken from the drain chamber's roof by the Old Gnawer's tremor: its shadow grows on the
## floor for `warning` seconds (where to step away from), then it falls and bursts. No shield stops
## a stone from above. Assembles its own parts.

const FX := preload("res://assets/ardovel/monsters/gnawer_fx.png")
const FALL := 0.15
const HEIGHT := 96.0

@export var warning: float = 0.9
@export var damage: int = 2

var _left := 0.0
var _shadow: Sprite2D
var _stone: Sprite2D
var _hitbox: Hitbox
var _sound: AudioStreamPlayer2D


func _init() -> void:
	_shadow = _sprite("Shadow", 0)
	_stone = _sprite("Stone", 2)
	_stone.visible = false
	_hitbox = CreatureParts.hitbox(self, "Hitbox", damage, 120.0, false, false, CreatureParts.circle(8.0, Vector2(0, -3)))
	_sound = CreatureParts.sound(self, "Sound", "Hit & Impact/Impact.wav", -6.0)


func _ready() -> void:
	_left = warning + FALL


func is_falling() -> bool:
	return _left > 0.0


func _physics_process(delta: float) -> void:
	_left -= delta
	if _left > FALL:
		_shadow.frame = 0 if _left > FALL + warning * 0.5 else 1
		return
	if _left > 0.0:
		_stone.visible = true
		_stone.position.y = -HEIGHT * (_left / FALL)
		return
	if not _hitbox.active and _stone.visible:
		_stone.position.y = 0.0
		_shadow.visible = false
		_hitbox.active = true
		_sound.play()
		return
	_hitbox.active = false
	_stone.visible = false
	set_physics_process(false)
	_shadow.frame = 6
	_shadow.visible = true
	get_tree().create_timer(0.4, false).timeout.connect(queue_free)


func _sprite(node_name: String, frame: int) -> Sprite2D:
	var s := Sprite2D.new()
	s.name = node_name
	s.texture = FX
	s.hframes = FX.get_width() / 16
	s.frame = frame
	s.offset = Vector2(0, -6)
	add_child(s)
	return s
