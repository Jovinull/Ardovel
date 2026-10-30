class_name Hud
extends CanvasLayer
## Heads-up display: hearts for the player's health, the dialogue box and, during a boss fight,
## the boss's name and health bar. Messages are shown page by page (a blank line starts a new
## page) and wait for the player to read them.
##
## Growth stays out of the way: under the hearts, the level and a thin experience bar show for a
## moment when experience comes in; the level and a small gold mark stay while attribute points
## wait to be spent; a level reached shows a short notice at the top and a sound, and the play goes
## on underneath (nothing waits for it).

signal dialogue_started
signal dialogue_finished

const HEART_SHEET := preload("res://assets/ninja_adventure/Ui/Receptacle/Heart.png")
## Each heart shows four quarters of health; the sheet has one frame per quarter (0 = empty).
const QUARTERS_PER_HEART := 4
const HEART_SIZE := 16
const REVEAL_CHARS_PER_SECOND := 50.0
const SPEAKER_X := 34.0
const SPEAKER_X_BESIDE_PORTRAIT := 82.0
const GUIDANCE_HOLD_TIME := 9.0
const GUIDANCE_FADE_TIME := 0.7
## Inner width of the boss health bar.
const BOSS_BAR_WIDTH := 138.0
## Inner width of the breath bar under the hearts.
const BREATH_WIDTH := 44.0
const CHOICE_BOX := preload("res://assets/ninja_adventure/Ui/Dialog/ChoiceBox.png")
const LEVEL_SOUND := preload("res://assets/ninja_adventure/Audio/Sounds/Bonus/Bonus.wav")
const GOLD := Color("f1c471")
const DARK := Color("141b1b")
const XP_WIDTH := 44.0
## Seconds the experience bar stays after experience comes in, and the level notice.
const XP_HOLD_TIME := 2.4
const LEVEL_HOLD_TIME := 2.8
const FADE_TIME := 0.4

var _heart_frames: Array[AtlasTexture] = []
var _message_tween: Tween
var _arrow_tween: Tween
var _pages: PackedStringArray = []
var _page: int = 0
var _guidance_key: String = ""
## The actions whose keys or buttons fill the hint's placeholders, in order.
var _guidance_actions: Array[StringName] = [&"pause", &"interact"]
var _guidance_tween: Tween
var _gamepad_active: bool = false
var _joypad_name: String = ""
var _boss_health: Health
var _growth: Control
var _level_label: Label
var _points_mark: Control
var _xp_bar: Control
var _xp_fill: ColorRect
var _xp_gain: Label
var _level_box: NinePatchRect
var _level_title: Label
var _level_points: Label
var _level_sound: AudioStreamPlayer
var _growth_tween: Tween
var _level_tween: Tween
var _shown_level := 1
var _free_points := 0

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
@onready var _breath: Control = %Breath
@onready var _breath_fill: ColorRect = %BreathFill
@onready var _quick: Control = %Quick
@onready var _quick_icon: TextureRect = %QuickIcon
@onready var _quick_count: Label = %QuickCount
@onready var _quick_key: Label = %QuickKey


func _ready() -> void:
	for quarter in QUARTERS_PER_HEART + 1:
		var frame := AtlasTexture.new()
		frame.atlas = HEART_SHEET
		frame.region = Rect2(quarter * HEART_SIZE, 0, HEART_SIZE, HEART_SIZE)
		_heart_frames.append(frame)
	_close_box()
	_build_growth()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_guidance()
		if _level_label != null:
			_level_label.text = tr("HUD_LEVEL") % _shown_level


func bind_player(player: Player) -> void:
	player.health.changed.connect(show_health)
	player.stamina.changed.connect(show_breath)
	show_breath(player.stamina.current, player.stamina.maximum)
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


## Breath, under the hearts: shown while it is not full, so a calm walk keeps the screen clean.
func show_breath(current: float, maximum: float) -> void:
	_breath_fill.size.x = BREATH_WIDTH * current / maxf(maximum, 1.0)
	_breath.visible = current < maximum - 0.5


func is_breath_visible() -> bool:
	return _breath.visible


func _build_growth() -> void:
	var frame := get_node(^"Frame") as Control
	_growth = Control.new()
	_growth.name = "Growth"
	_growth.position = Vector2(6, 27)
	_growth.size = Vector2(96, 10)
	_growth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_growth.visible = false
	frame.add_child(_growth)
	_level_label = _hud_label(_growth, "Level", Rect2(0, 0, 24, 10), GOLD)
	_points_mark = _diamond(_growth)
	_xp_bar = Control.new()
	_xp_bar.name = "Experience"
	_xp_bar.position = Vector2(30, 3)
	_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_growth.add_child(_xp_bar)
	var back := ColorRect.new()
	back.color = DARK
	back.size = Vector2(XP_WIDTH + 2, 4)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_xp_bar.add_child(back)
	_xp_fill = ColorRect.new()
	_xp_fill.color = GOLD
	_xp_fill.position = Vector2(1, 1)
	_xp_fill.size = Vector2(0, 2)
	_xp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(_xp_fill)
	_xp_gain = _hud_label(_growth, "Gain", Rect2(XP_WIDTH + 34, 0, 30, 10), GOLD)
	_level_box = NinePatchRect.new()
	_level_box.name = "LevelUp"
	_level_box.texture = CHOICE_BOX
	_level_box.patch_margin_left = 4
	_level_box.patch_margin_top = 4
	_level_box.patch_margin_right = 4
	_level_box.patch_margin_bottom = 4
	_level_box.position = Vector2(100, 30)
	_level_box.size = Vector2(120, 28)
	_level_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_box.visible = false
	frame.add_child(_level_box)
	_level_title = _hud_label(_level_box, "Title", Rect2(4, 4, 112, 10), Color("8f3e56"), false)
	_level_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_points = _hud_label(_level_box, "Points", Rect2(4, 14, 112, 10), Color("3b3643"), false)
	_level_points.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level_sound = AudioStreamPlayer.new()
	_level_sound.name = "LevelSound"
	_level_sound.stream = LEVEL_SOUND
	_level_sound.volume_db = -6.0
	add_child(_level_sound)


func _hud_label(parent: Control, node_name: String, rect: Rect2, colour: Color, shadow: bool = true) -> Label:
	var label := Label.new()
	label.name = node_name
	label.position = rect.position
	label.size = rect.size
	label.add_theme_color_override(&"font_color", colour)
	if not shadow:
		label.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 0))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


## A 5x5 gold diamond with a dark edge: attribute points wait to be spent.
func _diamond(parent: Control) -> Control:
	var mark := Control.new()
	mark.name = "Points"
	mark.size = Vector2(7, 7)
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(mark)
	for row: Array in [[3, 0, 1], [2, 1, 3], [1, 2, 5], [2, 3, 3], [3, 4, 1]]:
		var edge := ColorRect.new()
		edge.color = DARK
		edge.position = Vector2(row[0] - 1, row[1] + 1)
		edge.size = Vector2(row[2] + 2, 1)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_child(edge)
	for row: Array in [[3, 0, 1], [2, 1, 3], [1, 2, 5], [2, 3, 3], [3, 4, 1]]:
		var light := ColorRect.new()
		light.color = GOLD
		light.position = Vector2(row[0], row[1] + 1)
		light.size = Vector2(row[2], 1)
		light.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.add_child(light)
	return mark


## The hero's growth now: `level`, `progress` (gained, needed in this level; zero at the last),
## `free_points` waiting, and `gained` experience just now (0: nothing came in, only keep the mark
## right).
func show_growth(level: int, progress: Vector2i, free_points: int, gained: int) -> void:
	if _growth == null:
		return
	_shown_level = level
	_free_points = free_points
	_level_label.text = tr("HUD_LEVEL") % level
	_points_mark.position = Vector2(_level_label.get_minimum_size().x + 2, 1)
	_points_mark.visible = free_points > 0
	_xp_fill.size.x = XP_WIDTH * progress.x / maxf(progress.y, 1.0) if progress.y > 0 else XP_WIDTH
	if gained > 0:
		_xp_gain.text = tr("HUD_XP_GAIN") % gained
		_flash_growth()
	elif _growth_tween == null or not _growth_tween.is_running():
		_settle_growth()


func _flash_growth() -> void:
	if _growth_tween != null:
		_growth_tween.kill()
	_growth.visible = true
	_growth.modulate.a = 1.0
	_xp_bar.visible = true
	_xp_gain.visible = true
	_growth_tween = create_tween()
	_growth_tween.tween_interval(XP_HOLD_TIME)
	_growth_tween.tween_callback(_settle_growth)


## Between gains: only the level and the mark, and only while points wait.
func _settle_growth() -> void:
	_xp_bar.visible = false
	_xp_gain.visible = false
	_growth.visible = _free_points > 0
	_growth.modulate.a = 1.0


## A level reached: a short notice at the top and a sound; nothing waits for it.
func show_level_up(level: int, free_points: int) -> void:
	if _level_box == null:
		return
	_level_title.text = tr("HUD_LEVEL_UP") % level
	_level_points.text = tr("HUD_POINTS_ONE") if free_points == 1 else tr("HUD_POINTS") % free_points
	_level_box.visible = true
	_level_box.modulate.a = 1.0
	_level_sound.play()
	if _level_tween != null:
		_level_tween.kill()
	_level_tween = create_tween()
	_level_tween.tween_interval(LEVEL_HOLD_TIME)
	_level_tween.tween_property(_level_box, ^"modulate:a", 0.0, FADE_TIME)
	_level_tween.tween_callback(_level_box.hide)


func is_growth_visible() -> bool:
	return _growth != null and _growth.visible


func is_experience_bar_visible() -> bool:
	return is_growth_visible() and _xp_bar.visible


func is_points_mark_visible() -> bool:
	return is_growth_visible() and _points_mark.visible


func is_level_notice_visible() -> bool:
	return _level_box != null and _level_box.visible


func level_notice_text() -> String:
	return _level_title.text + "\n" + _level_points.text if _level_box != null else ""


## The food the quick-use key eats, with how many are left (no icon: the slot hides).
func show_quick_item(icon: Texture2D, count: int) -> void:
	_quick.visible = icon != null
	_quick_icon.texture = icon
	_quick_count.text = str(count) if count > 1 else ""
	_quick_key.text = InputPrompts.action_label(&"quick_item", _gamepad_active, _joypad_name).split(" / ", false)[0] \
			if not InputPrompts.action_label(&"quick_item", _gamepad_active, _joypad_name).is_empty() else ""


func is_quick_item_visible() -> bool:
	return _quick.visible


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


## Shows or hides a short translated hint without interrupting movement; its placeholders name
## the keys or buttons of `actions`.
func set_guidance(message_key: String, actions: Array[StringName] = [&"pause", &"interact"]) -> void:
	_guidance_actions = actions
	if message_key == _guidance_key:
		_update_guidance()
		return
	if _guidance_tween != null:
		_guidance_tween.kill()
	_guidance_key = message_key
	_update_guidance()
	_guidance_box.visible = not message_key.is_empty()
	_guidance_box.modulate.a = 1.0
	if not message_key.is_empty():
		_guidance_tween = create_tween()
		_guidance_tween.tween_interval(GUIDANCE_HOLD_TIME)
		_guidance_tween.tween_property(_guidance_box, ^"modulate:a", 0.0, GUIDANCE_FADE_TIME)
		_guidance_tween.tween_callback(_guidance_box.hide)


func set_input_mode(gamepad: bool, joypad_name: String) -> void:
	_gamepad_active = gamepad
	_joypad_name = joypad_name
	_update_guidance()


func is_guidance_visible() -> bool:
	return _guidance_box.visible


func _update_guidance() -> void:
	if _guidance_key.is_empty():
		_guidance.text = ""
		return
	var labels: Array[String] = []
	for action in _guidance_actions:
		labels.append(InputPrompts.action_label(action, _gamepad_active, _joypad_name))
	_guidance.text = InputPrompts.format_template(tr(_guidance_key), labels)


func _unhandled_input(event: InputEvent) -> void:
	if is_message_visible() and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack")):
		get_viewport().set_input_as_handled()
		advance()
	elif is_guidance_visible() and event.is_action_pressed(&"interact"):
		_dismiss_guidance()


func _dismiss_guidance() -> void:
	if _guidance_tween != null:
		_guidance_tween.kill()
	_guidance_tween = create_tween()
	_guidance_tween.tween_property(_guidance_box, ^"modulate:a", 0.0, GUIDANCE_FADE_TIME)
	_guidance_tween.tween_callback(_guidance_box.hide)


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
