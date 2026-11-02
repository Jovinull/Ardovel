class_name WaterChannel
extends WaterNode
## A stone-lined channel (or the pool): running water while wet, a mud bed while dry. Wet, it cuts
## the way (a body on the world layer); dry, it is walked across. Water coming back pushes the hero
## (and creatures in the group "vein_walkers") standing in it to the nearest bank, so nobody is ever caught inside. Its eels (Mucum) live in it.

const FRAME_TIME := 0.25
const WORLD_LAYER := 1

enum Kind { EAST_WEST, NORTH_SOUTH, WIDE }

@export var kind: Kind = Kind.EAST_WEST
## Size in pixels (whole tiles), from the node's position (its top-left corner).
@export var size: Vector2 = Vector2(64, 16)
## A footbridge across an east-west channel, 16 px wide, this far from its west end (negative: none):
## the water runs under it and the hero walks over it.
@export var bridge_at: float = -1.0

var _wet_frames: Array[Texture2D] = []
var _dry: Texture2D
var _frame := 0
var _clock := 0.0
var _patch: NinePatchRect
var _body: StaticBody2D
var _shape: CollisionShape2D
var _shapes: Array[CollisionShape2D] = []


func _ready() -> void:
	var base := "res://assets/ardovel/vein/"
	var stem: String = ["channel_h", "channel_v", "pool"][kind]
	_wet_frames = [load(base + stem + "_wet_0.png"), load(base + stem + "_wet_1.png")]
	_dry = load(base + stem + "_dry.png")
	_patch = NinePatchRect.new()
	_patch.name = "Water"
	_patch.size = size
	_patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_patch.axis_stretch_vertical = NinePatchRect.AXIS_STRETCH_MODE_TILE
	_patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == Kind.WIDE:
		for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
			_patch.set_patch_margin(side, 16)
	add_child(_patch)
	_body = StaticBody2D.new()
	_body.name = "Body"
	_body.collision_layer = WORLD_LAYER
	_body.collision_mask = 0
	# A wet channel stops feet at its lining (two pixels in), not at the first pixel of stone.
	var spans: Array[Rect2] = [Rect2(Vector2(2, 2), size - Vector2(4, 4))]
	if bridge_at >= 0.0 and kind == Kind.EAST_WEST:
		spans = [Rect2(2, 2, bridge_at - 2, size.y - 4), Rect2(bridge_at + 16, 2, size.x - bridge_at - 18, size.y - 4)]
	for span in spans:
		if span.size.x <= 0.0:
			continue
		var col := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = span.size
		col.shape = rect
		col.position = span.get_center()
		_body.add_child(col)
		_shapes.append(col)
	_shape = _shapes[0]
	add_child(_body)
	super._ready()


func _process(delta: float) -> void:
	if _shown != 1:
		return
	_clock += delta
	if _clock >= FRAME_TIME:
		_clock = 0.0
		_frame = 1 - _frame
		_patch.texture = _wet_frames[_frame]


## The channel's area in global coordinates.
func rect() -> Rect2:
	return Rect2(global_position, size)


## The point of the channel's middle line nearest `point` (where an eel surfaces).
func nearest_on_line(point: Vector2) -> Vector2:
	var r := rect()
	if kind == Kind.NORTH_SOUTH:
		return Vector2(r.get_center().x, clampf(point.y, r.position.y + 6, r.end.y - 6))
	if kind == Kind.EAST_WEST:
		return Vector2(clampf(point.x, r.position.x + 6, r.end.x - 6), r.get_center().y)
	return Vector2(clampf(point.x, r.position.x + 8, r.end.x - 8), clampf(point.y, r.position.y + 8, r.end.y - 8))


func _show(wet: bool, _animate: bool) -> void:
	_patch.texture = _wet_frames[_frame] if wet else _dry
	for col in _shapes:
		col.set_deferred(&"disabled", not wet)
	if wet:
		_push_out.call_deferred()


## Moves whoever stands in the channel to the nearest bank.
func _push_out() -> void:
	var r := rect().grow(2)
	var bridge := Rect2(global_position + Vector2(bridge_at, 0), Vector2(16, size.y)) if bridge_at >= 0.0 else Rect2()
	var walkers: Array = get_tree().get_nodes_in_group(&"vein_walkers")
	var level := Level.containing(self)
	if level != null and level.player != null:
		walkers.append(level.player)
	for node in walkers:
		var body := node as Node2D
		if body == null or not r.has_point(body.global_position) or bridge.has_point(body.global_position):
			continue
		var p := body.global_position
		var options := [Vector2(r.position.x - 6, p.y), Vector2(r.end.x + 6, p.y),
				Vector2(p.x, r.position.y - 4), Vector2(p.x, r.end.y + 8)]
		options.sort_custom(func(a: Vector2, b: Vector2) -> bool: return p.distance_to(a) < p.distance_to(b))
		body.global_position = options[0]
