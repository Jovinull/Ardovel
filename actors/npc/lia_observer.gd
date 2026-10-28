class_name LiaObserver
extends Npc
## Lia chooses a view of the forest path once the second glint has been seen there and Cida
## uses the path again, in whichever order those happen.

const READY_FLAG := &"cida_path_acknowledged"
const FOUND_FLAG := &"forest_echo_found"
const ARCH_POSITION := Vector2(274, 96)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	adventure.changed.connect(_show_observation)
	_show_observation()


func _show_observation() -> void:
	if not (_adventure.has_flag(READY_FLAG) and _adventure.has_flag(FOUND_FLAG)):
		return
	position = ARCH_POSITION
	face(Vector2.UP)
