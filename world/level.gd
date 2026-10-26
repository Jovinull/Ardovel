class_name Level
extends Node2D
## A playable area. Exposes its player and keeps the camera inside the painted ground.

@export var player: Player
@export var ground: TileMapLayer


func _ready() -> void:
	var bounds := Rect2i(ground.get_used_rect().position * ground.tile_set.tile_size,
			ground.get_used_rect().size * ground.tile_set.tile_size)
	var camera := player.camera
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y
	camera.reset_physics_interpolation()
