class_name IaraWorker
extends Npc
## Iara keeps the rope bridge over the western gorge and makes lamp oil from Cardosa seeds.
## Until the hero has spoken to her she waits by her end of the bridge, looking across; after
## that she walks back to her press and works it, turning the screw a little at a time. Once the
## hero has gone off after meeting her, she sets to the rockfall on the road instead, prying at
## it with her bar (lying beside her whenever she is not lending it), and keeps at it from then
## on; while the hero is away after the ditch is cleared, she stacks the smaller stones aside.

const MET_FLAG := &"far_bank_iara_met"
## Her place at the press, the way there from the bridge (between the lamp post and the fire),
## and how she works it.
const WORK_SPOT := Vector2(156, 132)
const TO_WORK: Array[Vector2] = [Vector2(300, 126), Vector2(214, 126), WORK_SPOT]
## Her place by the rockfall, prying at it.
const ROAD_SPOT := Vector2(104, 208)
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
		position = ROAD_SPOT if adventure.has_flag(RoadWork.STARTED) else WORK_SPOT
		face(Vector2.LEFT)
	adventure.changed.connect(_refresh)
	_refresh()
	var level := owner as Level
	if level != null:
		level.exit_requested.connect(_on_hero_leaves)


func is_working() -> bool:
	return _adventure != null and _adventure.has_flag(MET_FLAG) and _route.is_empty() \
			and position in [WORK_SPOT, ROAD_SPOT]


func is_at_the_rockfall() -> bool:
	return position == ROAD_SPOT


## Time passes while the hero is away: after meeting her she turns to the road, and once the
## ditch runs again she gets the smaller stones out of the way.
func _on_hero_leaves(area: StringName, _entry: StringName) -> void:
	# Going up to the slope above is not being away: the camp is right below it.
	if not _adventure.has_flag(MET_FLAG) or area == &"road_slope":
		return
	if not _adventure.has_flag(RoadWork.STARTED):
		_adventure.set_flag(RoadWork.STARTED)
	elif _adventure.has_flag(RoadWork.DITCH_CLEARED):
		_adventure.set_flag(RoadWork.PROGRESSED)


func _refresh() -> void:
	var bar := get_node_or_null(^"PryBar") as CanvasItem
	if bar != null:
		bar.visible = _adventure.has_flag(RoadWork.STARTED) and position == ROAD_SPOT \
				and (not _adventure.has_flag(RoadWork.BAR_LENT) or _adventure.has_flag(RoadWork.HEARD))
	if not _adventure.has_flag(MET_FLAG):
		return
	if position != WORK_SPOT and position != ROAD_SPOT and _route.is_empty():
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
