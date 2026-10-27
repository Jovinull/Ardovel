class_name WeightPuzzle
extends Node
## The ruin's interaction puzzle: a pressure plate holds a root seal open only while something
## weighs on it. Standing on it shows what it does; to walk through, the stone block has to
## take the hero's place. Leaving the room with the puzzle unsolved puts the block back, so it
## can never end up stuck in a corner. Solving it sets `flag`, which keeps the roots open.

signal solved

@export var flag: StringName = &"ruin_roots_solved"
@export var plate: PressurePlate
@export var block: PushBlock
@export var seal: RootSeal
## The room's floor: the hero walking out of it resets an unsolved block.
@export var room: Area2D

var _adventure: Adventure

@onready var _sound: AudioStreamPlayer = $SolvedSound


func _ready() -> void:
	add_to_group(&"adventure")
	plate.pressed_changed.connect(_on_pressed_changed)
	block.moved.connect(_check_block)
	room.body_exited.connect(_on_room_exited)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if is_solved():
		block.place(plate.position)
		block.locked = true


func is_solved() -> bool:
	return _adventure != null and _adventure.has_flag(flag)


func _on_pressed_changed(pressed: bool) -> void:
	if is_solved():
		return
	if pressed:
		seal.open()
	else:
		seal.close()


func _check_block() -> void:
	# The plate notices the block a physics frame after it stops.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if is_solved() or not plate.holds(block):
		return
	block.locked = true
	_sound.play()
	if _adventure != null:
		_adventure.set_flag(flag)
	seal.open()
	solved.emit()


func _on_room_exited(body: Node2D) -> void:
	if body is Player and not is_solved():
		block.reset()
