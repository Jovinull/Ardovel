class_name OneShotEffect
extends Sprite2D
## Plays a horizontal sprite-sheet strip once (one frame per `hframes` cell) and frees itself.

@export var fps: float = 12.0

var _elapsed: float = 0.0


func _ready() -> void:
	frame = 0


func _process(delta: float) -> void:
	_elapsed += delta
	var next := int(_elapsed * fps)
	if next >= hframes:
		queue_free()
	else:
		frame = next
