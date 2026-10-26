class_name Interactable
extends Area2D
## Something the player can interact with. The owning object supplies the behaviour through
## `action` (a Callable taking the actor and returning a message to show, possibly empty).

@export var enabled: bool = true
## Optional indicator shown while this is the player's current interaction target.
@export var prompt: CanvasItem

var action: Callable


func _ready() -> void:
	monitoring = false
	set_focused(false)


func can_interact() -> bool:
	return enabled and action.is_valid()


func interact(actor: Node2D) -> String:
	if not can_interact():
		return ""
	return action.call(actor)


func set_focused(value: bool) -> void:
	if prompt != null:
		prompt.visible = value and can_interact()
