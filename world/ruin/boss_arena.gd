class_name BossArena
extends Node
## The warden's hall. When the hero walks in, the roots close the way back and the fight
## starts; beating the warden sets `flag` (once), which opens the way on and keeps the warden
## gone for good, and its light flies off towards the ruin's heart. A fall in the middle of the
## fight just leaves: coming back finds the warden whole and the door open, as before.

signal fight_started
signal fight_won

const SPIRIT := preload("res://actors/root_warden/warden_light.tscn")

@export var flag: StringName = &"ruin_warden_defeated"
@export var warden: RootWarden
## The roots behind the hero, closed while the fight lasts.
@export var entrance_seal: RootSeal
## The hall's floor: stepping in starts the fight.
@export var trigger: Area2D
## Where the warden's light goes when it falls (the ruin's heart).
@export var light_target: Node2D
@export var music: AudioStream
## Translation key of the name over the boss bar.
@export var boss_name: String = "BOSS_ROOT_WARDEN"

var _adventure: Adventure
var _fighting: bool = false


func _ready() -> void:
	add_to_group(&"adventure")
	trigger.body_entered.connect(_on_body_entered)
	warden.defeated.connect(_on_warden_defeated)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if is_won():
		warden.queue_free()


func is_won() -> bool:
	return _adventure != null and _adventure.has_flag(flag)


func is_fighting() -> bool:
	return _fighting


func _on_body_entered(body: Node2D) -> void:
	var hero := body as Player
	if hero == null or _fighting or is_won() or not is_instance_valid(warden):
		return
	_fighting = true
	entrance_seal.close()
	warden.wake(hero)
	fight_started.emit()


func _on_warden_defeated() -> void:
	_fighting = false
	if _adventure != null:
		_adventure.set_flag(flag)
	entrance_seal.open()
	var light: Node2D = SPIRIT.instantiate()
	light.global_position = warden.global_position + Vector2(0, -24)
	light.set(&"target", light_target.global_position)
	warden.get_parent().add_child(light)
	warden.queue_free()
	fight_won.emit()
