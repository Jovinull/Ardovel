class_name Npc
extends StaticBody2D
## A villager to talk to. Says the first of its `lines` whose conditions hold for the current
## adventure, turning to face whoever spoke to them. A line may hand over a gift: it is given only
## if the bag has room (otherwise the villager keeps it for later and the line will be said again).
## A villager who trades (`merchant`, a Commerce id) asks for their goods to be shown once the line
## is read, after `trades_after` (empty: from the start).

## Asks for the trade with `merchant` (Game opens it once the dialogue closes).
signal trade_requested(merchant: StringName)

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
## Commerce id of the goods this villager trades (empty: none).
@export var merchant: StringName
## They trade only once this flag is set (empty: always).
@export var trades_after: StringName

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


## The line this villager would say now, or null. A gift waits while the story has something new to
## say (a line that sets a flag not yet set): it never takes that line's place, only an everyday one's.
func current_line() -> DialogueLine:
	var said: DialogueLine = null
	var gift: DialogueLine = null
	for line in lines:
		if not line.applies(_adventure):
			continue
		if line.gives.is_empty() and line.gives_money <= 0:
			if said == null:
				said = line
		elif gift == null:
			gift = line
	if said != null and _adventure != null and not said.sets.is_empty() and not _adventure.has_flag(said.sets):
		return said
	return gift if gift != null else said


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


## Whether they would trade now.
func trades() -> bool:
	return not merchant.is_empty() and _adventure != null \
			and (trades_after.is_empty() or _adventure.has_flag(trades_after))


func _on_interact(actor: Node2D) -> String:
	var line := current_line()
	var will_trade := trades()
	if line == null:
		if will_trade:
			trade_requested.emit(merchant)
		return ""
	face(actor.global_position - global_position)
	var text := line.text
	if _adventure != null and line.gives_money > 0:
		text = _pay(line)
	elif _adventure != null and not line.gives.is_empty():
		text = _give(line)
	elif _adventure != null:
		_adventure.set_flag(line.sets)
	if will_trade:
		trade_requested.emit(merchant)
	return text


## The line with its payment: the coppers handed over (and the line's flag set) if the purse holds them.
func _pay(line: DialogueLine) -> String:
	if not _adventure.earn(line.gives_money):
		return tr(line.text) + "

" + tr("PICKUP_PURSE_FULL")
	_adventure.set_flag(line.sets)
	return tr(line.text) + "

" + tr("MONEY_RECEIVED") % line.gives_money


## The line with its gift: handed over (and the line's flag set) if it fits in the bag.
func _give(line: DialogueLine) -> String:
	var item := ItemCatalog.find(line.gives)
	var name := tr(item.name_key) if item != null else String(line.gives)
	if not Bag.try_add(_adventure, line.gives, line.gives_count):
		return tr(line.text) + "\n\n" + tr("GIFT_BAG_FULL") % name
	_adventure.set_flag(line.sets)
	var got := tr("GIFT_RECEIVED") % name if line.gives_count == 1 \
			else tr("GIFT_RECEIVED_MANY") % [name, line.gives_count]
	return tr(line.text) + "\n\n" + got


