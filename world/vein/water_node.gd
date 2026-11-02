class_name WaterNode
extends Node2D
## One part of the vein's water, in discrete states: wet or dry. It is wet while what feeds it is
## wet: a node with no `source` is a spring (always wet); a Sluice sends its water down one of its
## two ways (`branch`). The whole network is worked out again whenever a sluice turns
## (`refresh_all`). Nothing of it is saved: entering the area always finds the water as the miners
## left it (Sluice.found_way), and only what flags prove stays done (a drained pool, a cart sent).
##
## By default a wet node shows its child "Wet" and hides "Dry" (and the other way round); subclasses
## add what being wet does (a channel blocks, a bucket hangs low).

signal wetness_changed(wet: bool)

## What feeds this (empty: a spring).
@export var source: WaterNode
## Which way of a Sluice source feeds this (Sluice.WEST or Sluice.EAST); ignored otherwise.
@export var branch: int = 0
## Dry for good once this flag is set (the pool after the drain runs).
@export var dries_with: StringName

var _adventure: Adventure
var _shown := -1


func _ready() -> void:
	add_to_group(&"vein_water")
	add_to_group(&"adventure")
	_apply.call_deferred(false)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	if not dries_with.is_empty():
		adventure.changed.connect(_apply.bind(true))
	_apply.call_deferred(false)


func is_wet() -> bool:
	if not dries_with.is_empty() and _adventure != null and _adventure.has_flag(dries_with):
		return false
	if source == null:
		return true
	if source is Sluice:
		return source.is_wet() and (source as Sluice).way == branch
	return source.is_wet()


## Works the water out again everywhere in the area (after a sluice turns).
static func refresh_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(&"vein_water"):
		(node as WaterNode)._apply(true)


func _apply(animate: bool) -> void:
	if not is_inside_tree():
		return
	var wet := is_wet()
	if int(wet) == _shown:
		return
	var first := _shown == -1
	_shown = int(wet)
	_show(wet, animate and not first)
	if not first:
		wetness_changed.emit(wet)


func _show(wet: bool, _animate: bool) -> void:
	var w := get_node_or_null(^"Wet") as CanvasItem
	var d := get_node_or_null(^"Dry") as CanvasItem
	if w != null:
		w.visible = wet
	if d != null:
		d.visible = not wet
