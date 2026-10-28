class_name LiaObserver
extends Npc
## Lia chooses a view of the forest path after Cida can use it again.

const READY_FLAG := &"cida_path_acknowledged"
const ARCH_POSITION := Vector2(274, 96)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	adventure.changed.connect(_show_observation)
	_show_observation()


func _show_observation() -> void:
	if not _adventure.has_flag(READY_FLAG):
		return
	position = ARCH_POSITION
	face(Vector2.UP)
