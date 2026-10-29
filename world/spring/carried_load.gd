class_name CarriedLoad
extends Node2D
## Iara's carrying frame on her back, drawn to suit the way she faces (read from her sprite's
## sheet column): seen side on behind her when she walks east or west, the whole frame peeking
## behind her when she faces the hero, and over her back when she walks away.

@onready var _front: Sprite2D = $Frame
@onready var _side: Sprite2D = $Side

var _sprite: Sprite2D


func _ready() -> void:
	_sprite = get_parent().get_node_or_null(^"Sprite") as Sprite2D


func _process(_delta: float) -> void:
	if _sprite == null:
		return
	var column := _sprite.frame % 4  # pack sheets: down, up, left, right
	_side.visible = column >= 2
	_front.visible = column < 2
	_side.flip_h = column == 3
	_side.position.x = -8.0 if column == 3 else 8.0  # out behind her back
	# behind her facing the hero, over her back walking away: drawn before or after her sprite
	var over := column == 1
	if (get_index() > _sprite.get_index()) != over:
		get_parent().move_child(self, -1 if over else 0)
