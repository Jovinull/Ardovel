class_name Stamina
extends Node
## Breath: spent by dodging and by blocking, never by attacking (so waiting between swings earns
## nothing). It comes back on its own after a short pause since it was last spent. Not saved: every
## area starts with full breath.

signal changed(current: float, maximum: float)

@export var maximum: float = 100.0
## Breath back per second once recovering.
@export var regen: float = 45.0
## Seconds after spending before breath starts to come back.
@export var regen_delay: float = 0.45

var current: float = 0.0
## Multiplies `regen` (heavier loads breathe slower).
var regen_factor: float = 1.0
var _pause_left: float = 0.0


func _ready() -> void:
	current = maximum


func _physics_process(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		return
	if current < maximum:
		current = minf(current + regen * regen_factor * delta, maximum)
		changed.emit(current, maximum)


## Takes `amount` if there is that much; false (and nothing taken) otherwise.
func spend(amount: float) -> bool:
	if amount > current + 0.001:
		return false
	current = maxf(current - amount, 0.0)
	_pause_left = regen_delay
	changed.emit(current, maximum)
	return true


## Empties what is left (a broken guard), pausing recovery.
func drain() -> void:
	current = 0.0
	_pause_left = regen_delay * 2.0
	changed.emit(current, maximum)


func refill() -> void:
	current = maximum
	_pause_left = 0.0
	changed.emit(current, maximum)


func is_full() -> bool:
	return current >= maximum - 0.001
