@tool
class_name RuinGuardian
extends Inscription
## A grey stone guardian in the ruin, the same figure as the village's statue. Some still hold
## their orb: the ruin's light puzzle reads its answer from them, and so does the player, since
## a guardian with empty hands says so when examined.

## Regions of the pack's TilesetHouse.png (grey stone guardian with and without its orb).
const WITH_ORB := Rect2(48, 304, 32, 32)
const WITHOUT_ORB := Rect2(80, 304, 32, 32)

## Said instead of its lines by a guardian whose hands are empty.
const EMPTY_HANDS_TEXT := "STATUE_RUIN_EMPTY"

@export var holds_orb: bool = true:
	set(value):
		holds_orb = value
		if is_node_ready():
			_show()


func _ready() -> void:
	_show()
	super()


func _on_interact(actor: Node2D) -> String:
	return super(actor) if holds_orb else EMPTY_HANDS_TEXT


func _show() -> void:
	($Sprite as Sprite2D).region_rect = WITH_ORB if holds_orb else WITHOUT_ORB
