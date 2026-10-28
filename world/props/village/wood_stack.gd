class_name WoodStack
extends Sprite2D
## A small visible change at Cida's stall after she learns the forest route is usable.

const READY_FLAG := &"cida_path_acknowledged"
## Part of the wood went into Anselmo's coop roof: fewer logs, until the wood of Cida's old pen
## comes back to her.
const WOOD_USED_FLAG := &"village_coop_wood_from_cida"
const PEN_CLEARED_FLAG := &"village_pen_cleared"

var _adventure: Adventure


func _ready() -> void:
	add_to_group(&"adventure")
	visible = false


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	# Only on arrival, so the logs never vanish in front of the hero.
	frame = 1 if adventure.has_flag(WOOD_USED_FLAG) and not adventure.has_flag(PEN_CLEARED_FLAG) else 0
	adventure.changed.connect(_show_state)
	_show_state()


func _show_state() -> void:
	visible = _adventure.has_flag(READY_FLAG)
