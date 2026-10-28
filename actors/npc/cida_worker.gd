class_name CidaWorker
extends Npc
## Cida takes a short step toward her stall and sorts the wood after the path opens.
## While her hens run loose under the village light she is out in the square after them; once
## Anselmo's old coop is mended she walks to its gate and scatters grain while the hero
## drives the hens in.

const READY_FLAG := &"cida_path_acknowledged"
const WORKED_FLAG := &"cida_stall_worked"
const WORK_OFFSET := Vector2(14, 8)
const WALK_SPEED := 28.0
const SORT_TIME := 0.75
## Where she stands while the hens are loose, and her way from there to the coop gate.
const SQUARE_SPOT := Vector2(208, 234)
const COOP_ROUTE: Array[Vector2] = [Vector2(172, 206), Vector2(172, 124), Vector2(60, 124),
		Vector2(60, 112)]
const ROUTE_SPEED := 40.0

var _home: Vector2
var _sorting := false
var _sort_elapsed := 0.0
var _started := false
var _yard: HenYard
var _route: Array[Vector2] = []
var _calling := false
var _call_elapsed := 0.0
var _look_elapsed := 0.0


func _ready() -> void:
	super._ready()
	_home = position
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	_yard = get_parent().get_node_or_null(^"HenYard") as HenYard
	if _yard != null and _yard.hens_loose():
		position = SQUARE_SPOT
	elif _yard != null and _yard.calling():
		_start_calling()
	adventure.changed.connect(_refresh_work)
	_refresh_work()


## True while she is busy with the hens, which comes before her stall.
func is_with_hens() -> bool:
	return _yard != null and (_yard.hens_loose() or _yard.calling() or _calling)


func _refresh_work() -> void:
	if is_with_hens():
		# The coop was just mended while she waited in the square: off she goes.
		if _yard.calling() and not _calling and _route.is_empty() and position == SQUARE_SPOT:
			_route = COOP_ROUTE.duplicate()
		set_physics_process(true)
		return
	if _adventure.has_flag(WORKED_FLAG):
		position = _home + WORK_OFFSET
		face(Vector2.RIGHT)
		set_physics_process(false)
	elif _adventure.has_flag(READY_FLAG):
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	if is_with_hens():
		_tend_hens(delta)
		return
	if not _started:
		var player := get_parent().get_node_or_null(^"Player") as Player
		if player == null or global_position.distance_to(player.global_position) > 80.0:
			return
		_started = true
	if not _sorting:
		if walk_towards(_home + WORK_OFFSET, WALK_SPEED, delta):
			_sorting = true
			_sort_elapsed = 0.0
	else:
		_sort_elapsed += delta
		gesture(Vector2.RIGHT, _sort_elapsed)
		if _sort_elapsed >= SORT_TIME:
			face(Vector2.RIGHT)
			_adventure.set_flag(WORKED_FLAG)


func _tend_hens(delta: float) -> void:
	if not _route.is_empty():
		# Anselmo comes back along the same narrow way: she lets him through first.
		var anselmo := get_parent().get_node_or_null(^"Anselmo") as AnselmoHelper
		if anselmo != null and anselmo.is_working():
			return
		if walk_towards(_route[0], ROUTE_SPEED, delta):
			_route.pop_front()
			if _route.is_empty():
				_start_calling()
		return
	if _calling:
		if _yard.settled():
			# The hens are in: she watches them, and goes back to her stall another day.
			face(Vector2.UP)
			set_physics_process(false)
			return
		_call_elapsed += delta
		gesture(Vector2.RIGHT, _call_elapsed, 0.5)
		return
	# In the square: she keeps an eye on the nearest of her hens.
	_look_elapsed -= delta
	if _look_elapsed <= 0.0:
		_look_elapsed = 0.6
		var hen := _yard.nearest_loose_hen(global_position)
		if hen != null:
			face(hen.global_position - global_position)


func _start_calling() -> void:
	position = COOP_ROUTE.back()
	_calling = true
	_call_elapsed = 0.0
	_yard.start_grain()
	face(Vector2.RIGHT)
	set_physics_process(true)
