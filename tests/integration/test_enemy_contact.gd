extends GutTest
## Bodies of the hero and the Musgoricos: hedgehogs must not end up on top of the hero, and the
## hero must never be pinned in place by them.

const PlayerScene := preload("res://actors/player/player.tscn")
const MusgoricoScene := preload("res://actors/musgorico/musgorico.tscn")

## Both bodies are 10x6 rectangles; more than 1 px of interpenetration counts as overlapping.
const OVERLAP := Vector2(9, 5)

var player: Player


func before_each() -> void:
	player = PlayerScene.instantiate()
	player.position = Vector2(200, 200)
	add_child_autofree(player)
	# Survives the whole fight; long invulnerability means most pricks do not land.
	player.health.max_health = 999
	player.health.restore_full()


func after_each() -> void:
	for action in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		Input.action_release(action)


func _hedgehog(at: Vector2, seed: int) -> Musgorico:
	var musgo: Musgorico = MusgoricoScene.instantiate()
	musgo.position = at
	musgo.rng_seed = seed
	add_child_autofree(musgo)
	return musgo


func _wall(at: Vector2, size: Vector2) -> void:
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	wall.position = at
	add_child_autofree(wall)


func _overlapping(musgo: Musgorico) -> bool:
	var gap := (musgo.global_position - player.global_position).abs()
	return gap.x < OVERLAP.x and gap.y < OVERLAP.y


## Watches `frames` physics frames; returns (frames with any hedgehog overlapping the hero,
## longest unbroken run of such frames).
func _overlap(hedgehogs: Array[Musgorico], frames: int) -> Vector2i:
	var total := 0
	var run := 0
	var longest := 0
	for i in frames:
		await wait_physics_frames(1)
		if hedgehogs.any(func(m: Musgorico) -> bool: return is_instance_valid(m) and _overlapping(m)):
			total += 1
			run += 1
			longest = maxi(longest, run)
		else:
			run = 0
	return Vector2i(total, longest)


func test_lunging_hedgehogs_stop_at_the_hero() -> void:
	var hedgehogs: Array[Musgorico] = [
		_hedgehog(Vector2(240, 200), 11), _hedgehog(Vector2(160, 205), 12), _hedgehog(Vector2(200, 240), 13),
	]
	var overlap := await _overlap(hedgehogs, 480)
	# The hero ignores enemy bodies so they can never pin them; a prick's knockback may carry the
	# hero through another hedgehog, which is pushed clear in the next frame. Before the fix,
	# hedgehogs sat on the hero for half a second at a time.
	assert_lte(overlap.y, 2, "no hedgehog stays on top of the hero")
	assert_lt(overlap.x, 12, "brief crossings only")
	assert_lt(player.health.current, player.health.max_health, "they still reach and hurt the hero")


func test_hedgehogs_stop_at_a_hero_backed_against_a_wall() -> void:
	_wall(Vector2(188, 200), Vector2(8, 64))
	var hedgehogs: Array[Musgorico] = [_hedgehog(Vector2(240, 195), 21), _hedgehog(Vector2(235, 215), 22)]
	var overlap := await _overlap(hedgehogs, 480)
	assert_eq(overlap.x, 0)
	assert_lt(player.health.current, player.health.max_health, "pricked from the side, not only from above")


func test_the_hero_can_always_walk_out_of_a_crowd() -> void:
	_wall(Vector2(188, 200), Vector2(8, 64))
	for musgo: Musgorico in [_hedgehog(Vector2(213, 200), 31), _hedgehog(Vector2(200, 188), 32), _hedgehog(Vector2(200, 212), 33)]:
		# A fixed ring around the hero: bodies that never move (disabling them would remove them from physics).
		musgo.wander_speed = 0.0
		musgo.chase_speed = 0.0
		musgo.lunge_speed = 0.0
		musgo.recoil_speed = 0.0
	await wait_physics_frames(2)
	Input.action_press(&"move_right")
	await wait_physics_frames(30)
	assert_gt(player.position.x, 215.0, "walked through the ring instead of being pinned")
