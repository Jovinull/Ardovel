class_name VoidWalls
extends StaticBody2D
## Closes every cell around the floor that has neither floor nor wall. In the ruin the dark
## between the rooms is only drawn, so without this it could be walked into from the sides of
## the corridors. Cells are closed in runs along each row, one shape per run.

@export var ground: TileMapLayer
@export var walls: TileMapLayer
## Cells left open: where an exit runs off the map.
@export var open_cells: Array[Vector2i] = []


func _ready() -> void:
	var area := ground.get_used_rect().grow(1)
	for y in range(area.position.y, area.end.y):
		var in_run := false
		var run_start := 0
		for x in range(area.position.x, area.end.x + 1):
			var closed := x < area.end.x and _is_void(Vector2i(x, y))
			if closed and not in_run:
				in_run = true
				run_start = x
			elif not closed and in_run:
				in_run = false
				_close(Vector2i(run_start, y), x - run_start)


func _is_void(cell: Vector2i) -> bool:
	return ground.get_cell_source_id(cell) == -1 and walls.get_cell_source_id(cell) == -1 \
			and not open_cells.has(cell)


func _close(first: Vector2i, length: int) -> void:
	var tile := Vector2(ground.tile_set.tile_size)
	var rect := RectangleShape2D.new()
	rect.size = Vector2(tile.x * length, tile.y)
	var shape := CollisionShape2D.new()
	shape.shape = rect
	shape.position = ground.map_to_local(first) - tile / 2.0 + rect.size / 2.0
	add_child(shape)
