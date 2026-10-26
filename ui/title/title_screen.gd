class_name TitleScreen
extends CanvasLayer
## Opening menu: continue the saved adventure, start a new one (asking first when that would
## replace existing progress) or quit.

signal continue_requested
signal new_requested
signal quit_requested

enum Choice { CONTINUE, NEW, QUIT, CONFIRM_NEW, CANCEL }

const LABELS: Dictionary[Choice, String] = {
	Choice.CONTINUE: "Continuar",
	Choice.NEW: "Nova aventura",
	Choice.QUIT: "Sair",
	Choice.CONFIRM_NEW: "Sim, começar de novo",
	Choice.CANCEL: "Não",
}
const SELECTED_COLOR := Color("f1c471")
const IDLE_COLOR := Color("948a9c")

var choices: Array[Choice] = []
var _selected: int = 0
var _can_continue: bool = false
var _has_progress: bool = false
var _notice_text: String = ""

@onready var _root: Control = $Root
@onready var _notice: Label = %Notice
@onready var _options: VBoxContainer = %Options


func _ready() -> void:
	close()


## Shows the main menu. `has_progress` means a save exists, even an unreadable one.
func open(can_continue: bool, has_progress: bool, notice: String = "") -> void:
	_can_continue = can_continue
	_has_progress = has_progress
	_notice_text = notice
	_show_main_menu()
	_root.show()
	set_process_unhandled_input(true)


func close() -> void:
	_root.hide()
	set_process_unhandled_input(false)


func is_open() -> bool:
	return _root.visible


func choose(choice: Choice) -> void:
	match choice:
		Choice.CONTINUE:
			continue_requested.emit()
		Choice.NEW:
			if _has_progress:
				_notice.text = "Uma nova aventura substitui a que está salva."
				_show_choices([Choice.CANCEL, Choice.CONFIRM_NEW])
			else:
				new_requested.emit()
		Choice.CONFIRM_NEW:
			new_requested.emit()
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
	var main: Array[Choice] = [Choice.NEW, Choice.QUIT]
	if _can_continue:
		main.push_front(Choice.CONTINUE)
	_show_choices(main)


func _show_choices(list: Array[Choice]) -> void:
	choices = list
	for child in _options.get_children():
		_options.remove_child(child)
		child.queue_free()
	for choice in choices:
		var label := Label.new()
		label.text = LABELS[choice]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_options.add_child(label)
	_select(0)


func _select(index: int) -> void:
	_selected = wrapi(index, 0, choices.size())
	for i in _options.get_child_count():
		var label := _options.get_child(i) as Label
		label.add_theme_color_override(&"font_color", SELECTED_COLOR if i == _selected else IDLE_COLOR)
