extends GutTest
## The shrine with the real player: proximity, focus, awakening, persistence.

const ShrineScene := preload("res://world/props/shrine/shrine.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")

var shrine: Shrine
var player: Player


func before_each() -> void:
	shrine = ShrineScene.instantiate()
	shrine.position = Vector2(200, 200)
	add_child_autofree(shrine)
	player = PlayerScene.instantiate()
	add_child_autofree(player)


func _place_player(at: Vector2) -> void:
	player.position = at
	await wait_physics_frames(3)


func test_far_player_has_no_focus_and_cannot_interact() -> void:
	await _place_player(Vector2(200, 300))
	assert_null(player.interactor.focused)
	assert_false(player.interactor.interact(player))
	assert_eq(shrine.state, Shrine.State.DORMANT)


func test_nearby_player_focuses_the_shrine_and_sees_the_prompt() -> void:
	await _place_player(Vector2(200, 214))
	assert_eq(player.interactor.focused, shrine.get_node(^"Interactable"))
	assert_true(shrine.get_node(^"Prompt").visible)
	await _place_player(Vector2(200, 300))
	assert_false(shrine.get_node(^"Prompt").visible, "prompt hides when walking away")


func test_first_interaction_awakens_and_restores_health() -> void:
	await _place_player(Vector2(200, 214))
	player.health.take_damage(7)
	var messages := []
	player.interactor.interacted.connect(func(_t: Interactable, msg: String) -> void: messages.append(msg))
	assert_true(player.interactor.interact(player))
	assert_eq(shrine.state, Shrine.State.AWAKENED)
	assert_eq(player.health.current, player.health.max_health)
	assert_eq(messages, [shrine.awaken_message])
	assert_eq((shrine.get_node(^"Sprite") as Sprite2D).texture, Shrine.AWAKENED_TEXTURE)


func test_awakened_shrine_stays_awakened_and_does_not_heal_again() -> void:
	await _place_player(Vector2(200, 214))
	watch_signals(shrine)
	player.interactor.interact(player)
	player.health.take_damage(4)
	var messages := []
	player.interactor.interacted.connect(func(_t: Interactable, msg: String) -> void: messages.append(msg))
	player.interactor.interact(player)
	assert_eq(shrine.state, Shrine.State.AWAKENED)
	assert_eq(player.health.current, player.health.max_health - 4, "only the first activation heals")
	assert_eq(messages, [shrine.awakened_message])
	assert_signal_emit_count(shrine, "awakened", 1)


func test_interactor_prefers_the_nearest_target() -> void:
	var other: Shrine = ShrineScene.instantiate()
	other.position = Vector2(226, 200)
	add_child_autofree(other)
	await _place_player(Vector2(205, 214))
	assert_eq(player.interactor.focused, shrine.get_node(^"Interactable"))
	await _place_player(Vector2(222, 214))
	assert_eq(player.interactor.focused, other.get_node(^"Interactable"))
