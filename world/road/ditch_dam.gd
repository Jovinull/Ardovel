class_name DitchDam
extends Node2D
## The pine trunk the storm brought down into the ditch, with the mud and branches piled up
## against it. Hands cannot shift it; Iara's pry bar can, and then the trunk lies on the bank and
## the water runs on.

@onready var _interactable: Interactable = $Interactable
@onready var _log: Sprite2D = $Log
@onready var _debris: Sprite2D = $Debris
@onready var _aside: Sprite2D = $LogAside
@onready var _sound: AudioStreamPlayer2D = $Sound

var _adventure: Adventure


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_show)
	_show()


func is_cleared() -> bool:
	return _adventure != null and _adventure.has_flag(RoadWork.DITCH_CLEARED)


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	if is_cleared():
		return "ROAD_DAM_AFTER"
	if not _adventure.has_flag(RoadWork.BAR_LENT):
		return "ROAD_DAM"
	_sound.play()
	_adventure.set_flag(RoadWork.DITCH_CLEARED)
	return "ROAD_DAM_CLEARED"


func _show() -> void:
	var cleared := is_cleared()
	_log.visible = not cleared
	_debris.visible = not cleared
	_aside.visible = cleared
