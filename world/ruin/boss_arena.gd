class_name BossArena
extends Node
## A boss's hall (the ruin's warden, the vein's gnawer). When the hero walks in, the way back
## closes and the fight starts; beating the boss sets `flag` (once), which opens the way on and keeps
## the boss gone for good, and (if there is a `light_target`) its light flies off there. A fall in
## the middle of the fight just leaves: coming back finds the boss whole and the door open, as
## before. The boss is any node with `health`, `wake(hero)` and a `defeated` signal; the seal any
## node with `open()` and `close()`.

signal fight_started
signal fight_won

const SPIRIT := preload("res://actors/root_warden/warden_light.tscn")

@export var flag: StringName = &"ruin_warden_defeated"
@export var warden: Node2D
## The way back (roots, a door), closed while the fight lasts.
@export var entrance_seal: Node
## The hall's floor: stepping in starts the fight.
@export var trigger: Area2D
## Where the warden's light goes when it falls (the ruin's heart; none: no light).
@export var light_target: Node2D
@export var music: AudioStream
## Translation key of the name over the boss bar.
@export var boss_name: String = "BOSS_ROOT_WARDEN"
## While the fight lasts the camera keeps inside this rect (global; empty: it follows as everywhere),
## so a boss across the hall is never fought off screen.
@export var camera_rect: Rect2

var _camera: Camera2D
var _limits: Array[int] = []

var _adventure: Adventure
var _fighting: bool = false


func _ready() -> void:
	add_to_group(&"adventure")
	trigger.body_entered.connect(_on_body_entered)
	warden.connect(&"defeated", _on_warden_defeated)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if is_won():
		warden.queue_free()


func is_won() -> bool:
	return _adventure != null and _adventure.has_flag(flag)


func is_fighting() -> bool:
	return _fighting


## The boss's health (for the boss bar).
func boss_health() -> Health:
	return warden.get(&"health") as Health


func _on_body_entered(body: Node2D) -> void:
	var hero := body as Player
	if hero == null or _fighting or is_won() or not is_instance_valid(warden):
		return
	_fighting = true
	_frame_camera(hero.camera)
	entrance_seal.call(&"close")
	warden.call(&"wake", hero)
	fight_started.emit()


func _on_warden_defeated() -> void:
	_fighting = false
	if _adventure != null:
		_adventure.set_flag(flag)
	entrance_seal.call(&"open")
	_release_camera()
	if light_target != null:
		var light: Node2D = SPIRIT.instantiate()
		light.global_position = warden.global_position + Vector2(0, -24)
		light.set(&"target", light_target.global_position)
		warden.get_parent().add_child(light)
	warden.queue_free()
	fight_won.emit()


func _frame_camera(camera: Camera2D) -> void:
	if not camera_rect.has_area() or camera == null:
		return
	_camera = camera
	_limits = [camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom]
	camera.limit_left = int(camera_rect.position.x)
	camera.limit_top = int(camera_rect.position.y)
	camera.limit_right = int(camera_rect.end.x)
	camera.limit_bottom = int(camera_rect.end.y)


func _release_camera() -> void:
	if not is_instance_valid(_camera) or _limits.is_empty():
		return
	_camera.limit_left = _limits[0]
	_camera.limit_top = _limits[1]
	_camera.limit_right = _limits[2]
	_camera.limit_bottom = _limits[3]
	_limits.clear()


## Whether the camera is held to the hall now.
func is_framing() -> bool:
	return not _limits.is_empty()
