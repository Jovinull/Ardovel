class_name MapSheet
extends Node2D
## The witch's map lying open by her fire (gone with her once she has gone east). Looked at, it
## fills the screen (the area holds still) until the hero presses on: blank past the Ponte da Laje,
## or drawn on to the gorge once she has drawn the stretch.

const OPEN_DELAY := 0.25

@export var blank: Texture2D
@export var drawn: Texture2D

var _adventure: Adventure
var _opened_for := 0.0

@onready var _interactable: Interactable = $Interactable
@onready var _view: CanvasLayer = $View
@onready var _picture: TextureRect = $View/Picture


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact
	_view.visible = false
	_view.process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	process_mode = Node.PROCESS_MODE_ALWAYS


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if adventure.has_flag(Blank.GONE):
		queue_free()  # she took it east with her


func is_open() -> bool:
	return _view.visible


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	_picture.texture = drawn if _adventure.has_flag(Blank.DRAWN) else blank
	_view.visible = true
	_opened_for = 0.0
	set_process(true)
	var level := owner as Level
	if level != null:
		level.set_deferred(&"process_mode", Node.PROCESS_MODE_DISABLED)
	return ""


func close() -> void:
	_view.visible = false
	set_process(false)
	var level := owner as Level
	if level != null:
		level.process_mode = Node.PROCESS_MODE_INHERIT


func _process(delta: float) -> void:
	_opened_for += delta
	if _opened_for < OPEN_DELAY:
		return
	if Input.is_action_just_pressed(&"interact") or Input.is_action_just_pressed(&"attack") \
			or Input.is_action_just_pressed(&"ui_cancel"):
		close()
