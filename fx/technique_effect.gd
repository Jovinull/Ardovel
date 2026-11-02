extends Node2D
## A technique's mark, played once where the hero stood: frames drawn for a technique pointing
## right (or, for a mark on the ground, the same for every direction), turned to where the hero
## faces and placed along it. It waits for the technique's wind-up, so it shows the blow as it lands.

@export var texture: Texture2D
@export var frames: int = 4
@export var frame_time: float = 0.05
## Turn the frames to the direction (they are drawn pointing right).
@export var turns: bool = true
## Where along the blow it sits: 0 at the hero, 1 at the end of the reach.
@export_range(0.0, 1.0) var along: float = 0.5
## Height of the hero's middle above their feet (the blow happens there, not at the feet).
@export var lift: float = 8.0

var direction := Vector2.DOWN
var delay := 0.0
var reach := 12.0

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.hframes = frames
	_sprite.position = direction * reach * along + Vector2(0, -lift)
	if turns:
		_sprite.rotation = direction.angle()
	_sprite.visible = false
	z_index = 1
	add_child(_sprite)
	var tween := create_tween()
	tween.tween_interval(delay)
	tween.tween_callback(_sprite.show)
	for i in range(1, frames):
		tween.tween_interval(frame_time)
		tween.tween_property(_sprite, ^"frame", i, 0.0)
	tween.tween_interval(frame_time)
	tween.tween_callback(queue_free)
