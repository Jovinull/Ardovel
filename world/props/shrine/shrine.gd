class_name Shrine
extends StaticBody2D
## The forest wayshrine. The first interaction awakens it (restoring the actor's health);
## afterwards it stays awakened and only answers with a short message.

signal awakened

enum State { DORMANT, AWAKENED }

const SPARK := preload("res://fx/awaken_spark.tscn")
const AWAKENED_TEXTURE := preload("res://assets/ardovel/props/shrine_awakened.png")

@export_multiline var awaken_message: String = "Uma luz antiga desperta no santuário.\nSuas feridas se fecham."
@export_multiline var awakened_message: String = "O cristal pulsa em silêncio."

var state: State = State.DORMANT

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _crystal: Marker2D = $Crystal
@onready var _awaken_sound: AudioStreamPlayer2D = $AwakenSound


func _ready() -> void:
	_interactable.action = _on_interact


func _on_interact(actor: Node2D) -> String:
	if state == State.AWAKENED:
		return awakened_message
	state = State.AWAKENED
	_sprite.texture = AWAKENED_TEXTURE
	var spark: Node2D = SPARK.instantiate()
	spark.position = _crystal.position
	add_child(spark)
	_awaken_sound.play()
	var actor_health := actor.get(&"health") as Health
	if actor_health != null:
		actor_health.restore_full()
	awakened.emit()
	return awaken_message
