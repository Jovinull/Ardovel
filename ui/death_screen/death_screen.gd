class_name DeathScreen
extends CanvasLayer
## Shown when the player falls; asks for the restart action.

signal restart_requested

const FADE_TIME := 0.6

@onready var _root: Control = $Root


func _ready() -> void:
	_root.hide()
	set_process_unhandled_input(false)


func open() -> void:
	_root.modulate.a = 0.0
	_root.show()
	create_tween().tween_property(_root, ^"modulate:a", 1.0, FADE_TIME)
	set_process_unhandled_input(true)


func close() -> void:
	_root.hide()
	set_process_unhandled_input(false)


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		set_process_unhandled_input(false)
		restart_requested.emit()
