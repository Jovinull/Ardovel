class_name MineCart
extends StaticBody2D
## The loaded cart the miners left on its rails. Knocking its chock out (interacting) sends it
## rolling to the rails' end, over the bare trestle no one can walk on; there it stands on the weigh
## plate for good (`flag`). Anyone on the rails in its way is shoved aside (no harm). It never rolls
## back: the rails run downhill.

const SPEED := 64.0

## The rails' bends and end, in global coordinates (the cart starts where it stands).
@export var path: PackedVector2Array = PackedVector2Array()
@export var plate: WeighPlate
@export var flag: StringName = &"vein_cart_sent"

var _adventure: Adventure
var _rolling := false
var _next := 0

@onready var _interactable: Interactable = $Interactable
@onready var _sound: AudioStreamPlayer2D = $Sound
@onready var _shape: CollisionShape2D = $Collision


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact
	set_physics_process(false)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if adventure.has_flag(flag) and not path.is_empty():
		global_position = path[path.size() - 1]
		_arrive()


func is_rolling() -> bool:
	return _rolling


func is_at_end() -> bool:
	return not path.is_empty() and global_position.is_equal_approx(path[path.size() - 1])


func push() -> bool:
	if _rolling or is_at_end() or path.is_empty():
		return false
	_rolling = true
	_next = 0
	_interactable.enabled = false
	_shape.set_deferred(&"disabled", true)
	_sound.play()
	set_physics_process(true)
	return true


func _on_interact(_actor: Node2D) -> String:
	return "VEIN_CART_PUSHED" if push() else ""


func _physics_process(delta: float) -> void:
	var step := SPEED * delta
	while step > 0.0 and _next < path.size():
		var to := path[_next] - global_position
		if to.length() <= step:
			global_position = path[_next]
			step -= to.length()
			_next += 1
		else:
			global_position += to.normalized() * step
			step = 0.0
	var level := Level.containing(self)
	if level != null and level.player != null and level.player.global_position.distance_to(global_position) < 10.0:
		level.player.bump(global_position, 120.0)
	if _next >= path.size():
		set_physics_process(false)
		_rolling = false
		_sound.stop()
		_shape.set_deferred(&"disabled", false)
		_arrive()
		if _adventure != null:
			_adventure.set_flag(flag)


func _arrive() -> void:
	_interactable.enabled = false
	if plate != null:
		plate.press()
