class_name BucketGate
extends StaticBody2D
## An iron grate hung on a counterweight: raised while its bucket is fed (or its weigh plate holds
## the cart), down otherwise. A gate held by a flag stays raised for good (the cart sent; the mouth's
## gate wedged by the hero once through). Closed it blocks; frame 0 closed, 1 raised.

@export var bucket: WaterNode
@export var plate: WeighPlate
## Raised for good while this flag is set (empty: none).
@export var held_by: StringName
## Walking through this area while the gate is up sets `held_by` (the hero wedges it open).
@export var wedge_area: Area2D

var _adventure: Adventure
var _open := false
var _ready_done := false

@onready var _sprite: Sprite2D = $Sprite
@onready var _shape: CollisionShape2D = $Collision
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	if bucket != null:
		bucket.wetness_changed.connect(func(_wet: bool) -> void: _refresh(true))
	if plate != null:
		plate.pressed.connect(_refresh.bind(true))
	if wedge_area != null:
		wedge_area.body_entered.connect(_on_wedge_area_entered)
	_refresh.call_deferred(false)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_refresh.bind(true))
	_refresh.call_deferred(false)


func is_open() -> bool:
	return _open


func should_be_open() -> bool:
	if _adventure != null and not held_by.is_empty() and _adventure.has_flag(held_by):
		return true
	if plate != null and plate.is_pressed():
		return true
	return bucket != null and bucket.is_wet()


func _refresh(animate: bool) -> void:
	if not is_inside_tree():
		return
	var next := should_be_open()
	if next == _open and _ready_done:
		return
	_ready_done = true
	_open = next
	_sprite.frame = 1 if next else 0
	_shape.set_deferred(&"disabled", next)
	if animate:
		_sound.play()


func _on_wedge_area_entered(body: Node2D) -> void:
	if body is Player and _open and _adventure != null and not held_by.is_empty():
		_adventure.set_flag(held_by)
