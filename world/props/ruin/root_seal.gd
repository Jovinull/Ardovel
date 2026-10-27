class_name RootSeal
extends StaticBody2D
## Thick roots grown across a doorway of the ruin. They pull back for good once `open_flag` is
## set, whatever sets it and even in the middle of a visit; a mechanism can also open and
## close them while the flag is not set.

## Adventure flag that keeps these roots open (empty: only mechanisms open them).
@export var open_flag: StringName
@export var starts_open: bool = false

var _open: bool = false
var _adventure: Adventure

@onready var _sprite: AnimatedSprite2D = $Sprite
@onready var _collision: CollisionShape2D = $Collision
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_show(starts_open, false)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_on_adventure_changed)
	if _held_open():
		_show(true, false)


func is_open() -> bool:
	return _open


func open() -> void:
	if not _open:
		_show(true, true)


## Ignored while the flag holds the roots open.
func close() -> void:
	if _open and not _held_open():
		_show(false, true)


func _held_open() -> bool:
	return _adventure != null and not open_flag.is_empty() and _adventure.has_flag(open_flag)


func _on_adventure_changed() -> void:
	if _held_open():
		open()


func _show(value: bool, animate: bool) -> void:
	_open = value
	_collision.set_deferred(&"disabled", value)
	if not animate:
		_sprite.play(&"open" if value else &"closed")
		_sprite.frame = _sprite.sprite_frames.get_frame_count(_sprite.animation) - 1
		return
	_sound.play()
	if value:
		_sprite.play(&"open")
	else:
		_sprite.play_backwards(&"open")
