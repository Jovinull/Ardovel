class_name AnselmoHelper
extends Npc
## Anselmo keeps his word: once he has offered his mother's old coop he walks behind his house,
## frees the gate that was nailed shut, mends the roof and walks back to his door. If Cida has
## firewood at her stall by then, he first walks there and takes two logs from her pile (it
## shrinks as he lifts them), carrying them over his head to the coop.

const OFFERED_FLAG := &"village_coop_offered"
const REPAIRED_FLAG := &"village_coop_repaired"
## Cida's firewood (once the forest path is open) gives the roof its new wood.
const CIDA_WOOD_FLAG := &"cida_path_acknowledged"
const WOOD_USED_FLAG := &"village_coop_wood_from_cida"
const HAMMER := preload("res://assets/ninja_adventure/Audio/Sounds/Hit & Impact/Hit1.wav")
const SPEED := 32.0
const TO_GATE: Array[Vector2] = [Vector2(172, 182), Vector2(172, 116), Vector2(88, 116)]
## Down past the corner of the red house and along the square's south edge to the front of
## Cida's pile (well clear of where Cida stands in the square at night), and from there back
## the same way to the coop's gate.
const TO_STALL: Array[Vector2] = [Vector2(172, 200), Vector2(176, 262), Vector2(200, 300),
		Vector2(262, 306), Vector2(352, 318), Vector2(410, 318)]
const STALL_TO_GATE: Array[Vector2] = [Vector2(352, 318), Vector2(262, 306), Vector2(200, 300),
		Vector2(176, 262), Vector2(172, 200), Vector2(172, 116), Vector2(88, 116)]
const TAKE_TIME := 1.2
## Where the logs ride while he carries them: over his head.
const CARRIED_AT := Vector2(0, -21)
const INTO_YARD: Array[Vector2] = [Vector2(88, 90), Vector2(62, 89)]
const BACK_HOME: Array[Vector2] = [Vector2(88, 90), Vector2(88, 116), Vector2(172, 116),
		Vector2(172, 182), Vector2(150, 190)]
const GATE_TIME := 1.2
const ROOF_TIME := 2.4
const BLOW_EVERY := 0.6

enum Task { NONE, TO_STALL, TAKE_WOOD, TO_GATE, GATE, INTO_YARD, ROOF, HOME }

var _task := Task.NONE
var _route: Array[Vector2] = []
var _work := 0.0
var _blows := 0
var _yard: HenYard
var _hammer: AudioStreamPlayer2D
var _carried: Sprite2D


func _ready() -> void:
	super._ready()
	set_physics_process(false)
	_hammer = AudioStreamPlayer2D.new()
	_hammer.stream = HAMMER
	_hammer.volume_db = -10.0
	add_child(_hammer)
	_carried = Sprite2D.new()
	_carried.texture = preload("res://assets/ardovel/forest/wood_carried.png")
	_carried.position = CARRIED_AT
	_carried.visible = false
	add_child(_carried)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	_yard = get_parent().get_node_or_null(^"HenYard") as HenYard
	adventure.changed.connect(_check_offer)
	_check_offer()


func is_working() -> bool:
	return _task != Task.NONE


func is_carrying_wood() -> bool:
	return _carried.visible


func _check_offer() -> void:
	if _task != Task.NONE or _yard == null:
		return
	if _adventure.has_flag(OFFERED_FLAG) and not _adventure.has_flag(REPAIRED_FLAG):
		if _adventure.has_flag(CIDA_WOOD_FLAG) and not _adventure.has_flag(WOOD_USED_FLAG):
			_begin(Task.TO_STALL, TO_STALL)
		else:
			_begin(Task.TO_GATE, TO_GATE)


func _begin(task: Task, route: Array[Vector2]) -> void:
	_task = task
	_route = route.duplicate()
	_work = 0.0
	_blows = 0
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	match _task:
		Task.TO_STALL, Task.TO_GATE, Task.INTO_YARD, Task.HOME:
			if walk_towards(_route[0], SPEED, delta):
				_route.pop_front()
				if _route.is_empty():
					_arrive()
		Task.TAKE_WOOD:
			_work += delta
			gesture(Vector2.UP, _work, TAKE_TIME)
			if _work >= TAKE_TIME:
				face(Vector2.UP)
				_adventure.set_flag(WOOD_USED_FLAG)
				_carried.visible = true
				_begin(Task.TO_GATE, STALL_TO_GATE)
		Task.GATE:
			if _hammer_at(Vector2.UP, GATE_TIME, delta):
				_yard.open_gate()
				_begin(Task.INTO_YARD, INTO_YARD)
		Task.ROOF:
			if _hammer_at(Vector2.UP, ROOF_TIME, delta):
				_adventure.set_flag(REPAIRED_FLAG)
				_begin(Task.HOME, BACK_HOME)


func _arrive() -> void:
	match _task:
		Task.TO_STALL:
			_task = Task.TAKE_WOOD
		Task.TO_GATE:
			# He sets the logs down by the gate before he starts on it.
			_carried.visible = false
			_task = Task.GATE
		Task.INTO_YARD:
			_task = Task.ROOF
		Task.HOME:
			_task = Task.NONE
			face(facing)
			set_physics_process(false)


## Hammers facing `direction`; true once `duration` has passed.
func _hammer_at(direction: Vector2, duration: float, delta: float) -> bool:
	_work += delta
	gesture(direction, _work, BLOW_EVERY)
	if int(_work / BLOW_EVERY) > _blows:
		_blows += 1
		_hammer.play()
	if _work < duration:
		return false
	face(direction)
	return true
