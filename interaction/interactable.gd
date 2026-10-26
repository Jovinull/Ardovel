class_name Interactable
extends Area2D
## Something the player can interact with. The owning object supplies the behaviour through
## `action` (a Callable taking the actor and returning a message to show, possibly empty).

const PROMPT_BOB := 2.0

@export var enabled: bool = true
## Optional indicator shown (and gently bobbing) while this is the player's current target.
@export var prompt: Node2D
## Name and portrait shown with this object's messages (for characters; empty for things).
@export var speaker: String = ""
@export var portrait: Texture2D

var action: Callable
var _prompt_rest_y: float
var _bob: Tween


func _ready() -> void:
	monitoring = false
	if prompt != null:
		_prompt_rest_y = prompt.position.y
	set_focused(false)


func can_interact() -> bool:
	return enabled and action.is_valid()


func interact(actor: Node2D) -> String:
	if not can_interact():
		return ""
	return action.call(actor)


func set_focused(value: bool) -> void:
	if prompt == null:
		return
	prompt.visible = value and can_interact()
	if _bob != null:
		_bob.kill()
		_bob = null
	prompt.position.y = _prompt_rest_y
	if prompt.visible:
		_bob = create_tween().set_loops()
		_bob.tween_property(prompt, ^"position:y", _prompt_rest_y - PROMPT_BOB, 0.35)
		_bob.tween_property(prompt, ^"position:y", _prompt_rest_y, 0.35)
