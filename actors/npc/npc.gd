class_name Npc
extends StaticBody2D
## A villager to talk to. Says the first of its `lines` whose conditions hold for the current
## adventure, turning to face whoever spoke to them.

const FRAME_SIZE := 16

## Translation key of the name shown in the dialogue box.
@export var display_name: String
## Pack character sheet (16x16 frames; columns down, up, left, right; idle pose on the first row).
@export var sheet: Texture2D
@export var faceset: Texture2D
## Facing while nobody talks to them.
@export var facing: Vector2 = Vector2.DOWN
## Checked from the top: put the most specific (latest in the story) lines first.
@export var lines: Array[DialogueLine] = []

var _adventure: Adventure

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"adventure")
	_sprite.texture = sheet
	# Pack sheets use 16x16 frames but not all have the same number of rows.
	_sprite.hframes = sheet.get_width() / FRAME_SIZE
	_sprite.vframes = sheet.get_height() / FRAME_SIZE
	_interactable.action = _on_interact
	_interactable.speaker = display_name
	_interactable.portrait = faceset
	face(facing)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure


## The line this villager would say now, or null.
func current_line() -> DialogueLine:
	for line in lines:
		if line.applies(_adventure):
			return line
	return null


## Shows the sheet column for `direction` (pack character sheets: down, up, left, right).
func face(direction: Vector2) -> void:
	_sprite.frame = ["down", "up", "left", "right"].find(String(Facing.name_of(direction)))


func _on_interact(actor: Node2D) -> String:
	var line := current_line()
	if line == null:
		return ""
	face(actor.global_position - global_position)
	if _adventure != null:
		_adventure.set_flag(line.sets)
	return line.text
