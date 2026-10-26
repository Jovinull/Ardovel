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
	# Impact sparks are spawned beside the player, not by the test, so they are not auto-freed.
	for effect in get_children().filter(func(n: Node) -> bool: return n is OneShotEffect):
		effect.free()


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
	assert_eq(player.get_node(^"Sprite").animation, &"death")
	await wait_seconds(1.0)
	assert_signal_not_emitted(player, "died", "still falling")
	await wait_for_signal(player.died, 3.0)
	assert_signal_emitted(player, "died")


func test_hurt_pose_faces_the_attacker_while_being_pushed_away() -> void:
	player.facing = Vector2.UP
	var hurtbox: Hurtbox = player.get_node(^"Hurtbox")
	hurtbox.receive_hit(Hit.new(1, 150.0, player.global_position + Vector2(-12, 0)))
	assert_eq(player.facing, Vector2.LEFT)
	assert_eq(_sprite().animation, &"hurt_left")
	await wait_physics_frames(6)
	assert_gt(player.position.x, 101.0, "pushed to the right, away from the attacker")


func test_can_turn_between_swings() -> void:
	player.facing = Vector2.RIGHT
	Input.action_press(&"attack")
	await wait_physics_frames(1)
	Input.action_release(&"attack")
	assert_eq(_sprite().animation, &"attack_right")
	Input.action_press(&"move_down")
	await wait_physics_frames(14)
	Input.action_press(&"attack")
	await wait_physics_frames(1)
	Input.action_release(&"attack")
	await wait_physics_frames(8)
	Input.action_release(&"move_down")
	assert_eq(_sprite().animation, &"attack_down", "the queued swing follows the held direction")


func test_early_presses_are_not_queued() -> void:
	Input.action_press(&"attack")
	await wait_physics_frames(1)
	Input.action_release(&"attack")
	await wait_physics_frames(2)
	Input.action_press(&"attack")
	await wait_physics_frames(1)
	Input.action_release(&"attack")
	await wait_physics_frames(25)
	assert_eq(player.state, Player.State.MOVE, "a press during the wind-up does not chain a second swing")


func test_sword_hit_emits_hit_landed_and_leaves_a_spark() -> void:
	watch_signals(player)
	var target := Hurtbox.new()
	target.collision_layer = 16
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(12, 12)
	shape.shape = rect
	target.add_child(shape)
	target.position = player.position + Vector2(0, 6)
	add_child_autofree(target)
	player.facing = Vector2.DOWN
	Input.action_press(&"attack")
	await wait_physics_frames(1)
	Input.action_release(&"attack")
	await wait_physics_frames(12)
	assert_signal_emit_count(player, "hit_landed", 1)
	var sparks := player.get_parent().get_children().filter(func(n: Node) -> bool: return n.name.begins_with("HitSpark"))
	assert_eq(sparks.size(), 1)
