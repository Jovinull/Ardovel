class_name VeinLamp
extends StaticBody2D
## The miners' lamp in their shelter. Lit once (`flag`), it is the vein's own way back: a fall
## anywhere in the vein leads here (Level.fall_entry) and Continue starts here (the resume point).
## Resting by it restores the hero's health, every time. Frames: 0 cold, 1-2 lit (flicker).

const FLICKER := 0.3

@export var flag: StringName = &"vein_lamp_lit"
## The entry beside the lamp.
@export var entry: StringName = &"shelter"

var _adventure: Adventure
var _clock := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact
	set_process(false)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if adventure.has_flag(flag):
		_light()


func is_lit() -> bool:
	return _adventure != null and _adventure.has_flag(flag)


func _process(delta: float) -> void:
	_clock += delta
	_sprite.frame = 1 + int(_clock / FLICKER) % 2


func _light() -> void:
	set_process(true)
	_sprite.frame = 1
	var level := Level.containing(self)
	if level != null:
		level.fall_entry = entry


func _on_interact(actor: Node2D) -> String:
	if _adventure == null:
		return ""
	var health := actor.get(&"health") as Health
	if health != null:
		health.restore_full()
	_sound.play()
	if is_lit():
		return "VEIN_LAMP_REST"
	_adventure.set_flag(flag)
	var level := Level.containing(self)
	if level != null:
		_adventure.enter(level.area_id, entry)
	_light()
	return "VEIN_LAMP_LIT"
