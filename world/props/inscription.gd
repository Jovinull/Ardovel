@tool
class_name Inscription
extends StaticBody2D
## Something to examine (a carving, a tablet, a statue) whose text can follow the adventure:
## it says the first of its `lines` that applies, and reading it may set a flag.

@export var lines: Array[DialogueLine] = []

var _adventure: Adventure

@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure


func _on_interact(_actor: Node2D) -> String:
	var line := DialogueLine.first_that_applies(lines, _adventure)
	if line == null:
		return ""
	if _adventure != null:
		_adventure.set_flag(line.sets)
	return line.text
