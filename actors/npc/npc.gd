class_name Npc
extends StaticBody2D
## A villager to talk to. Says the first of its `lines` whose conditions hold for the current
## adventure, turning to face whoever spoke to them.

const FRAME_SIZE := 16

## Translation key of the name shown in the dialogue box.
@export var display_name: String
## Pack character sheet (16x16 frames; columns down, up, left, right; idle pose on the first row).
@export var sheet: Texture2D
@export var faceset: Texture2D
## Facing while nobody talks to them.
@export var facing: Vector2 = Vector2.DOWN
## Checked from the top: put the most specific (latest in the story) lines first.
@export var lines: Array[DialogueLine] = []

var _adventure: Adventure
var _walked := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _interactable: Interactable = $Interactable


func _ready() -> void:
	add_to_group(&"adventure")
	_sprite.texture = sheet
	# Pack sheets use 16x16 frames but not all have the same number of rows.
	_sprite.hframes = sheet.get_width() / FRAME_SIZE
	_sprite.vframes = sheet.get_height() / FRAME_SIZE
	_interactable.action = _on_interact
	_interactable.speaker = display_name
	_interactable.portrait = faceset
	face(facing)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure


## The line this villager would say now, or null.
func current_line() -> DialogueLine:
	return DialogueLine.first_that_applies(lines, _adventure)


## Shows the sheet column for `direction` (pack character sheets: down, up, left, right).
func face(direction: Vector2) -> void:
	_sprite.frame = _column(direction)


## One step of a walk towards `point` at `speed`, with the walk cycle of the pack's sheets.
## Waits while the hero or another villager stands in the way. True once there.
func walk_towards(point: Vector2, speed: float, delta: float) -> bool:
	var next := position.move_toward(point, speed * delta)
	if next != position and step_is_clear(next):
		_walked += delta
		_sprite.frame = _column(next - position) + (4 if fmod(_walked, 0.28) >= 0.14 else 0)
		position = next
	return position.distance_to(point) <= 0.1


## A short repeated gesture on the spot (sorting, hammering, scattering grain) facing
## `direction`: the sheet's idle and step rows in turn.
func gesture(direction: Vector2, elapsed: float, period: float = 0.3) -> void:
	_sprite.frame = _column(direction) + (4 if fmod(elapsed, period) >= period * 0.5 else 0)


func step_is_clear(next: Vector2) -> bool:
	var body: CollisionShape2D = $Collision
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = body.shape
	query.transform = Transform2D(0.0, next + body.position)
	query.collision_mask = 3  # World and player bodies.
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()


func _column(direction: Vector2) -> int:
	return ["down", "up", "left", "right"].find(String(Facing.name_of(direction)))


func _on_interact(actor: Node2D) -> String:
	var line := current_line()
	if line == null:
		return ""
	face(actor.global_position - global_position)
	if _adventure != null:
		_adventure.set_flag(line.sets)
	return line.text
