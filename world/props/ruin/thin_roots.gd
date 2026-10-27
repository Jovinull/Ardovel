class_name ThinRoots
extends StaticBody2D
## A curtain of thin roots over a gap in the wall. One sword strike cuts it, for good: the lower
## parts drop away and the stubs stay where they hung.

## Adventure flag recording that these roots were cut.
@export var flag: StringName

var _adventure: Adventure

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _collision: CollisionShape2D = $Collision
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_hurtbox.hit_received.connect(_on_hit_received)
	_sprite.play(&"hanging")


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if is_cut():
		_open_way()
		_sprite.play(&"cut")
		_sprite.frame = _sprite.sprite_frames.get_frame_count(&"cut") - 1


func is_cut() -> bool:
	return _adventure != null and _adventure.has_flag(flag)


func _on_hit_received(_hit: Hit) -> void:
	if is_cut():
		return
	if _adventure != null:
		_adventure.set_flag(flag)
	_open_way()
	_sound.play()
	_sprite.play(&"cut")


func _open_way() -> void:
	_hurtbox.set_deferred(&"monitorable", false)
	_collision.set_deferred(&"disabled", true)
