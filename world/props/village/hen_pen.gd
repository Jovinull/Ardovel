class_name HenPen
extends Node2D
## Cida's small pen behind the shop, where her hens live until the village light keeps them awake.
## The hen yard puts them here and opens the gate once they have fled.

## Where the hens peck about inside (local).
const INSIDE := Rect2(12, 18, 40, 16)

@onready var _gate_sprite: Sprite2D = $Gate/Sprite
@onready var _gate_shape: CollisionShape2D = $Gate/Collision


func inside() -> Rect2:
	return Rect2(global_position + INSIDE.position, INSIDE.size)


## The gate left open (frame 1: posts only) or shut (frame 2: the pack-coloured gate).
func show_open(open: bool) -> void:
	_gate_sprite.frame = 1 if open else 2
	_gate_shape.set_deferred(&"disabled", open)


func is_open() -> bool:
	return _gate_shape.disabled
