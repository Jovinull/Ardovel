class_name EchoTrail
extends Node2D
## Carved stones carry a brief glow toward a second glint beyond the old path.

const HEART_FLAG := &"ruin_heart_awakened"

var _adventure: Adventure


func _ready() -> void:
	add_to_group(&"adventure")
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false


func bind_adventure(adventure: Adventure) -> void:
	_adventure = adventure
	adventure.changed.connect(_show_state)
	_show_state()


func _show_state() -> void:
	visible = _adventure.has_flag(HEART_FLAG)


func flash_reply() -> void:
	if not visible:
		return
	var sequence := create_tween()
	for sprite: Sprite2D in [$TraceEast, $TraceMiddle, $TraceWest]:
		sequence.tween_callback(_show_reply.bind(sprite))
		sequence.tween_interval(0.30)
		sequence.tween_callback(_show_normal.bind(sprite))
		sequence.tween_interval(0.08)
	sequence.tween_callback(_show_distant_glint)
	sequence.tween_property($DistantGlint, ^"position", Vector2(156, 222), 0.48)
	sequence.tween_property($DistantGlint, ^"modulate:a", 0.0, 0.22)
	sequence.tween_callback(_hide_distant_glint)


func _show_reply(sprite: Sprite2D) -> void:
	sprite.region_rect = Rect2(sprite.region_rect.position + Vector2(0, 16), Vector2(16, 16))


func _show_normal(sprite: Sprite2D) -> void:
	sprite.region_rect = Rect2(sprite.region_rect.position - Vector2(0, 16), Vector2(16, 16))


func _show_distant_glint() -> void:
	$DistantGlint.visible = true
	$DistantGlint.position = Vector2(125, 211)
	$DistantGlint.modulate.a = 1.0
	$DistantSound.play()


func _hide_distant_glint() -> void:
	$DistantGlint.visible = false
