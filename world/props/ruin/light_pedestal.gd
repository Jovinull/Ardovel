class_name LightPedestal
extends StaticBody2D
## An orb on a stone stand. A sword strike lights it or puts it out, until it is locked.

signal toggled(lit: bool)

## Regions of the pack's TilesetDungeon.png: the dark orb and the blue one, like the guardians'.
const DARK := Rect2(48, 32, 16, 16)
const LIT := Rect2(64, 32, 16, 16)

@export var lit: bool = false

var locked: bool = false

@onready var _sprite: Sprite2D = $Sprite
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _sound: AudioStreamPlayer2D = $Sound


func _ready() -> void:
	_hurtbox.hit_received.connect(_on_hit_received)
	_show()


## Sets the orb without a sound or a signal (restoring a solved puzzle).
func set_lit_quietly(value: bool) -> void:
	lit = value
	_show()


func _on_hit_received(_hit: Hit) -> void:
	if locked:
		return
	lit = not lit
	_show()
	_sound.pitch_scale = 1.2 if lit else 0.85
	_sound.play()
	toggled.emit(lit)


func _show() -> void:
	_sprite.region_rect = LIT if lit else DARK
