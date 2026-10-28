class_name WestTraces
extends Node2D
## Fresh footprints in the dust of the lookout's shelf, between the fallen bridge and the
## disc. They are only there once the glint has been seen in the forest: someone came by
## after that, or about then.

const GLINT_FLAG := &"forest_echo_found"


func _ready() -> void:
	add_to_group(&"adventure")
	visible = false


func bind_adventure(adventure: Adventure) -> void:
	# Only on arrival: the marks never appear in front of the hero.
	visible = adventure.has_flag(GLINT_FLAG)
