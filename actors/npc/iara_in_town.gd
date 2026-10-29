class_name IaraInTown
extends Npc
## Iara in Pedrabranca, where she has sold oil for years: by the gate with what is left of her load,
## selling. Once Rufina has called the halt she walks into the yard to face her; once the notice is
## down she goes back to her stall to wait for the council.

const STALL_SPOT := Vector2(392, 236)
const TO_THE_YARD: Array[Vector2] = [Vector2(330, 228), Vector2(256, 226)]
const YARD_SPOT := Vector2(254, 198)
const BACK_TO_THE_STALL: Array[Vector2] = [Vector2(256, 226), Vector2(330, 230)]
const WALK_SPEED := 34.0

var _route: Array[Vector2] = []


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	var in_the_yard := adventure.has_flag(Town.HEARD) and not adventure.has_flag(Town.NOTICE_DOWN)
	position = YARD_SPOT if in_the_yard else STALL_SPOT
	face(Vector2.LEFT)
	adventure.changed.connect(_refresh)
	set_physics_process(true)


func is_at_the_stall() -> bool:
	return position == STALL_SPOT and _route.is_empty()


func is_in_the_yard() -> bool:
	return position == YARD_SPOT and _route.is_empty()


func _refresh() -> void:
	if not _route.is_empty():
		return
	if _adventure.has_flag(Town.NOTICE_DOWN) and position == YARD_SPOT:
		_route = BACK_TO_THE_STALL.duplicate()
		_route.append(STALL_SPOT)
	elif _adventure.has_flag(Town.HEARD) and not _adventure.has_flag(Town.NOTICE_DOWN) and position == STALL_SPOT:
		_route = TO_THE_YARD.duplicate()
		_route.append(YARD_SPOT)


func _physics_process(delta: float) -> void:
	if _route.is_empty():
		return
	if walk_towards(_route[0], WALK_SPEED, delta):
		_route.pop_front()
		if _route.is_empty():
			face(Vector2.LEFT)
