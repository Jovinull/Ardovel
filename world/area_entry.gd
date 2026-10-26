class_name AreaEntry
extends Marker2D
## A named spot where the hero appears when arriving in this area, and that can serve as the
## adventure's return point (after death or when resuming a save).

@export var id: StringName
## Direction the hero faces on arrival, normally into the area.
@export var facing: Vector2 = Vector2.DOWN
