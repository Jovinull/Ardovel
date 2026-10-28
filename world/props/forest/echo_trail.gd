class_name EchoTrail
extends Node2D
## Carved stones carry the stone's light along the path; after a held breath a glint lights up
## between the trees to the west, flares, drifts toward the canopy and leaves a brief ember.

const HEART_FLAG := &"ruin_heart_awakened"
## Rows of light_traces.png.
const TRACE_REST := 0
const TRACE_REPLY := 1
const TRACE_FLARE := 2
## Frames of distant_glint.png.
const GLINT_KINDLE := 0
const GLINT_FLARE := 1
const GLINT_PEAK := 2
const GLINT_SETTLE := 3
const GLINT_DRIFT := 4
const GLINT_EMBER := 5
## Where the glint appears (the gap between two trees) and where it fades, at the canopy's edge.
const GLINT_START := Vector2(136, 222)
const GLINT_AWAY := Vector2(113, 211)
const GLINT_TIME := 1.45
const DRIFT_TIME := 0.8

## Sorted with the trees (outside this node), never drawn over their canopies.
@export var glint: Sprite2D

var _adventure: Adventure
var _sequence: Tween


func _ready() -> void:
	add_to_group(&"adventure")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_show_state)
	_show_state()


func _show_state() -> void:
	visible = _adventure.has_flag(HEART_FLAG)


func is_replying() -> bool:
	return _sequence != null and _sequence.is_running()


func flash_reply() -> void:
	if not visible:
		return
	if _sequence != null:
		_sequence.kill()
	_sequence = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	# The light leaves the stone along the marks: nearest first, each one flaring in turn.
	var traces: Array[Sprite2D] = [$TraceWest, $TraceMiddle, $TraceEast]
	for index in traces.size():
		var start := 0.15 + index * 0.22
		_at(start, _show_trace.bind(traces[index], TRACE_REPLY))
		_at(start + 0.12, _show_trace.bind(traces[index], TRACE_FLARE))
		_at(start + 0.36, _show_trace.bind(traces[index], TRACE_REPLY))
		_at(start + 0.6, _show_trace.bind(traces[index], TRACE_REST))
	# A held breath, then something far away lights up, pulses and moves off.
	var t := GLINT_TIME
	_at(t, _kindle_glint)
	for step: Array in [[0.12, GLINT_FLARE], [0.12, GLINT_PEAK], [0.24, GLINT_SETTLE],
			[0.16, GLINT_FLARE]]:
		t += step[0]
		_at(t, _show_glint.bind(step[1]))
	# It starts moving while still bright, so the eye can follow it, and dims on the way.
	t += 0.2
	_sequence.tween_property(glint, ^"position", GLINT_AWAY, DRIFT_TIME).set_delay(t)
	_at(t + DRIFT_TIME * 0.45, _show_glint.bind(GLINT_DRIFT))
	t += DRIFT_TIME
	for step: Array in [[0.0, GLINT_EMBER], [0.25, -1], [0.1, GLINT_EMBER], [0.15, -1]]:
		t += step[0]
		_at(t, _show_glint.bind(step[1]))


func _at(time: float, callback: Callable) -> void:
	_sequence.tween_callback(callback).set_delay(time)


func _show_trace(sprite: Sprite2D, row: int) -> void:
	sprite.region_rect.position.y = row * 16


func _kindle_glint() -> void:
	glint.position = GLINT_START
	glint.reset_physics_interpolation()
	_show_glint(GLINT_KINDLE)
	$DistantSound.play()


## Shows `frame` of the glint, or hides it for -1.
func _show_glint(frame: int) -> void:
	glint.visible = frame >= 0
	if frame >= 0:
		glint.frame = frame
