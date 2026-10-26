extends GutTest

var interactable: Interactable
var actor: Node2D


func before_each() -> void:
	interactable = Interactable.new()
	add_child_autofree(interactable)
	actor = autofree(Node2D.new())


func test_without_action_it_cannot_be_used() -> void:
	assert_false(interactable.can_interact())
	assert_eq(interactable.interact(actor), "")


func test_action_receives_the_actor_and_returns_its_message() -> void:
	var received := []
	interactable.action = func(who: Node2D) -> String:
		received.append(who)
		return "hello"
	assert_eq(interactable.interact(actor), "hello")
	assert_eq(received, [actor])


func test_disabled_interactable_rejects_interaction() -> void:
	var calls := [0]
	interactable.action = func(_who: Node2D) -> String:
		calls[0] += 1
		return "x"
	interactable.enabled = false
	assert_false(interactable.can_interact())
	assert_eq(interactable.interact(actor), "")
	assert_eq(calls[0], 0)


func test_prompt_is_shown_only_when_focused_and_usable() -> void:
	var prompt := Sprite2D.new()
	var with_prompt := Interactable.new()
	with_prompt.prompt = prompt
	with_prompt.add_child(prompt)
	add_child_autofree(with_prompt)
	with_prompt.set_focused(true)
	assert_false(prompt.visible, "no action yet")
	with_prompt.action = func(_who: Node2D) -> String: return ""
	with_prompt.set_focused(true)
	assert_true(prompt.visible)
	with_prompt.set_focused(false)
	assert_false(prompt.visible)
