class_name IaraWorker
extends Npc
## Iara keeps the rope bridge over the western gorge and makes lamp oil from Cardosa seeds.
## Until the hero has spoken to her she waits by her end of the bridge, looking across; after
## that she walks back to her press and works it, turning the screw a little at a time, as she
## does whenever the hero comes by.

const MET_FLAG := &"far_bank_iara_met"
## Her place at the press, the way there from the bridge (between the lamp post and the fire),
## and how she works it.
const WORK_SPOT := Vector2(156, 132)
const TO_WORK: Array[Vector2] = [Vector2(300, 126), Vector2(214, 126), WORK_SPOT]
const WALK_SPEED := 34.0
const PRESS_EVERY := 0.9

var _route: Array[Vector2] = []
var _work_elapsed := 0.0


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	if adventure.has_flag(MET_FLAG):
		position = WORK_SPOT
		face(Vector2.LEFT)
	adventure.changed.connect(_refresh)
	_refresh()


func is_working() -> bool:
	return _adventure != null and _adventure.has_flag(MET_FLAG) and _route.is_empty() \
			and position == WORK_SPOT


func _refresh() -> void:
	if not _adventure.has_flag(MET_FLAG):
		return
	if position != WORK_SPOT and _route.is_empty():
		_route = TO_WORK.duplicate()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _route.is_empty():
		if walk_towards(_route[0], WALK_SPEED, delta):
			_route.pop_front()
			if _route.is_empty():
				face(Vector2.LEFT)
		return
	_work_elapsed += delta
	gesture(Vector2.LEFT, _work_elapsed, PRESS_EVERY)
