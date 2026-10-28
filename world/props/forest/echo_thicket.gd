class_name EchoThicket
extends StaticBody2D
## A living tangle that yields to a sword only after the ruin's heart responds.

const HEART_FLAG := &"ruin_heart_awakened"
const CUT_FLAG := &"forest_echo_thicket_cut"

var _adventure: Adventure

@onready var _sprite: Sprite2D = $Sprite
@onready var _collision: CollisionShape2D = $Collision
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_hurtbox.hit_received.connect(_on_hit)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_show_state)
	_show_state()


func _show_state() -> void:
	_show_cut(_adventure.has_flag(CUT_FLAG))


func is_cut() -> bool:
	return _adventure != null and _adventure.has_flag(CUT_FLAG)


func _on_hit(_hit: Hit) -> void:
	if _adventure == null or not _adventure.has_flag(HEART_FLAG) or is_cut():
		return
	_adventure.set_flag(CUT_FLAG)
	_show_cut(true)
	_sound.play()


func _show_cut(cut: bool) -> void:
	var frame := 2 if cut else 1 if _adventure.has_flag(HEART_FLAG) else 0
	_sprite.region_rect = Rect2(frame * 32, 0, 32, 16)
	_collision.set_deferred(&"disabled", cut)
	_hurtbox.set_deferred(&"monitorable", not cut and _adventure.has_flag(HEART_FLAG))
