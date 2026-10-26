extends GutTest
## Musgorico's state machine on the real scene, with real physics and a stand-in target.

const MusgoricoScene := preload("res://actors/musgorico/musgorico.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")
const S := Musgorico.State

var musgo: Musgorico
var dummy: Node2D


func before_each() -> void:
	musgo = MusgoricoScene.instantiate()
	musgo.rng_seed = 7
	musgo.position = Vector2(300, 300)
	add_child_autofree(musgo)
	dummy = Node2D.new()
	dummy.position = Vector2(2000, 2000)
	add_child_autofree(dummy)
	await wait_physics_frames(1)


func _step(frames: int) -> void:
	await wait_physics_frames(frames)


func test_wanders_but_stays_near_home() -> void:
	var furthest := 0.0
	for i in 40:
		await _step(10)
		furthest = maxf(furthest, musgo.global_position.distance_to(musgo.home))
	assert_gt(furthest, 5.0, "it does move around")
	assert_lt(furthest, musgo.wander_radius + 4.0, "but never leaves its wander radius")


func test_chases_a_visible_target() -> void:
	dummy.position = musgo.position + Vector2(80, 0)
	musgo.set_target(dummy)
	await _step(2)
	assert_eq(musgo.state, S.CHASE)
	var before := musgo.global_position.distance_to(dummy.global_position)
	await _step(20)
	assert_lt(musgo.global_position.distance_to(dummy.global_position), before)


func test_ignores_a_target_beyond_lose_radius() -> void:
	dummy.position = musgo.position + Vector2(musgo.lose_radius + 20.0, 0)
	musgo.set_target(dummy)
	await _step(5)
	assert_ne(musgo.state, S.CHASE)


func test_telegraphs_then_lunges_then_recovers() -> void:
	dummy.position = musgo.position + Vector2(20, 0)
	musgo.set_target(dummy)
	await _step(2)
	assert_eq(musgo.state, S.WINDUP)
	var start := musgo.global_position
	await _step(int(musgo.windup_time * 60.0) - 4)
	assert_eq(musgo.state, S.WINDUP, "holds still while telegraphing")
	assert_almost_eq(musgo.global_position.distance_to(start), 0.0, 0.01)
	await _step(8)
	assert_eq(musgo.state, S.LUNGE)
	await _step(int(musgo.lunge_time * 60.0) + 2)
	assert_eq(musgo.state, S.RECOVER)
	assert_gt(musgo.global_position.x, start.x + 15.0, "the lunge travelled towards the target")


func test_gives_up_and_returns_home_when_target_leaves() -> void:
	dummy.position = musgo.position + Vector2(60, 0)
	musgo.set_target(dummy)
	await _step(30)
	dummy.position = Vector2(5000, 5000)
	await _step(2)
	assert_eq(musgo.state, S.RETURN)
	var frames := 0
	while musgo.state == S.RETURN and frames < 600:
		await _step(1)
		frames += 1
	assert_eq(musgo.state, S.IDLE, "rests once it is back")
	assert_lt(musgo.global_position.distance_to(musgo.home), 6.0)


func test_never_chases_past_its_leash() -> void:
	musgo.lose_radius = 10000.0
	dummy.position = musgo.position + Vector2(60, 0)
	musgo.set_target(dummy)
	for i in 30:
		dummy.position.x += 8.0
		await _step(4)
	assert_lt(musgo.global_position.distance_to(musgo.home), musgo.leash_radius + 4.0)


func test_three_sword_hits_defeat_it() -> void:
	var defeated := [false]
	musgo.defeated.connect(func() -> void: defeated[0] = true)
	var hurtbox: Hurtbox = musgo.get_node(^"Hurtbox")
	for i in 3:
		assert_true(hurtbox.receive_hit(Hit.new(1, 100.0, musgo.global_position + Vector2(0, -20))))
		await _step(int(musgo.health.invulnerability_time * 60.0) + 2)
	assert_true(defeated[0], "defeated was emitted")
	await _step(1)
	assert_false(is_instance_valid(musgo), "freed after dying")


func test_detection_area_acquires_the_player_and_contact_hurts() -> void:
	var player: Player = PlayerScene.instantiate()
	player.position = musgo.position + Vector2(50, 0)
	add_child_autofree(player)
	await _step(3)
	assert_eq(musgo.target, player, "noticed through the detection area")
	await _step(120)
	assert_lt(player.health.current, player.health.max_health, "the hedgehog reached and hurt the player")


func test_stops_chasing_a_dead_player() -> void:
	var player: Player = PlayerScene.instantiate()
	player.position = musgo.position + Vector2(50, 0)
	add_child_autofree(player)
	await _step(3)
	player.health.take_damage(999)
	await _step(3)
	assert_ne(musgo.state, S.CHASE)
	assert_ne(musgo.state, S.WINDUP)
