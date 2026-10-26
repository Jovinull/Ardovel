extends GutTest
## The assembled game scene: HUD wiring, death screen and the restart request.
## The actual scene reload is validated in real runs (reloading here would reload the test runner).

const GameScene := preload("res://game/game.tscn")

var game: Node
var player: Player
var hud: Hud
var death_screen: DeathScreen


func before_each() -> void:
	game = GameScene.instantiate()
	add_child_autofree(game)
	await wait_physics_frames(2)
	player = (game.get_node(^"Level") as Level).player
	hud = game.get_node(^"HUD")
	death_screen = game.get_node(^"DeathScreen")


func _hearts() -> Array[int]:
	var quarters: Array[int] = []
	for i in 3:
		quarters.append(hud.heart_quarters(i))
	return quarters


func test_hud_starts_with_three_full_hearts() -> void:
	assert_eq(_hearts(), [4, 4, 4])


func test_hud_shows_damage_in_quarters() -> void:
	player.health.invulnerability_time = 0.0
	player.health.take_damage(3)
	assert_eq(_hearts(), [4, 4, 1])
	player.health.take_damage(5)
	assert_eq(_hearts(), [4, 0, 0])


func test_interaction_messages_reach_the_hud() -> void:
	player.interactor.interacted.emit(null, "Teste")
	assert_true(hud.is_message_visible())
	player.interactor.interacted.emit(null, "")
	assert_true(hud.is_message_visible(), "empty messages do not replace the current one")


func test_death_opens_the_death_screen() -> void:
	assert_false(death_screen.is_open())
	player.health.take_damage(999)
	await wait_for_signal(player.died, 4.0)
	assert_true(death_screen.is_open())


func test_restart_action_requests_a_restart_only_when_open() -> void:
	assert_true(death_screen.restart_requested.is_connected(game.restart), "wired to the game's restart")
	death_screen.restart_requested.disconnect(game.restart)  # reloading would reload the test runner
	watch_signals(death_screen)
	var press := InputEventAction.new()
	press.action = &"restart"
	press.pressed = true
	Input.parse_input_event(press)
	await wait_frames(2)
	assert_signal_not_emitted(death_screen, "restart_requested")
	death_screen.open()
	Input.parse_input_event(press)
	await wait_frames(2)
	assert_signal_emitted(death_screen, "restart_requested")
	var release := InputEventAction.new()
	release.action = &"restart"
	Input.parse_input_event(release)
