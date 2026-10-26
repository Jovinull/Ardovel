class_name HitFlash
extends Node
## Hit feedback for a sprite: a short white flash, and blinking while invulnerable.

const FLASH_SHADER := preload("res://combat/hit_flash.gdshader")
const BLINK_PERIOD := 0.06

@export var target: CanvasItem
@export var flash_time: float = 0.12

var _material: ShaderMaterial
var _flash_tween: Tween
var _blink_tween: Tween


func _ready() -> void:
	# A material per instance, so flashing one actor never flashes the others.
	_material = ShaderMaterial.new()
	_material.shader = FLASH_SHADER
	target.material = _material


func flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	_material.set_shader_parameter(&"flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, flash_time)


func blink(duration: float) -> void:
	if _blink_tween != null:
		_blink_tween.kill()
	_blink_tween = create_tween()
	_blink_tween.tween_method(_set_blink_phase, 0.0, duration, duration)
	_blink_tween.tween_callback(_set_blink_phase.bind(-1.0))


func _set_flash(value: float) -> void:
	_material.set_shader_parameter(&"flash", value)


func _set_blink_phase(elapsed: float) -> void:
	var dimmed := elapsed >= 0.0 and int(elapsed / BLINK_PERIOD) % 2 == 0
	target.modulate.a = 0.35 if dimmed else 1.0
