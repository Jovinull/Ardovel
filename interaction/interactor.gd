class_name Interactor
extends Area2D
## Tracks the Interactables in reach of its owner and focuses the nearest usable one.

signal focus_changed(target: Interactable)
signal interacted(target: Interactable, message: String)

var focused: Interactable
var _candidates: Array[Interactable] = []


func _ready() -> void:
	monitorable = false
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	# Only needed while several targets compete: the nearest one changes as the owner moves.
	refresh_focus()


## Interacts with the focused target on behalf of `actor`. Returns false if nothing is focused.
func interact(actor: Node2D) -> bool:
	if focused == null:
		return false
	var target := focused
	var message := target.interact(actor)
	interacted.emit(target, message)
	refresh_focus()
	return true


func refresh_focus() -> void:
	var best: Interactable = null
	var best_distance := INF
	for candidate in _candidates:
		if not candidate.can_interact():
			continue
		var d := global_position.distance_squared_to(candidate.global_position)
		if d < best_distance:
			best = candidate
			best_distance = d
	if best != focused:
		if is_instance_valid(focused):
			focused.set_focused(false)
		focused = best
		if focused != null:
			focused.set_focused(true)
		focus_changed.emit(focused)


func _on_area_entered(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable != null and not _candidates.has(interactable):
		_candidates.append(interactable)
		set_physics_process(_candidates.size() > 1)
		refresh_focus()


func _on_area_exited(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable != null:
		_candidates.erase(interactable)
		set_physics_process(_candidates.size() > 1)
		refresh_focus()
