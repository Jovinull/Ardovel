class_name WitchTraveler
extends Npc
## The travelling witch at the halt on the road to Pedrabranca. She draws roads: she walks them
## and sells her maps to travellers; people call her a witch for the hat, and she lets them. Breu,
## her bat, is a child of her scene and never leaves her (Breu). Her frames are 16x20 (the hat rises
## above the others' heads; the style guide's tall-accessory exception). Standing facing the road
## she idles (the hat's tip sways, she blinks). Once she has drawn the stretch the hero saw from the
## high stone, she walks to the board, pins her note and comes back; once the hero has walked off
## after that, she has gone east to walk it herself.

const FRAME_HEIGHT := 20
const IDLE_EVERY := 0.3
## How long she keeps facing whoever spoke to her before turning back to the road.
const LOOK_BACK_AFTER := 3.0
const WALK_SPEED := 30.0
## Her first step towards the board, to one side of where people stand to talk to her.
const AROUND := Vector2(16, -16)

## Her four idle frames facing down (bruxa_idle.png).
@export var idle_sheet: Texture2D
## Where she stands by the fire, and where she stands to pin her note on the board.
@export var camp_spot: Vector2
@export var board_spot: Vector2
## Her note on the board, shown when she has pinned it.
@export var board_note: CanvasItem

var _route: Array[Vector2] = []
var _idle_time := 0.0
var _since_talk := 0.0
var _idling := false
var _pinning := false


func _ready() -> void:
	super._ready()
	_use_walk_sheet()
	_sprite.position = Vector2(0, -FRAME_HEIGHT / 2.0)
	($Prompt as Node2D).position.y = -FRAME_HEIGHT - 12.0  # above the hat
	face(facing)


func bind_adventure(adventure: Adventure) -> void:
	super.bind_adventure(adventure)
	if board_note != null:
		board_note.visible = adventure.has_flag(Blank.DRAWN)
	if adventure.has_flag(Blank.GONE):
		queue_free()  # gone east to walk the stretch; her note stays on the board
		return
	position = camp_spot
	adventure.changed.connect(_refresh)
	var level := owner as Level
	if level != null:
		level.exit_requested.connect(_on_hero_leaves)


func is_pinning() -> bool:
	return _pinning


func is_idling() -> bool:
	return _idling


## Which way she faces (for Breu, who keeps to her other side).
func facing_direction() -> Vector2:
	if _idling:
		return Vector2.DOWN
	return [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT][_sprite.frame % 4]


func face(direction: Vector2) -> void:
	_use_walk_sheet()
	super.face(direction)


func _use_walk_sheet() -> void:
	_idling = false
	_sprite.texture = sheet
	_sprite.hframes = sheet.get_width() / FRAME_SIZE
	_sprite.vframes = sheet.get_height() / FRAME_HEIGHT


func _on_interact(actor: Node2D) -> String:
	_since_talk = 0.0
	return super._on_interact(actor)


func _refresh() -> void:
	if _adventure.has_flag(Blank.DRAWN) and not _pinning and board_note != null and not board_note.visible:
		_pinning = true
		# round by the east side, away from whoever stood talking to her, north of the fire
		_route = [camp_spot + AROUND, board_spot, camp_spot + AROUND, camp_spot]


func _on_hero_leaves(_area: StringName, _entry: StringName) -> void:
	if _adventure.has_flag(Blank.DRAWN):
		_adventure.set_flag(Blank.GONE)


func _physics_process(delta: float) -> void:
	if not _route.is_empty():
		if walk_towards(_route[0], WALK_SPEED, delta):
			var reached: Vector2 = _route.pop_front()
			if reached == board_spot and board_note != null:
				board_note.visible = true
			if _route.is_empty():
				_pinning = false
				face(Vector2.DOWN)
		return
	_since_talk += delta
	if _since_talk < LOOK_BACK_AFTER:
		return
	if not _idling:
		_idling = true
		_sprite.texture = idle_sheet
		_sprite.hframes = 4
		_sprite.vframes = 1
	_idle_time += delta
	_sprite.frame = int(_idle_time / IDLE_EVERY) % 4
