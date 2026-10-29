class_name RopeBridge
extends Node2D
## The rope bridge over the western gorge. It broke at the far end and its deck hangs on the far
## side, out of sight. The first look at it brings a shout from across: someone there throws a
## messenger line. Its stone lands on the shelf and slides back towards the edge; the hero has
## to grab it before it drops. Holding the line, the hero hauls the deck across by walking away
## from the edge, slower under its weight. The line must run clear: across a rock it snags and
## nothing comes up until it runs free again. A blow makes the hero let go; the line stays where
## it fell. Once the deck's end has come up between the posts, the hero ties it, and the bridge
## stays tied. Only the shout and the tied bridge are remembered; a haul left half done starts
## again from a new throw.

const HAILED_FLAG := &"far_bank_hailed"
const TIED_FLAG := &"far_bank_bridge_tied"
const GLINT_FLAG := &"forest_echo_found"

enum Stage { FALLEN, WAITING, FLYING, SLIDING, HELD, DROPPED, HAULED, TIED }

## Where the line comes from (the far bank, across the drop) and where it runs over the edge,
## between the posts: both relative to this node.
const FAR_END := Vector2(-44, 4)
const EDGE := Vector2(0, 4)
## Where the stone lands, throw after throw (relative), and how it moves.
const LANDINGS: Array[Vector2] = [Vector2(26, -6), Vector2(18, 28), Vector2(44, 12)]
const FLIGHT_TIME := 0.8
const FLIGHT_HEIGHT := 26.0
const SLIDE_TIME := 3.0
const RETHROW_TIME := 1.4
## The throws only come while the hero is this near the edge.
const THROW_REACH := 150.0
## How far from the edge the hero must haul for the deck's end to come up, and how slow the
## weight makes them.
const HAUL_LENGTH := 160.0
## A creak for every stretch of line hauled in, so the hero hears the deck come up even with the
## gorge out of sight.
const CREAK_EVERY := 20.0
const HAUL_SPEED_SCALE := 0.6
## Where the hero holds the line, from their feet.
const HAND := Vector2(0, -6)
## A dropped line can be picked up again once the hero has stepped this far from it.
const REGRAB_DISTANCE := 14.0
## The deck's full length, from the far side to the edge.
const DECK_LENGTH := 46.0

signal stage_changed(stage: Stage)

@export var deck: Sprite2D
@export var rope: Line2D
## The rope's shadow on the ground, one pixel below it.
@export var rope_shadow: Line2D

var stage: Stage = Stage.FALLEN
## How far the deck has come across, in pixels of line hauled.
var hauled := 0.0
## The last point where the line snagged, while it does.
var snag_point := Vector2.INF
var _adventure: Adventure
var _player: Player
var _landing := 0
var _timer := 0.0
var _flight_from := Vector2.ZERO
var _speed_before := 0.0
var _health_before := 0

@onready var _fallen: Sprite2D = $Fallen
@onready var _posts: Array[Sprite2D] = [$NorthPost, $SouthPost]
@onready var _gap: CollisionShape2D = $Gap/Shape
@onready var _weight: Sprite2D = $Weight
@onready var _catch: Area2D = $Weight/Catch
@onready var _interactable: Interactable = $Interactable
@onready var _throw_sound: AudioStreamPlayer2D = $ThrowSound
@onready var _land_sound: AudioStreamPlayer2D = $LandSound
@onready var _deck_sound: AudioStreamPlayer2D = $DeckSound
@onready var _creak_sound: AudioStreamPlayer2D = $CreakSound
@onready var _snag_sound: AudioStreamPlayer2D = $SnagSound


func _ready() -> void:
	add_to_group(&"adventure")
	_interactable.action = _on_interact
	_catch.body_entered.connect(_on_catch_touched)
	_weight.visible = false
	rope.visible = false
	rope_shadow.visible = false


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	var level := owner as Level
	_player = level.player if level != null else null
	if adventure.has_flag(TIED_FLAG):
		_set_stage(Stage.TIED)
	elif adventure.has_flag(HAILED_FLAG):
		_set_stage(Stage.WAITING)
	else:
		_set_stage(Stage.FALLEN)


func is_tied() -> bool:
	return stage == Stage.TIED


func is_holding_line() -> bool:
	return stage == Stage.HELD


## Where the stone of the line is now (global), while it is out.
func weight_position() -> Vector2:
	return _weight.global_position


func _on_interact(_actor: Node2D) -> String:
	if _adventure == null:
		return ""
	match stage:
		Stage.FALLEN:
			_adventure.set_flag(HAILED_FLAG)
			_set_stage(Stage.WAITING)
			return "WEST_BRIDGE_GLINT_HAIL" if _adventure.has_flag(GLINT_FLAG) else "WEST_BRIDGE_HAIL"
		Stage.HAULED:
			_adventure.set_flag(TIED_FLAG)
			_set_stage(Stage.TIED)
			return "FAR_TIED"
		Stage.TIED:
			return "WEST_BRIDGE_TIED"
		_:
			return "FAR_LINE_HINT"


func _physics_process(delta: float) -> void:
	match stage:
		Stage.WAITING:
			_timer -= delta
			if _timer <= 0.0 and _hero_near():
				_throw()
		Stage.FLYING:
			_timer += delta
			var t := minf(_timer / FLIGHT_TIME, 1.0)
			var to: Vector2 = LANDINGS[_landing]
			_weight.position = _flight_from.lerp(to, t)
			_weight.offset.y = -sin(PI * t) * FLIGHT_HEIGHT - 3.0
			_draw_line([FAR_END, _weight.position + Vector2(0, _weight.offset.y + 3.0)])
			if t >= 1.0:
				_land_sound.play()
				_timer = 0.0
				_set_stage(Stage.SLIDING)
		Stage.SLIDING:
			_timer += delta
			var from: Vector2 = LANDINGS[_landing]
			_weight.position = from.lerp(EDGE, minf(_timer / SLIDE_TIME, 1.0))
			_draw_line([FAR_END, _weight.position])
			if _timer >= SLIDE_TIME:
				# Over the edge and gone: the far side pulls it back in and throws again.
				_landing = (_landing + 1) % LANDINGS.size()
				_timer = RETHROW_TIME
				_set_stage(Stage.WAITING)
		Stage.HELD:
			_haul()
		Stage.DROPPED:
			_draw_line([FAR_END, EDGE, _weight.position])
			if not _catch.monitoring and _player.global_position.distance_to(_weight.global_position) > REGRAB_DISTANCE:
				_catch.monitoring = true


func _hero_near() -> bool:
	return _player != null and not _player.health.is_dead() \
			and to_local(_player.global_position).distance_to(EDGE) <= THROW_REACH


func _throw() -> void:
	_flight_from = FAR_END
	_weight.position = FAR_END
	_timer = 0.0
	_throw_sound.play()
	_set_stage(Stage.FLYING)


func _on_catch_touched(body: Node2D) -> void:
	if body == _player and stage in [Stage.SLIDING, Stage.DROPPED]:
		_set_stage.call_deferred(Stage.HELD)


func _haul() -> void:
	var hand := to_local(_player.global_position) + HAND
	var space := get_world_2d().direct_space_state
	var query := PhysicsRayQueryParameters2D.create(to_global(EDGE), to_global(hand), 1)
	# The line runs out from between the posts, over the closed walkway: neither can catch it.
	query.exclude = [_player.get_rid(), $Posts.get_rid(), $Gap.get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		snag_point = Vector2.INF
		var before := hauled
		hauled = maxf(hauled, hand.distance_to(EDGE))
		if floorf(hauled / CREAK_EVERY) > floorf(before / CREAK_EVERY):
			_creak_sound.play()
		_draw_line([FAR_END, EDGE, hand])
	else:
		if snag_point == Vector2.INF:
			_snag_sound.play()
		snag_point = hit.position
		_draw_line([FAR_END, EDGE, to_local(snag_point), hand])
	_show_deck(hauled / HAUL_LENGTH)
	if hauled >= HAUL_LENGTH:
		_deck_sound.play()
		_set_stage(Stage.HAULED)


func _on_health_changed(current: int, _maximum: int) -> void:
	if current < _health_before and stage == Stage.HELD:
		_weight.position = to_local(_player.global_position)
		_set_stage(Stage.DROPPED)
	_health_before = current


func _set_stage(value: Stage) -> void:
	var was_holding := stage == Stage.HELD
	stage = value
	if was_holding and value != Stage.HELD:
		_let_go()
	_weight.offset.y = -3.0
	_weight.visible = value in [Stage.FLYING, Stage.SLIDING, Stage.DROPPED]
	# Dropped at the hero's feet, the line waits until they step off it before it can be taken.
	_catch.set_deferred(&"monitoring", value == Stage.SLIDING)
	rope.visible = value in [Stage.FLYING, Stage.SLIDING, Stage.HELD, Stage.DROPPED, Stage.HAULED]
	rope_shadow.visible = rope.visible
	snag_point = Vector2.INF
	match value:
		Stage.FALLEN, Stage.WAITING:
			hauled = 0.0
			_show_deck(0.0)
		Stage.HELD:
			_take_line()
		Stage.HAULED:
			_show_deck(1.0)
			_draw_line([FAR_END, EDGE])
		Stage.TIED:
			_show_deck(1.0)
	var tied := value == Stage.TIED
	_fallen.visible = not tied
	for post in _posts:
		post.visible = tied
	_gap.set_deferred(&"disabled", tied)
	set_physics_process(value != Stage.FALLEN and value != Stage.HAULED and not tied)
	stage_changed.emit(value)


func _take_line() -> void:
	_speed_before = _player.max_speed
	_player.max_speed = _speed_before * HAUL_SPEED_SCALE
	_health_before = _player.health.current
	if not _player.health.changed.is_connected(_on_health_changed):
		_player.health.changed.connect(_on_health_changed)


func _let_go() -> void:
	if _player == null:
		return
	_player.max_speed = _speed_before
	if _player.health.changed.is_connected(_on_health_changed):
		_player.health.changed.disconnect(_on_health_changed)


func _show_deck(fraction: float) -> void:
	var length := roundf(DECK_LENGTH * clampf(fraction, 0.0, 1.0))
	deck.visible = length > 0.0
	deck.region_rect = Rect2(0, 0, length, deck.texture.get_height())


func _draw_line(points: Array) -> void:
	var line := PackedVector2Array()
	for point: Vector2 in points:
		line.append(rope.to_local(to_global(point)))
	rope.points = line
	for i in line.size():
		line[i] += Vector2(0, 1)
	rope_shadow.points = line
