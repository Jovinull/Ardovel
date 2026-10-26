class_name Shrine
extends StaticBody2D
## The forest wayshrine. The first interaction awakens it (restoring the actor's health) and
## makes it the adventure's checkpoint; afterwards it stays awakened, also across saves, and
## only answers with a short message.

signal awakened

enum State { DORMANT, AWAKENED }

const SPARK := preload("res://fx/awaken_spark.tscn")
const AWAKENED_TEXTURE := preload("res://assets/ardovel/props/shrine_awakened.png")

## Translation keys of the shrine's messages.
@export var awaken_message: String = "SHRINE_AWAKEN"
@export var awakened_message: String = "SHRINE_AWAKENED"
## Adventure flag recording that this shrine is awake.
@export var flag: StringName = &"forest_shrine_awakened"
## Entry of this area that becomes the checkpoint once the shrine is awake.
@export var return_entry: StringName = &"shrine"

var state: State = State.DORMANT
var _adventure: Adventure

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _crystal: Marker2D = $Crystal
@onready var _awaken_sound: AudioStreamPlayer2D = $AwakenSound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact


## Takes the adventure state; a shrine awakened earlier comes back awake, without ceremony.
func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if adventure.has_flag(flag):
		state = State.AWAKENED
		_sprite.texture = AWAKENED_TEXTURE


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
	if _adventure != null:
		_adventure.activate_checkpoint(return_entry)
		_adventure.set_flag(flag)
	awakened.emit()
	return awaken_message
