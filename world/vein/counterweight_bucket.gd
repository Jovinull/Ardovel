class_name CounterweightBucket
extends WaterNode
## A counterweight bucket hanging on its rope: fed, it fills and hangs low (whatever it is tied to is
## lifted: a gate, a lift); dry, it empties through its leak and rises. Frame 0 up and empty, 1 down
## and full.

@onready var _sprite: Sprite2D = $Sprite
@onready var _sound: AudioStreamPlayer2D = $Sound


func _show(wet: bool, animate: bool) -> void:
	_sprite.frame = 1 if wet else 0
	if animate:
		_sound.play()
