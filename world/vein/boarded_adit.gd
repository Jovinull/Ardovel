class_name BoardedAdit
extends StaticBody2D
## The old adit into the vein, in Pedrabranca's quarry face, boarded by the crew with a chalk cross.
## Nobody is to open it; once Rufina has said that whoever wants to go down can take the boards off
## (`allowed_by`), the hero does (`flag`) and the way stays open. Frames: 0 boarded, 1 open.

@export var allowed_by: StringName = &"vein_heard"
@export var flag: StringName = &"vein_opened"

var _adventure: Adventure

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Collision
@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	_show_state()


func is_open() -> bool:
	return _adventure != null and _adventure.has_flag(flag)


func _show_state() -> void:
	var open := is_open()
	_sprite.frame = 1 if open else 0
	_shape.set_deferred(&"disabled", open)
	_interactable.enabled = not open


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null or is_open():
		return ""
	if not _adventure.has_flag(allowed_by):
		return "VEIN_ADIT_SEALED"
	_adventure.set_flag(flag)
	_sound.play()
	_show_state()
	return "VEIN_ADIT_OPENED"
