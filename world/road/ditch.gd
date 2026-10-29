class_name Ditch
extends TileMapLayer
## The old drainage ditch across the slope, one row of tiles. Choked at `dam_column`, the water
## backs up west of it and spills through the breaches down the slope; east of it the channel is
## dry. Once the choke is cleared it runs the whole way to the gorge and the breaches stop
## spilling.

## Tiles of ditch.png: two ways of laying the bank stones, each dry and running (two frames).
const DRY: Array[Vector2i] = [Vector2i(0, 0), Vector2i(5, 0)]
const RUNNING: Array[Vector2i] = [Vector2i(1, 0), Vector2i(6, 0)]
const BREACH_SPILLING := Vector2i(3, 0)
const BREACH_QUIET := Vector2i(8, 0)

@export var row: int = 4
@export var first_column: int = 2
@export var last_column: int = 22
@export var dam_column: int = 16
@export var breaches: Array[int] = []

var _adventure: Adventure


func _ready() -> void:
	add_to_group(&"adventure")


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_paint)
	_paint()


func is_running_at(column: int) -> bool:
	return get_cell_atlas_coords(Vector2i(column, row)) != DRY[0] \
			and get_cell_atlas_coords(Vector2i(column, row)) != DRY[1]


func _paint() -> void:
	var cleared := _adventure.has_flag(RoadWork.DITCH_CLEARED)
	for x in range(first_column, last_column + 1):
		var laid := 1 if x % 3 == 1 else 0
		var tile: Vector2i
		if x in breaches:
			tile = BREACH_QUIET if cleared else BREACH_SPILLING
		elif cleared or x < dam_column:
			tile = RUNNING[laid]
		else:
			tile = DRY[laid]
		set_cell(Vector2i(x, row), 0, tile)
