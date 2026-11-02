class_name Sluice
extends WaterNode
## A sluice of the old vein: a stone housing with a lever that sends the water down one of two ways
## (west or east). Turning it is one interaction; the lever leans to where the water goes and a
## plank closes the other way's mouth, so the state reads at a glance.

const WEST := 0
const EAST := 1

## The way the water goes when the area is entered (as the miners left it).
@export var found_way: int = WEST
## The planks closing each way's mouth (shown on the closed way).
@export var board_west: CanvasItem
@export var board_east: CanvasItem

var way: int = WEST

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	way = found_way
	super._ready()
	_interactable.action = _on_interact
	_show_way()


## Turns the water to the other way.
func turn() -> void:
	way = EAST if way == WEST else WEST
	_show_way()
	_sound.play()
	WaterNode.refresh_all(get_tree())


func _on_interact(_actor: Node2D) -> String:
	turn()
	return ""


func _show_way() -> void:
	_sprite.frame = way
	if board_west != null:
		board_west.visible = way == EAST
	if board_east != null:
		board_east.visible = way == WEST
