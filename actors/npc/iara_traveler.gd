class_name IaraTraveler
extends Npc
## Iara on the road to Pedrabranca, her load on her back. She went ahead and is at the slab bridge,
## where the crew's work ends; once she has said what she makes of it and what she will do, she
## walks on west and is gone (two days to Pedrabranca).

## By the stake at the bridge's west end, looking back east at whoever comes.
const BRIDGE_SPOT := Vector2(118, 104)
## Her way on west: down off the road's middle first, so she goes round whoever she was talking to.
const ON_WEST: Array[Vector2] = [Vector2(118, 120), Vector2(60, 120), Vector2(6, 108)]
const WALK_SPEED := 30.0

var _route: Array[Vector2] = []


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	if adventure.has_flag(Spring.IARA_LEFT) or not adventure.has_flag(Spring.AHEAD):
		queue_free()  # either still on the far bank, or already gone west
		return
	position = BRIDGE_SPOT
	face(Vector2.RIGHT)
	adventure.changed.connect(_refresh)


func is_waiting_at_the_bridge() -> bool:
	return position == BRIDGE_SPOT and _route.is_empty()


func _refresh() -> void:
	if _adventure.has_flag(Spring.IARA_LEFT) and _route.is_empty():
		_route = ON_WEST.duplicate()
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	if _route.is_empty():
		return
	if walk_towards(_route[0], WALK_SPEED, delta):
		_route.pop_front()
		if _route.is_empty():
			queue_free()  # out of sight, on towards Pedrabranca
