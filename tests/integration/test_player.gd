extends GutTest
## The real player scene, stepped with physics frames and simulated input actions.

const PlayerScene := preload("res://actors/player/player.tscn")

var player: Player


func before_each() -> void:
	player = PlayerScene.instantiate()
	player.position = Vector2(100, 100)
	add_child_autofree(player)
	await wait_physics_frames(1)


func after_each() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack", &"interact"]:
		Input.action_release(action)


func _sprite() -> AnimatedSprite2D:
	return player.get_node(^"Sprite")


func test_walks_right_and_plays_walk_animation() -> void:
	Input.action_press(&"move_right")
	await wait_physics_frames(30)
	assert_gt(player.position.x, 125.0, "moved about 72 px/s for half a second")
	assert_almost_eq(player.position.y, 100.0, 0.01)
	assert_eq(_sprite().animation, &"walk_right")
	Input.action_release(&"move_right")
	await wait_physics_frames(5)
	assert_eq(_sprite().animation, &"idle_right")


func test_diagonal_walk_speed_matches_cardinal() -> void:
	Input.action_press(&"move_right")
	Input.action_press(&"move_down")
	await wait_physics_frames(60)
	var travelled := player.position.distance_to(Vector2(100, 100))
	assert_almost_eq(travelled, 72.0, 4.0, "one second of diagonal walking covers ~max_speed")


func test_attack_shows_three_phases_and_returns_to_move() -> void:
	player.facing = Vector2.UP
	Input.action_press(&"attack")
	await wait_physics_frames(1)
	Input.action_release(&"attack")
	assert_eq(player.state, Player.State.ATTACK)
	assert_eq(_sprite().animation, &"attack_up")
	var seen := {}
	for i in 30:
		seen[_sprite().frame] = true
		await wait_physics_frames(1)
	assert_eq(seen.keys().size(), 3, "wind-up, strike and follow-through frames were all shown")
	assert_eq(player.state, Player.State.MOVE)


func test_cannot_walk_during_attack() -> void:
	Input.action_press(&"attack")
	await wait_physics_frames(1)
	Input.action_release(&"attack")
	Input.action_press(&"move_left")
	await wait_physics_frames(8)
	assert_almost_eq(player.position.x, 100.0, 0.01)


func test_hit_knocks_back_and_grants_invulnerability() -> void:
	var hurtbox: Hurtbox = player.get_node(^"Hurtbox")
	assert_true(hurtbox.receive_hit(Hit.new(2, 150.0, player.global_position + Vector2(10, 0))))
	assert_eq(player.health.current, 10)
	assert_eq(player.state, Player.State.HURT)
	await wait_physics_frames(6)
	assert_lt(player.position.x, 99.0, "pushed away from the source (to the left)")
	assert_false(hurtbox.receive_hit(Hit.new(2, 150.0, Vector2.ZERO)), "invulnerable right after a hit")
	await wait_physics_frames(20)
	assert_eq(player.state, Player.State.MOVE)


func test_lethal_damage_kills_and_emits_died_after_the_death_animation() -> void:
	watch_signals(player)
	var hurtbox: Hurtbox = player.get_node(^"Hurtbox")
	hurtbox.receive_hit(Hit.new(99, 0.0, Vector2.ZERO))
	assert_eq(player.state, Player.State.DEAD)
	assert_signal_not_emitted(player, "died", "waits for the death animation")
	await wait_seconds(1.4)
	assert_signal_emitted(player, "died")
