class_name Mural
extends Inscription
## The carved slab in the heart chamber: barely visible in the dark, its cuts glow once the
## ruin's heart is lit (and what it says follows its `lines`, like any inscription).

## Regions of the mural sheet: dark, lit.
const DARK := Rect2(0, 0, 48, 32)
const LIT := Rect2(48, 0, 48, 32)

## Flag that lights the carving.
@export var lit_flag: StringName = &"ruin_heart_awakened"

@onready var _sprite: Sprite2D = $Sprite


func bind_adventure(adventure: Adventure) -> void:
	super(adventure)
	adventure.changed.connect(_show)
	_show()


func _show() -> void:
	_sprite.region_rect = LIT if _adventure != null and _adventure.has_flag(lit_flag) else DARK
