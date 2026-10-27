class_name PressurePlate
extends Area2D
## A stone plate that sinks while the hero or a push block stands on it.

signal pressed_changed(pressed: bool)

## Regions of the pack's TilesetDungeon.png: the plate raised and sunk.
const RAISED := Rect2(0, 16, 16, 16)
const SUNK := Rect2(16, 16, 16, 16)

var _weights: Array[Node2D] = []

@onready var _sprite: Sprite2D = $Sprite
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	_sprite.region_rect = RAISED


func is_pressed() -> bool:
	return not _weights.is_empty()


## True when `body` is one of the things weighing on the plate.
func holds(body: Node2D) -> bool:
	return _weights.has(body)


func _on_body_entered(body: Node2D) -> void:
	if not (body is Player or body is PushBlock) or _weights.has(body):
		return
	_weights.append(body)
	if _weights.size() == 1:
		_set_pressed(true)


func _on_body_exited(body: Node2D) -> void:
	if not _weights.has(body):
		return
	_weights.erase(body)
	if _weights.is_empty():
		_set_pressed(false)


func _set_pressed(pressed: bool) -> void:
	_sprite.region_rect = SUNK if pressed else RAISED
	_sound.play()
	pressed_changed.emit(pressed)
