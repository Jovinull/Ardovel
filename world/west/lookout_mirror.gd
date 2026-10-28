class_name LookoutMirror
extends StaticBody2D
## A polished metal disc on a swivel at the western lookout. The first look tells what is odd
## about it; after that each use turns it between the slope below and the forest. Daylight off
## the disc leaves its face and runs the way it faces: down the slope to the south, or east
## toward the forest. Once the glint in the forest has been seen, the disc is found already
## turned toward the forest.

signal reflected

const FOUND_FLAG := &"west_lookout_seen"
const GLINT_FLAG := &"forest_echo_found"
## The disc's two positions (frames of its sheet).
enum Turn { SOUTH, FOREST }
## Where the reflected patch starts (the middle of the disc's face) and where it ends for
## each position: down the slope or off east, landing a little lower on the ground.
const GLEAM_FROM := Vector2(0, -16)
const GLEAM_TO := {Turn.SOUTH: Vector2(0, 96), Turn.FOREST: Vector2(160, -4)}
const GLEAM_TIME := 1.4

var turn: Turn = Turn.SOUTH
var _adventure: Adventure
var _gleam_tween: Tween

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _gleam: Sprite2D = $Gleam
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact
	_gleam.visible = false
	# The dialogue holds the area still while it is read; the gleam and its sound run on, like
	# the forest's echo.
	_gleam.process_mode = Node.PROCESS_MODE_ALWAYS
	_sound.process_mode = Node.PROCESS_MODE_ALWAYS


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	_show(Turn.FOREST if adventure.has_flag(GLINT_FLAG) else Turn.SOUTH)


func is_reflecting() -> bool:
	return _gleam_tween != null and _gleam_tween.is_running()


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	if not _adventure.has_flag(FOUND_FLAG):
		_adventure.set_flag(FOUND_FLAG)
		_throw_gleam()
		return "WEST_MIRROR_FIRST_GLINT" if _adventure.has_flag(GLINT_FLAG) else "WEST_MIRROR_FIRST"
	_show(Turn.SOUTH if turn == Turn.FOREST else Turn.FOREST)
	_throw_gleam()
	if turn == Turn.SOUTH:
		return "WEST_MIRROR_SOUTH"
	return "WEST_MIRROR_FOREST_GLINT" if _adventure.has_flag(GLINT_FLAG) else "WEST_MIRROR_FOREST"


func _show(value: Turn) -> void:
	turn = value
	_sprite.frame = int(value)


## Daylight off the disc: a soft patch leaves its face, runs the way it faces, brightens and fades.
func _throw_gleam() -> void:
	if _gleam_tween != null:
		_gleam_tween.kill()
	_gleam.position = GLEAM_FROM
	_gleam.frame = 0
	_gleam.visible = true
	_sound.play()
	_gleam_tween = _gleam.create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_gleam_tween.tween_property(_gleam, ^"position", GLEAM_TO[turn], GLEAM_TIME)
	_gleam_tween.parallel().tween_property(_gleam, ^"frame", 2, GLEAM_TIME * 0.4)
	_gleam_tween.tween_property(_gleam, ^"frame", 3, 0.2)
	_gleam_tween.tween_callback(_gleam.hide)
	reflected.emit()
