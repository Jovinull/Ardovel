class_name RootSpike
extends Node2D
## One of the warden's root spikes: the floor cracks first (the warning), then a root bursts
## out, hurting whoever stands there while it is up, and sinks back.

## Seconds the cracks show before the root comes out.
@export var warning_time: float = 0.8
## Seconds the root stays up (and dangerous).
@export var up_time: float = 0.35

@onready var _warning: AnimatedSprite2D = $Warning
@onready var _spike: AnimatedSprite2D = $Spike
@onready var _hitbox: Hitbox = $Hitbox
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	_spike.hide()
	_warning.play(&"warn")
	_run()


func _run() -> void:
	await get_tree().create_timer(warning_time, false, true).timeout
	_warning.hide()
	_spike.show()
	_spike.play(&"erupt")
	_sound.play()
	_hitbox.active = true
	await get_tree().create_timer(up_time, false, true).timeout
	_hitbox.active = false
	_spike.play(&"sink")
	await _spike.animation_finished
	queue_free()
