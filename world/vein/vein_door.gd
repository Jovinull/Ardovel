class_name VeinDoor
extends StaticBody2D
## The drain chamber's heavy door: open, it can be shut behind the hero (a boss fight's seal) and
## opened again. Frames: 0 shut, 1 open.

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Collision
@onready var _sound: AudioStreamPlayer2D = $Sound

var _open := true


func _ready() -> void:
	_show_state()


func is_open() -> bool:
	return _open


func open() -> void:
	if not _open:
		_open = true
		_sound.play()
		_show_state()


func close() -> void:
	if _open:
		_open = false
		_sound.play()
		_show_state()


func _show_state() -> void:
	_sprite.frame = 1 if _open else 0
	_shape.set_deferred(&"disabled", _open)
