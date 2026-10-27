class_name HeartVessel
extends Node2D
## A crystal heart left in a hidden corner. Taking it gives the hero one more heart (the game
## counts the heart vessel flags) and heals them fully. It can only be taken once.

## Heart vessel flags start with this; the game counts them to size the hero's health.
const FLAG_PREFIX := "heart_vessel_"

## Adventure flag recording that this heart was taken.
@export var flag: StringName = &"heart_vessel_ruin"
@export var message: String = "HEART_VESSEL_FOUND"

var _adventure: Adventure

@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if adventure.has_flag(flag):
		queue_free()


func _on_interact(actor: Node2D) -> String:
	if _adventure == null or _adventure.has_flag(flag):
		return ""
	_adventure.set_flag(flag)
	var health := actor.get(&"health") as Health
	if health != null:
		health.restore_full()
	_sound.play()
	_interactable.enabled = false
	visible = false
	_sound.finished.connect(queue_free)
	return message
