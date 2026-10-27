class_name DeathScreen
extends CanvasLayer
## Shown when the player falls; asks for the restart action.

signal restart_requested

const FADE_TIME := 0.6

@onready var _root: Control = $Root
@onready var _keyboard_key: TextureRect = $Root/Retry/Key
@onready var _gamepad_prompt: Label = $Root/Retry/Prompt

var _gamepad_active: bool = false


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


func set_input_mode(gamepad: bool) -> void:
	_gamepad_active = gamepad
	_keyboard_key.visible = not gamepad
	_gamepad_prompt.visible = gamepad
	_gamepad_prompt.text = "[ %s ]" % InputPrompts.restart_label(gamepad)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"restart"):
		get_viewport().set_input_as_handled()
		set_process_unhandled_input(false)
		restart_requested.emit()
