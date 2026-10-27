extends Node2D
## The light the warden kept: when it falls, the light drifts away towards the ruin's heart,
## showing the hero where to go, and fades there.

@export var travel_time: float = 2.2

var target: Vector2

@onready var _sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	_sprite.play(&"float")
	var tween := create_tween()
	tween.tween_property(self, ^"global_position", target, travel_time) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, ^"modulate:a", 0.0, 0.4)
	tween.tween_callback(queue_free)
