class_name BrushTangle
extends StaticBody2D
## A tangle of brush across the old path up to the high stone, cut with any sword. The cuts are
## not saved one by one: once the view from the stone has been seen, the whole path stays open.

const CUT_FRAME := 2

## Its place along the path, from the road up (Breu hovers over the lowest one still standing).
@export var order: int = 0

var _adventure: Adventure
var _cut := false

@onready var _sprite: Sprite2D = $Sprite
@onready var _collision: CollisionShape2D = $Collision
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	add_to_group(&"adventure")
	add_to_group(&"blank_tangle")
	_hurtbox.hit_received.connect(_on_hit)


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	_show(adventure.has_flag(Blank.VIEW_SEEN))


func is_cut() -> bool:
	return _cut


func _on_hit(_hit: Hit) -> void:
	if _cut:
		return
	_sound.play()
	_show(true)


func _show(cut: bool) -> void:
	_cut = cut
	_sprite.region_rect = Rect2((CUT_FRAME if cut else 0) * 32, 0, 32, 16)
	_collision.set_deferred(&"disabled", cut)
	_hurtbox.set_deferred(&"monitorable", not cut)
