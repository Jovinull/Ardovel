class_name DitchDam
extends Node2D
## The pine trunk the storm brought down into the ditch, with the mud and branches piled up
## against its upper end. Hands cannot shift it. Iara's pry bar rolls the trunk a hand's width,
## and then it jams on the branches; those are wrenched out from beside the breach just upstream,
## where the water spills over and the stones start rolling. Then the trunk lies on the bank and
## the water runs on.

@onready var _trunk: Interactable = $Trunk
@onready var _branches: Interactable = $Branches
@onready var _log: Sprite2D = $Log
@onready var _debris: Sprite2D = $Debris
@onready var _aside: Sprite2D = $LogAside
@onready var _sound: AudioStreamPlayer2D = $Sound

## How far the trunk rolls when it is first levered, before it jams.
const LOOSENED_SHIFT := Vector2(3, 2)

var _adventure: Adventure
var _log_rest: Vector2


func _ready() -> void:
	add_to_group(&"adventure")
	_log_rest = _log.position
	_trunk.action = _on_trunk
	_branches.action = _on_branches


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_show)
	_show()


func is_cleared() -> bool:
	return _adventure != null and _adventure.has_flag(RoadWork.DITCH_CLEARED)


func is_loosened() -> bool:
	return _adventure != null and _adventure.has_flag(RoadWork.LOOSENED)


func _on_trunk(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	if is_cleared():
		return "ROAD_DAM_AFTER"
	if not _adventure.has_flag(RoadWork.BAR_LENT):
		return "ROAD_DAM"
	if is_loosened():
		return "ROAD_DAM_JAMMED"
	_adventure.set_flag(RoadWork.LOOSENED)
	return "ROAD_DAM_LOOSENED"


func _on_branches(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	if is_cleared():
		return "ROAD_DAM_AFTER"
	if not _adventure.has_flag(RoadWork.BAR_LENT):
		return "ROAD_DAM"
	if not is_loosened():
		return "ROAD_DEBRIS_PINNED"
	_sound.play()
	_adventure.set_flag(RoadWork.DITCH_CLEARED)
	return "ROAD_DAM_CLEARED"


func _show() -> void:
	var cleared := is_cleared()
	_log.visible = not cleared
	_log.position = _log_rest + (LOOSENED_SHIFT if is_loosened() else Vector2.ZERO)
	_debris.visible = not cleared
	_branches.enabled = not cleared  # gone with the water
	_aside.visible = cleared
