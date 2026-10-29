class_name IaraWorker
extends Npc
## Iara keeps the rope bridge over the western gorge and makes lamp oil from Cardosa seeds.
## Until the hero has spoken to her she waits by her end of the bridge, looking across; after
## that she walks back to her press and works it, turning the screw a little at a time. Once the
## hero has gone off after meeting her, she sets to the rockfall on the road instead, prying at
## it with her bar (lying beside her whenever she is not lending it), and keeps at it from then
## on; while the hero is away after the ditch is cleared, she stacks the smaller stones aside and
## gets ready to walk her oil to Pedrabranca: she crouches by the big stone
## with a wedge and counts for whoever bears down on the crew's bar (BigStone); the morning after
## it is walked aside she waits by the gap with her load on her back, and once she has said so she
## goes on ahead down the road and is no longer on this bank.

const MET_FLAG := &"far_bank_iara_met"
## Her place at the press, the way there from the bridge (between the lamp post and the fire),
## and how she works it.
const WORK_SPOT := Vector2(156, 132)
const TO_WORK: Array[Vector2] = [Vector2(300, 126), Vector2(214, 126), WORK_SPOT]
## Her place by the rockfall, prying at it.
const ROAD_SPOT := Vector2(104, 208)
## Crouched at the big stone's foot with a wedge, beside the bar's foot.
const STONE_SPOT := Vector2(60, 238)
## The morning after: by the gap the stone left, and the way she goes through it.
const GAP_SPOT := Vector2(44, 190)
const THROUGH_THE_GAP: Array[Vector2] = [Vector2(20, 190), Vector2(6, 190)]
const WALK_SPEED := 34.0
const PRESS_EVERY := 0.9
## Trips that are not time away: up to the slope above the camp, onto the road past the stone,
## and the night after the stone (a trip to this same bank).
const NOT_AWAY: Array[StringName] = [&"road_slope", &"road_west", &"far_bank"]
const EMOTES := {
	&"wait": preload("res://assets/ninja_adventure/Ui/Emote/emote20.png"),
	&"now": preload("res://assets/ninja_adventure/Ui/Emote/emote21.png"),
	&"frown": preload("res://assets/ninja_adventure/Ui/Emote/emote14.png"),
}

var _route: Array[Vector2] = []
var _work_elapsed := 0.0
var _leaving := false


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	if adventure.has_flag(Spring.AHEAD) or adventure.has_flag(Spring.IARA_LEFT):
		queue_free()  # gone on down the road
		return
	if adventure.has_flag(MET_FLAG):
		if adventure.has_flag(Spring.SHIFTED):
			position = GAP_SPOT
			face(Vector2.RIGHT)
		elif adventure.has_flag(Spring.READY):
			position = STONE_SPOT
			face(Vector2.LEFT)
		else:
			position = ROAD_SPOT if adventure.has_flag(RoadWork.STARTED) else WORK_SPOT
			face(Vector2.LEFT)
	adventure.changed.connect(_refresh)
	_refresh()
	var level := owner as Level
	if level != null:
		level.exit_requested.connect(_on_hero_leaves)


func is_working() -> bool:
	return _adventure != null and _adventure.has_flag(MET_FLAG) and _route.is_empty() \
			and position in [WORK_SPOT, ROAD_SPOT, STONE_SPOT]


func is_at_the_rockfall() -> bool:
	return position == ROAD_SPOT


func is_at_the_stone() -> bool:
	return position == STONE_SPOT


func is_waiting_by_the_gap() -> bool:
	return position == GAP_SPOT and not _leaving


## Over her head while she counts for the bar: "..." counting, "!" now, a flat look if the bar
## slipped; nothing otherwise.
func show_emote(kind: StringName) -> void:
	var emote := get_node_or_null(^"Emote") as Sprite2D
	if emote == null:
		return
	emote.texture = EMOTES.get(kind)
	emote.visible = emote.texture != null


func current_emote() -> StringName:
	var emote := get_node_or_null(^"Emote") as Sprite2D
	if emote == null or not emote.visible:
		return &""
	return EMOTES.find_key(emote.texture)


## Time passes while the hero is away: after meeting her she turns to the road; once the ditch
## runs again, a single absence is enough for her to get the smaller stones out of the way and get
## ready to go (asking for one absence each made the hero come and go for nothing). A save from
## between the two (stones stacked, not yet ready) catches up on the next absence.
func _on_hero_leaves(area: StringName, _entry: StringName) -> void:
	if not _adventure.has_flag(MET_FLAG) or area in NOT_AWAY:
		return
	if not _adventure.has_flag(RoadWork.STARTED):
		_adventure.set_flag(RoadWork.STARTED)
	elif _adventure.has_flag(RoadWork.DITCH_CLEARED):
		_adventure.set_flag(RoadWork.PROGRESSED)
		_adventure.set_flag(Spring.READY)


func _refresh() -> void:
	var bar := get_node_or_null(^"PryBar") as CanvasItem
	if bar != null:
		bar.visible = _adventure.has_flag(RoadWork.STARTED) and position == ROAD_SPOT \
				and (not _adventure.has_flag(RoadWork.BAR_LENT) or _adventure.has_flag(RoadWork.HEARD))
	var load := get_node_or_null(^"Load") as CanvasItem
	if load != null:
		load.visible = _adventure.has_flag(Spring.SHIFTED)
	if not _adventure.has_flag(MET_FLAG):
		return
	if _adventure.has_flag(Spring.AHEAD) and not _leaving:
		_leaving = true
		_route = THROUGH_THE_GAP.duplicate()
	elif position not in [WORK_SPOT, ROAD_SPOT, STONE_SPOT, GAP_SPOT] and _route.is_empty() and not _leaving:
		_route = TO_WORK.duplicate()
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _route.is_empty():
		if walk_towards(_route[0], WALK_SPEED, delta):
			_route.pop_front()
			if _route.is_empty():
				if _leaving:
					queue_free()  # through the gap and on down the road
					return
				face(Vector2.LEFT)
		return
	if position == GAP_SPOT:
		return  # waiting for the hero, load on her back
	_work_elapsed += delta
	gesture(Vector2.LEFT, _work_elapsed, PRESS_EVERY)
