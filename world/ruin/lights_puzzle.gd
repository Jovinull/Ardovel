class_name LightsPuzzle
extends Node
## The ruin's observation puzzle: the orbs on their stands must be lit the way the guardians in
## the hall still hold theirs, in the same order. The answer is read from the guardians
## themselves, so clue and solution cannot drift apart. Solving it sets `flag`, which opens
## the way on, and the orbs stay as they are from then on.

signal solved

@export var flag: StringName = &"ruin_lights_solved"
@export var pedestals: Array[LightPedestal] = []
## The guardians whose orbs give the answer, in the same order as `pedestals`.
@export var clues: Array[RuinGuardian] = []

var _adventure: Adventure

@onready var _sound: AudioStreamPlayer = $SolvedSound


func _ready() -> void:
	add_to_group(&"adventure")
	for pedestal in pedestals:
		pedestal.toggled.connect(_on_toggled.unbind(1))


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if is_solved():
		var answer := pattern()
		for i in pedestals.size():
			pedestals[i].set_lit_quietly(answer[i])
			pedestals[i].locked = true


func is_solved() -> bool:
	return _adventure != null and _adventure.has_flag(flag)


func pattern() -> Array[bool]:
	var answer: Array[bool] = []
	for clue in clues:
		answer.append(clue.holds_orb)
	return answer


func matches() -> bool:
	var answer := pattern()
	for i in pedestals.size():
		if pedestals[i].lit != answer[i]:
			return false
	return true


func _on_toggled() -> void:
	if is_solved() or not matches():
		return
	for pedestal in pedestals:
		pedestal.locked = true
	_sound.play()
	if _adventure != null:
		_adventure.set_flag(flag)
	solved.emit()
