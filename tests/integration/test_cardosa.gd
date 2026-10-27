extends GutTest
## Cardosa with the real player: warning, shot, rhythm, interruption and death.

const CardosaScene := preload("res://actors/cardosa/cardosa.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")
const S := Cardosa.State

var plant: Cardosa
var player: Player


func before_each() -> void:
	plant = CardosaScene.instantiate()
	plant.position = Vector2(200, 200)
	add_child_autofree(plant)
	player = PlayerScene.instantiate()
	player.position = Vector2(600, 600)
	add_child_autofree(player)
	await wait_physics_frames(2)


func after_each() -> void:
	# Seeds are spawned by the plant, not by the test, so they are not auto-freed. They are queued
	# rather than freed on the spot: freeing monitoring areas in the middle of a frame preceded
	# rare engine freezes in later tests (see test_checkpoints).
	for seed in _seeds():
		seed.queue_free()


func _seeds() -> Array:
	return get_children().filter(func(n: Node) -> bool: return n is Projectile and not n.is_queued_for_deletion())


func _bring_player(offset: Vector2) -> void:
	player.position = plant.position + offset
	await wait_physics_frames(3)


func test_rests_while_nobody_is_near() -> void:
	await wait_physics_frames(60)
	assert_eq(plant.state, S.IDLE)
	assert_eq(_seeds().size(), 0)


func test_warns_then_fires_one_seed_towards_the_player() -> void:
	await _bring_player(Vector2(60, 0))
	assert_eq(plant.state, S.WINDUP)
	assert_eq(plant.get_node(^"Sprite").animation, &"windup")
	await wait_physics_frames(int(plant.windup_time * 60.0) - 6)
	assert_eq(_seeds().size(), 0, "no shot during the warning")
	await wait_physics_frames(10)
	var seeds := _seeds()
	assert_eq(seeds.size(), 1)
	assert_gt((seeds[0] as Projectile).direction.x, 0.95, "aimed at the player")
	assert_eq(plant.state, S.SHOOT)


func test_needs_to_recover_before_the_next_shot() -> void:
	player.health.max_health = 99
	player.health.restore_full()
	await _bring_player(Vector2(70, 0))
	var frames := 0
	while plant.state != S.COOLDOWN and frames < 120:
		await wait_physics_frames(1)
		frames += 1
	assert_eq(plant.state, S.COOLDOWN)
	var shots := _seeds().size()
	await wait_physics_frames(int(plant.cooldown_time * 60.0) - 10)
	assert_eq(plant.state, S.COOLDOWN, "still recovering")
	assert_lte(_seeds().size(), shots, "no second shot while recovering")


func test_a_hit_during_the_warning_cancels_the_shot() -> void:
	await _bring_player(Vector2(60, 0))
	await wait_physics_frames(10)
	plant.get_node(^"Hurtbox").receive_hit(Hit.new(1, 0.0, player.global_position))
	assert_eq(plant.state, S.HURT)
	await wait_physics_frames(int(plant.windup_time * 60.0))
	assert_eq(_seeds().size(), 0)


func test_no_shot_if_the_player_leaves_during_the_warning() -> void:
	await _bring_player(Vector2(60, 0))
	await _bring_player(Vector2(400, 0))
	await wait_physics_frames(int(plant.windup_time * 60.0) + 4)
	assert_eq(_seeds().size(), 0)
	assert_eq(plant.state, S.IDLE)


func test_the_seed_reaches_and_hurts_the_player() -> void:
	await _bring_player(Vector2(50, 6))
	await wait_physics_frames(int(plant.windup_time * 60.0) + 70)
	assert_lt(player.health.current, player.health.max_health)


func test_two_hits_defeat_it_after_its_wilt_animation() -> void:
	var defeated := [false]
	plant.defeated.connect(func() -> void: defeated[0] = true)
	var hurtbox: Hurtbox = plant.get_node(^"Hurtbox")
	hurtbox.receive_hit(Hit.new(1, 0.0, Vector2.ZERO))
	await wait_physics_frames(int(plant.health.invulnerability_time * 60.0) + 2)
	hurtbox.receive_hit(Hit.new(1, 0.0, Vector2.ZERO))
	assert_true(defeated[0])
	assert_eq(plant.get_node(^"Sprite").animation, &"death")
	await wait_seconds(1.0)
	assert_false(is_instance_valid(plant))
