class_name Hud
extends CanvasLayer
## Heads-up display: hearts for the player's health, the dialogue box and, during a boss fight,
## the boss's name and health bar. Messages are shown page by page (a blank line starts a new
## page) and wait for the player to read them.

signal dialogue_started
signal dialogue_finished

const HEART_SHEET := preload("res://assets/ninja_adventure/Ui/Receptacle/Heart.png")
## Each heart shows four quarters of health; the sheet has one frame per quarter (0 = empty).
const QUARTERS_PER_HEART := 4
const HEART_SIZE := 16
const REVEAL_CHARS_PER_SECOND := 50.0
const SPEAKER_X := 34.0
const SPEAKER_X_BESIDE_PORTRAIT := 82.0
## Inner width of the boss health bar.
const BOSS_BAR_WIDTH := 138.0

var _heart_frames: Array[AtlasTexture] = []
var _message_tween: Tween
var _arrow_tween: Tween
var _pages: PackedStringArray = []
var _page: int = 0
var _guidance_key: String = ""
var _boss_health: Health

@onready var _hearts: HBoxContainer = %Hearts
@onready var _message_box: Control = %MessageBox
@onready var _message: Label = %Message
@onready var _next_arrow: TextureRect = %NextArrow
@onready var _portrait_box: Control = %PortraitBox
@onready var _portrait: TextureRect = %Portrait
@onready var _speaker: Label = %Speaker
@onready var _guidance_box: NinePatchRect = %GuidanceBox
@onready var _guidance: Label = %Guidance
@onready var _boss_bar: Control = %BossBar
@onready var _boss_name: Label = %Name
@onready var _boss_fill: ColorRect = %Fill


func _ready() -> void:
	for quarter in QUARTERS_PER_HEART + 1:
		var frame := AtlasTexture.new()
		frame.atlas = HEART_SHEET
		frame.region = Rect2(quarter * HEART_SIZE, 0, HEART_SIZE, HEART_SIZE)
		_heart_frames.append(frame)
	_close_box()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_guidance()


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


## Shows the boss bar for `health` under the name `name_key` (a translation key).
func show_boss(name_key: String, health: Health) -> void:
	hide_boss()
	_boss_health = health
	_boss_name.text = name_key
	health.changed.connect(_show_boss_health)
	_show_boss_health(health.current, health.max_health)
	_boss_bar.show()


func hide_boss() -> void:
	if is_instance_valid(_boss_health) and _boss_health.changed.is_connected(_show_boss_health):
		_boss_health.changed.disconnect(_show_boss_health)
	_boss_health = null
	_boss_bar.hide()


func is_boss_bar_visible() -> bool:
	return _boss_bar.visible


func boss_bar_fraction() -> float:
	return _boss_fill.size.x / BOSS_BAR_WIDTH


func _show_boss_health(current: int, maximum: int) -> void:
	_boss_fill.size.x = BOSS_BAR_WIDTH * float(current) / maximum


## Number of filled quarters shown by heart `index` (for tests and debugging).
func heart_quarters(index: int) -> int:
	var heart := _hearts.get_child(index) as TextureRect
	return _heart_frames.find(heart.texture)


## Opens the dialogue box with `text` (a translation key, or text without one); an empty text
## changes nothing. `speaker` is translated too.
func show_message(text: String, speaker: String = "", portrait: Texture2D = null) -> void:
	if text.is_empty():
		return
	var was_open := is_message_visible()
	_pages = tr(text).split("\n\n", false)
	_page = 0
	_speaker.text = tr(speaker)
	_speaker.visible = not speaker.is_empty()
	_portrait.texture = portrait
	_portrait_box.visible = portrait != null
	_speaker.position.x = SPEAKER_X_BESIDE_PORTRAIT if portrait != null else SPEAKER_X
	_message_box.show()
	_show_page()
	if not was_open:
		dialogue_started.emit()


## Finishes typing the current page, or moves to the next one, closing after the last.
func advance() -> void:
	if not is_message_visible():
		return
	if _message.visible_characters != -1:
		_message_tween.kill()
		_reveal_done()
	elif _page + 1 < _pages.size():
		_page += 1
		_show_page()
	else:
		_close_box()
		dialogue_finished.emit()


func is_message_visible() -> bool:
	return _message_box.visible


## Shows or hides a short translated first-step hint without interrupting movement.
func set_guidance(message_key: String) -> void:
	_guidance_key = message_key
	_update_guidance()
	_guidance_box.visible = not message_key.is_empty()


func is_guidance_visible() -> bool:
	return _guidance_box.visible


func _update_guidance() -> void:
	_guidance.text = tr(_guidance_key) if not _guidance_key.is_empty() else ""


func _unhandled_input(event: InputEvent) -> void:
	if is_message_visible() and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack")):
		get_viewport().set_input_as_handled()
		advance()


func _show_page() -> void:
	if _message_tween != null:
		_message_tween.kill()
	_set_arrow(false)
	_message.text = _pages[_page]
	_message.visible_characters = 0
	var length := _message.get_total_character_count()
	_message_tween = create_tween()
	_message_tween.tween_property(_message, ^"visible_characters", length, length / REVEAL_CHARS_PER_SECOND)
	_message_tween.tween_callback(_reveal_done)


func _reveal_done() -> void:
	_message.visible_characters = -1
	_set_arrow(true)


func _set_arrow(shown: bool) -> void:
	if _arrow_tween != null:
		_arrow_tween.kill()
	_next_arrow.visible = shown
	_next_arrow.position.y = 40.0
	if shown:
		_arrow_tween = create_tween().set_loops()
		_arrow_tween.tween_property(_next_arrow, ^"position:y", 38.0, 0.3)
		_arrow_tween.tween_property(_next_arrow, ^"position:y", 40.0, 0.3)


func _close_box() -> void:
	if _message_tween != null:
		_message_tween.kill()
	_set_arrow(false)
	_message_box.hide()
	_portrait_box.hide()
	_speaker.hide()


func _on_interacted(target: Interactable, message: String) -> void:
	if target == null:
		show_message(message)
	else:
		show_message(message, target.speaker, target.portrait)
