class_name PlayerMotion
## Pure movement rules of the player, kept free of nodes so they can be tested directly.


## Velocity after one step: accelerate towards `input * max_speed`, or brake when idle.
## `input` comes from Input.get_vector, so diagonals are already limited to length 1.
static func next_velocity(velocity: Vector2, input: Vector2, max_speed: float,
		acceleration: float, friction: float, delta: float) -> Vector2:
	var target := input.limit_length(1.0) * max_speed
	var rate := acceleration if input != Vector2.ZERO else friction
	return velocity.move_toward(target, rate * delta)


## Facing for the current input. While moving diagonally the current facing is kept if it is
## one of the two pressed directions, so sprites do not flicker between axes.
static func next_facing(input: Vector2, current: Vector2) -> Vector2:
	if input == Vector2.ZERO:
		return current
	var horizontal := Vector2(signf(input.x), 0.0)
	var vertical := Vector2(0.0, signf(input.y))
	if horizontal != Vector2.ZERO and vertical != Vector2.ZERO:
		if current == horizontal or current == vertical:
			return current
	return Facing.cardinal(input)
