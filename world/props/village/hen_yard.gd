class_name HenYard
extends Node2D
## The old coop behind Anselmo's house and Cida's three hens.
##
## The hens live in Cida's pen behind the shop. Once the village light has kept them awake for
## a night (the hero walked out of the village after the ruin's heart woke), they have jumped
## out and are found loose in the square, the pen left open. Anselmo offers this coop, where
## the roof shades them from the light; when he has mended it, Cida scatters grain at the gate
## and the hero drives the hens in. They stay there from then on.

const HEART_FLAG := &"ruin_heart_awakened"
const NIGHT_FLAG := &"village_beacon_night"
const REPAIRED_FLAG := &"village_coop_repaired"
const SETTLED_FLAG := &"village_hens_settled"
## Each hen driven into the coop is remembered on its own, so it never has to be driven again.
const IN_FLAGS := {&"HenWhite": &"village_hen_white_in", &"HenBrown": &"village_hen_brown_in",
		&"HenBlack": &"village_hen_black_in"}
## Where the hens are found in the square.
const LOOSE_SPOTS: Array[Vector2] = [Vector2(196, 172), Vector2(284, 236), Vector2(246, 262)]
const LURE_RADIUS := 52.0
## Inside the fence (local): where penned hens peck about, and where the hero counts as inside.
const PEN := Rect2(14, 39, 54, 10)
const YARD := Rect2(8, 10, 66, 46)

enum GateFrame { OLD, OPEN, NEW }

## Cida's own pen, where the hens live until they flee the light.
@export var home_pen: HenPen

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
	# All three remembered but the event not marked done (saved in between): it is done.
	if calling() and _hens.all(func(hen: Hen) -> bool: return adventure.has_flag(IN_FLAGS[hen.name])):
		adventure.set_flag(SETTLED_FLAG)
	var level := owner as Level
	for index in _hens.size():
		var hen := _hens[index]
		hen.hero = level.player if level != null else null
		if is_in_coop(hen):
			hen.settle_at(_pen().position + Vector2(8 + 19 * index, 4 + 6 * (index % 2)), _pen())
		elif hens_loose() or calling():
			hen.global_position = LOOSE_SPOTS[index]
			hen.reset_physics_interpolation()
		elif home_pen != null:
			# Before the light kept them awake: at home in Cida's pen.
			var home := home_pen.inside()
			hen.settle_at(home.position + Vector2(4 + 16 * index, 6 + 6 * (index % 2)), home)
	if home_pen != null:
		home_pen.show_open(adventure.has_flag(NIGHT_FLAG))
	if level != null:
		level.exit_requested.connect(_on_hero_walks_out)
	adventure.changed.connect(_show_state)
	_show_state()


## The night passes while the hero is away: only when they walk out of the village through its
## arch, after a visit under the new light. Unloading the village for any other reason (title,
## loading, quitting, a restart) is not a night.
func _on_hero_walks_out(_area: StringName, _entry: StringName) -> void:
	if _adventure.has_flag(HEART_FLAG) and not _adventure.has_flag(NIGHT_FLAG):
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


## Whether `hen` has been driven into the coop (all of them, for saves from before each hen
## was remembered on its own).
func is_in_coop(hen: Hen) -> bool:
	return settled() or _adventure.has_flag(IN_FLAGS[hen.name])


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
	_adventure.set_flag(IN_FLAGS[hen.name])
	for other in _hens:
		if not other.penned:
			return
	# In the same change as the last hen's own flag, so both are saved together.
	_adventure.set_flag(SETTLED_FLAG)


func _pen() -> Rect2:
	return Rect2(global_position + PEN.position, PEN.size)


func _yard() -> Rect2:
	return Rect2(global_position + YARD.position, YARD.size)
