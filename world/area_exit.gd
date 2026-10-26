class_name AreaExit
extends Area2D
## A passage out of the area. When the living hero walks into it, `taken` asks the game to
## travel to `target_area`, arriving through its entry `target_entry`.

signal taken(target_area: StringName, target_entry: StringName)

@export var target_area: StringName
@export var target_entry: StringName


func _ready() -> void:
	monitorable = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if player != null and not player.health.is_dead():
		# Deferred: the trip disables the area, which is not allowed inside a physics callback.
		taken.emit.call_deferred(target_area, target_entry)
