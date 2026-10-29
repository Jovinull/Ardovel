class_name BigStone
extends Node2D
## The biggest stone of the rockfall, which "comes out with more people or more days". It does not
## come out: with the crew's long bar and wedges it is walked aside, a hand's width at a time, until
## people on foot can get by. One person bears down on the bar; Iara, crouched by the stone with a
## wedge, counts ("...") and calls ("!"). Heaving on her call shifts the stone a notch and she packs
## a wedge under it; heaving before it lets the bar slip and the stone settles back a notch; missing
## the call only makes her count again. After the last notch the rest of the day and the night pass
## (a trip to this same area's `stone` entry, with an interlude), and the next morning the way is
## open. The notches are not saved: leaving midway puts the stone back where it was.

signal notch_moved(notch: int)
signal slipped
signal shifted

const NOTCHES := 5
## How far each notch walks the stone (towards the roadside, away from the slope).
const STEP := Vector2(0, 4)
## Iara's counts before each call, one per notch, so the rhythm is learned rather than guessed.
const COUNTS: Array[float] = [1.4, 1.1, 1.6, 1.2, 1.5]
## How long her call lasts: heave within it.
const WINDOW := 0.6
## How long the bar stays borne down after a heave.
const BEAR_DOWN := 0.25
## Holding the bar means standing at its grip; walking further off lets go.
const GRIP_REACH := 22.0
const NIGHT_TEXT := "SPRING_STONE_NIGHT"

enum Phase { IDLE, COUNTING, CALLING }

@onready var _stone: Node2D = $Stone
@onready var _bar: Sprite2D = $Bar
@onready var _bar_area: Interactable = $Bar/Interactable
@onready var _grip: Marker2D = $Bar/Grip
@onready var _wedges: Node2D = $Wedges
@onready var _drag: CanvasItem = $Drag
@onready var _heave_sound: AudioStreamPlayer2D = $HeaveSound
@onready var _slip_sound: AudioStreamPlayer2D = $SlipSound

@export var bar_ready: Texture2D
@export var bar_heave: Texture2D

var _adventure: Adventure
var _notch := 0
var _holder: Node2D
var _phase := Phase.IDLE
var _timer := 0.0
var _bearing := 0.0


func _ready() -> void:
	add_to_group(&"adventure")
	_bar_area.action = _on_bar


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	_show()


func notch() -> int:
	return _notch


func is_shifted() -> bool:
	return _adventure != null and _adventure.has_flag(Spring.SHIFTED)


func is_held() -> bool:
	return _holder != null


func is_calling() -> bool:
	return _phase == Phase.CALLING


func grip_position() -> Vector2:
	return _grip.global_position


func _iara() -> IaraWorker:
	return get_parent().get_node_or_null(^"Iara") as IaraWorker


func _show() -> void:
	var done := is_shifted()
	_stone.position = STEP * (NOTCHES if done else _notch)
	_drag.visible = done
	var ready := _adventure != null and _adventure.has_flag(Spring.READY) and not done
	_bar.visible = ready
	_bar_area.enabled = ready
	for i in _wedges.get_child_count():
		(_wedges.get_child(i) as CanvasItem).visible = i < (NOTCHES if done else _notch)


func _on_bar(actor: Node2D) -> String:
	if _adventure == null or is_shifted() or not _adventure.has_flag(Spring.READY):
		return ""
	if _holder == null:
		_holder = actor
		_count()
		return "SPRING_BAR_TAKE"
	_heave()
	return ""


func _count() -> void:
	_phase = Phase.COUNTING
	_timer = COUNTS[mini(_notch, COUNTS.size() - 1)]
	_signal(&"wait")


func _heave() -> void:
	if _phase == Phase.CALLING:
		_notch += 1
		_bearing = BEAR_DOWN
		_heave_sound.play()
		_show()
		notch_moved.emit(_notch)
		if _notch >= NOTCHES:
			_finish()
			return
		_count()
	else:
		# Too soon: the bar slips off the wedge she has not placed yet.
		if _notch > 0:
			_notch -= 1
		_slip_sound.play()
		_show()
		slipped.emit()
		_signal(&"frown")
		_phase = Phase.COUNTING
		_timer = COUNTS[mini(_notch, COUNTS.size() - 1)] + 0.6


func _finish() -> void:
	_phase = Phase.IDLE
	_holder = null
	_signal(&"")
	_adventure.set_flag(Spring.SHIFTED)
	shifted.emit()
	var level := owner as Level
	if level != null:
		level.interlude = NIGHT_TEXT
		# Deferred: the heave comes from inside the hero's physics step, and the trip freezes the area.
		level.exit_requested.emit.call_deferred(level.area_id, &"stone")


func _let_go() -> void:
	_holder = null
	_phase = Phase.IDLE
	_signal(&"")


func _signal(kind: StringName) -> void:
	var iara := _iara()
	if iara != null:
		iara.show_emote(kind)


func _physics_process(delta: float) -> void:
	if _bearing > 0.0:
		_bearing -= delta
	_bar.texture = bar_heave if _bearing > 0.0 else bar_ready
	if _holder == null:
		return
	if not is_instance_valid(_holder) or _holder.global_position.distance_to(grip_position()) > GRIP_REACH:
		_let_go()
		return
	_timer -= delta
	if _timer > 0.0:
		return
	if _phase == Phase.COUNTING:
		_phase = Phase.CALLING
		_timer = WINDOW
		_signal(&"now")
	else:
		_count()  # the call passed unanswered: she counts again
