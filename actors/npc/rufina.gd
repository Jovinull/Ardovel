class_name Rufina
extends Npc
## Mestra Rufina, overseer of Pedrabranca's road crew and of the quarry's new face. Up on the
## terrace she directs the cutting and does not come down at loading time. Once she has heard that
## the stretch past the Laje has only Iara, she calls a halt to the loading and comes down the steps
## to the yard; once she has faced Iara there she goes to the gate and takes the notice down, and
## stays by it.

const TERRACE_SPOT := Vector2(300, 24)
const DOWN_TO_THE_YARD: Array[Vector2] = [Vector2(242, 24), Vector2(240, 40), Vector2(240, 92), Vector2(232, 188)]
const YARD_SPOT := Vector2(226, 196)
const TO_THE_GATE: Array[Vector2] = [Vector2(232, 222), Vector2(300, 228)]
const GATE_SPOT := Vector2(416, 228)
const WALK_SPEED := 36.0
const DIRECT_EVERY := 1.2

var _route: Array[Vector2] = []
var _directing := 0.0


func _ready() -> void:
	super._ready()
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	if adventure.has_flag(Town.FACED) and not adventure.has_flag(Town.NOTICE_DOWN):
		adventure.set_flag(Town.NOTICE_DOWN)  # she was on her way to the gate when the hero left
	if adventure.has_flag(Town.NOTICE_DOWN):
		position = GATE_SPOT
		face(Vector2.UP)
	elif adventure.has_flag(Town.HEARD):
		position = YARD_SPOT
		face(Vector2.RIGHT)
	else:
		position = TERRACE_SPOT
		face(Vector2.DOWN)
	adventure.changed.connect(_refresh)
	set_physics_process(true)


func is_on_the_terrace() -> bool:
	return position == TERRACE_SPOT


func is_in_the_yard() -> bool:
	return position == YARD_SPOT and _route.is_empty()


func is_at_the_gate() -> bool:
	return position == GATE_SPOT and _route.is_empty()


func is_walking() -> bool:
	return not _route.is_empty()


func _on_interact(actor: Node2D) -> String:
	if is_walking():
		return "RUFINA_WALKING"
	return super._on_interact(actor)


func _refresh() -> void:
	if not _route.is_empty():
		return
	if _adventure.has_flag(Town.FACED) and position == YARD_SPOT:
		_route = TO_THE_GATE.duplicate()
		_route.append(GATE_SPOT)
	elif _adventure.has_flag(Town.HEARD) and position == TERRACE_SPOT:
		_route = DOWN_TO_THE_YARD.duplicate()
		_route.append(YARD_SPOT)


func _physics_process(delta: float) -> void:
	if not _route.is_empty():
		if walk_towards(_route[0], WALK_SPEED, delta):
			var reached: Vector2 = _route.pop_front()
			if _route.is_empty():
				if reached == GATE_SPOT:
					_adventure.set_flag(Town.NOTICE_DOWN)
					face(Vector2.UP)
				else:
					face(Vector2.RIGHT)
		return
	if position == TERRACE_SPOT:
		_directing += delta
		gesture(Vector2.DOWN, _directing, DIRECT_EVERY)
