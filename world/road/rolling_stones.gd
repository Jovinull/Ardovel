class_name RollingStones
extends Node2D
## Where the runoff has loosened the slope: every so often, after a puff of dust and a rattle at
## the top, a stone breaks loose and rolls down the water's course to `fall`. Quiet for good once
## the ditch runs again.

signal rolled(stone: Projectile)

const STONE := preload("res://world/road/rolling_stone.tscn")
const PUFF := preload("res://fx/smoke_puff.tscn")

## Where a stone stops, from the top of the chute.
@export var fall: Vector2 = Vector2(-40, 130)
@export var interval: float = 3.0
## Time before the first stone, so neighbouring chutes do not roll together.
@export var first_delay: float = 1.0
## How long the dust at the top comes before the stone.
@export var warning: float = 0.8

var _adventure: Adventure
var _timer := 0.0
var _warned := false


func _ready() -> void:
	add_to_group(&"adventure")
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	_timer = first_delay
	adventure.changed.connect(_refresh)
	_refresh()


func is_active() -> bool:
	return is_physics_processing()


func _refresh() -> void:
	set_physics_process(not _adventure.has_flag(RoadWork.DITCH_CLEARED))


func _physics_process(delta: float) -> void:
	_timer -= delta
	if not _warned and _timer <= warning:
		_warned = true
		var puff: Node2D = PUFF.instantiate()
		puff.position = position
		get_parent().add_child(puff)
	if _timer <= 0.0:
		_timer = interval
		_warned = false
		var stone: Projectile = STONE.instantiate()
		get_parent().add_child(stone)
		stone.max_distance = fall.length()
		stone.launch(global_position, fall, self)
		rolled.emit(stone)
