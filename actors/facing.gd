class_name Facing
## Four-way facing used by sprites drawn in down/up/left/right sheets.

const NAMES := {Vector2i.DOWN: &"down", Vector2i.UP: &"up", Vector2i.LEFT: &"left", Vector2i.RIGHT: &"right"}


## Nearest cardinal direction of `v`; horizontal wins exact diagonals. ZERO stays ZERO.
static func cardinal(v: Vector2) -> Vector2:
	if v == Vector2.ZERO:
		return Vector2.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector2.RIGHT if v.x > 0.0 else Vector2.LEFT
	return Vector2.DOWN if v.y > 0.0 else Vector2.UP


## Animation suffix ("down", "up", ...) for a cardinal direction.
static func name_of(direction: Vector2) -> StringName:
	return NAMES.get(Vector2i(cardinal(direction)), &"down")
