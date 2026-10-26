class_name GuardianStatue
extends StaticBody2D
## The village's old guardian. Moss-covered and empty-handed while the forest shrine sleeps;
## once the shrine is awake the statue is clean and holds a glowing orb again, for good.
## The first time the restored statue comes into view, its change is marked with a spark.

const SPARK := preload("res://fx/awaken_spark.tscn")
## Regions of the pack's TilesetHouse.png.
const DORMANT_REGION := Rect2(80, 304, 32, 32)
const RESTORED_REGION := Rect2(48, 240, 32, 32)
## Delay before the spark, so it never plays under the fade of an arriving area.
const CELEBRATE_DELAY := 0.4

## Adventure flag that restores the statue.
@export var flag: StringName = &"forest_shrine_awakened"
## Set once the restored statue has been seen.
@export var seen_flag: StringName = &"village_statue_seen_restored"
@export_multiline var dormant_text: String = "Uma velha estátua coberta de musgo.\nAs mãos estão vazias, como se esperassem algo."
@export_multiline var restored_text: String = "A guardiã voltou a segurar a luz.\nO musgo secou e a pedra parece nova."

var restored: bool = false
var _adventure: Adventure
var _awaiting_first_sight: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable
@onready var _orb: Marker2D = $Orb
@onready var _sound: AudioStreamPlayer2D = $RestoreSound


func _ready() -> void:
	add_to_group(&"adventure")
	set_process(false)
	_interactable.action = func(_actor: Node2D) -> String: return restored_text if restored else dormant_text
	_show()


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	restored = adventure.has_flag(flag)
	_show()
	_awaiting_first_sight = restored and not adventure.has_flag(seen_flag)
	set_process(_awaiting_first_sight)


## True until the restored statue has been seen once.
func is_waiting_to_be_seen() -> bool:
	return _awaiting_first_sight


func _process(_delta: float) -> void:
	# Polled rather than using VisibleOnScreenNotifier2D, which depends on the renderer and stays
	# silent in headless runs. Only runs until the statue is first seen.
	var on_screen := get_global_transform_with_canvas().origin
	if get_viewport_rect().grow(-8.0).has_point(on_screen):
		_on_first_sight()


func _show() -> void:
	_sprite.region_rect = RESTORED_REGION if restored else DORMANT_REGION


func _on_first_sight() -> void:
	_awaiting_first_sight = false
	set_process(false)
	_adventure.set_flag(seen_flag)
	get_tree().create_timer(CELEBRATE_DELAY).timeout.connect(_celebrate)


func _celebrate() -> void:
	var spark: Node2D = SPARK.instantiate()
	spark.position = _orb.position
	add_child(spark)
	_sound.play()
