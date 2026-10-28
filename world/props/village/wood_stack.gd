class_name WoodStack
extends Sprite2D
## A small visible change at Cida's stall after she learns the forest route is usable.

const READY_FLAG := &"cida_path_acknowledged"

var _adventure: Adventure


func _ready() -> void:
	add_to_group(&"adventure")
	visible = false


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_show_state)
	_show_state()


func _show_state() -> void:
	visible = _adventure.has_flag(READY_FLAG)
