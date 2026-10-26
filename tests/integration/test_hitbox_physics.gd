extends GutTest
## Real physics: overlapping areas on the project's collision layers, stepped physics frames.

const PLAYER_HURTBOX_LAYER := 1 << 3
const ENEMY_HURTBOX_LAYER := 1 << 4


func _area(area: Area2D, layer: int, mask: int, at: Vector2) -> Area2D:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	area.add_child(shape)
	area.collision_layer = layer
	area.collision_mask = mask
	area.position = at
	add_child_autofree(area)
	return area


func test_active_swing_hits_overlapping_enemy_once() -> void:
	var health := Health.new()
	health.max_health = 5
	add_child_autofree(health)
	var hurtbox := _area(Hurtbox.new(), ENEMY_HURTBOX_LAYER, 0, Vector2(200, 200)) as Hurtbox
	hurtbox.health = health
	var hitbox := _area(Hitbox.new(), 0, ENEMY_HURTBOX_LAYER, Vector2(206, 200)) as Hitbox
	await wait_physics_frames(3)
	hitbox.active = true
	await wait_physics_frames(6)
	assert_eq(health.current, 4, "one swing, one hit, despite several frames of overlap")


func test_layers_prevent_friendly_fire() -> void:
	var health := Health.new()
	add_child_autofree(health)
	var hurtbox := _area(Hurtbox.new(), PLAYER_HURTBOX_LAYER, 0, Vector2(200, 200)) as Hurtbox
	hurtbox.health = health
	var hitbox := _area(Hitbox.new(), 0, ENEMY_HURTBOX_LAYER, Vector2(200, 200)) as Hitbox
	hitbox.active = true
	await wait_physics_frames(4)
	assert_eq(health.current, health.max_health)
