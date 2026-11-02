class_name WeighPlate
extends Sprite2D
## The weigh plate at the rails' end: pressed down by the loaded cart, it holds its gate's
## counterweight down. Frames of rails.png: 2 up, 3 pressed.

signal pressed

var _pressed := false


func _ready() -> void:
	frame = 2


func is_pressed() -> bool:
	return _pressed


func press() -> void:
	if _pressed:
		return
	_pressed = true
	frame = 3
	pressed.emit()
