extends GutTest
## The Cardosa seed as a real physics object: what stops it and what it hurts.

const SeedScene := preload("res://actors/cardosa/seed.tscn")
const PlayerScene := preload("res://actors/player/player.tscn")


func after_each() -> void:
	# A burst leaves a spark in the seed's parent; it is not the test's own node to auto-free.
	for effect in get_children().filter(func(n: Node) -> bool: return n is OneShotEffect):
		effect.free()


func _seed(from: Vector2, toward: Vector2, shooter: Node = null) -> Projectile:
	var seed: Projectile = SeedScene.instantiate()
	add_child_autofree(seed)
	seed.launch(from, toward, shooter)
	return seed


func _wall(at: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 32)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = at
	add_child_autofree(wall)
	return wall


func test_flies_straight_and_bursts_at_the_end_of_its_range() -> void:
	var seed := _seed(Vector2(100, 100), Vector2.RIGHT)
	seed.speed = 60.0
	seed.max_distance = 30.0
	await wait_physics_frames(15)
	assert_almost_eq(seed.position.y, 100.0, 0.01)
	assert_gt(seed.position.x, 110.0)
	await wait_physics_frames(25)
	assert_false(is_instance_valid(seed), "burst after travelling its range")


func test_hurts_the_player_once_and_bursts() -> void:
	var player: Player = PlayerScene.instantiate()
	player.position = Vector2(160, 106)
	add_child_autofree(player)
	var seed := _seed(Vector2(120, 100), Vector2.RIGHT)
	await wait_physics_frames(60)
	assert_eq(player.health.current, player.health.max_health - 2)
	assert_false(is_instance_valid(seed))


func test_passes_its_shooter_but_bursts_on_other_solids() -> void:
	var shooter := _wall(Vector2(110, 100))
	var seed := _seed(Vector2(110, 100), Vector2.RIGHT, shooter)
	await wait_physics_frames(6)
	assert_true(is_instance_valid(seed), "leaving the shooter's own body")
	_wall(Vector2(140, 100))
	await wait_physics_frames(40)
	assert_false(is_instance_valid(seed), "stopped by the next solid")


func test_a_sword_can_cut_it() -> void:
	var seed := _seed(Vector2(100, 100), Vector2.RIGHT)
	seed.speed = 0.0
	var sword := Hitbox.new()
	sword.collision_layer = 0
	sword.collision_mask = 16
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	sword.add_child(shape)
	sword.position = Vector2(100, 100)
	add_child_autofree(sword)
	await wait_physics_frames(2)
	sword.active = true
	await wait_physics_frames(3)
	assert_false(is_instance_valid(seed), "cut down")
