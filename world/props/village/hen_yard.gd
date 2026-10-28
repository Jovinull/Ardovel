class_name HenYard
extends Node2D
## The old coop behind Anselmo's house and Cida's three hens.
##
## Once the village light has kept the hens awake for a night (the hero left the village after
## the ruin's heart woke), they are found loose in the square. Anselmo offers this coop, where
## the roof shades them from the light; when he has mended it, Cida scatters grain at the gate
## and the hero drives the hens in. They stay there from then on.

const HEART_FLAG := &"ruin_heart_awakened"
const NIGHT_FLAG := &"village_beacon_night"
const REPAIRED_FLAG := &"village_coop_repaired"
const SETTLED_FLAG := &"village_hens_settled"
## Where the hens are found in the square.
const LOOSE_SPOTS: Array[Vector2] = [Vector2(196, 172), Vector2(284, 236), Vector2(246, 262)]
const LURE_RADIUS := 52.0
## Inside the fence (local): where penned hens peck about, and where the hero counts as inside.
const PEN := Rect2(14, 39, 54, 10)
const YARD := Rect2(8, 10, 66, 46)

enum GateFrame { OLD, OPEN, NEW }

var _adventure: Adventure
var _gate_opened := false
var _hens: Array[Hen] = []

@onready var _coop: Sprite2D = $Coop/Sprite
@onready var _gate_sprite: Sprite2D = $Gate/Sprite
@onready var _gate_shape: CollisionShape2D = $Gate/Collision
@onready var _inside: Area2D = $Inside
@onready var _grain: Sprite2D = $Grain
@onready var _lure: Marker2D = $Lure
@onready var _mouth: Marker2D = $Mouth


func _ready() -> void:
	add_to_group(&"adventure")
	set_physics_process(false)
	for child in get_children():
		if child is Hen:
			_hens.append(child)
	_inside.body_entered.connect(_on_body_entered)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	var level := owner as Level
	var present := hens_loose() or calling() or settled()
	for index in _hens.size():
		var hen := _hens[index]
		if not present:
			hen.queue_free()
			continue
		hen.hero = level.player if level != null else null
		if settled():
			hen.settle_at(_pen().position + Vector2(8 + 19 * index, 4 + 6 * (index % 2)), _pen())
		else:
			hen.global_position = LOOSE_SPOTS[index]
			hen.reset_physics_interpolation()
	if not present:
		_hens.clear()
	adventure.changed.connect(_show_state)
	_show_state()


func _exit_tree() -> void:
	# A night passes whenever the hero leaves the village once the light shines.
	if _adventure != null and _adventure.has_flag(HEART_FLAG) \
			and not _adventure.has_flag(NIGHT_FLAG):
		_adventure.set_flag(NIGHT_FLAG)


## The hens are out and nobody has a place for them yet.
func hens_loose() -> bool:
	return _adventure != null and _adventure.has_flag(NIGHT_FLAG) \
			and not _adventure.has_flag(REPAIRED_FLAG)


## The coop is ready and the hens still have to go in.
func calling() -> bool:
	return _adventure != null and _adventure.has_flag(REPAIRED_FLAG) and not settled()


func settled() -> bool:
	return _adventure != null and _adventure.has_flag(SETTLED_FLAG)


func hens() -> Array[Hen]:
	return _hens


func nearest_loose_hen(from: Vector2) -> Hen:
	var best: Hen = null
	for hen in _hens:
		if not hen.penned and (best == null
				or from.distance_to(hen.global_position) < from.distance_to(best.global_position)):
			best = hen
	return best


## Anselmo has pulled the old boards off the gate.
func open_gate() -> void:
	_gate_opened = true
	_show_state()


## Cida is at the gate: grain draws the hens that come near its mouth, then in.
func start_grain() -> void:
	_grain.visible = true
	for hen in _hens:
		if not hen.penned:
			hen.lure([_mouth.global_position, _lure.global_position], LURE_RADIUS)


func is_gate_closed() -> bool:
	return not _gate_shape.disabled


func _show_state() -> void:
	var repaired := _adventure.has_flag(REPAIRED_FLAG)
	_coop.frame = 1 if repaired else 0
	if settled():
		# Closed behind the hens, but never with the hero still inside.
		set_physics_process(true)
	elif repaired or _gate_opened:
		_set_gate(GateFrame.OPEN)
	else:
		_set_gate(GateFrame.OLD)


func _physics_process(_delta: float) -> void:
	var level := owner as Level
	if level != null and _yard().has_point(level.player.global_position):
		_set_gate(GateFrame.OPEN)
		return
	_set_gate(GateFrame.NEW)
	_grain.visible = false
	set_physics_process(false)


func _set_gate(frame: GateFrame) -> void:
	_gate_sprite.frame = frame
	_gate_shape.set_deferred(&"disabled", frame == GateFrame.OPEN)


func _on_body_entered(body: Node2D) -> void:
	var hen := body as Hen
	if hen == null or hen.penned or not calling():
		return
	hen.pen(_pen())
	for other in _hens:
		if not other.penned:
			return
	_adventure.set_flag(SETTLED_FLAG)


func _pen() -> Rect2:
	return Rect2(global_position + PEN.position, PEN.size)


func _yard() -> Rect2:
	return Rect2(global_position + YARD.position, YARD.size)
