class_name Level
extends Node2D
## A playable area: exposes its player, keeps the camera inside the painted ground, places the
## hero at its entries and hands the adventure state to the objects that remember things.

## Asks the game to travel to another area (relayed from the area's AreaExits).
signal exit_requested(area: StringName, entry: StringName)
## Asks the game to move the hero to entry `entry` of this same area behind a fade, without
## reloading it (a cage ride, a ladder): what the area's machines are doing stays as it is.
signal passage_requested(entry: StringName)

## Stable name of this area in saves and passages.
@export var area_id: StringName
@export var music: AudioStream
@export var player: Player
@export var ground: TileMapLayer
## Where a fall in this area leads (an entry of it), for areas with their own way back (the vein);
## empty: the adventure's checkpoint as everywhere. Objects of the area may move it (a lamp lit).
@export var fall_entry: StringName

## Text shown over the black between this area and the next, for the next trip only: something
## that happens while the hero is on the road (a night passing).
var interlude: String = ""


func _ready() -> void:
	var bounds := Rect2i(ground.get_used_rect().position * ground.tile_set.tile_size,
			ground.get_used_rect().size * ground.tile_set.tile_size)
	var camera := player.camera
	camera.limit_left = bounds.position.x
	camera.limit_top = bounds.position.y
	camera.limit_right = bounds.end.x
	camera.limit_bottom = bounds.end.y
	camera.reset_physics_interpolation()
	for node in find_children("*", "", true, false):
		if node is AreaExit:
			(node as AreaExit).taken.connect(exit_requested.emit)


## The Level `node` belongs to, or null.
static func containing(node: Node) -> Level:
	var at := node
	while at != null and not at is Level:
		at = at.get_parent()
	return at as Level


func entry(id: StringName) -> AreaEntry:
	for node in find_children("*", "", true, false):
		if node is AreaEntry and (node as AreaEntry).id == id:
			return node
	return null


## Moves the hero to entry `id`, snapping camera and interpolation. False if there is no such entry.
func place_player(id: StringName) -> bool:
	var arrival := entry(id)
	if arrival == null:
		return false
	player.global_position = arrival.global_position
	player.face(arrival.facing)
	player.reset_physics_interpolation()
	player.camera.reset_smoothing()
	return true


## Gives every object of this area that remembers progress (group "adventure") the state.
func bind_adventure(adventure: Adventure) -> void:
	for node in get_tree().get_nodes_in_group(&"adventure"):
		if is_ancestor_of(node):
			node.call(&"bind_adventure", adventure)
