class_name MasterSluice
extends StaticBody2D
## The drain's master sluice, behind the Old Gnawer's den. It turns only once the den no longer
## plugs the drain (`requires`); turned (`flag`), the backed-up water runs out down the old adit for
## good: the pool drains and the new face above dries. Frames: 0 shut, 1 open.

@export var requires: StringName = &"vein_gnawer_defeated"
@export var flag: StringName = &"vein_drain_open"

var _adventure: Adventure

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	_sprite.frame = 1 if adventure.has_flag(flag) else 0


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	if _adventure.has_flag(flag):
		return "VEIN_MASTER_OPEN"
	if not _adventure.has_flag(requires):
		return "VEIN_MASTER_STUCK"
	_adventure.set_flag(flag)
	_sprite.frame = 1
	_sound.play()
	return "VEIN_MASTER_TURNED"
