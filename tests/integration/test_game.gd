extends GutTest
## The assembled game scene: HUD wiring, death screen, the restart request and hit-stop.

const GameScene := preload("res://game/game.tscn")

var game: Game
var player: Player
var hud: Hud
var death_screen: DeathScreen


func before_each() -> void:
	game = GameScene.instantiate()
	game.show_title = false
	add_child_autofree(game)
	game.start_new()
	await wait_physics_frames(2)
	player = game.level.player
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
	assert_true(death_screen.restart_requested.is_connected(game.respawn), "wired to the game's respawn")
	death_screen.restart_requested.disconnect(game.respawn)  # only the request is under test here
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


func test_sword_hit_freezes_the_world_briefly() -> void:
	player.hit_landed.emit()
	assert_eq(Engine.time_scale, 0.0)
	await get_tree().create_timer(0.15, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0)


func test_a_second_hit_extends_the_freeze() -> void:
	# Long freezes so a slow frame cannot blur the windows: first ends at 0.3, second at 0.5.
	game.hit_stop_time = 0.3
	player.hit_landed.emit()
	await get_tree().create_timer(0.2, true, false, true).timeout
	player.hit_landed.emit()
	await get_tree().create_timer(0.2, true, false, true).timeout
	assert_eq(Engine.time_scale, 0.0, "the first freeze must not release the second")
	await get_tree().create_timer(0.3, true, false, true).timeout
	assert_eq(Engine.time_scale, 1.0)


func test_leaving_the_game_never_leaves_time_frozen() -> void:
	player.hit_landed.emit()
	remove_child(game)
	assert_eq(Engine.time_scale, 1.0)
	add_child(game)
