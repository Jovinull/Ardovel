class_name Hud
extends CanvasLayer
## Heads-up display: hearts for the player's health and a message box for interactions.

const HEART_SHEET := preload("res://assets/ninja_adventure/Ui/Receptacle/Heart.png")
## Each heart shows four quarters of health; the sheet has one frame per quarter (0 = empty).
const QUARTERS_PER_HEART := 4
const HEART_SIZE := 16
const MESSAGE_TIME := 2.5
const REVEAL_CHARS_PER_SECOND := 50.0

var _heart_frames: Array[AtlasTexture] = []
var _message_tween: Tween

@onready var _hearts: HBoxContainer = %Hearts
@onready var _message_box: Control = %MessageBox
@onready var _message: Label = %Message


func _ready() -> void:
	for quarter in QUARTERS_PER_HEART + 1:
		var frame := AtlasTexture.new()
		frame.atlas = HEART_SHEET
		frame.region = Rect2(quarter * HEART_SIZE, 0, HEART_SIZE, HEART_SIZE)
		_heart_frames.append(frame)
	_message_box.hide()


func bind_player(player: Player) -> void:
	player.health.changed.connect(show_health)
	player.interactor.interacted.connect(_on_interacted)
	show_health(player.health.current, player.health.max_health)


func show_health(current: int, maximum: int) -> void:
	var heart_count := ceili(float(maximum) / QUARTERS_PER_HEART)
	while _hearts.get_child_count() < heart_count:
		var heart := TextureRect.new()
		heart.stretch_mode = TextureRect.STRETCH_KEEP
		_hearts.add_child(heart)
	while _hearts.get_child_count() > heart_count:
		var extra := _hearts.get_child(_hearts.get_child_count() - 1)
		_hearts.remove_child(extra)
		extra.queue_free()
	for i in heart_count:
		var quarters := clampi(current - i * QUARTERS_PER_HEART, 0, QUARTERS_PER_HEART)
		(_hearts.get_child(i) as TextureRect).texture = _heart_frames[quarters]


## Number of filled quarters shown by heart `index` (for tests and debugging).
func heart_quarters(index: int) -> int:
	var heart := _hearts.get_child(index) as TextureRect
	return _heart_frames.find(heart.texture)


func show_message(text: String) -> void:
	if text.is_empty():
		return
	if _message_tween != null:
		_message_tween.kill()
	_message.text = text
	_message.visible_characters = 0
	_message_box.show()
	var length := _message.get_total_character_count()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, ^"visible_characters", length, length / REVEAL_CHARS_PER_SECOND)
	_message_tween.tween_interval(MESSAGE_TIME)
	_message_tween.tween_callback(_message_box.hide)


func is_message_visible() -> bool:
	return _message_box.visible


func _on_interacted(_target: Interactable, message: String) -> void:
	show_message(message)
