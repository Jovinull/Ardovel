class_name PauseScreen
extends CanvasLayer
## Pauses the adventure and offers the small set of actions needed during play.

signal resume_requested
signal language_requested
signal title_requested
signal quit_requested

enum Choice { RESUME, CONTROLS, LANGUAGE, TITLE, QUIT, BACK }

const LABELS: Dictionary[Choice, String] = {
	Choice.RESUME: "PAUSE_RESUME",
	Choice.CONTROLS: "PAUSE_CONTROLS",
	Choice.LANGUAGE: "PAUSE_LANGUAGE",
	Choice.TITLE: "PAUSE_TITLE_SCREEN",
	Choice.QUIT: "PAUSE_QUIT",
	Choice.BACK: "PAUSE_BACK",
}
const CONTROL_KEYS: Array[String] = [
	"PAUSE_CONTROL_MOVE",
	"PAUSE_CONTROL_SWORD",
	"PAUSE_CONTROL_INTERACT",
	"PAUSE_CONTROL_MENU",
]
const SELECTED_COLOR := Color("f1c471")
const IDLE_COLOR := Color("948a9c")

var choices: Array[Choice] = []
var _selected: int = 0
var _showing_controls: bool = false

@onready var _root: Control = $Root
@onready var _title: Label = %Title
@onready var _options: VBoxContainer = %Options
@onready var _controls: Label = %Controls
@onready var _back: Label = %Back
@onready var _notice: Label = %Notice


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_translations()


func open() -> void:
	_notice.text = ""
	_show_main_menu()
	_root.show()
	set_process_unhandled_input(true)


func close() -> void:
	_root.hide()
	set_process_unhandled_input(false)


func is_open() -> bool:
	return _root.visible


func is_showing_controls() -> bool:
	return _showing_controls


func show_notice(key: String) -> void:
	_notice.text = key


func choose(choice: Choice) -> void:
	match choice:
		Choice.RESUME:
			resume_requested.emit()
		Choice.CONTROLS:
			_show_controls()
		Choice.LANGUAGE:
			language_requested.emit()
		Choice.TITLE:
			title_requested.emit()
		Choice.QUIT:
			quit_requested.emit()
		Choice.BACK:
			_show_main_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if _showing_controls:
			_show_main_menu()
		else:
			choose(Choice.RESUME)
		return
	if _showing_controls:
		if event.is_action_pressed(&"interact") or event.is_action_pressed(&"attack") \
				or event.is_action_pressed(&"ui_accept"):
			get_viewport().set_input_as_handled()
			_show_main_menu()
		return
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
	_showing_controls = false
	_controls.hide()
	_back.hide()
	_options.show()
	_show_choices([Choice.RESUME, Choice.CONTROLS, Choice.LANGUAGE, Choice.TITLE, Choice.QUIT])


func _show_controls() -> void:
	_showing_controls = true
	choices = [Choice.BACK]
	_options.hide()
	_controls.show()
	_back.show()
	_back.add_theme_color_override(&"font_color", SELECTED_COLOR)
	_update_translations()


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
	_update_translations()
	_select(0)


func _update_translations() -> void:
	var index := choices.find(Choice.LANGUAGE)
	if index != -1:
		var label := _options.get_child(index) as Label
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = tr(LABELS[Choice.LANGUAGE]) % tr("LANGUAGE_NAME")
	if _showing_controls:
		_controls.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var lines: PackedStringArray = []
		for key in CONTROL_KEYS:
			lines.append(tr(key))
		_controls.text = "\n".join(lines)


func _select(index: int) -> void:
	_selected = wrapi(index, 0, choices.size())
	for i in _options.get_child_count():
		var label := _options.get_child(i) as Label
		label.add_theme_color_override(&"font_color", SELECTED_COLOR if i == _selected else IDLE_COLOR)
