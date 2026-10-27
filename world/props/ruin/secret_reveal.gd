class_name SecretReveal
extends Area2D
## Darkness over a hidden corner that lifts when the hero steps in. Only the look changes:
## the way in exists all along for whoever finds it.

const FADE_TIME := 0.4

## What hides the corner (a tile layer or sprite drawn above everything).
@export var cover: CanvasItem


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and cover.modulate.a > 0.0:
		create_tween().tween_property(cover, ^"modulate:a", 0.0, FADE_TIME)
