class_name TitleScreen
extends CanvasLayer
## Opening menu: continue the saved adventure, start a new one (asking first when that would
## replace existing progress), switch the language or quit. Labels hold translation keys and
## follow language changes on their own.

signal continue_requested
signal new_requested
signal language_requested
signal quit_requested

enum Choice { CONTINUE, NEW, LANGUAGE, QUIT, CONFIRM_NEW, CANCEL }

const LABELS: Dictionary[Choice, String] = {
	Choice.CONTINUE: "TITLE_CONTINUE",
	Choice.NEW: "TITLE_NEW",
	Choice.LANGUAGE: "TITLE_LANGUAGE",
	Choice.QUIT: "TITLE_QUIT",
	Choice.CONFIRM_NEW: "TITLE_CONFIRM_NEW",
	Choice.CANCEL: "TITLE_CANCEL",
}
const SELECTED_COLOR := Color("f1c471")
const IDLE_COLOR := Color("948a9c")
const BACKDROP_SCENES: Array[String] = [
	"res://world/village/village.tscn",
	"res://world/forest/forest.tscn",
	"res://world/ruin/ruin.tscn",
]
const BACKDROP_FADE_TIME := 0.75
const BACKDROP_SCENE_TIME := 17.0

var choices: Array[Choice] = []
var _selected: int = 0
var _can_continue: bool = false
var _has_progress: bool = false
var _notice_text: String = ""
var _gamepad_active: bool = false
var _joypad_name: String = ""
var _backdrop_level: Level
var _backdrop_elapsed: float = 0.0
var _backdrop_scene_index: int = -1
var _backdrop_tween: Tween

@onready var _root: Control = $Root
@onready var _notice: Label = %Notice
@onready var _options: VBoxContainer = %Options
@onready var _input_hint: Label = %InputHint
@onready var _backdrop_view: SubViewport = $Root/Backdrop/SubViewport
@onready var _backdrop_shade: ColorRect = %BackdropShade


func _ready() -> void:
	close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_language_label()


## Shows the main menu. `has_progress` means a save exists, even an unreadable one; `notice`
## is a translation key.
func open(can_continue: bool, has_progress: bool, notice: String = "") -> void:
	_can_continue = can_continue
	_has_progress = has_progress
	_notice_text = notice
	_show_main_menu()
	_root.show()
	_activate_backdrop()
	set_physics_process(true)
	set_process_unhandled_input(true)


func close() -> void:
	_root.hide()
	set_physics_process(false)
	set_process_unhandled_input(false)
	_deactivate_backdrop()


func is_open() -> bool:
	return _root.visible


func set_input_mode(gamepad: bool, joypad_name: String) -> void:
	_gamepad_active = gamepad
	_joypad_name = joypad_name
	_input_hint.text = InputPrompts.title_hint(_gamepad_active, _joypad_name)


func choose(choice: Choice) -> void:
	match choice:
		Choice.CONTINUE:
			continue_requested.emit()
		Choice.NEW:
			if _has_progress:
				_notice.text = "TITLE_REPLACE_WARNING"
				_show_choices([Choice.CANCEL, Choice.CONFIRM_NEW])
			else:
				new_requested.emit()
		Choice.CONFIRM_NEW:
			new_requested.emit()
		Choice.LANGUAGE:
			language_requested.emit()
		Choice.CANCEL:
			_show_main_menu()
		Choice.QUIT:
			quit_requested.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"move_up"):
		_select(_selected - 1)
	elif event.is_action_pressed(&"move_down"):
		_select(_selected + 1)
	elif event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack") \
			or event.is_action_pressed(&"ui_accept"):
		choose(choices[_selected])
	else:
		return
	get_viewport().set_input_as_handled()


func _show_main_menu() -> void:
	_notice.text = _notice_text
	var main: Array[Choice] = [Choice.NEW, Choice.LANGUAGE, Choice.QUIT]
	if _can_continue:
		main.push_front(Choice.CONTINUE)
	_show_choices(main)


func _show_choices(list: Array[Choice]) -> void:
	choices = list
	for child in _options.get_children():
		_options.remove_child(child)
		child.free()
	for choice in choices:
		var label := Label.new()
		label.text = LABELS[choice]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_options.add_child(label)
	_select(0)


func _physics_process(delta: float) -> void:
	if not is_open() or _backdrop_level == null or _backdrop_tween != null:
		return
	_backdrop_elapsed += delta
	if _backdrop_elapsed >= BACKDROP_SCENE_TIME:
		_transition_backdrop()


## "Language: <name>" needs formatting, so that label is translated here instead.
func _update_language_label() -> void:
	var index := choices.find(Choice.LANGUAGE)
	for i in _options.get_child_count():
		var label := _options.get_child(i) as Label
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var text := tr(LABELS[choices[i]])
		if i == index:
			text = text % tr("LANGUAGE_NAME")
		label.text = ("> " if i == _selected else "  ") + text
	_input_hint.text = InputPrompts.title_hint(_gamepad_active, _joypad_name)


func _select(index: int) -> void:
	_selected = wrapi(index, 0, choices.size())
	for i in _options.get_child_count():
		var label := _options.get_child(i) as Label
		label.add_theme_color_override(&"font_color", SELECTED_COLOR if i == _selected else IDLE_COLOR)
	_update_language_label()


func _activate_backdrop() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_backdrop_shade.color.a = 1.0
	_backdrop_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if _backdrop_level == null:
		_set_backdrop(0)
	_reveal_backdrop_after_render()


func _reveal_backdrop_after_render() -> void:
	await RenderingServer.frame_post_draw
	if not is_open() or _backdrop_level == null:
		return
	_backdrop_shade.color.a = 0.48


func _deactivate_backdrop() -> void:
	if _backdrop_tween != null:
		_backdrop_tween.kill()
	_backdrop_tween = null
	_backdrop_view.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if _backdrop_level != null:
		_backdrop_view.remove_child(_backdrop_level)
		_backdrop_level.queue_free()
		_backdrop_level = null
	_backdrop_scene_index = -1


func _transition_backdrop() -> void:
	_backdrop_tween = create_tween()
	_backdrop_tween.tween_property(_backdrop_shade, ^"color:a", 1.0, BACKDROP_FADE_TIME)
	_backdrop_tween.tween_callback(func() -> void:
		_set_backdrop((_backdrop_scene_index + 1) % BACKDROP_SCENES.size())
		_backdrop_shade.color.a = 1.0
	)
	_backdrop_tween.tween_interval(0.1)
	_backdrop_tween.tween_property(_backdrop_shade, ^"color:a", 0.48, BACKDROP_FADE_TIME)
	_backdrop_tween.tween_callback(func() -> void: _backdrop_tween = null)


func _set_backdrop(index: int) -> void:
	if _backdrop_level != null:
		_backdrop_view.remove_child(_backdrop_level)
		_backdrop_level.queue_free()
	var packed := load(BACKDROP_SCENES[index]) as PackedScene
	_backdrop_level = packed.instantiate() as Level
	_backdrop_level.process_mode = Node.PROCESS_MODE_DISABLED
	_backdrop_view.add_child(_backdrop_level)
	_backdrop_level.player.camera.enabled = false
	_backdrop_level.player.hide()
	_backdrop_level.bind_adventure(Adventure.new())
	var camera := Camera2D.new()
	camera.name = "TitleCamera"
	camera.process_mode = Node.PROCESS_MODE_ALWAYS
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	_backdrop_level.add_child(camera)
	camera.make_current()
	_backdrop_scene_index = index
	_backdrop_elapsed = 0.0
	var bounds := _backdrop_level.ground.get_used_rect()
	var tile_size := _backdrop_level.ground.tile_set.tile_size
	var world_rect := Rect2(bounds.position * tile_size, bounds.size * tile_size)
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.position = world_rect.get_center().round()
