class_name CidaWorker
extends Npc
## Cida takes a short step toward her stall and sorts the wood after the path opens.

const READY_FLAG := &"cida_path_acknowledged"
const WORKED_FLAG := &"cida_stall_worked"
const WORK_OFFSET := Vector2(14, 8)
const WALK_SPEED := 28.0
const SORT_TIME := 0.75

var _home: Vector2
var _sorting := false
var _sort_elapsed := 0.0
var _walk_elapsed := 0.0
var _started := false


func _ready() -> void:
	super._ready()
	_home = position
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	adventure.changed.connect(_refresh_work)
	_refresh_work()


func _refresh_work() -> void:
	if _adventure.has_flag(WORKED_FLAG):
		position = _home + WORK_OFFSET
		face(Vector2.RIGHT)
		set_physics_process(false)
	elif _adventure.has_flag(READY_FLAG):
		set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _started:
		var player := get_parent().get_node_or_null(^"Player") as Player
		if player == null or global_position.distance_to(player.global_position) > 80.0:
			return
		_started = true
	if not _sorting:
		var destination := _home + WORK_OFFSET
		var next := position.move_toward(destination, WALK_SPEED * delta)
		if _step_is_clear(next):
			position = next
			_walk_elapsed += delta
			_sprite.frame = (3 if fmod(_walk_elapsed, 0.28) < 0.14 else 7)
		if position.distance_to(destination) <= 0.1:
			_sorting = true
			_sort_elapsed = 0.0
	else:
		_sort_elapsed += delta
		_sprite.frame = (3 if fmod(_sort_elapsed, 0.3) < 0.15 else 7)
		if _sort_elapsed >= SORT_TIME:
			face(Vector2.RIGHT)
			_adventure.set_flag(WORKED_FLAG)


func _step_is_clear(next: Vector2) -> bool:
	var body: CollisionShape2D = $Collision
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.transform = Transform2D(0.0, next + body.position)
	query.collision_mask = 3  # World and player bodies.
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()
