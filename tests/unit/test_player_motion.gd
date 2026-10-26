extends GutTest

const SPEED := 72.0
const ACCEL := 1200.0
const FRICTION := 1600.0


func _settle(input: Vector2) -> Vector2:
	var v := Vector2.ZERO
	for i in 60:
		v = PlayerMotion.next_velocity(v, input, SPEED, ACCEL, FRICTION, 1.0 / 60.0)
	return v


func test_cardinal_speed_reaches_max() -> void:
	assert_almost_eq(_settle(Vector2.RIGHT).length(), SPEED, 0.001)


func test_diagonal_is_not_faster_than_cardinal() -> void:
	var diagonal := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	assert_eq(diagonal, Vector2.ZERO, "sanity: no input pressed in tests")
	# Raw (1, 1) as a gamepad corner could report it must still be capped at max speed.
	assert_almost_eq(_settle(Vector2(1, 1)).length(), SPEED, 0.001)
	assert_almost_eq(_settle(Vector2(1, 1).normalized()).length(), SPEED, 0.001)


func test_partial_stick_input_moves_slower() -> void:
	assert_almost_eq(_settle(Vector2(0.5, 0)).length(), SPEED * 0.5, 0.001)


func test_reaches_full_speed_quickly_and_stops_quickly() -> void:
	var v := Vector2.ZERO
	for i in 4:
		v = PlayerMotion.next_velocity(v, Vector2.RIGHT, SPEED, ACCEL, FRICTION, 1.0 / 60.0)
	assert_almost_eq(v.x, SPEED, 0.001, "full speed within 4 ticks (~67 ms)")
	for i in 3:
		v = PlayerMotion.next_velocity(v, Vector2.ZERO, SPEED, ACCEL, FRICTION, 1.0 / 60.0)
	assert_eq(v, Vector2.ZERO, "stops within 3 ticks")


func test_facing_follows_cardinal_input() -> void:
	assert_eq(PlayerMotion.next_facing(Vector2.LEFT, Vector2.DOWN), Vector2.LEFT)
	assert_eq(PlayerMotion.next_facing(Vector2.ZERO, Vector2.UP), Vector2.UP, "idle keeps facing")


func test_diagonal_keeps_current_facing_when_it_is_pressed() -> void:
	var diag := Vector2(1, -1).normalized()
	assert_eq(PlayerMotion.next_facing(diag, Vector2.UP), Vector2.UP)
	assert_eq(PlayerMotion.next_facing(diag, Vector2.RIGHT), Vector2.RIGHT)
	assert_eq(PlayerMotion.next_facing(diag, Vector2.DOWN), Vector2.RIGHT, "otherwise falls back to an axis")


func test_facing_names() -> void:
	assert_eq(Facing.name_of(Vector2.DOWN), &"down")
	assert_eq(Facing.name_of(Vector2(-3, 1)), &"left")
	assert_eq(Facing.name_of(Vector2(0.1, -2)), &"up")
