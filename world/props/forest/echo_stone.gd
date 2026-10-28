class_name EchoStone
extends StaticBody2D
## A carved stone behind the tangle. Reaching it only takes a sword; it answers only once the
## ruin's heart is awake, and only the first time.

signal answered

const HEART_FLAG := &"ruin_heart_awakened"
const CUT_FLAG := &"forest_echo_thicket_cut"
const FOUND_FLAG := &"forest_echo_found"

var _adventure: Adventure

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_show_state)
	_show_state()


func _show_state() -> void:
	var frame := 0
	if _adventure.has_flag(FOUND_FLAG):
		frame = 2
	elif _adventure.has_flag(HEART_FLAG):
		frame = 1
	_sprite.region_rect = Rect2(frame * 24, 0, 24, 30)


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null or not _adventure.has_flag(HEART_FLAG):
		return "ECHO_STONE_DARK"
	if not _adventure.has_flag(CUT_FLAG):
		return "ECHO_STONE_BLOCKED"
	if _adventure.has_flag(FOUND_FLAG):
		return "ECHO_STONE_AFTER"
	_adventure.set_flag(FOUND_FLAG)
	_sound.play()
	answered.emit()
	return "ECHO_STONE_REPLY"
